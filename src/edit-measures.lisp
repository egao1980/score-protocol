;;;; SC1 edits of the measure map, and transposition.
;;;;
;;;; Terms as in edit-events.lisp. A measure's own TIME or KEY is the slot of its
;;;; MEASURE-INFO; the meter or key IN FORCE at a bar is BAR-TIME or BAR-KEY
;;;; (measure-map.lisp). Bars are counted in the score the rule speaks of.
;;;; A chord-symbol anchor outside the measures an operation changes STAYS
;;;; WITH ITS MEASURE: its bar becomes that measure's bar in the result, its
;;;; offset unchanged (it changes in place, provenance :user, when the number
;;;; differs). So anchors move when measures are inserted or deleted before
;;;; them, and stay put when a pickup is deleted.
;;;;
;;;; Keeping signatures in force. Several operations change what a measure
;;;; inherits. Where a rule says a measure KEEPS ITS SIGNATURES, that measure,
;;;; when it has no TIME of its own and the meter it would inherit after the
;;;; change differs (EQUALP) from the meter in force at it before, gets that
;;;; earlier meter as its own TIME; the same for KEY. A measure that becomes the
;;;; first one gets the meter and key in force at it before whenever it has no
;;;; TIME or KEY of its own. Such a measure changes in place (provenance :user).
;;;;
;;;; SET-KEY, slots MEASURE (an id) and KEY (NIL or a music-theory KEY with a
;;;; signature of -7..7): the measure's own KEY becomes KEY; NIL removes the key
;;;; change there. Pitches don't change. KEY NIL on the first measure fails the
;;;; check (:MISSING-SIGNATURE).
;;;;
;;;; SET-TIME, slots MEASURE (an id) and TIME (NIL or a METER): re-bars. The
;;;; REGION is MEASURE and the measures after it up to, not including, the next
;;;; measure with a TIME of its own (or the end). Let S be its start, R its
;;;; duration (the sum of its bar lengths before the edit) and B the bar of the
;;;; meter in force at MEASURE after the edit (TIME, or with NIL the meter in
;;;; force at the measure before it, else 4/4).
;;;;   New bars. When MEASURE is a pickup, the first new bar keeps the pickup's
;;;;   LENGTH; then come bars of length B, and the last one is shorter when R
;;;;   doesn't divide evenly: k' bars in all. A bar of length B has LENGTH NIL;
;;;;   the pickup and a short last bar have their length as LENGTH.
;;;;   Measures. A new bar that starts at the absolute offset where a measure of
;;;;   the region started before is that measure, with its id and everything on
;;;;   it, and LENGTH as just said; MEASURE is the first, with TIME as its own.
;;;;   Every other new bar is a new measure (minted, otherwise default). A
;;;;   measure of the region whose start is no new bar's start is removed; one
;;;;   that carries a KEY of its own, a jump mark, a rehearsal mark, an ending
;;;;   or a repeat sign signals INVALID-EDIT, since re-barring would lose it.
;;;;   Every tempo mark of the region keeps its absolute offset: it moves to the
;;;;   new bar holding that offset, at the offset from that bar's start, with
;;;;   its id. The new last bar gets the BARLINE the region's last measure had;
;;;;   that measure, when it is kept but no longer last, gets :REGULAR. The
;;;;   other kept measures keep theirs.
;;;;   Music. Every voice's time line over the region is re-flowed into the
;;;;   new bars (edit-events.lisp). Chord-symbol anchors in the region keep
;;;;   their absolute offsets too: each moves to the new bar holding it.
;;;;   Anchors after the region stay with their measures.
;;;;   So 4/4 → 3/4 over four whole-note bars gives five full bars and a
;;;;   quarter: the first and fourth measures stay (at offsets 0 and 3), the
;;;;   second and third go, and the notes tie across the new barlines.
;;;;
;;;; REPLACE-MEASURE, slots ID (a measure) and MEASURE-INFO (a MEASURE-INFO,
;;;; given, whose id is NIL or ID, else INVALID-EDIT): MEASURE-INFO takes the
;;;; measure's place with id ID; the elements on the old measure whose ids it
;;;; doesn't carry are removed. Voices don't change: a new length fails the
;;;; check unless the voice measures already fit. This is how barlines, repeat
;;;; signs, numbers and lengths change, and how INVERT-EDIT restores a measure.
;;;;
;;;; INSERT-MEASURES, slots BEFORE (NIL or a measure id), MEASURE-INFOS (a
;;;; non-empty list of MEASURE-INFOs, given) and CONTENTS (a list of entries
;;;; (voice-id voice-measure...), the voice measures lists of EVENTs, given):
;;;; the measures go before the measure BEFORE, or after the last one when
;;;; BEFORE is NIL, in order; n = their number. Every voice gets n new voice
;;;; measures at the same place: those of its CONTENTS entry (it must name a
;;;; voice, else EDIT-TARGET-MISSING, and hold n voice measures, else
;;;; INVALID-EDIT; a voice named twice is INVALID-EDIT), or else, for the first
;;;; voice of each staff of each part (the first of the part's VOICES with that
;;;; STAFF), one rest of the bar's length with MEASURE-REST-P per new measure,
;;;; minted, and for the other voices silent voice measures. Anchors stay with
;;;; their measures, so those from the insertion on move n bars later.
;;;; Inserted before the first
;;;; measure, the first new measure takes the old first measure's TIME and KEY
;;;; when it has none of its own. The measure BEFORE keeps its signatures.
;;;; (make-insert-measures :count n) with no MEASURE-INFOS gives n new default
;;;; measures (MAKE-MEASURE-INFO with no arguments).
;;;;
;;;; DELETE-MEASURES, slots MEASURE (an id) and COUNT (an integer >= 1, default
;;;; 1): the measures from MEASURE on, COUNT of them, which must all exist
;;;; (EDIT-POSITION-INVALID, POSITION = the first bar past the end), are
;;;; removed with everything on them, every voice's voice measures there, and
;;;; the anchors in those bars. The anchors after them stay with their measures
;;;; (COUNT bars earlier, unless a pickup is among the deleted ones). The
;;;; measure after them keeps its signatures (and when the first measure is
;;;; deleted, the new first measure gets them). Ties and spanners that lose an
;;;; endpoint go with the cascade.
;;;;
;;;; TRANSPOSE, slots INTERVAL (NIL or a music-theory INTERVAL with a name),
;;;; TO-KEY (NIL or a KEY with a signature of -7..7), PARTS (a list of part ids;
;;;; NIL for all parts), FROM and TO (NIL or measure ids: the first and last
;;;; measures of the range; NIL for the first and the last measure). Exactly one
;;;; of INTERVAL and TO-KEY must be given (INVALID-EDIT), FROM must not come
;;;; after TO (EDIT-POSITION-INVALID, POSITION = TO's bar), and PARTS must name
;;;; parts.
;;;;   Moving. The spelling is music-theory's; nothing here re-derives it.
;;;;   With INTERVAL, a pitch p moves to (transpose-pitch p INTERVAL), a chord
;;;;   symbol c to (transpose-chord-symbol c INTERVAL), and a key tonic t (a
;;;;   PITCH-CLASS-NAME) to the class of (transpose-pitch t-in-octave-4
;;;;   INTERVAL). With TO-KEY, let F be the key in force at FROM: p moves to
;;;;   (transpose-to-key p F TO-KEY), c to (transpose-chord-symbol c (list F
;;;;   TO-KEY)) and t to (transpose-to-key t F TO-KEY) (MT4: the letter moves at
;;;;   most three steps, roots and basses respell as notes do, modes play no
;;;;   part). Moving a key K keeps its mode and moves its tonic.
;;;;   Notes. Every note event and chord note of the voices of PARTS in the bars
;;;;   FROM to TO, grace notes included, moves; its accidental display is kept.
;;;;   With some parts only, that is all: keys and chord symbols belong to the
;;;;   whole score and stay.
;;;;   Keys and chord symbols, when the scope covers every part. Each measure m
;;;;   of the range has the key K in force there; its MOVED KEY is K', and its
;;;;   TARGET key T is (choose-enharmonic-key K' :max-accidentals 7): K' itself
;;;;   when K' is one of the 30 keys, else the one of them that sounds like it.
;;;;   Each measure of the range with a KEY of its own gets T, and FROM's
;;;;   measure gets its T when it has none. Each anchor in the range moves; each
;;;;   note moves; and where T differs from K', both are then respelled from K'
;;;;   to T: (transpose-chord-symbol c (list K' T)) and (transpose-to-key p K'
;;;;   T), the same sounds spelled for T. So G major up an augmented unison is
;;;;   Ab major, with the notes spelled for Ab major, not G# major with eight
;;;;   sharps. The measure after TO keeps its signatures. Anchors lose their
;;;;   TEXT (TRANSPOSE-CHORD-SYMBOL); N.C. stays N.C.
;;;;   A pitch, root or bass beyond two accidentals signals INVALID-EDIT. A tie
;;;;   from inside the range to a note outside it breaks and goes with the
;;;;   cascade.

(in-package #:score-protocol)

(defun %signature-key-p (object)
  "True when OBJECT is a KEY with a signature of -7..7."
  (and (typep object 'music-theory:key)
       (handler-case (progn (music-theory:key-signature object) t)
         (music-theory:invalid-key () nil))))

(defun %named-interval-p (object)
  "True when OBJECT is an INTERVAL that INTERVAL-NAME can print."
  (and (typep object 'music-theory:interval)
       (handler-case (progn (music-theory:interval-name object) t)
         (music-theory:invalid-interval () nil))))

(defun %measure-infos-p (object) (%list-of-p object 'measure-info t))
(defun %id-list-p (object) (%list-of-p object '%id))

(defun %contents-p (object)
  "True when OBJECT is a list of (voice-id voice-measure...) entries, each voice
measure a list of EVENTs."
  (%list-of-p object '(satisfies %contents-entry-p)))

(defun %contents-entry-p (object)
  (and (consp object) (valid-id-p (car object)) (%event-measures-p (cdr object))))

;;; Classes -------------------------------------------------------------------

(defclass set-key (edit-operation)
  ((measure :initarg :measure :reader edit-measure)
   (key :initarg :key :reader edit-key)))

(defclass set-time (edit-operation)
  ((measure :initarg :measure :reader edit-measure)
   (time :initarg :time :reader edit-time)))

(defclass replace-measure (edit-operation)
  ((id :initarg :id :reader edit-id)
   (measure-info :initarg :measure-info :reader edit-measure-info)))

(defclass insert-measures (edit-operation)
  ((before :initarg :before :reader edit-before)
   (measure-infos :initarg :measure-infos :reader edit-measure-infos)
   (contents :initarg :contents :reader edit-contents)))

(defclass delete-measures (edit-operation)
  ((measure :initarg :measure :reader edit-measure)
   (count :initarg :count :reader edit-count)))

(defclass transpose (edit-operation)
  ((interval :initarg :interval :reader edit-interval)
   (to-key :initarg :to-key :reader edit-to-key)
   (parts :initarg :parts :reader edit-parts)
   (from :initarg :from :reader edit-from)
   (to :initarg :to :reader edit-to)))

;;; Constructors ----------------------------------------------------------------

(defun make-set-key (&key measure key)
  "A SET-KEY of the measure MEASURE (file header)."
  (check-type measure %id "an id string")
  (check-type key (or null (satisfies %signature-key-p)) "NIL or a KEY of -7..7")
  (make-instance 'set-key :measure measure :key key))

(defun make-set-time (&key measure time)
  "A SET-TIME of the measure MEASURE (file header)."
  (check-type measure %id "an id string")
  (check-type time (or null music-theory:meter))
  (make-instance 'set-time :measure measure :time time))

(defun make-replace-measure (&key id measure-info)
  "A REPLACE-MEASURE of the measure ID by MEASURE-INFO (file header)."
  (check-type id %id "an id string")
  (check-type measure-info measure-info)
  (make-instance 'replace-measure :id id :measure-info measure-info))

(defun make-insert-measures (&key before (measure-infos nil measure-infos-p) count contents)
  "An INSERT-MEASURES of MEASURE-INFOS, or of COUNT default measures, before
BEFORE (file header)."
  (check-type before (or null %id) "NIL or an id string")
  (check-type count (or null (integer 1)))
  (let ((measure-infos (if (and (not measure-infos-p) count)
                           (loop repeat count collect (make-measure-info))
                           measure-infos)))
    (check-type measure-infos (satisfies %measure-infos-p) "a non-empty list of MEASURE-INFOs")
    (check-type contents (satisfies %contents-p)
                "a list of (voice-id voice-measure...) entries")
    (make-instance 'insert-measures
                   :before before :measure-infos (copy-list measure-infos)
                   :contents (mapcar (lambda (entry)
                                       (cons (car entry) (mapcar #'copy-list (cdr entry))))
                                     contents))))

(defun make-delete-measures (&key measure (count 1))
  "A DELETE-MEASURES of COUNT measures from MEASURE (file header)."
  (check-type measure %id "an id string")
  (check-type count (integer 1))
  (make-instance 'delete-measures :measure measure :count count))

(defun make-transpose (&key interval to-key parts from to)
  "A TRANSPOSE by INTERVAL or to TO-KEY of PARTS between FROM and TO (file header)."
  (check-type interval (or null (satisfies %named-interval-p)) "NIL or a named INTERVAL")
  (check-type to-key (or null (satisfies %signature-key-p)) "NIL or a KEY of -7..7")
  (check-type parts (satisfies %id-list-p) "a list of id strings")
  (check-type from (or null %id) "NIL or an id string")
  (check-type to (or null %id) "NIL or an id string")
  (make-instance 'transpose :interval interval :to-key to-key :parts (copy-list parts)
                            :from from :to to))

;;; Application ---------------------------------------------------------------

(defmethod apply-edit ((score score) (op set-key))
  (%sc1-pending 'apply-edit/set-key))

(defmethod apply-edit ((score score) (op set-time))
  (%sc1-pending 'apply-edit/set-time))

(defmethod apply-edit ((score score) (op replace-measure))
  (%sc1-pending 'apply-edit/replace-measure))

(defmethod apply-edit ((score score) (op insert-measures))
  (%sc1-pending 'apply-edit/insert-measures))

(defmethod apply-edit ((score score) (op delete-measures))
  (%sc1-pending 'apply-edit/delete-measures))

(defmethod apply-edit ((score score) (op transpose))
  (%sc1-pending 'apply-edit/transpose))
