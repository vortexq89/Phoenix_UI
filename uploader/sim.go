package main

// Sim requests: what the Phoenix UI "Sim" page saves in PhoenixUISimDB, checked line by line before anything
// reaches SimulationCraft.
//
// The addon sends a SimC profile (the same text the SimulationCraft addon exports) plus the items the player
// ticked. That text comes from a file other programs could edit, and SimC options can write files (html=, json2=,
// output=, save=, log=...), so nothing is passed through as is: every line is parsed and only a short list of
// character and gear options with strictly shaped values is kept. All output options are set by this app.

import (
	"errors"
	"fmt"
	"math"
	"os"
	"regexp"
	"sort"
	"strings"
	"unicode"
)

const simVariable = "PhoenixUISimDB"
const simSchema = 1

// SimItem is one item of a request: an equipped one (from the profile) or a candidate the player ticked.
type SimItem struct {
	Key     string // stable item identity from the addon (item ID and bonus IDs)
	Slot    string // simc slot group: head, neck, ..., finger, trinket, main_hand, off_hand, weapon
	Line    string // ",id=...,bonus_id=..." (everything after "<slot>=")
	Name    string
	Level   int64
	TwoHand bool
	ItemID  int64
}

type SimFight struct {
	Style   string
	Length  int64
	Targets int64
}

// SimRequest is one entry of PhoenixUISimDB.requests.
type SimRequest struct {
	ID       string
	Created  int64
	Char     string
	Mode     string // gear, compare, best, weights
	Fight    SimFight
	Profile  []string // the checked profile lines
	Equipped []SimItem
	Items    []SimItem
	File     string // the SavedVariables file it came from
	Retail   string // its _retail_ folder
}

var (
	reqID       = regexp.MustCompile(`^[0-9a-z]{6,40}$`)
	itemKey     = regexp.MustCompile(`^[0-9]{1,9}(:[0-9]{1,9}){0,40}$`)
	itemLine    = regexp.MustCompile(`^,id=[0-9]{1,9}(,(enchant_id|gem_id|bonus_id|drop_level|content_tuning|crafted_stats|redirected_base_stats|gem_bonus_id|crafting_quality|titan_disc_id)=[0-9]{1,9}(/[0-9]{1,9}){0,40})*$`)
	tokenValue  = regexp.MustCompile(`^[a-z0-9_]{1,40}$`)
	talentValue = regexp.MustCompile(`^[A-Za-z0-9+/]{8,400}$`)
	traitEntry  = regexp.MustCompile(`^[0-9]{1,9}:[0-9]{1,3}$`)
	profValue   = regexp.MustCompile(`^[a-z_]{2,20}=[0-9]{1,4}(/[a-z_]{2,20}=[0-9]{1,4})?$`)
)

var simClasses = map[string]bool{"warrior": true, "paladin": true, "hunter": true, "rogue": true, "priest": true,
	"deathknight": true, "shaman": true, "mage": true, "warlock": true, "monk": true, "druid": true,
	"demonhunter": true, "evoker": true}

// SimSlots are the gear options a profile may carry, in output order.
var SimSlots = []string{"head", "neck", "shoulder", "back", "chest", "shirt", "tabard", "wrist", "hands", "waist",
	"legs", "feet", "finger1", "finger2", "trinket1", "trinket2", "main_hand", "off_hand"}

var slotAlias = map[string]string{"shoulders": "shoulder", "wrists": "wrist"}

// slotsOf maps a slot group to the profile slots an item of that group can go in.
func slotsOf(group string) []string {
	switch group {
	case "finger":
		return []string{"finger1", "finger2"}
	case "trinket":
		return []string{"trinket1", "trinket2"}
	case "weapon": // a one-hander of a character who can dual wield
		return []string{"main_hand", "off_hand"}
	}
	for _, s := range SimSlots {
		if s == group && s != "finger1" && s != "finger2" && s != "trinket1" && s != "trinket2" {
			return []string{s}
		}
	}
	return nil
}

var simFightStyles = map[string]bool{"Patchwerk": true, "CastingPatchwerk": true, "LightMovement": true,
	"HeavyMovement": true, "HecticAddCleave": true, "DungeonSlice": true, "DungeonRoute": true}

