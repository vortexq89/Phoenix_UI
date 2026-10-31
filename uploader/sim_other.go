//go:build !windows

package main

import "os/exec"

// Without a desktop dialog the download needs --allow-simc-download.
func askConsent(SimcBuild, string, string) (bool, bool) { return false, false }

func notifySim(string, string, string) {}

func quietProcess(*exec.Cmd) {}
