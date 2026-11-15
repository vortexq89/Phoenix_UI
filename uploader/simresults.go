package main

// Writing sim results where the game can read them: Interface\AddOns\Phoenix_UI\Sim\Results.lua, a file the
// addon ships (empty) and loads, so a /reload picks up new content. The file is data only, written by a small
// serializer (strings escaped, finite numbers, keys always bracketed) and replaced atomically. Results stay for
// 14 days (at most 30), then the addon has long since copied them into its own SavedVariables.

import (
	"fmt"
	"math"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"
)

const resultsVariable = "PhoenixUISimResults"
const resultsKeep = 30
const resultsDays = 14

// ResultsFile is the results file of a retail folder, or "" when Phoenix UI is not installed there (the app
// never creates addon folders).
func ResultsFile(retail string) string {
	addon := filepath.Join(retail, "Interface", "AddOns", "Phoenix_UI")
	if _, err := os.Stat(filepath.Join(addon, "Phoenix_UI.toc")); err != nil {
		return ""
	}
	return filepath.Join(addon, "Sim", "Results.lua")
}

type luaWriter struct{ b strings.Builder }

func luaString(s string) string {
	var b strings.Builder
	b.WriteByte('"')
	for i := 0; i < len(s); i++ {
		c := s[i]
		switch {
		case c == '"' || c == '\\':
			b.WriteByte('\\')
			b.WriteByte(c)
		case c == '\n':
			b.WriteString(`\n`)
		case c < 0x20 || c == 0x7f:
			fmt.Fprintf(&b, `\%03d`, c)
		default:
			b.WriteByte(c)
		}
	}
	b.WriteByte('"')
	return b.String()
}

func luaNumber(f float64) string {
	if math.IsNaN(f) || math.IsInf(f, 0) {
		return "0"
	}
	return strconv.FormatFloat(f, 'f', -1, 64)
}

func (w *luaWriter) kv(indent int, k, v string) {
	fmt.Fprintf(&w.b, "%s[%s] = %s,\n", strings.Repeat("\t", indent), luaString(k), v)
}

func (w *luaWriter) result(indent int, r SimResult) {
	in := strings.Repeat("\t", indent)
	fmt.Fprintf(&w.b, "%s[%s] = {\n", in, luaString(r.ID))
	w.kv(indent+1, "id", luaString(r.ID))
	w.kv(indent+1, "state", luaString(r.State))
	if r.Error != "" {
		w.kv(indent+1, "error", luaString(r.Error))
	}
	w.kv(indent+1, "finished", luaNumber(float64(r.Finished)))
	w.kv(indent+1, "seconds", luaNumber(math.Round(r.Seconds*10)/10))
	w.kv(indent+1, "mode", luaString(r.Mode))
	w.kv(indent+1, "char", luaString(r.Char))
	if r.Spec != "" {
		w.kv(indent+1, "spec", luaString(r.Spec))
	}
	if r.Simc != "" {
		w.kv(indent+1, "simc", luaString(r.Simc))
	}
	if r.DPS > 0 {
		w.kv(indent+1, "dps", luaNumber(math.Round(r.DPS)))
		w.kv(indent+1, "dpsError", luaNumber(math.Round(r.DPSError)))
	}
	if r.Fight.Style != "" {
		w.kv(indent+1, "fight", fmt.Sprintf("{ style = %s, length = %d, targets = %d }", luaString(r.Fight.Style), r.Fight.Length, r.Fight.Targets))
	}
	set := func(s SimSetResult) string {
		keys := make([]string, len(s.Keys))
		for i, k := range s.Keys {
			keys[i] = luaString(k)
		}
		return fmt.Sprintf("{ label = %s, dps = %s, delta = %s, pct = %s, keys = { %s } }", luaString(s.Label),
			luaNumber(math.Round(s.DPS)), luaNumber(math.Round(s.Delta)), luaNumber(math.Round(s.Pct*100)/100), strings.Join(keys, ", "))
	}
	if len(r.Sets) > 0 {
		fmt.Fprintf(&w.b, "%s\t[\"sets\"] = {\n", in)
		for _, s := range r.Sets {
			fmt.Fprintf(&w.b, "%s\t\t%s,\n", in, set(s))
		}
		fmt.Fprintf(&w.b, "%s\t},\n", in)
	}
	if len(r.Items) > 0 {
		fmt.Fprintf(&w.b, "%s\t[\"items\"] = {\n", in)
		keys := make([]string, 0, len(r.Items))
		for k := range r.Items {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		for _, k := range keys {
			s := r.Items[k]
			w.kv(indent+2, k, fmt.Sprintf("{ dps = %s, delta = %s, pct = %s }", luaNumber(math.Round(s.DPS)), luaNumber(math.Round(s.Delta)), luaNumber(math.Round(s.Pct*100)/100)))
		}
		fmt.Fprintf(&w.b, "%s\t},\n", in)
	}
	if len(r.Weights) > 0 {
		fmt.Fprintf(&w.b, "%s\t[\"weights\"] = {\n", in)
		keys := make([]string, 0, len(r.Weights))
		for k := range r.Weights {
			keys = append(keys, k)
		}
		sort.Strings(keys)
		for _, k := range keys {
			w.kv(indent+2, k, luaNumber(r.Weights[k]))
		}
		fmt.Fprintf(&w.b, "%s\t},\n", in)
	}
	fmt.Fprintf(&w.b, "%s},\n", in)
}

// RenderResults is the complete file for a set of results.
func RenderResults(results []SimResult, now time.Time) string {
	var w luaWriter
	w.b.WriteString("-- Written by the Phoenix app (" + version + "). Data only; it is replaced after every sim.\n")
	fmt.Fprintf(&w.b, "%s = {\n\t[\"schema\"] = 1,\n\t[\"written\"] = %d,\n\t[\"results\"] = {\n", resultsVariable, now.Unix())
	for _, r := range results {
		w.result(2, r)
	}
	w.b.WriteString("\t},\n}\n")
	return w.b.String()
}

// readPrevious returns the results already in the file (only what the writer itself produces is understood).
func readPrevious(path string) []SimResult {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil
	}
	vars, err := ParseSavedVariables(string(b))
	if err != nil {
		return nil
	}
	root, _ := vars[resultsVariable].(*Table)
	rv, _ := root.Get("results")
	rt, _ := rv.(*Table)
	if rt == nil {
		return nil
	}
	var out []SimResult
	for k, v := range rt.Hash {
		t, ok := v.(*Table)
		if !ok || !reqID.MatchString(k) {
			continue
		}
		out = append(out, resultFromTable(t))
	}
	return out
}

