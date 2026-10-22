package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"sync"
	"time"
)

// State remembers which reports were delivered (and at what count), so only new or grown ones are sent again.
// It lives in the data folder as state.json and is written atomically.
type State struct {
	mu         sync.Mutex
	path       string
	Version    int                  `json:"version"`
	Sent       map[string]SentEntry `json:"sent"`
	LastUpload int64                `json:"lastUpload"`
	LastError  string               `json:"lastError,omitempty"`
	Startup    bool                 `json:"startupOffered"`
}

// SentEntry is one delivered report: its count when sent, and when we last saw it in a file.
type SentEntry struct {
	Count int64 `json:"c"`
	Seen  int64 `json:"t"`
}

const stateKeepDays = 180

func LoadState(dir string) *State {
	s := &State{path: filepath.Join(dir, "state.json"), Version: 1, Sent: map[string]SentEntry{}}
	if b, err := os.ReadFile(s.path); err == nil {
		_ = json.Unmarshal(b, s)
		if s.Sent == nil {
			s.Sent = map[string]SentEntry{}
		}
	}
	return s
}

// Pending returns the reports that are new or have a higher count than when they were sent.
func (s *State) Pending(rs []Report) []Report {
	s.mu.Lock()
	defer s.mu.Unlock()
	now := time.Now().Unix()
	var out []Report
	for _, r := range rs {
		e, ok := s.Sent[r.ID]
		if ok {
			e.Seen = now
			s.Sent[r.ID] = e
		}
		if !ok || r.Count > e.Count {
			out = append(out, r)
		}
	}
	return out
}

func (s *State) MarkSent(rs []Report) {
	s.mu.Lock()
	defer s.mu.Unlock()
	now := time.Now().Unix()
	for _, r := range rs {
		s.Sent[r.ID] = SentEntry{Count: r.Count, Seen: now}
	}
	s.LastUpload = now
}

// MarkSkipped records reports as handled without sending them (the account opted out).
func (s *State) MarkSkipped(rs []Report) {
	s.mu.Lock()
	defer s.mu.Unlock()
	now := time.Now().Unix()
	for _, r := range rs {
		s.Sent[r.ID] = SentEntry{Count: r.Count, Seen: now}
	}
}

func (s *State) Save() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	cut := time.Now().Add(-stateKeepDays * 24 * time.Hour).Unix()
	for id, e := range s.Sent {
		if e.Seen < cut {
			delete(s.Sent, id)
		}
	}
	b, err := json.MarshalIndent(s, "", " ")
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(s.path), 0o755); err != nil {
		return err
	}
	tmp := s.path + ".tmp"
	if err := os.WriteFile(tmp, b, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, s.path)
}
