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
;;;;   Origins (0.4.0, elements.lisp). An anchor's ORIGIN whose VALUE is a
;;;;   chord symbol moves with the anchor: the value moves exactly as the
;;;;   anchor's own symbol does in that bar (the same transposition, the same
;;;;   respelling to T), and the ID stays. So the origin keeps reading as the
;;;;   replaced symbol would in the transposed score. An anchor changes (and
;;;;   gets provenance :user with the moved origin) when its symbol or its
;;;;   origin's value moves; an origin with no value is kept as it is. Origins
;;;;   of other elements (notes) are kept.
;;;;   A pitch, root or bass beyond two accidentals signals INVALID-EDIT. A tie
;;;;   from inside the range to a note outside it breaks and goes with the
;;;;   cascade.

(in-package #:score-protocol)

(defun %move-anchor-origin (anchor symbol move table)
  "TRANSPOSE (0.4.0, file header, Origins): ANCHOR, whose origin has a chord-symbol
value, moves to SYMBOL and its origin's value to (funcall MOVE value); when either
changes, TABLE maps ANCHOR to the anchor with both, provenance :user."
  (declare (ignore anchor symbol move table))
  (%sc4-pending '%move-anchor-origin))

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

;;; Shared rules ---------------------------------------------------------------------

(defun %signatures-kept (measure old-time old-key new-time new-key &optional first)
  "MEASURE keeping its signatures (file header): with no TIME of its own it gets
OLD-TIME, the meter in force at it before, when NEW-TIME (what it inherits after
the change) differs, or always when it becomes the FIRST measure; the same for
KEY. MEASURE itself when nothing changes."
  (flet ((kept (own old new)
           (and (null own) (or first (not (equalp new old))) old)))
    (let ((time (kept (measure-info-time measure) old-time new-time))
          (key (kept (measure-info-key measure) old-key new-key)))
      (if (or time key)
          (apply #'%user measure (append (and time (list :time time)) (and key (list :key key))))
          measure))))

(defun %keep-at (draft j old-bars i &optional first)
  "DRAFT, a list of measures, with its measure J keeping the signatures it had at
index I of OLD-BARS (%SIGNATURES-KEPT)."
  (let* ((new-bars (%compute-bar-table draft))
         (measure (nth j draft))
         (kept (%signatures-kept measure
                                 (svref (%bar-table-times old-bars) i) (svref (%bar-table-keys old-bars) i)
                                 (svref (%bar-table-times new-bars) j) (svref (%bar-table-keys new-bars) j)
                                 first)))
    (if (eq kept measure)
        draft
        (append (subseq draft 0 j) (list kept) (nthcdr (1+ j) draft)))))

(defun %anchors-staying (score new-bars index)
  "SCORE's anchors after a change of the measure map: each stays with its measure
(file header), INDEX mapping its old measure index to the new one (NIL: the
anchor goes; :KEEP: it is left as it is)."
  (let ((old-first (%bar-table-first (%score-bars score)))
        (count (%bar-count (%score-bars score)))
        (anchors '()))
    (dolist (anchor (%anchor-list score) (nreverse anchors))
      (let* ((position (anchor-position anchor))
             (i (- (car position) old-first))
             (j (if (< -1 i count) (funcall index i anchor) :keep)))
        (cond ((null j))
              ((eq j :keep) (push anchor anchors))
              ((consp j) (push (%moved-anchor anchor j) anchors))
              (t (push (%moved-anchor anchor (cons (+ (%bar-table-first new-bars) j) (cdr position)))
                       anchors)))))))

(defun %moved-anchor (anchor position)
  "ANCHOR at POSITION: itself when it is there already, else changed (:USER)."
  (if (equal position (anchor-position anchor))
      anchor
      (%user anchor :position position)))

(defun %map-voices (score fn)
  "SCORE's parts with every voice v replaced by (funcall fn v part)."
  (mapcar (lambda (part)
            (values (%map-children part (lambda (child)
                                          (if (typep child 'voice)
                                              (let ((new (funcall fn child part)))
                                                (values new (not (eq new child))))
                                              (values child nil))))))
          (%part-list score)))

(defun %with-span (voice from below cells)
  "VOICE with its voice measures FROM..BELOW-1 replaced by CELLS (event lists)."
  (let ((seq (voice-measures voice)))
    (%rebuild voice (%element-row voice) (element-id voice)
              (list (cons (%row-field voice :measures)
                          (fset:concat (fset:subseq seq 0 from)
                                       (fset:convert 'fset:seq (mapcar (lambda (cell) (fset:convert 'fset:seq cell))
                                                                       cells))
                                       (fset:subseq seq below)))))))

;;; SET-KEY, REPLACE-MEASURE ---------------------------------------------------------

(defmethod %edit-change ((op set-key) (score score))
  (let ((measure (%target score op (edit-measure op) 'measure-info "a measure")))
    (if (equalp (measure-info-key measure) (edit-key op))
        score
        (%substitute-1 score measure (%user measure :key (edit-key op))))))

(defmethod %edit-change ((op replace-measure) (score score))
  (let ((old (%target score op (edit-id op) 'measure-info "a measure"))
        (new (edit-measure-info op)))
    (unless (member (element-id new) (list nil (edit-id op)) :test #'equal)
      (%refuse op "the new measure has another id"))
    (%check-given score op (list new) (list old))
    (%substitute-1 score old (%with-id new (edit-id op)))))

;;; INSERT-MEASURES, DELETE-MEASURES ---------------------------------------------------

(defun %first-of-staff-p (voice part)
  "True when VOICE is the first of PART's voices on its staff."
  (eq voice (find (voice-staff voice) (part-voices part) :key #'voice-staff)))

(defmethod %edit-change ((op insert-measures) (score score))
  (let* ((before (and (edit-before op)
                      (%target-entry score op (edit-before op) 'measure-info "a measure")))
         (infos (edit-measure-infos op))
         (n (length infos))
         (bars (%score-bars score))
         (measures (%measure-list score))
         (count (length measures))
         (p (if before (%entry-measure before) count))
         (contents '()))
    (%check-given score op infos '())
    (dolist (entry (edit-contents op))
      (let ((voice (%target score op (car entry) 'voice "a voice")))
        (unless (= n (length (cdr entry)))
          (%refuse op "contents of the wrong length"))
        (when (assoc voice contents)
          (%refuse op "a voice named twice in the contents"))
        (push (cons voice (cdr entry)) contents)))
    (%check-given score op (loop for entry in contents append (apply #'append (cdr entry))) '())
    (let* ((infos (if (and (zerop p) measures)
                      ;; The new first measure takes the old first one's signatures.
                      (let* ((new (first infos))
                             (old (first measures))
                             (time (and (null (measure-info-time new)) (measure-info-time old)))
                             (key (and (null (measure-info-key new)) (measure-info-key old))))
                        (if (or time key)
                            (cons (apply #'%user new (append (and time (list :time time))
                                                             (and key (list :key key))))
                                  (rest infos))
                            infos))
                      infos))
           (draft (append (subseq measures 0 p) infos (nthcdr p measures)))
           (draft (if (< p count) (%keep-at draft (+ p n) bars p) draft))
           (new-bars (%compute-bar-table draft))
           (parts (%map-voices
                   score
                   (lambda (voice part)
                     (%with-span voice p p
                                 (or (cdr (assoc voice contents))
                                     (loop for j from p below (+ p n)
                                           collect (and (%first-of-staff-p voice part)
                                                        (list (apply #'make-rest-event
                                                                     :duration (svref (%bar-table-lengths new-bars) j)
                                                                     :measure-rest-p t (%user-provenance))))))))))
           (anchors (%anchors-staying score new-bars (lambda (i anchor)
                                                      (declare (ignore anchor))
                                                      (if (>= i p) (+ i n) i)))))
      (%build-score score :measures draft :parts parts :anchors anchors))))

(defmethod %edit-change ((op delete-measures) (score score))
  (let* ((entry (%target-entry score op (edit-measure op) 'measure-info "a measure"))
         (i (%entry-measure entry))
         (c (edit-count op))
         (bars (%score-bars score))
         (measures (%measure-list score))
         (count (length measures)))
    (when (> (+ i c) count)
      (%off op (+ (%bar-table-first bars) count) "past the end of the score"))
    (let* ((draft (append (subseq measures 0 i) (nthcdr (+ i c) measures)))
           (draft (if (< (+ i c) count) (%keep-at draft i bars (+ i c) (zerop i)) draft))
           (new-bars (%compute-bar-table draft))
           (parts (%map-voices score (lambda (voice part)
                                       (declare (ignore part))
                                       (%with-span voice i (+ i c) '()))))
           (anchors (%anchors-staying score new-bars (lambda (j anchor)
                                                      (declare (ignore anchor))
                                                      (cond ((< j i) j)
                                                            ((< j (+ i c)) nil)
                                                            (t (- j c)))))))
      (%build-score score :measures draft :parts parts :anchors anchors))))

;;; SET-TIME --------------------------------------------------------------------------

(defun %lost-mark-p (measure)
  "True when re-barring can't remove MEASURE without losing something on it."
  (or (measure-info-key measure) (measure-info-jump measure) (measure-info-rehearsal measure)
      (measure-info-ending measure) (measure-info-repeat-start measure)
      (measure-info-repeat-end measure)))

(defmethod %edit-change ((op set-time) (score score))
  (let* ((entry (%target-entry score op (edit-measure op) 'measure-info "a measure"))
         (measure (%entry-element entry))
         (time (edit-time op))
         (bars (%score-bars score))
         (starts (%bar-table-starts bars))
         (lengths (%bar-table-lengths bars))
         (measures (%measure-list score))
         (count (length measures))
         (i0 (%entry-measure entry))
         (i1 (or (position-if #'measure-info-time measures :start (1+ i0)) count))
         (s (svref starts i0))
         (r (loop for k from i0 below i1 sum (svref lengths k)))
         (b (music-theory:meter-measure-duration
             (or time (if (plusp i0) (svref (%bar-table-times bars) (1- i0)) (music-theory:make-meter)))))
         (pickup (and (zerop i0) (measure-info-pickup-p measure)))
         (new-lengths (multiple-value-bind (k remainder) (floor (- r (if pickup (svref lengths i0) 0)) b)
                        (append (and pickup (list (svref lengths i0)))
                                (make-list k :initial-element b)
                                (and (plusp remainder) (list remainder)))))
         (new-starts (let ((at s)) (mapcar (lambda (length) (prog1 at (incf at length))) new-lengths)))
         (k1 (length new-lengths))
         (region (subseq measures i0 i1))
         (old-starts (loop for k from i0 below i1 collect (svref starts k)))
         (last-old (car (last region)))
         (kept (mapcar (lambda (start) (let ((k (position start old-starts))) (and k (nth k region))))
                       new-starts)))
    (dolist (m region)
      (when (and (not (member m kept :test #'eq)) (%lost-mark-p m))
        (%refuse op "re-barring would remove a measure with a key, a repeat, an ending, a jump or a rehearsal mark")))
    (flet ((new-bar-of (offset)
             (or (position-if (lambda (start) (<= start offset)) new-starts :from-end t) 0)))
      (let* ((tempos (loop for m in region
                           for start in old-starts
                           append (mapcar (lambda (mark) (cons (+ start (tempo-mark-offset mark)) mark))
                                          (measure-info-tempo m))))
             (new-region
               (loop for j from 0 below k1
                     for length in new-lengths
                     for start in new-starts
                     for old = (nth j kept)
                     for own-length = (if (or (and pickup (zerop j)) (/= length b)) length nil)
                     for barline = (cond ((= j (1- k1)) (measure-info-barline last-old))
                                         ((eq old last-old) :regular)
                                         (old (measure-info-barline old))
                                         (t :regular))
                     for marks = (loop for (offset . mark) in tempos
                                       when (= (new-bar-of offset) j)
                                         collect (if (= (- offset start) (tempo-mark-offset mark))
                                                     mark
                                                     (%user mark :offset (- offset start))))
                     collect (cond ((null old)
                                    (apply #'make-measure-info :length own-length :barline barline
                                                               :tempo marks (%user-provenance)))
                                   ((and (eql own-length (measure-info-length old))
                                         (equalp (if (zerop j) time (measure-info-time old))
                                                 (measure-info-time old))
                                         (eq barline (measure-info-barline old)))
                                    (if (%cell-eq marks (measure-info-tempo old))
                                        old
                                        (%remake old :tempo marks)))
                                   (t (%user old :length own-length :barline barline :tempo marks
                                                 :time (if (zerop j) time (measure-info-time old)))))))
             (draft (append (subseq measures 0 i0) new-region (nthcdr i1 measures)))
             (new-bars (%compute-bar-table draft))
             (shift (- k1 (- i1 i0)))
             (parts (%map-voices
                     score
                     (lambda (voice part)
                       (declare (ignore part))
                       (let ((slots (loop for slot in (%voice-slots voice bars)
                                          when (and (<= s (%slot-onset slot)) (< (%slot-onset slot) (+ s r)))
                                            collect (%make-slot (%slot-onset slot) (%slot-event slot)
                                                                (%slot-graces slot) (%slot-trailing slot) t))))
                         (%with-span voice i0 i1 (%assemble op slots '() new-bars i0 (+ i0 k1 -1)))))))
             (anchors (%anchors-staying
                       score new-bars
                       (lambda (i anchor)
                         (cond ((< i i0) i)
                               ((>= i i1) (+ i shift))
                               (t (let* ((offset (+ (svref starts i) (cdr (anchor-position anchor))))
                                         (j (new-bar-of offset)))
                                    (cons (+ (%bar-table-first new-bars) i0 j)
                                          (- offset (nth j new-starts))))))))))
        (%build-score score :measures draft :parts parts :anchors anchors)))))

;;; TRANSPOSE ----------------------------------------------------------------------

(defun %moving (op fn &rest arguments)
  "FN applied to ARGUMENTS, a music-theory transposition: a result beyond two
accidentals (INVALID-PITCH) is INVALID-EDIT, the one translated condition."
  (handler-case (apply fn arguments)
    (music-theory:invalid-pitch () (%refuse op "a pitch beyond two accidentals"))))

(defmethod %edit-change ((op transpose) (score score))
  (let ((interval (edit-interval op))
        (to-key (edit-to-key op)))
    (unless (if interval (null to-key) to-key)
      (%refuse op "exactly one of INTERVAL and TO-KEY must be given"))
    (let* ((parts (mapcar (lambda (id) (%target score op id 'part "a part")) (edit-parts op)))
           (bars (%score-bars score))
           (count (%bar-count bars))
           (first (%bar-table-first bars))
           (fi (if (edit-from op)
                   (%entry-measure (%target-entry score op (edit-from op) 'measure-info "a measure"))
                   0))
           (ti (if (edit-to op)
                   (%entry-measure (%target-entry score op (edit-to op) 'measure-info "a measure"))
                   (1- count))))
      (when (> fi ti)
        (%off op (+ first ti) "the range runs backwards"))
      (let* ((every-part (or (null parts) (every (lambda (part) (member part parts)) (%part-list score))))
             (keys (%bar-table-keys bars))
             (from-key (svref keys fi))
             (moved (make-array count :initial-element nil))
             (target (make-array count :initial-element nil))
             (measures (%measure-list score))
             (table (make-hash-table :test 'eq)))
        (labels ((move-pitch (pitch)
                   (if interval
                       (%moving op #'music-theory:transpose-pitch pitch interval)
                       (%moving op #'music-theory:transpose-to-key pitch from-key to-key)))
                 (move-key (key)
                   (let ((tonic (music-theory:key-tonic key)))
                     (music-theory:make-key
                      :tonic (if interval
                                 (music-theory:pitch-spelling
                                  (%moving op #'music-theory:transpose-pitch
                                           (music-theory:make-spelled-pitch
                                            :letter (music-theory:pitch-class-name-letter tonic)
                                            :alter (music-theory:pitch-class-name-alter tonic)
                                            :octave 4)
                                           interval))
                                 (%moving op #'music-theory:transpose-to-key tonic from-key to-key))
                      :mode (music-theory:key-mode key))))
                 (respell-p (i)
                   (and every-part (not (equalp (aref target i) (aref moved i)))))
                 (note-pitch-at (pitch i)
                   (let ((pitch (move-pitch pitch)))
                     (if (respell-p i)
                         (%moving op #'music-theory:transpose-to-key pitch (aref moved i) (aref target i))
                         pitch)))
                 (symbol-at (symbol i)
                   (let ((symbol (%moving op #'music-theory:transpose-chord-symbol symbol
                                          (or interval (list from-key to-key)))))
                     (if (respell-p i)
                         (%moving op #'music-theory:transpose-chord-symbol symbol
                                  (list (aref moved i) (aref target i)))
                         symbol))))
          (loop for i from fi to ti
                do (setf (aref moved i) (move-key (svref keys i))
                         (aref target i) (music-theory:choose-enharmonic-key (aref moved i)
                                                                             :max-accidentals 7)))
          ;; Notes.
          (dolist (part (or parts (%part-list score)))
            (dolist (voice (part-voices part))
              (loop for i from fi to (min ti (1- (fset:size (voice-measures voice))))
                    do (dolist (event (%cell voice i))
                         (dolist (note (typecase event
                                         (note-event (list event))
                                         (chord-event (chord-event-notes event))))
                           (let ((pitch (note-pitch-at (note-pitch note) i)))
                             (unless (equalp pitch (note-pitch note))
                               (setf (gethash note table) (%user note :pitch pitch)))))))))
          (when every-part
            ;; Keys: the range's own keys, FROM's, and the measure after TO keeping its own.
            (loop for i from fi to ti
                  for measure = (nth i measures)
                  when (and (or (measure-info-key measure) (= i fi))
                            (not (equalp (measure-info-key measure) (aref target i))))
                    do (setf (gethash measure table) (%user measure :key (aref target i))))
            (when (< (1+ ti) count)
              (let* ((after (nth (1+ ti) measures))
                     (last (loop for i from ti downto fi
                                 when (or (measure-info-key (nth i measures)) (= i fi)) return i)))
                (when (and (null (measure-info-key after))
                           (not (equalp (aref target last) (svref keys (1+ ti)))))
                  (setf (gethash after table) (%user after :key (svref keys (1+ ti)))))))
            ;; Chord symbols in the range, and (0.4.0) their origins' values.
            (dolist (anchor (%anchor-list score))
              (let ((i (- (car (anchor-position anchor)) first)))
                (when (<= fi i ti)
                  (let ((symbol (symbol-at (anchor-symbol anchor) i))
                        (origin (element-origin anchor)))
                    (if (and origin (origin-value origin))
                        (%move-anchor-origin anchor symbol (lambda (value) (symbol-at value i)) table)
                        (unless (equal (%chord-symbol-to-sexp symbol) (%chord-symbol-to-sexp (anchor-symbol anchor)))
                          (setf (gethash anchor table) (%user anchor :symbol symbol))))))))))
        (if (zerop (hash-table-count table))
            score
            (%substitute score table))))))
