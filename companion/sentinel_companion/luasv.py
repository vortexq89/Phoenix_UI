"""Reader for WoW SavedVariables files (a restricted Lua table syntax).

Supports what the client writes: top-level `Name = value` assignments, tables
with ["key"] = v, [n] = v and positional values, strings with Lua escapes,
numbers (incl. hex and inf/nan spellings), true/false/nil, and -- comments.
"""
import re

_NUM = re.compile(r"-?(?:0[xX][0-9a-fA-F]+|(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?)")
_NAME = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
_ESC = {"n": "\n", "t": "\t", "r": "\r", "a": "\a", "b": "\b", "f": "\f", "v": "\v", "\\": "\\", '"': '"', "'": "'", "\n": "\n"}


class LuaParseError(ValueError):
    pass


class _Reader:
    def __init__(self, text):
        self.s = text
        self.i = 0

    def error(self, msg):
        line = self.s.count("\n", 0, self.i) + 1
        raise LuaParseError("%s at line %d" % (msg, line))

    def ws(self):
        s, n = self.s, len(self.s)
        while self.i < n:
            c = s[self.i]
            if c in " \t\r\n":
                self.i += 1
            elif s.startswith("--", self.i):
                if s.startswith("--[[", self.i):
                    end = s.find("]]", self.i)
                    self.i = n if end < 0 else end + 2
                else:
                    end = s.find("\n", self.i)
                    self.i = n if end < 0 else end + 1
            else:
                break

    def peek(self):
        self.ws()
        return self.s[self.i] if self.i < len(self.s) else ""

    def expect(self, ch):
        if self.peek() != ch:
            self.error("expected %r" % ch)
        self.i += 1

    def string(self):
        q = self.s[self.i]
        self.i += 1
        out = []
        s = self.s
        while True:
            if self.i >= len(s):
                self.error("unterminated string")
            c = s[self.i]
            if c == q:
                self.i += 1
                return "".join(out)
            if c == "\\":
                nxt = s[self.i + 1] if self.i + 1 < len(s) else ""
                if nxt.isdigit():
                    m = re.match(r"\d{1,3}", s[self.i + 1:])
                    out.append(chr(int(m.group(0)) & 0xFF))
                    self.i += 1 + len(m.group(0))
                elif nxt in _ESC:
                    out.append(_ESC[nxt])
                    self.i += 2
                else:
                    self.error("bad escape")
            else:
                out.append(c)
                self.i += 1

    def value(self):
        c = self.peek()
        if not c:
            self.error("unexpected end of file")
        if c == "{":
            return self.table()
        if c in "\"'":
            return self.string()
        if self.s.startswith("[[", self.i):
            end = self.s.find("]]", self.i)
            v = self.s[self.i + 2:end]
            self.i = end + 2
            return v
        m = _NAME.match(self.s, self.i)
        if m:
            word = m.group(0)
            self.i = m.end()
            if word == "true":
                return True
            if word == "false":
                return False
            if word == "nil":
                return None
            self.error("unexpected name %r" % word)
        m = _NUM.match(self.s, self.i)
        if m:
            self.i = m.end()
            t = m.group(0)
            if "x" in t.lower():
                return int(t, 16)
            v = float(t)
            return int(v) if v.is_integer() and not re.search(r"[.eE]", t) else v
        if self.s.startswith("math.huge", self.i):
            self.i += 9
            return float("inf")
        self.error("unexpected character %r" % c)

    def table(self):
        self.expect("{")
        out, pos = {}, 1
        while True:
            c = self.peek()
            if not c:
                self.error("unterminated table")
            if c == "}":
                self.i += 1
                break
            if c == "[" and not self.s.startswith("[[", self.i):
                self.i += 1
                key = self.value()
                self.expect("]")
                self.expect("=")
                out[key] = self.value()
            else:
                m = _NAME.match(self.s, self.i)
                save = self.i
                if m and m.group(0) not in ("true", "false", "nil"):
                    self.i = m.end()
                    if self.peek() == "=":
                        self.i += 1
                        out[m.group(0)] = self.value()
                    else:
                        self.i = save
                        out[pos] = self.value()
                        pos += 1
                else:
                    out[pos] = self.value()
                    pos += 1
            c = self.peek()
            if c in ",;":
                self.i += 1
            elif c != "}":
                self.error("expected ',' or '}'")
        return out


def loads(text):
    """Parses a SavedVariables file; returns {global name: value}."""
    r = _Reader(text)
    result = {}
    while r.peek():
        m = _NAME.match(r.s, r.i)
        if not m:
            r.error("expected an assignment")
        r.i = m.end()
        r.expect("=")
        result[m.group(0)] = r.value()
    return result


def as_list(t):
    """A Lua array table (dict with 1..n keys) as a Python list; {} -> []."""
    if isinstance(t, list):
        return t
    if not isinstance(t, dict):
        return []
    return [t[k] for k in sorted(k for k in t if isinstance(k, int))]
