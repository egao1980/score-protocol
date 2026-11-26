;;;; SC1 the edit algebra: operations as values, APPLY-EDIT and its change set,
;;;; INVERT-EDIT, composition, and the canonical form of operations.
;;;;
;;;; An EDIT-OPERATION is an immutable value that names one change to a score.
;;;; The classes, with the rules of each in its file:
;;;;   events     INSERT-EVENT DELETE-EVENT REPLACE-EVENT SET-VOICE-MEASURES
;;;;              SET-PITCH SET-ACCIDENTAL SET-DURATION        (edit-events.lisp)
;;;;   marks      ADD-MARK REMOVE-MARK: dynamics, fermatas, breath marks,
;;;;              articulations, ties and lyrics on events; tempo marks,
;;;;              rehearsal marks, jump marks and endings on measures
;;;;   the score  ADD-SPANNER REMOVE-SPANNER ADD-CHORD-SYMBOL REMOVE-CHORD-SYMBOL
;;;;   measures   SET-KEY SET-TIME REPLACE-MEASURE INSERT-MEASURES DELETE-MEASURES
;;;;   pitch      TRANSPOSE                                    (edit-measures.lisp)
;;;;   several    COMPOSITE-EDIT                               (this file)
;;;; The brief's SET-LYRIC, SET-DYNAMIC and SET-ARTICULATION are ADD-MARK and
;;;; REMOVE-MARK; its SET-CHORD-SYMBOL is ADD-CHORD-SYMBOL.
;;;;
;;;; Operations target elements by id, never by place, so a logged operation
;;;; still names the same elements after other edits. Constructors MAKE-<class>
;;;; take keyword arguments named like the slots and signal TYPE-ERROR
;;;; (CHECK-TYPE) for a value outside the slot's type, as elements.lisp does.
;;;; Everything that relates an operation to a score, or two of its slots to
;;;; each other, is APPLY-EDIT's to check. Lists are stored fresh. Readers are
;;;; shared between classes (EDIT-ID, EDIT-VOICE, ...).
;;;;
;;;; APPLY-EDIT score op → (values new-score change-set). SCORE is never changed,
;;;; and the new score shares structure with it. APPLY-EDIT does this, in order:
;;;;  1. Preconditions: the ids OP names exist and are of the right kind, its
;;;;     positions lie in the score, and the rest each operation states. They
;;;;     are checked in the order of OP's slots, before anything changes. First
;;;;     of all (SC3), no element OP holds carries or refers to a DRAFT-REF
;;;;     (builder.lisp): refs are for building, and an operation with one
;;;;     signals INVALID-EDIT with REASON "draft reference". A COMPOSITE-EDIT's
;;;;     members are checked each in its own step 1, so the condition names the
;;;;     member.
;;;;  2. The change, by the operation's rules.
;;;;  3. Ids: every element without one is minted (Ids, below).
;;;;  4. The cascade: a tie or spanner of SCORE that the change broke is removed.
;;;;     Broken means it has, in the changed score, a :TIE-TARGET or :TIE-PITCH
;;;;     issue (for a tie) or a :SPANNER-ENDPOINT or :SPANNER-ORDER issue (for a
;;;;     spanner), check.lisp, that it does not have in SCORE. So a tie whose
;;;;     note is deleted or re-pitched goes, as does a slur whose note becomes a
;;;;     rest. Ties and spanners that OP itself adds are never removed.
;;;;  5. The check: every other CHECK-SCORE issue of the result that SCORE does
;;;;     not have (issues compared by kind and id) signals EDIT-BREAKS-SCORE with
;;;;     those issues. So an edit keeps a valid score valid.
;;;;
;;;; Ids (ids.lisp: stability). An operation keeps the id of every element it
;;;; doesn't remove, including the elements it changes or moves.
;;;;   * Elements an operation is GIVEN (an inserted event, a mark, a spanner,
;;;;     an anchor, measures, voice measures) keep the ids they carry, and so do
;;;;     the elements inside them. That is how INVERT-EDIT restores the elements
;;;;     an edit removed. A given id that the score carries outside what the
;;;;     operation replaces signals INVALID-EDIT. A user's new element is built
;;;;     without an id, so it gets a new one.
;;;;   * Every element of the result without an id, given without one or made
;;;;     by the operation (split pieces, the rests that fill a gap, the ties
;;;;     between pieces, measures), is minted: PREFIX-(c + k), c the
;;;;     SCORE-ID-COUNTER of SCORE and k = 1, 2, ... in document order of the
;;;;     result. Where a rule says an element "takes" an id (a mark that replaces
;;;;     one), it gets that id instead.
;;;;   * The result's SCORE-ID-COUNTER is the larger of c and every serial it
;;;;     carries, as MAKE-SCORE computes it. Serials are never reused.
;;;; A COMPOSITE-EDIT mints member by member: each member numbers its new
;;;; elements in document order of the score that member produces.
;;;;
;;;; Provenance (elements.lisp). Every element whose own slots an operation
;;;; changes, every element it makes, and the target of SET-PITCH,
;;;; SET-ACCIDENTAL and SET-DURATION (whatever the new value: the user has
;;;; confirmed it) get provenance (make-provenance :source :user) and
;;;; confidence 1: a re-pitched note, a lengthened event, its new pieces, fill
;;;; rests, a measure whose key changed. Own slots are the slots that aren't
;;;; children (score.lisp's grammar): a voice whose events change, and a chord
;;;; whose notes are transposed, keep their provenance. Given elements are
;;;; stored as given, provenance and confidence included.
;;;; Origins (0.4.0, elements.lisp). An element whose own slots an operation
;;;; changes keeps its ORIGIN: its new provenance is (make-provenance :source
;;;; :user :origin O), O its ELEMENT-ORIGIN before the edit (NIL when it had
;;;; none), so a derived element the user then edits still records what it
;;;; replaced. TRANSPOSE moves a chord-symbol origin with its anchor
;;;; (edit-measures.lisp). Every element an operation makes (split pieces, fill
;;;; rests, ties between pieces, measures, the rest a deleted note leaves) has
;;;; no origin, even one that takes an existing id. Elements the operation
;;;; doesn't change keep everything, origins included (Sharing, below), and
;;;; INVERT-EDIT gives every element back as it was, origin included. An
;;;; origin's ID is no element id: no precondition, mint or cascade reads it.
;;;;
;;;; The change set. A CHANGE-SET holds three lists of ids:
;;;;   CREATED   ids of the result that SCORE lacks, in the result's document
;;;;             order;
;;;;   REMOVED   ids of SCORE that the result lacks, in SCORE's document order;
;;;;   MODIFIED  ids of both whose SHALLOW FORM differs, in the result's
;;;;             document order.
;;;; The shallow form of an element is its canonical form (ELEMENT-TO-SEXP)
;;;; with the form of every child replaced by the child's id string. So a voice
;;;; is modified when events are added to it, removed or moved between its
;;;; voice measures, but not when one of its events changes pitch; an event is
;;;; modified when a mark is added to it, but not when its lyric's text
;;;; changes. The change set is exact: it is the difference between SCORE and
;;;; the result, whatever route the operation took. CHANGE-SET-EMPTY-P is true
;;;; when all three lists are empty; an operation that changes nothing returns
;;;; a score SCORE-EQUAL to SCORE and an empty change set.
;;;;
;;;; Sharing. Every element of the result whose canonical form (with
;;;; everything inside it) is EQUAL to the canonical form of the element of
;;;; SCORE with the same id is that element: EQ. Untouched subtrees are never
;;;; copied.
;;;;
;;;; Conditions (conditions.lisp). APPLY-EDIT signals INVALID-EDIT, OP being the
;;;; operation being applied, for a failed precondition or rule, with REASON a
;;;; short text. More specific subtypes:
;;;;   EDIT-TARGET-MISSING    an id OP names is not in SCORE. ID = that id. It
;;;;                          is also an UNKNOWN-ELEMENT.
;;;;   EDIT-POSITION-INVALID  a position, bar or measure range outside SCORE, an
;;;;                          offset that isn't an event boundary where one is
;;;;                          required, or music that would end after the end of
;;;;                          the score. POSITION = the rejected (bar . offset)
;;;;                          or bar, or the absolute offset where the music
;;;;                          would end. It is also an INVALID-POSITION.
;;;;   MEASURE-OVERFULL       INSERT-EVENT without REFLOW (edit-events.lisp).
;;;;   EDIT-BREAKS-SCORE      step 5. ISSUES = the new issues. It is also a
;;;;                          SCORE-INVARIANT-VIOLATION.
;;;; INVALID-EDIT itself covers the rest: an id of the wrong kind of element, a
;;;; given id the score already carries, a tuplet that would need splitting, a
;;;; pitch beyond two accidentals, and each operation's own refusals. Every one
;;;; is signalled inside the restarts SKIP-EDIT, which
;;;; makes APPLY-EDIT return (values score <empty change set>), and USE-VALUE,
;;;; which takes an operation and returns (apply-edit score that-operation).
;;;; MEASURE-OVERFULL adds REFLOW. TYPE-ERRORs from element constructors and
;;;; music-theory's own conditions are not wrapped, except where an operation
;;;; says so.
;;;; After REFLOW the operation being applied is the reflowed one: the same
;;;; INSERT-EVENT with REFLOW true. Every condition signalled after the
;;;; restart, the EDIT-BREAKS-SCORE of step 5 included, names that operation
;;;; as OP (SC3), so (edit-reflow (invalid-edit-op c)) is true. A member of a
;;;; COMPOSITE-EDIT is reflowed the same way; a failed check still names the
;;;; composite.
;;;;
;;;; Cost. APPLY-EDIT runs CHECK-SCORE up to three times (on SCORE, after the
;;;; change, after the cascade) and walks the whole score to share structure
;;;; and compute the change set, so one edit is O(n) in the size of the score
;;;; whatever its own size. That suits batch edits and edit logs. An editor
;;;; that applies an edit per keystroke should measure it on its largest
;;;; scores first (200 bars, four parts); checks scoped to the change set are
;;;; possible future work, not part of this contract.
;;;;
;;;; INVERT-EDIT score op → an operation INV such that, with
;;;; (values after changes) = (apply-edit score op):
;;;;   (apply-edit after INV) returns a score SCORE-EQUAL to SCORE, and a change
;;;;   set whose CREATED is the REMOVED of CHANGES, whose REMOVED is its CREATED
;;;;   and whose MODIFIED holds the same ids as its MODIFIED.
;;;; INV restores the removed elements with their ids. It is built from the
;;;; classes of this library (most often a COMPOSITE-EDIT), so it serialises;
;;;; its exact shape is the implementation's. INVERT-EDIT applies OP to SCORE
;;;; as APPLY-EDIT does, with the same conditions and restarts; when a restart
;;;; changes what is applied, INV inverts what was applied (an empty
;;;; COMPOSITE-EDIT for SKIP-EDIT).
;;;;
;;;; COMPOSITE-EDIT, slot OPS: a list of operations. Its members are applied in
;;;; order, each to the score the one before produced, through steps 1 to 3 of
;;;; APPLY-EDIT; the cascade and the check run once, on the score the last
;;;; member produced, against SCORE. A member's INVALID-EDIT names the member as
;;;; OP and is signalled in the member's own restarts: SKIP-EDIT skips that
;;;; member, USE-VALUE replaces it. A failed check names the composite. The
;;;; change set is the composite's, from SCORE to the result. An empty
;;;; composite changes nothing. COMPOSE-EDITS &rest ops → a COMPOSITE-EDIT of
;;;; OPS, the members of any composite among them spliced in their place; the
;;;; one operation itself when there is exactly one after splicing.
;;;;
;;;; The canonical form of operations. EDIT-TO-SEXP op → a form built like the
;;;; element forms of sexp.lisp: the operation's kind keyword, then its slots as
;;;; keys in the order below, a key left out when its value is NIL (or the
;;;; default shown as "= x"), except keys marked "always". Elements are written
;;;; as ELEMENT-TO-SEXP forms, operations as their own forms, ID as an id
;;;; string, PITCH as (pitch-name p), METER as (meter-string m), KEY as
;;;; (key-name k), INTERVAL as (interval-name i), R a rational, N an integer, K
;;;; a keyword:
;;;;   (:insert-event :voice ID :measure ID :offset R (= 0) :event EVENT :reflow T)
;;;;   (:delete-event :id ID)
;;;;   (:replace-event :id ID :event EVENT)
;;;;   (:set-voice-measures :voice ID :measure ID :measures ((EVENT...)...) (always))
;;;;   (:set-pitch :id ID :pitch PITCH)
;;;;   (:set-accidental :id ID :accidental K)
;;;;   (:set-duration :id ID :duration R :tuplet R)
;;;;   (:add-mark :target ID :mark MARK)
;;;;   (:remove-mark :id ID)
;;;;   (:add-spanner :spanner SPANNER)
;;;;   (:remove-spanner :id ID)
;;;;   (:add-chord-symbol :anchor ANCHOR)
;;;;   (:remove-chord-symbol :id ID)
;;;;   (:set-key :measure ID :key KEY)
;;;;   (:set-time :measure ID :time METER)
;;;;   (:replace-measure :id ID :measure-info MEASURE)
;;;;   (:insert-measures :before ID :measure-infos (MEASURE...) (always)
;;;;                     :contents ((ID (EVENT...)...)...))
;;;;   (:delete-measures :measure ID :count N (= 1))
;;;;   (:transpose :interval INTERVAL :to-key KEY :parts (ID...) :from ID :to ID)
;;;;   (:composite :ops (OP...) (always))
;;;; A CONTENTS entry is a voice id followed by that voice's new voice
;;;; measures. SEXP-TO-EDIT form → the operation, reading keys in any order and
;;;; building with the constructors and SEXP-TO-ELEMENT. A form that isn't a
;;;; list of a known kind keyword and a proper plist, or a plist with an unknown
;;;; key or a key given twice, signals SCORE-FORMAT-ERROR (FORMAT :SEXP,
;;;; POSITION the offending form), as sexp.lisp does; constructor TYPE-ERRORs
;;;; and music-theory's parse errors are not wrapped. For a form f that
;;;; EDIT-TO-SEXP returned, (edit-to-sexp (sexp-to-edit f)) is EQUAL to f, and
;;;; the operation read back applies to any score as the original does
;;;; (SCORE-EQUAL results, equal change sets).

(in-package #:score-protocol)

(defclass edit-operation ()
  ()
  (:documentation "An immutable edit of a score (file header)."))

(defmethod print-object ((op edit-operation) stream)
  (print-unreadable-object (op stream :type t :identity t)))

(defstruct (change-set (:constructor make-change-set (&key created removed modified)))
  "The ids an edit created, removed and modified (file header)."
  (created '() :type list :read-only t)
  (removed '() :type list :read-only t)
  (modified '() :type list :read-only t))

(defun change-set-empty-p (change-set)
  "True when CHANGE-SET created, removed and modified nothing."
  (check-type change-set change-set)
  (and (null (change-set-created change-set))
       (null (change-set-removed change-set))
       (null (change-set-modified change-set))))

(defclass composite-edit (edit-operation)
  ((ops :initarg :ops :reader edit-ops))
  (:documentation "Several operations applied as one (file header)."))

(defun %ops-p (object) (%list-of-p object 'edit-operation))

(defun make-composite-edit (&key ops)
  "A COMPOSITE-EDIT of the list OPS."
  (check-type ops (satisfies %ops-p) "a list of EDIT-OPERATIONs")
  (make-instance 'composite-edit :ops (copy-list ops)))

(defgeneric apply-edit (score op)
  (:documentation "(values new-score change-set): OP applied to SCORE (file header)."))

(defgeneric invert-edit (score op)
  (:documentation "The operation that undoes (apply-edit score op) (file header)."))

;;; Signalling -----------------------------------------------------------------
;;; Every refusal is signalled inside APPLY-EDIT's restarts (below). Lookups go
;;; through the index (%ENTRY-OF), never FIND-ELEMENT with ERRORP or the BAR-*
;;; functions, whose own USE-VALUE restarts would sit between the signal and
;;; APPLY-EDIT's.

(defun %refuse (op reason)
  "Signal INVALID-EDIT for OP."
  (error 'invalid-edit :op op :reason reason))

(defun %missing (op id)
  "Signal EDIT-TARGET-MISSING for the id ID of OP."
  (error 'edit-target-missing :op op :id id :reason "no element with this id"))

(defun %off (op position reason)
  "Signal EDIT-POSITION-INVALID for OP at POSITION."
  (error 'edit-position-invalid :op op :position position :reason reason))

(defun %target-entry (score op id type what)
  "The index entry of the element of SCORE with ID, which must be of TYPE:
EDIT-TARGET-MISSING when SCORE lacks ID, INVALID-EDIT when it is not WHAT."
  (let ((entry (%entry-of score id)))
    (cond ((null entry) (%missing op id))
          ((typep (%entry-element entry) type) entry)
          (t (%refuse op (format nil "~A is not ~A" id what))))))

(defun %target (score op id type what)
  "The element of SCORE with ID, of TYPE (%TARGET-ENTRY)."
  (%entry-element (%target-entry score op id type what)))

(defun %subtree-ids (elements)
  "The ids of ELEMENTS and of everything inside them, in document order."
  (let ((ids '()))
    (labels ((visit (element)
               (when (element-id element) (push (element-id element) ids))
               (mapc #'visit (%element-children element))))
      (mapc #'visit elements))
    (nreverse ids)))

(defun %check-given (score op elements replaced)
  "INVALID-EDIT when an id of ELEMENTS (given to OP, with everything inside
them) is carried by SCORE outside REPLACED, the elements OP replaces."
  (let ((inside (make-hash-table :test 'equal)))
    (dolist (id (%subtree-ids replaced))
      (setf (gethash id inside) t))
    (dolist (id (%subtree-ids elements))
      (when (and (%entry-of score id) (not (gethash id inside)))
        (%refuse op (format nil "the score already carries the id ~S" id))))))

;;; Rebuilding elements ------------------------------------------------------------

(defun %edited-origin (element)
  "The ORIGIN an edit that changes ELEMENT's own slots gives it: ELEMENT's own
(file header, Origins, 0.4.0)."
  (check-type element element)
  ;; ORIGIN is immutable, so the same object is shared; NIL when ELEMENT has none.
  (element-origin element))

(defun %user-provenance (&optional element)
  "The provenance and confidence an edit gives (file header), as initargs: with
ELEMENT, the element it changes, whose origin it keeps (0.4.0)."
  (list :provenance (make-provenance :source :user :origin (and element (%edited-origin element)))
        :confidence 1))

(defun %remake (element &rest overrides)
  "ELEMENT built again through its grammar row's constructor, with OVERRIDES
(initarg value ...) in place of its own values, so lists re-sort and booleans
normalise as the constructors do. Provenance is kept unless overridden."
  (let ((row (%element-row element)))
    (apply (%form-row-constructor row)
           (append overrides
                   (loop for field in (%form-row-fields row)
                         nconc (list (%field-initarg field) (%field-value field element)))))))

(defun %user (element &rest overrides)
  "%REMAKE with OVERRIDES and the provenance of an edit: ELEMENT's own slots change,
its origin stays (0.4.0). A :PROVENANCE among OVERRIDES wins."
  (apply #'%remake element (append overrides (%user-provenance element))))

(defun %field-initarg-of (element reader)
  "The initarg of the field of ELEMENT's grammar row read by READER."
  (%field-initarg (find reader (%form-row-fields (%element-row element)) :key #'%field-reader)))

(defun %with-id (element id)
  "ELEMENT with the id ID (ELEMENT itself when it has it)."
  (if (equal (element-id element) id)
      element
      (%rebuild element (%element-row element) id '())))

(defun %map-list (list fn)
  "(values list changed-p): LIST with FN applied to each member. FN returns
(values new changed-p); a NEW of :REMOVE drops the member. LIST itself when
nothing changed."
  (let ((changed nil) (out '()))
    (dolist (x list)
      (multiple-value-bind (new new-p) (funcall fn x)
        (when new-p (setf changed t))
        (unless (eq new :remove) (push new out))))
    (if changed (values (nreverse out) t) (values list nil))))

(defun %map-field (field value fn)
  "(values value changed-p) for the child FIELD's VALUE, FN applied to each child."
  (ecase (car (%field-codec field))
    (:form (if value
               (multiple-value-bind (new changed) (funcall fn value)
                 (if changed (values (if (eq new :remove) nil new) t) (values value nil)))
               (values nil nil)))
    (:forms (%map-list value fn))
    (:voice-measures
     (let ((result value) (changed nil))
       (dotimes (i (fset:size value) (values result changed))
         (multiple-value-bind (events events-p) (%map-list (fset:convert 'list (fset:@ value i)) fn)
           (when events-p
             (setf changed t
                   result (fset:with result i (fset:convert 'fset:seq events))))))))))

(defun %map-children (element fn &optional (id (element-id element)) more)
  "(values element changed-p): ELEMENT with FN applied to each child (%MAP-FIELD),
the id ID and the extra (field . value) replacements MORE. ELEMENT itself (EQ)
when nothing changed; otherwise a %REBUILD, other slots and provenance kept."
  (let* ((row (%element-row element))
         (replacements (copy-list more)))
    (dolist (field (%form-row-children row))
      (multiple-value-bind (value changed) (%map-field field (%field-value field element) fn)
        (when changed (push (cons field value) replacements))))
    (if (or replacements (not (equal id (element-id element))))
        (values (%rebuild element row id replacements) t)
        (values element nil))))

(defun %row-field (element key)
  "The field of ELEMENT's grammar row with KEY."
  (find key (%form-row-fields (%element-row element)) :key #'%field-key))

;;; Building the result ---------------------------------------------------------------
;;; A change builds its new elements without ids. A tie it makes between split
;;; pieces holds the piece itself as END until %BUILD-SCORE has numbered it.

(defun %seq-list (seq)
  (fset:convert 'list seq))

(defun %measure-list (score) (%seq-list (score-measure-map score)))
(defun %part-list (score) (%seq-list (score-parts score)))
(defun %anchor-list (score) (%seq-list (score-chord-symbols score)))
(defun %spanner-list (score) (%seq-list (score-spanners score)))

(defun %voice-list (score)
  "Every voice of SCORE, in document order."
  (loop for part in (%part-list score) append (copy-list (part-voices part))))

(defun %resolve (element ids)
  "(values element changed-p): ELEMENT with the ids planned in IDS (an EQ table)
and every tie END that is an element replaced by that element's id."
  (let ((more (and (typep element 'tie) (not (stringp (tie-end element)))
                   (let ((target (tie-end element)))
                     (list (cons (%row-field element :end)
                                 (or (element-id target) (gethash target ids))))))))
    (%map-children element (lambda (child) (%resolve child ids))
                   (or (element-id element) (gethash element ids))
                   more)))

(defun %build-score (score &key (measures nil measures-p) (parts nil parts-p)
                                (anchors nil anchors-p) (spanners nil spanners-p))
  "A score with SCORE's metadata and the given lists (the others SCORE's). Steps 3
of APPLY-EDIT: every element without an id is minted PREFIX-(c + k) in document
order, c the counter MAKE-SCORE would start from (SCORE's, or a larger given
serial); ties to new pieces get their ids. Then MAKE-SCORE, which mints nothing."
  (let* ((measures (if measures-p measures (%measure-list score)))
         (parts (if parts-p parts (%part-list score)))
         ;; Track order before numbering, as MAKE-SCORE sorts it.
         (anchors (stable-sort (copy-list (if anchors-p anchors (%anchor-list score)))
                               #'%position< :key #'anchor-position))
         (spanners (if spanners-p spanners (%spanner-list score)))
         (all (append measures parts anchors spanners))
         (counter (max (score-id-counter score) (%max-serial all)))
         (ids (make-hash-table :test 'eq))
         (pending nil))
    (labels ((plan (element)
               (unless (or (element-id element) (gethash element ids))
                 (setf (gethash element ids) (%minted-id (%id-prefix element) (incf counter))))
               (when (and (typep element 'tie) (not (stringp (tie-end element))))
                 (setf pending t))
               (mapc #'plan (%element-children element))))
      (mapc #'plan all))
    (flet ((fix (list)
             (if (or pending (plusp (hash-table-count ids)))
                 (values (%map-list list (lambda (element) (%resolve element ids))))
                 list)))
      (make-score :metadata (score-metadata score)
                  :measures (fix measures) :parts (fix parts)
                  :chord-symbols (fix anchors) :spanners (fix spanners)
                  :id-counter (score-id-counter score)))))

(defun %substitute (score table)
  "SCORE with every element that is a key of TABLE (an EQ hash table) replaced
by its value, :REMOVE dropping it; only their ancestors are rebuilt."
  (let ((above (make-hash-table :test 'eq)))
    (labels ((mark (element)
               (let* ((entry (%entry-of score (element-id element)))
                      (parent (and entry (%entry-parent entry))))
                 (when (and parent (not (gethash parent above)))
                   (setf (gethash parent above) t)
                   (mark parent))))
             (walk (element)
               (multiple-value-bind (new found) (gethash element table)
                 (cond (found (values new t))
                       ((gethash element above) (%map-children element #'walk))
                       (t (values element nil)))))
             (top (list) (values (%map-list list #'walk))))
      (loop for element being the hash-keys of table do (mark element))
      (%build-score score :measures (top (%measure-list score)) :parts (top (%part-list score))
                          :anchors (top (%anchor-list score)) :spanners (top (%spanner-list score))))))

(defun %substitute-1 (score old new)
  "SCORE with the element OLD replaced by NEW (%SUBSTITUTE)."
  (if (eq old new)
      score
      (let ((table (make-hash-table :test 'eq)))
        (setf (gethash old table) new)
        (%substitute score table))))

;;; The shallow form, sharing and the change set ------------------------------------

(defun %shallow-form (element)
  "ELEMENT's canonical form with every child form replaced by its id (file header)."
  (let ((row (%element-row element)))
    (cons (%form-row-kind row)
          (loop for field in (%form-row-fields row)
                for value = (%field-value field element)
                nconc (if (%child-field-p field)
                          (ecase (car (%field-codec field))
                            (:form (and value (list (%field-key field) (element-id value))))
                            (:forms (and (or value (%field-always field))
                                         (list (%field-key field) (mapcar #'element-id value))))
                            (:voice-measures
                             (list (%field-key field)
                                   (mapcar (lambda (events) (mapcar #'element-id (%seq-list events)))
                                           (%seq-list value)))))
                          (%encode-field field element))))))

(defun %reshare (input result)
  "RESULT with every element whose canonical form equals that of INPUT's element
with the same id replaced by INPUT's (EQ), bottom-up (file header: Sharing)."
  (labels ((share (element)
             (let* ((entry (%entry-of input (element-id element)))
                    (old (and entry (%entry-element entry))))
               (if (eq element old)
                   (values element nil)
                   (multiple-value-bind (new changed) (%map-children element #'share)
                     (if (and old
                              (eq (class-of old) (class-of new))
                              (equal (%shallow-form new) (%shallow-form old))
                              (every #'eq (%element-children new) (%element-children old)))
                         (values old t)
                         (values new changed))))))
           (top (list) (%map-list list #'share)))
    (multiple-value-bind (measures m-p) (top (%measure-list result))
      (multiple-value-bind (parts p-p) (top (%part-list result))
        (multiple-value-bind (anchors a-p) (top (%anchor-list result))
          (multiple-value-bind (spanners s-p) (top (%spanner-list result))
            (if (or m-p p-p a-p s-p)
                (make-score :metadata (score-metadata result) :measures measures :parts parts
                            :chord-symbols anchors :spanners spanners
                            :id-counter (score-id-counter result))
                result)))))))

(defun %change-set (input result)
  "The CHANGE-SET from INPUT to RESULT (file header), computed as a difference."
  (let ((created '()) (removed '()) (modified '()))
    (loop for entry across (%score-index-entries (%score-index result))
          for element = (%entry-element entry)
          for old-entry = (%entry-of input (element-id element))
          for old = (and old-entry (%entry-element old-entry))
          do (cond ((null old) (push (element-id element) created))
                   ((eq old element))
                   ((not (equal (%shallow-form element) (%shallow-form old)))
                    (push (element-id element) modified))))
    (loop for entry across (%score-index-entries (%score-index input))
          for id = (element-id (%entry-element entry))
          unless (%entry-of result id) do (push id removed))
    (make-change-set :created (nreverse created) :removed (nreverse removed)
                     :modified (nreverse modified))))

;;; Steps 4 and 5: the cascade and the check ------------------------------------------

(defparameter +cascade-kinds+
  '((:tie-target . tie) (:tie-pitch . tie)
    (:spanner-endpoint . spanner) (:spanner-order . spanner))
  "The issue kinds that remove a broken tie or spanner of the score, and the
class of their subject (file header, step 4). Data.")

(defun %issue-key (issue)
  (cons (score-issue-kind issue) (score-issue-id issue)))

(defun %issue-keys (issues)
  "An EQUAL hash set of the (kind . id) keys of ISSUES."
  (let ((keys (make-hash-table :test 'equal)))
    (dolist (issue issues keys)
      (setf (gethash (%issue-key issue) keys) t))))

(defun %cascade (input changed old-keys)
  "CHANGED without the ties and spanners of INPUT that the change broke: those
with a cascade issue (+CASCADE-KINDS+) not in OLD-KEYS. A tie or spanner is
INPUT's when INPUT has one with its id and an EQUAL canonical form; the ones the
operation added face the check."
  (let ((table (make-hash-table :test 'eq)))
    (dolist (issue (check-score changed))
      (let ((class (cdr (assoc (score-issue-kind issue) +cascade-kinds+))))
        (when (and class (not (gethash (%issue-key issue) old-keys)))
          (let* ((id (score-issue-id issue))
                 (new (find-element changed id :errorp nil))
                 (old (find-element input id :errorp nil)))
            (when (and (typep new class) (typep old class)
                       (or (eq new old) (equal (element-to-sexp new) (element-to-sexp old))))
              (setf (gethash new table) :remove))))))
    (if (zerop (hash-table-count table))
        changed
        (%substitute changed table))))

(defun %finish (score changed op)
  "Steps 4 and 5 of APPLY-EDIT for the score CHANGED that OP made from SCORE, then
sharing: (values result change-set)."
  (if (eq changed score)
      (values score (make-change-set))
      (let* ((old-keys (%issue-keys (check-score score)))
             (cut (%cascade score changed old-keys))
             (new (remove-if (lambda (issue) (gethash (%issue-key issue) old-keys))
                             (check-score cut))))
        (when new
          (error 'edit-breaks-score :op op :issues new :reason "the edit breaks the score"))
        (let ((result (%reshare score cut)))
          (values result (%change-set score result))))))

;;; The driver -------------------------------------------------------------------

(defgeneric %edit-change (op score)
  (:documentation "Steps 1 to 3 of APPLY-EDIT: OP's preconditions in slot order,
then its change. Returns the changed score with every new element minted
(%BUILD-SCORE), or SCORE itself when nothing changes; when the REFLOW restart
re-applied an INSERT-EVENT, the reflowed operation is a second value. Each
operation class has a method in its own file; the :BEFORE method on every
operation (the end of this file) is the draft-reference check of step 1."))

(defun %read-operation ()
  "The :INTERACTIVE argument list of the USE-VALUE restarts: an operation form."
  (format *query-io* "~&Operation form to apply instead: ")
  (finish-output *query-io*)
  (list (sexp-to-edit (read *query-io*))))

(defmethod apply-edit ((score score) (op edit-operation))
  ;; A second value that is an operation is the reflowed insert the REFLOW
  ;; restart applied (edit-events.lisp): from then on it is the one applied.
  (restart-case (multiple-value-bind (changed reflowed) (%edit-change op score)
                  (%finish score changed (if (typep reflowed 'edit-operation) reflowed op)))
    (skip-edit ()
      :report "Skip this edit: return the score unchanged."
      (values score (make-change-set)))
    (use-value (other)
      :report "Apply another operation instead."
      :interactive %read-operation
      (apply-edit score other))))

(defun %apply-member (score op)
  "Steps 1 to 3 for the composite member OP on SCORE, in the member's own restarts."
  (restart-case (%edit-change op score)
    (skip-edit ()
      :report "Skip this member of the composite."
      score)
    (use-value (other)
      :report "Apply another operation in place of this member."
      :interactive %read-operation
      (%apply-member score other))))

(defmethod %edit-change ((op composite-edit) (score score))
  ;; One value: a reflowed member never renames the composite.
  (values (reduce #'%apply-member (edit-ops op) :initial-value score)))

(defun compose-edits (&rest ops)
  "A COMPOSITE-EDIT of OPS with nested composites spliced in, or the single
operation (file header)."
  (let ((members (loop for op in ops
                       append (if (typep op 'composite-edit)
                                  (copy-list (edit-ops op))
                                  (list op)))))
    (if (and members (null (rest members)))
        (first members)
        (make-composite-edit :ops members))))

;;; INVERT-EDIT ---------------------------------------------------------------------
;;; The inverse is read off the pair (before, after), so it inverts what was
;;; applied, whatever route, restart or cascade led there. It holds only
;;; restore-style operations, given BEFORE's own elements, so ids, provenance
;;; and confidence come back as stored and nothing is minted.

(defmethod invert-edit ((score score) (op edit-operation))
  (make-composite-edit :ops (%restore-ops score (apply-edit score op))))

(defun %cells (voice)
  "VOICE's voice measures as a list of lists of events."
  (mapcar #'%seq-list (%seq-list (voice-measures voice))))

(defun %cell-eq (a b)
  "True when the event lists A and B hold the same objects in order."
  (and (= (length a) (length b)) (every #'eq a b)))

(defun %bare-measure (measure)
  "MEASURE with its own slots and none of its marks."
  (%remake measure :ending nil :jump '() :rehearsal nil :tempo '()))

(defun %spanner-tail (before after)
  "(values removed added): AFTER's spanners after the longest common prefix with
BEFORE's (EQ members), and BEFORE's."
  (let* ((b (%spanner-list before))
         (a (%spanner-list after))
         (k (or (mismatch a b :test #'eq) (length a))))
    (values (nthcdr k a) (nthcdr k b))))

(defun %runs (list predicate)
  "The maximal runs of consecutive members of LIST satisfying PREDICATE, each
(run . next), NEXT the member after the run or NIL."
  (let ((runs '()) (run '()))
    (loop for x in list
          do (cond ((funcall predicate x) (push x run))
                   (run (push (cons (nreverse run) x) runs) (setf run '()))))
    (when run (push (cons (nreverse run) nil) runs))
    (nreverse runs)))

(defun %direct-restore (before after)
  "(values ops ok-p): the restore when BEFORE and AFTER have the same measures by
id: replace what differs. OK-P is false when a given id is carried in AFTER
outside the place its operation replaces (then %REMAP-RESTORE is used)."
  (let ((removals '()) (replacements '()) (additions '())
        (units '()))                    ; (given . replaced)
    (let ((b-anchors (%anchor-list before)) (a-anchors (%anchor-list after)))
      (dolist (a a-anchors)
        (unless (member a b-anchors :test #'eq)
          (push (make-remove-chord-symbol :id (element-id a)) removals)
          (push (cons '() (list a)) units)))
      (dolist (b b-anchors)
        (unless (member b a-anchors :test #'eq)
          (push (make-add-chord-symbol :anchor b) additions)
          (push (cons (list b) '()) units))))
    (multiple-value-bind (gone back) (%spanner-tail before after)
      (dolist (a gone)
        (push (make-remove-spanner :id (element-id a)) removals)
        (push (cons '() (list a)) units))
      (dolist (b back)
        (push (make-add-spanner :spanner b) additions)
        (push (cons (list b) '()) units)))
    (loop for b in (%measure-list before)
          for a in (%measure-list after)
          unless (eq a b)
            do (push (make-replace-measure :id (element-id b) :measure-info b) replacements)
               (push (cons (list b) (list a)) units))
    (let ((measure-ids (mapcar #'element-id (%measure-list before))))
      (dolist (b (%voice-list before))
        (let ((a (%entry-element (%entry-of after (element-id b)))))
          (unless (eq a b)
            (let* ((bc (%cells b)) (ac (%cells a))
                   (lo (loop for x in bc for y in ac for i from 0
                             unless (%cell-eq x y) return i))
                   (hi (loop for i from (1- (min (length bc) (length ac))) downto 0
                             unless (%cell-eq (nth i bc) (nth i ac)) return i)))
              (when lo
                (let ((given (subseq bc lo (1+ hi))))
                  (push (make-set-voice-measures :voice (element-id b) :measure (nth lo measure-ids)
                                                 :measures given)
                        replacements)
                  (push (cons (apply #'append given) (apply #'append (subseq ac lo (1+ hi))))
                        units))))))))
    ;; Each given id must be free in AFTER except inside its own unit.
    (let ((ok (loop for (given . replaced) in units
                    always (let ((inside (%subtree-ids replaced)))
                             (loop for id in (%subtree-ids given)
                                   never (and (%entry-of after id)
                                              (not (member id inside :test #'string=))))))))
      (values (append (nreverse removals) (nreverse replacements) (nreverse additions)) ok))))

(defun %remap-restore (before after)
  "The restore when the measures differ (or a direct restore would collide): clear,
re-shape the measure map, then restore everything that can differ."
  (let* ((b-measures (%measure-list before))
         (a-measures (%measure-list after))
         (b-ids (mapcar #'element-id b-measures))
         (a-ids (mapcar #'element-id a-measures))
         (ops '()))
    (flet ((emit (op) (push op ops))
           (b-has (id) (member id b-ids :test #'string=))
           (a-has (id) (member id a-ids :test #'string=)))
      ;; 1. Anchors would move with measures and turn :USER: all go now.
      (dolist (a (%anchor-list after))
        (emit (make-remove-chord-symbol :id (element-id a))))
      (multiple-value-bind (gone back) (%spanner-tail before after)
        (dolist (a gone)
          (emit (make-remove-spanner :id (element-id a))))
        ;; 2. Silence every voice that holds music.
        (when a-measures
          (dolist (v (%voice-list after))
            (when (some #'identity (%cells v))
              (emit (make-set-voice-measures :voice (element-id v) :measure (first a-ids)
                                             :measures (make-list (length a-measures)))))))
        ;; 3. Strip the kept measures that differ, so no mark is carried twice.
        (dolist (a a-measures)
          (let ((b (find (element-id a) b-measures :key #'element-id :test #'string=)))
            (when (and b (not (eq a b)))
              (emit (make-replace-measure :id (element-id a) :measure-info (%bare-measure b))))))
        ;; 4. Delete AFTER's measures that BEFORE lacks.
        (loop for (run) in (%runs a-measures (lambda (m) (not (b-has (element-id m)))))
              do (emit (make-delete-measures :measure (element-id (first run)) :count (length run))))
        ;; 5. Insert BEFORE's measures that AFTER lacks, every voice silent there.
        (let ((voices (%voice-list before)))
          (loop for (run . next) in (%runs b-measures (lambda (m) (not (a-has (element-id m)))))
                do (emit (make-insert-measures
                          :before (and next (element-id next)) :measure-infos run
                          :contents (mapcar (lambda (v) (cons (element-id v) (make-list (length run))))
                                            voices)))))
        ;; 6. Every kept measure as it was: undoes stripped marks and kept signatures.
        (dolist (b b-measures)
          (when (a-has (element-id b))
            (emit (make-replace-measure :id (element-id b) :measure-info b))))
        ;; 7. Every voice's music as it was.
        (when b-measures
          (dolist (v (%voice-list before))
            (when (some #'identity (%cells v))
              (emit (make-set-voice-measures :voice (element-id v) :measure (first b-ids)
                                             :measures (%cells v))))))
        ;; 8. The anchors and the spanner tail.
        (dolist (b (%anchor-list before))
          (emit (make-add-chord-symbol :anchor b)))
        (dolist (b back)
          (emit (make-add-spanner :spanner b))))
      (nreverse ops))))

(defun %restore-ops (before after)
  "Restore-style operations that turn AFTER back into BEFORE."
  (cond ((eq before after) '())
        ((equal (mapcar #'element-id (%measure-list before))
                (mapcar #'element-id (%measure-list after)))
         (multiple-value-bind (ops ok) (%direct-restore before after)
           (if ok ops (%remap-restore before after))))
        (t (%remap-restore before after))))

;;; The canonical form of operations ---------------------------------------------
;;; One row per operation class, like +ELEMENT-FORMS+ (score.lisp): kind,
;;; class, constructor, then the fields in header order, parsed by %PARSE-FIELD.
;;; Codecs beyond sexp.lisp's: (:ELEMENT kind...), (:ELEMENTS kind...),
;;; (:EVENT-MEASURES kind...), (:CONTENTS kind...), :INTERVAL and :OPS.

(defparameter +edit-forms+
  '((:insert-event insert-event make-insert-event
     (:voice edit-voice) (:measure edit-measure) (:offset edit-offset :default 0)
     (:event edit-event :codec (:element :rest :note :chord)) (:reflow edit-reflow))
    (:delete-event delete-event make-delete-event
     (:id edit-id))
    (:replace-event replace-event make-replace-event
     (:id edit-id) (:event edit-event :codec (:element :rest :note :chord)))
    (:set-voice-measures set-voice-measures make-set-voice-measures
     (:voice edit-voice) (:measure edit-measure)
     (:measures edit-measures :codec (:event-measures :rest :note :chord) :always t))
    (:set-pitch set-pitch make-set-pitch
     (:id edit-id) (:pitch edit-pitch :codec :pitch))
    (:set-accidental set-accidental make-set-accidental
     (:id edit-id) (:accidental edit-accidental))
    (:set-duration set-duration make-set-duration
     (:id edit-id) (:duration edit-duration) (:tuplet edit-tuplet))
    (:add-mark add-mark make-add-mark
     (:target edit-target)
     (:mark edit-mark :codec (:element :dynamic :fermata :breath-mark :articulation :tie :lyric
                                       :tempo-mark :rehearsal :jump :ending)))
    (:remove-mark remove-mark make-remove-mark
     (:id edit-id))
    (:add-spanner add-spanner make-add-spanner
     (:spanner edit-spanner :codec (:element :spanner)))
    (:remove-spanner remove-spanner make-remove-spanner
     (:id edit-id))
    (:add-chord-symbol add-chord-symbol make-add-chord-symbol
     (:anchor edit-anchor :codec (:element :chord-symbol)))
    (:remove-chord-symbol remove-chord-symbol make-remove-chord-symbol
     (:id edit-id))
    (:set-key set-key make-set-key
     (:measure edit-measure) (:key edit-key :codec :key))
    (:set-time set-time make-set-time
     (:measure edit-measure) (:time edit-time :codec :meter))
    (:replace-measure replace-measure make-replace-measure
     (:id edit-id) (:measure-info edit-measure-info :codec (:element :measure)))
    (:insert-measures insert-measures make-insert-measures
     (:before edit-before) (:measure-infos edit-measure-infos :codec (:elements :measure) :always t)
     (:contents edit-contents :codec (:contents :rest :note :chord)))
    (:delete-measures delete-measures make-delete-measures
     (:measure edit-measure) (:count edit-count :default 1))
    (:transpose transpose make-transpose
     (:interval edit-interval :codec :interval) (:to-key edit-to-key :codec :key)
     (:parts edit-parts) (:from edit-from) (:to edit-to))
    (:composite composite-edit make-composite-edit
     (:ops edit-ops :codec :ops :always t)))
  "The canonical forms of the operations (file header), as data: kind, class,
constructor, fields (KEY READER &key CODEC INITARG DEFAULT ALWAYS).")

(defstruct (%edit-row (:constructor %make-edit-row (kind class constructor fields))
                      (:copier nil) (:predicate nil))
  (kind nil :read-only t)
  (class nil :read-only t)
  (constructor nil :read-only t)
  (fields '() :read-only t))

(defparameter +edit-rows+
  (mapcar (lambda (row)
            (destructuring-bind (kind class constructor &rest specs) row
              (%make-edit-row kind class constructor (mapcar #'%parse-field specs))))
          +edit-forms+)
  "+EDIT-FORMS+ parsed.")

(defun %edit-row-of (op)
  (or (find-if (lambda (row) (typep op (%edit-row-class row))) +edit-rows+)
      (error 'type-error :datum op :expected-type 'edit-operation)))

(defun %event-measures-to-sexp (measures)
  (mapcar (lambda (events) (mapcar #'element-to-sexp events)) measures))

(defun %encode-op-value (codec value)
  "VALUE of an operation field in its canonical form."
  (if (consp codec)
      (ecase (car codec)
        (:element (element-to-sexp value))
        (:elements (mapcar #'element-to-sexp value))
        (:event-measures (%event-measures-to-sexp value))
        (:contents (mapcar (lambda (entry)
                             (cons (car entry) (%event-measures-to-sexp (cdr entry))))
                           value)))
      (case codec
        (:interval (music-theory:interval-name value))
        (:ops (mapcar #'edit-to-sexp value))
        (t (%encode codec value)))))

(defun %read-event-measures (value kinds)
  (unless (%proper-list-p value)
    (%format-error value "expected a list of voice measures"))
  (mapcar (lambda (events) (%read-forms events kinds)) value))

(defun %decode-op-value (codec value)
  "The value of the non-NIL form VALUE of an operation field."
  (if (consp codec)
      (destructuring-bind (shape &rest kinds) codec
        (ecase shape
          (:element (%read-element value kinds))
          (:elements (%read-forms value kinds))
          (:event-measures (%read-event-measures value kinds))
          (:contents
           (unless (%proper-list-p value)
             (%format-error value "expected a list of contents entries"))
           (mapcar (lambda (entry)
                     (unless (consp entry)
                       (%format-error entry "expected (voice-id voice-measure...)"))
                     (cons (car entry) (%read-event-measures (cdr entry) kinds)))
                   value))))
      (case codec
        (:interval (music-theory:parse-interval value))
        (:ops
         (unless (%proper-list-p value)
           (%format-error value "expected a list of operation forms"))
         (mapcar #'sexp-to-edit value))
        (t (%decode codec value)))))

(defun edit-to-sexp (op)
  "The canonical form of OP (file header)."
  (check-type op edit-operation)
  (let ((row (%edit-row-of op)))
    (cons (%edit-row-kind row)
          (loop for field in (%edit-row-fields row)
                for value = (funcall (%field-reader field) op)
                unless (and (not (%field-always field))
                            (or (null value) (eql value (%field-default field))))
                  nconc (list (%field-key field) (%encode-op-value (%field-codec field) value))))))

(defun sexp-to-edit (form)
  "The operation FORM describes (file header)."
  (let ((row (and (consp form) (find (car form) +edit-rows+ :key #'%edit-row-kind))))
    (unless (and row (%proper-list-p form))
      (%format-error form "expected an operation form"))
    (let ((plist (cdr form))
          (fields (%edit-row-fields row)))
      (%check-plist plist (mapcar #'%field-key fields) form)
      (apply (%edit-row-constructor row)
             (loop for field in fields
                   for value = (getf plist (%field-key field))
                   when value
                     nconc (list (%field-initarg field)
                                 (%decode-op-value (%field-codec field) value)))))))

;;; Step 1: refs are for building ---------------------------------------------------

(defun %op-elements (op)
  "The elements OP is given, from the element codecs of its +EDIT-ROWS+ row. A
COMPOSITE-EDIT holds operations, not elements: none."
  (loop for field in (%edit-row-fields (%edit-row-of op))
        for codec = (%field-codec field)
        for value = (funcall (%field-reader field) op)
        when (consp codec)
          append (ecase (car codec)
                   (:element (and value (list value)))
                   (:elements (copy-list value))
                   (:event-measures (loop for events in value append (copy-list events)))
                   (:contents (loop for (nil . measures) in value
                                    append (loop for events in measures
                                                 append (copy-list events)))))))

(defmethod %edit-change :before ((op edit-operation) (score score))
  ;; First of every precondition, inside the restarts of whoever applies OP:
  ;; APPLY-EDIT's, or a composite member's own.
  (when (nth-value 1 (%max-serial (%op-elements op)))
    (%refuse op "draft reference")))
