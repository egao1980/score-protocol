"""Check the SC0 fixture scores and generate their music21 oracle files.

    uv run --with music21==10.5.2 python -I tests/fixtures/generate-sc0.py
    uv run --with music21==10.5.2 python -I tests/fixtures/generate-sc0.py --renumber

The fixture scores (sc0-*.sexp except the oracle files below) are hand-built in
the canonical form of src/sexp.lisp. This script is an implementation of the
id rules in src/ids.lisp independent of the Lisp code: it walks each score in
document order and checks that its ids are the ones MAKE-SCORE would mint for
an id-less copy (m-1, m-2, p-3, ...), with :id-counter = the number of elements.
--renumber rewrites the files in place so that they are, inserting and
replacing ids and following references (:tie, :start, :end); the rest of the
text is untouched.

Then it builds every score in music21 (measures appended in order, a pickup as
a short first measure with paddingLeft, grace notes with zero duration) and
writes what music21 computes:
  sc0-bars.sexp      (fixture bar start length time key) per bar
  sc0-events.sexp    (fixture id bar offset absolute) per event
  sc0-anchors.sexp   (fixture id absolute) per chord-symbol anchor
  sc0-pickups.sexp   pickup arithmetic for generated scores (see pickup_cases)
  sc0-uncertain.sexp (fixture below (id...)): elements with confidence < below,
                     in document order
Offsets are in whole notes (music21 quarterLength / 4).
"""

import os
import re
import sys
from fractions import Fraction

HERE = os.path.dirname(os.path.abspath(__file__))
ORACLES = {"sc0-bars.sexp", "sc0-events.sexp", "sc0-anchors.sexp",
           "sc0-pickups.sexp", "sc0-uncertain.sexp"}

# --- s-expressions with source offsets ------------------------------------


class Node:
    """A parsed form: kind is 'list', 'str', 'kw', 'num', 'sym'; value is a
    Python value (a list of Nodes for lists); start/end are text offsets."""

    def __init__(self, kind, value, start, end, tail=None):
        self.kind, self.value, self.start, self.end, self.tail = kind, value, start, end, tail

    def __repr__(self):
        return f"Node({self.kind}, {self.value!r})"


TOKEN = re.compile(r'\s+|;[^\n]*|\(|\)|"(?:[^"\\]|\\.)*"|[^\s()";]+')
NUMBER = re.compile(r'^[+-]?\d+(/\d+)?$|^[+-]?\d*\.\d+$')


def parse(text):
    pos, stack, top = 0, [[]], None
    starts = []
    while pos < len(text):
        m = TOKEN.match(text, pos)
        if not m:
            raise ValueError(f"bad token at {pos}")
        tok, start, pos = m.group(0), m.start(), m.end()
        if tok[0].isspace() or tok[0] == ";":
            continue
        if tok == "(":
            stack.append([])
            starts.append(start)
        elif tok == ")":
            items = stack.pop()
            tail = None
            if len(items) >= 3 and items[-2].kind == "sym" and items[-2].value == ".":
                tail, items = items[-1], items[:-2]
            stack[-1].append(Node("list", items, starts.pop(), pos, tail))
        elif tok[0] == '"':
            body = re.sub(r'\\(.)', r'\1', tok[1:-1])
            stack[-1].append(Node("str", body, start, pos))
        elif tok[0] == ":":
            stack[-1].append(Node("kw", tok[1:].lower(), start, pos))
        elif NUMBER.match(tok):
            value = float(tok) if "." in tok else Fraction(tok)
            stack[-1].append(Node("num", value, start, pos))
        else:
            stack[-1].append(Node("sym", tok.lower(), start, pos))
    (top,) = stack[0]
    return top


def plist(node):
    """(kind-keyword . plist) → (kind, {key: value-node}, key-nodes)."""
    items = node.value
    kind = items[0].value
    keys = {items[i].value: items[i + 1] for i in range(1, len(items), 2)}
    return kind, keys


