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

(defun make-ending (&key id passes (measures 1) provenance confidence)
  "An ENDING played on PASSES, spanning MEASURES measures."
  (declare (ignorable id passes measures provenance confidence))
  (%sc0-pending 'make-ending))

(defun make-jump-mark (&key id kind provenance confidence)
  "A JUMP-MARK with KIND from +JUMPS+."
  (declare (ignorable id kind provenance confidence))
  (%sc0-pending 'make-jump-mark))

(defun make-rehearsal-mark (&key id text provenance confidence)
  "A REHEARSAL-MARK with TEXT."
  (declare (ignorable id text provenance confidence))
  (%sc0-pending 'make-rehearsal-mark))

(defun make-tempo-mark (&key id (offset 0) tempo text provenance confidence)
  "A TEMPO-MARK at OFFSET in its measure: a music-theory TEMPO, TEXT, or both."
  (declare (ignorable id offset tempo text provenance confidence))
  (%sc0-pending 'make-tempo-mark))

(defun make-measure-info (&key id number time key pickup-p length (barline :regular)
                               repeat-start repeat-end ending jump rehearsal tempo
                               provenance confidence)
  "A MEASURE-INFO (file header)."
  (declare (ignorable id number time key pickup-p length barline repeat-start
                      repeat-end ending jump rehearsal tempo provenance confidence))
  (%sc0-pending 'make-measure-info))

;;; Bars ---------------------------------------------------------------------

(defun score-first-bar (score)
  "0 when the first measure is a pickup, else 1."
  (declare (ignorable score))
  (%sc0-pending 'score-first-bar))

(defun score-last-bar (score)
  "The first bar + the number of measures - 1."
  (declare (ignorable score))
  (%sc0-pending 'score-last-bar))

(defun score-duration (score)
  "The sum of all bar lengths, in whole notes."
  (declare (ignorable score))
  (%sc0-pending 'score-duration))

(defun bar-measure (score bar)
  "The MEASURE-INFO of BAR."
  (declare (ignorable score bar))
  (%sc0-pending 'bar-measure))

(defun bar-time (score bar)
  "The METER in force in BAR (file header: inherited, else 4/4)."
  (declare (ignorable score bar))
  (%sc0-pending 'bar-time))

(defun bar-key (score bar)
  "The KEY in force in BAR (file header: inherited, else C major)."
  (declare (ignorable score bar))
  (%sc0-pending 'bar-key))

(defun bar-length (score bar)
  "The length of BAR: its measure's LENGTH, else its meter's bar."
  (declare (ignorable score bar))
  (%sc0-pending 'bar-length))

(defun bar-start (score bar)
  "The absolute offset of the start of BAR; the first bar starts at 0."
  (declare (ignorable score bar))
  (%sc0-pending 'bar-start))

;;; Positions ----------------------------------------------------------------

(defun absolute-offset (score position)
  "BAR-START of POSITION's bar + its offset (file header)."
  (declare (ignorable score position))
  (%sc0-pending 'absolute-offset))

(defun offset-position (score offset)
  "The (bar . offset) position of the absolute OFFSET (file header)."
  (declare (ignorable score offset))
  (%sc0-pending 'offset-position))
