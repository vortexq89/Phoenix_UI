package main

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestParseSavedVariablesShapes(t *testing.T) {
	src := "\ufeffA = {\r\n [\"s\"] = \"q\\\"\\\\\\n\\65\\x42\\u{263A}\\z   x\", -- comment\n" +
		" [1] = 1, 2, name = true, [\"nilled\"] = nil, [ [[k]] ] = [==[\nlong ]] \"string\"]==],\n" +
		" --[[ block\n comment ]] neg = - 3.5e2, hex = 0x1F, t = { { 1, 2 }; {} },\n}\nB = 'single'\n;C = false"
	v, err := ParseSavedVariables(src)
	if err != nil {
		t.Fatal(err)
	}
	a := v["A"].(*Table)
	if got := a.Hash["s"]; got != "q\"\\\nAB\u263Ax" {
		t.Fatalf("escapes: %q", got)
	}
	if a.Array[0] != 2.0 || a.Hash["1"] != 1.0 || a.Hash["name"] != true || a.Hash["neg"] != -350.0 || a.Hash["hex"] != 31.0 {
		t.Fatalf("values: %#v %#v", a.Array, a.Hash)
	}
	if _, ok := a.Hash["nilled"]; ok {
		t.Fatal("nil fields must be absent")
	}
	if a.Hash["k"] != "long ]] \"string\"" {
		t.Fatalf("long string: %q", a.Hash["k"])
	}
	if len(a.Hash["t"].(*Table).Array) != 2 || v["B"] != "single" || v["C"] != false {
		t.Fatal("nested / top level")
	}
	if l := a.List(); len(l) != 1 || l[0] != 2.0 { // Lua: the positional 2 is index 1 and wins over [1] = 1
		t.Fatalf("list: %v", l)
	}
}

func TestParseRejectsCodeAndJunk(t *testing.T) {
	for _, src := range []string{
		"A = os.execute('x')", "A = { f() }", "A = {", "A = \"unterminated", "A = 1 +", "= 3", "A = {[{}] = 1}",
		"A = " + strings.Repeat("{", maxDepth+2) + strings.Repeat("}", maxDepth+2),
	} {
		if _, err := ParseSavedVariables(src); err == nil {
			t.Errorf("accepted %q", src)
		}
	}
}

func TestReadBugsDBFixture(t *testing.T) {
	db, err := ReadBugsDB(filepath.Join("testdata", "Phoenix_UI.lua"))
	if err != nil {
		t.Fatal(err)
	}
	if db.Schema != 1 || db.InstallID != "7f3a9c2e5b1d4e60" || len(db.Reports) != 5 || db.Skipped != 0 {
		t.Fatalf("%+v", db)
	}
	r := db.Reports[4]
	if r.Source != "WeakAuras" || r.Count != 12 || r.Interface != 120105 || r.Locale != "deDE" || !strings.Contains(r.Locals, "\\ escaped backslash and \"quotes\"") {
		t.Fatalf("%+v", r)
	}
	b, _ := json.Marshal(r)
	if strings.Contains(string(b), "uploaded") {
		t.Fatal("the uploaded flag must not travel")
	}
}

func TestStatePendingOnlyNewOrGrown(t *testing.T) {
	s := LoadState(t.TempDir())
	rs := []Report{{ID: "a", Count: 1}, {ID: "b", Count: 2}}
	if len(s.Pending(rs)) != 2 {
		t.Fatal("fresh")
	}
	s.MarkSent(rs)
	if len(s.Pending(rs)) != 0 {
		t.Fatal("sent")
	}
	rs[1].Count = 5
	if p := s.Pending(rs); len(p) != 1 || p[0].ID != "b" {
		t.Fatalf("grown: %v", p)
	}
	if err := s.Save(); err != nil {
		t.Fatal(err)
	}
	if again := LoadState(filepath.Dir(s.path)); again.Sent["a"].Count != 1 {
		t.Fatal("round trip")
	}
}

func TestBatches(t *testing.T) {
	var rs []Report
	for i := 0; i < 250; i++ {
		rs = append(rs, Report{ID: "x", Message: "m"})
	}
	if b := Batches(rs); len(b) != 3 || len(b[0]) != 100 || len(b[2]) != 50 {
		t.Fatalf("by count: %d", len(b))
	}
	big := []Report{{Stack: strings.Repeat("s", 400<<10)}, {Stack: strings.Repeat("s", 400<<10)}}
	if b := Batches(big); len(b) != 2 {
		t.Fatalf("by size: %d", len(b))
	}
}

func TestEndpointPolicy(t *testing.T) {
	for _, ok := range []string{"https://vq8s.com/phoenix/api/ingest", "http://127.0.0.1:8787/phoenix/api/ingest", "http://localhost:8787/x"} {
		if CheckEndpoint(ok) != nil {
			t.Error(ok)
		}
	}
	for _, bad := range []string{"http://vq8s.com/phoenix/api/ingest", "ftp://x", "not a url"} {
		if CheckEndpoint(bad) == nil {
			t.Error(bad)
		}
	}
}

