;;;; SC1 edits of events, marks, spanners and chord symbols.
;;;;
;;;; Terms. A voice's TIME LINE is its non-grace events at their onsets (the
;;;; absolute offsets of their positions, check.lisp), voice measure by voice
;;;; measure. A SILENT voice measure (no events) is a gap in it. A grace event
;;;; belongs to the non-grace event that follows it in its voice measure, and
;;;; moves and goes with it. The EVENT BOUNDARIES of a voice measure are the
;;;; offsets of its non-grace events. The bar of an absolute offset t is the bar
;;;; b with BAR-START b <= t < BAR-START b + BAR-LENGTH b. The METRIC OFFSET of
;;;; t in bar b is t - BAR-START b, plus, when b is a pickup, the meter's bar
;;;; minus the pickup's length (a pickup is the end of a bar). Durations are
;;;; sounding time; an event's notated value is DURATION * TUPLET (elements.lisp).
;;;;
;;;; Pieces. An event E of duration D placed at onset T takes the span
;;;; [T, T + D). The span is cut at every barline; each segment [s, e), in bar b,
;;;; is
;;;;   one piece of e - s when (duration-dots (- e s) :tuplet (event-tuplet E))
;;;;   returns a value (up to three dots, as check.lisp asks), or else
;;;;   the pieces of (split-duration (- e s) :meter (bar-time score b)
;;;;   :offset m), m the metric offset of s (music-theory MT1).
;;;; An event with a TUPLET that would need more than one piece, and a segment
;;;; that SPLIT-DURATION can't notate without a tuplet, signal INVALID-EDIT. The
;;;; first piece in time is E itself: its id, and everything on and in it
;;;; (marks, lyrics, its chord notes with their ids). Each later piece is a copy
;;;; of E with its pitch or pitches (accidental :AUTO), its TUPLET, and nothing
;;;; else on it; its id, its chord notes' ids and the new ties are minted. Piece
;;;; i of a note ties to piece i + 1; for a chord, each chord note of piece i
;;;; ties to the chord note in the same position of piece i + 1. Rest pieces
;;;; have no ties and keep HIDDEN-P. E's own ties (to the notes after it) move
;;;; to the last piece, to the note in the same position, keeping their ids.
;;;; MEASURE-REST-P is true for a rest piece exactly when it fills its bar
;;;; alone.
;;;;
;;;; Filling. A GAP is a span of a voice measure that holds no non-grace event.
;;;; Every gap the change leaves in a voice measure that holds music afterwards
;;;; is filled with rests, bar segment by bar segment (gaps never cross a
;;;; barline, since nothing does): a segment that is the whole bar becomes one
;;;; rest of the bar's length with MEASURE-REST-P; any other segment [s, e) the
;;;; rests of (split-duration (- e s) :meter (bar-time score b) :offset m), m
;;;; the metric offset of s, in order. A voice measure the change leaves without
;;;; music is silent (empty), not filled.
;;;;
;;;; Writing. To write an event E of duration D at onset T of a voice, with U =
;;;; T + D:
;;;;   1. When U is after the end of the score, EDIT-POSITION-INVALID with
;;;;      POSITION = U.
;;;;   2. Every non-grace event of the voice, other than E, whose onset lies in
;;;;      (T, U) is removed with the grace events before it. If it ends after U,
;;;;      [U, its end) is a gap.
;;;;   3. E's pieces take [T, U); the gaps around them are filled.
;;;;
;;;; Re-flowing. To re-flow a time line into the bars of a measure map: every
;;;; event whose span crosses a barline becomes its pieces; each voice measure
;;;; receives, in time order, the events and pieces whose onsets lie in its bar,
;;;; each with its grace events before it; a voice measure that receives
;;;; nothing is silent, and the gaps of one that receives something are filled.
;;;; An event that crosses no barline is kept as it is, and only moved, except
;;;; that a rest's MEASURE-REST-P becomes true exactly when it fills its bar
;;;; alone. INSERT-EVENT with REFLOW and SET-TIME (edit-measures.lisp) re-flow.
;;;;
;;;; The operations. Each names its target by id. A target id the score lacks
;;;; signals EDIT-TARGET-MISSING; one of the wrong kind, INVALID-EDIT.
;;;;
;;;; INSERT-EVENT, slots VOICE (an id), MEASURE (an id), OFFSET (a rational >= 0,
;;;; default 0), EVENT (an EVENT, given) and REFLOW (a boolean). VOICE names a
;;;; voice and MEASURE a measure, of bar b; OFFSET must be < BAR-LENGTH b, and an
;;;; event boundary of the voice measure unless that voice measure is silent
;;;; (EDIT-POSITION-INVALID, POSITION = (b . OFFSET)). With D the duration of
;;;; EVENT and L the bar's length:
;;;;   A grace EVENT goes right before the non-grace event at OFFSET, after the
;;;;   grace events already there; OFFSET must be the offset of a non-grace
;;;;   event (EDIT-POSITION-INVALID). Nothing else moves; REFLOW plays no part.
;;;;   In a silent voice measure, EVENT takes [OFFSET, OFFSET + D) and the rest
;;;;   of the bar is filled. When OFFSET + D > L: without REFLOW,
;;;;   MEASURE-OVERFULL with EXCESS OFFSET + D - L; with REFLOW, as below.
;;;;   Otherwise, without REFLOW: when OFFSET + D > L, EVENT itself doesn't fit:
;;;;   MEASURE-OVERFULL with EXCESS OFFSET + D - L. Else EVENT goes before the
;;;;   event at OFFSET and its grace events; that event and everything after it
;;;;   in the voice measure move D later, so the music now ends at L + D. Let r
;;;;   be the onset, after the move, of the run of rest events after EVENT that
;;;;   ends the voice measure (grace events inside the run belong to it), or
;;;;   L + D when the voice measure doesn't end with a rest. When r <= L the run
;;;;   is removed and [r, L) is a gap, filled; otherwise MEASURE-OVERFULL with
;;;;   VOICE the voice's id, BAR b and EXCESS r - L.
;;;;   With REFLOW: EVENT takes [T, T + D), T the absolute offset of (b .
;;;;   OFFSET); the voice's time line from T on moves D later and is re-flowed
;;;;   into the measures. Rests moved past the end of the score are cut at it
;;;;   (what is left of them is a gap, filled); a sounding event that would end
;;;;   after it signals EDIT-POSITION-INVALID with POSITION = where it would end.
;;;; MEASURE-OVERFULL is signalled in a REFLOW restart, beside SKIP-EDIT and
;;;; USE-VALUE, that applies the same operation with REFLOW true.
;;;;
;;;; DELETE-EVENT, slot ID: an event.
;;;;   A grace event is removed.
;;;;   A note or chord event becomes a REST-EVENT with the same ID, DURATION
;;;;   and TUPLET, MEASURE-REST-P when it fills its bar alone, and nothing on
;;;;   it: everything on and in the old event is removed.
;;;;   A rest: when every non-grace event of its voice measure is a rest, the
;;;;   voice measure becomes silent (all its events are removed); otherwise
;;;;   INVALID-EDIT.
;;;;
;;;; REPLACE-EVENT, slots ID (an event) and EVENT (an EVENT, given). EVENT's id
;;;; must be NIL or ID, EVENT and the old event must both be grace events or
;;;; both not, and a non-grace EVENT must have the old event's DURATION (each
;;;; INVALID-EDIT). EVENT takes the old event's place with id ID; the elements
;;;; in the old event whose ids EVENT doesn't carry are removed. An event can
;;;; change kind this way (a note becomes a chord) and keep its id.
;;;;
;;;; SET-VOICE-MEASURES, slots VOICE (an id), MEASURE (an id) and MEASURES (a
;;;; list of lists of EVENTs, given): the voice measures of VOICE from MEASURE's
;;;; on, one per member of MEASURES, become those events. The last of them must
;;;; be a bar of the score (EDIT-POSITION-INVALID, POSITION = the first bar past
;;;; the end). Contents that don't fill their bars fail the check
;;;; (:MEASURE-DURATION). This is how a span of one voice is regenerated, and
;;;; how INVERT-EDIT restores one.
;;;;
;;;; SET-PITCH, slots ID (a note event or chord note) and PITCH (a music-theory
;;;; SPELLED-PITCH): the note's pitch becomes PITCH; its accidental display is
;;;; kept. A tie the new pitch breaks is removed (the cascade).
;;;;
;;;; SET-ACCIDENTAL, slots ID (a note event or chord note) and ACCIDENTAL (a
;;;; keyword of +ACCIDENTAL-DISPLAYS+).
;;;;
;;;; SET-DURATION, slots ID (an event), DURATION (a positive rational) and
;;;; TUPLET (NIL or a positive rational): the event gets DURATION and TUPLET.
;;;; A grace event changes in place, and nothing moves. Otherwise the event is
;;;; written (Writing) with its new duration at its onset; when it is shorter
;;;; than before, the rest of its old span is a gap, filled. So a longer note
;;;; overwrites what follows it and, past the barline, continues as tied notes;
;;;; a shorter one leaves rests.
;;;;
;;;; ADD-MARK, slots TARGET (an id) and MARK (a mark element, given). Where a
;;;; mark goes is the row of +MARK-PLACES+ for its class: the class TARGET must
;;;; be (else INVALID-EDIT), the slot, and how marks there are told apart. MARK
;;;; replaces the mark in that slot with its key (for a single slot, the mark
;;;; there), else joins the slot (lists stay sorted as the constructors sort
;;;; them). A MARK without an id takes the id of the mark it replaces. A lyric
;;;; on a rest or a grace event, a tie to a note that isn't next, and a tempo
;;;; mark past its bar fail the check.
;;;;
;;;; REMOVE-MARK, slot ID: a mark of a class in +MARK-PLACES+; it is removed.
;;;;
;;;; ADD-SPANNER, slot SPANNER (given): it joins the end of SCORE-SPANNERS. Its
;;;; endpoints face the check. REMOVE-SPANNER, slot ID: a spanner; removed.
;;;;
;;;; ADD-CHORD-SYMBOL, slot ANCHOR (given): it joins the chord-symbol track. An
;;;; anchor of the score at an EQUAL position is replaced; ANCHOR, without an id,
;;;; takes that anchor's id. A position outside its bar fails the check.
;;;; REMOVE-CHORD-SYMBOL, slot ID: an anchor; removed.

