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
;;;;               :time-range (START END) :origin ORIGIN)
;;;;   ORIGIN      (0.4.0) (:id ID (always) :value SYMBOL): the ORIGIN of a
;;;;               provenance (elements.lisp); :value left out when it is NIL
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
;;;; An ORIGIN plist is read like the others (0.4.0): a key other than :id and
;;;; :value, or a key twice, is a SCORE-FORMAT-ERROR whose POSITION is the
;;;; ORIGIN plist; a missing or invalid :id is MAKE-ORIGIN's TYPE-ERROR. An
;;;; origin is data: reading one mints nothing and checks nothing against the
;;;; score's ids.

(in-package #:score-protocol)

;;; Element forms come from the grammar rows in score.lisp; the plists below
;;; are the values that aren't elements. Keys are in canonical order.

(defparameter +score-keys+
  '(:metadata :id-counter :measures :parts :chord-symbols :spanners)
  "The keys of a (:score ...) form, in canonical order. Data.")

(defparameter +provenance-fields+
  '((:source provenance-source) (:backend provenance-backend) (:page provenance-page)
    (:bbox provenance-bbox) (:time-range provenance-time-range)
    (:origin provenance-origin :origin))
  "PROVENANCE plist keys, readers and codecs (NIL: the value as stored; :ORIGIN:
an ORIGIN plist, 0.4.0), in canonical order; :SOURCE is always written. Data.")

(defparameter +chord-symbol-fields+
  '((:root music-theory:chord-symbol-root :pitch-class)
    (:quality music-theory:chord-symbol-quality :value)
    (:extensions music-theory:chord-symbol-extensions :value)
    (:alterations music-theory:chord-symbol-alterations :value)
    (:suspension music-theory:chord-symbol-suspension :value)
    (:added music-theory:chord-symbol-added :value)
    (:omitted music-theory:chord-symbol-omitted :value)
    (:bass music-theory:chord-symbol-bass :pitch-class)
    (:no-chord-p music-theory:chord-symbol-no-chord-p :value)
    (:text music-theory:chord-symbol-text :value)
    (:dialect music-theory:chord-symbol-dialect :value))
  "CHORD-SYMBOL plist keys, readers and codecs, in music-theory's slot order. Data.")

;;; Writing ------------------------------------------------------------------------

