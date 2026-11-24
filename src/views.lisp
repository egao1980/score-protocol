;;;; SC1 views: EXTRACT-PART, CONDENSED-VIEW and UNFOLD.
;;;;
;;;; A view is a pure function of a source score. It returns a new score and an
;;;; ID MAP: an FSet map from the id of every element of the view that comes
;;;; from the source to the id of the source element it comes from. A view
;;;; keeps the ids of the elements it carries over (ids.lisp), and an element it
;;;; carries over unchanged is the source's own object (EQ). Elements a view
;;;; makes, and every copy of an element after the first, get minted ids:
;;;; PREFIX-(c + k), c the source's SCORE-ID-COUNTER and k = 1, 2, ... in the
;;;; view's document order; the view's counter is computed as MAKE-SCORE does.
;;;; The view's metadata is the source's. The view of a valid score is valid
;;;; (CHECK-SCORE returns ()).
;;;;
;;;; EXTRACT-PART score id → (values view id-map). ID names a part or a voice;
;;;; another id signals UNKNOWN-ELEMENT (ID = the id) inside a USE-VALUE restart
;;;; that takes an id to extract instead. The view has the source's measure map
;;;; (the same measures), every chord-symbol anchor (chord symbols belong to the
;;;; whole score), the spanners whose two endpoints are events of what is
;;;; extracted, and one part:
;;;;   for a part, that part itself;
;;;;   for a voice, its part's id, abbreviation and name (the voice's NAME
;;;;   instead, when it has one), with one staff, the voice's own (the same
;;;;   staff), and the voice alone, with STAFF 1 and STEM NIL.
;;;; Every element of the view comes from the source; the id map sends each id
;;;; to itself. So the alto of a hymn on two staves is (extract-part s "alto-id").
;;;;
;;;; CONDENSED-VIEW score &key voices → (values view id-map): up to four voices
;;;; on two staves, the hymnal reduction. VOICES is a list of one to four voice
;;;; ids, highest first (soprano, alto, tenor, bass); by default the first four
;;;; voices of the score in document order, or all of them when it has fewer.
;;;; An id that isn't in the score signals UNKNOWN-ELEMENT inside a USE-VALUE
;;;; restart that takes a list of voice ids to use instead; an id of another
;;;; kind, the same voice twice, more than four, and a score without voices
;;;; signal SCORE-ERROR. The view has the source's measure map, every anchor,
;;;; the spanners whose two endpoints lie in those voices, and one new part
;;;; (minted, with the NAME and ABBREVIATION of the voices' part when they all
;;;; come from one part, else none). Its staves are new: one :TREBLE staff for
;;;; one or two voices, a :TREBLE and a :BASS staff for three or four. The voices
;;;; are VOICES, in order, carried over whole: the first two on staff 1, the
;;;; others on staff 2. A voice that shares its staff has STEM :UP when it is
;;;; the upper of the two and :DOWN when it is the lower; a voice alone on its
;;;; staff has STEM NIL. Unisons and differing rhythms between the two voices of
;;;; a staff are the engraver's: both voices stay whole, and the engraver draws
;;;; a shared notehead or offset heads from their events. The id map sends
;;;; every carried id to itself; the part and staves are not in it.
;;;;
;;;; UNFOLD score → (values view id-map passes): repeats, endings and jumps
;;;; expanded into playback order.
;;;;   Ending groups. Endings that each start on the measure after the last
;;;;   measure of the one before form a group. A REPEAT-END measure e belongs to
;;;;   the group that contains e or starts on the measure after e; g(e) is that
;;;;   group's last measure, or e when there is none.
;;;;   Sections. Each REPEAT-END measure e ends a section, which starts at s(e):
;;;;   the last measure with REPEAT-START in (g(p), e], p the REPEAT-END measure
;;;;   before e; when there is none, at g(p) + 1. For the first section, g(p) is
;;;;   taken as -1: a backward repeat with no forward repeat goes back to the
;;;;   beginning of the score, or to the end of the section before.
;;;;   The walk keeps PASS (the time through the current section, from 1),
;;;;   whether a jump has been taken (JUMPED), and the MODE of that jump (NIL,
;;;;   :FINE or :CODA). It starts at the first measure, and at each measure m:
;;;;    1. When m starts an ENDING: before a jump (JUMPED false) it is played
;;;;       when PASS is among its PASSES; after a jump, when it is the last
;;;;       ending of its group, whatever PASS is. Otherwise the walk goes on at
;;;;       the measure after the ending's measures.
;;;;    2. Entering a section start s(e) other than by repeating sets PASS to 1.
;;;;    3. m is played: it is the next measure of the view.
;;;;    4. At the end of m, the first of these that applies:
;;;;       a. m has REPEAT-END n, not JUMPED, PASS < n: PASS + 1, back to s(m).
;;;;       b. m has :FINE and MODE is :FINE: the walk ends.
;;;;       c. m has :TO-CODA and MODE is :CODA: on at the first measure after m
;;;;          with a :CODA mark, or the walk ends when there is none.
;;;;       d. m has a D.C. or D.S. mark not taken before (the first in +JUMPS+
;;;;          order): it is taken, JUMPED becomes true, MODE becomes :FINE for
;;;;          :DA-CAPO-AL-FINE and :DAL-SEGNO-AL-FINE, :CODA for
;;;;          :DA-CAPO-AL-CODA and :DAL-SEGNO-AL-CODA, NIL for :DA-CAPO and
;;;;          :DAL-SEGNO; on at the first measure (D.C.) or at the last measure
;;;;          at or before m with a :SEGNO mark (D.S.; with none, SCORE-ERROR).
;;;;       e. on at the next measure; after the last one the walk ends.
;;;;   So after a jump repeats are not taken again and only the last ending of
;;;;   each group is played; a plain D.C. or D.S. plays to the end; Fine and To
;;;;   Coda act only after a jump that asks for them.
;;;;   The walk always ends, so it has no step limit (SC3): each D.C. or D.S.
;;;;   mark is taken at most once; repeats are taken only before the first
;;;;   jump; a repeat goes back to s(m), after every earlier REPEAT-END measure,
;;;;   so it never re-enters an earlier section, and it is taken at most
;;;;   REPEAT-END - 1 times in a row; every other move goes forward. A
;;;;   REPEAT-END of any size unfolds in full: one measure with REPEAT-END 100
;;;;   gives 100 view measures, passes 1 to 100. The only SCORE-ERROR of the
;;;;   walk is a D.S. with no segno.
;;;;   The PASS of a measure of the view is how many times its source measure
;;;;   has been played up to and including it (1 the first time).
;;;;   The view. Its measures are copies of the played measures, in order: the
;;;;   same slots and marks, minus REPEAT-START, REPEAT-END, the ENDING and the
;;;;   JUMP marks (the view has nothing left to navigate); PICKUP-P only on the
;;;;   first; TIME (KEY) its own, else the one in force at its source when that
;;;;   differs from the one in force at the source of the view measure before it,
;;;;   and always both for the first. Each voice's voice measure k is a copy of
;;;;   its source voice measure. A tie keeps its END when the target's copy is
;;;;   in the same view measure, or in the next one when that one is the source
;;;;   measure right after; otherwise the copy has no tie. A spanner is copied
;;;;   for each copy of its START event whose END event has a copy in the same
;;;;   view measure or in a following one reached through source measures that
;;;;   follow each other, with no jump; that END copy is its END. Each anchor is
;;;;   copied into every view bar whose source bar holds it, at the same offset.
;;;;   Parts, staves and voices are carried over with their ids.
;;;;   The first copy of an element in the view's document order keeps its id;
;;;;   the id map sends every copy to its source. PASSES is an FSet map from each
;;;;   view id to a pass: a measure's, for the measure, what is on it, the
;;;;   events of its voice measures and what is in them, and the anchors in its
;;;;   bar; for a spanner, the pass of its START copy; 1 for parts, staves and
;;;;   voices. So (bar . offset) in the view, the pass, and the source id
;;;;   together say where in the score playback is. UNFOLD of a view gives the
;;;;   same measures again.

