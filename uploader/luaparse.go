package main

// A small, strict reader for the Lua that World of Warcraft writes into SavedVariables files.
//
// It understands exactly the data subset WoW emits (and a little more, so a hand-edited file still loads):
// top-level `Name = value` assignments; tables with positional, [key] = and name = fields; strings in all
// quote styles with every Lua 5.1-5.4 escape, long brackets, numbers (decimal, hex, exponent, inf/nan
// spellings WoW never writes but some tools do), booleans and nil; -- line and --[[ block ]] comments.
// It never executes anything, and it refuses input deeper than maxDepth or larger than maxInput.

import (
	"errors"
	"fmt"
	"math"
	"sort"
	"strconv"
	"strings"
	"unicode/utf8"
)

const (
	maxDepth = 64
	maxInput = 128 << 20
)

// Table is a parsed Lua table: the array part in order, plus every keyed field (keys rendered as strings;
// numeric keys keep their integer spelling, so ["1"] and [1] read the same here).
type Table struct {
	Array []any
	Hash  map[string]any
}

// Get returns a keyed field.
func (t *Table) Get(k string) (any, bool) {
	if t == nil {
		return nil, false
	}
	v, ok := t.Hash[k]
	return v, ok
}

// List returns the table as a sequence: the array part followed by any integer-keyed fields in key order
// (WoW writes `[5] = ...` for a sparse array).
func (t *Table) List() []any {
	if t == nil {
		return nil
	}
	out := append([]any(nil), t.Array...)
	var idx []int
	for k := range t.Hash {
		if n, err := strconv.Atoi(k); err == nil && n > len(t.Array) {
			idx = append(idx, n)
		}
	}
	sort.Ints(idx)
	for _, n := range idx {
		out = append(out, t.Hash[strconv.Itoa(n)])
	}
	return out
}

type parser struct {
	s     string
	i     int
	line  int
	depth int
}

// ParseError carries the line of the problem.
type ParseError struct {
	Line int
	Msg  string
}

func (e *ParseError) Error() string { return fmt.Sprintf("line %d: %s", e.Line, e.Msg) }

func (p *parser) fail(format string, a ...any) error {
	return &ParseError{Line: p.line, Msg: fmt.Sprintf(format, a...)}
}

// ParseSavedVariables reads a whole SavedVariables file into name -> value.
func ParseSavedVariables(src string) (map[string]any, error) {
	if len(src) > maxInput {
		return nil, errors.New("file too large")
	}
	src = strings.TrimPrefix(src, "\ufeff")
	p := &parser{s: src, line: 1}
	out := map[string]any{}
	for {
		if err := p.skip(); err != nil {
			return nil, err
		}
		if p.i >= len(p.s) {
			return out, nil
		}
		if p.s[p.i] == ';' {
			p.i++
			continue
		}
		name, ok := p.name()
		if !ok {
			return nil, p.fail("expected a variable name")
		}
		if err := p.skip(); err != nil {
			return nil, err
		}
		if p.i >= len(p.s) || p.s[p.i] != '=' {
			return nil, p.fail("expected '=' after %s", name)
		}
		p.i++
		v, err := p.value()
		if err != nil {
			return nil, err
		}
		out[name] = v
	}
}

