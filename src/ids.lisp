;;;; SC0 element ids: syntax, minting, document order, stability, slice ids.
;;;;
;;;; Every element (an instance of ELEMENT, elements.lisp: everything a user can
;;;; select or edit, and everything an engraver draws as an object of its own)
;;;; has an ID, a string unique in its score. The scheme is self-contained: ids
;;;; are minted by this library from the score alone (no clock, no randomness,
;;;; no global state, nothing from a file format or a renderer), and they are
;;;; data in the score. They are persistent and not positional: an element's
;;;; place in the score never enters its id, so ids survive edits and
;;;; re-barring. Ids are opaque: code never parses one to learn about its
;;;; element; it asks FIND-ELEMENT.
;;;;
;;;; Syntax (VALID-ID-P): a non-empty string of ASCII characters whose first
;;;; character is a letter (A-Z, a-z) and whose others are letters, digits, "-"
;;;; or "_". So an id is an XML NCName (an xs:ID, as MusicXML 4.0 id and MEI
;;;; xml:id attributes are), with no colon, space or "." (slice ids use the dot).
;;;; Constructors signal TYPE-ERROR for an ID that is neither NIL, a valid id
;;;; nor a DRAFT-REF (builder.lisp, SC3: a placeholder MAKE-SCORE replaces).
;;;;
;;;; Minted ids are a PREFIX, "-", and a SERIAL: an integer >= 1 written in base
;;;; 36 with the digits 0-9 a-z, lower case, no leading zero. So serial 12 in an
;;;; event is "e-c", and serial 40 is "e-14". The prefix comes from the
;;;; element's class through +ID-PREFIXES+:
;;;;   m measure     p part        st staff         v voice        e event
;;;;   n chord note  ly lyric      dy dynamic       fe fermata     br breath mark
;;;;   ar articulation             ti tie           tm tempo mark
;;;;   rh rehearsal mark           jm jump mark     en ending
;;;;   h chord-symbol anchor       sp spanner
;;;; Rest, note and chord events all use "e", so an event that changes kind
;;;; keeps a truthful id. Every mark has a kind of its own, so a fermata's id
;;;; never looks like its note's. The hyphen keeps minted ids apart from
;;;; engravers' generated ids, which are bare letters and digits. A string HAS
;;;; SERIAL k when it is one of those prefixes, "-", and k written that way,
;;;; whatever element carries it. Other valid ids have no serial: "P1", "e12",
;;;; "e-0c", "E-C", "x-9".
;;;;
;;;; The id counter. A score records SCORE-ID-COUNTER, the highest serial minted
;;;; or seen in it. MAKE-SCORE sets the counter to the largest of its :ID-COUNTER
;;;; argument (default 0) and every serial among the ids of the elements it is
;;;; given (references don't count; in a draft, a preferred id a carrier takes
;;;; counts as given, builder.lisp). It then visits the elements in document
;;;; order, and gives each one whose ID is NIL (in a draft, or a DRAFT-REF that
;;;; took no preferred id) the id PREFIX-(counter + 1), incrementing the counter.
;;;; Minting is the only thing that consumes serials, and a minted id never
;;;; equals an id that was given.
;;;;
;;;; Document order is the pre-order walk of the element tree: an element, then
;;;; its children, each child followed by its own children. Children come in
;;;; the order of the keys of the element's canonical form (sexp.lisp), and the
;;;; members of a key that holds several in their stored order:
;;;;   score        measures, parts, chord-symbol anchors (track order), spanners
;;;;   measure      ending, jump marks, rehearsal mark, tempo marks
;;;;   part         staves, voices
;;;;   voice        events, voice measure by voice measure
;;;;   note event   tie, articulations, fermata, breath mark, dynamic, lyrics
;;;;   chord event  chord notes (each followed by its tie), articulations,
;;;;                fermata, breath mark, dynamic, lyrics
;;;;   rest event   fermata, dynamic, lyrics
;;;;   chord note   tie
;;;; Lyrics, articulations, jump marks and tempo marks are kept sorted
;;;; (elements.lisp, measure-map.lisp). SCORE-ELEMENTS lists the elements in this
;;;; order. Minting is therefore deterministic: equal input gets equal ids, and a
;;;; score built from elements with no ids and no :ID-COUNTER numbers them 1..N
;;;; in document order (m-1, tm-2, m-3, p-4, ..., e-a, fe-b, ...).
;;;;
;;;; Stability. An element keeps its id for as long as it exists.
;;;;   * MAKE-SCORE and COPY-SCORE keep every id they are given. COPY-SCORE
;;;;     passes the counter on, so an element added later never gets the serial
;;;;     of one that was removed: a serial is used at most once in the lineage of
;;;;     a score (the chain of scores built from it).
;;;;   * Edits (SC1) keep the id of every element they change in place (a new
;;;;     pitch, duration, lyric text, dynamic value, provenance...). An edit that
;;;;     splits an element (a duration that overflows the barline becomes tied
;;;;     notes) keeps the id on the first piece in time, with its marks, and mints
;;;;     the others and the new ties; one that merges elements keeps the id of the
;;;;     first. Re-barring keeps the ids of the events it moves. An element that is
;;;;     deleted and then inserted again by a new edit is a new element with a new
;;;;     id; only INVERT-EDIT brings back the ids its inverse removed.
;;;;   * Views (SC1) keep the ids of the elements they carry over. An element a
;;;;     view copies more than once (UNFOLD) keeps its id in the first copy; the
;;;;     others get minted ids, and the view's id map gives each one its source id.
;;;;   * Serialization keeps ids verbatim. SCORE-TO-SEXP writes every id and the
;;;;     counter; SEXP-TO-SCORE restores both, so the copy mints the same next id
;;;;     as the original. A format that carries ids (MusicXML, MEI) writes and
;;;;     reads them verbatim. A reader of a file with no ids mints them in
;;;;     document order like MAKE-SCORE, so the same file always reads with the
;;;;     same ids. A format that can't carry them (MIDI) warns LOSSY-CONVERSION
;;;;     on write, and its importer mints fresh ones.
;;;;
;;;; Slice ids. A measure spans every part, so one part's, staff's or voice's
;;;; share of a measure is a separate kind (a part's <measure> in MusicXML; a
;;;; <staff> or <layer> inside an MEI <measure>). Slices aren't elements: they
;;;; hold nothing of their own. Their ids are derived from two persistent ids:
;;;; (slice-id measure-id element-id) is MEASURE-ID "." ELEMENT-ID, so
;;;; "m-3.p-4"; it signals TYPE-ERROR unless both are valid ids. A slice id is an
;;;; NCName that no element can have, and no two pairs give the same one, since
;;;; element ids never contain ".". FIND-SLICE score slice-id → (values measure
;;;; element): the MEASURE-INFO and the PART, STAFF or VOICE it names. For a
;;;; string that isn't the slice id of a measure and a part, staff or voice of
;;;; the score, FIND-SLICE returns NIL when :ERRORP is false, else signals
;;;; UNKNOWN-ELEMENT (ID = the string) inside a USE-VALUE restart whose value it
;;;; returns.
;;;;
;;;; References. A tie's END and a spanner's START and END hold ids. An element
;;;; that is referenced either gets its id when it is constructed (any unique
;;;; valid string), or carries a DRAFT-REF that the referring tie or spanner
;;;; names too; MAKE-SCORE then mints or settles its id and puts it in every
;;;; reference, in the same call (builder.lisp, SC3). A score's references are
;;;; always id strings. Duplicate ids are a CHECK-SCORE issue (:DUPLICATE-ID);
;;;; FIND-ELEMENT then finds the first carrier in document order.

