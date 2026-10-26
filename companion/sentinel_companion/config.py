"""Companion settings: a JSON file (default %APPDATA%/PhoenixSentinel/config.json
or ~/.config/phoenix-sentinel/config.json). Keys:
  wowPath   - the game flavour folder, e.g. D:/Games/World of Warcraft/_retail_
  endpoint  - default https://vq8s.com/phoenix/api/ingest
  ingestKey - X-Phoenix-Key (or the PHOENIX_INGEST_KEY environment variable)
  interval  - seconds between checks in watch mode (default 5)
"""
import glob
import json
import os

DEFAULT_ENDPOINT = "https://vq8s.com/phoenix/api/ingest"
SV_NAME = "Phoenix_UI_Sentinel.lua"


def default_dir():
    base = os.environ.get("APPDATA") or os.path.join(os.path.expanduser("~"), ".config")
    return os.path.join(base, "PhoenixSentinel" if os.environ.get("APPDATA") else "phoenix-sentinel")


class Config:
    def __init__(self, path=None):
        self.path = path or os.path.join(default_dir(), "config.json")
        data = {}
        if os.path.exists(self.path):
            with open(self.path, encoding="utf-8") as fh:
                data = json.load(fh)
        self.wow_path = data.get("wowPath", "")
        self.endpoint = data.get("endpoint", DEFAULT_ENDPOINT)
        self._key = data.get("ingestKey") or os.environ.get("PHOENIX_INGEST_KEY", "")
        self.interval = float(data.get("interval", 5))
        self.state_path = os.path.join(os.path.dirname(self.path), "state.json")

    @property
    def ingest_key(self):
        return self._key

    def key_status(self):
        """For display: never the key itself."""
        return "set" if len(self._key) >= 8 else "missing"

    def saved_variables(self):
        if not self.wow_path:
            return []
        pattern = os.path.join(self.wow_path, "WTF", "Account", "*", "SavedVariables", SV_NAME)
        return sorted(glob.glob(pattern))

    def taint_log(self):
        return os.path.join(self.wow_path, "Logs", "taint.log") if self.wow_path else ""

    def __repr__(self):
        return "Config(path=%r, wowPath=%r, endpoint=%r, ingestKey=%s)" % (
            self.path, self.wow_path, self.endpoint, self.key_status())
