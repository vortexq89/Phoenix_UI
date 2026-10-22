package main

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

const testProfile = `# Phoenix UI export
mage="Ignis"
level=90
race=void_elf
region=eu
server=tarren_mill
role=spell
professions=tailoring=100/enchanting=100
spec=fire
talents=C8PAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
head=,id=250000,bonus_id=1/2/3
shoulders=,id=250001,enchant_id=7000
finger1=,id=250010,gem_id=213743
finger2=,id=250011
trinket1=,id=250020,bonus_id=12
trinket2=,id=250021
main_hand=,id=250030,bonus_id=4/5,drop_level=90,crafted_stats=36/49,crafting_quality=5
`

func TestEmbeddedManifest(t *testing.T) {
	b, err := ParseManifest(embeddedManifest)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.HasPrefix(b.URL, "http://downloads.simulationcraft.org/") || b.Exe == "" || b.License == "" {
		t.Fatalf("pin: %+v", b)
	}
}

func TestManifestRefusals(t *testing.T) {
	good, _ := ParseManifest(embeddedManifest)
	for name, mod := range map[string]func(*SimcBuild){
		"host":     func(b *SimcBuild) { b.URL = "http://evil.example/simc.7z" },
		"userinfo": func(b *SimcBuild) { b.URL = "http://x@downloads.simulationcraft.org/a.7z" },
		"scheme":   func(b *SimcBuild) { b.URL = "file:///c:/simc.7z" },
		"sha":      func(b *SimcBuild) { b.SHA256 = "abc" },
		"exe":      func(b *SimcBuild) { b.Exe = "../simc.exe" },
		"exename":  func(b *SimcBuild) { b.Exe = "dir/evil.exe" },
		"file":     func(b *SimcBuild) { b.File = "../x.7z" },
		"version":  func(b *SimcBuild) { b.Version = "latest" },
		"size":     func(b *SimcBuild) { b.Size = 0 },
	} {
		b := good
		mod(&b)
		if b.Validate() == nil {
			t.Errorf("%s: accepted", name)
		}
	}
}

func TestCleanProfile(t *testing.T) {
	lines, err := CleanProfile(testProfile)
	if err != nil {
		t.Fatal(err)
	}
	if lines[0] != `mage="Ignis"` || !contains(lines, "shoulder=,id=250001,enchant_id=7000") || contains(lines, "shoulders=,id=250001,enchant_id=7000") {
		t.Fatalf("lines: %q", lines)
	}
	for _, bad := range []string{
		"html=C:\\x.html", "output=/tmp/x", "save=x.simc", "json2=x", "log=1", "threads=1000",
		"head=,id=1,html=x", "head=,id=1\nhead=,id=2", "talents=$(rm)", "race=Night Elf", "level=999",
		"profileset.\"a\"+=head=,id=1", "input=other.simc", "mage=a\nwarrior=b",
	} {
		if _, err := CleanProfile("mage=Ignis\n" + bad); err == nil && bad != "mage=a\nwarrior=b" {
			t.Errorf("accepted %q", bad)
		}
	}
	if _, err := CleanProfile("level=90"); err == nil {
		t.Error("profile without a class accepted")
	}
	if _, err := CleanProfile("mage=a\nwarrior=b"); err == nil {
		t.Error("two characters accepted")
	}
	if l, _ := CleanProfile(`mage="Ig'nis <script>"`); l[0] != `mage="Ignisscript"` {
		t.Errorf("name: %q", l[0])
	}
}

func contains(l []string, s string) bool {
	for _, x := range l {
		if x == s {
			return true
		}
	}
	return false
}

