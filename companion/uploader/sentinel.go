package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
)

// Sentinel (Phoenix UI 2.x, contract v2): Phoenix_UI_Sentinel.lua holds PhoenixUISentinelDB. When the player has
// "Auto-upload via Companion" on (optIn), the game writes db.outbox at logout / reload: the exact payload the in-game
// Preview shows, privacy filters already applied. The uploader sends that payload as-is (schema 2), only the reports it
// has not sent yet (same state.json bookkeeping as v1), with its game flavor, session and installed addon list.

const sentinelVariable = "PhoenixUISentinelDB"

// SentinelDB is one account's Sentinel outbox.
type SentinelDB struct {
	File, Account, InstallID string
	OptIn                    bool
	Flavor                   string
	Session                  int64
	Addons                   []any
	Reports                  []map[string]any
}

// SentinelFiles lists every account's Phoenix_UI_Sentinel.lua in this client folder and its sibling client folders
// (_retail_, and WoW Forever's own folder next to it), so both games are covered.
func SentinelFiles(client string) []string {
	seen := map[string]bool{}
	var out []string
	add := func(dir string) {
		m, _ := filepath.Glob(filepath.Join(dir, "WTF", "Account", "*", "SavedVariables", "Phoenix_UI_Sentinel.lua"))
		for _, f := range m {
			if !seen[strings.ToLower(f)] {
				seen[strings.ToLower(f)] = true
				out = append(out, f)
			}
		}
	}
	add(client)
	if sib, _ := filepath.Glob(filepath.Join(filepath.Dir(client), "_*_")); sib != nil {
		for _, d := range sib {
			add(d)
		}
	}
	sort.Strings(out)
	return out
}

// plain turns a parsed Lua value into JSON-ready Go values (tables with only an array part become lists).
func plain(v any) any {
	t, ok := v.(*Table)
	if !ok {
		return v
	}
	if len(t.Hash) == 0 || (len(t.Array) > 0 && allInts(t)) {
		l := t.List()
		out := make([]any, len(l))
		for i, x := range l {
			out[i] = plain(x)
		}
		return out
	}
	out := map[string]any{}
	for i, x := range t.Array {
		out[strconv.Itoa(i+1)] = plain(x)
	}
	for k, x := range t.Hash {
		out[k] = plain(x)
	}
	return out
}

func allInts(t *Table) bool {
	for k := range t.Hash {
		if _, err := strconv.Atoi(k); err != nil {
			return false
		}
	}
	return true
}

func listOf(v any) []any {
	switch x := plain(v).(type) {
	case []any:
		return x
	case map[string]any:
		if len(x) == 0 {
			return nil
		}
	}
	return nil
}

// ReadSentinel parses one Phoenix_UI_Sentinel.lua. nil, nil when the file has no Sentinel data.
func ReadSentinel(path string) (*SentinelDB, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	vars, err := ParseSavedVariables(string(b))
	if err != nil {
		return nil, fmt.Errorf("%s: %w", path, err)
	}
	root, ok := vars[sentinelVariable].(*Table)
	if !ok {
		return nil, nil
	}
	db := &SentinelDB{File: path, Account: filepath.Base(filepath.Dir(filepath.Dir(path))), InstallID: strings.ToLower(str(root, "installId"))}
	if v, ok := root.Get("optIn"); ok {
		db.OptIn, _ = v.(bool)
	}
	ov, _ := root.Get("outbox")
	ob, _ := ov.(*Table)
	if ob == nil {
		return db, nil
	}
	db.Flavor = str(ob, "flavor")
	db.Session = integer(ob, "session")
	if v, ok := ob.Get("addons"); ok {
		db.Addons = listOf(v)
	}
	if v, ok := ob.Get("reports"); ok {
		for _, r := range listOf(v) {
			if m, ok := r.(map[string]any); ok {
				db.Reports = append(db.Reports, m)
			}
		}
	}
	return db, nil
}

// asReport gives a v2 report the id / count the state bookkeeping needs.
func asReport(m map[string]any) Report {
	r := Report{}
	r.ID, _ = m["id"].(string)
	if c, ok := m["count"].(float64); ok {
		r.Count = int64(c)
	}
	if r.Count < 1 {
		r.Count = 1
	}
	return r
}

type sentinelBody struct {
	Schema    int              `json:"schema"`
	InstallID string           `json:"installId"`
	Uploader  string           `json:"uploader"`
	Flavor    string           `json:"flavor,omitempty"`
	Session   int64            `json:"session,omitempty"`
	Addons    []any            `json:"addons,omitempty"`
	Reports   []map[string]any `json:"reports"`
}

// SentinelBody builds one schema-2 request.
func SentinelBody(db *SentinelDB, reports []map[string]any) ([]byte, error) {
	return json.Marshal(sentinelBody{Schema: 2, InstallID: db.InstallID, Uploader: "PhoenixUploader " + version, Flavor: db.Flavor,
		Session: db.Session, Addons: db.Addons, Reports: reports})
}

// SentinelBatches splits reports at batchReports / batchBytes like v1.
func SentinelBatches(rs []map[string]any) [][]map[string]any {
	var out [][]map[string]any
	var cur []map[string]any
	size := 0
	for _, r := range rs {
		b, _ := json.Marshal(r)
		if len(cur) > 0 && (len(cur) >= batchReports || size+len(b) > batchBytes) {
			out = append(out, cur)
			cur, size = nil, 0
		}
		cur = append(cur, r)
		size += len(b) + 1
	}
	if len(cur) > 0 {
		out = append(out, cur)
	}
	return out
}
