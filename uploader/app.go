package main

import (
	"errors"
	"fmt"
	"os"
	"regexp"
	"sync"
	"time"
)

var installIDPattern = regexp.MustCompile(`^[0-9a-f]{16,64}$`)

// App is one uploader: config, state, and the scan -> upload cycle shared by --once and the background loop.
type App struct {
	mu        sync.Mutex
	cfg       Config
	cfgPath   string
	dataDir   string
	log       *Logger
	state     *State
	up        *Uploader
	extraWow  []string
	dryRun    bool
	retail    []string
	retailAt  time.Time
	done      map[string]time.Time // file -> mtime whose reports are all delivered
	holdUntil time.Time            // server asked us to wait (429 / 5xx / offline)
	status    string
	sims      *SimService // nil with --no-sim / --dry-run
}

// Summary of one cycle.
type Summary struct {
	Folders, Files, Reports, Pending, Accepted, Updated, Duplicates, Rejected, OptedOut int
	Err                                                                                 error
}

func (s Summary) String() string {
	out := fmt.Sprintf("%d WoW folder(s), %d file(s), %d report(s), %d new or grown -> accepted %d, updated %d, already there %d, rejected %d",
		s.Folders, s.Files, s.Reports, s.Pending, s.Accepted, s.Updated, s.Duplicates, s.Rejected)
	if s.OptedOut > 0 {
		out += fmt.Sprintf(", %d account(s) opted out", s.OptedOut)
	}
	return out
}

func NewApp(dataDir string, log *Logger, extraWow []string, endpoint, key string, dry bool) (*App, error) {
	cfg, path, err := LoadConfig(dataDir)
	if err != nil {
		return nil, err
	}
	if endpoint != "" {
		cfg.Endpoint = endpoint
	}
	if key != "" {
		cfg.IngestKey = key
	}
	if err := CheckEndpoint(cfg.Endpoint); err != nil {
		return nil, err
	}
	WriteTemplate(dataDir)
	return &App{cfg: cfg, cfgPath: path, dataDir: dataDir, log: log, state: LoadState(dataDir), up: NewUploader(cfg.Endpoint, cfg.IngestKey),
		extraWow: append(extraWow, cfg.WowPaths...), dryRun: dry, done: map[string]time.Time{}, status: "Starting"}, nil
}

func (a *App) Status() string     { a.mu.Lock(); defer a.mu.Unlock(); return a.status }
func (a *App) setStatus(s string) { a.mu.Lock(); a.status = s; a.mu.Unlock() }

func (a *App) folders(force bool) []string {
	if force || a.retail == nil || time.Since(a.retailAt) > 10*time.Minute {
		prev := len(a.retail)
		a.retail = DetectRetail(a.extraWow)
		a.retailAt = time.Now()
		if force || len(a.retail) != prev {
			if len(a.retail) == 0 {
				a.log.Printf("no World of Warcraft _retail_ folder found (add \"wowPaths\" to config.json or pass --wow)")
			}
			for _, r := range a.retail {
				a.log.Printf("watching %s", r)
			}
		}
	}
	return a.retail
}

// fatalHold is how long background mode waits after an error a retry cannot fix (Upload now still forces a try).
const fatalHold = 30 * time.Minute

// Cycle scans every account's Phoenix_UI.lua and sends what is new. force = ignore the "unchanged since" cache.
func (a *App) Cycle(force bool) Summary {
	var s Summary
	if !force && time.Now().Before(a.holdUntil) {
		return s
	}
	folders := a.folders(force)
	s.Folders = len(folders)
	for _, r := range folders {
		for _, f := range SavedVariablesFiles(r) {
			s.Files++
			st, err := os.Stat(f)
			if err != nil {
				continue
			}
			if !force && a.done[f].Equal(st.ModTime()) {
				continue
			}
			ok := a.file(f, &s)
			if ok {
				a.done[f] = st.ModTime()
			}
			if s.Err != nil {
				var re *RetryError
				var fe *FatalError
				if errors.As(s.Err, &re) {
					a.holdUntil = time.Now().Add(re.After)
				} else if errors.As(s.Err, &fe) {
					a.holdUntil = time.Now().Add(fatalHold) // e.g. a refused key: no point asking every minute
				}
				break
			}
		}
	}
	if err := a.state.Save(); err != nil {
		a.log.Printf("could not save state: %v", err)
	}
	switch {
	case s.Err != nil:
		a.setStatus("Waiting: " + s.Err.Error())
	case s.Pending > 0:
		a.setStatus(fmt.Sprintf("Sent %d report(s) at %s", s.Accepted+s.Updated, time.Now().Format("15:04")))
	case a.status == "Starting":
		a.setStatus("Up to date")
	}
	return s
}

