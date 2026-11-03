package main

import (
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

// Finding World of Warcraft. Every source only proposes folders; a folder counts when it really is a retail
// install (it has WTF, Interface or the game executable). Sources, in order: config.json / --wow, the
// Windows registry, Battle.net's own config and product database, then the usual install folders on every drive.

// retailOf turns ".../World of Warcraft" or ".../World of Warcraft/_retail_" (or a path inside it) into the _retail_ folder.
func retailOf(p string) string {
	p = strings.TrimSpace(strings.Trim(p, "\"'"))
	if p == "" {
		return ""
	}
	p = filepath.Clean(p)
	for q := p; ; {
		if strings.EqualFold(filepath.Base(q), "_retail_") {
			return q
		}
		parent := filepath.Dir(q)
		if parent == q {
			break
		}
		q = parent
	}
	return filepath.Join(p, "_retail_")
}

func isRetail(dir string) bool {
	for _, n := range []string{"WTF", "Interface", "Wow.exe", "WowT.exe"} {
		if _, err := os.Stat(filepath.Join(dir, n)); err == nil {
			return true
		}
	}
	return false
}

var bnetPath = regexp.MustCompile(`(?i)[A-Z]:[\\/][^\x00-\x1f"<>|?*]{0,240}?World of Warcraft`)

// pathsInText pulls every "X:\...World of Warcraft" out of a config file or a binary database.
func pathsInText(b []byte) []string {
	var out []string
	for _, m := range bnetPath.FindAll(b, 64) {
		s := strings.ReplaceAll(string(m), "\\\\", "\\")
		out = append(out, s)
	}
	return out
}

// DetectRetail returns every retail folder found, deduplicated, in discovery order.
func DetectRetail(extra []string) []string {
	var cand []string
	cand = append(cand, extra...)
	if v := os.Getenv("PHOENIX_WOW_PATH"); v != "" {
		cand = append(cand, v)
	}
	cand = append(cand, platformCandidates()...)
	seen := map[string]bool{}
	var out []string
	for _, c := range cand {
		r := retailOf(c)
		if r == "" {
			continue
		}
		k := strings.ToLower(r)
		if seen[k] {
			continue
		}
		seen[k] = true
		if isRetail(r) {
			out = append(out, r)
		}
	}
	return out
}

// commonRoots lists the usual install folders under one drive root (also one level of "Games\<anything>").
func commonRoots(drive string) []string {
	out := []string{
		filepath.Join(drive, "World of Warcraft"),
		filepath.Join(drive, "Program Files (x86)", "World of Warcraft"),
		filepath.Join(drive, "Program Files", "World of Warcraft"),
		filepath.Join(drive, "Games", "World of Warcraft"),
		filepath.Join(drive, "Blizzard", "World of Warcraft"),
		filepath.Join(drive, "Battle.net", "World of Warcraft"),
		filepath.Join(drive, "Program Files (x86)", "Battle.net", "World of Warcraft"),
	}
	for _, pat := range []string{filepath.Join(drive, "Games", "*", "World of Warcraft"), filepath.Join(drive, "*", "World of Warcraft")} {
		m, _ := filepath.Glob(pat)
		sort.Strings(m)
		out = append(out, m...)
	}
	return out
}
