package main

// The sim service: notices new requests in the SavedVariables (a cheap time stamp check every few seconds),
// asks before SimulationCraft is downloaded, runs one sim at a time at below-normal priority, and writes the
// result where the game reads it.

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"sort"
	"strings"
	"sync"
	"time"
)

const (
	simTimeout   = 15 * time.Minute
	simStaleDays = 2 // requests older than this are left alone (the player has moved on)
	simKeepRuns  = 10
)

// ConsentAsker shows the download question; true = the player agreed. ok=false when it cannot ask at all.
type ConsentAsker func(b SimcBuild, char string, dir string) (yes bool, ok bool)

// Notifier tells the player a sim finished; report is the HTML report to offer.
type Notifier func(title, text, report string)

type SimService struct {
	mu       sync.Mutex
	app      *App
	simc     *Simc
	dir      string
	threads  int
	allow    bool // --allow-simc-download: consent given on the command line
	ask      ConsentAsker
	notify   Notifier
	seen     map[string]time.Time
	queued   map[string]bool
	queue    chan SimRequest
	cancel   context.CancelFunc
	status   string
	report   string
	runSimc  func(ctx context.Context, exe, dir string, args []string) ([]byte, error)
	disabled bool
	have     bool // SimulationCraft ready (refreshed by the worker; the tray reads it without touching the network)
}

// HaveSimc is the last known install state.
func (s *SimService) HaveSimc() bool { s.mu.Lock(); defer s.mu.Unlock(); return s.have }

func (s *SimService) refreshHave() {
	h := s.simc.Installed()
	s.mu.Lock()
	s.have = h
	s.mu.Unlock()
}

func NewSimService(a *App, allow bool) *SimService {
	threads := a.cfg.SimThreads
	if threads <= 0 {
		threads = runtime.NumCPU() - 2
	}
	if threads < 1 {
		threads = 1
	}
	s := &SimService{app: a, simc: NewSimc(a.dataDir, a.cfg.SimcManifest, a.cfg.SimcPath, a.log), dir: filepath.Join(a.dataDir, "sims"),
		threads: threads, allow: allow, ask: askConsent, notify: notifySim, seen: map[string]time.Time{}, queued: map[string]bool{},
		queue: make(chan SimRequest, 32), runSimc: runProcess, disabled: a.cfg.SimDisabled, status: "Sim: idle"}
	if !boolDefault(a.cfg.SimNotify, true) {
		s.notify = func(string, string, string) {}
	}
	s.simc.progress = func(done, total int64) {
		if total > 0 {
			s.setStatus(fmt.Sprintf("Sim: downloading SimulationCraft %d%%", done*100/total))
		}
	}
	return s
}

func (s *SimService) Status() string     { s.mu.Lock(); defer s.mu.Unlock(); return s.status }
func (s *SimService) setStatus(t string) { s.mu.Lock(); s.status = t; s.mu.Unlock() }
func (s *SimService) Report() string     { s.mu.Lock(); defer s.mu.Unlock(); return s.report }
func (s *SimService) Busy() bool         { s.mu.Lock(); defer s.mu.Unlock(); return s.cancel != nil }

// Cancel stops the running sim (or download).
func (s *SimService) Cancel() {
	if s == nil {
		return
	}
	s.mu.Lock()
	c := s.cancel
	s.mu.Unlock()
	if c != nil {
		c()
	}
}

// Scan finds new requests in the retail folders' SavedVariables; force re-reads unchanged files.
func (s *SimService) Scan(retails []string, force bool) []SimRequest {
	if s.disabled {
		return nil
	}
	var found []SimRequest
	cut := time.Now().Add(-simStaleDays * 24 * time.Hour).Unix()
	for _, r := range retails {
		for _, f := range SavedVariablesFiles(r) {
			st, err := os.Stat(f)
			if err != nil {
				continue
			}
			if !force && s.seen[f].Equal(st.ModTime()) {
				continue
			}
			reqs, bad, err := ReadSimRequests(f, r)
			if err != nil {
				s.app.log.Printf("sim: skipping %s: %v", f, err)
				s.seen[f] = st.ModTime()
				continue
			}
			s.seen[f] = st.ModTime()
			for _, e := range bad {
				s.app.log.Printf("sim: %s: %v", f, e)
			}
			for _, q := range reqs {
				s.mu.Lock()
				busy := s.queued[q.ID]
				s.mu.Unlock()
				if busy || s.app.state.SimDone(q.ID) || q.Created < cut {
					continue
				}
				found = append(found, q)
			}
		}
	}
	return found
}

// Enqueue hands requests to the background worker.
func (s *SimService) Enqueue(reqs []SimRequest) {
	for _, q := range reqs {
		s.mu.Lock()
		s.queued[q.ID] = true
		s.mu.Unlock()
		select {
		case s.queue <- q:
			s.app.log.Printf("sim: request %s (%s, %s) queued", q.ID, q.Mode, q.Char)
		default:
			s.mu.Lock()
			delete(s.queued, q.ID)
			s.mu.Unlock()
		}
	}
}

