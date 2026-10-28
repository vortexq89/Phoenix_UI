//go:build !windows

package main

import (
	"errors"
	"os"
	"strings"
)

func attachConsole()       {}
func singleInstance() bool { return true }
func setStartup(bool) error {
	return errors.New("start-up registration is only available on Windows")
}
func startupEnabled() bool                                     { return false }
func runTray(app *App, stop chan struct{}, kick chan struct{}) { app.Loop(stop, kick) }

// wowRunning outside Windows: look for a WoW process in /proc (Wine / Proton runs show the exe name).
func wowRunning() bool {
	ents, err := os.ReadDir("/proc")
	if err != nil {
		return false
	}
	for _, e := range ents {
		b, err := os.ReadFile("/proc/" + e.Name() + "/comm")
		if err == nil && isWowExe(strings.TrimSpace(string(b))) {
			return true
		}
	}
	return false
}
