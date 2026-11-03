//go:build !windows

package main

import (
	"os"
	"path/filepath"
)

// Off Windows (tests, Wine prefixes, a copied WTF folder) only the home and Wine defaults are probed.
func platformCandidates() []string {
	h, _ := os.UserHomeDir()
	return []string{
		filepath.Join(h, "Games", "World of Warcraft"),
		filepath.Join(h, ".wine", "drive_c", "Program Files (x86)", "World of Warcraft"),
	}
}
