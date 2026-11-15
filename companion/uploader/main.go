// Phoenix Uploader: sends the Phoenix UI addon's saved error reports to vq8s.com.
//
// World of Warcraft addons cannot use the network, so the addon's error catcher writes reports into its
// SavedVariables (PhoenixUIBugsDB, written when you log out, reload or quit) and this program delivers them.
// It runs quietly in the tray (or with --once, a single pass), only ever reads WoW's files, and keeps a small
// state file so each report is sent once (again only if its count grows).
package main

import (
	"flag"
	"fmt"
	"os"
	"os/signal"
	"path/filepath"
	"runtime"
	"strings"
)

func dataDirDefault() string {
	if runtime.GOOS == "windows" {
		if d := os.Getenv("LOCALAPPDATA"); d != "" {
			return filepath.Join(d, "Phoenix UI Uploader")
		}
	}
	if d, err := os.UserConfigDir(); err == nil {
		return filepath.Join(d, "phoenix-uploader")
	}
	return "."
}

type multi []string

func (m *multi) String() string     { return strings.Join(*m, ";") }
func (m *multi) Set(v string) error { *m = append(*m, v); return nil }

func main() {
	var (
		once       = flag.Bool("once", false, "scan and upload once, then exit")
		dry        = flag.Bool("dry-run", false, "with --once: show what would be sent, send nothing")
		background = flag.Bool("background", false, "run in the background (the default when started with no options)")
		noTray     = flag.Bool("no-tray", false, "background mode without a tray icon")
		dataDir    = flag.String("data-dir", dataDirDefault(), "where state.json, uploader.log and config.json live")
		endpoint   = flag.String("endpoint", "", "override the ingest URL (https, or http://localhost for testing)")
		key        = flag.String("key", "", "override the ingest key")
		startOn    = flag.Bool("install-startup", false, "start with Windows (current user)")
		startOff   = flag.Bool("remove-startup", false, "stop starting with Windows")
		showVer    = flag.Bool("version", false, "print the version")
		wow        multi
	)
	flag.Var(&wow, "wow", "a World of Warcraft or _retail_ folder to scan (repeatable)")
	cli := len(os.Args) > 1 && !*background
	if cli {
		attachConsole()
	}
	flag.Parse()
	if *showVer {
		fmt.Println("Phoenix Uploader", version)
		return
	}
	if *startOn || *startOff {
		if err := setStartup(*startOn); err != nil {
			fmt.Fprintln(os.Stderr, "startup:", err)
			os.Exit(1)
		}
		fmt.Println("start with Windows:", *startOn)
		return
	}
	var console *os.File
	if *once || *dry || *noTray || runtime.GOOS != "windows" {
		console = os.Stdout
	}
	log := NewLogger(*dataDir, console)
	app, err := NewApp(*dataDir, log, wow, *endpoint, *key, *dry)
	if err != nil {
		log.Printf("cannot start: %v", err)
		os.Exit(1)
	}
	if *once || *dry {
		s := app.Cycle(true)
		log.Printf("%s", s)
		switch {
		case s.Err != nil:
			os.Exit(1)
		case s.Folders == 0:
			os.Exit(2)
		}
		return
	}
	if !singleInstance() {
		return // already running in the tray
	}
	if !app.state.Startup && runtime.GOOS == "windows" {
		// First background run: start with Windows from now on (the tray menu turns it off).
		if err := setStartup(true); err == nil {
			log.Printf("added to Windows startup (untick \"Start with Windows\" in the tray menu to undo)")
		}
		app.state.Startup = true
		_ = app.state.Save()
	}
	stop, kick := make(chan struct{}), make(chan struct{}, 1)
	if *noTray || runtime.GOOS != "windows" {
		sig := make(chan os.Signal, 1)
		signal.Notify(sig, os.Interrupt)
		go func() { <-sig; close(stop) }()
		app.Loop(stop, kick)
		return
	}
	runTray(app, stop, kick)
}
