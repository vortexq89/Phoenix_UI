//go:build windows

package main

import (
	"fmt"
	"os/exec"
	"syscall"
	"unsafe"

	"golang.org/x/sys/windows"
)

const (
	mbYesNo          = 0x00000004
	mbIconQuestion   = 0x00000020
	mbIconInfo       = 0x00000040
	mbSetForeground  = 0x00010000
	mbDefButton2     = 0x00000100
	idYes            = 6
	createNoWindow   = 0x08000000
	belowNormalClass = 0x00004000
)

var messageBox = windows.NewLazySystemDLL("user32.dll").NewProc("MessageBoxW")

func msgBox(title, text string, flags uintptr) int {
	t, _ := windows.UTF16PtrFromString(title)
	b, _ := windows.UTF16PtrFromString(text)
	r, _, _ := messageBox.Call(0, uintptr(unsafe.Pointer(b)), uintptr(unsafe.Pointer(t)), flags)
	return int(r)
}

// askConsent is the only way a SimulationCraft download starts without --allow-simc-download: a plain Yes/No
// window that says what is downloaded, from where, how it is checked and where it goes. "No" is the default
// button.
func askConsent(b SimcBuild, char, dir string) (bool, bool) {
	who := "Phoenix UI asked for a simulation"
	if char != "" {
		who += " of " + char
	}
	text := fmt.Sprintf("%s.\n\nSims run on this PC with SimulationCraft, a free program by the SimulationCraft project (GPL-3.0). "+
		"Phoenix UI does not include it.\n\nDownload SimulationCraft %s (for WoW %s) now?\n\n"+
		"  - about %d MB from downloads.simulationcraft.org\n"+
		"  - checked against the SHA-256 of the official SimulationCraft build before it is used\n"+
		"  - kept in %s; nothing else is installed and nothing is uploaded\n\n"+
		"You can remove it any time: tray icon > Remove SimulationCraft.", who, b.Version, b.WowBuild, b.Size>>20, dir)
	return msgBox("Phoenix UI - download SimulationCraft?", text, mbYesNo|mbIconQuestion|mbSetForeground|mbDefButton2) == idYes, true
}

// notifySim offers the full SimC report when a sim finishes.
func notifySim(title, text, report string) {
	go func() {
		if msgBox(title, text+"\n\nOpen the full SimulationCraft report?", mbYesNo|mbIconInfo|mbSetForeground) == idYes && report != "" {
			open(report)
		}
	}()
}

// quietProcess: no console window, below-normal priority.
func quietProcess(cmd *exec.Cmd) {
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true, CreationFlags: createNoWindow | belowNormalClass}
}