(in-package #:score-protocol)

(defparameter +id-prefixes+
  '((measure-info . "m") (part . "p") (staff . "st") (voice . "v") (event . "e")
    (chord-note . "n") (lyric . "ly") (dynamic-mark . "dy") (fermata . "fe")
    (breath-mark . "br") (articulation . "ar") (tie . "ti") (tempo-mark . "tm")
    (rehearsal-mark . "rh") (jump-mark . "jm") (ending . "en")
    (chord-symbol-anchor . "h") (spanner . "sp"))
  "Element class → the prefix of its minted ids (before the \"-\"); an element
takes the first row whose class it is an instance of. These are also the only
prefixes that give a string a serial. Data.")

(defparameter +serial-digits+ "0123456789abcdefghijklmnopqrstuvwxyz"
  "The base-36 digits of a serial, in value order: lower case only. Data.")

;;; ASCII by char code: ALPHA-CHAR-P and DIGIT-CHAR-P accept non-ASCII letters
;;; and digits on some implementations.

(defun %ascii-letter-p (char)
  (let ((code (char-code char)))
    (or (<= 65 code 90) (<= 97 code 122))))

(defun %ascii-digit-p (char)
  (<= 48 (char-code char) 57))

(defun %id-char-p (char)
  (or (%ascii-letter-p char) (%ascii-digit-p char) (char= char #\-) (char= char #\_)))

(defun valid-id-p (object)
  "True when OBJECT is a string in the id syntax of the file header."
  (and (stringp object)
       (plusp (length object))
       (%ascii-letter-p (char object 0))
       (every #'%id-char-p object)
       t))

(deftype %id ()
  "An id string (VALID-ID-P)."
  '(satisfies valid-id-p))

(defun %id-serial (id)
  "The serial ID has (file header): an integer >= 1, or NIL when ID is not a
known prefix, \"-\" and a canonical base-36 numeral."
  (let ((dash (and (stringp id) (position #\- id))))
    (when (and dash (rassoc (subseq id 0 dash) +id-prefixes+ :test #'string=))
      (let ((start (1+ dash)))
        ;; Check the digits first: PARSE-INTEGER would accept upper case and a sign.
        (when (and (< start (length id))
                   (char/= #\0 (char id start))
                   (loop for i from start below (length id)
                         always (find (char id i) +serial-digits+)))
          (parse-integer id :start start :radix 36))))))

(defun %id-prefix (element)
  "The prefix of ELEMENT's minted ids: the first +ID-PREFIXES+ row it is of."
  (cdr (find-if (lambda (row) (typep element (car row))) +id-prefixes+)))

(defun %minted-id (prefix serial)
  "PREFIX, \"-\" and SERIAL in lower-case base 36: (%minted-id \"e\" 40) => \"e-14\"."
  (format nil "~A-~(~36R~)" prefix serial))

(defun slice-id (measure-id element-id)
  "The id of ELEMENT-ID's share of the measure MEASURE-ID: \"m-3.p-4\"."
  (check-type measure-id %id "an id string")
  (check-type element-id %id "an id string")
  (concatenate 'string measure-id "." element-id))