func testRequest(t *testing.T, mode string, items []SimItem) SimRequest {
	t.Helper()
	p, err := CleanProfile(testProfile)
	if err != nil {
		t.Fatal(err)
	}
	return SimRequest{ID: "abc123", Mode: mode, Char: "Ignis-TarrenMill", Fight: SimFight{"Patchwerk", 300, 1}, Profile: p,
		Equipped: []SimItem{
			{Key: "250010", Slot: "finger", Line: ",id=250010,gem_id=213743", Name: "Ring A", ItemID: 250010},
			{Key: "250011", Slot: "finger", Line: ",id=250011", Name: "Ring B", ItemID: 250011},
			{Key: "250030:4:5", Slot: "main_hand", Line: ",id=250030,bonus_id=4/5", Name: "Staff", ItemID: 250030, TwoHand: true},
		}, Items: items}
}

func TestComparePlan(t *testing.T) {
	r := testRequest(t, "compare", []SimItem{
		{Key: "260000:1", Slot: "finger", Line: ",id=260000,bonus_id=1", Name: "New ring", ItemID: 260000},
		{Key: "260001", Slot: "off_hand", Line: ",id=260001", Name: "Orb", ItemID: 260001},
		{Key: "260002", Slot: "main_hand", Line: ",id=260002", Name: "Big staff", ItemID: 260002, TwoHand: true},
		{Key: "260004", Slot: "weapon", Line: ",id=260004", Name: "Dagger", ItemID: 260004},
	})
	p, err := BuildPlan(r)
	if err != nil {
		t.Fatal(err)
	}
	if len(p.Sets) != 4 { // ring in two slots, staff, dagger in the main hand; the off hands are skipped next to a two-hander
		t.Fatalf("sets: %+v", p.Sets)
	}
	for _, want := range []string{`profileset."i1_1"+=finger1=,id=260000,bonus_id=1`, `profileset."i1_2"+=finger2=,id=260000,bonus_id=1`,
		`profileset."i3_1"+=off_hand=`, "fight_style=Patchwerk", "max_time=300", "target_error=0.2"} {
		if !strings.Contains(p.Input, want) {
			t.Errorf("input lacks %q:\n%s", want, p.Input)
		}
	}
	for _, bad := range []string{"html=", "json2=", "output=", "threads="} {
		if strings.Contains(p.Input, bad) {
			t.Errorf("input sets %s", bad)
		}
	}
}

func TestBestPlan(t *testing.T) {
	r := testRequest(t, "best", []SimItem{
		{Key: "260000", Slot: "finger", Line: ",id=260000", Name: "Ring C", ItemID: 260000},
		{Key: "250010:9", Slot: "finger", Line: ",id=250010,bonus_id=9", Name: "Ring A (other)", ItemID: 250010},
		{Key: "260001", Slot: "off_hand", Line: ",id=260001", Name: "Orb", ItemID: 260001},
		{Key: "260003", Slot: "main_hand", Line: ",id=260003", Name: "Wand", ItemID: 260003},
	})
	p, err := BuildPlan(r)
	if err != nil {
		t.Fatal(err)
	}
	// rings: A B C A' -> pairs AB(base) AC BC BA' CA' (AA' refused: same item) = 5
	// hands: staff (2H, off hand cleared), wand+orb = 2 -> 10 combinations minus the equipped one = 9
	if len(p.Sets) != 9 {
		t.Fatalf("%d sets: %+v", len(p.Sets), p.Sets)
	}
	for _, s := range p.Sets {
		for _, k := range s.Keys {
			if k == "250010" || k == "250011" || k == "250030:4:5" {
				t.Errorf("set %s credits the equipped item %s", s.Name, k)
			}
		}
		staff := contains(s.Lines, "main_hand=,id=250030,bonus_id=4/5")
		if staff != contains(s.Lines, "off_hand=") || staff == contains(s.Lines, "off_hand=,id=260001") {
			t.Errorf("set %s hands: %q", s.Name, s.Lines)
		}
	}
	many := testRequest(t, "best", nil)
	for i := 0; i < 30; i++ {
		many.Items = append(many.Items, SimItem{Key: strings.Repeat("1", i+1), Slot: "trinket", Line: ",id=1", ItemID: int64(100 + i)})
	}
	if _, err := BuildPlan(many); err == nil {
		t.Error("too many combinations accepted")
	}
}

