package main

import (
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func signed(t *testing.T, priv ed25519.PrivateKey, payload string) []byte {
	b, _ := json.Marshal(map[string]string{"alg": "ed25519", "keyId": "t", "payload": payload, "sig": base64.StdEncoding.EncodeToString(ed25519.Sign(priv, []byte(payload)))})
	return b
}

func TestVerifyFixed(t *testing.T) {
	pub, priv, _ := ed25519.GenerateKey(rand.Reader)
	payload := `{"v":1,"kind":"fixed-in","generatedAt":1,"fixed":[{"hash":"ABCDEF12","fixedIn":"2.0.1"},{"hash":"abcdef12","fixedIn":"2.0.2"},{"hash":"zz","fixedIn":"1"},{"hash":"12345678","fixedIn":"bad version"}]}`
	rows, err := VerifyFixed(signed(t, priv, payload), pub)
	if err != nil || len(rows) != 1 || rows[0] != (FixedRow{"abcdef12", "2.0.1"}) {
		t.Fatalf("rows %v err %v", rows, err)
	}
	bad := signed(t, priv, payload)
	bad = []byte(strings.Replace(string(bad), "2.0.1", "9.9.9", 1))
	if _, err := VerifyFixed(bad, pub); err == nil {
		t.Fatal("tampered list accepted")
	}
	other, _, _ := ed25519.GenerateKey(rand.Reader)
	if _, err := VerifyFixed(signed(t, priv, payload), other); err == nil {
		t.Fatal("wrong key accepted")
	}
	if len(publicKey()) != ed25519.PublicKeySize {
		t.Fatal("embedded public key is not a 32-byte Ed25519 key")
	}
}

func TestFixedSumMatchesSentinel(t *testing.T) {
	// Same rows and value as the Lua test in Phoenix_UI_Sentinel/Tests (Adler-32 of "hash=version;" pairs).
	rows := []FixedRow{{"aaaaaaaa11111111", "2.0.3"}, {"bbbbbbbb22222222", "2.0.4"}}
	if got := FixedSum(rows); got != 0x2f560c04 {
		t.Fatalf("sum %x", got)
	}
}

func TestWriteFixed(t *testing.T) {
	dir := t.TempDir()
	p := filepath.Join(dir, "Phoenix_UI_Sentinel.lua")
	orig := "\nPhoenixUISentinelDB = {\n[\"installId\"] = \"0123456789abcdef\",\n}\nPhoenixUISentinelFixed = nil\n"
	os.WriteFile(p, []byte(orig), 0o644)
	rows := []FixedRow{{"aaaaaaaa11111111", "2.0.3"}}
	wrote, err := WriteFixed(p, rows, 100)
	if err != nil || !wrote {
		t.Fatalf("wrote %v err %v", wrote, err)
	}
	b, _ := os.ReadFile(p)
	if strings.Count(string(b), "PhoenixUISentinelFixed = ") != 1 || !strings.Contains(string(b), `["hash"]="aaaaaaaa11111111"`) {
		t.Fatalf("file:\n%s", b)
	}
	if bak, _ := os.ReadFile(p + ".phoenix-bak"); string(bak) != orig {
		t.Fatal("recovery copy missing")
	}
	vars, err := ParseSavedVariables(string(b))
	if err != nil || vars["PhoenixUISentinelDB"] == nil || vars["PhoenixUISentinelFixed"] == nil {
		t.Fatalf("file no longer parses: %v", err)
	}
	if wrote, _ := WriteFixed(p, rows, 200); wrote {
		t.Fatal("same list written twice")
	}
	if _, err := os.Stat(p + ".phoenix-tmp"); err == nil {
		t.Fatal("staged file left behind")
	}
}

func TestFixedURLAndExe(t *testing.T) {
	if FixedURL("https://vq8s.com/phoenix/api/ingest") != "https://vq8s.com/phoenix/api/fixed" {
		t.Fatal("url")
	}
	for n, want := range map[string]bool{"Wow.exe": true, "WowT.exe": true, "WowClassic.exe": true, "Wowhead.txt": false, "explorer.exe": false} {
		if isWowExe(n) != want {
			t.Fatalf("%s", n)
		}
	}
}
