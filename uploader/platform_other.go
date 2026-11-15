//go:build !windows

package main

import "errors"

func attachConsole()       {}
func singleInstance() bool { return true }
func setStartup(bool) error {
	return errors.New("start-up registration is only available on Windows")
}
func startupEnabled() bool                                     { return false }
func runTray(app *App, stop chan struct{}, kick chan struct{}) { app.Loop(stop, kick) }
