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

// "Send error reports to the author" off in the addon: nothing is sent for that account, and what was caught
// while it was off stays unsent after it is switched back on. A missing flag (older addon builds) means on.
func TestShareFlag(t *testing.T) {
	fixture, _ := os.ReadFile(filepath.Join("testdata", "Phoenix_UI.lua"))
	off := strings.Replace(string(fixture), `["schema"] = 1,`, `["schema"] = 1,`+"\n\t[\"share\"] = false,", 1)
	on := strings.Replace(string(fixture), `["schema"] = 1,`, `["schema"] = 1,`+"\n\t[\"share\"] = true,", 1)
	dir := t.TempDir()
	for name, src := range map[string]string{"missing": string(fixture), "on": on, "off": off} {
		p := filepath.Join(dir, name+".lua")
		_ = os.WriteFile(p, []byte(src), 0o644)
		db, err := ReadBugsDB(p)
		if err != nil || db.Share != (name != "off") {
			t.Fatalf("%s: share=%v err=%v", name, db != nil && db.Share, err)
		}
	}

	var sent int
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var b uploadBody
		raw, _ := io.ReadAll(r.Body)
		_ = json.Unmarshal(raw, &b)
		sent += len(b.Reports)
		_, _ = w.Write([]byte(`{"ok":true,"accepted":` + itoa(len(b.Reports)) + `,"updated":0,"duplicates":0,"rejected":[]}`))
	}))
	defer srv.Close()
	root := t.TempDir()
	sv := filepath.Join(root, "_retail_", "WTF", "Account", "ACCOUNT1", "SavedVariables")
	_ = os.MkdirAll(sv, 0o755)
	file := filepath.Join(sv, "Phoenix_UI.lua")
	_ = os.WriteFile(file, []byte(off), 0o644)
	data := t.TempDir()
	app, err := NewApp(data, NewLogger(data, nil), []string{filepath.Join(root, "_retail_")}, srv.URL, "k", false)
	if err != nil {
		t.Fatal(err)
	}
	if s := app.Cycle(true); s.Err != nil || sent != 0 || s.OptedOut != 1 {
		t.Fatalf("opted out: %+v sent %d", s, sent)
	}
	log, _ := os.ReadFile(filepath.Join(data, "uploader.log"))
	if !strings.Contains(string(log), "is off in Phoenix UI") {
		t.Fatalf("opt-out not logged: %s", log)
	}
	_ = os.WriteFile(file, []byte(on), 0o644)
	if s := app.Cycle(true); s.Err != nil || sent != 0 {
		t.Fatalf("reports caught while off must stay unsent: %+v sent %d", s, sent)
	}
	_ = os.WriteFile(file, []byte(strings.Replace(on, `["count"] = 12,`, `["count"] = 13,`, 1)), 0o644)
	if s := app.Cycle(true); s.Err != nil || sent != 1 {
		t.Fatalf("new activity after switching on is sent: %+v sent %d", s, sent)
	}
}

func TestScrubber(t *testing.T) {
	acct := filepath.Join(t.TempDir(), "WTF", "Account", "MYACCOUNT")
	_ = os.MkdirAll(filepath.Join(acct, "Twisting Nether", "Vortexq"), 0o755)
	_ = os.MkdirAll(filepath.Join(acct, "SavedVariables"), 0o755)
	s := NewScrubber(filepath.Join(acct, "SavedVariables", "Phoenix_UI.lua"))
	r := s.Report(Report{
		Message: `Vortexq-Twisting Nether: Player-1305-0B1C2D3E Vortexqs Me#12345 C:\Users\Vorte\WTF\Account\MYACCOUNT\x MYACCOUNT`,
		Stack:   "Interface/AddOns/Foo/Foo.lua:1: in function `Vortexq`",
		Locals:  "unit = \"player\"\nmsg = \"meet me at the bank\"\nwho = \"Vortexq\"\nn = 3\nkept = \"<text, 9 bytes>\"",
	})
	for _, bad := range []string{"Vortexq-", "Twisting", "0B1C2D3E", "Me#", "Vorte\\", "MYACCOUNT"} {
		if strings.Contains(r.Message, bad) {
			t.Fatalf("%q left in %q", bad, r.Message)
		}
	}
	if !strings.Contains(r.Message, "Vortexqs") || !strings.Contains(r.Stack, "`<player>`") {
		t.Fatalf("whole words only: %q / %q", r.Message, r.Stack)
	}
	want := "unit = \"player\"\nmsg = \"<text, 19 bytes>\"\nwho = \"<player>\"\nn = 3\nkept = \"<text, 9 bytes>\""
	if r.Locals != want {
		t.Fatalf("locals:\n%s", r.Locals)
	}
}