def items(node):
    return [] if node is None or node.kind == "sym" else node.value


def num(node, default=None):
    return default if node is None else node.value


# --- document order and ids (src/ids.lisp) ---------------------------------

PREFIX = {"measure": "m", "part": "p", "staff": "st", "voice": "v", "rest": "e",
          "note": "e", "chord": "e", "chord-note": "n", "lyric": "ly",
          "chord-symbol": "h", "spanner": "sp"}


def base36(n):
    """N >= 1 in base 36, digits 0-9 a-z, no leading zero."""
    digits = ""
    while n:
        n, d = divmod(n, 36)
        digits = "0123456789abcdefghijklmnopqrstuvwxyz"[d] + digits
    return digits


def document_order(score):
    """Yield every element form of SCORE in document order."""
    _, s = plist(score)
    for m in items(s.get("measures")):
        yield m
    for part in items(s.get("parts")):
        yield part
        _, p = plist(part)
        for staff in items(p.get("staves")):
            yield staff
        for voice in items(p.get("voices")):
            yield voice
            _, v = plist(voice)
            for vm in items(v.get("measures")):
                for event in items(vm):
                    yield event
                    kind, e = plist(event)
                    for n in items(e.get("notes")):
                        yield n
                    for lyric in items(e.get("lyrics")):
                        yield lyric
    for a in items(s.get("chord-symbols")):
        yield a
    for sp in items(s.get("spanners")):
        yield sp


def renumbered(text):
    """TEXT with ids minted in document order and references followed."""
    score = parse(text)
    edits, mapping, refs = [], {}, []
    elements = list(document_order(score))
    for serial, element in enumerate(elements, 1):
        kind, keys = plist(element)
        new = f"{PREFIX[kind]}-{base36(serial)}"
        old = keys.get("id")
        if old is not None:
            if old.value in mapping:
                raise ValueError(f"duplicate fixture id {old.value}")
            mapping[old.value] = new
            edits.append((old.start, old.end, f'"{new}"'))
        else:
            head = element.value[0]
            edits.append((head.end, head.end, f' :id "{new}"'))
        for ref in ("tie", "start", "end"):
            if ref in keys:
                refs.append(keys[ref])
    for ref in refs:
        if ref.value not in mapping:
            raise ValueError(f"dangling fixture reference {ref.value}")
        edits.append((ref.start, ref.end, f'"{mapping[ref.value]}"'))
    _, s = plist(score)
    counter = s["id-counter"]
    edits.append((counter.start, counter.end, str(len(elements))))
    for start, end, new in sorted(edits, reverse=True):
        text = text[:start] + new + text[end:]
    return text


# --- music21 ---------------------------------------------------------------


def lisp(value):
    if isinstance(value, bool):
        return "t" if value else "nil"
    if value is None:
        return "nil"
    if isinstance(value, str):
        return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'
    if isinstance(value, Fraction):
        return str(value.numerator) if value.denominator == 1 else f"{value.numerator}/{value.denominator}"
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, (list, tuple)):
        return "(" + " ".join(lisp(v) for v in value) + ")"
    raise TypeError(value)


def write_rows(name, header, rows):
    with open(os.path.join(HERE, name), "w", encoding="utf-8") as out:
        out.write(f";;;; {header}\n;;;; Generated by generate-sc0.py with music21 10.5.2. Do not edit.\n(\n")
        for row in rows:
            out.write(" " + lisp(row) + "\n")
        out.write(")\n")


def m21_pitch(name):
    m = re.match(r"^([A-G])(#|##|b|bb|)(-?\d+)$", name)
    letter, acc, octave = m.groups()
    return letter + {"": "", "#": "#", "##": "##", "b": "-", "bb": "--"}[acc] + octave


def key_name(k):
    return k.tonic.name.replace("-", "b") + " " + k.mode


