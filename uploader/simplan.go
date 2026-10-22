package main

// From a checked request to a SimulationCraft input file, and from SimC's json2 report back to results.
//
// compare: one profileset per ticked item and slot (a ring is tried in both ring slots, the better counts).
// best:    every combination of equipped and ticked items (rings and trinkets as pairs, two-handers clear the
//          off hand), capped at maxCombos; the equipped set is the baseline actor.
// weights: the baseline with calculate_scale_factors, reported relative to the primary stat.

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"sort"
	"strings"
)

const maxCombos = 400

type simSet struct {
	Name  string   // profileset name (p1, p2, ...)
	Lines []string // "slot=..." overrides
	Keys  []string // item keys it puts on
	Label string   // what the player sees
}

type SimPlan struct {
	Input string
	Sets  []simSet
}

// equippedLine returns the profile's current line for a slot ("" when empty).
func equippedLine(profile []string, slot string) string {
	for _, l := range profile {
		if strings.HasPrefix(l, slot+"=") {
			return strings.TrimPrefix(l, slot+"=")
		}
	}
	return ""
}

func mainIsTwoHand(r SimRequest) bool {
	for _, e := range r.Equipped {
		if e.Slot == "main_hand" {
			return e.TwoHand
		}
	}
	return false
}

// BuildPlan writes the SimC input for a request. threads and paths are added on the command line.
func BuildPlan(r SimRequest) (SimPlan, error) {
	var p SimPlan
	var b strings.Builder
	b.WriteString("# Phoenix UI sim " + r.ID + "\n")
	for _, l := range r.Profile {
		b.WriteString(l + "\n")
	}
	fmt.Fprintf(&b, "fight_style=%s\nmax_time=%d\ndesired_targets=%d\ntarget_error=0.2\n", r.Fight.Style, r.Fight.Length, r.Fight.Targets)
	b.WriteString("report_details=0\n")
	switch r.Mode {
	case "gear":
	case "weights":
		b.WriteString("calculate_scale_factors=1\nscale_only=strength,agility,intellect,crit_rating,haste_rating,mastery_rating,versatility_rating\n")
	case "compare":
		p.Sets = compareSets(r)
	case "best":
		sets, err := bestSets(r)
		if err != nil {
			return p, err
		}
		p.Sets = sets
	}
	if (r.Mode == "compare" || r.Mode == "best") && len(p.Sets) == 0 {
		return p, errors.New("none of the ticked items fits a slot that can be compared")
	}
	for _, s := range p.Sets {
		for _, l := range s.Lines {
			fmt.Fprintf(&b, "profileset.\"%s\"+=%s\n", s.Name, l)
		}
	}
	p.Input = b.String()
	return p, nil
}

func compareSets(r SimRequest) []simSet {
	var out []simSet
	twoHandNow := mainIsTwoHand(r)
	for i, it := range r.Items {
		for j, slot := range slotsOf(it.Slot) {
			if slot == "off_hand" && twoHandNow {
				continue // an off hand cannot be judged alone next to a two-hander
			}
			lines := []string{slot + "=" + it.Line}
			if slot == "main_hand" && it.TwoHand {
				lines = append(lines, "off_hand=")
			}
			out = append(out, simSet{Name: fmt.Sprintf("i%d_%d", i+1, j+1), Lines: lines, Keys: []string{it.Key}, Label: it.Name})
		}
	}
	return out
}

type option struct {
	key, line, name string
	itemID          int64
	twoHand         bool
	equipped        bool
}

