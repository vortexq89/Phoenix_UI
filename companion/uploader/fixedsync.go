package main

import (
	"crypto/ed25519"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"hash/adler32"
	"io"
	"net/http"
	"os"
	"regexp"
	"strings"
	"time"
)

// Fixed-in sync (docs/FIXED_SYNC.md): the dashboard publishes a signed list of fixed errors at /phoenix/api/fixed.
// The uploader fetches it, checks the Ed25519 signature against the public key below, and writes it into each
// account's Phoenix_UI_Sentinel.lua as PhoenixUISentinelFixed, only while the game is closed (the client rewrites
// SavedVariables at logout and would drop an edit made while it runs). The write goes to a staged file that is then
// swapped in, with the previous file kept as Phoenix_UI_Sentinel.lua.phoenix-bak. At load Sentinel checks the
// list's checksum, marks those errors "Fixed in <version>" and clears the variable.

// fixedPublicKey is the server's Ed25519 public key (raw, base64). The private half is the Worker secret
// PHOENIX_FIXED_SIGNING_KEY and never leaves Cloudflare.
const fixedPublicKey = "zwWe8DZfMh+w/CRScS/h1INplXcR2K2RYJFwD5WOTJQ="
const fixedVariable = "PhoenixUISentinelFixed"
const fixedEvery = 30 * time.Minute
const fixedMax = 500

var (
	fixedHash = regexp.MustCompile(`^[0-9a-f]{8,64}$`)
	fixedVer  = regexp.MustCompile(`^[A-Za-z0-9.\-]{1,32}$`)
	fixedLine = regexp.MustCompile(`(?m)^PhoenixUISentinelFixed = .*\r?\n?`)
)

// FixedRow is one fixed error.
type FixedRow struct {
	Hash    string `json:"hash"`
	FixedIn string `json:"fixedIn"`
}

type fixedEnvelope struct {
	Alg     string `json:"alg"`
	KeyID   string `json:"keyId"`
	Payload string `json:"payload"`
	Sig     string `json:"sig"`
}

type fixedPayload struct {
	V           int        `json:"v"`
	Kind        string     `json:"kind"`
	GeneratedAt int64      `json:"generatedAt"`
	Fixed       []FixedRow `json:"fixed"`
}

// FixedURL is the list's address on the same site as the ingest endpoint.
func FixedURL(endpoint string) string {
	if i := strings.Index(endpoint, "/phoenix/api/"); i >= 0 {
		return endpoint[:i] + "/phoenix/api/fixed"
	}
	return ""
}

// VerifyFixed checks the envelope against key and returns the valid rows (bad rows are dropped, never trusted).
func VerifyFixed(raw []byte, key ed25519.PublicKey) ([]FixedRow, error) {
	var env fixedEnvelope
	if err := json.Unmarshal(raw, &env); err != nil {
		return nil, fmt.Errorf("fixed list: %w", err)
	}
	if env.Alg != "ed25519" {
		return nil, errors.New("fixed list: unknown signature algorithm")
	}
	sig, err := base64.StdEncoding.DecodeString(env.Sig)
	if err != nil || len(key) != ed25519.PublicKeySize || !ed25519.Verify(key, []byte(env.Payload), sig) {
		return nil, errors.New("fixed list: signature does not match")
	}
	var p fixedPayload
	if err := json.Unmarshal([]byte(env.Payload), &p); err != nil || p.Kind != "fixed-in" || p.V != 1 {
		return nil, errors.New("fixed list: unknown payload")
	}
	var out []FixedRow
	seen := map[string]bool{}
	for _, r := range p.Fixed {
		h := strings.ToLower(r.Hash)
		if fixedHash.MatchString(h) && fixedVer.MatchString(r.FixedIn) && !seen[h] && len(out) < fixedMax {
			seen[h] = true
			out = append(out, FixedRow{h, r.FixedIn})
		}
	}
	return out, nil
}

func publicKey() ed25519.PublicKey {
	b, _ := base64.StdEncoding.DecodeString(fixedPublicKey)
	return ed25519.PublicKey(b)
}