func isNameStart(c byte) bool { return c == '_' || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') }
func isNameChar(c byte) bool  { return isNameStart(c) || (c >= '0' && c <= '9') }

func (p *parser) name() (string, bool) {
	if p.i >= len(p.s) || !isNameStart(p.s[p.i]) {
		return "", false
	}
	j := p.i
	for j < len(p.s) && isNameChar(p.s[j]) {
		j++
	}
	n := p.s[p.i:j]
	p.i = j
	return n, true
}

// skip whitespace and comments.
func (p *parser) skip() error {
	for p.i < len(p.s) {
		c := p.s[p.i]
		switch {
		case c == '\n':
			p.line++
			p.i++
		case c == ' ' || c == '\t' || c == '\r' || c == '\f' || c == '\v':
			p.i++
		case c == '-' && p.i+1 < len(p.s) && p.s[p.i+1] == '-':
			p.i += 2
			if lvl, ok := p.longOpen(); ok {
				if _, err := p.longBody(lvl); err != nil {
					return err
				}
				continue
			}
			for p.i < len(p.s) && p.s[p.i] != '\n' {
				p.i++
			}
		default:
			return nil
		}
	}
	return nil
}

// longOpen consumes "[[", "[=[", ... and returns the level.
func (p *parser) longOpen() (int, bool) {
	if p.i >= len(p.s) || p.s[p.i] != '[' {
		return 0, false
	}
	j := p.i + 1
	lvl := 0
	for j < len(p.s) && p.s[j] == '=' {
		lvl++
		j++
	}
	if j < len(p.s) && p.s[j] == '[' {
		p.i = j + 1
		return lvl, true
	}
	return 0, false
}

func (p *parser) longBody(lvl int) (string, error) {
	closer := "]" + strings.Repeat("=", lvl) + "]"
	k := strings.Index(p.s[p.i:], closer)
	if k < 0 {
		return "", p.fail("unfinished long string or comment")
	}
	body := p.s[p.i : p.i+k]
	p.line += strings.Count(body, "\n")
	p.i += k + len(closer)
	// a newline right after the opening bracket is not part of the string
	if strings.HasPrefix(body, "\r\n") {
		body = body[2:]
	} else if strings.HasPrefix(body, "\n") || strings.HasPrefix(body, "\r") {
		body = body[1:]
	}
	return body, nil
}

func (p *parser) value() (any, error) {
	if err := p.skip(); err != nil {
		return nil, err
	}
	if p.i >= len(p.s) {
		return nil, p.fail("unexpected end of file")
	}
	c := p.s[p.i]
	switch {
	case c == '{':
		return p.table()
	case c == '"' || c == '\'':
		return p.quoted()
	case c == '[':
		if lvl, ok := p.longOpen(); ok {
			return p.longBody(lvl)
		}
		return nil, p.fail("unexpected '['")
	case c == '-' || c == '.' || (c >= '0' && c <= '9'):
		return p.number()
	case isNameStart(c):
		n, _ := p.name()
		switch n {
		case "true":
			return true, nil
		case "false":
			return false, nil
		case "nil":
			return nil, nil
		}
		return nil, p.fail("unexpected name %q (only data is allowed)", n)
	}
	return nil, p.fail("unexpected %q", c)
}

func (p *parser) number() (any, error) {
	j := p.i
	neg := false
	if p.s[j] == '-' {
		neg = true
		j++
		for j < len(p.s) && (p.s[j] == ' ' || p.s[j] == '\t') {
			j++
		}
	}
	k := j
	if k+1 < len(p.s) && p.s[k] == '0' && (p.s[k+1] == 'x' || p.s[k+1] == 'X') {
		k += 2
		for k < len(p.s) && strings.IndexByte("0123456789abcdefABCDEF.pP+-", p.s[k]) >= 0 {
			if (p.s[k] == '+' || p.s[k] == '-') && !(p.s[k-1] == 'p' || p.s[k-1] == 'P') {
				break
			}
			k++
		}
	} else {
		for k < len(p.s) && strings.IndexByte("0123456789.eE+-", p.s[k]) >= 0 {
			if (p.s[k] == '+' || p.s[k] == '-') && !(p.s[k-1] == 'e' || p.s[k-1] == 'E') {
				break
			}
			k++
		}
		// WoW never writes these, but tolerate the spellings other serializers use
		for _, w := range []string{"inf", "INF", "nan", "NAN"} {
			if k == j && strings.HasPrefix(p.s[j:], w) {
				k = j + len(w)
			}
		}
	}
	lit := p.s[j:k]
	if lit == "" {
		return nil, p.fail("bad number")
	}
	var f float64
	var err error
	switch {
	case strings.HasPrefix(lit, "0x") || strings.HasPrefix(lit, "0X"):
		if strings.ContainsAny(lit, ".pP") {
			f, err = strconv.ParseFloat(lit, 64)
		} else {
			var u uint64
			u, err = strconv.ParseUint(lit[2:], 16, 64)
			f = float64(int64(u))
		}
	case strings.EqualFold(lit, "inf"):
		f = math.Inf(1)
	case strings.EqualFold(lit, "nan"):
		f = math.NaN()
	default:
		f, err = strconv.ParseFloat(lit, 64)
	}
	if err != nil {
		return nil, p.fail("bad number %q", lit)
	}
	p.i = k
	if neg {
		f = -f
	}
	return f, nil
}

func (p *parser) quoted() (string, error) {
	q := p.s[p.i]
	p.i++
	var b strings.Builder
	for {
		if p.i >= len(p.s) {
			return "", p.fail("unfinished string")
		}
		c := p.s[p.i]
		if c == q {
			p.i++
			return b.String(), nil
		}
		if c == '\n' {
			return "", p.fail("newline inside a quoted string")
		}
		if c != '\\' {
			b.WriteByte(c)
			p.i++
			continue
		}
		p.i++
		if p.i >= len(p.s) {
			return "", p.fail("unfinished escape")
		}
		e := p.s[p.i]
		p.i++
		switch e {
		case 'n':
			b.WriteByte('\n')
		case 't':
			b.WriteByte('\t')
		case 'r':
			b.WriteByte('\r')
		case 'a':
			b.WriteByte('\a')
		case 'b':
			b.WriteByte('\b')
		case 'f':
			b.WriteByte('\f')
		case 'v':
			b.WriteByte('\v')
		case '\\', '"', '\'':
			b.WriteByte(e)
		case '\n':
			p.line++
			b.WriteByte('\n')
		case '\r':
			if p.i < len(p.s) && p.s[p.i] == '\n' {
				p.i++
			}
			p.line++
			b.WriteByte('\n')
		case 'z':
			for p.i < len(p.s) && strings.IndexByte(" \t\r\n\f\v", p.s[p.i]) >= 0 {
				if p.s[p.i] == '\n' {
					p.line++
				}
				p.i++
			}
		case 'x':
			if p.i+2 > len(p.s) {
				return "", p.fail("bad \\x escape")
			}
			v, err := strconv.ParseUint(p.s[p.i:p.i+2], 16, 8)
			if err != nil {
				return "", p.fail("bad \\x escape")
			}
			b.WriteByte(byte(v))
			p.i += 2
		case 'u':
			end := strings.IndexByte(p.s[p.i:], '}')
			if p.i >= len(p.s) || p.s[p.i] != '{' || end < 0 {
				return "", p.fail("bad \\u escape")
			}
			v, err := strconv.ParseUint(p.s[p.i+1:p.i+end], 16, 32)
			if err != nil || v > utf8.MaxRune {
				return "", p.fail("bad \\u escape")
			}
			b.WriteRune(rune(v))
			p.i += end + 1
		default:
			if e >= '0' && e <= '9' {
				j := p.i - 1
				k := j
				for k < len(p.s) && k < j+3 && p.s[k] >= '0' && p.s[k] <= '9' {
					k++
				}
				v, _ := strconv.Atoi(p.s[j:k])
				if v > 255 {
					return "", p.fail("decimal escape too large")
				}
				b.WriteByte(byte(v))
				p.i = k
			} else {
				return "", p.fail("unknown escape \\%c", e)
			}
		}
	}
}

func keyString(v any) (string, error) {
	switch k := v.(type) {
	case string:
		return k, nil
	case float64:
		if k == math.Trunc(k) && math.Abs(k) < 1e15 {
			return strconv.FormatInt(int64(k), 10), nil
		}
		return strconv.FormatFloat(k, 'g', -1, 64), nil
	case bool:
		return strconv.FormatBool(k), nil
	}
	return "", errors.New("unsupported table key")
}

func (p *parser) table() (*Table, error) {
	p.depth++
	if p.depth > maxDepth {
		return nil, p.fail("tables nested too deeply")
	}
	defer func() { p.depth-- }()
	p.i++ // {
	t := &Table{Hash: map[string]any{}}
	for {
		if err := p.skip(); err != nil {
			return nil, err
		}
		if p.i >= len(p.s) {
			return nil, p.fail("unfinished table")
		}
		if p.s[p.i] == '}' {
			p.i++
			return t, nil
		}
		var key any
		hasKey := false
		if p.s[p.i] == '[' {
			if lvl, ok := p.longOpen(); ok { // a long string as a positional value
				v, err := p.longBody(lvl)
				if err != nil {
					return nil, err
				}
				t.Array = append(t.Array, v)
				goto sep
			}
			p.i++
			k, err := p.value()
			if err != nil {
				return nil, err
			}
			if err := p.skip(); err != nil {
				return nil, err
			}
			if p.i >= len(p.s) || p.s[p.i] != ']' {
				return nil, p.fail("expected ']'")
			}
			p.i++
			key, hasKey = k, true
		} else if isNameStart(p.s[p.i]) {
			save, saveLine := p.i, p.line
			n, _ := p.name()
			if err := p.skip(); err != nil {
				return nil, err
			}
			if p.i < len(p.s) && p.s[p.i] == '=' && !(p.i+1 < len(p.s) && p.s[p.i+1] == '=') {
				key, hasKey = n, true
			} else {
				p.i, p.line = save, saveLine
			}
		}
		if hasKey {
			if err := p.skip(); err != nil {
				return nil, err
			}
			if p.i >= len(p.s) || p.s[p.i] != '=' {
				return nil, p.fail("expected '='")
			}
			p.i++
			v, err := p.value()
			if err != nil {
				return nil, err
			}
			ks, err := keyString(key)
			if err != nil {
				return nil, p.fail("%v", err)
			}
			if v != nil {
				t.Hash[ks] = v
			}
		} else {
			v, err := p.value()
			if err != nil {
				return nil, err
			}
			t.Array = append(t.Array, v)
		}
	sep:
		if err := p.skip(); err != nil {
			return nil, err
		}
		if p.i < len(p.s) && (p.s[p.i] == ',' || p.s[p.i] == ';') {
			p.i++
			continue
		}
		if p.i < len(p.s) && p.s[p.i] == '}' {
			continue
		}
		return nil, p.fail("expected ',' or '}'")
	}
}
