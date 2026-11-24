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

;;; The time kernel -------------------------------------------------------------
;;; A time line is a list of %SLOTs in time order: a non-grace event at its
;;; absolute onset with the grace events before it, and, for the last event of
;;; a voice measure, the grace events after it. %ASSEMBLE turns slots back into
;;; the voice measures of a bar table (Pieces, Filling and Re-flowing above).
;;; Bar tables are measure-map.lisp's, so SET-TIME passes the table of its new
;;; bars.

(defstruct (%slot (:constructor %make-slot (onset event &optional graces trailing moved written))
                  (:copier nil) (:predicate nil))
  "ONSET, the non-grace EVENT, GRACES before it, TRAILING graces after it;
MOVED for a re-flowed event (its MEASURE-REST-P follows the rule), WRITTEN for
the event Writing places (cut into pieces even inside one bar)."
  onset event graces trailing moved written)

(defun %bar-end (bars i)
  (+ (svref (%bar-table-starts bars) i) (svref (%bar-table-lengths bars) i)))

(defun %bar-at (bars time)
  "The index of the bar of BARS with start <= TIME < end, or NIL."
  (loop for i from 0 below (%bar-count bars)
        when (and (<= (svref (%bar-table-starts bars) i) time) (< time (%bar-end bars i)))
          return i))

(defun %bar-before (bars time)
  "The index of the bar of BARS holding the instant just before TIME."
  (loop for i from (1- (%bar-count bars)) downto 0
        when (< (svref (%bar-table-starts bars) i) time)
          return i))

(defun %cell (voice i)
  "VOICE's voice measure I as a list of events."
  (%seq-list (fset:@ (voice-measures voice) i)))

