"""sentinel-companion [once|watch|status|decode <string>|send-export <string>|fixed-string [file.json]] [--config PATH] [--dry-run]"""
import argparse
import json
import os
import sys
import time

from . import VERSION, exportstring, fixedin
from .config import Config
from .core import run_once
from .state import State
from .upload import UploadError, send


def _mtimes(cfg):
    out = {}
    for p in cfg.saved_variables():
        try:
            out[p] = os.path.getmtime(p)
        except OSError:
            pass
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(prog="sentinel-companion", description="Phoenix UI Sentinel Companion " + VERSION)
    ap.add_argument("command", nargs="?", default="watch", choices=["once", "watch", "status", "decode", "send-export", "fixed-string"])
    ap.add_argument("text", nargs="?", help="a !PUI_SEN string (decode / send-export)")
    ap.add_argument("--config")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args(argv)
    cfg = Config(a.config)
    if a.command == "status":
        print(repr(cfg))
        print("SavedVariables found: %d" % len(cfg.saved_variables()))
        print("reports already sent: %d" % len(State(cfg.state_path).sent))
        return 0
    if a.command == "fixed-string":
        # a JSON file path, or JSON on stdin: prints the string to paste in game
        raw = open(a.text, encoding="utf-8").read() if a.text else sys.stdin.read()
        print(fixedin.build(json.loads(raw)))
        return 0
    if a.command in ("decode", "send-export"):
        payload = exportstring.decode(a.text or sys.stdin.read())
        if a.command == "decode":
            print(json.dumps(payload, indent=2, sort_keys=True))
            return 0
        r = send(cfg.endpoint, cfg.ingest_key, payload)
        print("sent: %d new, %d updated, %d rejected" % (r["accepted"], r["updated"], len(r["rejected"])))
        return 0
    try:
        run_once(cfg, dry_run=a.dry_run)
    except UploadError as e:
        print("upload failed: %s (will retry)" % e)
    if a.command == "once":
        return 0
    print("watching %d SavedVariables file(s); Ctrl+C to stop" % len(cfg.saved_variables()))
    seen = _mtimes(cfg)
    while True:
        time.sleep(cfg.interval)
        now = _mtimes(cfg)
        if now != seen:
            seen = now
            time.sleep(1)  # the client writes the file at reload/logout; let it finish
            try:
                run_once(cfg, dry_run=a.dry_run)
            except UploadError as e:
                print("upload failed: %s (will retry on the next change)" % e)


if __name__ == "__main__":
    sys.exit(main())
