"""What has been sent already: report id -> count. A report is sent again only when its count grew."""
import json
import os


class State:
    def __init__(self, path):
        self.path = path
        self.sent = {}
        if os.path.exists(path):
            with open(path, encoding="utf-8") as fh:
                self.sent = json.load(fh).get("sent", {})

    def pending(self, reports):
        return [r for r in reports if self.sent.get(r["id"], -1) < (r.get("count") or 1)]

    def mark(self, reports):
        for r in reports:
            self.sent[r["id"]] = r.get("count") or 1

    def save(self):
        os.makedirs(os.path.dirname(self.path) or ".", exist_ok=True)
        tmp = self.path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump({"sent": self.sent}, fh)
        os.replace(tmp, self.path)
