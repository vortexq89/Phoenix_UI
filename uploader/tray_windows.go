//go:build windows

package main

import (
	_ "embed"
	"time"

	"fyne.io/systray"
)

//go:embed assets/phoenix.ico
var trayIcon []byte

func runTray(app *App, stop chan struct{}, kick chan struct{}) {
	systray.Run(func() {
		systray.SetIcon(trayIcon)
		systray.SetTitle("Phoenix Uploader")
		systray.SetTooltip("Phoenix Uploader " + version)
		status := systray.AddMenuItem("Starting…", "")
		status.Disable()
		systray.AddSeparator()
		now := systray.AddMenuItem("Upload now", "Scan the SavedVariables and send anything new")
		logs := systray.AddMenuItem("Open log", "uploader.log")
		folder := systray.AddMenuItem("Open data folder", "config, state and log")
		site := systray.AddMenuItem("Phoenix UI website", "https://vq8s.com/phoenix-ui")
		systray.AddSeparator()
		simStatus := systray.AddMenuItem("Sim: idle", "")
		simStatus.Disable()
		simReport := systray.AddMenuItem("Open last sim report", "The full SimulationCraft report of the last sim")
		simCancel := systray.AddMenuItem("Cancel sim", "Stop the running sim or download")
		simGet := systray.AddMenuItem("Download SimulationCraft…", "Asks first; about 115 MB, checked before use")
		simDel := systray.AddMenuItem("Remove SimulationCraft", "Delete the downloaded SimulationCraft")
		if app.sims == nil {
			for _, m := range []*systray.MenuItem{simStatus, simReport, simCancel, simGet, simDel} {
				m.Hide()
			}
		}
		systray.AddSeparator()
		startup := systray.AddMenuItemCheckbox("Start with Windows", "", startupEnabled())
		quit := systray.AddMenuItem("Quit", "")
		go app.Loop(stop, kick)
		go func() {
			t := time.NewTicker(2 * time.Second)
			defer t.Stop()
			for {
				select {
				case <-t.C:
					s := app.Status()
					status.SetTitle(s)
					systray.SetTooltip("Phoenix Uploader · " + s)
					if app.sims != nil {
						simStatus.SetTitle(app.sims.Status())
						showIf(simReport, app.sims.Report() != "")
						showIf(simCancel, app.sims.Busy())
						have := app.sims.HaveSimc()
						showIf(simGet, !have && !app.sims.Busy())
						showIf(simDel, have && app.sims.simc.custom == "" && !app.sims.Busy())
					}
				case <-simReport.ClickedCh:
					if r := app.sims.Report(); r != "" {
						open(r)
					}
				case <-simCancel.ClickedCh:
					app.sims.Cancel()
				case <-simGet.ClickedCh:
					go app.sims.AllowDownload()
				case <-simDel.ClickedCh:
					if err := app.sims.RemoveSimc(); err != nil {
						app.log.Printf("remove SimulationCraft: %v", err)
					}
				case <-now.ClickedCh:
					select {
					case kick <- struct{}{}:
					default:
					}
				case <-logs.ClickedCh:
					open(app.log.Path())
				case <-folder.ClickedCh:
					open(app.dataDir)
				case <-site.ClickedCh:
					open("https://vq8s.com/phoenix-ui")
				case <-startup.ClickedCh:
					on := !startup.Checked()
					if err := setStartup(on); err == nil {
						if on {
							startup.Check()
						} else {
							startup.Uncheck()
						}
					}
				case <-quit.ClickedCh:
					close(stop)
					systray.Quit()
					return
				}
			}
		}()
	}, func() {})
}

func showIf(m *systray.MenuItem, on bool) {
	if on {
		m.Show()
	} else {
		m.Hide()
	}
}