// Worker runs queued requests one by one until stop closes.
func (s *SimService) Worker(stop <-chan struct{}) {
	s.refreshHave()
	for {
		select {
		case <-stop:
			return
		case q := <-s.queue:
			s.Run(q)
		}
	}
}

// Run handles one request end to end and always leaves a result for the game.
func (s *SimService) Run(q SimRequest) SimResult {
	ctx, cancel := context.WithTimeout(context.Background(), simTimeout)
	s.mu.Lock()
	s.cancel = cancel
	s.mu.Unlock()
	defer func() {
		cancel()
		s.mu.Lock()
		s.cancel = nil
		s.mu.Unlock()
	}()
	res := s.run(ctx, q)
	s.refreshHave()
	res.ID, res.Mode, res.Char, res.Fight = q.ID, q.Mode, q.Char, q.Fight
	if res.Finished == 0 {
		res.Finished = time.Now().Unix()
	}
	if path, err := WriteResult(q.Retail, res, time.Now()); err != nil {
		s.app.log.Printf("sim: could not write the result of %s: %v", q.ID, err)
	} else {
		s.app.log.Printf("sim: %s %s -> %s", q.ID, res.State, path)
	}
	if res.State != "waiting" {
		s.app.state.MarkSimDone(q.ID)
		_ = s.app.state.Save()
	}
	s.mu.Lock()
	delete(s.queued, q.ID)
	s.mu.Unlock()
	return res
}

func (s *SimService) run(ctx context.Context, q SimRequest) SimResult {
	fail := func(state, msg string) SimResult {
		s.setStatus("Sim: " + msg)
		return SimResult{State: state, Error: msg}
	}
	if !s.simc.Installed() {
		switch s.consent(q) {
		case "no":
			return fail("declined", "SimulationCraft download declined in the Phoenix app (tray menu > Download SimulationCraft to allow it)")
		case "ask":
			return fail("waiting", "SimulationCraft is not installed yet: allow the download in the Phoenix app")
		}
		s.setStatus("Sim: downloading SimulationCraft")
		if err := s.simc.Install(ctx); err != nil {
			s.app.log.Printf("simc: %v", err)
			return fail("failed", "SimulationCraft download failed: "+err.Error())
		}
	}
	exe, ok := s.simc.Exe()
	if !ok {
		return fail("failed", "SimulationCraft did not pass its check after the download")
	}
	plan, err := BuildPlan(q)
	if err != nil {
		return fail("failed", err.Error())
	}
	run := filepath.Join(s.dir, q.ID)
	_ = os.RemoveAll(run)
	if err := os.MkdirAll(run, 0o755); err != nil {
		return fail("failed", err.Error())
	}
	if err := os.WriteFile(filepath.Join(run, "input.simc"), []byte(plan.Input), 0o644); err != nil {
		return fail("failed", err.Error())
	}
	s.setStatus(fmt.Sprintf("Sim: running %s (%s)", q.Mode, q.Char))
	start := time.Now()
	out, err := s.runSimc(ctx, exe, run, []string{"input.simc", "json2=report.json", "html=report.html", fmt.Sprintf("threads=%d", s.threads)})
	_ = os.WriteFile(filepath.Join(run, "simc.log"), out, 0o644)
	if ctx.Err() != nil {
		if errors.Is(ctx.Err(), context.DeadlineExceeded) {
			return fail("failed", "the sim took longer than 15 minutes and was stopped")
		}
		return fail("failed", "the sim was cancelled in the Phoenix app")
	}
	if err != nil {
		return fail("failed", simcError(out, err))
	}
	res, err := ReadReport(filepath.Join(run, "report.json"), q, plan)
	if err != nil {
		return fail("failed", err.Error())
	}
	res.Seconds = time.Since(start).Seconds()
	res.Finished = time.Now().Unix()
	report := filepath.Join(run, "report.html")
	s.mu.Lock()
	s.report = report
	s.mu.Unlock()
	summary := Summarise(res)
	s.setStatus("Sim done: " + summary)
	s.app.log.Printf("sim: %s done in %.1fs: %s", q.ID, res.Seconds, summary)
	s.notify("Phoenix UI sim finished", summary+"\n\nType /reload in game to see it on the Sim page and on item tooltips.", report)
	s.prune()
	return res
}

