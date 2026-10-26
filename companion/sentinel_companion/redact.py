"""Defence-in-depth redaction (PUI_V2 16.3/16.4): the addon already strips
personal data; the companion applies the same rules again before upload."""
import re

_RULES = [
    (re.compile(r"(?i)([A-Z]:[\\/]+Users[\\/]+)[^\\/\s\"']+"), r"\1<user>"),
    (re.compile(r"(/home/|/Users/)[^/\s\"']+"), r"\1<user>"),
    (re.compile(r"[\w.+-]+@[\w-]+\.[\w.-]+"), "<email>"),
    (re.compile(r"\b[^\s#|\"'<>]{2,12}#\d{4,5}\b"), "<battletag>"),
    (re.compile(r"(?i)\b(ingestKey|x-phoenix-key|api[_-]?key|token|password)(\s*[=:]\s*)\S+"), r"\1\2<redacted>"),
]


def text(value, names=()):
    if not isinstance(value, str):
        return value
    for rx, rep in _RULES:
        value = rx.sub(rep, value)
    for n in names:
        if n and len(n) >= 2:
            value = re.sub(r"(?<![\w])" + re.escape(n) + r"(?![\w])", "<name>", value)
    return value


def deep(value, names=()):
    if isinstance(value, str):
        return text(value, names)
    if isinstance(value, list):
        return [deep(v, names) for v in value]
    if isinstance(value, dict):
        return {k: deep(v, names) for k, v in value.items()}
    return value
