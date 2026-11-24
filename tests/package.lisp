(defpackage #:score-protocol/tests
  (:use #:cl #:rove #:score-protocol #:music-theory))

(in-package #:score-protocol/tests)

(defparameter +fixture-scores+
  '("sc0-carol-6-8" "sc0-chords-under-rests" "sc0-jumps" "sc0-key-change"
    "sc0-keyboard" "sc0-omr-result" "sc0-pickup" "sc0-repeats-voltas" "sc0-satb"
    "sc0-three-verses")
  "The hand-built fixture scores, tests/fixtures/<name>.sexp.")

(defun fixture (name)
  "Read the single top-level form in tests/fixtures/NAME."
  (with-open-file (in (asdf:system-relative-pathname "score-protocol/tests"
                                                     (format nil "tests/fixtures/~A" name))
                      :external-format :utf-8)
    (with-standard-io-syntax
      (let ((*read-eval* nil)
            (*package* (find-package '#:score-protocol/tests)))
        (read in)))))

(defun fixture-form (name)
  "The canonical form of the fixture score NAME."
  (fixture (format nil "~A.sexp" name)))

(defvar *fixture-scores* (make-hash-table :test 'equal))

(defun fixture-score (name)
  "The fixture score NAME, read once per test run."
  (or (gethash name *fixture-scores*)
      (setf (gethash name *fixture-scores*) (sexp-to-score (fixture-form name)))))

(defun seq-list (seq)
  "The members of the FSet seq SEQ as a list."
  (fset:convert 'list seq))

(defmacro collect-mismatches ((row rows) &body checks)
  "Run CHECKS (forms returning true when the ROW passes) over ROWS; return the
failing rows, each paired with the list of failed check indices."
  (let ((bad (gensym)) (fails (gensym)))
    `(let ((,bad '()))
       (dolist (,row ,rows (nreverse ,bad))
         (let ((,fails '()))
           ,@(loop for c in checks for i from 0
                   collect `(unless (ignore-errors ,c) (push ,i ,fails)))
           (when ,fails (push (list ,row (nreverse ,fails)) ,bad)))))))

(defun report (bad)
  (format nil "~D mismatches~@[, first: ~S~]" (length bad)
          (and bad (subseq bad 0 (min 8 (length bad))))))

(defun signals-type (thunk type)
  "True when THUNK signals a condition of TYPE."
  (handler-case (progn (funcall thunk) nil)
    (condition (c) (typep c type))))

(defun signalled (thunk)
  "The condition THUNK signals, or NIL."
  (handler-case (progn (funcall thunk) nil)
    (condition (c) c)))

(defun ids (elements)
  (mapcar #'element-id elements))

(defun triple-key (triple)
  (format nil "~S" triple))

(defun issue-triples (issues)
  "ISSUES as (kind id bar) lists, sorted."
  (sort (mapcar (lambda (i) (list (score-issue-kind i) (score-issue-id i) (score-issue-bar i)))
                issues)
        #'string< :key #'triple-key))

(defun sorted-triples (triples)
  (sort (copy-list triples) #'string< :key #'triple-key))

(defparameter +element-kinds+
  '(:measure :part :staff :voice :rest :note :chord :chord-note :lyric
    :chord-symbol :spanner :dynamic :fermata :breath-mark :articulation :tie
    :tempo-mark :rehearsal :jump :ending)
  "The kind keywords of element forms (src/sexp.lisp).")

(defun strip-ids (form)
  "A copy of FORM with the :ID entry removed from every element form, and the
:ID-COUNTER entry from a score form."
  (cond ((atom form) form)
        ((member (car form) (cons :score +element-kinds+))
         (cons (car form)
               (loop for (key value) on (cdr form) by #'cddr
                     unless (member key '(:id :id-counter))
                       nconc (list key (strip-ids value)))))
        ;; Walk conses, not lists: chord-symbol alterations are dotted pairs.
        (t (cons (strip-ids (car form)) (strip-ids (cdr form))))))

(defun minted-prefix (element)
  "The prefix ids.lisp gives ELEMENT's minted ids, decided here independently."
  (etypecase element
    (measure-info "m") (part "p") (staff "st") (voice "v") (event "e")
    (chord-note "n") (lyric "ly") (dynamic-mark "dy") (fermata "fe") (breath-mark "br")
    (articulation "ar") (tie "ti") (tempo-mark "tm") (rehearsal-mark "rh") (jump-mark "jm")
    (ending "en") (chord-symbol-anchor "h") (spanner "sp")))
