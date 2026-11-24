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
;;;;     are checked in the order of OP's slots, before anything changes.
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

(defmethod apply-edit ((score score) (op composite-edit))
  (%sc1-pending 'apply-edit/composite-edit))

(defmethod invert-edit ((score score) (op edit-operation))
  (%sc1-pending 'invert-edit))

(defun compose-edits (&rest ops)
  "A COMPOSITE-EDIT of OPS with nested composites spliced in, or the single
operation (file header)."
  (declare (ignorable ops))
  (%sc1-pending 'compose-edits))

(defun edit-to-sexp (op)
  "The canonical form of OP (file header)."
  (declare (ignorable op))
  (%sc1-pending 'edit-to-sexp))

(defun sexp-to-edit (form)
  "The operation FORM describes (file header)."
  (declare (ignorable form))
  (%sc1-pending 'sexp-to-edit))