// consent returns "yes", "no" or "ask" (could not ask), asking the player when needed.
func (s *SimService) consent(q SimRequest) string {
	b := s.simc.Build()
	st := s.app.state
	if s.allow {
		st.SetSimConsent("yes", b.Version)
		_ = st.Save()
		return "yes"
	}
	answer, ver := st.SimConsent()
	if answer == "yes" && ver == b.Version {
		return "yes"
	}
	if answer == "no" {
		return "no"
	}
	yes, ok := s.ask(b, q.Char, s.simc.dir)
	if !ok {
		return "ask"
	}
	if yes {
		st.SetSimConsent("yes", b.Version)
		s.app.log.Printf("simc: the player allowed the download of SimulationCraft %s", b.Version)
	} else {
		st.SetSimConsent("no", b.Version)
		s.app.log.Printf("simc: the player declined the SimulationCraft download")
	}
	_ = st.Save()
	if yes {
		return "yes"
	}
	return "no"
}

// AllowDownload is the tray's "Download SimulationCraft": asks again, then installs in the background.
func (s *SimService) AllowDownload() {
	if s.Busy() {
		return
	}
	b := s.simc.Build()
	yes, ok := s.ask(b, "", s.simc.dir)
	if !ok || !yes {
		return
	}
	s.app.state.SetSimConsent("yes", b.Version)
	_ = s.app.state.Save()
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), simTimeout)
		s.mu.Lock()
		s.cancel = cancel
		s.mu.Unlock()
		defer func() { cancel(); s.mu.Lock(); s.cancel = nil; s.mu.Unlock() }()
		err := s.simc.Install(ctx)
		s.refreshHave()
		if err != nil {
			s.app.log.Printf("simc: %v", err)
			s.setStatus("Sim: SimulationCraft download failed")
			return
		}
		s.setStatus("Sim: SimulationCraft ready")
	}()
}

// RemoveSimc deletes the download and forgets the consent.
func (s *SimService) RemoveSimc() error {
	if s.Busy() {
		return errors.New("a sim is running")
	}
	s.app.state.SetSimConsent("", "")
	_ = s.app.state.Save()
	s.setStatus("Sim: SimulationCraft removed")
	err := s.simc.Remove()
	s.refreshHave()
	return err
}

var simcPathLike = regexp.MustCompile(`(?i)[a-z]:\\[^\s'"]+|/[^\s'"]+/`)

// simcError keeps SimC's own error line (without local paths) for the game.
func simcError(out []byte, err error) string {
	for _, l := range strings.Split(string(out), "\n") {
		l = strings.TrimSpace(l)
		if strings.HasPrefix(l, "Error") || strings.Contains(l, "error:") {
			return clipErr(simcPathLike.ReplaceAllString(l, ""))
		}
	}
	return clipErr("SimulationCraft stopped: " + err.Error())
}

func clipErr(s string) string {
	if len(s) > 240 {
		return s[:240] + "…"
	}
	return s
}

// Summarise is the one-line outcome shown in the tray, the notification and the log.
func Summarise(r SimResult) string {
	out := fmt.Sprintf("%s %s DPS", strings.TrimSpace(r.Char), groupDigits(r.DPS))
	if len(r.Sets) > 0 {
		b := r.Sets[0]
		out += fmt.Sprintf("; best: %s %+.1f%%", b.Label, b.Pct)
	}
	if len(r.Weights) > 0 {
		out += "; stat weights ready"
	}
	return out
}

func groupDigits(f float64) string {
	s := fmt.Sprintf("%.0f", f)
	var b strings.Builder
	for i, c := range s {
		if i > 0 && (len(s)-i)%3 == 0 {
			b.WriteByte(',')
		}
		b.WriteRune(c)
	}
	return b.String()
}

// prune keeps the newest simKeepRuns run folders.
func (s *SimService) prune() {
	entries, _ := os.ReadDir(s.dir)
	type run struct {
		name string
		at   time.Time
	}
	var runs []run
	for _, e := range entries {
		if info, err := e.Info(); err == nil && e.IsDir() && reqID.MatchString(e.Name()) {
			runs = append(runs, run{e.Name(), info.ModTime()})
		}
	}
	sort.Slice(runs, func(a, b int) bool { return runs[a].at.After(runs[b].at) })
	for i := simKeepRuns; i < len(runs); i++ {
		_ = os.RemoveAll(filepath.Join(s.dir, runs[i].name))
	}
}

// runProcess starts SimC hidden and at below-normal priority, so the game keeps its frame rate.
func runProcess(ctx context.Context, exe, dir string, args []string) ([]byte, error) {
	cmd := exec.CommandContext(ctx, exe, args...)
	cmd.Dir = dir
	quietProcess(cmd)
	var buf limitedBuffer
	cmd.Stdout, cmd.Stderr = &buf, &buf
	err := cmd.Run()
	return buf.Bytes(), err
}

// limitedBuffer keeps the last 256 KB of SimC's console output.
type limitedBuffer struct{ b []byte }

func (l *limitedBuffer) Write(p []byte) (int, error) {
	l.b = append(l.b, p...)
	if len(l.b) > 256<<10 {
		l.b = l.b[len(l.b)-256<<10:]
	}
	return len(p), nil
}
func (l *limitedBuffer) Bytes() []byte { return l.b }
