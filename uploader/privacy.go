package main

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// Privacy, second line. The addon already strips identity when it stores a report (Core/Errors.lua); this repeats
// the same rules on what is about to leave the PC, so a report stored by an older Phoenix_UI build cannot carry
// a character name either. The uploader knows more than the addon here: every character and realm on the
// account is a folder under WTF\Account\<account>\.

var (
	reGUID      = regexp.MustCompile(`Player-\d+-[0-9A-Fa-f]+`)
	reBattleTag = regexp.MustCompile(`[\p{L}\p{N}]+#\d{4,}`)
	reUserDir   = regexp.MustCompile(`([Uu]sers[/\\])[^/\\\n"']+`)
	reAccount   = regexp.MustCompile(`([Aa]ccount[/\\])[^/\\\n"']+`)
	reLocal     = regexp.MustCompile(`^(\s*[^=]*?=\s*)"(.*)"$`)
	reToken     = regexp.MustCompile(`^[\w.\-:/\\<>]*$`)
)

// Scrubber removes one account's character names, realms and account name from report text.
type Scrubber struct{ names []*regexp.Regexp }

// NewScrubber collects the realm and character folder names of the account that owns this SavedVariables file
// (<account>\SavedVariables\Phoenix_UI.lua -> <account>\<realm>\<character>).
func NewScrubber(svFile string) *Scrubber {
	account := filepath.Dir(filepath.Dir(svFile))
	seen := map[string]bool{}
	add := func(n string) {
		if len([]rune(n)) >= 2 && !seen[n] {
			seen[n] = true
		}
	}
	add(filepath.Base(account))
	realms, _ := os.ReadDir(account)
	for _, realm := range realms {
		if !realm.IsDir() || strings.EqualFold(realm.Name(), "SavedVariables") {
			continue
		}
		add(realm.Name())
		chars, _ := os.ReadDir(filepath.Join(account, realm.Name()))
		for _, c := range chars {
			if c.IsDir() && !strings.EqualFold(c.Name(), "SavedVariables") {
				add(c.Name())
			}
		}
	}
	s := &Scrubber{}
	for n := range seen {
		// whole words only: a character called "Frame" must not turn CreateFrame into Create<player>
		s.names = append(s.names, regexp.MustCompile(`(^|[^\p{L}\p{N}_])`+regexp.QuoteMeta(n)+`($|[^\p{L}\p{N}_])`))
	}
	return s
}

func (s *Scrubber) text(t string) string {
	t = reGUID.ReplaceAllString(t, "Player-<guid>")
	t = reBattleTag.ReplaceAllString(t, "<battletag>")
	t = reUserDir.ReplaceAllString(t, "${1}<user>")
	t = reAccount.ReplaceAllString(t, "${1}<account>")
	for _, re := range s.names {
		for i := 0; i < 2; i++ { // twice: adjacent matches ("Name-Name") share a separator
			t = re.ReplaceAllString(t, "${1}<player>${2}")
		}
	}
	return t
}

func (s *Scrubber) locals(t string) string {
	lines := strings.Split(s.text(t), "\n")
	for i, l := range lines {
		m := reLocal.FindStringSubmatch(l)
		if m == nil || (len(m[2]) <= 40 && reToken.MatchString(m[2])) || strings.HasPrefix(m[2], "<text, ") {
			continue
		}
		lines[i] = fmt.Sprintf(`%s"<text, %d bytes>"`, m[1], len(m[2]))
	}
	return strings.Join(lines, "\n")
}

// Report returns a copy that is safe to send.
func (s *Scrubber) Report(r Report) Report {
	r.Message, r.Stack, r.Locals = s.text(r.Message), s.text(r.Stack), s.locals(r.Locals)
	return r
}