// bestSets enumerates gear combinations over the slots that have ticked items.
func bestSets(r SimRequest) ([]simSet, error) {
	groups := map[string][]option{}
	add := func(it SimItem, eq bool) {
		g := normGroup(it.Slot)
		for _, o := range groups[g] {
			if o.key == it.Key && o.equipped == eq {
				return
			}
		}
		groups[g] = append(groups[g], option{key: it.Key, line: it.Line, name: it.Name, itemID: it.ItemID, twoHand: it.TwoHand, equipped: eq})
	}
	ticked := map[string]bool{}
	for _, it := range r.Items {
		ticked[normGroup(it.Slot)] = true
	}
	for _, it := range r.Equipped {
		if ticked[normGroup(it.Slot)] {
			add(it, true)
		}
	}
	for _, it := range r.Items {
		if it.Slot == "off_hand" && !ticked["main_hand"] && mainIsTwoHand(r) {
			continue // an off hand cannot be judged next to the two-hander that stays equipped
		}
		add(it, false)
	}
	// Each group yields a list of choices: one item, or a pair for rings and trinkets.
	type choice struct {
		lines []string
		keys  []string
		names []string
		base  bool // the equipped choice
		twoH  bool
	}
	var names []string
	for g := range groups {
		names = append(names, g)
	}
	sort.Strings(names)
	var slots [][]choice
	for _, g := range names {
		opts := groups[g]
		var cs []choice
		if g == "finger" || g == "trinket" {
			for i := 0; i < len(opts); i++ {
				for j := i + 1; j < len(opts); j++ {
					a, c := opts[i], opts[j]
					if a.itemID != 0 && a.itemID == c.itemID {
						continue // the same ring or trinket twice is unique-equipped
					}
					ch := choice{lines: []string{g + "1=" + a.line, g + "2=" + c.line}, base: a.equipped && c.equipped}
					for _, o := range []option{a, c} {
						if !o.equipped { // only the items that change count for the tooltip of an item
							ch.keys, ch.names = append(ch.keys, o.key), append(ch.names, o.name)
						}
					}
					cs = append(cs, ch)
				}
			}
		} else {
			for _, o := range opts {
				cs = append(cs, choice{lines: []string{g + "=" + o.line}, keys: []string{o.key}, names: []string{o.name}, base: o.equipped, twoH: o.twoHand})
			}
		}
		if len(cs) > 0 {
			slots = append(slots, cs)
		}
	}
	total := 1
	for _, cs := range slots {
		total *= len(cs)
		if total > maxCombos*4 {
			return nil, fmt.Errorf("too many combinations (more than %d); tick fewer items", maxCombos)
		}
	}
	var out []simSet
	idx := make([]int, len(slots))
	for {
		var lines, keys, labels []string
		allBase, twoH, skip := true, false, false
		for s, i := range idx {
			if slots[s][i].twoH {
				twoH = true
			}
		}
		for s, i := range idx {
			c := slots[s][i]
			if strings.HasPrefix(c.lines[0], "off_hand=") && twoH {
				// a two-hander empties the off hand: keep one combination of this kind, not one per off hand
				skip = skip || i > 0
				continue
			}
			lines = append(lines, c.lines...)
			if !c.base {
				allBase = false
				keys = append(keys, c.keys...)
				labels = append(labels, c.names...)
			}
		}
		if !allBase && !skip {
			if twoH {
				lines = append(lines, "off_hand=")
			}
			out = append(out, simSet{Name: fmt.Sprintf("c%d", len(out)+1), Lines: lines, Keys: keys, Label: strings.Join(labels, " + ")})
			if len(out) > maxCombos {
				return nil, fmt.Errorf("too many combinations (more than %d); tick fewer items", maxCombos)
			}
		}
		k := len(idx) - 1
		for k >= 0 {
			idx[k]++
			if idx[k] < len(slots[k]) {
				break
			}
			idx[k] = 0
			k--
		}
		if k < 0 {
			break
		}
	}
	return out, nil
}

// normGroup maps a slot or slot group to the group "best" combines over (dual-wield one-handers are tried in
// the main hand there; "compare" also tries them in the off hand).
func normGroup(s string) string {
	switch s {
	case "finger1", "finger2":
		return "finger"
	case "trinket1", "trinket2":
		return "trinket"
	case "weapon":
		return "main_hand"
	}
	return s
}

// ---------------------------------------------------------------- report

type simcJSON struct {
	Version     string `json:"version"`
	GitRevision string `json:"git_revision"`
	Sim         struct {
		Players []struct {
			Name           string             `json:"name"`
			Specialization string             `json:"specialization"`
			ScaleFactors   map[string]float64 `json:"scale_factors"`
			CollectedData  struct {
				DPS struct {
					Mean       float64 `json:"mean"`
					MeanStdDev float64 `json:"mean_std_dev"`
				} `json:"dps"`
			} `json:"collected_data"`
		} `json:"players"`
		Profilesets struct {
			Results []struct {
				Name      string  `json:"name"`
				Mean      float64 `json:"mean"`
				MeanError float64 `json:"mean_error"`
			} `json:"results"`
		} `json:"profilesets"`
		Statistics struct {
			Elapsed float64 `json:"elapsed_time_seconds"`
		} `json:"statistics"`
		Options struct {
			DBC map[string]any `json:"dbc"`
		} `json:"options"`
	} `json:"sim"`
}

