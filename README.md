# score-protocol

The canonical score model: parts, staves, measures, voices, notes and rests with rational durations, ties, slurs, lyrics (several verses), chord symbols, dynamics and articulations. Elements have stable ids and provenance/confidence slots. Includes an edit-operation algebra and view transforms (condensed, unfold repeats, extract part). Formats plug in as backends through serdes-protocol.

**Status:** skeleton (0.0.1). The design is in the capability brief [cl-stack/docs/capabilities/score.md](https://github.com/egao1980/cl-stack/blob/main/docs/capabilities/score.md). The API and tests land through contract branches and team-solve.

```sh
cl-repo test --system score-protocol
```

## License

MIT, see [LICENSE](LICENSE).