func TestReadReport(t *testing.T) {
	r := testRequest(t, "best", nil)
	plan := SimPlan{Sets: []simSet{
		{Name: "c1", Keys: []string{"k1"}, Label: "One"}, {Name: "c2", Keys: []string{"k2"}, Label: "Two"},
		{Name: "c3", Keys: []string{"k1", "k3"}, Label: "One + Three"}, {Name: "c4", Keys: []string{"k4"}, Label: "Four"},
		{Name: "c5", Keys: []string{"k5"}, Label: "Five"},
	}}
	res, err := ReadReport("testdata/simc_compare.json", r, plan)
	if err != nil {
		t.Fatal(err)
	}
	if res.DPS < 1000 || res.Spec != "Fire Mage" || res.Simc != "1210-01" || len(res.Sets) != 5 || len(res.Items) != 5 {
		t.Fatalf("result: %+v", res)
	}
	for i := 1; i < len(res.Sets); i++ {
		if res.Sets[i].DPS > res.Sets[i-1].DPS {
			t.Fatal("sets not sorted")
		}
	}
	if s := res.Sets[0]; s.Delta != s.DPS-res.DPS {
		t.Fatalf("delta: %+v", s)
	}
	w, err := ReadReport("testdata/simc_weights.json", testRequest(t, "weights", nil), SimPlan{})
	if err != nil {
		t.Fatal(err)
	}
	if w.Weights["Int"] != 1 || w.Weights["Crit"] <= 0 || w.Weights["Crit"] >= 1 || len(w.Weights) != 5 {
		t.Fatalf("weights: %v", w.Weights)
	}
}