// SimSetResult is one compared set in the results file.
type SimSetResult struct {
	Label string
	DPS   float64
	Delta float64
	Pct   float64
	Keys  []string
}

// SimResult is what goes back into the game for one request.
type SimResult struct {
	ID       string
	State    string // done, failed, declined, waiting
	Error    string
	Finished int64
	Seconds  float64
	Mode     string
	Char     string
	Spec     string
	Simc     string
	DPS      float64
	DPSError float64
	Sets     []SimSetResult
	Items    map[string]SimSetResult // best result per ticked item key
	Weights  map[string]float64
	Fight    SimFight
}

// ReadReport turns SimC's json2 output into a result.
func ReadReport(path string, r SimRequest, plan SimPlan) (SimResult, error) {
	res := SimResult{ID: r.ID, State: "done", Mode: r.Mode, Char: r.Char, Fight: r.Fight}
	raw, err := os.ReadFile(path)
	if err != nil {
		return res, err
	}
	var j simcJSON
	if err := json.Unmarshal(raw, &j); err != nil {
		return res, fmt.Errorf("SimC report: %w", err)
	}
	if len(j.Sim.Players) == 0 {
		return res, errors.New("SimC report has no player")
	}
	pl := j.Sim.Players[0]
	res.Simc, res.Spec = j.Version, pl.Specialization
	res.DPS = pl.CollectedData.DPS.Mean
	res.DPSError = 1.96 * pl.CollectedData.DPS.MeanStdDev
	res.Seconds = j.Sim.Statistics.Elapsed
	if r.Mode == "weights" && len(pl.ScaleFactors) > 0 {
		res.Weights = normaliseWeights(pl.ScaleFactors)
	}
	byName := map[string]simSet{}
	for _, s := range plan.Sets {
		byName[s.Name] = s
	}
	best := map[string]SimSetResult{} // per label (a ring tried in both slots counts once, the better slot)
	for _, ps := range j.Sim.Profilesets.Results {
		s, ok := byName[ps.Name]
		if !ok || res.DPS <= 0 {
			continue
		}
		sr := SimSetResult{Label: s.Label, DPS: ps.Mean, Delta: ps.Mean - res.DPS, Pct: (ps.Mean - res.DPS) / res.DPS * 100, Keys: s.Keys}
		id := strings.Join(s.Keys, "+")
		if r.Mode == "compare" {
			id = strings.SplitN(s.Name, "_", 2)[0]
		}
		if old, ok := best[id]; !ok || sr.DPS > old.DPS {
			best[id] = sr
		}
	}
	res.Items = map[string]SimSetResult{}
	for _, sr := range best {
		res.Sets = append(res.Sets, sr)
		for _, k := range sr.Keys {
			if old, ok := res.Items[k]; !ok || sr.DPS > old.DPS {
				res.Items[k] = sr
			}
		}
	}
	sort.Slice(res.Sets, func(a, b int) bool { return res.Sets[a].DPS > res.Sets[b].DPS })
	if len(res.Sets) > 25 {
		res.Sets = res.Sets[:25]
	}
	return res, nil
}

// normaliseWeights reports stat weights relative to the primary stat (the largest of Str/Agi/Int) = 1.
func normaliseWeights(sf map[string]float64) map[string]float64 {
	primary := 0.0
	for _, k := range []string{"Str", "Agi", "Int"} {
		if sf[k] > primary {
			primary = sf[k]
		}
	}
	out := map[string]float64{}
	if primary <= 0 {
		return out
	}
	for k, v := range sf {
		switch k {
		case "Str", "Agi", "Int", "Crit", "Haste", "Mastery", "Vers":
			if v > 0 {
				out[k] = float64(int64(v/primary*1000+0.5)) / 1000
			}
		}
	}
	return out
}
