package main

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sync"
	"time"
)

// Logger writes timestamped lines to uploader.log in the data folder (rotated at 1 MB, one old file kept)
// and, when a console is attached, to stdout too.
type Logger struct {
	mu      sync.Mutex
	path    string
	console io.Writer
}

const logMax = 1 << 20

func NewLogger(dir string, console io.Writer) *Logger {
	_ = os.MkdirAll(dir, 0o755)
	return &Logger{path: filepath.Join(dir, "uploader.log"), console: console}
}

func (l *Logger) Printf(format string, a ...any) {
	l.mu.Lock()
	defer l.mu.Unlock()
	line := time.Now().Format("2006-01-02 15:04:05") + "  " + fmt.Sprintf(format, a...) + "\n"
	if l.console != nil {
		_, _ = io.WriteString(l.console, line)
	}
	if st, err := os.Stat(l.path); err == nil && st.Size() > logMax {
		_ = os.Rename(l.path, l.path+".1")
	}
	f, err := os.OpenFile(l.path, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o644)
	if err != nil {
		return
	}
	defer f.Close()
	_, _ = io.WriteString(f, line)
}

func (l *Logger) Path() string { return l.path }
