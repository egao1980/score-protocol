;;;; SC0 validation: CHECK-SCORE and the issue kinds.
;;;;
;;;; MAKE-SCORE builds any score whose values have the right types; whether the
;;;; values fit together is reported, not refused. CHECK-SCORE score returns a
;;;; list of SCORE-ISSUEs, in no particular order, () for a valid score. Each is
;;;; a struct with KIND (a keyword of +ISSUE-KINDS+), ID (the subject: an id
;;;; string), BAR (an integer or NIL) and DETAIL (a plist, NIL unless stated).
;;;; Each check is a small structural predicate over the model, so none of this
;;;; is policy for the logic family.
;;;;
;;;; Terms. The bar of an event is its ELEMENT-POSITION bar; an event is "past
;;;; the map" when its voice measure index is >= the number of measures. Its
;;;; ONSET is the ABSOLUTE-OFFSET of its ELEMENT-POSITION, defined for events
;;;; that aren't past the map. A "note" is a NOTE-EVENT or a CHORD-NOTE, and the
;;;; event of a note is the note itself for a note event, its chord for a chord
;;;; note. Unless stated, BAR is the bar of the event the subject belongs to.
;;;;
;;;; One issue per subject, per kind:
;;;;   :DUPLICATE-ID      ID is carried by two or more elements. ID = that id,
;;;;                      BAR NIL.
;;;;   :MISSING-SIGNATURE the first measure has no TIME or no KEY. ID = that
;;;;                      measure, BAR = the first bar.
;;;;   :BAD-PICKUP        a measure with PICKUP-P that isn't the first; or a
;;;;                      first measure with PICKUP-P and no LENGTH, or with a
;;;;                      LENGTH >= the bar of its meter (BAR-TIME). ID = the
;;;;                      measure, BAR = its bar.
;;;;   :VOICE-STAFF       a voice whose STAFF is greater than the number of
;;;;                      staves of its part. ID = the voice, BAR NIL.
;;;;   :MEASURE-COUNT     a voice whose number of voice measures isn't the number
;;;;                      of measures. ID = the voice, BAR NIL, DETAIL (:EXPECTED
;;;;                      number-of-measures :ACTUAL number-of-voice-measures).
;;;;   :MEASURE-DURATION  a non-empty voice measure that isn't past the map and
;;;;                      whose non-grace event durations don't sum to its
;;;;                      BAR-LENGTH. One issue per voice and bar: ID = the voice,
;;;;                      BAR = the bar, DETAIL (:EXPECTED bar-length :ACTUAL sum).
;;;;   :UNNOTATABLE-DURATION an event that isn't a measure rest and whose
;;;;                      notated value has no plain or dotted form:
;;;;                      (music-theory:duration-dots duration :tuplet tuplet)
;;;;                      returns NIL (at most 3 dots). ID = the event.
;;;;   :DEGENERATE-CHORD  a chord event with fewer than two notes. ID = the event.
;;;;   :MISPLACED-LYRIC   a lyric on a rest event or on a grace event. ID = the
;;;;                      lyric.
;;;;   :DUPLICATE-VERSE   an event with two or more lyrics of the same verse.
;;;;                      ID = the event.
;;;;   :TIE-TARGET        a note whose TIE is not NIL and any of: no element has
;;;;                      that id; it isn't a note; its event isn't in the same
;;;;                      voice as the source's event; either event is a grace
;;;;                      event or past the map; the target event's onset isn't
;;;;                      the source event's onset + its duration; an earlier note
;;;;                      in document order ties to the same id. ID = the source
;;;;                      note.
;;;;   :TIE-PITCH         a note whose TIE names a note (anywhere) whose pitch
;;;;                      isn't EQUALP to its own: a tie joins equal spellings.
;;;;                      ID = the source note.
;;;;   :SPANNER-ENDPOINT  a spanner whose START or END names no element or one
;;;;                      that isn't an event; or whose two events are in
;;;;                      different parts; or one is past the map; or, for a
;;;;                      :SLUR, one is a rest event. ID = the spanner, BAR NIL.
;;;;   :SPANNER-ORDER     a spanner whose endpoints pass :SPANNER-ENDPOINT and
;;;;                      whose START doesn't precede its END. START precedes END
;;;;                      when its onset is earlier, or when the onsets are equal
;;;;                      and both are in one voice with START earlier in it (a
;;;;                      grace note before its main note). A hairpin (:CRESCENDO,
;;;;                      :DIMINUENDO) may also start and end on one event; a slur
;;;;                      can't. ID = the spanner, BAR NIL.
;;;;   :CHORD-SYMBOL-POSITION an anchor whose bar isn't a bar of the score, or
;;;;                      whose offset isn't < its BAR-LENGTH (a chord at the end
;;;;                      of a bar belongs to the next one), or whose position is
;;;;                      EQUAL to an earlier anchor's in the track. ID = the
;;;;                      anchor, BAR NIL.
;;;; Lookups of a referenced id go through FIND-ELEMENT, so with duplicate ids
;;;; they see the first carrier.
;;;;
;;;; VALIDATE-SCORE score returns SCORE when CHECK-SCORE finds nothing, and
;;;; otherwise signals SCORE-INVARIANT-VIOLATION (ISSUES = those issues) inside a
;;;; CONTINUE restart that returns SCORE as it is. Edits (SC1) keep a valid
;;;; score valid or signal.

(in-package #:score-protocol)

(defparameter +issue-kinds+
  '(:duplicate-id :missing-signature :bad-pickup :voice-staff :measure-count
    :measure-duration :unnotatable-duration :degenerate-chord :misplaced-lyric
    :duplicate-verse :tie-target :tie-pitch :spanner-endpoint :spanner-order
    :chord-symbol-position)
  "SCORE-ISSUE-KIND values, defined in the file header. Data.")

(defstruct (score-issue (:constructor make-score-issue))
  (kind nil :type keyword :read-only t)
  (id nil :type (or null string) :read-only t)
  (bar nil :type (or null integer) :read-only t)
  (detail nil :type list :read-only t))

(defun check-score (score)
  "The SCORE-ISSUEs of SCORE (file header), () when it is valid."
  (declare (ignorable score))
  (%sc0-pending 'check-score))

(defun validate-score (score)
  "SCORE when it is valid, else SCORE-INVARIANT-VIOLATION inside CONTINUE."
  (declare (ignorable score))
  (%sc0-pending 'validate-score))
