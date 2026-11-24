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
;;;; note. A tie's source is the note that holds it. Unless stated, BAR is the
;;;; bar of the event the subject belongs to (for a tie, its source's event).
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
;;;;   :DUPLICATE-MARK    an event with two or more articulations of one KIND, or
;;;;                      a measure with two or more jump marks of one KIND. ID =
;;;;                      the event or the measure, BAR = its bar.
;;;;   :TIE-TARGET        a tie for which any of: no element has the id END; it
;;;;                      isn't a note; its event isn't in the same voice as the
;;;;                      source's event; either event is a grace event or past
;;;;                      the map; the target event's onset isn't the source
;;;;                      event's onset + its duration; an earlier tie in document
;;;;                      order has the same END. ID = the tie.
;;;;   :TIE-PITCH         a tie whose END names a note (anywhere) whose pitch
;;;;                      isn't EQUALP to the source's: a tie joins equal
;;;;                      spellings. ID = the tie.
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
;;;;   :TEMPO-MARK-POSITION a tempo mark whose OFFSET isn't < the BAR-LENGTH of
;;;;                      its measure. ID = the tempo mark, BAR = its bar.
;;;;   :BAD-ENDING        an ending whose MEASURES run past the last measure (it
;;;;                      starts at measure index i and i + MEASURES > the number
;;;;                      of measures), or that starts on a measure an earlier
;;;;                      ending spans. ID = the ending, BAR = its measure's bar.
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
    :duplicate-verse :duplicate-mark :tie-target :tie-pitch :spanner-endpoint
    :spanner-order :chord-symbol-position :tempo-mark-position :bad-ending)
  "SCORE-ISSUE-KIND values, defined in the file header. Data.")

(defstruct (score-issue (:constructor make-score-issue))
  (kind nil :type keyword :read-only t)
  (id nil :type (or null string) :read-only t)
  (bar nil :type (or null integer) :read-only t)
  (detail nil :type list :read-only t))

;;; One pass over the index entries in document order. Each subject class has a
;;; %CHECK-ELEMENT method (PROGN combination, so an event's EVENT,
;;; SOUNDING-EVENT and CHORD-EVENT methods all run). Onsets come from the bar
;;; table, not from ABSOLUTE-OFFSET, so CHECK-SCORE never signals.

