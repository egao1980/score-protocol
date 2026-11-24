# Test fixture provenance

| File | Source | Version | SPDX | How |
|------|--------|---------|------|-----|
| `sc0-carol-6-8.sexp`, `sc0-chords-under-rests.sexp`, `sc0-jumps.sexp`, `sc0-key-change.sexp`, `sc0-keyboard.sexp`, `sc0-omr-result.sexp`, `sc0-pickup.sexp`, `sc0-repeats-voltas.sexp`, `sc0-satb.sexp`, `sc0-three-verses.sexp` | hand-built for these tests. Where a file's header names a tune or text, it is a short public-domain one (*Amazing Grace*: text 1779, tune 1829; *What Child Is This*: text 1865, Greensleeves; Thomas Ken, 1674) | — | MIT | written by hand in the canonical form of `src/sexp.lisp`; ids assigned by `generate-sc0.py --renumber` |
| `sc0-bars.sexp` | computed with music21 from the fixture scores: measure offset and `highestTime`, the `TimeSignature` and `Key` in force | music21 10.5.2 | MIT (generated facts; music21 itself is BSD-3-Clause) | `uv run --with music21==10.5.2 python -I tests/fixtures/generate-sc0.py` |
| `sc0-events.sexp` | music21: each event's offset in its voice and `getOffsetInHierarchy` (grace notes through `getGrace`, so they take no time) | music21 10.5.2 | MIT (generated facts) | same script |
| `sc0-anchors.sexp` | music21: a harmony object inserted at each chord-symbol anchor's offset, `getOffsetInHierarchy` | music21 10.5.2 | MIT (generated facts) | same script |
| `sc0-pickups.sexp` | music21: generated one-voice scores with a pickup (5 meters, 15 pickup lengths, with and without a completing final bar); measure offsets and `getElementAtOrBefore` every eighth note | music21 10.5.2 | MIT (generated facts) | same script |
| `sc0-uncertain.sexp` | the script's own document-order walk of the fixture forms (no music21): elements whose confidence is below each threshold | — | MIT | same script |

The generator lives next to the fixtures. Regenerate the oracle files rather than hand-edit them. Without `--renumber` the script also checks the fixture scores. Their ids must be exactly the ones `make-score` mints for an id-less copy, in document order, with `:id-counter` equal to the number of elements. The script does that walk and mints those ids itself, in Python, independently of the Lisp code.

## Where our conventions differ from music21

- **Units.** Offsets and durations are whole notes; music21's are quarter notes. The script divides by 4.
- **Pickups.** Our pickup measure states its length (`:length`). music21 derives it from the content (`paddingLeft` set for display). The script stops if the two disagree for any bar, so every fixture's explicit lengths match its content.
- **Bar numbers.** Ours are indices: bar 0 is the pickup, else the first measure is bar 1. The script numbers music21's measures the same way, so its rows use our numbers. The `:number` labels in `sc0-key-change` and `sc0-jumps` are display text only.
- **Context lookups.** music21's `getContextByClass` doesn't find a pickup measure's own time signature once `paddingLeft` is set, so the script looks in the measure first.
