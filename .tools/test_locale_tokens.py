#!/usr/bin/env python3
"""Self-test for .tools/locale_tokens.py."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
import locale_tokens as T

cases = [
    ("Size %d px", "Размер %d пикс.", []),
    ("%s of %d", "%d из %s", ["specs"]),
    ("%s of %d", "%2$d из %1$s", []),
    ("Use /pui test", "Введите /pui test", []),
    ("Use /pui test", "Введите /пуи", ["slash"]),
    ("a|b", "а б", ["pipes"]),
    ("line\nnext", "строка следующая", ["newlines"]),
    ("|cffff0000Red|r", "|cffff0000Красный|r", []),
    ("50%% more", "на 50%% больше", []),
]
fails = 0
for en, tr, want in cases:
    got = T.compare(en, tr)
    if got != want:
        fails += 1
        print("FAIL", en, tr, got, want)
print("locale tokens self-test: %s" % ("FAIL" if fails else "ok"))
sys.exit(1 if fails else 0)
