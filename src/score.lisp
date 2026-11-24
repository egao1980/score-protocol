;;;; SC0 the score: an immutable, FSet-backed value.
;;;;
;;;; A SCORE is its METADATA, its measure map, its PARTS, its chord-symbol track,
;;;; its SPANNERS and its id counter (ids.lisp). The collections that grow with
;;;; the score are FSet seqs, so a score built from another shares structure
;;;; with it:
;;;;   SCORE-MEASURE-MAP    a seq of MEASURE-INFOs
;;;;   SCORE-PARTS          a seq of PARTs
;;;;   SCORE-CHORD-SYMBOLS  a seq of CHORD-SYMBOL-ANCHORs, in track order:
;;;;                        stable-sorted by bar, then by offset
;;;;   SCORE-SPANNERS       a seq of SPANNERs
;;;;   VOICE-MEASURES       a seq of seqs of EVENTs (elements.lisp)
;;;; Small collections are lists: a part's staves and voices, a chord's notes,
;;;; an event's lyrics and articulations, a measure's volta, jumps and tempo
;;;; marks. SCORE-METADATA is a plist of +METADATA-KEYS+ keys and string values,
;;;; in +METADATA-KEYS+ order, holding only the keys that were given.
;;;; SCORE-ID-COUNTER is an integer >= 0.
;;;;
;;;; MAKE-SCORE &key metadata measures parts chord-symbols spanners (id-counter 0)
;;;; takes lists or FSet seqs. It signals TYPE-ERROR for METADATA that isn't a
;;;; plist of distinct +METADATA-KEYS+ keys to strings, for collections whose
;;;; members aren't of the types above, and for an ID-COUNTER that isn't an
;;;; integer >= 0. It sorts the chord-symbol track, mints an id for every
;;;; element that has none (ids.lisp), and indexes the elements by id (an FSet
;;;; map), so lookups don't walk the score. An element that had its id, and
;;;; everything inside it too, is stored as the same (EQ) object; an element
;;;; that gets a minted id, or contains one that does, is rebuilt with its other
;;;; slots unchanged. The elements may form a draft (SC3, builder.lisp): ids and
;;;; tie and spanner references that are DRAFT-REFs are resolved in the same
;;;; call, and an element that carries or refers to one is rebuilt like an
;;;; element that gets a minted id. The score holds no refs.
;;;;
;;;; COPY-SCORE score &key metadata measures parts chord-symbols spanners is
;;;; MAKE-SCORE with each omitted argument taken from SCORE, and :ID-COUNTER
;;;; (score-id-counter score). Unchanged parts of the score are shared. So new
;;;; elements added to a score with COPY-SCORE may be a draft too: their
;;;; references may name SCORE's ids (strings) or refs.
;;;;
;;;; Lookups:
;;;;   SCORE-ELEMENTS score: a fresh list of every element, in document order.
;;;;   FIND-ELEMENT score id &key (errorp t): the element with that id, the first
;;;;     in document order when several share it. For an unknown id, NIL when
;;;;     ERRORP is false, else UNKNOWN-ELEMENT (ID = the id) inside a USE-VALUE
;;;;     restart whose value is returned.
;;;;   ELEMENT-PARENT score id: the element above it in the tree: a staff's or
;;;;     voice's part; an event's voice; the event of a chord note, a lyric, a
;;;;     dynamic, a fermata, a breath mark or an articulation; a tie's note; the
;;;;     measure of an ending, a jump mark, a rehearsal mark or a tempo mark. NIL
;;;;     for measures, parts, chord-symbol anchors and spanners.
;;;;   ELEMENT-POSITION score id: measure-map.lisp.
;;;;   FIND-SLICE score slice-id &key (errorp t): ids.lisp.
;;;;   ELEMENT-PARENT and ELEMENT-POSITION treat an unknown id as FIND-ELEMENT
;;;;   does with ERRORP true.
;;;;   UNCERTAIN-ELEMENTS score &key (below 0.8): the uncertainty report, the
;;;;     elements whose CONFIDENCE is not NIL and is < BELOW, in document order.
;;;;     An element with no recorded confidence counts as certain.

