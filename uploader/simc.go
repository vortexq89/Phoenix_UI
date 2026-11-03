package main

// SimulationCraft for the Phoenix app: which build may be used, asking the player before anything is
// downloaded, and fetching, checking and unpacking it.
//
// Trust chain. SimulationCraft publishes its Windows nightlies only on downloads.simulationcraft.org, over plain
// HTTP (its HTTPS certificate is for another host) and without checksums or signatures; the executable is not
// code-signed either. Every nightly is however built by the public GitHub workflow simulationcraft/simc-publish
// ("Nightly"), whose artifact GitHub stores with its own SHA-256 digest. tools/simc/pin.py downloads that
// artifact, checks GitHub's digest, hashes the .7z inside it and compares it with the file on the download
// server; the result is pinned in simc.json (embedded in this exe, and refreshed over HTTPS from the Phoenix
// repository). The app downloads only from the SimulationCraft host, refuses anything whose size or SHA-256
// differs from the pin, extracts only simc.exe and its licence, and checks simc.exe's own SHA-256 as well.
//
// Licence: SimulationCraft is GPL-3.0. Phoenix does not redistribute it; the player's PC downloads it from the
// SimulationCraft project and runs it as a separate program. Its COPYING file is kept next to simc.exe.

import (
	"context"
	"crypto/sha256"
	_ "embed"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"time"

	"github.com/bodgit/sevenzip"
)

//go:embed simc.json
var embeddedManifest []byte

// defaultManifestURL is the copy in the repository; it lets a new SimulationCraft build be pinned without a new
// app release. When it cannot be fetched or is not valid, the embedded copy is used.
var defaultManifestURL = "https://raw.githubusercontent.com/vortexq89/Phoenix_UI/main/uploader/simc.json"

// simcHosts are the only places a pinned build may be downloaded from.
var simcHosts = map[string]bool{"downloads.simulationcraft.org": true}

type SimcBuild struct {
	Version   string `json:"version"`
	Commit    string `json:"commit"`
	WowBuild  string `json:"wowBuild"`
	File      string `json:"file"`
	URL       string `json:"url"`
	Size      int64  `json:"size"`
	SHA256    string `json:"sha256"`
	Exe       string `json:"exe"`
	ExeSize   int64  `json:"exeSize"`
	ExeSHA256 string `json:"exeSha256"`
	License   string `json:"license"`
	Verified  string `json:"verified"`
}

type SimcManifest struct {
	Schema int         `json:"schema"`
	Builds []SimcBuild `json:"builds"`
}

var (
	hex64       = regexp.MustCompile(`^[0-9a-f]{64}$`)
	versionName = regexp.MustCompile(`^[0-9]{3,5}-[0-9]{2}$`)
	archivePath = regexp.MustCompile(`^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*$`)
)

// Validate refuses a manifest entry that is incomplete or points anywhere but the SimulationCraft host.
func (b SimcBuild) Validate() error {
	u, err := url.Parse(b.URL)
	switch {
	case !versionName.MatchString(b.Version):
		return fmt.Errorf("bad version %q", b.Version)
	case err != nil || (u.Scheme != "http" && u.Scheme != "https") || !simcHosts[strings.ToLower(u.Hostname())] || u.User != nil:
		return fmt.Errorf("download URL %q is not on a SimulationCraft host", b.URL)
	case b.Size <= 0 || b.Size > 1<<30 || b.ExeSize <= 0 || b.ExeSize > 1<<30:
		return errors.New("bad size")
	case !hex64.MatchString(b.SHA256) || !hex64.MatchString(b.ExeSHA256):
		return errors.New("bad SHA-256")
	case !archivePath.MatchString(b.Exe) || !strings.HasSuffix(strings.ToLower(b.Exe), "simc.exe") || strings.Contains(b.Exe, ".."):
		return fmt.Errorf("bad exe path %q", b.Exe)
	case !archivePath.MatchString(b.File) || strings.Contains(b.File, "/") || strings.Contains(b.File, ".."):
		return fmt.Errorf("bad file name %q", b.File)
	case b.License != "" && (!archivePath.MatchString(b.License) || strings.Contains(b.License, "..")):
		return fmt.Errorf("bad licence path %q", b.License)
	}
	return nil
}

// ParseManifest returns the first valid build of a manifest.
func ParseManifest(raw []byte) (SimcBuild, error) {
	var m SimcManifest
	if err := json.Unmarshal(raw, &m); err != nil {
		return SimcBuild{}, err
	}
	if m.Schema != 1 {
		return SimcBuild{}, fmt.Errorf("manifest schema %d", m.Schema)
	}
	for _, b := range m.Builds {
		if err := b.Validate(); err == nil {
			return b, nil
		}
	}
	return SimcBuild{}, errors.New("manifest has no usable build")
}

// Simc owns the SimulationCraft install in <data>/simc/<version>/.
type Simc struct {
	mu          sync.Mutex
	installMu   sync.Mutex // one download at a time
	dir         string
	manifestURL string
	custom      string // config "simcPath": the player's own simc.exe, used as is
	log         *Logger
	client      *http.Client
	build       SimcBuild
	buildAt     time.Time
	progress    func(done, total int64)
}