def build(score_node, music21):
    """The music21 Score of a fixture, and (id, music21 object, bar) triples for
    its events and anchors."""
    from music21 import stream, note, chord, meter, key, harmony, tempo  # noqa
    _, s = plist(score_node)
    measures = items(s.get("measures"))
    first_bar = 0 if plist(measures[0])[1].get("pickup") else 1
    sc = stream.Score()
    events, anchors = [], []
    part_measures = []
    for part in items(s.get("parts")):
        p_m21 = stream.Part()
        _, p = plist(part)
        voices = items(p.get("voices"))
        bar_objects = []
        current_meter = None
        for i, mnode in enumerate(measures):
            _, mk = plist(mnode)
            m = stream.Measure(number=first_bar + i)
            if "time" in mk:
                current_meter = meter.TimeSignature(mk["time"].value)
                m.insert(0, current_meter)
            if "key" in mk:
                tonic, mode = mk["key"].value.split(" ")
                m.insert(0, key.Key(m21_pitch(tonic + "4")[:-1], mode))
            for vi, voice in enumerate(voices):
                _, vk = plist(voice)
                vms = items(vk.get("measures"))
                v = stream.Voice(id=str(vi + 1))
                for event in items(vms[i]):
                    kind, e = plist(event)
                    ql = Fraction(e["duration"].value) * 4
                    if kind == "rest":
                        obj = note.Rest(quarterLength=ql)
                    elif kind == "note":
                        obj = note.Note(m21_pitch(e["pitch"].value), quarterLength=ql)
                    else:
                        obj = chord.Chord([m21_pitch(plist(n)[1]["pitch"].value)
                                           for n in items(e["notes"])], quarterLength=ql)
                    if "grace" in e:
                        obj = obj.getGrace()
                    v.append(obj)
                    events.append((e["id"].value, obj, first_bar + i))
                m.insert(0, v)
            bar_objects.append(m)
        for i, m in enumerate(bar_objects):
            _, mk = plist(measures[i])
            if i == 0 and mk.get("pickup"):
                m.paddingLeft = m.timeSignature.barDuration.quarterLength - m.highestTime
            p_m21.append(m)
        sc.insert(0, p_m21)
        part_measures.append(bar_objects)
    for a in items(s.get("chord-symbols")):
        _, ak = plist(a)
        bar, offset = int(ak["bar"].value), Fraction(ak["offset"].value)
        obj = harmony.NoChord()
        part_measures[0][bar - first_bar].insert(offset * 4, obj)
        anchors.append((ak["id"].value, obj, bar))
    return sc, part_measures[0], events, anchors, first_bar


def in_force(m, cls):
    """The CLS object in force in measure M: its own, else the context's.
    (getContextByClass misses a measure's own object once paddingLeft is set.)"""
    own = list(m.getElementsByClass(cls))
    return own[0] if own else m.getContextByClass(cls)


def explicit_length(mk, ts):
    if "length" in mk:
        return Fraction(mk["length"].value)
    return Fraction(ts.barDuration.quarterLength) / 4


def oracle_rows(name, score_node):
    from music21 import meter, key
    sc, bars, events, anchors, first_bar = build(score_node, None)
    _, s = plist(score_node)
    bar_rows, event_rows, anchor_rows = [], [], []
    for i, m in enumerate(bars):
        ts, k = in_force(m, meter.TimeSignature), in_force(m, key.Key)
        start = Fraction(m.getOffsetInHierarchy(sc)) / 4
        length = Fraction(m.highestTime) / 4
        expected = explicit_length(plist(items(s["measures"])[i])[1], ts)
        if length != expected:
            raise ValueError(f"{name} bar {first_bar + i}: content {length}, length {expected}")
        bar_rows.append([name, first_bar + i, start, length, ts.ratioString, key_name(k)])
    for ident, obj, bar in events:
        event_rows.append([name, ident, bar, Fraction(obj.offset) / 4,
                           Fraction(obj.getOffsetInHierarchy(sc)) / 4])
    for ident, obj, bar in anchors:
        anchor_rows.append([name, ident, Fraction(obj.getOffsetInHierarchy(sc)) / 4])
    return bar_rows, event_rows, anchor_rows


