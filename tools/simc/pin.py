#!/usr/bin/env python3
"""Pin a SimulationCraft nightly for the Phoenix app (uploader/simc.json).

SimulationCraft publishes no checksums or signatures for its Windows nightlies, and downloads.simulationcraft.org
serves them over plain HTTP. The trust anchor is GitHub itself: the official build workflow
(simulationcraft/simc-publish, "Nightly") uploads each .7z as an Actions artifact, and GitHub records a SHA-256
digest of every artifact. This tool

  1. finds the artifact (newest successful Nightly run, or --artifact ID) through the GitHub API (gh CLI),
  2. downloads it and checks GitHub's digest,
  3. hashes the .7z inside it and the simc.exe inside that (py7zr),
  4. writes the entry (size and SHA-256 of both) into uploader/simc.json.

The app then refuses any download whose size or SHA-256 differ, whichever mirror it came from.
Usage:  tools/simc/pin.py [--artifact ID] [--wow-build 12.1.5.70448] [--check]
  --check only confirms that the pinned artifact still exists with the pinned digest (no download).
Needs: python3; for pinning also gh (authenticated, artifact downloads need a token) and py7zr (pip install py7zr, in a venv).
"""
import argparse
import datetime
import hashlib
import io
import json
import pathlib
import re
import subprocess
import sys
import shutil
import tempfile
import urllib.error
import urllib.request
import zipfile

REPO = "simulationcraft/simc-publish"
WORKFLOW = "Nightly"
MANIFEST = pathlib.Path(__file__).resolve().parents[2] / "uploader" / "simc.json"
NAME = re.compile(r"^simc-(\d{3,5})\.(\d{2})\.([0-9a-f]{7,12})-win64\.7z$")


def gh(path, raw=False):
    """GitHub API. Metadata is public (plain HTTPS); artifact zips need an authenticated gh CLI."""
    authed = subprocess.run(["gh", "auth", "status"], capture_output=True).returncode == 0 if shutil.which("gh") else False
    if authed:
        out = subprocess.run(["gh", "api", path], check=True, capture_output=True)
        return out.stdout if raw else json.loads(out.stdout)
    if raw:
        sys.exit("downloading an artifact needs an authenticated gh CLI (gh auth login)")
    req = urllib.request.Request(f"https://api.github.com/{path}", headers={"Accept": "application/vnd.github+json"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        sys.exit(f"GitHub API {path}: {e.code} {e.reason} (sign in with gh auth login to avoid rate limits)")


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def find_artifact(artifact_id):
    if artifact_id:
        return gh(f"repos/{REPO}/actions/artifacts/{artifact_id}")
    runs = gh(f"repos/{REPO}/actions/runs?status=success&per_page=30")["workflow_runs"]
    for run in runs:
        if run.get("name") != WORKFLOW:
            continue
        for a in gh(f"repos/{REPO}/actions/runs/{run['id']}/artifacts")["artifacts"]:
            if NAME.match(a["name"]) and not a.get("expired"):
                return a
    sys.exit("no unexpired win64 nightly artifact found")


def check(manifest):
    ok = True
    for b in manifest["builds"]:
        src = b.get("source", {})
        a = gh(f"repos/{REPO}/actions/artifacts/{src['artifactId']}")
        same = a.get("digest") == src.get("artifactDigest") and not a.get("expired")
        ok &= same
        print(f"{b['version']}: artifact {src['artifactId']} {'ok' if same else 'CHANGED OR EXPIRED'} ({a.get('digest')})")
    return ok


def pin(a, wow_build):
    import py7zr  # noqa: PLC0415 (only needed when pinning)

    m = NAME.match(a["name"])
    if not m:
        sys.exit(f"unexpected artifact name {a['name']}")
    blob = gh(f"repos/{REPO}/actions/artifacts/{a['id']}/zip", raw=True)
    digest = "sha256:" + sha256(blob)
    if a.get("digest") and a["digest"] != digest:
        sys.exit(f"artifact digest mismatch: GitHub says {a['digest']}, download is {digest}")
    with zipfile.ZipFile(io.BytesIO(blob)) as z:
        seven = z.read(a["name"])
    base = a["name"][: -len(".7z")]
    with tempfile.TemporaryDirectory() as tmp:
        with py7zr.SevenZipFile(io.BytesIO(seven)) as arc:
            arc.extract(path=tmp, targets=[f"{base}/simc.exe"])
        exe = (pathlib.Path(tmp) / base / "simc.exe").read_bytes()
    return {
        "version": f"{m.group(1)}-{m.group(2)}",
        "commit": m.group(3),
        "wowBuild": wow_build,
        "file": a["name"],
        "url": f"http://downloads.simulationcraft.org/nightly/{a['name']}",
        "size": len(seven),
        "sha256": sha256(seven),
        "exe": f"{base}/simc.exe",
        "exeSize": len(exe),
        "exeSha256": sha256(exe),
        "license": f"{base}/COPYING",
        "source": {"repo": REPO, "workflow": WORKFLOW, "artifactId": a["id"], "artifactDigest": digest},
        "verified": datetime.date.today().isoformat(),
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--artifact", type=int, help="artifact ID (default: newest successful Nightly)")
    ap.add_argument("--wow-build", default="12.1.5.70448", help="WoW build the nightly targets")
    ap.add_argument("--check", action="store_true", help="only confirm the pinned artifacts are unchanged")
    args = ap.parse_args()
    manifest = json.loads(MANIFEST.read_text())
    if args.check:
        sys.exit(0 if check(manifest) else 1)
    entry = pin(find_artifact(args.artifact), args.wow_build)
    manifest["builds"] = [entry] + [b for b in manifest["builds"] if b["version"] != entry["version"]][:2]
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"pinned {entry['file']}: {entry['size']} bytes, sha256 {entry['sha256']}")


if __name__ == "__main__":
    main()