var simModes = map[string]bool{"gear": true, "compare": true, "best": true, "weights": true}

// CleanProfile keeps the character and gear lines of a SimC profile and refuses everything else. It returns the
// lines in a fixed order: character, talents, then gear.
func CleanProfile(text string) ([]string, error) {
	if len(text) > 64<<10 {
		return nil, errors.New("profile too long")
	}
	var head, gear []string
	seen := map[string]bool{}
	slots := map[string]string{}
	class := ""
	for _, raw := range strings.Split(strings.ReplaceAll(text, "\r", ""), "\n") {
		line := strings.TrimSpace(raw)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		k, v, ok := strings.Cut(line, "=")
		if !ok {
			return nil, fmt.Errorf("profile line %q is not key=value", clip(line))
		}
		k = strings.ToLower(strings.TrimSpace(k))
		if a, ok := slotAlias[k]; ok {
			k = a
		}
		if seen[k] {
			return nil, fmt.Errorf("profile sets %s twice", k)
		}
		seen[k] = true
		switch {
		case simClasses[k]:
			if class != "" {
				return nil, errors.New("profile has two characters")
			}
			class = k
			head = append([]string{k + "=" + quoteName(v)}, head...)
		case k == "level":
			if n, err := atoiRange(v, 1, 100); err != nil {
				return nil, err
			} else {
				head = append(head, fmt.Sprintf("level=%d", n))
			}
		case k == "race" || k == "region" || k == "server" || k == "role" || k == "spec" || k == "zandalari_loa":
			if !tokenValue.MatchString(v) {
				return nil, fmt.Errorf("profile %s=%q is not a plain name", k, clip(v))
			}
			head = append(head, k+"="+v)
		case k == "professions":
			if v != "" && !profValue.MatchString(v) {
				return nil, fmt.Errorf("profile professions=%q not understood", clip(v))
			}
			if v != "" {
				head = append(head, k+"="+v)
			}
		case k == "talents":
			if !talentValue.MatchString(v) {
				return nil, errors.New("profile talents= is not a talent export string")
			}
			head = append(head, k+"="+v)
		case k == "omnium_talents":
			if !validTraits(v) {
				return nil, errors.New("profile omnium_talents= not understood")
			}
			head = append(head, k+"="+v)
		case isSlot(k):
			if v != "" && !itemLine.MatchString(v) {
				return nil, fmt.Errorf("profile %s= has an unexpected item option", k)
			}
			slots[k] = v
		default:
			return nil, fmt.Errorf("profile option %q is not allowed", clip(k))
		}
	}
	if class == "" {
		return nil, errors.New("profile names no character class")
	}
	for _, s := range SimSlots {
		if v, ok := slots[s]; ok && v != "" {
			gear = append(gear, s+"="+v)
		}
	}
	return append(head, gear...), nil
}

// validTraits accepts "entryID:rank/entryID:rank/..." (at most 200 entries).
func validTraits(v string) bool {
	parts := strings.Split(v, "/")
	if len(parts) > 200 {
		return false
	}
	for _, p := range parts {
		if !traitEntry.MatchString(p) {
			return false
		}
	}
	return true
}

func isSlot(k string) bool {
	for _, s := range SimSlots {
		if s == k {
			return true
		}
	}
	return false
}

// quoteName keeps letters and digits of the character name (SimC uses it only as a label).
func quoteName(v string) string {
	v = strings.Trim(strings.TrimSpace(v), `"'`)
	var b strings.Builder
	for _, r := range v {
		if unicode.IsLetter(r) || unicode.IsDigit(r) {
			b.WriteRune(r)
		}
		if b.Len() >= 48 {
			break
		}
	}
	if b.Len() == 0 {
		return `"Player"`
	}
	return `"` + b.String() + `"`
}

func atoiRange(v string, lo, hi int64) (int64, error) {
	var n int64
	if _, err := fmt.Sscan(strings.TrimSpace(v), &n); err != nil || n < lo || n > hi {
		return 0, fmt.Errorf("%q is not a number from %d to %d", clip(v), lo, hi)
	}
	return n, nil
}

func clip(s string) string {
	if len(s) > 40 {
		return s[:40] + "…"
	}
	return s
}