(in-package #:score-protocol)

(defparameter +mark-places+
  '((dynamic-mark event event-dynamic :single)
    (fermata event event-fermata :single)
    (breath-mark sounding-event event-breath-mark :single)
    (articulation sounding-event event-articulations articulation-kind)
    (tie (or note-event chord-note) note-tie :single)
    (lyric event event-lyrics lyric-verse)
    (tempo-mark measure-info measure-info-tempo tempo-mark-offset)
    (rehearsal-mark measure-info measure-info-rehearsal :single)
    (jump-mark measure-info measure-info-jump jump-mark-kind)
    (ending measure-info measure-info-ending :single))
  "Where ADD-MARK puts a mark: (mark-class target-type slot-reader key). KEY is
:SINGLE for a slot that holds one mark, else the reader whose EQL values tell
the marks of a list slot apart. REMOVE-MARK takes the marks of these classes.
Data.")

(defun %mark-p (object)
  (and (find-if (lambda (row) (typep object (first row))) +mark-places+) t))

(defun %event-measures-p (object)
  "True when OBJECT is a list of lists of EVENTs."
  (and (%list-of-p object 'list) (every (lambda (m) (%list-of-p m 'event)) object)))

;;; Classes -------------------------------------------------------------------

(defclass insert-event (edit-operation)
  ((voice :initarg :voice :reader edit-voice)
   (measure :initarg :measure :reader edit-measure)
   (offset :initarg :offset :reader edit-offset)
   (event :initarg :event :reader edit-event)
   (reflow :initarg :reflow :reader edit-reflow)))

