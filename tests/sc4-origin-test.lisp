;;;; 0.4.0: origins, what a derived element replaced (score-protocol#11). Rules:
;;;; the Origins section of src/elements.lisp, the ORIGIN grammar row of
;;;; src/sexp.lisp, the origin paragraphs of src/edits.lisp and of TRANSPOSE in
;;;; src/edit-measures.lisp. Expected values were worked out from those headers
;;;; and checked against a separate reference implementation.

(in-package #:score-protocol/tests)

;;; The origin score: a lead sheet whose chord track a generator rewrote.
;;;   v1: a E4 h, b D4 h | c G4 w (an OMR correction of "n-7", confidence 1/2) | d C4 w
;;;   g1 C replacing h1 (C), g2 G/B replacing an element whose id is the note
;;;   b's (a record, not a reference), g3 Dm/F replacing h2 (F), g4 N.C.
;;;   replacing h3 (G7), g5 C generated with nothing before it (no origin).

(defparameter +origin-base+
  '(:score
    :id-counter 30
    :measures ((:measure :id "m1" :time "4/4" :key "C major")
               (:measure :id "m2")
               (:measure :id "m3" :barline :final))
    :parts ((:part :id "p1" :staves ((:staff :id "s1"))
             :voices ((:voice :id "v1"
                       :measures (((:note :id "a" :pitch "E4" :duration 1/2)
                                   (:note :id "b" :pitch "D4" :duration 1/2))
                                  ((:note :id "c" :pitch "G4" :duration 1
                                    :provenance (:source :omr :origin (:id "n-7"))
                                    :confidence 1/2))
                                  ((:note :id "d" :pitch "C4" :duration 1)))))))
    :chord-symbols ((:chord-symbol :id "g1" :bar 1 :offset 0 :symbol (:root "C" :quality :major)
                     :provenance (:source :engine :backend "a generator"
                                  :origin (:id "h1" :value (:root "C" :quality :major))))
                    (:chord-symbol :id "g2" :bar 1 :offset 1/2 :symbol (:root "G" :quality :major :bass "B")
                     :provenance (:source :engine :origin (:id "b" :value (:root "G" :quality :dominant-7))))
                    (:chord-symbol :id "g3" :bar 2 :offset 0 :symbol (:root "D" :quality :minor :bass "F")
                     :provenance (:source :engine :origin (:id "h2" :value (:root "F" :quality :major))))
                    (:chord-symbol :id "g4" :bar 2 :offset 1/2 :symbol (:no-chord-p t)
                     :provenance (:source :engine :origin (:id "h3" :value (:root "G" :quality :dominant-7))))
                    (:chord-symbol :id "g5" :bar 3 :offset 0 :symbol (:root "C" :quality :major)
                     :provenance (:source :engine))))
  "The origin score's canonical form (file header).")

(defvar *origin-base* nil)
(defun origin-base () (or *origin-base* (setf *origin-base* (sexp-to-score +origin-base+))))

(defun strip-origins (form)
  "A copy of FORM without any :ORIGIN entry of a provenance plist."
  (cond ((atom form) form)
        ((eq (car form) :source)
         (loop for (key value) on form by #'cddr
               unless (eq key :origin) nconc (list key value)))
        (t (cons (strip-origins (car form)) (strip-origins (cdr form))))))

(defun origin-form (element)
  "The :ORIGIN plist of ELEMENT's canonical form, or NIL."
  (getf (getf (cdr (element-to-sexp element)) :provenance) :origin))

(defun anchor-of (score id) (find-element score id))

(defun chord (text)
  "The chord symbol TEXT spells, with its root, quality and bass only (no TEXT or
DIALECT), as SEXP-TO-SCORE reads a symbol plist."
  (let ((c (parse-chord-symbol text)))
    (make-chord-symbol :root (chord-symbol-root c) :quality (chord-symbol-quality c)
                       :bass (chord-symbol-bass c))))

;;; Construction ------------------------------------------------------------------

