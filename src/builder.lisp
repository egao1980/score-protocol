;;;; SC3 drafts and the score builder: references to elements that have no id yet.
;;;;
;;;; A tie's END and a spanner's START and END hold ids (ids.lisp: References),
;;;; and MAKE-SCORE mints the ids of the elements given without one. A reader of
;;;; a file builds every element before MAKE-SCORE runs, so it can't know the id
;;;; its tie or slur must name. A SCORE-BUILDER hands out DRAFT-REFs: placeholders
;;;; that stand for the id of the element that carries one. MAKE-SCORE puts the
;;;; final ids in their place, in the same call, so a reader builds its score
;;;; once.
;;;;
;;;; MAKE-SCORE-BUILDER → a fresh SCORE-BUILDER. It is a value its caller owns:
;;;;   nothing here is global, and minting stays a function of the score alone.
;;;; BUILDER-REF builder key &key prefer → the DRAFT-REF of KEY in BUILDER, made
;;;;   by the first call for KEY. KEY is any object, compared with EQUAL: every
;;;;   later call with an EQUAL key returns the same (EQ) ref, and refs of two
;;;;   builders are never EQ. PREFER is NIL or an id string (VALID-ID-P), else
;;;;   TYPE-ERROR; a non-NIL PREFER becomes the ref's preferred id (Resolution,
;;;;   step 2), in place of an earlier one, and NIL leaves the ref as it is.
;;;;   BUILDER is a SCORE-BUILDER, else TYPE-ERROR. DRAFT-REF-KEY and
;;;;   DRAFT-REF-PREFER read a ref's key and preferred id.
;;;;
;;;; Drafts. A draft is an element tree in which refs stand for ids. Elements of
;;;; a draft are ordinary elements, built with the usual constructors:
;;;;   * an element CARRIES a ref when its ID is that ref. Any element may: every
;;;;     constructor's :ID takes NIL, an id string or a DRAFT-REF;
;;;;   * a tie's END and a spanner's START and END may be a ref (MAKE-TIE and
;;;;     MAKE-SPANNER take an id string or a DRAFT-REF there): they REFER to the
;;;;     element that carries it.
;;;; So a note tied to a later note is (make-tie :end (builder-ref b :next)) on
;;;; the first, and the second is (make-note-event :id (builder-ref b :next) ...),
;;;; built in either order; a slur is (make-spanner :kind :slur :start r1 :end r2).
;;;; Carriers and references may sit anywhere in the tree: other voices, other
;;;; parts, before or after one another.
;;;;
;;;; Resolution. MAKE-SCORE (and so COPY-SCORE) takes drafts. A ref is matched
;;;; to its carrier by identity (EQ), never by its key. Over the elements in
;;;; document order (ids.lisp; the chord-symbol track sorted first, as always):
;;;;   1. Carriers. A ref carried by two or more elements signals
;;;;      UNRESOLVED-REFERENCE (KEY the ref's key, REASON "carried by more than
;;;;      one element"), with no restart.
;;;;   2. Preferred ids. A carrier whose ref has a preferred id P takes P as its
;;;;      id when no element of the tree is given P (a string ID) and no carrier
;;;;      before it in document order took P. Otherwise it takes none: the first
;;;;      taker wins, and a given id always wins.
;;;;   3. The counter. A taken preferred id counts as a given id: the counter
;;;;      starts at the largest of :ID-COUNTER and the serials of the given ids
;;;;      and of the taken preferred ids (references still don't count).
;;;;   4. Minting. A carrier that took no id is minted like an element whose ID
;;;;      is NIL, in its place in document order: PREFIX-(counter + 1), and so on.
;;;;   5. References. Each ref a tie or spanner refers to becomes the id its
;;;;      carrier got. For a ref that no element carries, in document order of
;;;;      the referring tie or spanner, MAKE-SCORE signals UNRESOLVED-REFERENCE
;;;;      (KEY the ref's key, REASON "no element carries it") inside a USE-VALUE
;;;;      restart: its value, an id string (else TYPE-ERROR), is stored instead.
;;;; So MAKE-SCORE of a draft gives the score a caller would get by building
;;;; twice: once with each carrier's ID set to the preferred id step 2 lets it
;;;; take, or NIL, and every reference set to an id-less placeholder such as
;;;; "zz", to read off the minted ids; then again with every reference set to
;;;; the id its target got. The two builds and the draft mint the same ids in
;;;; the same order. A score never holds a ref.
;;;;
;;;; Sharing (score.lisp). An element that has its id and refers to no ref, with
;;;; everything inside it the same, is stored as the same (EQ) object. An
;;;; element that carries or refers to a ref, or holds one that does, is rebuilt
;;;; with its other slots unchanged, like an element that gets a minted id.
;;;;
;;;; Reading the ids back. When MAKE-SCORE has built its score, it records in
;;;; each carried ref's builder the id its carrier got; a MAKE-SCORE that
;;;; signals and is not continued records nothing.
;;;; BUILDER-ID builder key &key (errorp t) → the id the carrier of KEY's ref got
;;;;   in the latest MAKE-SCORE that carried it. For a key with no ref in
;;;;   BUILDER, or one whose ref no MAKE-SCORE has carried: NIL when ERRORP is
;;;;   false, else UNRESOLVED-REFERENCE (KEY the key, REASON "not carried in a
;;;;   built score") inside a USE-VALUE restart whose value is returned.
;;;; So a reader that needs the final ids (to report guesses by id, say) asks the
;;;; builder instead of walking the score.
;;;;
;;;; Refs are for building. Everything else takes resolved elements: APPLY-EDIT
;;;; and INVERT-EDIT signal INVALID-EDIT (REASON "draft reference") for an
;;;; operation whose elements hold a ref, before its other preconditions
;;;; (edits.lisp, step 1), and ELEMENT-TO-SEXP writes a ref as the ref itself,
;;;; so a draft's form is not printable data. CHECK-SCORE, views and SCORE-EQUAL
;;;; only ever see scores, which hold none.
;;;;
;;;; Why a builder. A tie's END holding the target element object itself would
;;;; need the target built before the tie, which is backwards for ties (they
;;;; point forward in time), and identity breaks when a draft shares an object.
;;;; A symbolic (:ref key) would need a draft-only KEY slot on every element.
;;;; Refs need neither: they sit in the slots ids already use, carry a type of
;;;; their own, and the builder also returns the minted ids, which both kinds of
;;;; reader need. There is no WITH- macro: (let ((b (make-score-builder))) ...)
;;;; is all it would do.

(in-package #:score-protocol)

(defclass score-builder ()
  ()
  (:documentation "Hands out DRAFT-REFs and records the ids MAKE-SCORE gives their
carriers (file header). Build one with MAKE-SCORE-BUILDER."))

(defun make-score-builder ()
  "A fresh SCORE-BUILDER (file header)."
  (make-instance 'score-builder))

(defclass draft-ref ()
  ((key :initarg :key :reader draft-ref-key
        :documentation "The key BUILDER-REF was given.")
   (prefer :initarg :prefer :initform nil :reader draft-ref-prefer
           :documentation "NIL or the preferred id (file header, step 2)."))
  (:documentation "A placeholder for the id of the element that carries it, in a
draft (file header). Get one with BUILDER-REF."))

(defun %sc3-pending (name)
  "Signal that NAME belongs to the SC3 contract and is not implemented yet."
  (error "score-protocol SC3 pending: ~A" name))

(defun builder-ref (builder key &key prefer)
  "The DRAFT-REF of KEY in BUILDER, made on first use (file header)."
  (declare (ignore builder key prefer))
  (%sc3-pending 'builder-ref))

(defun builder-id (builder key &key (errorp t))
  "The id the carrier of KEY's ref got in the latest MAKE-SCORE (file header)."
  (declare (ignore builder key errorp))
  (%sc3-pending 'builder-id))