def pickup_cases():
    """(meter pickup full-bars completing) for the pickup sweep."""
    cases = []
    for text, pickups in (("4/4", ["1/8", "1/4", "3/8", "1/2", "3/4"]),
                          ("3/4", ["1/8", "1/4", "1/2"]),
                          ("6/8", ["1/8", "1/4", "3/8"]),
                          ("2/2", ["1/4", "1/2"]),
                          ("2+3/8", ["1/8", "1/4"])):
        for p in pickups:
            for completing in (False, True):
                cases.append((text, Fraction(p), 3, completing))
    return cases


def pickup_rows():
    from music21 import stream, note, meter
    rows = []
    for text, p, n, completing in pickup_cases():
        ts = meter.TimeSignature(text)
        bar = Fraction(ts.barDuration.quarterLength) / 4
        lengths = [p] + [bar] * n + ([bar - p] if completing else [])
        part = stream.Part()
        for i, length in enumerate(lengths):
            m = stream.Measure(number=i)
            if i == 0:
                m.insert(0, meter.TimeSignature(text))
            m.append(note.Rest(quarterLength=length * 4))
            if i == 0:
                m.paddingLeft = (bar - p) * 4
            part.append(m)
        measures = list(part.getElementsByClass(stream.Measure))
        starts = [Fraction(m.offset) / 4 for m in measures]
        total = Fraction(part.highestTime) / 4
        samples = []
        x = Fraction(0)
        while x <= total:
            m = part.getElementAtOrBefore(x * 4, [stream.Measure])
            samples.append([x, m.number, x - Fraction(m.offset) / 4])
            x += Fraction(1, 8)
        rows.append([text, p, n, completing, starts, total, samples])
    return rows


def uncertain_rows(name, score_node):
    rows = []
    for below in (0, 0.3, 0.45, 0.5, 0.62, 0.8, 0.9, 1, 1.5):
        ids = []
        for element in document_order(score_node):
            _, k = plist(element)
            c = num(k.get("confidence"))
            if c is not None and c < below:
                ids.append(k["id"].value)
        rows.append([name, below, ids])
    return rows


def main():
    renumber = "--renumber" in sys.argv
    names = sorted(f for f in os.listdir(HERE)
                   if f.startswith("sc0-") and f.endswith(".sexp") and f not in ORACLES)
    bars, events, anchors, uncertain = [], [], [], []
    for file in names:
        path = os.path.join(HERE, file)
        with open(path, encoding="utf-8") as f:
            text = f.read()
        canonical = renumbered(text)
        if canonical != text:
            if not renumber:
                sys.exit(f"{file}: ids are not in document order (run with --renumber)")
            with open(path, "w", encoding="utf-8") as f:
                f.write(canonical)
        name = file[:-len(".sexp")]
        b, e, a = oracle_rows(name, parse(canonical))
        bars += b
        events += e
        anchors += a
        uncertain += uncertain_rows(name, parse(canonical))
    write_rows("sc0-bars.sexp", "SC0 bars: (fixture bar start length time key)", bars)
    write_rows("sc0-events.sexp", "SC0 events: (fixture id bar offset absolute)", events)
    write_rows("sc0-anchors.sexp", "SC0 chord-symbol anchors: (fixture id absolute)", anchors)
    write_rows("sc0-pickups.sexp",
               "SC0 pickups: (meter pickup full-bars completing bar-starts duration "
               "((absolute bar offset)...))", pickup_rows())
    write_rows("sc0-uncertain.sexp", "SC0 uncertainty: (fixture below (id...))", uncertain)
    print(f"{len(names)} fixtures, {len(bars)} bars, {len(events)} events, "
          f"{len(anchors)} anchors")


if __name__ == "__main__":
    main()