func NewSimc(dataDir, manifestURL, custom string, log *Logger) *Simc {
	if manifestURL == "" {
		manifestURL = defaultManifestURL
	}
	client := &http.Client{Timeout: 20 * time.Minute, CheckRedirect: func(req *http.Request, via []*http.Request) error {
		// The manifest may move within GitHub and the archive within the SimulationCraft server; nothing else.
		h := strings.ToLower(req.URL.Hostname())
		if len(via) > 5 || !(simcHosts[h] || h == "raw.githubusercontent.com" || isLocal(h)) {
			return fmt.Errorf("redirect to %s refused", h)
		}
		return nil
	}}
	return &Simc{dir: filepath.Join(dataDir, "simc"), manifestURL: manifestURL, custom: custom, log: log, client: client}
}

// Build is the pinned build: the repository manifest when it can be read (checked once an hour), else the
// embedded one.
func (s *Simc) Build() SimcBuild {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.build.Version != "" && time.Since(s.buildAt) < time.Hour {
		return s.build
	}
	b, err := ParseManifest(embeddedManifest)
	if err != nil {
		panic("embedded simc.json: " + err.Error()) // caught by the tests
	}
	if remote, err := s.fetchManifest(); err == nil {
		b = remote
	} else if s.log != nil && s.build.Version == "" {
		s.log.Printf("simc: using the built-in SimulationCraft pin (%v)", err)
	}
	s.build, s.buildAt = b, time.Now()
	return b
}

func (s *Simc) fetchManifest() (SimcBuild, error) {
	u, err := url.Parse(s.manifestURL)
	if err != nil || u.Scheme != "https" && !(u.Scheme == "http" && isLocal(u.Hostname())) {
		return SimcBuild{}, fmt.Errorf("manifest URL %q must use https", s.manifestURL)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, s.manifestURL, nil)
	req.Header.Set("User-Agent", "PhoenixUploader/"+version)
	res, err := s.client.Do(req)
	if err != nil {
		return SimcBuild{}, err
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return SimcBuild{}, fmt.Errorf("manifest: HTTP %d", res.StatusCode)
	}
	raw, err := io.ReadAll(io.LimitReader(res.Body, 64<<10))
	if err != nil {
		return SimcBuild{}, err
	}
	return ParseManifest(raw)
}

func isLocal(h string) bool { return h == "localhost" || h == "127.0.0.1" || h == "::1" }

// Exe returns a ready simc.exe: the player's own (config "simcPath") or the verified download.
func (s *Simc) Exe() (string, bool) {
	if s.custom != "" {
		if st, err := os.Stat(s.custom); err == nil && !st.IsDir() {
			return s.custom, true
		}
		return "", false
	}
	b := s.Build()
	p := s.exePath(b)
	ok, _ := fileMatches(p, b.ExeSize, b.ExeSHA256)
	return p, ok
}

func (s *Simc) exePath(b SimcBuild) string { return filepath.Join(s.dir, b.Version, "simc.exe") }

// Installed reports whether the pinned build is in place (without hashing 120 MB on every call: size and a
// marker written after a verified install).
func (s *Simc) Installed() bool {
	if s.custom != "" {
		_, ok := s.Exe()
		return ok
	}
	b := s.Build()
	st, err := os.Stat(s.exePath(b))
	if err != nil || st.Size() != b.ExeSize {
		return false
	}
	m, err := os.ReadFile(filepath.Join(s.dir, b.Version, "verified.sha256"))
	return err == nil && strings.TrimSpace(string(m)) == b.ExeSHA256
}

func fileMatches(path string, size int64, sum string) (bool, error) {
	f, err := os.Open(path)
	if err != nil {
		return false, err
	}
	defer f.Close()
	st, err := f.Stat()
	if err != nil || st.Size() != size {
		return false, err
	}
	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return false, err
	}
	return hex.EncodeToString(h.Sum(nil)) == sum, nil
}

// Install downloads, verifies and unpacks the pinned build. Only call it after the player said yes.
func (s *Simc) Install(ctx context.Context) error {
	if s.custom != "" {
		return errors.New("a custom simcPath is configured; nothing to download")
	}
	s.installMu.Lock()
	defer s.installMu.Unlock()
	if s.Installed() {
		return nil
	}
	b := s.Build()
	if err := os.MkdirAll(s.dir, 0o755); err != nil {
		return err
	}
	archive := filepath.Join(s.dir, b.File+".part")
	defer os.Remove(archive)
	s.log.Printf("simc: downloading %s (%d MB) from %s", b.File, b.Size>>20, b.URL)
	if err := s.download(ctx, b, archive); err != nil {
		return err
	}
	s.log.Printf("simc: archive SHA-256 matches the pin %s", b.SHA256[:16])
	final := filepath.Join(s.dir, b.Version)
	tmp := final + ".tmp"
	_ = os.RemoveAll(tmp)
	if err := os.MkdirAll(tmp, 0o755); err != nil {
		return err
	}
	if err := extract(archive, tmp, b); err != nil {
		_ = os.RemoveAll(tmp)
		return err
	}
	if err := os.WriteFile(filepath.Join(tmp, "verified.sha256"), []byte(b.ExeSHA256+"\n"), 0o644); err != nil {
		return err
	}
	_ = os.RemoveAll(final)
	if err := os.Rename(tmp, final); err != nil {
		return err
	}
	s.prune(b.Version)
	s.log.Printf("simc: SimulationCraft %s ready in %s", b.Version, final)
	return nil
}