func boolField(t *Table, k string) bool {
	v, _ := t.Get(k)
	b, _ := v.(bool)
	return b
}

func readItems(t *Table, k string) ([]SimItem, error) {
	v, _ := t.Get(k)
	list, _ := v.(*Table)
	var out []SimItem
	for _, e := range list.List() {
		it, ok := e.(*Table)
		if !ok {
			return nil, errors.New("item entry is not a table")
		}
		i := SimItem{Key: str(it, "key"), Slot: str(it, "slot"), Line: str(it, "line"), Name: str(it, "name"),
			Level: integer(it, "level"), TwoHand: boolField(it, "twoHand"), ItemID: integer(it, "itemID")}
		if !itemKey.MatchString(i.Key) || slotsOf(i.Slot) == nil || !itemLine.MatchString(i.Line) {
			return nil, fmt.Errorf("item %q is malformed", clip(i.Key))
		}
		if len([]rune(i.Name)) > 80 {
			i.Name = string([]rune(i.Name)[:80])
		}
		out = append(out, i)
		if len(out) > 60 {
			return nil, errors.New("too many items")
		}
	}
	return out, nil
}

// ReadSimRequests returns the pending requests of one SavedVariables file (nil when it has none).
func ReadSimRequests(path, retail string) ([]SimRequest, []error, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, nil, err
	}
	if !strings.Contains(string(b), simVariable) {
		return nil, nil, nil
	}
	vars, err := ParseSavedVariables(string(b))
	if err != nil {
		return nil, nil, err
	}
	root, ok := vars[simVariable].(*Table)
	if !ok {
		return nil, nil, nil
	}
	if s := integer(root, "schema"); s != simSchema {
		return nil, nil, fmt.Errorf("PhoenixUISimDB schema %d (this app speaks %d - update it)", s, simSchema)
	}
	rv, _ := root.Get("requests")
	rt, _ := rv.(*Table)
	if rt == nil {
		return nil, nil, nil
	}
	keys := make([]string, 0, len(rt.Hash))
	for k := range rt.Hash {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	var out []SimRequest
	var bad []error
	for _, k := range keys {
		t, ok := rt.Hash[k].(*Table)
		if !ok {
			continue
		}
		r, err := parseRequest(t)
		if err != nil {
			bad = append(bad, fmt.Errorf("request %s: %w", clip(k), err))
			continue
		}
		r.File, r.Retail = path, retail
		out = append(out, r)
	}
	return out, bad, nil
}

func parseRequest(t *Table) (SimRequest, error) {
	r := SimRequest{ID: str(t, "id"), Created: integer(t, "created"), Char: str(t, "char"), Mode: str(t, "mode")}
	if !reqID.MatchString(r.ID) {
		return r, errors.New("bad id")
	}
	if !simModes[r.Mode] {
		return r, fmt.Errorf("unknown mode %q", clip(r.Mode))
	}
	if len([]rune(r.Char)) > 64 {
		r.Char = string([]rune(r.Char)[:64])
	}
	fv, _ := t.Get("fight")
	ft, _ := fv.(*Table)
	r.Fight = SimFight{Style: str(ft, "style"), Length: integer(ft, "length"), Targets: integer(ft, "targets")}
	if !simFightStyles[r.Fight.Style] {
		r.Fight.Style = "Patchwerk"
	}
	r.Fight.Length = clampInt(r.Fight.Length, 30, 900, 300)
	r.Fight.Targets = clampInt(r.Fight.Targets, 1, 20, 1)
	var err error
	if r.Profile, err = CleanProfile(str(t, "profile")); err != nil {
		return r, err
	}
	if r.Equipped, err = readItems(t, "equipped"); err != nil {
		return r, err
	}
	if r.Items, err = readItems(t, "items"); err != nil {
		return r, err
	}
	if (r.Mode == "compare" || r.Mode == "best") && len(r.Items) == 0 {
		return r, errors.New("no items ticked")
	}
	return r, nil
}

func clampInt(v, lo, hi, def int64) int64 {
	if v == 0 {
		return def
	}
	return int64(math.Max(float64(lo), math.Min(float64(hi), float64(v))))
}
