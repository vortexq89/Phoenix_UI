"""POSTs contract v2 uploads to the Incident Service. The ingest key comes
from the config file or PHOENIX_INGEST_KEY and is never printed or logged."""
import json
import urllib.error
import urllib.request

from . import VERSION

BATCH = 100


class UploadError(RuntimeError):
    pass


def post(endpoint, key, payload, timeout=20, opener=None):
    body = json.dumps(payload, separators=(",", ":")).encode("utf-8")
    req = urllib.request.Request(endpoint, data=body, method="POST", headers={
        "content-type": "application/json", "x-phoenix-key": key, "user-agent": "sentinel-companion/" + VERSION})
    try:
        with (opener or urllib.request.urlopen)(req, timeout=timeout) as res:
            return json.loads(res.read().decode("utf-8") or "{}")
    except urllib.error.HTTPError as e:
        detail = ""
        try:
            detail = json.loads(e.read().decode("utf-8")).get("error", "")
        except ValueError:
            pass
        raise UploadError("HTTP %d %s" % (e.code, detail)) from None
    except urllib.error.URLError as e:
        raise UploadError("network: %s" % e.reason) from None


def send(endpoint, key, payload, opener=None):
    """Sends in batches; returns the merged result counts."""
    total = {"accepted": 0, "updated": 0, "duplicates": 0, "rejected": [], "heartbeats": 0, "tests": 0}
    reports = payload["reports"]
    for i in range(0, max(1, len(reports)), BATCH):
        part = dict(payload, reports=reports[i:i + BATCH])
        r = post(endpoint, key, part, opener=opener)
        for k in ("accepted", "updated", "duplicates", "heartbeats", "tests"):
            total[k] += int(r.get(k) or 0)
        total["rejected"] += r.get("rejected") or []
    return total