func TestRetailDetection(t *testing.T) {
	root := t.TempDir()
	wow := filepath.Join(root, "World of Warcraft")
	_ = os.MkdirAll(filepath.Join(wow, "_retail_", "WTF"), 0o755)
	got := DetectRetail([]string{wow, filepath.Join(wow, "_retail_"), filepath.Join(root, "nothing")})
	if len(got) != 1 || filepath.Base(got[0]) != "_retail_" {
		t.Fatalf("%v", got)
	}
	cfg := []byte(`{"Client":{"Install":{"DefaultInstallPath":"D:\\Games\\ALL GAMES"}},"x":"D:\\Games\\ALL GAMES\\World of Warcraft\\_retail_"}`)
	if p := pathsInText(cfg); len(p) != 1 || !strings.HasSuffix(p[0], `ALL GAMES\World of Warcraft`) {
		t.Fatalf("battle.net config: %q", p)
	}
}

// One full pass against a fake server: everything is sent once, a re-run sends nothing, a grown count is re-sent.
func TestCycleEndToEnd(t *testing.T) {
	var got []uploadBody
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("X-Phoenix-Key") != "k-123456789" {
			w.WriteHeader(403)
			return
		}
		var b uploadBody
		raw, _ := io.ReadAll(r.Body)
		_ = json.Unmarshal(raw, &b)
		got = append(got, b)
		_, _ = w.Write([]byte(`{"ok":true,"accepted":` + itoa(len(b.Reports)) + `,"updated":0,"duplicates":0,"rejected":[]}`))
	}))
	defer srv.Close()
	root := t.TempDir()
	sv := filepath.Join(root, "_retail_", "WTF", "Account", "ACCOUNT1", "SavedVariables")
	_ = os.MkdirAll(sv, 0o755)
	fixture, _ := os.ReadFile(filepath.Join("testdata", "Phoenix_UI.lua"))
	_ = os.WriteFile(filepath.Join(sv, "Phoenix_UI.lua"), fixture, 0o644)
	data := t.TempDir()
	app, err := NewApp(data, NewLogger(data, nil), []string{filepath.Join(root, "_retail_")}, srv.URL, "k-123456789", false)
	if err != nil {
		t.Fatal(err)
	}
	if s := app.Cycle(true); s.Err != nil || s.Accepted != 5 || len(got) != 1 || got[0].InstallID != "7f3a9c2e5b1d4e60" || got[0].Schema != 1 {
		t.Fatalf("first: %+v %d", s, len(got))
	}
	if s := app.Cycle(true); s.Pending != 0 || len(got) != 1 {
		t.Fatalf("second: %+v", s)
	}
	grown := strings.Replace(string(fixture), `["count"] = 12,`, `["count"] = 20,`, 1)
	_ = os.WriteFile(filepath.Join(sv, "Phoenix_UI.lua"), []byte(grown), 0o644)
	if s := app.Cycle(true); s.Pending != 1 || len(got) != 2 || got[1].Reports[0].Count != 20 {
		t.Fatalf("grown: %+v", s)
	}
	app.up.Key = "wrong"
	_ = os.WriteFile(filepath.Join(sv, "Phoenix_UI.lua"), []byte(strings.Replace(grown, `["count"] = 20,`, `["count"] = 21,`, 1)), 0o644)
	if s := app.Cycle(true); s.Err == nil {
		t.Fatal("a refused key must surface")
	}
}

func itoa(n int) string { b, _ := json.Marshal(n); return string(b) }

func TestSentinelOutboxCarriesFlavorAndAddons(t *testing.T) {
	db, err := ReadSentinel(filepath.Join("testdata", "Phoenix_UI_Sentinel.lua"))
	if err != nil || db == nil {
		t.Fatalf("read: %v", err)
	}
	if !db.OptIn || db.Flavor != "forever" || db.Session != 9 || len(db.Reports) != 1 || len(db.Addons) != 1 {
		t.Fatalf("parsed %+v", db)
	}
	body, err := SentinelBody(db, db.Reports)
	if err != nil {
		t.Fatal(err)
	}
	var back map[string]any
	_ = json.Unmarshal(body, &back)
	if back["schema"].(float64) != 2 || back["flavor"] != "forever" {
		t.Fatalf("body %s", body)
	}
	a := back["addons"].([]any)[0].(map[string]any)
	if a["name"] != "WeakAuras" || a["enabled"] != true {
		t.Fatalf("addons %v", back["addons"])
	}
	r := back["reports"].([]any)[0].(map[string]any)
	if r["id"] != "aa11bb22cc33dd44-9-123" || r["context"].(map[string]any)["zone"] != "Elwynn" {
		t.Fatalf("report %v", r)
	}
	if asReport(db.Reports[0]).Count != 3 {
		t.Fatal("count")
	}
}

func TestSentinelFilesFindsSiblingClients(t *testing.T) {
	root := t.TempDir()
	for _, c := range []string{"_retail_", "_forever_"} {
		d := filepath.Join(root, c, "WTF", "Account", "ACC", "SavedVariables")
		_ = os.MkdirAll(d, 0o755)
		_ = os.WriteFile(filepath.Join(d, "Phoenix_UI_Sentinel.lua"), []byte("PhoenixUISentinelDB = {}"), 0o644)
	}
	got := SentinelFiles(filepath.Join(root, "_retail_"))
	if len(got) != 2 {
		t.Fatalf("got %v", got)
	}
}