func TestResultsRoundTrip(t *testing.T) {
	retail := t.TempDir()
	if _, err := WriteResult(retail, SimResult{ID: "x1x1x1"}, time.Now()); err == nil {
		t.Fatal("wrote results without Phoenix_UI installed")
	}
	dir := filepath.Join(retail, "Interface", "AddOns", "Phoenix_UI")
	_ = os.MkdirAll(filepath.Join(dir, "Sim"), 0o755)
	_ = os.WriteFile(filepath.Join(dir, "Phoenix_UI.toc"), []byte("## Interface: 120105\n"), 0o644)
	now := time.Now()
	a := SimResult{ID: "aaaaaa", State: "done", Finished: now.Unix(), Seconds: 2.5, Mode: "compare", Char: `Ig"nis\`, Spec: "Fire Mage",
		Simc: "1210-01", DPS: 229040.5, DPSError: 120, Fight: SimFight{"DungeonSlice", 300, 1},
		Sets:  []SimSetResult{{Label: "Ring \"C\"\n", DPS: 230000, Delta: 959.5, Pct: 0.42, Keys: []string{"260000:1"}}},
		Items: map[string]SimSetResult{"260000:1": {Label: "Ring", DPS: 230000, Delta: 959.5, Pct: 0.42}}}
	if _, err := WriteResult(retail, a, now); err != nil {
		t.Fatal(err)
	}
	b := SimResult{ID: "bbbbbb", State: "failed", Error: "Error: talent |cff", Finished: now.Unix() + 1, Mode: "weights", Weights: map[string]float64{"Int": 1, "Crit": 0.22}}
	path, err := WriteResult(retail, b, now)
	if err != nil {
		t.Fatal(err)
	}
	raw, _ := os.ReadFile(path)
	vars, err := ParseSavedVariables(string(raw))
	if err != nil {
		t.Fatalf("%v\n%s", err, raw)
	}
	got := readPrevious(path)
	if len(got) != 2 {
		t.Fatalf("results: %+v", got)
	}
	byID := map[string]SimResult{}
	for _, r := range got {
		byID[r.ID] = r
	}
	ga := byID["aaaaaa"]
	if ga.Char != a.Char || ga.DPS != 229041 || ga.Fight.Style != "DungeonSlice" || len(ga.Sets) != 1 || ga.Sets[0].Label != a.Sets[0].Label ||
		ga.Items["260000:1"].Delta != 960 || byID["bbbbbb"].Error != b.Error || byID["bbbbbb"].Weights["Crit"] != 0.22 {
		t.Fatalf("round trip:\n%+v\n%+v", ga, byID["bbbbbb"])
	}
	if _, ok := vars[resultsVariable].(*Table); !ok {
		t.Fatal("no PhoenixUISimResults table")
	}
	// old results age out
	if _, err := WriteResult(retail, SimResult{ID: "cccccc", State: "done", Finished: now.Unix()}, now.Add(20*24*time.Hour)); err != nil {
		t.Fatal(err)
	}
	if got := readPrevious(path); len(got) != 1 {
		t.Fatalf("aged: %d", len(got))
	}
}

func TestReadSimRequests(t *testing.T) {
	dir := t.TempDir()
	sv := filepath.Join(dir, "Phoenix_UI.lua")
	src := "PhoenixUISimDB = {\n[\"schema\"] = 1,\n[\"requests\"] = {\n" +
		"[\"req001\"] = {[\"id\"] = \"req001\", [\"created\"] = 1790000000, [\"char\"] = \"Ignis\", [\"mode\"] = \"compare\"," +
		"[\"fight\"] = {[\"style\"] = \"DungeonSlice\", [\"length\"] = 5000, [\"targets\"] = 0}," +
		"[\"profile\"] = " + luaString(testProfile) + "," +
		"[\"items\"] = {{[\"key\"] = \"260000:1\", [\"slot\"] = \"finger\", [\"line\"] = \",id=260000,bonus_id=1\", [\"name\"] = \"Ring\", [\"itemID\"] = 260000}}}," +
		"[\"req002\"] = {[\"id\"] = \"req002\", [\"mode\"] = \"gear\", [\"profile\"] = \"mage=x\\nhtml=c:\\\\evil.html\"}," +
		"[\"req003\"] = {[\"id\"] = \"req003\", [\"mode\"] = \"compare\", [\"profile\"] = \"mage=x\", [\"items\"] = {{[\"key\"] = \"1\", [\"slot\"] = \"finger\", [\"line\"] = \",id=1,save=x\"}}}," +
		"},\n}\n"
	_ = os.WriteFile(sv, []byte(src), 0o644)
	reqs, bad, err := ReadSimRequests(sv, dir)
	if err != nil {
		t.Fatal(err)
	}
	if len(reqs) != 1 || len(bad) != 2 {
		t.Fatalf("reqs %+v bad %v", reqs, bad)
	}
	r := reqs[0]
	if r.Fight.Style != "DungeonSlice" || r.Fight.Length != 900 || r.Fight.Targets != 1 || len(r.Items) != 1 || r.Retail != dir {
		t.Fatalf("request: %+v", r)
	}
}

// installFixture serves testdata/simc_test.7z as a pinned build.
func installFixture(t *testing.T) (*Simc, SimcBuild, func(code int)) {
	t.Helper()
	raw, err := os.ReadFile("testdata/simc_test.7z")
	if err != nil {
		t.Fatal(err)
	}
	status := http.StatusOK
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if status != http.StatusOK {
			w.WriteHeader(status)
			return
		}
		_, _ = w.Write(raw)
	}))
	t.Cleanup(srv.Close)
	simcHosts["127.0.0.1"] = true
	t.Cleanup(func() { delete(simcHosts, "127.0.0.1") })
	sum := sha256.Sum256(raw)
	b := SimcBuild{Version: "1210-99", File: "simc-test.7z", URL: srv.URL + "/simc-test.7z", Size: int64(len(raw)), SHA256: hex.EncodeToString(sum[:]),
		Exe: "simc-test/simc.exe", ExeSize: 23, ExeSHA256: "c2b0f1804a03fc265ae347c9623f3cbfdd55681d9b0ddcf38e1bc7624e9dc491", License: "simc-test/COPYING"}
	if err := b.Validate(); err != nil {
		t.Fatal(err)
	}
	s := NewSimc(t.TempDir(), "", "", NewLogger(t.TempDir(), nil))
	s.build, s.buildAt = b, time.Now()
	return s, b, func(code int) { status = code }
}

func TestSimcInstall(t *testing.T) {
	s, b, _ := installFixture(t)
	if s.Installed() {
		t.Fatal("installed before download")
	}
	if err := s.Install(context.Background()); err != nil {
		t.Fatal(err)
	}
	exe, ok := s.Exe()
	if !ok || !s.Installed() {
		t.Fatal("not installed after download")
	}
	if _, err := os.Stat(filepath.Join(filepath.Dir(exe), "COPYING.txt")); err != nil {
		t.Fatal("licence not kept")
	}
	if _, err := os.Stat(filepath.Join(filepath.Dir(exe), "README.txt")); err == nil {
		t.Fatal("extracted more than simc.exe and the licence")
	}
	if left, _ := filepath.Glob(filepath.Join(s.dir, "*.part")); len(left) != 0 {
		t.Fatal("partial download left behind")
	}
	// a tampered exe is no longer accepted
	_ = os.WriteFile(exe, []byte("MZ evil simc for tests!"), 0o644)
	if _, ok := s.Exe(); ok {
		t.Fatal("tampered simc.exe accepted")
	}
	_ = b
	if err := s.Remove(); err != nil || s.Installed() {
		t.Fatal("remove")
	}
}

func TestSimcInstallRefusals(t *testing.T) {
	s, b, setStatus := installFixture(t)
	bad := b
	bad.SHA256 = strings.Repeat("0", 64)
	s.build = bad
	if err := s.Install(context.Background()); err == nil || !strings.Contains(err.Error(), "does not match") {
		t.Fatalf("archive hash: %v", err)
	}
	bad = b
	bad.ExeSHA256 = strings.Repeat("1", 64)
	s.build = bad
	if err := s.Install(context.Background()); err == nil || !strings.Contains(err.Error(), "simc.exe") {
		t.Fatalf("exe hash: %v", err)
	}
	if s.Installed() {
		t.Fatal("installed after a refused download")
	}
	s.build = b
	setStatus(http.StatusNotFound)
	if err := s.Install(context.Background()); err == nil {
		t.Fatal("404 accepted")
	}
}

func TestSimServiceRun(t *testing.T) {
	retail := t.TempDir()
	addon := filepath.Join(retail, "Interface", "AddOns", "Phoenix_UI")
	_ = os.MkdirAll(filepath.Join(addon, "Sim"), 0o755)
	_ = os.WriteFile(filepath.Join(addon, "Phoenix_UI.toc"), []byte("x"), 0o644)
	data := t.TempDir()
	app := &App{dataDir: data, log: NewLogger(data, nil), state: LoadState(data)}
	s := NewSimService(app, false)
	simc, _, _ := installFixture(t)
	s.simc = simc
	asked := 0
	answer := false
	s.ask = func(SimcBuild, string, string) (bool, bool) { asked++; return answer, true }
	s.notify = func(string, string, string) {}
	var gotArgs []string
	s.runSimc = func(ctx context.Context, exe, dir string, args []string) ([]byte, error) {
		gotArgs = args
		raw, _ := os.ReadFile("testdata/simc_weights.json")
		return nil, os.WriteFile(filepath.Join(dir, "report.json"), raw, 0o644)
	}
	q := testRequest(t, "weights", nil)
	q.Retail = retail
	// declined: nothing downloaded, the game is told
	if res := s.Run(q); res.State != "declined" || asked != 1 || simc.Installed() {
		t.Fatalf("declined: %+v asked %d", res, asked)
	}
	if !app.state.SimDone(q.ID) {
		t.Fatal("declined request not marked")
	}
	// a later request does not ask again after "no"
	q.ID = "def456"
	if res := s.Run(q); res.State != "declined" || asked != 1 {
		t.Fatalf("asked again: %d", asked)
	}
	// yes: downloads, runs, writes
	app.state.SetSimConsent("", "")
	answer = true
	q.ID = "ghi789"
	res := s.Run(q)
	if res.State != "done" || asked != 2 || !simc.Installed() || res.Weights["Int"] != 1 {
		t.Fatalf("run: %+v", res)
	}
	if !contains(gotArgs, "json2=report.json") || !contains(gotArgs, "input.simc") {
		t.Fatalf("args: %q", gotArgs)
	}
	got := readPrevious(ResultsFile(retail))
	if len(got) != 3 {
		t.Fatalf("results file: %d", len(got))
	}
	if ans, _ := app.state.SimConsent(); ans != "yes" {
		t.Fatal("consent not stored")
	}
}

// TestResultsFixture keeps testdata/sim_results.lua (which the addon's smoke test imports) in step with the
// writer, so the Go and Lua sides agree on the file format. UPDATE_FIXTURES=1 rewrites it.
func TestResultsFixture(t *testing.T) {
	results := []SimResult{
		{ID: "68f8e510c0ffee", State: "done", Finished: 1761130000, Seconds: 2.43, Mode: "compare", Char: "Tester-Realm",
			Spec: "frost", Simc: "1205-01", DPS: 228081.4, DPSError: 151.2,
			Fight: SimFight{Style: "Patchwerk", Length: 300, Targets: 1},
			Sets: []SimSetResult{
				{Label: "Equipped", DPS: 228081.4},
				{Label: "Band of | Tests", DPS: 229041.2, Delta: 959.8, Pct: 0.4208, Keys: []string{"212400:1520:10390:11977"}},
			},
			Items: map[string]SimSetResult{"212400:1520:10390:11977": {DPS: 229041.2, Delta: 959.8, Pct: 0.4208}}},
		{ID: "68f8b9c0000001", State: "failed", Error: "Player has no talents | check the export", Finished: 1761120000,
			Seconds: 0.4, Mode: "gear", Char: "Tester-Realm"},
	}
	got := RenderResults(results, time.Unix(1761130001, 0))
	path := filepath.Join("testdata", "sim_results.lua")
	if os.Getenv("UPDATE_FIXTURES") == "1" {
		if err := os.WriteFile(path, []byte(got), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	want, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	if string(want) != got {
		t.Fatalf("testdata/sim_results.lua is stale; run UPDATE_FIXTURES=1 go test ./...\n%s", got)
	}
}

// TestAddonRequest reads a request exactly as the addon writes it (testdata/sim_request.lua is produced by the
// addon's smoke test from its real export code) and plans it.
func TestAddonRequest(t *testing.T) {
	reqs, bad, err := ReadSimRequests(filepath.Join("testdata", "sim_request.lua"), "retail")
	if err != nil || len(bad) != 0 || len(reqs) != 1 {
		t.Fatalf("reqs %+v bad %v err %v", reqs, bad, err)
	}
	r := reqs[0]
	if r.ID != "68f8e510c0ffee" || r.Char != "Tester-Realm" || r.Mode != "compare" || len(r.Items) != 1 || r.Items[0].Key != "212400:1520:10390:11977" {
		t.Fatalf("request: %+v", r)
	}
	p, err := BuildPlan(r)
	if err != nil {
		t.Fatal(err)
	}
	if len(p.Sets) != 2 {
		t.Fatalf("a ring should compare in both finger slots: %+v", p.Sets)
	}
	for _, want := range []string{`mage="Tester"`, "spec=fire", "race=void_elf",
		`profileset."i1_2"+=finger2=,id=212400,enchant_id=7334,gem_id=213743,bonus_id=10390/11977/1520,drop_level=90,crafted_stats=36,crafting_quality=5`} {
		if !strings.Contains(p.Input, want) {
			t.Errorf("input lacks %q:\n%s", want, p.Input)
		}
	}
}