func num(t *Table, k string) float64 {
	v, _ := t.Get(k)
	f, _ := v.(float64)
	return f
}

func resultFromTable(t *Table) SimResult {
	r := SimResult{ID: str(t, "id"), State: str(t, "state"), Error: str(t, "error"), Finished: integer(t, "finished"),
		Seconds: num(t, "seconds"), Mode: str(t, "mode"), Char: str(t, "char"), Spec: str(t, "spec"), Simc: str(t, "simc"),
		DPS: num(t, "dps"), DPSError: num(t, "dpsError")}
	if fv, ok := t.Get("fight"); ok {
		if ft, ok := fv.(*Table); ok {
			r.Fight = SimFight{Style: str(ft, "style"), Length: integer(ft, "length"), Targets: integer(ft, "targets")}
		}
	}
	readSet := func(st *Table) SimSetResult {
		s := SimSetResult{Label: str(st, "label"), DPS: num(st, "dps"), Delta: num(st, "delta"), Pct: num(st, "pct")}
		kv, _ := st.Get("keys")
		kt, _ := kv.(*Table)
		for _, k := range kt.List() {
			if ks, ok := k.(string); ok {
				s.Keys = append(s.Keys, ks)
			}
		}
		return s
	}
	if sv, ok := t.Get("sets"); ok {
		if lt, ok := sv.(*Table); ok {
			for _, e := range lt.List() {
				if st, ok := e.(*Table); ok {
					r.Sets = append(r.Sets, readSet(st))
				}
			}
		}
	}
	if iv, ok := t.Get("items"); ok {
		if it, ok := iv.(*Table); ok {
			r.Items = map[string]SimSetResult{}
			for k, v := range it.Hash {
				if st, ok := v.(*Table); ok && itemKey.MatchString(k) {
					r.Items[k] = readSet(st)
				}
			}
		}
	}
	if wv, ok := t.Get("weights"); ok {
		if wt, ok := wv.(*Table); ok {
			r.Weights = map[string]float64{}
			for k, v := range wt.Hash {
				if f, ok := v.(float64); ok {
					r.Weights[k] = f
				}
			}
		}
	}
	return r
}

// WriteResult adds (or replaces) one result in a retail folder's results file.
func WriteResult(retail string, r SimResult, now time.Time) (string, error) {
	path := ResultsFile(retail)
	if path == "" {
		return "", fmt.Errorf("Phoenix UI is not installed in %s", retail)
	}
	cut := now.Add(-resultsDays * 24 * time.Hour).Unix()
	all := []SimResult{r}
	for _, p := range readPrevious(path) {
		if p.ID != r.ID && p.Finished >= cut {
			all = append(all, p)
		}
	}
	sort.Slice(all, func(a, b int) bool { return all[a].Finished > all[b].Finished })
	if len(all) > resultsKeep {
		all = all[:resultsKeep]
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return "", err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, []byte(RenderResults(all, now)), 0o644); err != nil {
		return "", err
	}
	return path, os.Rename(tmp, path)
}