(defclass delete-event (edit-operation)
  ((id :initarg :id :reader edit-id)))

(defclass replace-event (edit-operation)
  ((id :initarg :id :reader edit-id)
   (event :initarg :event :reader edit-event)))

(defclass set-voice-measures (edit-operation)
  ((voice :initarg :voice :reader edit-voice)
   (measure :initarg :measure :reader edit-measure)
   (measures :initarg :measures :reader edit-measures)))

(defclass set-pitch (edit-operation)
  ((id :initarg :id :reader edit-id)
   (pitch :initarg :pitch :reader edit-pitch)))

(defclass set-accidental (edit-operation)
  ((id :initarg :id :reader edit-id)
   (accidental :initarg :accidental :reader edit-accidental)))

(defclass set-duration (edit-operation)
  ((id :initarg :id :reader edit-id)
   (duration :initarg :duration :reader edit-duration)
   (tuplet :initarg :tuplet :reader edit-tuplet)))

(defclass add-mark (edit-operation)
  ((target :initarg :target :reader edit-target)
   (mark :initarg :mark :reader edit-mark)))

(defclass remove-mark (edit-operation)
  ((id :initarg :id :reader edit-id)))

(defclass add-spanner (edit-operation)
  ((spanner :initarg :spanner :reader edit-spanner)))

(defclass remove-spanner (edit-operation)
  ((id :initarg :id :reader edit-id)))

(defclass add-chord-symbol (edit-operation)
  ((anchor :initarg :anchor :reader edit-anchor)))

(defclass remove-chord-symbol (edit-operation)
  ((id :initarg :id :reader edit-id)))

;;; Constructors ----------------------------------------------------------------

(defun make-insert-event (&key voice measure (offset 0) event reflow)
  "An INSERT-EVENT of EVENT into VOICE at OFFSET in MEASURE (file header)."
  (check-type voice %id "an id string")
  (check-type measure %id "an id string")
  (check-type offset (rational 0))
  (check-type event event)
  (make-instance 'insert-event :voice voice :measure measure :offset offset
                               :event event :reflow (and reflow t)))