(deftest origin-construction
  (let ((o (make-origin :id "h1" :value (chord "G7"))))
    (ok (origin-p o))
    (ok (equal "h1" (origin-id o)))
    (ok (equalp (chord "G7") (origin-value o)))
    (ok (null (origin-value (make-origin :id "e-12"))) "the value is optional")
    (let ((p (make-provenance :source :engine :origin o)))
      (ok (eq o (provenance-origin p)))
      (ok (null (provenance-origin (make-provenance :source :engine))) "NIL by default")
      (let ((anchor (make-chord-symbol-anchor :position '(1 . 0) :symbol (chord "G7") :provenance p)))
        (ok (eq o (element-origin anchor)) "ELEMENT-ORIGIN reads the provenance's")))
    (ok (null (element-origin (make-chord-symbol-anchor :position '(1 . 0) :symbol (chord "C"))))
        "no provenance: no origin")
    (ok (null (element-origin (make-note-event :pitch (parse-pitch "C4") :duration 1/4
                                               :provenance (make-provenance :source :omr))))
        "a provenance without an origin")))

(defvar *not-origins* (list "h1" (list :id "h1"))
  "Values that are no ORIGIN, read at run time (a constant would be a compile-time
type conflict).")

(deftest-parametrize origin-type-errors
    ((label thunk)
     ("no id" (lambda () (make-origin :value (parse-chord-symbol "C"))))
     ("an empty id" (lambda () (make-origin :id "")))
     ("an id with a dot" (lambda () (make-origin :id "e.1")))
     ("an id starting with a digit" (lambda () (make-origin :id "1x")))
     ("a number for an id" (lambda () (make-origin :id 42)))
     ("a draft ref for an id" (lambda () (make-origin :id (builder-ref (make-score-builder) :x))))
     ("a string value" (lambda () (make-origin :id "h1" :value "G7")))
     ("a pitch value" (lambda () (make-origin :id "h1" :value (parse-pitch "C4"))))
     ("a provenance with a non-origin" (lambda () (make-provenance :source :engine :origin (first *not-origins*))))
     ("a provenance with an origin plist" (lambda () (make-provenance :source :engine :origin (second *not-origins*)))))
  (ok (signals (funcall thunk) 'type-error) label))

(deftest-parametrize origin-printing
    ((label origin text)
     ("a chord-symbol value" (make-origin :id "h-3" :value (parse-chord-symbol "G7")) "#<ORIGIN h-3 G7>")
     ("a slash chord" (make-origin :id "h1" :value (parse-chord-symbol "G/B")) "#<ORIGIN h1 G/B>")
     ("N.C." (make-origin :id "h1" :value (make-chord-symbol :no-chord-p t)) "#<ORIGIN h1 N.C.>")
     ("no value" (make-origin :id "e-12") "#<ORIGIN e-12 ->"))
  (ok (equal text (princ-to-string origin)) label)
  (ok (equal text (prin1-to-string origin)) (format nil "~A, PRIN1" label)))

(deftest a-provenance-with-an-origin-prints
  (let ((text (prin1-to-string (make-provenance :source :engine
                                                :origin (make-origin :id "h1" :value (chord "C"))))))
    (ok (search "#<ORIGIN h1 C>" text) "the provenance's printed form shows its origin")))

;;; The canonical form ------------------------------------------------------------

(deftest-parametrize origin-element-forms
    ((label id form)
     ("an origin with a value, after the backend" "g1"
      '(:chord-symbol :id "g1" :bar 1 :offset 0 :symbol (:root "C" :quality :major)
        :provenance (:source :engine :backend "a generator"
                     :origin (:id "h1" :value (:root "C" :quality :major)))))
     ("an id that names a live element is kept as written" "g2"
      '(:chord-symbol :id "g2" :bar 1 :offset 1/2 :symbol (:root "G" :quality :major :bass "B")
        :provenance (:source :engine :origin (:id "b" :value (:root "G" :quality :dominant-7)))))
     ("an N.C. anchor replacing a chord" "g4"
      '(:chord-symbol :id "g4" :bar 2 :offset 1/2 :symbol (:no-chord-p t)
        :provenance (:source :engine :origin (:id "h3" :value (:root "G" :quality :dominant-7)))))
     ("no origin: none written" "g5"
      '(:chord-symbol :id "g5" :bar 3 :offset 0 :symbol (:root "C" :quality :major)
        :provenance (:source :engine)))
     ("an origin without a value, on a note" "c"
      '(:note :id "c" :pitch "G4" :duration 1 :provenance (:source :omr :origin (:id "n-7"))
        :confidence 1/2)))
  (ok (equal form (form-of (origin-base) id)) label))

(deftest an-n-c-value-is-written-as-n-c
  (let ((anchor (make-chord-symbol-anchor
                 :id "x1" :position '(1 . 0) :symbol (chord "C")
                 :provenance (make-provenance :source :engine
                                              :origin (make-origin :id "h9" :value (make-chord-symbol :no-chord-p t))))))
    (ok (equal '(:id "h9" :value (:no-chord-p t)) (origin-form anchor)))))

(deftest origin-round-trip
  (let ((score (origin-base)))
    (ok (equal +origin-base+ (score-to-sexp score)) "the canonical form is written back as read")
    (ok (score-equal score (sexp-to-score (score-to-sexp score))) "SEXP-TO-SCORE of SCORE-TO-SEXP")
    (dolist (id '("g1" "g2" "g3" "g4" "c"))
      (let ((element (find-element score id)))
        (ok (equal (element-to-sexp element) (element-to-sexp (sexp-to-element (element-to-sexp element))))
            (format nil "~A: the element round trip keeps its origin" id))
        (ok (equalp (element-origin element) (element-origin (sexp-to-element (element-to-sexp element))))
            (format nil "~A: the origin read back is EQUALP" id))))
    (ok (equal "h2" (origin-id (element-origin (anchor-of score "g3")))))
    (ok (equalp (chord "F") (origin-value (element-origin (anchor-of score "g3")))))
    (ok (null (element-origin (anchor-of score "g5"))))))

(deftest-parametrize score-equal-compares-origins
    ((label old new)
     ("another origin id" '(:id "h1" :value (:root "C" :quality :major)) '(:id "h9" :value (:root "C" :quality :major)))
     ("another origin value" '(:id "h1" :value (:root "C" :quality :major)) '(:id "h1" :value (:root "A" :quality :minor)))
     ("no value" '(:id "h1" :value (:root "C" :quality :major)) '(:id "h1")))
  (let ((changed (subst new old +origin-base+ :test #'equal)))
    (ok (not (equal changed +origin-base+)) label)
    (ok (not (score-equal (origin-base) (sexp-to-score changed))) label))
  (ok (not (score-equal (origin-base) (sexp-to-score (strip-origins +origin-base+))))
      "a score without its origins is another score"))

(deftest-parametrize origin-read-errors
    ((label origin type)
     ("an unknown key" '(:id "h1" :symbol (:root "C" :quality :major)) 'score-format-error)
     ("a key twice" '(:id "h1" :id "h2") 'score-format-error)
     ("not a plist" '(:id) 'score-format-error)
     ("a value that is not a chord-symbol plist" '(:id "h1" :value "C") 'score-format-error)
     ("no id" '(:value (:root "C" :quality :major)) 'type-error)
     ("an invalid id" '(:id "1x") 'type-error))
  (let* ((form `(:chord-symbol :id "x1" :bar 1 :offset 0 :symbol (:root "C" :quality :major)
                               :provenance (:source :engine :origin ,origin)))
         (c (condition-of (lambda () (sexp-to-element form)))))
    (ok (typep c type) label)
    (when (and (eq type 'score-format-error) (typep c 'score-format-error)
               (string/= label "a value that is not a chord-symbol plist"))
      (ok (equal origin (score-format-error-position c)) (format nil "~A: the position is the origin plist" label)))))

;;; Origins are records, not elements ----------------------------------------------

(deftest origins-are-no-elements
  (let ((score (origin-base)))
    (ok (null (check-score score)) "no issue: origin ids need not name an element")
    (ok (null (find-element score "h1" :errorp nil)) "FIND-ELEMENT never finds an origin")
    (ok (typep (find-element score "b") 'note-event) "the note b is found, not g2's origin")
    (ok (notany #'origin-p (score-elements score)))
    (ok (= 30 (score-id-counter score)) "the origin n-7's serial does not count"))
  (let ((score (make-score
                :measures (list (make-measure-info :id "m1" :time (parse-meter "4/4") :key (parse-key "C major")))
                :chord-symbols (list (make-chord-symbol-anchor
                                      :id "x" :position '(1 . 0) :symbol (chord "C")
                                      :provenance (make-provenance :source :engine
                                                                   :origin (make-origin :id "h-zz")))))))
    (ok (= 0 (score-id-counter score)) "an origin id with a serial raises no counter")
    (ok (null (check-score score))))
  (let ((score (make-score
                :measures (list (make-measure-info :time (parse-meter "4/4") :key (parse-key "C major")))
                :chord-symbols (list (make-chord-symbol-anchor
                                      :position '(1 . 0) :symbol (chord "C")
                                      :provenance (make-provenance :source :engine
                                                                   :origin (make-origin :id "h-2")))))))
    (ok (equal "h-2" (element-id (first (seq-list (score-chord-symbols score)))))
        "minting may give an element the id an origin records")
    (ok (null (check-score score)))))

(deftest writers-see-the-same-provenance
  ;; A writer that can't carry provenance reports the elements that have one;
  ;; an origin only travels inside a provenance, so that set is the same.
  (flet ((carriers (score)
           (sort (loop for e in (score-elements score) when (element-provenance e) collect (element-id e))
                 #'string<)))
    (ok (equal (carriers (origin-base)) (carriers (sexp-to-score (strip-origins +origin-base+)))))))

;;; Copies and views keep origins ----------------------------------------------------

(deftest copies-and-views-keep-origins
  (let* ((score (origin-base))
         (anchors (seq-list (score-chord-symbols score))))
    (flet ((same-anchors-p (view)
             (every (lambda (a) (eq a (find-element view (element-id a)))) anchors)))
      (ok (same-anchors-p (copy-score score :metadata '(:title "Copy"))) "COPY-SCORE")
      (ok (same-anchors-p (extract-part score "p1")) "EXTRACT-PART")
      (ok (same-anchors-p (condensed-view score)) "CONDENSED-VIEW")
      (ok (same-anchors-p (unfold score)) "UNFOLD of a score without repeats")
      (ok (eq (find-element score "c") (find-element (extract-part score "v1") "c")) "the note's origin too"))))

;;; Edits keep origins ----------------------------------------------------------------

(deftest-parametrize edits-keep-untouched-origins
    ((label op)
     ("a re-pitched note" (make-set-pitch :id "a" :pitch (parse-pitch "G4")))
     ("a fermata" (make-add-mark :target "d" :mark (make-fermata)))
     ("a deleted note" (make-delete-event :id "b"))
     ("a removed anchor" (make-remove-chord-symbol :id "g3"))
     ("a new anchor" (make-add-chord-symbol :anchor (make-chord-symbol-anchor :position '(3 . 1/2)
                                                                             :symbol (parse-chord-symbol "G")))))
  (let ((score (origin-base)))
    (multiple-value-bind (new changes) (apply-op score op)
      (ok (every (lambda (a) (or (not (find-element new (element-id a) :errorp nil))
                                 (eq a (find-element new (element-id a)))))
                 (seq-list (score-chord-symbols score)))
          (format nil "~A: every anchor left alone is shared, origin included" label))
      (ok (notany (lambda (id) (member id '("g1" "g2" "g4" "g5") :test #'equal)) (third changes))
          (format nil "~A: no origin-carrying anchor is modified" label))
      (ok (null (check-score new)) (format nil "~A: still valid" label))
      (ok (score-equal score (apply-edit new (invert-edit score op)))
          (format nil "~A: the inverse restores every origin" label)))))

(deftest an-edited-element-keeps-its-origin
  (let* ((score (origin-base))
         (new (apply-edit score (make-set-pitch :id "c" :pitch (parse-pitch "A4")))))
    (ok (equal '(:note :id "c" :pitch "A4" :duration 1 :provenance (:source :user :origin (:id "n-7"))
                 :confidence 1)
               (form-of new "c"))
        "provenance :user, confidence 1, the origin kept")
    (ok (equalp (element-origin (find-element score "c")) (element-origin (find-element new "c"))))
    (ok (score-equal score (apply-edit new (invert-edit score (make-set-pitch :id "c" :pitch (parse-pitch "A4"))))))))

(deftest a-given-anchor-is-stored-with-its-origin
  (let* ((anchor (make-chord-symbol-anchor
                  :id "g6" :position '(3 . 1/2) :symbol (chord "G7")
                  :provenance (make-provenance :source :engine :origin (make-origin :id "h4" :value (chord "G")))))
         (op (make-add-chord-symbol :anchor anchor))
         (new (apply-edit (origin-base) op)))
    (ok (eq anchor (find-element new "g6")) "stored as given")
    (ok (equal '(:id "h4" :value (:root "G" :quality :major)) (origin-form (find-element new "g6"))))
    (let ((form (edit-to-sexp op)))
      (ok (equal '(:id "h4" :value (:root "G" :quality :major))
                 (getf (getf (cdr (getf (cdr form) :anchor)) :provenance) :origin))
          "the operation's canonical form carries the origin")
      (ok (equal form (edit-to-sexp (sexp-to-edit form))) "and reads back"))))

;;; TRANSPOSE moves chord-symbol origins ---------------------------------------------------

(defparameter +transposed-anchors+
  ;; Up a major second: every anchor and every chord-symbol origin value moves; the
  ;; anchors get provenance :user and confidence 1 with their origins (ids kept).
  '(("g1" (:chord-symbol :id "g1" :bar 1 :offset 0 :symbol (:root "D" :quality :major)
           :provenance (:source :user :origin (:id "h1" :value (:root "D" :quality :major))) :confidence 1))
    ("g2" (:chord-symbol :id "g2" :bar 1 :offset 1/2 :symbol (:root "A" :quality :major :bass "C#")
           :provenance (:source :user :origin (:id "b" :value (:root "A" :quality :dominant-7))) :confidence 1))
    ("g3" (:chord-symbol :id "g3" :bar 2 :offset 0 :symbol (:root "E" :quality :minor :bass "G")
           :provenance (:source :user :origin (:id "h2" :value (:root "G" :quality :major))) :confidence 1))
    ("g4" (:chord-symbol :id "g4" :bar 2 :offset 1/2 :symbol (:no-chord-p t)
           :provenance (:source :user :origin (:id "h3" :value (:root "A" :quality :dominant-7))) :confidence 1))
    ("g5" (:chord-symbol :id "g5" :bar 3 :offset 0 :symbol (:root "D" :quality :major)
           :provenance (:source :user) :confidence 1))
    ("c" (:note :id "c" :pitch "A4" :duration 1 :provenance (:source :user :origin (:id "n-7")) :confidence 1))))

(deftest transpose-moves-chord-origins
  (let* ((score (origin-base))
         (op (make-transpose :interval (parse-interval "M2"))))
    (multiple-value-bind (new changes) (apply-op score op)
      (loop for (id form) in +transposed-anchors+
            do (ok (equal form (form-of new id)) (format nil "~A after TRANSPOSE up a M2" id)))
      (ok (subsetp '("g1" "g2" "g3" "g4" "g5") (third changes) :test #'equal)
          "every anchor is modified, the N.C. one through its origin")
      (ok (null (check-score new)))
      (ok (score-equal score (apply-edit new (invert-edit score op))) "the inverse moves them back"))))

(deftest-parametrize transpose-moves-an-origin-as-its-anchor
    ((label op)
     ("down to B-flat major" (make-transpose :to-key (parse-key "Bb major")))
     ("up an augmented unison" (make-transpose :interval (parse-interval "A1")))
     ("down a minor third" (make-transpose :interval (parse-interval "-m3")))
     ("to F-sharp major" (make-transpose :to-key (parse-key "F# major"))))
  ;; g1's symbol and its origin's value are both C: they move alike, respelling included.
  (let* ((new (apply-edit (origin-base) op))
         (g1 (find-element new "g1")))
    (ok (equal (getf (cdr (element-to-sexp g1)) :symbol) (getf (origin-form g1) :value)) label)
    (ok (equal "h1" (origin-id (element-origin g1))) (format nil "~A: the id stays" label))))