(defun %origin-to-sexp (origin)
  "The canonical ORIGIN plist of ORIGIN (file header, 0.4.0)."
  (declare (ignore origin))
  (%sc4-pending '%origin-to-sexp))

(defun %provenance-to-sexp (provenance)
  (cons :source
        (cons (provenance-source provenance)
              (loop for (key reader codec) in (rest +provenance-fields+)
                    for value = (funcall reader provenance)
                    when value nconc (list key (if (eq codec :origin)
                                                   (%origin-to-sexp value)
                                                   (copy-tree value)))))))

(defun %chord-symbol-to-sexp (symbol)
  (loop for (key reader codec) in +chord-symbol-fields+
        for value = (funcall reader symbol)
        when value
          nconc (list key (if (eq codec :pitch-class)
                              (music-theory:pitch-class-string value)
                              (copy-tree value)))))

(defun %encode (codec value)
  "VALUE (not NIL unless the key is always written) in its canonical form."
  (if (consp codec)
      (ecase (car codec)
        (:form (element-to-sexp value))
        (:forms (mapcar #'element-to-sexp value))
        (:voice-measures
         (mapcar (lambda (events) (mapcar #'element-to-sexp (fset:convert 'list events)))
                 (fset:convert 'list value))))
      (ecase codec
        (:value (copy-tree value))
        (:pitch (music-theory:pitch-name value))
        (:meter (music-theory:meter-string value))
        (:key (music-theory:key-name value))
        (:provenance (%provenance-to-sexp value))
        (:chord-symbol (%chord-symbol-to-sexp value)))))

(defun %encode-field (field element)
  "The keys and values FIELD of ELEMENT contributes to its canonical form."
  (let ((value (%field-value field element)))
    (case (%field-codec field)
      (:tempo
       (and value (list :bpm (music-theory:tempo-bpm value)
                        :beat-unit (music-theory:tempo-beat-unit value))))
      (:position
       (list :bar (car value) :offset (cdr value)))
      (t
       (unless (and (not (%field-always field)) (eql value (%field-default field)))
         (list (%field-key field) (%encode (%field-codec field) value)))))))

(defun element-to-sexp (element)
  "The canonical form of ELEMENT and everything inside it (file header)."
  (check-type element element)
  (let ((row (%element-row element)))
    (cons (%form-row-kind row)
          (loop for field in (%form-row-fields row)
                nconc (%encode-field field element)))))

(defun score-to-sexp (score)
  "The canonical form of SCORE (file header)."
  (check-type score score)
  (flet ((forms (seq) (mapcar #'element-to-sexp (fset:convert 'list seq))))
    (let ((metadata (score-metadata score))
          (anchors (forms (score-chord-symbols score)))
          (spanners (forms (score-spanners score))))
      (append (list :score)
              (and metadata (list :metadata (copy-list metadata)))
              (list :id-counter (score-id-counter score)
                    :measures (forms (score-measure-map score))
                    :parts (forms (score-parts score)))
              (and anchors (list :chord-symbols anchors))
              (and spanners (list :spanners spanners))))))

;;; Reading ------------------------------------------------------------------------
;;; Top-down: a form's kind and plist are checked before anything inside it is
;;; read. No handlers: errors from the constructors and from music-theory's
;;; parsers reach the caller with their restarts.

(defun %format-error (position reason)
  (error 'score-format-error :format :sexp :position position :reason reason))

(defun %proper-list-p (object)
  (loop for tail = object then (cdr tail)
        while (consp tail)
        finally (return (null tail))))

(defun %check-plist (plist allowed whole)
  "PLIST when it is a proper plist of distinct keys from ALLOWED, else a
SCORE-FORMAT-ERROR at WHOLE."
  (loop with seen = '()
        for tail = plist then (cddr tail)
        until (null tail)
        do (unless (and (consp tail) (consp (cdr tail)) (keywordp (car tail)))
             (%format-error whole "not a property list"))
           (unless (member (car tail) allowed)
             (%format-error whole (format nil "unknown key ~S" (car tail))))
           (when (member (car tail) seen)
             (%format-error whole (format nil "key ~S given twice" (car tail))))
           (push (car tail) seen))
  plist)

(defun %present-args (plist keys decode)
  "Keyword arguments for the KEYS present in PLIST with a value that isn't
NIL, each value passed through DECODE (a function of the key and the value)."
  (loop for key in keys
        for value = (getf plist key)
        when value nconc (list key (funcall decode key value))))

(defun %sexp-to-origin (plist)
  "The ORIGIN the ORIGIN plist PLIST describes (file header, 0.4.0)."
  (declare (ignore plist))
  (%sc4-pending '%sexp-to-origin))

(defun %sexp-to-provenance (plist)
  (let ((keys (mapcar #'first +provenance-fields+)))
    (%check-plist plist keys plist)
    (apply #'make-provenance
           (%present-args plist keys (lambda (key value)
                                       (if (eq (third (assoc key +provenance-fields+)) :origin)
                                           (%sexp-to-origin value)
                                           (copy-tree value)))))))

(defun %sexp-to-chord-symbol (plist)
  (let ((keys (mapcar #'first +chord-symbol-fields+)))
    (%check-plist plist keys plist)
    (apply #'music-theory:make-chord-symbol
           (%present-args plist keys
                          (lambda (key value)
                            (if (eq :pitch-class (third (assoc key +chord-symbol-fields+)))
                                (music-theory:parse-pitch-class value)
                                (copy-tree value)))))))

(defun %row-keys (row)
  "Every key a form of ROW may hold."
  (loop for field in (%form-row-fields row)
        for key = (%field-key field)
        append (if (listp key) (copy-list key) (list key))))

(defun %read-forms (value kinds)
  "The elements of VALUE, a list of forms of KINDS."
  (unless (%proper-list-p value)
    (%format-error value "expected a list of forms"))
  (mapcar (lambda (form) (%read-element form kinds)) value))

(defun %decode (codec value)
  "The model value of the non-NIL form VALUE."
  (if (consp codec)
      (destructuring-bind (shape &rest kinds) codec
        (ecase shape
          (:form (%read-element value kinds))
          (:forms (%read-forms value kinds))
          (:voice-measures
           (unless (%proper-list-p value)
             (%format-error value "expected a list of voice measures"))
           (mapcar (lambda (events) (%read-forms events kinds)) value))))
      (ecase codec
        (:value (copy-tree value))
        (:pitch (music-theory:parse-pitch value))
        (:meter (music-theory:parse-meter value))
        (:key (music-theory:parse-key value))
        (:provenance (%sexp-to-provenance value))
        (:chord-symbol (%sexp-to-chord-symbol value)))))

(defun %decode-field (field plist)
  "The constructor arguments FIELD takes from the form PLIST: () when its keys
are absent or NIL, so the constructor's default applies."
  (let ((initarg (%field-initarg field)))
    (case (%field-codec field)
      (:tempo
       (let ((bpm (getf plist :bpm))
             (beat-unit (getf plist :beat-unit)))
         (and (or bpm beat-unit)
              (list initarg (apply #'music-theory:make-tempo
                                   (append (and bpm (list :bpm bpm))
                                           (and beat-unit (list :beat-unit beat-unit))))))))
      (:position
       (let ((bar (getf plist :bar))
             (offset (getf plist :offset)))
         (and (or bar offset)
              (list initarg (cons bar offset)))))
      (t
       (let ((value (getf plist (%field-key field))))
         (and value
              (list initarg (%decode (%field-codec field) value))))))))

(defun %read-element (form kinds)
  "The element FORM describes; FORM must be of one of KINDS."
  (unless (and (consp form) (member (car form) kinds))
    (%format-error form (format nil "expected a form of kind ~{~S~^ or ~}" kinds)))
  (let ((row (%kind-row (car form)))
        (plist (cdr form)))
    (%check-plist plist (%row-keys row) form)
    (apply (%form-row-constructor row)
           (loop for field in (%form-row-fields row)
                 nconc (%decode-field field plist)))))

(defun sexp-to-score (form)
  "The SCORE that FORM describes (file header)."
  (unless (and (consp form) (eq (car form) :score))
    (%format-error form "expected a :score form"))
  (let ((plist (cdr form)))
    (%check-plist plist +score-keys+ form)
    (apply #'make-score
           (%present-args plist +score-keys+
                          (lambda (key value)
                            (ecase key
                              (:metadata (copy-tree value))
                              (:id-counter value)
                              (:measures (%read-forms value '(:measure)))
                              (:parts (%read-forms value '(:part)))
                              (:chord-symbols (%read-forms value '(:chord-symbol)))
                              (:spanners (%read-forms value '(:spanner)))))))))

(defun sexp-to-element (form)
  "The element that FORM describes (file header)."
  (%read-element form (mapcar #'%form-row-kind +form-rows+)))

;;; Equality ------------------------------------------------------------------------

(defun %form-without-counter (form)
  (cons (car form)
        (loop for (key value) on (cdr form) by #'cddr
              unless (eq key :id-counter) nconc (list key value))))

(defun score-equal (a b)
  "Model equality: equal canonical forms, ignoring the id counter."
  (check-type a score)
  (check-type b score)
  (equal (%form-without-counter (score-to-sexp a))
         (%form-without-counter (score-to-sexp b))))