(defun %boundaries (events)
  "The offsets of the non-grace events of the voice measure EVENTS."
  (let ((at 0) (out '()))
    (dolist (event events (nreverse out))
      (unless (%grace-p event)
        (push at out)
        (incf at (event-duration event))))))

(defun %voice-slots (voice bars)
  "VOICE's time line under the bar table BARS."
  (let ((measures (voice-measures voice)) (slots '()))
    (dotimes (i (min (fset:size measures) (%bar-count bars)))
      (let ((at (svref (%bar-table-starts bars) i)) (graces '()) (last nil))
        (dolist (event (%seq-list (fset:@ measures i)))
          (if (%grace-p event)
              (push event graces)
              (progn (setf last (%make-slot at event (reverse graces)))
                     (push last slots)
                     (setf graces '())
                     (incf at (event-duration event)))))
        (when (and graces last)
          (setf (%slot-trailing last) (reverse graces)))))
    (nreverse slots)))

(defun %metric (bars i s)
  "The metric offset of the absolute offset S in bar I (file header)."
  (+ (- s (svref (%bar-table-starts bars) i))
     (if (and (zerop i) (measure-info-pickup-p (svref (%bar-table-measures bars) 0)))
         (- (music-theory:meter-measure-duration (svref (%bar-table-times bars) 0))
            (svref (%bar-table-lengths bars) 0))
         0)))

(defun %split (op bars i s duration reason)
  "SPLIT-DURATION of DURATION at the absolute offset S in bar I. A length that
needs a tuplet is INVALID-EDIT with REASON (the one translated condition)."
  (handler-case (music-theory:split-duration duration
                                             :meter (svref (%bar-table-times bars) i)
                                             :offset (%metric bars i s))
    (music-theory:music-theory-error () (%refuse op reason))))

(defun %segments (bars onset end)
  "The bar segments (i s e) of the span [ONSET, END), in time order."
  (loop for i from 0 below (%bar-count bars)
        for s = (max onset (svref (%bar-table-starts bars) i))
        for e = (min end (%bar-end bars i))
        when (< s e) collect (list i s e)))

(defun %fills-bar-p (bars onset duration)
  "True when [ONSET, ONSET + DURATION) is a whole bar of BARS."
  (let ((i (%bar-at bars onset)))
    (and i
         (= onset (svref (%bar-table-starts bars) i))
         (= duration (svref (%bar-table-lengths bars) i)))))

(defun %piece-spans (op event onset bars)
  "((onset . duration)...): the pieces of EVENT placed at ONSET (file header)."
  (let ((spans '()))
    (loop for (i s e) in (%segments bars onset (+ onset (event-duration event)))
          do (if (music-theory:duration-dots (- e s) :tuplet (event-tuplet event))
                 (push (cons s (- e s)) spans)
                 (let ((at s))
                   (dolist (d (%split op bars i s (- e s) "a duration that needs a tuplet"))
                     (push (cons at d) spans)
                     (incf at d)))))
    (setf spans (nreverse spans))
    (when (and (event-tuplet event) (rest spans))
      (%refuse op "a tuplet that would need splitting"))
    spans))

(defun %new-tie (target)
  "A tie made by an edit to the piece TARGET (numbered by %BUILD-SCORE)."
  (apply #'make-instance 'tie :end target (%user-provenance)))

(defun %pieces (event spans bars)
  "The events of the piece SPANS of EVENT: the first is EVENT remade, the others
copies, tied in order; EVENT's own ties move to the last piece."
  (let* ((k (length spans))
         (pieces (make-list k)))
    (etypecase event
      (note-event
       (loop for j from (1- k) downto 0
             for d = (cdr (nth j spans))
             for tie = (if (= j (1- k)) (note-tie event) (%new-tie (nth (1+ j) pieces)))
             do (setf (nth j pieces)
                      (if (zerop j)
                          (%user event :duration d :tie tie)
                          (apply #'make-note-event :pitch (note-pitch event) :duration d
                                                   :tuplet (event-tuplet event) :tie tie
                                                   (%user-provenance))))))
      (chord-event
       (let ((notes (chord-event-notes event)) (next '()))
         (loop for j from (1- k) downto 0
               for d = (cdr (nth j spans))
               for made = (loop for note in notes
                                for m from 0
                                for tie = (if (= j (1- k)) (note-tie note) (%new-tie (nth m next)))
                                collect (cond ((plusp j)
                                               (apply #'make-chord-note :pitch (note-pitch note) :tie tie
                                                                        (%user-provenance)))
                                              ((eq tie (note-tie note)) note)
                                              (t (%remake note :tie tie))))
               do (setf (nth j pieces)
                        (if (zerop j)
                            (%user event :duration d :notes made)
                            (apply #'make-chord-event :notes made :duration d
                                                      :tuplet (event-tuplet event) (%user-provenance)))
                        next made))))
      (rest-event
       (loop for j from 0 below k
             for (at . d) = (nth j spans)
             for whole = (%fills-bar-p bars at d)
             do (setf (nth j pieces)
                      (if (zerop j)
                          (%user event :duration d :measure-rest-p whole)
                          (apply #'make-rest-event :duration d :tuplet (event-tuplet event)
                                                   :hidden-p (rest-event-hidden-p event)
                                                   :measure-rest-p whole (%user-provenance)))))))
    pieces))

(defun %slot-entries (op slot bars)
  "The entries (onset graces event trailing moved) SLOT places: itself when its
event crosses no barline and isn't WRITTEN, else one per piece."
  (let* ((event (%slot-event slot))
         (onset (%slot-onset slot)))
    (if (and (not (%slot-written slot))
             (null (rest (%segments bars onset (+ onset (event-duration event))))))
        (list (list onset (%slot-graces slot) event (%slot-trailing slot) (%slot-moved slot)))
        (let* ((spans (%piece-spans op event onset bars))
               (k (length spans)))
          (loop for span in spans
                for piece in (%pieces event spans bars)
                for j from 0
                collect (list (car span)
                              (and (zerop j) (%slot-graces slot))
                              piece
                              (and (= j (1- k)) (%slot-trailing slot))
                              nil))))))

(defun %fill (op bars i s e)
  "The rests that fill the gap [S, E) of bar I (file header: Filling)."
  (if (and (= s (svref (%bar-table-starts bars) i)) (= e (%bar-end bars i)))
      (list (apply #'make-rest-event :duration (- e s) :measure-rest-p t (%user-provenance)))
      (mapcar (lambda (d) (apply #'make-rest-event :duration d (%user-provenance)))
              (%split op bars i s (- e s) "a gap that needs a tuplet"))))

(defun %measure-rest-as (rest whole)
  "REST with MEASURE-REST-P WHOLE: itself when it has it."
  (if (eq (rest-event-measure-rest-p rest) (and whole t))
      rest
      (%user rest :measure-rest-p whole)))

(defun %fill-bar (op bars i entries)
  "The events of bar I: ENTRIES in time order, the gaps between them filled."
  (let ((out '()) (at (svref (%bar-table-starts bars) i)))
    (flet ((gap (s e)
             (when (< s e)
               (dolist (rest (%fill op bars i s e)) (push rest out)))))
      (loop for (onset graces event trailing moved) in entries
            do (gap at onset)
               (dolist (grace graces) (push grace out))
               (push (if (and moved (typep event 'rest-event))
                         (%measure-rest-as event (%fills-bar-p bars onset (event-duration event)))
                         event)
                     out)
               (dolist (grace trailing) (push grace out))
               (setf at (+ onset (event-duration event))))
      (gap at (%bar-end bars i)))
    (nreverse out)))

(defun %assemble (op slots fills bars lo hi)
  "The voice measures LO..HI of the bar table BARS, a list of event lists: SLOTS
(in time order, cut into pieces at the barlines) by the bar of their onsets; a
bar that receives nothing and meets no FILLS span ((start . end)...) is silent,
the gaps of the others are filled."
  (let ((buckets (make-array (1+ (- hi lo)) :initial-element '())))
    (dolist (slot slots)
      (dolist (entry (%slot-entries op slot bars))
        (let ((i (%bar-at bars (first entry))))
          (when (and i (<= lo i hi))
            (push entry (aref buckets (- i lo)))))))
    (loop for i from lo to hi
          collect (let ((entries (reverse (aref buckets (- i lo))))
                        (start (svref (%bar-table-starts bars) i))
                        (end (%bar-end bars i)))
                    (if (and (null entries)
                             (notany (lambda (span) (and (< (car span) end) (> (cdr span) start)))
                                     fills))
                        '()
                        (%fill-bar op bars i entries))))))

(defun %with-cells (voice from cells)
  "VOICE with its voice measures FROM, FROM + 1, ... replaced by the event lists
CELLS; VOICE itself when none differs."
  (let ((seq (voice-measures voice)) (changed nil))
    (loop for cell in cells
          for j from from
          unless (%cell-eq cell (%seq-list (fset:@ seq j)))
            do (setf seq (fset:with seq j (fset:convert 'fset:seq cell))
                     changed t))
    (if changed
        (%rebuild voice (%element-row voice) (element-id voice)
                  (list (cons (%row-field voice :measures) seq)))
        voice)))

(defun %write (op score entry new)
  "Writing (file header): the event of ENTRY becomes NEW at its onset."
  (let* ((event (%entry-element entry))
         (voice (%entry-voice entry))
         (bars (%score-bars score))
         (lo (%entry-measure entry))
         (onset (+ (svref (%bar-table-starts bars) lo) (%entry-offset entry)))
         (u (+ onset (event-duration new)))
         (old-end (+ onset (event-duration event)))
         (reach (max u old-end))
         (fills '())
         (kept '()))
    (when (> u (%bar-table-duration bars))
      (%off op u "the music would end after the end of the score"))
    (dolist (slot (%voice-slots voice bars))
      (let ((at (%slot-onset slot)))
        (cond ((eq (%slot-event slot) event)
               (push (%make-slot onset new (%slot-graces slot) (%slot-trailing slot) nil t) kept))
              ((< onset at u)
               (let ((stop (+ at (event-duration (%slot-event slot)))))
                 (when (> stop u) (push (cons u stop) fills))
                 (setf reach (max reach stop))))
              (t (push slot kept)))))
    (when (< u old-end) (push (cons u old-end) fills))
    (let* ((hi (%bar-before bars reach))
           (start (svref (%bar-table-starts bars) lo))
           (end (%bar-end bars hi))
           (slots (remove-if-not (lambda (slot) (and (<= start (%slot-onset slot)) (< (%slot-onset slot) end)))
                                 (nreverse kept))))
      (%substitute-1 score voice (%with-cells voice lo (%assemble op slots fills bars lo hi))))))

;;; INSERT-EVENT ---------------------------------------------------------------------

(defun %with-reflow (op)
  "OP, an INSERT-EVENT, with REFLOW true."
  (make-insert-event :voice (edit-voice op) :measure (edit-measure op) :offset (edit-offset op)
                     :event (edit-event op) :reflow t))

(defun %overfull (op score voice bar excess)
  "Signal MEASURE-OVERFULL inside the REFLOW restart, whose values are the change
of OP with REFLOW true and that reflowed operation, the one applied from then on
(edits.lisp). Every call is in tail position of %EDIT-CHANGE, so both values
reach APPLY-EDIT."
  (restart-case (error 'measure-overfull :op op :voice (element-id voice) :bar bar :excess excess
                                         :reason "the voice measure would overflow")
    (reflow ()
      :report "Insert with REFLOW true: re-flow the voice into the measures."
      (let ((reflowed (%with-reflow op)))
        (values (%edit-change reflowed score) reflowed)))))

(defun %insert-grace (cell offset event)
  "CELL with the grace EVENT right before its non-grace event at OFFSET."
  (let ((at 0) (out '()) (done nil))
    (dolist (e cell (nreverse out))
      (when (and (not done) (not (%grace-p e)) (= at offset))
        (push event out)
        (setf done t))
      (push e out)
      (unless (%grace-p e) (incf at (event-duration e))))))

(defun %insert-local (op score voice i offset event)
  "INSERT-EVENT without REFLOW into the voice measure I that holds music."
  (let* ((bars (%score-bars score))
         (bar (+ (%bar-table-first bars) i))
         (length (svref (%bar-table-lengths bars) i))
         (start (svref (%bar-table-starts bars) i))
         (d (event-duration event))
         (cell (%cell voice i)))
    (when (> (+ offset d) length)
      (return-from %insert-local (%overfull op score voice bar (- (+ offset d) length))))
    ;; BEFORE ends before the graces of the event at OFFSET; AFTER starts with them.
    (let* ((k (let ((at 0))
                (loop for e in cell
                      for j from 0
                      when (and (not (%grace-p e)) (= at offset)) return j
                      unless (%grace-p e) do (incf at (event-duration e)))))
           (k (loop while (and (plusp k) (%grace-p (nth (1- k) cell))) do (decf k) finally (return k)))
           (before (subseq cell 0 k))
           (after (subseq cell k))
           ;; The run of rests (with graces inside it) that ends the voice measure.
           (j (let ((j (length after)))
                (loop while (and (plusp j) (or (%grace-p (nth (1- j) after))
                                               (typep (nth (1- j) after) 'rest-event)))
                      do (decf j))
                j))
           (run-p (some (lambda (e) (typep e 'rest-event)) (nthcdr j after)))
           (r (if run-p
                  (+ offset d (loop for e in (subseq after 0 j)
                                    unless (%grace-p e) sum (event-duration e)))
                  (+ length d))))
      (if (> r length)
          (%overfull op score voice bar (- r length))
          (%substitute-1 score voice
                         (%with-cells voice i
                                      (list (append before (list event) (subseq after 0 j)
                                                    (and (< r length)
                                                         (%fill op bars i (+ start r) (+ start length)))))))))))

(defun %insert-reflowing (op score voice i offset event)
  "INSERT-EVENT with REFLOW: the time line from the insertion on moves later and
is re-flowed into the measures; rests past the end are cut."
  (let* ((bars (%score-bars score))
         (n (%bar-count bars))
         (start (svref (%bar-table-starts bars) i))
         (t0 (+ start offset))
         (d (event-duration event))
         (end (%bar-table-duration bars))
         (early '()) (late '()) (fills '()))
    (dolist (slot (%voice-slots voice bars))
      (if (< (%slot-onset slot) t0)
          (push slot early)
          (push (%make-slot (+ (%slot-onset slot) d) (%slot-event slot)
                            (%slot-graces slot) (%slot-trailing slot) t)
                late)))
    (let ((kept '()))
      (dolist (slot (cons (%make-slot t0 event) (nreverse late)))
        (let* ((at (%slot-onset slot))
               (stop (+ at (event-duration (%slot-event slot)))))
          (cond ((<= stop end) (push slot kept))
                ((typep (%slot-event slot) 'rest-event)
                 (when (< at end) (push (cons at end) fills)))
                (t (%off op stop "the music would end after the end of the score")))))
      (let ((slots (remove-if (lambda (slot) (< (%slot-onset slot) start))
                              (append (nreverse early) (nreverse kept)))))
        (%substitute-1 score voice (%with-cells voice i (%assemble op slots fills bars i (1- n))))))))

(defmethod %edit-change ((op insert-event) (score score))
  (let* ((voice (%target score op (edit-voice op) 'voice "a voice"))
         (entry (%target-entry score op (edit-measure op) 'measure-info "a measure"))
         (bars (%score-bars score))
         (i (%entry-measure entry))
         (bar (+ (%bar-table-first bars) i))
         (offset (edit-offset op))
         (event (edit-event op))
         (length (svref (%bar-table-lengths bars) i))
         (cell (%cell voice i)))
    (when (>= offset length)
      (%off op (cons bar offset) "not inside the bar"))
    (when (and (or cell (%grace-p event))
               (not (member offset (%boundaries cell))))
      (%off op (cons bar offset) "not an event boundary of the voice measure"))
    (%check-given score op (list event) '())
    (cond ((%grace-p event)
           (%substitute-1 score voice (%with-cells voice i (list (%insert-grace cell offset event)))))
          ((and (null cell) (<= (+ offset (event-duration event)) length))
           (let ((slot (%make-slot (+ (svref (%bar-table-starts bars) i) offset) event)))
             (%substitute-1 score voice (%with-cells voice i (%assemble op (list slot) '() bars i i)))))
          ((edit-reflow op) (%insert-reflowing op score voice i offset event))
          ((null cell)
           (%overfull op score voice bar (- (+ offset (event-duration event)) length)))
          (t (%insert-local op score voice i offset event)))))

;;; The other event operations ---------------------------------------------------------

(defmethod %edit-change ((op delete-event) (score score))
  (let* ((entry (%target-entry score op (edit-id op) 'event "an event"))
         (event (%entry-element entry))
         (voice (%entry-voice entry))
         (i (%entry-measure entry))
         (cell (%cell voice i))
         (length (svref (%bar-table-lengths (%score-bars score)) i)))
    (%substitute-1
     score voice
     (%with-cells voice i
                  (list (cond ((%grace-p event) (remove event cell :test #'eq :count 1))
                              ((typep event 'sounding-event)
                               (substitute (apply #'make-rest-event
                                                  :id (element-id event) :duration (event-duration event)
                                                  :tuplet (event-tuplet event)
                                                  :measure-rest-p (and (= (event-duration event) length)
                                                                       (= 1 (count-if-not #'%grace-p cell)))
                                                  (%user-provenance))
                                           event cell :test #'eq :count 1))
                              ((every (lambda (e) (or (%grace-p e) (typep e 'rest-event))) cell) '())
                              (t (%refuse op "a rest among notes"))))))))

(defmethod %edit-change ((op replace-event) (score score))
  (let ((old (%target score op (edit-id op) 'event "an event"))
        (new (edit-event op)))
    (unless (member (element-id new) (list nil (edit-id op)) :test #'equal)
      (%refuse op "the new event has another id"))
    (unless (eq (%grace-p old) (%grace-p new))
      (%refuse op "a grace event replaces only a grace event"))
    (unless (or (%grace-p new) (= (event-duration new) (event-duration old)))
      (%refuse op "the new event has another duration"))
    (%check-given score op (list new) (list old))
    (%substitute-1 score old (%with-id new (edit-id op)))))

(defmethod %edit-change ((op set-voice-measures) (score score))
  (let* ((voice (%target score op (edit-voice op) 'voice "a voice"))
         (entry (%target-entry score op (edit-measure op) 'measure-info "a measure"))
         (bars (%score-bars score))
         (i (%entry-measure entry))
         (measures (edit-measures op)))
    (when (> (+ i (length measures)) (%bar-count bars))
      (%off op (+ (%bar-table-first bars) (%bar-count bars)) "past the end of the score"))
    (%check-given score op (apply #'append measures)
                  (loop for j from i below (+ i (length measures)) append (%cell voice j)))
    (%substitute-1 score voice (%with-cells voice i measures))))

(defmethod %edit-change ((op set-pitch) (score score))
  (let ((note (%target score op (edit-id op) '(or note-event chord-note) "a note")))
    (%substitute-1 score note (%user note :pitch (edit-pitch op)))))

(defmethod %edit-change ((op set-accidental) (score score))
  (let ((note (%target score op (edit-id op) '(or note-event chord-note) "a note")))
    (%substitute-1 score note (%user note :accidental (edit-accidental op)))))

(defmethod %edit-change ((op set-duration) (score score))
  (let* ((entry (%target-entry score op (edit-id op) 'event "an event"))
         (event (%entry-element entry))
         (new (%user event :duration (edit-duration op) :tuplet (edit-tuplet op))))
    (if (%grace-p event)
        (%substitute-1 score event new)
        (%write op score entry new))))

;;; Marks, spanners, chord symbols ------------------------------------------------------

(defun %mark-place (mark)
  "The +MARK-PLACES+ row of MARK."
  (find-if (lambda (row) (typep mark (first row))) +mark-places+))

(defmethod %edit-change ((op add-mark) (score score))
  (let* ((target (%target score op (edit-target op) 'element "an element"))
         (mark (edit-mark op)))
    (destructuring-bind (class type reader key) (%mark-place mark)
      (declare (ignore class))
      (unless (typep target type)
        (%refuse op (format nil "~A can't hold this mark" (edit-target op))))
      (let* ((old (funcall reader target))
             (replaced (if (eq key :single)
                           old
                           (find (funcall key mark) old :key key))))
        (%check-given score op (list mark) (and replaced (list replaced)))
        (let* ((mark (if (and replaced (null (element-id mark)))
                         (%with-id mark (element-id replaced))
                         mark))
               (value (cond ((eq key :single) mark)
                            (replaced (substitute mark replaced old :test #'eq :count 1))
                            (t (append old (list mark))))))
          (%substitute-1 score target (%remake target (%field-initarg-of target reader) value)))))))

(defmethod %edit-change ((op remove-mark) (score score))
  (%substitute-1 score (%target score op (edit-id op) '(satisfies %mark-p) "a mark") :remove))

(defmethod %edit-change ((op add-spanner) (score score))
  (let ((spanner (edit-spanner op)))
    (%check-given score op (list spanner) '())
    (%build-score score :spanners (append (%spanner-list score) (list spanner)))))

(defmethod %edit-change ((op remove-spanner) (score score))
  (let ((spanner (%target score op (edit-id op) 'spanner "a spanner")))
    (%build-score score :spanners (remove spanner (%spanner-list score) :test #'eq))))

(defmethod %edit-change ((op add-chord-symbol) (score score))
  (let* ((anchor (edit-anchor op))
         (anchors (%anchor-list score))
         (old (find (anchor-position anchor) anchors :key #'anchor-position :test #'equal)))
    (%check-given score op (list anchor) (and old (list old)))
    (let ((new (if (and old (null (element-id anchor))) (%with-id anchor (element-id old)) anchor)))
      (%build-score score :anchors (if old
                                       (substitute new old anchors :test #'eq :count 1)
                                       (append anchors (list new)))))))

(defmethod %edit-change ((op remove-chord-symbol) (score score))
  (let ((anchor (%target score op (edit-id op) 'chord-symbol-anchor "a chord-symbol anchor")))
    (%build-score score :anchors (remove anchor (%anchor-list score) :test #'eq))))
