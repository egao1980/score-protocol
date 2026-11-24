;;;; SC0 the measure map, bars and positions.
;;;;
;;;; The measure map (SCORE-MEASURE-MAP) is the one sequence of MEASURE-INFOs
;;;; that every part shares; voice measure i of every voice is measure i.
;;;;
;;;; MEASURE-INFO slots (readers MEASURE-INFO-<slot>), types and defaults:
;;;;   NUMBER        NIL or a string: the printed measure number ("12a"). A
;;;;                 label only, never used for arithmetic.
;;;;   TIME          NIL (unchanged) or a music-theory METER
;;;;   KEY           NIL (unchanged) or a music-theory KEY
;;;;   PICKUP-P      true for an anacrusis; only the first measure may be one
;;;;   LENGTH        NIL (the meter's bar), or a positive rational: the actual
;;;;                 length of a pickup or of a measure flagged incomplete
;;;;   BARLINE       the barline at the measure's end, a keyword of +BARLINES+,
;;;;                 default :REGULAR
;;;;   REPEAT-START  true for a forward repeat sign at the measure's start
;;;;   REPEAT-END    NIL, or an integer >= 2: a backward repeat sign at the
;;;;                 measure's end, and how many times the section is played in
;;;;                 all (MusicXML times; usually 2)
;;;;   ENDING        NIL, or an ENDING (a volta bracket) that starts on this
;;;;                 measure: PASSES, the passes on which its measures are played
;;;;                 (a non-empty list of positive integers), and MEASURES, how
;;;;                 many measures it spans from here (an integer >= 1, default 1)
;;;;   JUMP          a list of JUMP-MARKs, each with a KIND of +JUMPS+. :SEGNO and
;;;;                 :CODA mark the measure's start (the D.S. target, the coda's
;;;;                 entry); the others act at its end.
;;;;   REHEARSAL     NIL, or a REHEARSAL-MARK with TEXT, a string ("A", "Verse 2")
;;;;   TEMPO         a list of TEMPO-MARKs, each OFFSET (a rational >= 0, default
;;;;                 0, from the measure's start), TEMPO (NIL or a music-theory
;;;;                 TEMPO) and TEXT (NIL or a string such as "Andante")
;;;; Endings, jump marks, rehearsal marks and tempo marks are elements, with ids
;;;; (elements.lisp), and their constructors (MAKE-ENDING, MAKE-JUMP-MARK,
;;;; MAKE-REHEARSAL-MARK, MAKE-TEMPO-MARK) check their slots' types.
;;;; MAKE-MEASURE-INFO checks these types (TYPE-ERROR) and normalises: JUMP
;;;; stable-sorted by kind in +JUMPS+ order (two of one kind are kept: a
;;;; :DUPLICATE-MARK issue), TEMPO stable-sorted by offset, booleans to T or
;;;; NIL. MAKE-ENDING stores PASSES ascending without duplicates. An ending that
;;;; runs past the last measure, or starts inside an earlier one, is a
;;;; :BAD-ENDING issue; a tempo mark at or past the end of its bar a
;;;; :TEMPO-MARK-POSITION issue.
;;;; How repeats, endings and jumps unfold into playback order is SC1 (UNFOLD).
;;;;
;;;; Bars. Bar numbers are indices. When the first measure is a pickup it is bar
;;;; 0 and the next one is bar 1; otherwise the first measure is bar 1.
;;;; SCORE-FIRST-BAR is 0 or 1. SCORE-LAST-BAR is the first bar + the number of
;;;; measures - 1, so a score with no measures has first bar 1 and last bar 0.
;;;; Only the first measure's PICKUP-P affects numbering.
;;;;
;;;; Signatures are inherited. BAR-TIME is the TIME of the latest measure at or
;;;; before the bar that has one, else 4/4 (MAKE-METER's default); BAR-KEY the
;;;; same for KEY, else C major (MAKE-KEY's default). A first measure without
;;;; both is a :MISSING-SIGNATURE issue (check.lisp).
;;;;
;;;; Lengths. BAR-LENGTH is the measure's LENGTH when it has one, else
;;;; (meter-measure-duration (bar-time score bar)). A pickup must give a LENGTH
;;;; shorter than its meter's bar (:BAD-PICKUP otherwise). The final bar may
;;;; complete the pickup (its LENGTH is the rest of the bar), but nothing
;;;; requires that. BAR-START of the first bar is 0, and BAR-START of bar b + 1
;;;; is BAR-START b + BAR-LENGTH b. SCORE-DURATION is the sum of the lengths of
;;;; all bars, 0 with no measures. BAR-MEASURE is the bar's MEASURE-INFO.
;;;;
;;;; Positions are (BAR . OFFSET) conses: OFFSET is a rational in whole notes
;;;; from the start of the bar. A position is valid in a score when BAR is one of
;;;; its bars and 0 <= OFFSET <= BAR-LENGTH; the end of a bar is the same
;;;; instant as the start of the next.
;;;;   ABSOLUTE-OFFSET score position = BAR-START bar + OFFSET.
;;;;   OFFSET-POSITION score offset, for 0 <= offset <= SCORE-DURATION: the bar b
;;;;     with BAR-START b <= offset < BAR-START b + BAR-LENGTH b, and offset -
;;;;     BAR-START b; at the very end, (last bar . its length). So an offset on a
;;;;     barline gives (next bar . 0). In a pickup score, (1 . 0) is the pickup's
;;;;     length.
;;;; An invalid position, an offset outside 0..SCORE-DURATION, or a bar outside
;;;; first..last bar (for the BAR-* functions) signals INVALID-POSITION with
;;;; POSITION = the argument, inside a USE-VALUE restart whose value is returned.
;;;; Its REASON says what is wrong (SC3):
;;;;   BAR-* functions, and ABSOLUTE-OFFSET for a bar that isn't one of the
;;;;     score's            "no such bar"
;;;;   ABSOLUTE-OFFSET, offset < 0
;;;;                        "negative offset"
;;;;   ABSOLUTE-OFFSET, offset > BAR-LENGTH
;;;;                        "offset past the end of bar B (length L)", B the bar
;;;;                        and L its BAR-LENGTH printed with ~A: so (0 . 1/2)
;;;;                        in a score whose pickup is a quarter gives "offset
;;;;                        past the end of bar 0 (length 1/4)"
;;;;   OFFSET-POSITION      "outside the score": its argument is an instant.
;;;; With no measures, every position and every bar is invalid. A position that
;;;; isn't a cons, a bar that isn't an integer and an offset that isn't a
;;;; rational are TYPE-ERRORs.
;;;;
;;;; Element positions, ELEMENT-POSITION score id:
;;;;   measure              (bar . 0)
;;;;   event                (bar . offset): BAR is the first bar + the index of
;;;;                        the voice measure that holds it, and OFFSET is the sum
;;;;                        of the durations of the non-grace events before it in
;;;;                        that voice measure. So a grace note sits at the offset
;;;;                        of the event that follows it.
;;;;   chord note, lyric, dynamic, fermata, breath mark, articulation
;;;;                        the position of its event
;;;;   tie                  the position of the event of its start note
;;;;   ending, jump mark, rehearsal mark
;;;;                        (bar . 0) of its measure
;;;;   tempo mark           (bar . OFFSET) of its measure
;;;;   chord-symbol anchor  its ANCHOR-POSITION
;;;;   spanner              the position of its START element, NIL when the score
;;;;                        has no element with that id
;;;;   part, staff, voice   NIL
;;;; ELEMENT-POSITION reports structure and validates nothing: an event in a
;;;; voice measure past the end of the measure map still gets its (bar . offset).
;;;; An event's ONSET is the ABSOLUTE-OFFSET of its position (check.lisp).

(in-package #:score-protocol)

(defparameter +barlines+ '(:regular :double :final :dashed :dotted :heavy :none)
  "MEASURE-INFO-BARLINE values. :FINAL is thin-thick, :DOUBLE thin-thin. Data.")

(defparameter +jumps+
  '(:segno :coda :to-coda :fine :da-capo :da-capo-al-fine :da-capo-al-coda
    :dal-segno :dal-segno-al-fine :dal-segno-al-coda)
  "JUMP-MARK-KIND values, in canonical order. Data.")

(defclass measure-info (element)
  ((number :initarg :number :initform nil :reader measure-info-number)
   (time :initarg :time :initform nil :reader measure-info-time)
   (key :initarg :key :initform nil :reader measure-info-key)
   (pickup-p :initarg :pickup-p :initform nil :reader measure-info-pickup-p)
   (length :initarg :length :initform nil :reader measure-info-length)
   (barline :initarg :barline :initform :regular :reader measure-info-barline)
   (repeat-start :initarg :repeat-start :initform nil :reader measure-info-repeat-start)
   (repeat-end :initarg :repeat-end :initform nil :reader measure-info-repeat-end)
   (ending :initarg :ending :initform nil :reader measure-info-ending)
   (jump :initarg :jump :initform '() :reader measure-info-jump)
   (rehearsal :initarg :rehearsal :initform nil :reader measure-info-rehearsal)
   (tempo :initarg :tempo :initform '() :reader measure-info-tempo))
  (:documentation "One measure of the measure map (file header)."))

(defclass ending (element)
  ((passes :initarg :passes :reader ending-passes)
   (measures :initarg :measures :initform 1 :reader ending-measures)))

(defclass jump-mark (element)
  ((kind :initarg :kind :reader jump-mark-kind)))

(defclass rehearsal-mark (element)
  ((text :initarg :text :reader rehearsal-mark-text)))

(defclass tempo-mark (element)
  ((offset :initarg :offset :initform 0 :reader tempo-mark-offset)
   (tempo :initarg :tempo :initform nil :reader tempo-mark-tempo)
   (text :initarg :text :initform nil :reader tempo-mark-text)))

(defun %barline-p (object) (and (member object +barlines+) t))
(defun %jump-kind-p (object) (and (member object +jumps+) t))
(defun %passes-p (object) (%list-of-p object '(integer 1) t))
(defun %jump-marks-p (object) (%list-of-p object 'jump-mark))
(defun %tempo-marks-p (object) (%list-of-p object 'tempo-mark))

(defun make-ending (&key id passes (measures 1) provenance confidence)
  "An ENDING played on PASSES, spanning MEASURES measures."
  (check-type passes (satisfies %passes-p) "a non-empty list of positive integers")
  (check-type measures (integer 1))
  (%make-element 'ending id provenance confidence
                 :passes (sort (remove-duplicates (copy-list passes)) #'<)
                 :measures measures))

(defun make-jump-mark (&key id kind provenance confidence)
  "A JUMP-MARK with KIND from +JUMPS+."
  (check-type kind (satisfies %jump-kind-p) "a keyword of +JUMPS+")
  (%make-element 'jump-mark id provenance confidence :kind kind))

(defun make-rehearsal-mark (&key id text provenance confidence)
  "A REHEARSAL-MARK with TEXT."
  (check-type text string)
  (%make-element 'rehearsal-mark id provenance confidence :text text))

(defun make-tempo-mark (&key id (offset 0) tempo text provenance confidence)
  "A TEMPO-MARK at OFFSET in its measure: a music-theory TEMPO, TEXT, or both."
  (check-type offset (rational 0))
  (check-type tempo (or null music-theory:tempo))
  (check-type text (or null string))
  (%make-element 'tempo-mark id provenance confidence :offset offset :tempo tempo :text text))

(defun make-measure-info (&key id number time key pickup-p length (barline :regular)
                               repeat-start repeat-end ending jump rehearsal tempo
                               provenance confidence)
  "A MEASURE-INFO (file header)."
  (check-type number (or null string))
  (check-type time (or null music-theory:meter))
  (check-type key (or null music-theory:key))
  (check-type length (or null (rational (0))))
  (check-type barline (satisfies %barline-p) "a keyword of +BARLINES+")
  (check-type repeat-end (or null (integer 2)))
  (check-type ending (or null ending))
  (check-type jump (satisfies %jump-marks-p) "a list of JUMP-MARKs")
  (check-type rehearsal (or null rehearsal-mark))
  (check-type tempo (satisfies %tempo-marks-p) "a list of TEMPO-MARKs")
  (%make-element 'measure-info id provenance confidence
                 :number number :time time :key key :pickup-p (and pickup-p t)
                 :length length :barline barline :repeat-start (and repeat-start t)
                 :repeat-end repeat-end :ending ending
                 :jump (%sort-by-set jump #'jump-mark-kind +jumps+)
                 :rehearsal rehearsal
                 :tempo (stable-sort (copy-list tempo) #'< :key #'tempo-mark-offset)))

;;; The bar table -------------------------------------------------------------
;;; MAKE-SCORE computes it once from the measure map and keeps it in the score's
;;; index (score.lisp); %SCORE-BARS reads it back.

(defstruct (%bar-table (:constructor %make-bar-table) (:copier nil) (:predicate nil))
  "Per measure index: the MEASURE-INFO, its start, its length, and the meter and
key in force. FIRST is the first bar number, DURATION the sum of the lengths."
  (first 1 :type (integer 0 1) :read-only t)
  (measures #() :type simple-vector :read-only t)
  (starts #() :type simple-vector :read-only t)
  (lengths #() :type simple-vector :read-only t)
  (times #() :type simple-vector :read-only t)
  (keys #() :type simple-vector :read-only t)
  (duration 0 :type rational :read-only t))

(defun %compute-bar-table (measures)
  "The bar table of MEASURES, a list of MEASURE-INFOs (file header)."
  (let ((n (length measures))
        (time (music-theory:make-meter))
        (key (music-theory:make-key))
        (start 0))
    (let ((starts (make-array n)) (lengths (make-array n))
          (times (make-array n)) (keys (make-array n)))
      (loop for measure in measures
            for i from 0
            do (setf time (or (measure-info-time measure) time)
                     key (or (measure-info-key measure) key))
               (let ((length (or (measure-info-length measure)
                                 (music-theory:meter-measure-duration time))))
                 (setf (svref starts i) start
                       (svref lengths i) length
                       (svref times i) time
                       (svref keys i) key)
                 (incf start length)))
      (%make-bar-table :first (if (and measures (measure-info-pickup-p (first measures))) 0 1)
                       :measures (coerce measures 'simple-vector)
                       :starts starts :lengths lengths :times times :keys keys
                       :duration start))))

(defgeneric %score-bars (score)
  (:documentation "The bar table of SCORE. The method for SCORE is in score.lisp.")
  (:method (score)
    (error 'type-error :datum score :expected-type 'score)))

(defun %bar-count (table)
  (length (%bar-table-measures table)))

(defun %bar-index (table bar)
  "The measure index of the integer BAR in TABLE, or NIL when it isn't a bar."
  (let ((i (- bar (%bar-table-first table))))
    (and (<= 0 i) (< i (%bar-count table)) i)))

(defun %invalid-position (argument reason)
  "Signal INVALID-POSITION for ARGUMENT inside a USE-VALUE restart; return the
restart's value."
  (restart-case (error 'invalid-position :position argument :reason reason)
    (use-value (value)
      :report "Return a value instead."
      :interactive (lambda ()
                     (format *query-io* "~&Value to return: ")
                     (finish-output *query-io*)
                     (list (read *query-io*)))
      value)))

(defun %bar-slot (score bar vector-reader)
  "The VECTOR-READER entry of BAR in SCORE's bar table, or INVALID-POSITION."
  (check-type bar integer)
  (let* ((table (%score-bars score))
         (i (%bar-index table bar)))
    (if i
        (svref (funcall vector-reader table) i)
        (%invalid-position bar "no such bar"))))

;;; Bars ---------------------------------------------------------------------

(defun score-first-bar (score)
  "0 when the first measure is a pickup, else 1."
  (%bar-table-first (%score-bars score)))

(defun score-last-bar (score)
  "The first bar + the number of measures - 1."
  (let ((table (%score-bars score)))
    (+ (%bar-table-first table) (%bar-count table) -1)))

(defun score-duration (score)
  "The sum of all bar lengths, in whole notes."
  (%bar-table-duration (%score-bars score)))

(defun bar-measure (score bar)
  "The MEASURE-INFO of BAR."
  (%bar-slot score bar #'%bar-table-measures))

(defun bar-time (score bar)
  "The METER in force in BAR (file header: inherited, else 4/4)."
  (%bar-slot score bar #'%bar-table-times))

(defun bar-key (score bar)
  "The KEY in force in BAR (file header: inherited, else C major)."
  (%bar-slot score bar #'%bar-table-keys))

(defun bar-length (score bar)
  "The length of BAR: its measure's LENGTH, else its meter's bar."
  (%bar-slot score bar #'%bar-table-lengths))

(defun bar-start (score bar)
  "The absolute offset of the start of BAR; the first bar starts at 0."
  (%bar-slot score bar #'%bar-table-starts))

;;; Positions ----------------------------------------------------------------

(defun absolute-offset (score position)
  "BAR-START of POSITION's bar + its offset (file header)."
  (check-type position cons "a (bar . offset) position")
  (let ((bar (car position))
        (offset (cdr position)))
    ;; Every type before any range: the type rows sit next to the range rows.
    (check-type bar integer)
    (check-type offset rational)
    (let* ((table (%score-bars score))
           (i (%bar-index table bar))
           (length (and i (svref (%bar-table-lengths table) i))))
      ;; The bar first, then the offset in it (file header: REASON).
      (cond ((null i) (%invalid-position position "no such bar"))
            ((< offset 0) (%invalid-position position "negative offset"))
            ((> offset length)
             (%invalid-position position (format nil "offset past the end of bar ~A (length ~A)"
                                                 bar length)))
            (t (+ (svref (%bar-table-starts table) i) offset))))))

(defun offset-position (score offset)
  "The (bar . offset) position of the absolute OFFSET (file header)."
  (check-type offset rational)
  (let* ((table (%score-bars score))
         (n (%bar-count table))
         (starts (%bar-table-starts table)))
    (cond ((or (zerop n) (< offset 0) (> offset (%bar-table-duration table)))
           (%invalid-position offset "outside the score"))
          ((= offset (%bar-table-duration table))
           (cons (+ (%bar-table-first table) n -1)
                 (svref (%bar-table-lengths table) (1- n))))
          (t
           (let ((i (position-if (lambda (start) (<= start offset)) starts :from-end t)))
             (cons (+ (%bar-table-first table) i) (- offset (svref starts i))))))))
