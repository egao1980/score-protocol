;;;; score-protocol: the canonical, immutable model of a notated score.
;;;; Brief: cl-stack/docs/capabilities/score.md. Pitches, intervals, meters,
;;;; keys, tempi and chord symbols are music-theory values, never re-modelled.

(defpackage #:score-protocol
  (:use #:cl)
  (:nicknames #:stack-score)
  (:documentation "The score model, stable element ids, provenance and confidence, the
measure map and positions, validation and the canonical s-expression form (SC0);
the edit-operation algebra and the condensed, unfolded and extracted views
(SC1); drafts and the score builder, refs to elements not yet minted (SC3).
Formats live in backends (score-backend-musicxml, score-backend-midi).")
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
   #:lossy-conversion-direction
   #:low-confidence-guess #:low-confidence-guess-element-id
   #:low-confidence-guess-what #:low-confidence-guess-confidence
   #:edit-target-missing #:edit-position-invalid
   #:measure-overfull #:measure-overfull-voice #:measure-overfull-bar
   #:measure-overfull-excess #:reflow
   #:edit-breaks-score
   #:unresolved-reference #:unresolved-reference-key
   ;; Ids (SC0; see ids.lisp)
   #:valid-id-p #:slice-id #:find-slice
   ;; Drafts and the score builder (SC3; see builder.lisp)
   #:score-builder #:make-score-builder #:builder-ref #:builder-id
   #:draft-ref #:draft-ref-key #:draft-ref-prefer
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
   #:score-equal
   ;; The edit algebra (SC1; see edits.lisp)
   #:edit-operation #:apply-edit #:invert-edit #:compose-edits
   #:edit-to-sexp #:sexp-to-edit
   #:change-set #:make-change-set #:change-set-p #:change-set-created
   #:change-set-removed #:change-set-modified #:change-set-empty-p
   #:composite-edit #:make-composite-edit #:edit-ops
   ;; Edits of events and marks (SC1; see edit-events.lisp)
   #:insert-event #:make-insert-event #:delete-event #:make-delete-event
   #:replace-event #:make-replace-event
   #:set-voice-measures #:make-set-voice-measures
   #:set-pitch #:make-set-pitch #:set-accidental #:make-set-accidental
   #:set-duration #:make-set-duration
   #:add-mark #:make-add-mark #:remove-mark #:make-remove-mark
   #:add-spanner #:make-add-spanner #:remove-spanner #:make-remove-spanner
   #:add-chord-symbol #:make-add-chord-symbol
   #:remove-chord-symbol #:make-remove-chord-symbol
   ;; Edits of measures, and transposition (SC1; see edit-measures.lisp)
   #:set-key #:make-set-key #:set-time #:make-set-time
   #:replace-measure #:make-replace-measure
   #:insert-measures #:make-insert-measures
   #:delete-measures #:make-delete-measures
   #:transpose #:make-transpose
   ;; Operation slots (SC1; shared readers)
   #:edit-id #:edit-voice #:edit-measure #:edit-offset #:edit-event #:edit-reflow
   #:edit-measures #:edit-measure-info #:edit-measure-infos #:edit-pitch
   #:edit-accidental #:edit-duration #:edit-tuplet
   #:edit-target #:edit-mark #:edit-spanner #:edit-anchor #:edit-key #:edit-time
   #:edit-before #:edit-contents #:edit-count #:edit-interval #:edit-to-key
   #:edit-parts #:edit-from #:edit-to
   ;; Views (SC1; see views.lisp)
   #:condensed-view #:unfold #:extract-part))

(in-package #:score-protocol)
