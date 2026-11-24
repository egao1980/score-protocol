;;;; SC0 the canonical s-expression form, and model equality.
;;;;
;;;; SCORE-TO-SEXP score returns a form built only from conses, keywords, T,
;;;; NIL, strings, integers, ratios and floats, so it prints with PRIN1 under
;;;; WITH-STANDARD-IO-SYNTAX and reads back with *READ-EVAL* NIL. It is the
;;;; reference serialization: it writes every id and the id counter.
;;;; SEXP-TO-SCORE is its inverse: (sexp-to-score (score-to-sexp s)) is
;;;; SCORE-EQUAL to s with the same SCORE-ID-COUNTER, and for a form f that
;;;; SCORE-TO-SEXP returned, (score-to-sexp (sexp-to-score f)) is EQUAL to f.
;;;; ELEMENT-TO-SEXP and SEXP-TO-ELEMENT do the same for one element and
;;;; everything inside it.
;;;;
;;;; SCORE-EQUAL a b is model equality: true when (score-to-sexp a) and
;;;; (score-to-sexp b) are EQUAL once their :ID-COUNTER entries are removed.
;;;; Content, ids, provenance and confidence all count; the counter is
;;;; bookkeeping and doesn't.
;;;;
;;;; Grammar. A form is its kind keyword followed by a plist. A canonical form
;;;; writes the keys in the order below and leaves out every key whose value is
;;;; its default: NIL for booleans and optional values, () for lists, or the
;;;; default shown as "= x". Keys marked "always" are written whatever their
;;;; value. :ID comes first, left out only for an element with no id;
;;;; :PROVENANCE and then :CONFIDENCE come last, in every element form.
;;;;
;;;;   (:score :metadata PLIST :id-counter N (always) :measures (MEASURE...)
;;;;           (always) :parts (PART...) (always) :chord-symbols (ANCHOR...)
;;;;           :spanners (SPANNER...))
;;;;   (:measure :id :number STRING :time METER :key KEY :pickup T :length R
;;;;             :barline K (= :regular) :repeat-start T :repeat-end N
;;;;             :ending ENDING :jump (JUMP...) :rehearsal REHEARSAL
;;;;             :tempo (TEMPO-MARK...))
;;;;   (:ending :id :passes (N...) (always) :measures N (= 1))
;;;;   (:jump :id :kind K (always))
;;;;   (:rehearsal :id :text STRING (always))
;;;;   (:tempo-mark :id :offset R (= 0) :bpm REAL :beat-unit R :text STRING)
;;;;                ; :bpm and :beat-unit are the TEMPO's, both written when it
;;;;                ; isn't NIL
;;;;   (:part :id :name STRING :abbreviation STRING :staves (STAFF...) (always)
;;;;          :voices (VOICE...) (always))
;;;;   (:staff :id :clef K (= :treble))
;;;;   (:voice :id :name STRING :staff N (= 1) :stem K
;;;;           :measures ((EVENT...)...) (always))
;;;;   (:rest :id :duration R (always) :tuplet R :measure-rest T :hidden T
;;;;          :fermata FERMATA :dynamic DYNAMIC :lyrics (LYRIC...))
;;;;   (:note :id :pitch PITCH (always) :duration R (always) :tuplet R :grace K
;;;;          :accidental K (= :auto) :tie TIE :articulations (ARTICULATION...)
;;;;          :fermata FERMATA :breath-mark BREATH-MARK :dynamic DYNAMIC
;;;;          :lyrics (LYRIC...))
;;;;   (:chord :id :notes (CHORD-NOTE...) (always) :duration R (always) :tuplet R
;;;;           :grace K :articulations (ARTICULATION...) :fermata FERMATA
;;;;           :breath-mark BREATH-MARK :dynamic DYNAMIC :lyrics (LYRIC...))
;;;;   (:chord-note :id :pitch PITCH (always) :accidental K (= :auto) :tie TIE)
;;;;   (:tie :id :end ID (always))
;;;;   (:articulation :id :kind K (always))
;;;;   (:fermata :id :shape K (= :normal))
;;;;   (:breath-mark :id)
;;;;   (:dynamic :id :value K (always))
;;;;   (:lyric :id :verse N (= 1) :text STRING (always) :syllabic K (= :single)
;;;;           :extender T)
;;;;   (:chord-symbol :id :bar N (always) :offset R (always) :symbol SYMBOL (always))
;;;;   (:spanner :id :kind K (always) :start ID (always) :end ID (always))
;;;; EVENT is a :rest, :note or :chord form; the other upper-case names are the
;;;; forms of those kinds. Values that aren't elements are plists with no kind
;;;; keyword, keys in this order, defaults left out:
;;;;   PLIST       SCORE-METADATA as it is
;;;;   PROVENANCE  (:source K (always) :backend STRING :page N :bbox (X Y W H)
;;;;               :time-range (START END))
;;;;   SYMBOL      a music-theory CHORD-SYMBOL slot by slot in its slot order:
;;;;               (:root PC :quality K :extensions (N...) :alterations ((D . A)...)
;;;;               :suspension N :added ((D . A)...) :omitted (N...) :bass PC
;;;;               :no-chord-p T :text STRING :dialect K), so N.C. is
;;;;               (:no-chord-p t)
;;;; Text values use music-theory's printers and parsers: PITCH is
;;;; (pitch-name p) ("F#4"), PC (pitch-class-string pc) ("Bb"), METER
;;;; (meter-string m) ("6/8"), KEY (key-name k) ("G major"). R is a rational, N
;;;; an integer, K a keyword, ID an id string; T is the boolean true.
;;;;
;;;; Reading. SEXP-TO-SCORE and SEXP-TO-ELEMENT take keys in any order, and an
;;;; omitted key takes its default (for a required slot such as :pitch that
;;;; makes the constructor signal TYPE-ERROR). They build with the constructors
;;;; and MAKE-SCORE, so the constructors' normalisations apply, elements without
;;;; :id get minted ids, and :id-counter is MAKE-SCORE's argument. They signal
;;;; SCORE-FORMAT-ERROR with FORMAT :SEXP and POSITION = the offending sub-form
;;;; when a form isn't a list of a kind keyword and a proper plist (for
;;;; SEXP-TO-SCORE the top form must be :score; for SEXP-TO-ELEMENT it must be an
;;;; element kind; nested forms must be of the kind their key expects), or when a
;;;; plist has an unknown key or a key twice. Errors from the constructors
;;;; (TYPE-ERROR) and from music-theory's parsers (INVALID-PITCH, INVALID-METER,
;;;; INVALID-KEY) are not wrapped: they reach the caller with their restarts.

(in-package #:score-protocol)

(defun score-to-sexp (score)
  "The canonical form of SCORE (file header)."
  (declare (ignorable score))
  (%sc0-pending 'score-to-sexp))

(defun sexp-to-score (form)
  "The SCORE that FORM describes (file header)."
  (declare (ignorable form))
  (%sc0-pending 'sexp-to-score))

(defun element-to-sexp (element)
  "The canonical form of ELEMENT and everything inside it (file header)."
  (declare (ignorable element))
  (%sc0-pending 'element-to-sexp))

(defun sexp-to-element (form)
  "The element that FORM describes (file header)."
  (declare (ignorable form))
  (%sc0-pending 'sexp-to-element))

(defun score-equal (a b)
  "Model equality: equal canonical forms, ignoring the id counter."
  (declare (ignorable a b))
  (%sc0-pending 'score-equal))