func (s *Simc) download(ctx context.Context, b SimcBuild, dst string) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, b.URL, nil)
	if err != nil {
		return err
	}
	req.Header.Set("User-Agent", "PhoenixUploader/"+version)
	res, err := s.client.Do(req)
	if err != nil {
		return fmt.Errorf("download: %w", err)
	}
	defer res.Body.Close()
	if res.StatusCode != http.StatusOK {
		return fmt.Errorf("download: HTTP %d (the pinned build may have been replaced by a newer nightly; Phoenix pins the new one soon)", res.StatusCode)
	}
	if u := res.Request.URL; !simcHosts[strings.ToLower(u.Hostname())] {
		return fmt.Errorf("download was redirected to %s; refused", u.Hostname())
	}
	f, err := os.Create(dst)
	if err != nil {
		return err
	}
	h := sha256.New()
	w := io.MultiWriter(f, h)
	var done int64
	buf := make([]byte, 256<<10)
	body := io.LimitReader(res.Body, b.Size+1)
	for {
		n, rerr := body.Read(buf)
		if n > 0 {
			if _, err := w.Write(buf[:n]); err != nil {
				f.Close()
				return err
			}
			done += int64(n)
			if s.progress != nil {
				s.progress(done, b.Size)
			}
		}
		if rerr == io.EOF {
			break
		}
		if rerr != nil {
			f.Close()
			return fmt.Errorf("download: %w", rerr)
		}
	}
	if err := f.Close(); err != nil {
		return err
	}
	if done != b.Size {
		return fmt.Errorf("download size %d, expected %d; refused", done, b.Size)
	}
	if got := hex.EncodeToString(h.Sum(nil)); got != b.SHA256 {
		return fmt.Errorf("download SHA-256 %s does not match the pin %s; refused", got, b.SHA256)
	}
	return nil
}

// extract copies simc.exe (and the licence) out of the archive, checking simc.exe against its own pin.
func extract(archive, dir string, b SimcBuild) error {
	r, err := sevenzip.OpenReader(archive)
	if err != nil {
		return fmt.Errorf("open archive: %w", err)
	}
	defer r.Close()
	want := map[string]string{b.Exe: "simc.exe"}
	if b.License != "" {
		want[b.License] = "COPYING.txt"
	}
	found := false
	for _, f := range r.File {
		name, ok := want[f.Name]
		if !ok {
			continue
		}
		limit := int64(1 << 20)
		if name == "simc.exe" {
			limit = b.ExeSize
		}
		sum, n, err := copyOut(f, filepath.Join(dir, name), limit)
		if err != nil {
			return err
		}
		if name == "simc.exe" {
			if n != b.ExeSize || sum != b.ExeSHA256 {
				return fmt.Errorf("simc.exe in the archive does not match its pin (%d bytes, %s); refused", n, sum)
			}
			found = true
		}
	}
	if !found {
		return fmt.Errorf("%s is not in the archive", b.Exe)
	}
	return nil
}

func copyOut(f *sevenzip.File, dst string, limit int64) (string, int64, error) {
	rc, err := f.Open()
	if err != nil {
		return "", 0, err
	}
	defer rc.Close()
	out, err := os.Create(dst)
	if err != nil {
		return "", 0, err
	}
	h := sha256.New()
	n, err := io.Copy(io.MultiWriter(out, h), io.LimitReader(rc, limit+1))
	if cerr := out.Close(); err == nil {
		err = cerr
	}
	if err != nil {
		return "", n, err
	}
	if n > limit {
		return "", n, fmt.Errorf("%s is larger than expected; refused", f.Name)
	}
	return hex.EncodeToString(h.Sum(nil)), n, nil
}

// prune removes older SimulationCraft versions (only folders this app made under <data>/simc).
func (s *Simc) prune(keep string) {
	entries, _ := os.ReadDir(s.dir)
	for _, e := range entries {
		if e.IsDir() && e.Name() != keep && versionName.MatchString(strings.TrimSuffix(e.Name(), ".tmp")) {
			_ = os.RemoveAll(filepath.Join(s.dir, e.Name()))
		}
	}
}

// Remove deletes every downloaded SimulationCraft build.
func (s *Simc) Remove() error {
	if s.custom != "" {
		return nil
	}
	return os.RemoveAll(s.dir)
}
