//go:build windows

package main

import (
	"os"
	"path/filepath"

	"golang.org/x/sys/windows/registry"
)

func regString(root registry.Key, path, name string) string {
	k, err := registry.OpenKey(root, path, registry.QUERY_VALUE|registry.WOW64_64KEY)
	if err != nil {
		k, err = registry.OpenKey(root, path, registry.QUERY_VALUE)
		if err != nil {
			return ""
		}
	}
	defer k.Close()
	v, _, err := k.GetStringValue(name)
	if err != nil {
		return ""
	}
	return v
}

func platformCandidates() []string {
	var c []string
	for _, p := range []struct {
		root       registry.Key
		path, name string
	}{
		{registry.LOCAL_MACHINE, `SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft`, "InstallPath"},
		{registry.LOCAL_MACHINE, `SOFTWARE\Blizzard Entertainment\World of Warcraft`, "InstallPath"},
		{registry.LOCAL_MACHINE, `SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\World of Warcraft`, "InstallLocation"},
		{registry.LOCAL_MACHINE, `SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\World of Warcraft`, "InstallLocation"},
		{registry.CURRENT_USER, `SOFTWARE\Blizzard Entertainment\World of Warcraft`, "InstallPath"},
	} {
		if v := regString(p.root, p.path, p.name); v != "" {
			c = append(c, v)
		}
	}
	// Battle.net's own records of where it installed games.
	for _, f := range []string{
		filepath.Join(os.Getenv("APPDATA"), "Battle.net", "Battle.net.config"),
		filepath.Join(os.Getenv("ProgramData"), "Battle.net", "Agent", "product.db"),
		filepath.Join(os.Getenv("ProgramData"), "Battle.net", "Setup", "wow", "product.db"),
	} {
		if b, err := os.ReadFile(f); err == nil && len(b) < 32<<20 {
			c = append(c, pathsInText(b)...)
		}
	}
	for d := 'C'; d <= 'Z'; d++ {
		root := string(d) + `:\`
		if _, err := os.Stat(root); err == nil {
			c = append(c, commonRoots(root)...)
		}
	}
	return c
}