// file handles one SavedVariables file; true when everything in it is delivered.
func (a *App) file(path string, s *Summary) bool {
	db, err := ReadBugsDB(path)
	if err != nil {
		a.log.Printf("skipping %s: %v", path, err)
		return true // a file WoW is half-way through writing parses next time; nothing to retry until it changes
	}
	if db == nil {
		return true
	}
	if db.Schema != schema {
		a.log.Printf("skipping %s: PhoenixUIBugsDB schema %d (this uploader speaks %d - update it)", path, db.Schema, schema)
		return true
	}
	if !installIDPattern.MatchString(db.InstallID) {
		a.log.Printf("skipping %s: no valid installId yet", path)
		return true
	}
	s.Reports += len(db.Reports)
	if !db.Share {
		// The player turned "Send error reports to the author" off. What was caught meanwhile is marked as handled
		// so that switching it back on later sends only reports that are new from then on.
		if p := a.state.Pending(db.Reports); len(p) > 0 && !a.dryRun { // --dry-run changes nothing
			a.state.MarkSkipped(p)
		}
		s.OptedOut++
		a.log.Printf("skipping %s (account %s): \"Send error reports to the author\" is off in Phoenix UI", path, db.Account)
		return true
	}
	pending := a.state.Pending(db.Reports)
	s.Pending += len(pending)
	if len(pending) == 0 {
		return true
	}
	a.log.Printf("%s (account %s): %d of %d report(s) to send", path, db.Account, len(pending), len(db.Reports))
	if a.dryRun {
		for _, r := range pending {
			a.log.Printf("  would send %s  [%s] %s  x%d", r.ID, r.Kind, firstLine(r.Message), r.Count)
		}
		return false
	}
	if a.cfg.Disabled {
		a.log.Printf("uploading is disabled in config.json")
		return false
	}
	if a.cfg.IngestKey == "" {
		s.Err = &FatalError{errors.New("no ingest key configured (config.json \"ingestKey\")")}
		a.log.Printf("%v", s.Err)
		return false
	}
	scrub := NewScrubber(path)
	for i := range pending {
		pending[i] = scrub.Report(pending[i])
	}
	for _, b := range Batches(pending) {
		res, err := a.up.Send(db.InstallID, b)
		if err != nil {
			s.Err = err
			a.log.Printf("upload failed: %v", err)
			return false
		}
		a.state.MarkSent(b)
		s.Accepted += res.Accepted
		s.Updated += res.Updated
		s.Duplicates += res.Duplicates
		s.Rejected += len(res.Rejected)
		for _, rj := range res.Rejected {
			a.log.Printf("  server rejected %s: %s", rj.ID, rj.Reason)
		}
		a.log.Printf("  sent %d: accepted %d, updated %d, already there %d, rejected %d", len(b), res.Accepted, res.Updated, res.Duplicates, len(res.Rejected))
	}
	return true
}

func firstLine(s string) string {
	for i, c := range s {
		if c == '\n' {
			s = s[:i]
			break
		}
	}
	if len(s) > 110 {
		s = s[:110] + "…"
	}
	return s
}

// Loop runs until stop is closed: a cycle every ScanSeconds, or at once when kick fires.
func (a *App) Loop(stop <-chan struct{}, kick <-chan struct{}) {
	a.log.Printf("Phoenix Uploader %s running in the background (every %ds, endpoint %s)", version, a.cfg.ScanSeconds, a.cfg.Endpoint)
	if a.cfgPath != "" {
		a.log.Printf("config: %s", a.cfgPath)
	}
	t := time.NewTicker(time.Duration(a.cfg.ScanSeconds) * time.Second)
	defer t.Stop()
	// Sim requests are a time stamp check every few seconds, so a /reload is answered quickly.
	simTick := time.NewTicker(simScanEvery)
	defer simTick.Stop()
	if a.sims != nil {
		go a.sims.Worker(stop)
	}
	a.report(a.Cycle(true))
	a.scanSims(true)
	for {
		select {
		case <-stop:
			a.sims.Cancel()
			a.log.Printf("stopped")
			return
		case <-kick:
			a.holdUntil = time.Time{}
			a.report(a.Cycle(true))
			a.scanSims(true)
		case <-t.C:
			a.report(a.Cycle(false))
		case <-simTick.C:
			a.scanSims(false)
		}
	}
}

const simScanEvery = 5 * time.Second

func (a *App) scanSims(force bool) {
	if a.sims != nil {
		a.sims.Enqueue(a.sims.Scan(a.folders(false), force))
	}
}

// RunSimsOnce answers every open sim request now (--once); returns how many ran.
func (a *App) RunSimsOnce() int {
	if a.sims == nil {
		return 0
	}
	n := 0
	for _, q := range a.sims.Scan(a.folders(false), true) {
		res := a.sims.Run(q)
		a.log.Printf("sim %s: %s %s", q.ID, res.State, res.Error)
		n++
	}
	return n
}

func (a *App) report(s Summary) {
	if s.Pending > 0 || s.Err != nil {
		a.log.Printf("%s", s)
	}
}