// FetchFixed downloads and verifies the list.
func FetchFixed(url string) ([]FixedRow, error) {
	c := &http.Client{Timeout: 20 * time.Second}
	req, _ := http.NewRequest("GET", url, nil)
	req.Header.Set("User-Agent", "PhoenixUploader/"+version)
	res, err := c.Do(req)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()
	if res.StatusCode != 200 {
		return nil, fmt.Errorf("fixed list: HTTP %d", res.StatusCode)
	}
	raw, err := io.ReadAll(io.LimitReader(res.Body, 256<<10))
	if err != nil {
		return nil, err
	}
	return VerifyFixed(raw, publicKey())
}

// FixedSum is the checksum Sentinel recomputes: Adler-32 over "hash=version;" for every row in order.
func FixedSum(rows []FixedRow) uint32 {
	var b strings.Builder
	for _, r := range rows {
		b.WriteString(r.Hash + "=" + r.FixedIn + ";")
	}
	return adler32.Checksum([]byte(b.String()))
}

// FixedLua is the one-line SavedVariables assignment.
func FixedLua(rows []FixedRow, at int64) string {
	var b strings.Builder
	fmt.Fprintf(&b, "%s = {[\"kind\"]=\"fixed-in\",[\"at\"]=%d,[\"sum\"]=%d,[\"fixed\"]={", fixedVariable, at, FixedSum(rows))
	for _, r := range rows {
		fmt.Fprintf(&b, "{[\"hash\"]=%q,[\"fixedIn\"]=%q},", r.Hash, r.FixedIn)
	}
	b.WriteString("}}\n")
	return b.String()
}

// WriteFixed puts the list into one Sentinel SavedVariables file. false when it was already there.
func WriteFixed(path string, rows []FixedRow, at int64) (bool, error) {
	old, err := os.ReadFile(path)
	if err != nil {
		return false, err
	}
	sumTag := fmt.Sprintf("[\"sum\"]=%d,", FixedSum(rows))
	if m := fixedLine.Find(old); m != nil && strings.Contains(string(m), sumTag) {
		return false, nil
	}
	body := fixedLine.ReplaceAll(old, nil)
	if len(body) > 0 && body[len(body)-1] != '\n' {
		body = append(body, '\n')
	}
	body = append(body, []byte(FixedLua(rows, at))...)
	tmp := path + ".phoenix-tmp"
	if err := os.WriteFile(tmp, body, 0o644); err != nil {
		return false, err
	}
	if err := os.WriteFile(path+".phoenix-bak", old, 0o644); err != nil {
		os.Remove(tmp)
		return false, err
	}
	if err := os.Rename(tmp, path); err != nil {
		os.Remove(tmp)
		return false, err
	}
	return true, nil
}

// syncFixed runs at most every fixedEvery: fetch, verify, and write into every Sentinel file while WoW is closed.
func (a *App) syncFixed(folders []string, force bool) {
	if a.dryRun || a.cfg.Disabled || (!force && time.Since(a.fixedAt) < fixedEvery) {
		return
	}
	if wowRunning() {
		return // try again next cycle; the game would overwrite the file
	}
	url := FixedURL(a.cfg.Endpoint)
	if url == "" {
		return
	}
	a.fixedAt = time.Now()
	rows, err := FetchFixed(url)
	if err != nil {
		a.log.Printf("fixed list not updated: %v", err)
		return
	}
	if len(rows) == 0 {
		return
	}
	for _, r := range folders {
		for _, f := range SentinelFiles(r) {
			if wowRunning() {
				return
			}
			wrote, err := WriteFixed(f, rows, time.Now().Unix())
			if err != nil {
				a.log.Printf("could not write the fixed list to %s: %v", f, err)
			} else if wrote {
				a.log.Printf("fixed list (%d errors) written to %s", len(rows), f)
				if st, err := os.Stat(f); err == nil {
					a.done[f] = st.ModTime()
				}
			}
		}
	}
}

// isWowExe: a World of Warcraft client executable name.
func isWowExe(name string) bool {
	n := strings.ToLower(name)
	return strings.HasPrefix(n, "wow") && (strings.HasSuffix(n, ".exe") || n == "wow")
}