(defstruct (%checker (:constructor %make-checker (index bars)) (:copier nil) (:predicate nil))
  "The state of one CHECK-SCORE pass: the score's INDEX and BARS, the ISSUES so
far, and what earlier subjects in document order left behind."
  (index nil :read-only t)
  (bars nil :read-only t)
  (issues '())
  (tie-ends (make-hash-table :test 'equal) :read-only t)
  (anchor-positions '())
  (ending-reach 0))

(defun %issue (checker kind element bar &optional detail)
  (push (make-score-issue :kind kind :id (element-id element) :bar bar :detail detail)
        (%checker-issues checker)))

(defun %measure-count (checker)
  (%bar-count (%checker-bars checker)))

(defun %entry-bar (checker entry)
  "The bar of ENTRY's measure or voice measure."
  (+ (%bar-table-first (%checker-bars checker)) (%entry-measure entry)))

(defun %in-map-p (checker entry)
  "True when ENTRY's voice measure is inside the measure map."
  (< (%entry-measure entry) (%measure-count checker)))

(defun %onset (checker entry)
  "The absolute offset of ENTRY's position, which is inside the map."
  (+ (svref (%bar-table-starts (%checker-bars checker)) (%entry-measure entry))
     (%entry-offset entry)))

(defun %lookup (checker id)
  "The entry of the first carrier of ID, or NIL."
  (values (fset:lookup (%score-index-by-id (%checker-index checker)) id)))

(defun %duplicate-p (list key)
  "True when two members of LIST have EQL KEYs."
  (loop for (x . rest) on list
        thereis (member (funcall key x) rest :key key)))

(defgeneric %check-element (element entry checker)
  (:documentation "Record the issues ELEMENT is the subject of.")
  (:method-combination progn)
  (:method progn ((element element) entry checker)
    (declare (ignore entry checker))
    nil))

(defmethod %check-element progn ((measure measure-info) entry checker)
  (let* ((i (%entry-measure entry))
         (bar (%entry-bar checker entry)))
    (when (and (zerop i) (not (and (measure-info-time measure) (measure-info-key measure))))
      (%issue checker :missing-signature measure bar))
    (when (and (measure-info-pickup-p measure)
               (or (plusp i)
                   (null (measure-info-length measure))
                   (>= (measure-info-length measure)
                       (music-theory:meter-measure-duration
                        (svref (%bar-table-times (%checker-bars checker)) i)))))
      (%issue checker :bad-pickup measure bar))
    (when (%duplicate-p (measure-info-jump measure) #'jump-mark-kind)
      (%issue checker :duplicate-mark measure bar))))

(defmethod %check-element progn ((ending ending) entry checker)
  (let* ((i (%entry-measure entry))
         (end (+ i (ending-measures ending))))
    (when (or (> end (%measure-count checker))
              (< i (%checker-ending-reach checker)))
      (%issue checker :bad-ending ending (%entry-bar checker entry)))
    (setf (%checker-ending-reach checker) (max end (%checker-ending-reach checker)))))

(defmethod %check-element progn ((mark tempo-mark) entry checker)
  (when (>= (tempo-mark-offset mark)
            (svref (%bar-table-lengths (%checker-bars checker)) (%entry-measure entry)))
    (%issue checker :tempo-mark-position mark (%entry-bar checker entry))))

(defmethod %check-element progn ((voice voice) entry checker)
  (let* ((measures (voice-measures voice))
         (count (fset:size measures))
         (n (%measure-count checker))
         (bars (%checker-bars checker)))
    (when (> (voice-staff voice) (length (part-staves (%entry-part entry))))
      (%issue checker :voice-staff voice nil))
    (unless (= count n)
      (%issue checker :measure-count voice nil (list :expected n :actual count)))
    (dotimes (j (min count n))
      (let ((events (fset:convert 'list (fset:@ measures j))))
        (when events
          (let ((sum (loop for event in events
                           unless (%grace-p event) sum (event-duration event)))
                (length (svref (%bar-table-lengths bars) j)))
            (unless (= sum length)
              (%issue checker :measure-duration voice (+ (%bar-table-first bars) j)
                      (list :expected length :actual sum)))))))))

(defmethod %check-element progn ((event event) entry checker)
  (let ((bar (%entry-bar checker entry)))
    (unless (or (and (typep event 'rest-event) (rest-event-measure-rest-p event))
                (music-theory:duration-dots (event-duration event) :tuplet (event-tuplet event)))
      (%issue checker :unnotatable-duration event bar))
    (when (%duplicate-p (event-lyrics event) #'lyric-verse)
      (%issue checker :duplicate-verse event bar))))

(defmethod %check-element progn ((event sounding-event) entry checker)
  (when (%duplicate-p (event-articulations event) #'articulation-kind)
    (%issue checker :duplicate-mark event (%entry-bar checker entry))))

(defmethod %check-element progn ((chord chord-event) entry checker)
  (when (< (length (chord-event-notes chord)) 2)
    (%issue checker :degenerate-chord chord (%entry-bar checker entry))))

(defmethod %check-element progn ((lyric lyric) entry checker)
  (let ((event (%entry-event entry)))
    (when (or (typep event 'rest-event) (%grace-p event))
      (%issue checker :misplaced-lyric lyric (%entry-bar checker entry)))))

(defmethod %check-element progn ((tie tie) entry checker)
  (let* ((end (tie-end tie))
         (source (%entry-event entry))
         (target (%lookup checker end))
         (note (and target (%entry-element target)))
         (note-p (typep note '(or note-event chord-note)))
         (bar (%entry-bar checker entry)))
    ;; OR stops at the first reason, so onsets are only taken inside the map.
    (when (or (not note-p)
              (not (eq (%entry-voice target) (%entry-voice entry)))
              (%grace-p source)
              (%grace-p (%entry-event target))
              (not (%in-map-p checker entry))
              (not (%in-map-p checker target))
              (/= (%onset checker target) (+ (%onset checker entry) (event-duration source)))
              (gethash end (%checker-tie-ends checker)))
      (%issue checker :tie-target tie bar))
    (setf (gethash end (%checker-tie-ends checker)) t)
    (when (and note-p (not (equalp (note-pitch note) (note-pitch (%entry-parent entry)))))
      (%issue checker :tie-pitch tie bar))))

(defun %spanner-endpoints-p (checker spanner start end)
  "True when the entries START and END pass :SPANNER-ENDPOINT for SPANNER."
  (let ((a (and start (%entry-element start)))
        (b (and end (%entry-element end))))
    (and (typep a 'event)
         (typep b 'event)
         (eq (%entry-part start) (%entry-part end))
         (%in-map-p checker start)
         (%in-map-p checker end)
         (not (and (eq (spanner-kind spanner) :slur)
                   (or (typep a 'rest-event) (typep b 'rest-event)))))))

(defun %spanner-ordered-p (checker spanner start end)
  "True when START precedes END, or SPANNER is a hairpin on one event."
  (let ((onset-a (%onset checker start))
        (onset-b (%onset checker end)))
    (or (< onset-a onset-b)
        (and (= onset-a onset-b)
             (eq (%entry-voice start) (%entry-voice end))
             (< (%entry-order start) (%entry-order end)))
        (and (eq start end)
             (member (spanner-kind spanner) '(:crescendo :diminuendo))
             t))))

(defmethod %check-element progn ((spanner spanner) entry checker)
  (declare (ignore entry))
  (let ((start (%lookup checker (spanner-start spanner)))
        (end (%lookup checker (spanner-end spanner))))
    (cond ((not (%spanner-endpoints-p checker spanner start end))
           (%issue checker :spanner-endpoint spanner nil))
          ((not (%spanner-ordered-p checker spanner start end))
           (%issue checker :spanner-order spanner nil)))))

(defmethod %check-element progn ((anchor chord-symbol-anchor) entry checker)
  (declare (ignore entry))
  (let* ((position (anchor-position anchor))
         (bars (%checker-bars checker))
         (i (%bar-index bars (car position))))
    (when (or (null i)
              (>= (cdr position) (svref (%bar-table-lengths bars) i))
              (member position (%checker-anchor-positions checker) :test #'equal))
      (%issue checker :chord-symbol-position anchor nil))
    (push position (%checker-anchor-positions checker))))

(defun check-score (score)
  "The SCORE-ISSUEs of SCORE (file header), () when it is valid."
  (check-type score score)
  (let* ((index (%score-index score))
         (checker (%make-checker index (%score-index-bars index)))
         (id-counts (make-hash-table :test 'equal)))
    (loop for entry across (%score-index-entries index)
          for element = (%entry-element entry)
          do (when (= 2 (incf (gethash (element-id element) id-counts 0)))
               (%issue checker :duplicate-id element nil))
             (%check-element element entry checker))
    (%checker-issues checker)))

(defun validate-score (score)
  "SCORE when it is valid, else SCORE-INVARIANT-VIOLATION inside CONTINUE."
  (let ((issues (check-score score)))
    (if (null issues)
        score
        (restart-case (error 'score-invariant-violation :issues issues)
          (continue ()
            :report "Return the score as it is."
            score)))))
