package main

import (
	"fmt"
	"math"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// Report is one entry of PhoenixUIBugsDB.reports, in the shape the website expects (contract v1).
type Report struct {
	ID           string `json:"id"`
	Hash         string `json:"hash"`
	Kind         string `json:"kind"`
	Message      string `json:"message"`
	Stack        string `json:"stack"`
	Locals       string `json:"locals"`
	Count        int64  `json:"count"`
	FirstSeen    int64  `json:"firstSeen"`
	LastSeen     int64  `json:"lastSeen"`
	Session      int64  `json:"session"`
	AddonVersion string `json:"addonVersion"`
	Interface    int64  `json:"interface"`
	Build        string `json:"build"`
	Locale       string `json:"locale"`
	Source       string `json:"source"`
}

// BugsDB is what one account's SavedVariables file holds.
type BugsDB struct {
	File      string
	Account   string
	Schema    int64
	InstallID string
	Share     bool // "Send error reports to the author" in the addon; only an explicit false turns it off
	Reports   []Report
	Skipped   int // entries that were not usable reports
}

const savedVariable = "PhoenixUIBugsDB"

// SavedVariablesFiles lists every account's Phoenix_UI.lua under a _retail_ folder.
func SavedVariablesFiles(retail string) []string {
	m, _ := filepath.Glob(filepath.Join(retail, "WTF", "Account", "*", "SavedVariables", "Phoenix_UI.lua"))
	sort.Strings(m)
	return m
}

func str(t *Table, k string) string {
	if v, ok := t.Get(k); ok {
		switch x := v.(type) {
		case string:
			return x
		case float64:
			return fmt.Sprint(int64(x))
		}
	}
	return ""
}

func integer(t *Table, k string) int64 {
	if v, ok := t.Get(k); ok {
		switch x := v.(type) {
		case float64:
			if !math.IsNaN(x) && !math.IsInf(x, 0) {
				return int64(x)
			}
		case string:
			var n int64
			if _, err := fmt.Sscan(x, &n); err == nil {
				return n
			}
		}
	}
	return 0
}

// ReadBugsDB parses one SavedVariables file. A file without PhoenixUIBugsDB (the error catcher never ran on that
// account) is not an error: it returns nil, nil.
func ReadBugsDB(path string) (*BugsDB, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	vars, err := ParseSavedVariables(string(b))
	if err != nil {
		return nil, fmt.Errorf("%s: %w", path, err)
	}
	root, ok := vars[savedVariable].(*Table)
	if !ok {
		return nil, nil
	}
	db := &BugsDB{File: path, Account: filepath.Base(filepath.Dir(filepath.Dir(path))), Schema: integer(root, "schema"), InstallID: strings.ToLower(str(root, "installId")), Share: true}
	if v, ok := root.Get("share"); ok {
		if b, isBool := v.(bool); isBool && !b {
			db.Share = false
		}
	}
	rv, _ := root.Get("reports")
	rt, _ := rv.(*Table)
	for _, e := range rt.List() {
		t, ok := e.(*Table)
		if !ok {
			db.Skipped++
			continue
		}
		r := Report{
			ID: str(t, "id"), Hash: str(t, "hash"), Kind: str(t, "kind"), Message: str(t, "message"),
			Stack: str(t, "stack"), Locals: str(t, "locals"), Count: integer(t, "count"),
			FirstSeen: integer(t, "firstSeen"), LastSeen: integer(t, "lastSeen"), Session: integer(t, "session"),
			AddonVersion: str(t, "addonVersion"), Interface: integer(t, "interface"), Build: str(t, "build"),
			Locale: str(t, "locale"), Source: str(t, "source"),
		}
		if r.ID == "" || r.Hash == "" || r.Message == "" {
			db.Skipped++
			continue
		}
		if r.Count < 1 {
			r.Count = 1
		}
		db.Reports = append(db.Reports, r)
	}
	return db, nil
}