(in-package #:score-protocol)

(defparameter +metadata-keys+
  '(:title :subtitle :composer :lyricist :arranger :copyright)
  "SCORE-METADATA keys, in canonical order. Values are strings. Data.")

(defclass score ()
  ((metadata :initarg :metadata :initform '() :reader score-metadata)
   (measure-map :initarg :measure-map :reader score-measure-map)
   (parts :initarg :parts :reader score-parts)
   (chord-symbols :initarg :chord-symbols :reader score-chord-symbols)
   (spanners :initarg :spanners :reader score-spanners)
   (id-counter :initarg :id-counter :initform 0 :reader score-id-counter)
   (index :initarg :index :documentation "Private: the id index built by MAKE-SCORE."))
  (:documentation "An immutable score (file header). Build one with MAKE-SCORE."))

(defmethod print-object ((score score) stream)
  (print-unreadable-object (score stream :type t :identity t)
    (format stream "~@[~S~]" (getf (score-metadata score) :title))))

;;; The element grammar ------------------------------------------------------
;;; One row per element kind: the kind keyword of its canonical form
;;; (sexp.lisp), its class, its constructor, and its fields in canonical key
;;; order. A field is (KEY READER &key CODEC INITARG DEFAULT ALWAYS):
;;;   KEY      the form key; a list of keys for a composite codec
;;;   READER   the slot reader
;;;   CODEC    :VALUE (written as stored), :PITCH, :METER, :KEY (music-theory
;;;            text), :TEMPO (:bpm and :beat-unit), :POSITION (:bar and
;;;            :offset), :CHORD-SYMBOL, :PROVENANCE (plists), or a child codec:
;;;            (:FORM kind...), (:FORMS kind...) or (:VOICE-MEASURES kind...)
;;;   INITARG  the slot's initarg and constructor keyword, default KEY
;;;   DEFAULT  the value left out of a canonical form, default NIL
;;;   ALWAYS   true when the key is written whatever its value
;;; :ID comes first and :PROVENANCE, :CONFIDENCE last in every row
;;; (%PARSE-FORM-ROW adds them). The child fields, in row order, give an
;;; element's children in document order (ids.lisp), so the walk, the writer
;;; and the reader agree by construction. Grammar data, not rules.

(defparameter +element-forms+
  '((:measure measure-info make-measure-info
     (:number measure-info-number)
     (:time measure-info-time :codec :meter)
     (:key measure-info-key :codec :key)
     (:pickup measure-info-pickup-p :initarg :pickup-p)
     (:length measure-info-length)
     (:barline measure-info-barline :default :regular)
     (:repeat-start measure-info-repeat-start)
     (:repeat-end measure-info-repeat-end)
     (:ending measure-info-ending :codec (:form :ending))
     (:jump measure-info-jump :codec (:forms :jump))
     (:rehearsal measure-info-rehearsal :codec (:form :rehearsal))
     (:tempo measure-info-tempo :codec (:forms :tempo-mark)))
    (:ending ending make-ending
     (:passes ending-passes :always t)
     (:measures ending-measures :default 1))
    (:jump jump-mark make-jump-mark
     (:kind jump-mark-kind :always t))
    (:rehearsal rehearsal-mark make-rehearsal-mark
     (:text rehearsal-mark-text :always t))
    (:tempo-mark tempo-mark make-tempo-mark
     (:offset tempo-mark-offset :default 0)
     ((:bpm :beat-unit) tempo-mark-tempo :codec :tempo :initarg :tempo)
     (:text tempo-mark-text))
    (:part part make-part
     (:name part-name)
     (:abbreviation part-abbreviation)
     (:staves part-staves :codec (:forms :staff) :always t)
     (:voices part-voices :codec (:forms :voice) :always t))
    (:staff staff make-staff
     (:clef staff-clef :default :treble))
    (:voice voice make-voice
     (:name voice-name)
     (:staff voice-staff :default 1)
     (:stem voice-stem)
     (:measures voice-measures :codec (:voice-measures :rest :note :chord) :always t))
    (:rest rest-event make-rest-event
     (:duration event-duration :always t)
     (:tuplet event-tuplet)
     (:measure-rest rest-event-measure-rest-p :initarg :measure-rest-p)
     (:hidden rest-event-hidden-p :initarg :hidden-p)
     (:fermata event-fermata :codec (:form :fermata))
     (:dynamic event-dynamic :codec (:form :dynamic))
     (:lyrics event-lyrics :codec (:forms :lyric)))
    (:note note-event make-note-event
     (:pitch note-pitch :codec :pitch :always t)
     (:duration event-duration :always t)
     (:tuplet event-tuplet)
     (:grace event-grace)
     (:accidental note-accidental :default :auto)
     (:tie note-tie :codec (:form :tie))
     (:articulations event-articulations :codec (:forms :articulation))
     (:fermata event-fermata :codec (:form :fermata))
     (:breath-mark event-breath-mark :codec (:form :breath-mark))
     (:dynamic event-dynamic :codec (:form :dynamic))
     (:lyrics event-lyrics :codec (:forms :lyric)))
    (:chord chord-event make-chord-event
     (:notes chord-event-notes :codec (:forms :chord-note) :always t)
     (:duration event-duration :always t)
     (:tuplet event-tuplet)
     (:grace event-grace)
     (:articulations event-articulations :codec (:forms :articulation))
     (:fermata event-fermata :codec (:form :fermata))
     (:breath-mark event-breath-mark :codec (:form :breath-mark))
     (:dynamic event-dynamic :codec (:form :dynamic))
     (:lyrics event-lyrics :codec (:forms :lyric)))
    (:chord-note chord-note make-chord-note
     (:pitch note-pitch :codec :pitch :always t)
     (:accidental note-accidental :default :auto)
     (:tie note-tie :codec (:form :tie)))
    (:tie tie make-tie
     (:end tie-end :always t))
    (:articulation articulation make-articulation
     (:kind articulation-kind :always t))
    (:fermata fermata make-fermata
     (:shape fermata-shape :default :normal))
    (:breath-mark breath-mark make-breath-mark)
    (:dynamic dynamic-mark make-dynamic-mark
     (:value dynamic-mark-value :always t))
    (:lyric lyric make-lyric
     (:verse lyric-verse :default 1)
     (:text lyric-text :always t)
     (:syllabic lyric-syllabic :default :single)
     (:extender lyric-extender))
    (:chord-symbol chord-symbol-anchor make-chord-symbol-anchor
     ((:bar :offset) anchor-position :codec :position :initarg :position :always t)
     (:symbol anchor-symbol :codec :chord-symbol :always t))
    (:spanner spanner make-spanner
     (:kind spanner-kind :always t)
     (:start spanner-start :always t)
     (:end spanner-end :always t)))
  "The canonical forms of the elements (sexp.lisp), as data: see above.")