(defun make-delete-event (&key id)
  "A DELETE-EVENT of the event ID (file header)."
  (check-type id %id "an id string")
  (make-instance 'delete-event :id id))

(defun make-replace-event (&key id event)
  "A REPLACE-EVENT of the event ID by EVENT (file header)."
  (check-type id %id "an id string")
  (check-type event event)
  (make-instance 'replace-event :id id :event event))

(defun make-set-voice-measures (&key voice measure measures)
  "A SET-VOICE-MEASURES of VOICE from MEASURE on (file header)."
  (check-type voice %id "an id string")
  (check-type measure %id "an id string")
  (check-type measures (satisfies %event-measures-p) "a list of lists of EVENTs")
  (make-instance 'set-voice-measures :voice voice :measure measure
                                     :measures (mapcar #'copy-list measures)))

(defun make-set-pitch (&key id pitch)
  "A SET-PITCH of the note ID (file header)."
  (check-type id %id "an id string")
  (check-type pitch music-theory:spelled-pitch)
  (make-instance 'set-pitch :id id :pitch pitch))

(defun make-set-accidental (&key id accidental)
  "A SET-ACCIDENTAL of the note ID (file header)."
  (check-type id %id "an id string")
  (check-type accidental (satisfies %accidental-display-p)
              "a keyword of +ACCIDENTAL-DISPLAYS+")
  (make-instance 'set-accidental :id id :accidental accidental))

(defun make-set-duration (&key id duration tuplet)
  "A SET-DURATION of the event ID (file header)."
  (check-type id %id "an id string")
  (check-type duration (rational (0)))
  (check-type tuplet (or null (rational (0))))
  (make-instance 'set-duration :id id :duration duration :tuplet tuplet))

(defun make-add-mark (&key target mark)
  "An ADD-MARK of MARK onto the element TARGET (file header)."
  (check-type target %id "an id string")
  (check-type mark (satisfies %mark-p) "a mark of a class in +MARK-PLACES+")
  (make-instance 'add-mark :target target :mark mark))

(defun make-remove-mark (&key id)
  "A REMOVE-MARK of the mark ID (file header)."
  (check-type id %id "an id string")
  (make-instance 'remove-mark :id id))

(defun make-add-spanner (&key spanner)
  "An ADD-SPANNER of SPANNER (file header)."
  (check-type spanner spanner)
  (make-instance 'add-spanner :spanner spanner))

(defun make-remove-spanner (&key id)
  "A REMOVE-SPANNER of the spanner ID (file header)."
  (check-type id %id "an id string")
  (make-instance 'remove-spanner :id id))

(defun make-add-chord-symbol (&key anchor)
  "An ADD-CHORD-SYMBOL of ANCHOR (file header)."
  (check-type anchor chord-symbol-anchor)
  (make-instance 'add-chord-symbol :anchor anchor))

(defun make-remove-chord-symbol (&key id)
  "A REMOVE-CHORD-SYMBOL of the anchor ID (file header)."
  (check-type id %id "an id string")
  (make-instance 'remove-chord-symbol :id id))

;;; Application ---------------------------------------------------------------

(defmethod apply-edit ((score score) (op insert-event))
  (%sc1-pending 'apply-edit/insert-event))

(defmethod apply-edit ((score score) (op delete-event))
  (%sc1-pending 'apply-edit/delete-event))

(defmethod apply-edit ((score score) (op replace-event))
  (%sc1-pending 'apply-edit/replace-event))

(defmethod apply-edit ((score score) (op set-voice-measures))
  (%sc1-pending 'apply-edit/set-voice-measures))

(defmethod apply-edit ((score score) (op set-pitch))
  (%sc1-pending 'apply-edit/set-pitch))

(defmethod apply-edit ((score score) (op set-accidental))
  (%sc1-pending 'apply-edit/set-accidental))

(defmethod apply-edit ((score score) (op set-duration))
  (%sc1-pending 'apply-edit/set-duration))

(defmethod apply-edit ((score score) (op add-mark))
  (%sc1-pending 'apply-edit/add-mark))

(defmethod apply-edit ((score score) (op remove-mark))
  (%sc1-pending 'apply-edit/remove-mark))

(defmethod apply-edit ((score score) (op add-spanner))
  (%sc1-pending 'apply-edit/add-spanner))

(defmethod apply-edit ((score score) (op remove-spanner))
  (%sc1-pending 'apply-edit/remove-spanner))

(defmethod apply-edit ((score score) (op add-chord-symbol))
  (%sc1-pending 'apply-edit/add-chord-symbol))

(defmethod apply-edit ((score score) (op remove-chord-symbol))
  (%sc1-pending 'apply-edit/remove-chord-symbol))
