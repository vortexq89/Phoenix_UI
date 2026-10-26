"""Decodes a "!PUI_SEN" export string (JSON -> deflate -> base64, as written by
C_EncodingUtil in Phoenix_UI_Sentinel/Export.lua) into the contract v2 payload."""
import base64
import json
import zlib

PREFIX = "!PUI_SEN"


def decode(text):
    text = (text or "").strip()
    if not text.startswith(PREFIX):
        raise ValueError("not a !PUI_SEN string")
    raw = base64.b64decode(text[len(PREFIX):] + "=" * (-len(text[len(PREFIX):]) % 4))
    for wbits in (-15, 15, 31):
        try:
            return json.loads(zlib.decompress(raw, wbits).decode("utf-8"))
        except zlib.error:
            continue
    raise ValueError("bad compressed data")


def encode(payload, wbits=-15):
    c = zlib.compressobj(9, zlib.DEFLATED, wbits)
    data = c.compress(json.dumps(payload, sort_keys=True).encode("utf-8")) + c.flush()
    return PREFIX + base64.b64encode(data).decode("ascii")