(defparameter +reference-keys+
  '((:tie :end) (:spanner :start :end))
  "Element kind → the keys of its fields that hold references (ids.lisp:
References), where a draft may hold a DRAFT-REF (builder.lisp). Grammar data.")

(defstruct (%field (:constructor %make-field (key reader codec initarg default always))
                   (:copier nil) (:predicate nil))
  (key nil :read-only t)
  (reader nil :read-only t)
  (codec :value :read-only t)
  (initarg nil :read-only t)
  (default nil :read-only t)
  (always nil :read-only t))

(defstruct (%form-row (:constructor %make-form-row
                          (kind class constructor fields children references))
                      (:copier nil) (:predicate nil))
  "A parsed +ELEMENT-FORMS+ row. CHILDREN holds the child fields of FIELDS, in
document order; REFERENCES the fields that hold references (+REFERENCE-KEYS+),
in row order."
  (kind nil :read-only t)
  (class nil :read-only t)
  (constructor nil :read-only t)
  (fields '() :read-only t)
  (children '() :read-only t)
  (references '() :read-only t))

(defun %parse-field (spec)
  (destructuring-bind (key reader &key (codec :value) (initarg key) default always) spec
    (%make-field key reader codec initarg default always)))

(defun %child-field-p (field)
  (let ((codec (%field-codec field)))
    (and (consp codec) (member (car codec) '(:form :forms :voice-measures)) t)))

(defun %parse-form-row (row)
  (destructuring-bind (kind class constructor &rest specs) row
    (let ((fields (mapcar #'%parse-field
                          (append '((:id element-id))
                                  specs
                                  '((:provenance element-provenance :codec :provenance)
                                    (:confidence element-confidence))))))
      (%make-form-row kind class constructor fields
                      (remove-if-not #'%child-field-p fields)
                      (let ((keys (cdr (assoc kind +reference-keys+))))
                        (remove-if-not (lambda (field) (member (%field-key field) keys)) fields))))))

(defparameter +form-rows+ (mapcar #'%parse-form-row +element-forms+)
  "+ELEMENT-FORMS+ parsed, with the common fields added.")

(defun %element-row (element)
  "The grammar row of ELEMENT's class."
  (or (find-if (lambda (row) (typep element (%form-row-class row))) +form-rows+)
      (error 'type-error :datum element
                         :expected-type (cons 'or (mapcar #'%form-row-class +form-rows+)))))

(defun %kind-row (kind)
  (find kind +form-rows+ :key #'%form-row-kind))

(defun %field-value (field element)
  (funcall (%field-reader field) element))

;;; The walk --------------------------------------------------------------------

(defun %field-children (field value)
  "The elements in VALUE, the value of the child FIELD, in order."
  (ecase (car (%field-codec field))
    (:form (and value (list value)))
    (:forms value)
    (:voice-measures
     (loop for events in (fset:convert 'list value)
           append (fset:convert 'list events)))))

(defun %element-children (element)
  "ELEMENT's children in document order (ids.lisp)."
  (loop for field in (%form-row-children (%element-row element))
        append (%field-children field (%field-value field element))))

(defun %max-serial (elements)
  "(values serial draft-p): the largest serial among the ids of ELEMENTS and
everything inside them, or 0; and true when they form a draft, an id or a
reference among them being a DRAFT-REF (builder.lisp). References (tie ends,
spanner endpoints) aren't ids of elements."
  (let ((max 0) (draft nil))
    (labels ((visit (element)
               (let* ((id (element-id element))
                      (serial (%id-serial id))
                      (row (%element-row element)))
                 (when (and serial (> serial max)) (setf max serial))
                 (when (or (typep id 'draft-ref)
                           (some (lambda (field) (typep (%field-value field element) 'draft-ref))
                                 (%form-row-references row)))
                   (setf draft t))
                 (dolist (field (%form-row-children row))
                   (mapc #'visit (%field-children field (%field-value field element)))))))
      (mapc #'visit elements))
    (values max draft)))

;;; Drafts (builder.lisp, Resolution) --------------------------------------------
;;; A MINT SLOT is an element whose id MAKE-SCORE gives: its ID is NIL or a
;;; DRAFT-REF. %PLAN-DRAFT lists the ids of the slots in document order, the
;;; order in which %MINT asks NEXT-ID for them, so the rebuild walk takes the
;;; planned ids one by one and both walks mint the same ids in the same order.

(defun %mint-slot-p (id)
  "True when an element whose ID is ID gets its id from MAKE-SCORE."
  (or (null id) (typep id 'draft-ref)))

(defun %plan-draft (elements counter)
  "Resolution steps 1 to 4 (builder.lisp) over the draft ELEMENTS, in document
order, from COUNTER (the largest of :ID-COUNTER and the given serials).
(values ids carried counter): IDS, the id of every mint slot in document order;
CARRIED, an EQ hash table from each carried ref to its carrier's id; COUNTER,
the counter after minting."
  (let ((given (make-hash-table :test 'equal))
        (carried (make-hash-table :test 'eq))
        (slots '()))
    ;; 1. The given ids, and the slots. A ref carried twice can't be resolved:
    ;; no restart, before anything is minted.
    (labels ((scan (element)
               (let ((id (element-id element)))
                 (cond ((not (%mint-slot-p id)) (setf (gethash id given) t))
                       (t (when id
                            (when (nth-value 1 (gethash id carried))
                              (error 'unresolved-reference
                                     :key (draft-ref-key id)
                                     :reason "carried by more than one element"))
                            (setf (gethash id carried) nil))
                          (push element slots))))
               (mapc #'scan (%element-children element))))
      (mapc #'scan elements))
    (setf slots (nreverse slots))
    (let ((takes (make-hash-table :test 'eq))
          (taken (make-hash-table :test 'equal)))
      ;; 2. and 3. The first taker of a preferred id that no element is given
      ;; takes it, and its serial counts as a given one.
      (dolist (element slots)
        (let* ((ref (element-id element))
               (prefer (and ref (draft-ref-prefer ref))))
          (when (and prefer (not (gethash prefer given)) (not (gethash prefer taken)))
            (setf (gethash prefer taken) t
                  (gethash ref takes) prefer)
            (let ((serial (%id-serial prefer)))
              (when (and serial (> serial counter)) (setf counter serial))))))
      ;; 4. Every other slot is minted in its place.
      (let ((ids (mapcar (lambda (element)
                           (let* ((ref (element-id element))
                                  (id (or (and ref (gethash ref takes))
                                          (%minted-id (%id-prefix element) (incf counter)))))
                             (when ref (setf (gethash ref carried) id))
                             id))
                         slots)))
        (values ids carried counter)))))

;;; Minting and rebuilding -------------------------------------------------------

(defun %rebuild (element row id replacements)
  "A new instance of ELEMENT's class with ID, the field values in the alist
REPLACEMENTS (field . value: children, or resolved references), and every other
slot value unchanged."
  (apply #'make-instance (class-of element)
         (loop for field in (%form-row-fields row)
               for replacement = (assoc field replacements)
               nconc (list (%field-initarg field)
                           (cond ((eq (%field-key field) :id) id)
                                 (replacement (cdr replacement))
                                 (t (%field-value field element)))))))

(defun %mint-list (elements next-id &optional resolve)
  "(values elements changed-p): ELEMENTS minted in order; the same list when
nothing in it changed."
  (let* ((changed nil)
         (result (mapcar (lambda (element)
                           (multiple-value-bind (new new-p) (%mint element next-id resolve)
                             (when new-p (setf changed t))
                             new))
                         elements)))
    (if changed (values result t) (values elements nil))))

(defun %mint-field (field value next-id &optional resolve)
  "(values value changed-p) for the child FIELD's VALUE, minted in order."
  (ecase (car (%field-codec field))
    (:form (if value (%mint value next-id resolve) (values nil nil)))
    (:forms (%mint-list value next-id resolve))
    (:voice-measures
     ;; Replace only the voice measures that changed.
     (let ((result value) (changed nil))
       (dotimes (i (fset:size value) (values result changed))
         (multiple-value-bind (events events-p)
             (%mint-list (fset:convert 'list (fset:@ value i)) next-id resolve)
           (when events-p
             (setf changed t
                   result (fset:with result i (fset:convert 'fset:seq events))))))))))

(defun %mint (element next-id &optional resolve)
  "(values element changed-p): ELEMENT with an id from NEXT-ID (a function of
the element) for it and for everything inside it that is a mint slot, in
document order. The element takes its id before its children. RESOLVE, given
for a draft, maps each DRAFT-REF a reference holds to its id. ELEMENT itself
(EQ) when nothing needed an id or a resolved reference; otherwise a rebuilt
element. Never changes ELEMENT."
  (let* ((old-id (element-id element))
         (id (if (%mint-slot-p old-id) (funcall next-id element) old-id))
         (row (%element-row element))
         (replacements '()))
    (when resolve
      (dolist (field (%form-row-references row))
        (let ((value (%field-value field element)))
          (when (typep value 'draft-ref)
            (push (cons field (funcall resolve value)) replacements)))))
    (dolist (field (%form-row-children row))
      (multiple-value-bind (value changed)
          (%mint-field field (%field-value field element) next-id resolve)
        (when changed (push (cons field value) replacements))))
    (if (or (not (eq id old-id)) replacements)
        (values (%rebuild element row id replacements) t)
        (values element nil))))

;;; The index --------------------------------------------------------------------

(defstruct (%entry (:constructor %make-entry) (:copier nil) (:predicate nil))
  "One element of a score in its place: its PARENT element, its ORDER in the
document, and the PART, VOICE and EVENT it is inside (or is). MEASURE is the
index of its measure (measure-map elements) or voice measure (events and what
is on them), OFFSET its offset there; both NIL for parts, staves, voices,
anchors and spanners."
  (element nil :read-only t)
  (parent nil :read-only t)
  (order 0 :read-only t)
  (part nil :read-only t)
  (voice nil :read-only t)
  (event nil :read-only t)
  (measure nil :read-only t)
  (offset nil :read-only t))

(defstruct (%score-index (:constructor %make-score-index (by-id entries bars))
                         (:copier nil) (:predicate nil))
  "The private index of a score: BY-ID, an FSet map from id to the entry of its
first carrier; ENTRIES, every entry in document order (a simple-vector); BARS,
the bar table (measure-map.lisp)."
  (by-id nil :read-only t)
  (entries #() :read-only t)
  (bars nil :read-only t))

(defun %build-index (measures parts anchors spanners)
  "The index of the final element tree."
  (let ((entries '()) (order -1) (by-id (fset:empty-map)))
    (labels ((add (element parent part voice event measure offset)
               (let ((entry (%make-entry :element element :parent parent :order (incf order)
                                         :part part :voice voice :event event
                                         :measure measure :offset offset))
                     (id (element-id element)))
                 (push entry entries)
                 (unless (nth-value 1 (fset:lookup by-id id))
                   (setf by-id (fset:with by-id id entry)))))
             (visit (element parent part voice event measure offset)
               (add element parent part voice event measure offset)
               (typecase element
                 (part
                  (dolist (child (%element-children element))
                    (visit child element element nil nil nil nil)))
                 (voice
                  (let ((measures (voice-measures element)))
                    (dotimes (j (fset:size measures))
                      (let ((at 0))
                        (dolist (event (fset:convert 'list (fset:@ measures j)))
                          (visit event element part element event j at)
                          (unless (%grace-p event) (incf at (event-duration event))))))))
                 (t
                  (dolist (child (%element-children element))
                    (visit child element part voice event measure
                           (if (typep child 'tempo-mark) (tempo-mark-offset child) offset)))))))
      (loop for measure in measures
            for i from 0
            do (visit measure nil nil nil nil i 0))
      (dolist (part parts) (visit part nil part nil nil nil nil))
      (dolist (anchor anchors) (visit anchor nil nil nil nil nil nil))
      (dolist (spanner spanners) (visit spanner nil nil nil nil nil nil)))
    (%make-score-index by-id (coerce (nreverse entries) 'simple-vector)
                       (%compute-bar-table measures))))

(defun %score-index (score)
  (slot-value score 'index))

(defmethod %score-bars ((score score))
  (%score-index-bars (%score-index score)))

(defun %entry-of (score id)
  "The entry of the first carrier of ID in SCORE, or NIL."
  (values (fset:lookup (%score-index-by-id (%score-index score)) id)))

(defun %unknown-element (id)
  "Signal UNKNOWN-ELEMENT for ID inside a USE-VALUE restart; return the
restart's value."
  (restart-case (error 'unknown-element :id id)
    (use-value (value)
      :report "Return a value instead."
      :interactive (lambda ()
                     (format *query-io* "~&Value to return: ")
                     (finish-output *query-io*)
                     (list (read *query-io*)))
      value)))

;;; Construction ---------------------------------------------------------------

(defun %metadata-p (object)
  "True when OBJECT is a proper plist of distinct +METADATA-KEYS+ keys to strings."
  (loop with seen = '()
        for tail = object then (cddr tail)
        until (null tail)
        always (and (consp tail) (consp (cdr tail))
                    (member (car tail) +metadata-keys+)
                    (not (member (car tail) seen))
                    (stringp (cadr tail)))
        do (push (car tail) seen)))

(defun %canonical-metadata (metadata)
  "A fresh METADATA plist with its keys in +METADATA-KEYS+ order."
  (loop for key in +metadata-keys+
        for value = (getf metadata key)
        when value nconc (list key value)))

(defun %measures-p (object) (%list-or-seq-of-p object 'measure-info))
(defun %parts-p (object) (%list-or-seq-of-p object 'part))
(defun %anchors-p (object) (%list-or-seq-of-p object 'chord-symbol-anchor))
(defun %spanners-p (object) (%list-or-seq-of-p object 'spanner))

(defun %position< (a b)
  "True when the (bar . offset) position A is earlier than B."
  (or (< (car a) (car b))
      (and (= (car a) (car b)) (< (cdr a) (cdr b)))))

(defun make-score (&key metadata measures parts chord-symbols spanners (id-counter 0))
  "A SCORE (file header): ids minted, chord symbols sorted, elements indexed."
  (check-type metadata (satisfies %metadata-p)
              "a plist of distinct +METADATA-KEYS+ keys to strings")
  (check-type measures (satisfies %measures-p) "a list or FSet seq of MEASURE-INFOs")
  (check-type parts (satisfies %parts-p) "a list or FSet seq of PARTs")
  (check-type chord-symbols (satisfies %anchors-p)
              "a list or FSet seq of CHORD-SYMBOL-ANCHORs")
  (check-type spanners (satisfies %spanners-p) "a list or FSet seq of SPANNERs")
  (check-type id-counter (integer 0))
  (let* ((measures (fset:convert 'list measures))
         (parts (fset:convert 'list parts))
         ;; The track is sorted before minting: document order is track order.
         (anchors (stable-sort (copy-list (fset:convert 'list chord-symbols))
                               #'%position< :key #'anchor-position))
         (spanners (fset:convert 'list spanners))
         (all (append measures parts anchors spanners)))
    (multiple-value-bind (serial draft-p) (%max-serial all)
      (let ((counter (max id-counter serial))
            (planned '())                ; a draft's slot ids, in document order
            (carried nil)                ; a draft's ref → carrier id
            (dangling (and draft-p (make-hash-table :test 'eq)))) ; ref → its USE-VALUE
        ;; A draft is planned in full first: a reference may name a later carrier.
        (when draft-p
          (multiple-value-setq (planned carried counter) (%plan-draft all counter)))
        (labels ((next-id (element)
                   (if draft-p
                       (pop planned)
                       (%minted-id (%id-prefix element) (incf counter))))
                 (resolve (ref)
                   ;; Step 5, in document order of the referring element; one
                   ;; condition per dangling ref.
                   (multiple-value-bind (id found) (gethash ref carried)
                     (if found
                         id
                         (multiple-value-bind (stored seen) (gethash ref dangling)
                           (if seen
                               stored
                               (setf (gethash ref dangling) (%dangling-reference ref)))))))
                 (mint-all (elements)
                   (mapcar (lambda (element)
                             (values (%mint element #'next-id (and draft-p #'resolve))))
                           elements)))
          ;; LET* keeps score order: measures, parts, anchors, spanners.
          (let* ((measures (mint-all measures))
                 (parts (mint-all parts))
                 (anchors (mint-all anchors))
                 (spanners (mint-all spanners))
                 (score (make-instance 'score
                                       :metadata (%canonical-metadata metadata)
                                       :measure-map (fset:convert 'fset:seq measures)
                                       :parts (fset:convert 'fset:seq parts)
                                       :chord-symbols (fset:convert 'fset:seq anchors)
                                       :spanners (fset:convert 'fset:seq spanners)
                                       :id-counter counter
                                       :index (%build-index measures parts anchors spanners))))
            ;; Only a built score records its carriers' ids (builder.lisp).
            (when draft-p (%record-ids carried))
            score))))))

(defun copy-score (score &key (metadata nil metadata-p) (measures nil measures-p)
                              (parts nil parts-p) (chord-symbols nil chord-symbols-p)
                              (spanners nil spanners-p))
  "MAKE-SCORE with each omitted argument taken from SCORE, and SCORE's id counter."
  (check-type score score)
  (make-score :metadata (if metadata-p metadata (score-metadata score))
              :measures (if measures-p measures (score-measure-map score))
              :parts (if parts-p parts (score-parts score))
              :chord-symbols (if chord-symbols-p chord-symbols (score-chord-symbols score))
              :spanners (if spanners-p spanners (score-spanners score))
              :id-counter (score-id-counter score)))

;;; Lookups -------------------------------------------------------------------------

(defun score-elements (score)
  "A fresh list of every element of SCORE, in document order (ids.lisp)."
  (check-type score score)
  (map 'list #'%entry-element (%score-index-entries (%score-index score))))

(defgeneric find-element (score id &key errorp)
  (:documentation "The element of SCORE with ID (file header)."))

(defmethod find-element ((score score) id &key (errorp t))
  (let ((entry (%entry-of score id)))
    (cond (entry (%entry-element entry))
          (errorp (%unknown-element id))
          (t nil))))

(defgeneric element-parent (score id)
  (:documentation "The element above the element with ID, or NIL (file header)."))

(defmethod element-parent ((score score) id)
  (let ((entry (%entry-of score id)))
    (if entry
        (%entry-parent entry)
        (%unknown-element id))))

(defgeneric element-position (score id)
  (:documentation "The (bar . offset) of the element with ID, or NIL (measure-map.lisp)."))

(defun %entry-position (score entry seen)
  "The position of ENTRY's element (measure-map.lisp). SEEN holds the spanner
entries already followed, so a chain of spanners that loops gives NIL."
  (let ((element (%entry-element entry)))
    (typecase element
      (chord-symbol-anchor
       (let ((position (anchor-position element)))
         (cons (car position) (cdr position))))
      (spanner
       (let ((start (%entry-of score (spanner-start element))))
         (and start
              (not (member start seen))
              (%entry-position score start (cons entry seen)))))
      (t
       (let ((measure (%entry-measure entry)))
         (and measure
              (cons (+ (score-first-bar score) measure) (%entry-offset entry))))))))

(defmethod element-position ((score score) id)
  (let ((entry (%entry-of score id)))
    (if entry
        (%entry-position score entry (list entry))
        (%unknown-element id))))

(defun find-slice (score slice-id &key (errorp t))
  "(values measure element) for SLICE-ID (ids.lisp)."
  (check-type score score)
  (check-type slice-id string)
  (let* ((dot (position #\. slice-id))
         (measure-id (and dot (subseq slice-id 0 dot)))
         (element-id (and dot (subseq slice-id (1+ dot))))
         (measure (and (valid-id-p measure-id) (find-element score measure-id :errorp nil)))
         (element (and (valid-id-p element-id) (find-element score element-id :errorp nil))))
    (cond ((and (typep measure 'measure-info) (typep element '(or part staff voice)))
           (values measure element))
          (errorp (%unknown-element slice-id))
          (t nil))))

(defun uncertain-elements (score &key (below 0.8))
  "The elements of SCORE with a CONFIDENCE below BELOW, in document order."
  (check-type score score)
  (check-type below real)
  (loop for entry across (%score-index-entries (%score-index score))
        for element = (%entry-element entry)
        for confidence = (element-confidence element)
        when (and confidence (< confidence below))
          collect element))
