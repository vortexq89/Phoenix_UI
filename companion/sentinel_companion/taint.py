"""Attaches the matching Logs/taint.log section to taint incidents (PUI_V2 16.4)."""
import os

MAX_BYTES = 6000


def read_tail(path, limit=512 * 1024):
    if not path or not os.path.exists(path):
        return ""
    with open(path, "rb") as fh:
        fh.seek(0, os.SEEK_END)
        size = fh.tell()
        fh.seek(max(0, size - limit))
        return fh.read().decode("utf-8", "replace")


def section_for(log_text, report):
    """Lines that mention Phoenix UI near the incident's message, newest last."""
    if not log_text:
        return ""
    lines = log_text.splitlines()
    msg = (report.get("message") or "").split("\n")[0]
    probe = [w for w in msg.replace(":", " ").split() if len(w) > 6][:3]
    hits = []
    for i, line in enumerate(lines):
        if "Phoenix_UI" in line or any(p in line for p in probe):
            hits.extend(range(max(0, i - 2), min(len(lines), i + 3)))
    if not hits:
        return ""
    keep = sorted(set(hits))
    out = "\n".join(lines[i] for i in keep)
    return out[-MAX_BYTES:]


def attach(payload, log_text):
    n = 0
    for r in payload["reports"]:
        if r.get("kind") == "taint":
            sec = section_for(log_text, r)
            if sec:
                r["locals"] = ((r.get("locals") or "") + "\n--- taint.log ---\n" + sec).strip()
                n += 1
    return n
