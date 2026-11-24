;;;; score-protocol: the canonical, immutable model of a notated score.
;;;; Brief: cl-stack/docs/capabilities/score.md. Pitches, intervals, meters,
;;;; keys, tempi and chord symbols are music-theory values, never re-modelled.

(defpackage #:score-protocol
  (:use #:cl)
  (:nicknames #:stack-score)
  (:documentation "The score model, stable element ids, provenance and confidence, the
measure map and positions, validation and the canonical s-expression form (SC0).
Later slices add the edit-operation algebra and the views (SC1); formats live
in backends (score-backend-musicxml, score-backend-midi).")
  (:export
   ;; Conditions (all slices; see conditions.lisp)
   #:score-error #:score-error-reason
   #:invalid-position #:invalid-position-position
   #:unknown-element #:unknown-element-id
   #:score-invariant-violation #:score-invariant-violation-issues
   #:invalid-edit #:invalid-edit-op #:skip-edit
   #:score-format-error #:score-format-error-format
   #:score-format-error-position #:score-format-error-cause
   #:musicxml-unsupported #:musicxml-unsupported-element #:skip-element
   #:score-warning
   #:lossy-conversion #:lossy-conversion-format #:lossy-conversion-what
   #:low-confidence-guess #:low-confidence-guess-element-id
   #:low-confidence-guess-what #:low-confidence-guess-confidence
   ;; Ids (SC0; see ids.lisp)
   #:valid-id-p #:slice-id #:find-slice
   ;; Provenance and the element base class (SC0)
   #:provenance #:make-provenance #:provenance-p
   #:provenance-source #:provenance-backend #:provenance-page
   #:provenance-bbox #:provenance-time-range
   #:element #:element-id #:element-provenance #:element-confidence
   ;; Parts, staves, voices (SC0)
   #:part #:make-part #:part-name #:part-abbreviation #:part-staves #:part-voices
   #:staff #:make-staff #:staff-clef
   #:voice #:make-voice #:voice-name #:voice-staff #:voice-stem #:voice-measures
   ;; Events, notes, lyrics (SC0)
   #:event #:event-duration #:event-tuplet #:event-fermata #:event-dynamic
   #:event-lyrics
   #:rest-event #:make-rest-event #:rest-event-measure-rest-p #:rest-event-hidden-p
   #:sounding-event #:event-grace #:event-articulations #:event-breath-mark
   #:note-event #:make-note-event
   #:chord-event #:make-chord-event #:chord-event-notes
   #:chord-note #:make-chord-note
   #:note-pitch #:note-accidental #:note-tie
   #:lyric #:make-lyric #:lyric-verse #:lyric-text #:lyric-syllabic #:lyric-extender
   ;; Marks on events (SC0)
   #:dynamic-mark #:make-dynamic-mark #:dynamic-mark-value
   #:fermata #:make-fermata #:fermata-shape
   #:breath-mark #:make-breath-mark
   #:articulation #:make-articulation #:articulation-kind
   #:tie #:make-tie #:tie-end
   ;; Chord symbols and spanners (SC0)
   #:chord-symbol-anchor #:make-chord-symbol-anchor #:anchor-position #:anchor-symbol
   #:spanner #:make-spanner #:spanner-kind #:spanner-start #:spanner-end
   ;; The measure map (SC0; see measure-map.lisp)
   #:measure-info #:make-measure-info
   #:measure-info-number #:measure-info-time #:measure-info-key
   #:measure-info-pickup-p #:measure-info-length #:measure-info-barline
   #:measure-info-repeat-start #:measure-info-repeat-end #:measure-info-ending
   #:measure-info-jump #:measure-info-rehearsal #:measure-info-tempo
   ;; Marks on measures (SC0)
   #:ending #:make-ending #:ending-passes #:ending-measures
   #:jump-mark #:make-jump-mark #:jump-mark-kind
   #:rehearsal-mark #:make-rehearsal-mark #:rehearsal-mark-text
   #:tempo-mark #:make-tempo-mark #:tempo-mark-offset #:tempo-mark-tempo #:tempo-mark-text
   ;; Bars and positions (SC0)
   #:score-first-bar #:score-last-bar #:score-duration
   #:bar-measure #:bar-time #:bar-key #:bar-length #:bar-start
   #:absolute-offset #:offset-position
   ;; The score (SC0; see score.lisp)
   #:score #:make-score #:copy-score
   #:score-metadata #:score-measure-map #:score-parts #:score-chord-symbols
   #:score-spanners #:score-id-counter
   #:score-elements #:find-element #:element-parent #:element-position
   #:uncertain-elements
   ;; Validation (SC0; see check.lisp)
   #:score-issue #:score-issue-p #:score-issue-kind #:score-issue-id
   #:score-issue-bar #:score-issue-detail
   #:check-score #:validate-score
   ;; The canonical s-expression form (SC0; see sexp.lisp)
   #:score-to-sexp #:sexp-to-score #:element-to-sexp #:sexp-to-element
   #:score-equal))

(in-package #:score-protocol)
