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
;;;; slots unchanged.
;;;;
;;;; COPY-SCORE score &key metadata measures parts chord-symbols spanners is
;;;; MAKE-SCORE with each omitted argument taken from SCORE, and :ID-COUNTER
;;;; (score-id-counter score). Unchanged parts of the score are shared.
;;;;
;;;; Lookups:
;;;;   SCORE-ELEMENTS score: a fresh list of every element, in document order.
;;;;   FIND-ELEMENT score id &key (errorp t): the element with that id, the first
;;;;     in document order when several share it. For an unknown id, NIL when
;;;;     ERRORP is false, else UNKNOWN-ELEMENT (ID = the id) inside a USE-VALUE
;;;;     restart whose value is returned.
;;;;   ELEMENT-PARENT score id: the element above it in the tree: a staff's or
;;;;     voice's part, an event's voice, a chord note's or lyric's event. NIL for
;;;;     measures, parts, chord-symbol anchors and spanners.
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

(defun make-score (&key metadata measures parts chord-symbols spanners (id-counter 0))
  "A SCORE (file header): ids minted, chord symbols sorted, elements indexed."
  (declare (ignorable metadata measures parts chord-symbols spanners id-counter))
  (%sc0-pending 'make-score))

(defun copy-score (score &key (metadata nil metadata-p) (measures nil measures-p)
                              (parts nil parts-p) (chord-symbols nil chord-symbols-p)
                              (spanners nil spanners-p))
  "MAKE-SCORE with each omitted argument taken from SCORE, and SCORE's id counter."
  (declare (ignorable score metadata metadata-p measures measures-p parts parts-p
                      chord-symbols chord-symbols-p spanners spanners-p))
  (%sc0-pending 'copy-score))

(defun score-elements (score)
  "A fresh list of every element of SCORE, in document order (ids.lisp)."
  (declare (ignorable score))
  (%sc0-pending 'score-elements))

(defgeneric find-element (score id &key errorp)
  (:documentation "The element of SCORE with ID (file header)."))

(defmethod find-element ((score score) id &key (errorp t))
  (declare (ignorable id errorp))
  (%sc0-pending 'find-element))

(defgeneric element-parent (score id)
  (:documentation "The element above the element with ID, or NIL (file header)."))

(defmethod element-parent ((score score) id)
  (declare (ignorable id))
  (%sc0-pending 'element-parent))

(defgeneric element-position (score id)
  (:documentation "The (bar . offset) of the element with ID, or NIL (measure-map.lisp)."))

(defmethod element-position ((score score) id)
  (declare (ignorable id))
  (%sc0-pending 'element-position))

(defun find-slice (score slice-id &key (errorp t))
  "(values measure element) for SLICE-ID (ids.lisp)."
  (declare (ignorable score slice-id errorp))
  (%sc0-pending 'find-slice))

(defun uncertain-elements (score &key (below 0.8))
  "The elements of SCORE with a CONFIDENCE below BELOW, in document order."
  (declare (ignorable score below))
  (%sc0-pending 'uncertain-elements))