(in-package #:score-protocol)

;;; Shared ---------------------------------------------------------------------------

(defun %self-map (view &optional skip)
  "The id map of a view whose elements all come from the source unchanged in id:
every id of VIEW to itself, except the ids in SKIP."
  (let ((map (fset:empty-map)))
    (dolist (element (score-elements view) map)
      (let ((id (element-id element)))
        (unless (member id skip :test #'equal)
          (setf map (fset:with map id id)))))))

(defun %spanners-within (score voices)
  "SCORE's spanners whose two endpoints are events of VOICES."
  (flet ((inside-p (id)
           (let ((entry (%entry-of score id)))
             (and entry
                  (typep (%entry-element entry) 'event)
                  (member (%entry-voice entry) voices :test #'eq)))))
    (remove-if-not (lambda (spanner)
                     (and (inside-p (spanner-start spanner)) (inside-p (spanner-end spanner))))
                   (%spanner-list score))))

(defun %view-score (score parts spanners)
  "A view of SCORE: its metadata, measure map and anchors, with PARTS and SPANNERS."
  (make-score :metadata (score-metadata score)
              :measures (score-measure-map score)
              :parts parts
              :chord-symbols (score-chord-symbols score)
              :spanners spanners
              :id-counter (score-id-counter score)))

;;; EXTRACT-PART ---------------------------------------------------------------------

(defun extract-part (score id)
  "(values view id-map): the part or voice ID of SCORE on its own (file header)."
  (check-type score score)
  (let* ((entry (%entry-of score id))
         (element (and entry (%entry-element entry))))
    (typecase element
      (part
       (let ((view (%view-score score (list element) (%spanners-within score (part-voices element)))))
         (values view (%self-map view))))
      (voice
       (let* ((part (%entry-part entry))
              (staff (nth (1- (voice-staff element)) (part-staves part)))
              (voice (if (and (= 1 (voice-staff element)) (null (voice-stem element)))
                         element
                         (%remake element :staff 1 :stem nil)))
              (name (or (voice-name element) (part-name part)))
              (alone (if (and (equal name (part-name part))
                              (%cell-eq (list staff) (part-staves part))
                              (%cell-eq (list voice) (part-voices part)))
                         part
                         (%remake part :name name :staves (list staff) :voices (list voice))))
              (view (%view-score score (list alone) (%spanners-within score (list element)))))
         (values view (%self-map view))))
      (t (extract-part score (%unknown-element id))))))

;;; CONDENSED-VIEW -------------------------------------------------------------------

(defun condensed-view (score &key (voices nil voices-p))
  "(values view id-map): up to four VOICES on two staves (file header)."
  (check-type score score)
  (let* ((all (%voice-list score))
         (ids (if voices-p voices (mapcar #'element-id (subseq all 0 (min 4 (length all))))))
         (chosen '()))
    (check-type ids list)
    (when (null ids)
      (error 'score-error :reason "no voices to condense"))
    (dolist (id ids)
      (let ((entry (%entry-of score id)))
        (cond ((null entry)
               (return-from condensed-view (condensed-view score :voices (%unknown-element id))))
              ((not (typep (%entry-element entry) 'voice))
               (error 'score-error :reason (format nil "~S is not a voice" id)))
              ((member (%entry-element entry) chosen :test #'eq)
               (error 'score-error :reason (format nil "the voice ~S is given twice" id)))
              (t (push (%entry-element entry) chosen)))))
    (when (> (length ids) 4)
      (error 'score-error :reason "more than four voices"))
    (setf chosen (nreverse chosen))
    (let* ((k (length chosen))
           (owners (mapcar (lambda (voice) (%entry-part (%entry-of score (element-id voice)))) chosen))
           (owner (and (every (lambda (part) (eq part (first owners))) owners) (first owners)))
           (placed (loop for voice in chosen
                         for j from 0
                         for staff = (if (< j 2) 1 2)
                         for stem = (and (if (< j 2) (>= k 2) (= k 4)) (if (evenp j) :up :down))
                         collect (if (and (= staff (voice-staff voice)) (eq stem (voice-stem voice)))
                                     voice
                                     (%remake voice :staff staff :stem stem))))
           (part (make-part :name (and owner (part-name owner))
                            :abbreviation (and owner (part-abbreviation owner))
                            :staves (if (<= k 2)
                                        (list (make-staff :clef :treble))
                                        (list (make-staff :clef :treble) (make-staff :clef :bass)))
                            :voices placed))
           (view (%view-score score (list part) (%spanners-within score chosen)))
           (made (fset:@ (score-parts view) 0)))
      (values view (%self-map view (cons (element-id made) (mapcar #'element-id (part-staves made))))))))

;;; UNFOLD ----------------------------------------------------------------------------

(defparameter +unfold-jumps+
  '((:da-capo nil :start) (:da-capo-al-fine :fine :start) (:da-capo-al-coda :coda :start)
    (:dal-segno nil :segno) (:dal-segno-al-fine :fine :segno) (:dal-segno-al-coda :coda :segno))
  "The D.C. and D.S. jump kinds: (kind mode target), MODE what the jump asks of
Fine and To Coda, TARGET the first measure or the segno (file header, step 4d). Data.")

(defun %unfold-walk (measures)
  "The playback order of MEASURES (a simple-vector of MEASURE-INFOs) as a list of
measure indices: the ending groups, sections and steps 1 to 4 of the file
header. Navigation is decided here and nowhere else."
  (let* ((n (length measures))
         (group (make-array n :initial-element nil))       ; index → (first . last) of its group
         (last-start (make-array n :initial-element nil))  ; ending start → last ending start of its group
         (section (make-array n :initial-element nil))     ; REPEAT-END index → s(e)
         (section-start-p (make-array n :initial-element nil)))
    (flet ((info (i) (svref measures i))
           (kinds (i) (mapcar #'jump-mark-kind (measure-info-jump (svref measures i)))))
      ;; Ending groups.
      (let ((i 0))
        (loop while (< i n)
              do (if (null (measure-info-ending (info i)))
                     (incf i)
                     (let ((starts '()) (j i))
                       (loop while (and (< j n) (measure-info-ending (info j)))
                             do (push j starts)
                                (incf j (ending-measures (measure-info-ending (info j)))))
                       (let ((last (min (1- j) (1- n))))
                         (dolist (start starts) (setf (svref last-start start) (first starts)))
                         (loop for k from i to last do (setf (svref group k) (cons i last))))
                       (setf i j)))))
      ;; Sections.
      (flet ((g (e)
               (let ((in (svref group e))
                     (next (and (< (1+ e) n) (svref group (1+ e)))))
                 (cond (in (cdr in))
                       ((and next (= (car next) (1+ e))) (cdr next))
                       (t e)))))
        (let ((gp -1))
          (dotimes (e n)
            (when (measure-info-repeat-end (info e))
              (let ((s (or (loop for k from e downto (1+ gp)
                                 when (measure-info-repeat-start (info k)) return k)
                           (1+ gp))))
                (setf (svref section e) s
                      (svref section-start-p s) t
                      gp (g e)))))))
      ;; The walk.
      (let ((order '()) (pass 1) (jumped nil) (mode nil) (taken '()) (repeating nil)
            (m 0) (steps 0) (limit (* 16 (1+ n) (1+ n))))
        (loop while (< m n)
              do (when (> (incf steps) limit)
                   (error 'score-error :reason "the navigation marks never reach an end"))
                 (let ((ending (measure-info-ending (info m))))
                   (if (and ending
                            (not (if jumped
                                     (eql m (svref last-start m))
                                     (member pass (ending-passes ending)))))
                       ;; 1. An ending not played now.
                       (setf m (+ m (ending-measures ending)) repeating nil)
                       (let ((repeat (measure-info-repeat-end (info m)))
                             (jump (find-if (lambda (mark)
                                              (and (assoc (jump-mark-kind mark) +unfold-jumps+)
                                                   (not (member mark taken :test #'eq))))
                                            (measure-info-jump (info m)))))
                         ;; 2. and 3.
                         (when (and (svref section-start-p m) (not repeating))
                           (setf pass 1))
                         (setf repeating nil)
                         (push m order)
                         ;; 4.
                         (cond ((and repeat (not jumped) (< pass repeat))
                                (incf pass)
                                (setf m (svref section m) repeating t))
                               ((and (member :fine (kinds m)) (eq mode :fine))
                                (setf m n))
                               ((and (member :to-coda (kinds m)) (eq mode :coda))
                                (setf m (or (loop for k from (1+ m) below n
                                                  when (member :coda (kinds k)) return k)
                                            n)))
                               (jump
                                (destructuring-bind (new-mode target) (rest (assoc (jump-mark-kind jump) +unfold-jumps+))
                                  (push jump taken)
                                  (setf jumped t
                                        mode new-mode
                                        m (if (eq target :start)
                                              0
                                              (or (loop for k from m downto 0
                                                        when (member :segno (kinds k)) return k)
                                                  (error 'score-error :reason "a D.S. with no segno"))))))
                               (t (incf m)))))))
        (nreverse order)))))

(defun unfold (score)
  "(values view id-map passes): SCORE in playback order (file header)."
  (check-type score score)
  (let* ((bars (%score-bars score))
         (source-measures (coerce (%measure-list score) 'simple-vector))
         (order (coerce (%unfold-walk source-measures) 'simple-vector))
         (k (length order))
         (first-bar (%bar-table-first bars))
         (plays (make-array (length source-measures) :initial-element 0))
         (view-pass (map 'vector (lambda (i) (incf (aref plays i))) order))
         (counter (score-id-counter score))
         (used (make-hash-table :test 'equal))
         (ids (make-hash-table :test 'equal))      ; (element . j) → view id
         (id-map (fset:empty-map))
         (passes (fset:empty-map)))
    (labels ((assign (element j pass)
               (let* ((source (element-id element))
                      (id (if (gethash source used)
                              (%minted-id (%id-prefix element) (incf counter))
                              (setf (gethash source used) source))))
                 (setf (gethash (cons element j) ids) id
                       id-map (fset:with id-map id source)
                       passes (fset:with passes id pass))
                 id))
             (measure-of (id)
               (let ((entry (%entry-of score id)))
                 (and entry (%entry-measure entry))))
             (tie-copy (tie j)
               ;; The view measure of the copy of TIE's target, or NIL: no tie there.
               (let ((target (measure-of (tie-end tie)))
                     (here (svref order j)))
                 (cond ((null target) nil)
                       ((= target here) j)
                       ((and (< (1+ j) k) (= target (1+ here)) (= (svref order (1+ j)) (1+ here))) (1+ j)))))
             (visit (element j pass)
               (assign element j pass)
               (dolist (child (%element-children element))
                 (unless (and (typep child 'tie) (null (tie-copy child j)))
                   (visit child j pass))))
             (copy (element j)
               (let ((id (gethash (cons element j) ids)))
                 (if (typep element 'tie)
                     (let* ((l (tie-copy element j))
                            (end (gethash (cons (%entry-element (%entry-of score (tie-end element))) l) ids)))
                       (if (and (equal id (element-id element)) (equal end (tie-end element)))
                           element
                           (%rebuild element (%element-row element) id
                                     (list (cons (%row-field element :end) end)))))
                     (values (%map-children element
                                            (lambda (child)
                                              (if (and (typep child 'tie) (null (tie-copy child j)))
                                                  (values :remove t)
                                                  (let ((new (copy child j)))
                                                    (values new (not (eq new child))))))
                                            id)))))
             (cell (voice j)
               (%cell voice (svref order j))))
      ;; Ids, in the view's document order.
      (dotimes (j k)
        (let ((measure (svref source-measures (svref order j))))
          (assign measure j (aref view-pass j))
          (let ((rehearsal (measure-info-rehearsal measure)))
            (when rehearsal (assign rehearsal j (aref view-pass j))))
          (dolist (mark (measure-info-tempo measure))
            (assign mark j (aref view-pass j)))))
      (dolist (part (%part-list score))
        (assign part 0 1)
        (dolist (staff (part-staves part)) (assign staff 0 1))
        (dolist (voice (part-voices part))
          (assign voice 0 1)
          (dotimes (j k)
            (dolist (event (cell voice j))
              (visit event j (aref view-pass j))))))
      (let ((anchors '()) (spanners '()))
        (dotimes (j k)
          (dolist (anchor (%anchor-list score))
            (when (= (car (anchor-position anchor)) (+ first-bar (svref order j)))
              (assign anchor j (aref view-pass j))
              (push (cons anchor j) anchors))))
        (dolist (spanner (%spanner-list score))
          (let* ((start (%entry-of score (spanner-start spanner)))
                 (end (%entry-of score (spanner-end spanner))))
            (when (and start end (typep (%entry-element start) 'event) (typep (%entry-element end) 'event))
              (dotimes (j k)
                (when (= (svref order j) (%entry-measure start))
                  (let ((l (loop for l from j below k
                                 when (= (svref order l) (%entry-measure end)) return l
                                 while (and (< (1+ l) k) (= (svref order (1+ l)) (1+ (svref order l)))))))
                    (when l
                      (assign spanner j (aref view-pass j))
                      (push (list spanner j l) spanners))))))))
        ;; The view, built from the ids.
        (let* ((view-first (if (and (plusp k) (measure-info-pickup-p (svref source-measures (svref order 0)))) 0 1))
               (measures
                 (loop for j from 0 below k
                       for i = (svref order j)
                       for measure = (svref source-measures i)
                       collect (flet ((signature (own table)
                                        (or own
                                            (let ((here (svref table i)))
                                              (and (or (zerop j)
                                                       (not (equalp here (svref table (svref order (1- j))))))
                                                   here)))))
                                 (let ((id (gethash (cons measure j) ids))
                                       (pickup (and (zerop j) (measure-info-pickup-p measure)))
                                       (time (signature (measure-info-time measure) (%bar-table-times bars)))
                                       (key (signature (measure-info-key measure) (%bar-table-keys bars)))
                                       (rehearsal (let ((mark (measure-info-rehearsal measure)))
                                                    (and mark (%with-id mark (gethash (cons mark j) ids)))))
                                       (tempo (mapcar (lambda (mark) (%with-id mark (gethash (cons mark j) ids)))
                                                      (measure-info-tempo measure))))
                                   (if (and (equal id (element-id measure))
                                            (eq pickup (measure-info-pickup-p measure))
                                            (eq time (measure-info-time measure))
                                            (eq key (measure-info-key measure))
                                            (eq rehearsal (measure-info-rehearsal measure))
                                            (%cell-eq tempo (measure-info-tempo measure))
                                            (not (measure-info-repeat-start measure))
                                            (not (measure-info-repeat-end measure))
                                            (not (measure-info-ending measure))
                                            (null (measure-info-jump measure)))
                                       measure
                                       (%remake measure :id id :pickup-p pickup :time time :key key
                                                        :repeat-start nil :repeat-end nil :ending nil :jump '()
                                                        :rehearsal rehearsal :tempo tempo))))))
               (parts
                 (mapcar (lambda (part)
                           (values (%map-children
                                    part
                                    (lambda (child)
                                      (if (typep child 'voice)
                                          (let* ((cells (loop for j from 0 below k
                                                              collect (mapcar (lambda (event) (copy event j))
                                                                              (cell child j))))
                                                 (seq (voice-measures child))
                                                 (same (and (= k (fset:size seq))
                                                            (loop for c in cells for j from 0
                                                                  always (%cell-eq c (%seq-list (fset:@ seq j)))))))
                                            (if same
                                                (values child nil)
                                                (values (%rebuild child (%element-row child) (element-id child)
                                                                  (list (cons (%row-field child :measures)
                                                                              (fset:convert 'fset:seq
                                                                                            (mapcar (lambda (c) (fset:convert 'fset:seq c))
                                                                                                    cells)))))
                                                        t)))
                                          (values child nil))))))
                         (%part-list score)))
               (anchors
                 (mapcar (lambda (entry)
                           (destructuring-bind (anchor . j) entry
                             (let ((id (gethash (cons anchor j) ids))
                                   (position (cons (+ view-first j) (cdr (anchor-position anchor)))))
                               (if (and (equal id (element-id anchor)) (equal position (anchor-position anchor)))
                                   anchor
                                   (%remake anchor :id id :position position)))))
                         (nreverse anchors)))
               (spanners
                 (mapcar (lambda (entry)
                           (destructuring-bind (spanner j l) entry
                             (let ((id (gethash (cons spanner j) ids))
                                   (start (gethash (cons (%entry-element (%entry-of score (spanner-start spanner))) j) ids))
                                   (end (gethash (cons (%entry-element (%entry-of score (spanner-end spanner))) l) ids)))
                               (if (and (equal id (element-id spanner)) (equal start (spanner-start spanner))
                                        (equal end (spanner-end spanner)))
                                   spanner
                                   (%remake spanner :id id :start start :end end)))))
                         (nreverse spanners)))
               (view (make-score :metadata (score-metadata score) :measures measures :parts parts
                                 :chord-symbols anchors :spanners spanners
                                 :id-counter (score-id-counter score))))
          (values view id-map passes))))))
