# score-protocol

The canonical score model: parts, staves, measures, voices, notes and rests with rational durations, ties, slurs, lyrics (several verses), chord symbols, dynamics and articulations. Elements have stable ids and provenance/confidence slots. Includes an edit-operation algebra and view transforms (condensed, unfold repeats, extract part). Formats plug in as backends through serdes-protocol.

**Status:** SC0 contract (0.1.0). The model, element ids, provenance and confidence, the measure map and positions, `check-score` and the canonical s-expression form are specified. The rules are in the file headers under `src/`. They are implemented, and the Rove suite under `tests/` is the spec. The design is in the capability brief [cl-stack/docs/capabilities/score.md](https://github.com/egao1980/cl-stack/blob/main/docs/capabilities/score.md). Pitches, meters, keys, tempi and chord symbols are [music-theory](https://github.com/egao1980/music-theory) values.

```sh
cl-repo test --system score-protocol
```

## License

MIT, see [LICENSE](LICENSE).
