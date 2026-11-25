# score-protocol

The canonical score model: parts, staves, measures, voices, notes and rests with rational durations, ties, slurs, lyrics (several verses), chord symbols, dynamics and articulations. Elements have stable ids and provenance/confidence slots. Includes an edit-operation algebra and view transforms (condensed, unfold repeats, extract part). Formats plug in as backends through serdes-protocol.

**Status:** 0.4.0 contract (origins, below); 0.3.0 implemented. SC0, the model, element ids, provenance and confidence, the measure map and positions, `check-score` and the canonical s-expression form, is implemented. So is SC1, the edit-operation algebra (operations as values; `apply-edit` with an exact change set, `invert-edit`, composition, a canonical form for logs) and the views (`condensed-view`, `unfold`, `extract-part`). SC3 adds drafts: a `score-builder` hands out `draft-ref`s that stand for ids not minted yet, so a reader builds a score whose ties and spanners name later notes in one `make-score` call (`src/builder.lisp`); it also words position errors by what is wrong, drops `unfold`'s step limit, names a reflowed insert in later conditions, and gives `lossy-conversion` a direction. The rules are in the file headers under `src/`, and the Rove suite under `tests/` is the spec. The design is in the capability brief [cl-stack/docs/capabilities/score.md](https://github.com/egao1980/cl-stack/blob/main/docs/capabilities/score.md). Pitches, meters, keys, tempi and chord symbols are [music-theory](https://github.com/egao1980/music-theory) values.

```sh
cl-repo test --system score-protocol
```

## 0.4.0 (contract): origins

A tool that derives an element by replacing another one (a generator that rewrites a chord symbol, an OMR correction, a scripted edit) can now record what it replaced, in the element's provenance, so the original is recoverable from the score alone ([#11](https://github.com/egao1980/score-protocol/issues/11)). `provenance` gains an optional `origin`: an `origin` struct with the replaced element's `id` (a record, not a reference: it need not name an element of the score) and `value`, `nil` or a copy of the replaced chord symbol. `nil` means the element replaced nothing.

| File | Contents | |
|---|---|---|
| `src/elements.lisp` | the Origins section of the header; `origin`, `make-origin`, the `origin` slot of `provenance`, `element-origin` | given |
| `src/elements.lisp` | printing an origin, `#<ORIGIN h-3 G7>` | stubbed |
| `src/sexp.lisp` | `:origin` in the provenance plist, the ORIGIN plist `(:id ID :value SYMBOL)` | grammar given; `%origin-to-sexp`, `%sexp-to-origin` stubbed |
| `src/edits.lisp` | an edited element keeps its origin (`%edited-origin`) | stubbed |
| `src/edit-measures.lisp` | TRANSPOSE moves a chord-symbol origin with its anchor (`%move-anchor-origin`) | stubbed |
| `tests/sc4-origin-test.lisp` | construction and type errors, printing, canonical forms, the round trip, `score-equal`, read errors, origins as records (no issue, no element, no serial), copies and views, edits (sharing, an edited element, a given anchor, edit forms, inverses), TRANSPOSE | the spec |

Decisions to review:
- **An origin is a record.** Its id may name nothing, an element elsewhere, or a live element of the same score; `check-score`, `find-element`, minting and the id counter never read it.
- **0.4.0 knows one kind of value,** a chord symbol (N.C. included). Other element kinds' values (a pitch for an OMR correction) can come later with their own codec; until then such an origin records the id alone.
- **An edited element keeps its origin,** with provenance `:user`: the user's edit of a generated chord still says which symbol it replaced. Elements an edit makes have none.
- **TRANSPOSE moves an origin's chord symbol with its anchor,** the same transposition and respelling, so the origin keeps reading as the replaced symbol would in the transposed score.
- **Formats need no change.** Writers that can't carry provenance already report it (`lossy-conversion`, "provenance and confidence"), and an origin only travels inside a provenance.

## License

MIT, see [LICENSE](LICENSE).
