"""Local build: python3 companion/build.py -> companion/dist/sentinel-companion-<version>.pyz
(stdlib zipapp; needs only Python 3.9+). With --exe and PyInstaller installed it also
writes a one-file Windows exe to companion/dist/. Nothing is published."""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile
import zipapp

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from sentinel_companion import VERSION  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--exe", action="store_true")
    a = ap.parse_args()
    dist = os.path.join(HERE, "dist")
    os.makedirs(dist, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        shutil.copytree(os.path.join(HERE, "sentinel_companion"), os.path.join(tmp, "sentinel_companion"),
                        ignore=shutil.ignore_patterns("__pycache__"))
        out = os.path.join(dist, "sentinel-companion-%s.pyz" % VERSION)
        zipapp.create_archive(tmp, out, interpreter="/usr/bin/env python3", main="sentinel_companion.__main__:main")
        print(out)
    if a.exe:
        entry = os.path.join(HERE, "sentinel_companion", "__main__.py")
        subprocess.check_call([sys.executable, "-m", "PyInstaller", "--onefile", "--name", "sentinel-companion-" + VERSION,
                               "--distpath", dist, "--workpath", os.path.join(dist, "build"), "--specpath", os.path.join(dist, "build"),
                               "--paths", HERE, entry])


if __name__ == "__main__":
    main()
