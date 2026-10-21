package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/url"
	"os"
	"path/filepath"
	"strings"
)

// Set at build time:  -ldflags "-X main.defaultIngestKey=<PHOENIX_INGEST_KEY> -X main.defaultEndpoint=<url>"
// A config.json next to the exe (or in the data folder) overrides both.
var (
	version          = "1.0.0"
	defaultEndpoint  = "https://vq8s.com/phoenix/api/ingest"
	defaultIngestKey = "" // placeholder: filled at release time, never committed
)

// Config is config.json. Every field is optional.
type Config struct {
	Endpoint    string   `json:"endpoint,omitempty"`
	IngestKey   string   `json:"ingestKey,omitempty"`
	WowPaths    []string `json:"wowPaths,omitempty"`    // extra _retail_ (or World of Warcraft) folders to scan
	ScanSeconds int      `json:"scanSeconds,omitempty"` // how often the background mode looks for changes (default 60)
	Disabled    bool     `json:"disabled,omitempty"`    // true: never upload (the uploader still runs and logs)
}

const configName = "config.json"

func exeDir() string {
	exe, err := os.Executable()
	if err != nil {
		return "."
	}
	if r, err := filepath.EvalSymlinks(exe); err == nil {
		exe = r
	}
	return filepath.Dir(exe)
}

// LoadConfig reads config.json next to the exe, then the data folder's (the first one found wins).
func LoadConfig(dataDir string) (Config, string, error) {
	c := Config{}
	for _, p := range []string{filepath.Join(exeDir(), configName), filepath.Join(dataDir, configName)} {
		b, err := os.ReadFile(p)
		if errors.Is(err, os.ErrNotExist) {
			continue
		}
		if err != nil {
			return c, p, err
		}
		if err := json.Unmarshal(b, &c); err != nil {
			return c, p, fmt.Errorf("%s: %w", p, err)
		}
		c.fill()
		return c, p, nil
	}
	c.fill()
	return c, "", nil
}

func (c *Config) fill() {
	if strings.TrimSpace(c.Endpoint) == "" {
		c.Endpoint = defaultEndpoint
	}
	if strings.TrimSpace(c.IngestKey) == "" {
		c.IngestKey = defaultIngestKey
	}
	if c.ScanSeconds < 15 {
		c.ScanSeconds = 60
	}
}

// CheckEndpoint refuses plain http anywhere except this machine (local testing).
func CheckEndpoint(raw string) error {
	u, err := url.Parse(raw)
	if err != nil || u.Host == "" {
		return fmt.Errorf("endpoint %q is not a URL", raw)
	}
	if u.Scheme == "https" {
		return nil
	}
	h := u.Hostname()
	if u.Scheme == "http" && (h == "localhost" || h == "127.0.0.1" || h == "::1") {
		return nil
	}
	return fmt.Errorf("endpoint %q must use https", raw)
}

// WriteTemplate leaves an example config in the data folder the first time, so the key has an obvious home.
func WriteTemplate(dataDir string) {
	p := filepath.Join(dataDir, "config.example.json")
	if _, err := os.Stat(p); err == nil {
		return
	}
	b, _ := json.MarshalIndent(Config{Endpoint: defaultEndpoint, IngestKey: "<paste the Phoenix ingest key here>", ScanSeconds: 60}, "", "  ")
	_ = os.WriteFile(p, append(b, '\n'), 0o644)
}
