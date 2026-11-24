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

;;; SC1 helpers ---------------------------------------------------------------
;;; Independent of the implementation: the change set, the shallow form and
;;; sharing are recomputed here from the canonical forms (src/edits.lisp).

(defun element-form-p (x)
  (and (consp x) (member (car x) +element-kinds+) t))

(defun shallow-form (form)
  "FORM (an element's canonical form) with every child form replaced by its id."
  (cons (car form)
        (loop for (key value) on (cdr form) by #'cddr
              nconc (list key
                          (cond ((element-form-p value) (getf (cdr value) :id))
                                ((and (consp value) (every #'element-form-p value))
                                 (mapcar (lambda (f) (getf (cdr f) :id)) value))
                                ((and (eq key :measures) (listp value)
                                      (every #'listp value)
                                      (every (lambda (m) (every #'element-form-p m)) value))
                                 (mapcar (lambda (m) (mapcar (lambda (f) (getf (cdr f) :id)) m))
                                         value))
                                (t value))))))

(defun element-table (score)
  "id → element of SCORE (first carrier)."
  (let ((table (make-hash-table :test 'equal)))
    (dolist (e (score-elements score) table)
      (unless (gethash (element-id e) table)
        (setf (gethash (element-id e) table) e)))))

(defun expected-change-set (old new)
  "(created removed modified) from OLD to NEW, by the rules of src/edits.lisp."
  (let ((old-table (element-table old))
        (new-table (element-table new)))
    (list (loop for e in (score-elements new)
                unless (gethash (element-id e) old-table) collect (element-id e))
          (loop for e in (score-elements old)
                unless (gethash (element-id e) new-table) collect (element-id e))
          (loop for e in (score-elements new)
                for o = (gethash (element-id e) old-table)
                when (and o (not (equal (shallow-form (element-to-sexp e))
                                        (shallow-form (element-to-sexp o)))))
                  collect (element-id e)))))

(defun change-lists (change-set)
  (list (change-set-created change-set) (change-set-removed change-set)
        (change-set-modified change-set)))

(defun unshared (old new)
  "Ids of elements of NEW equal in canonical form to OLD's element with that id
but not EQ to it."
  (let ((old-table (element-table old)))
    (loop for e in (score-elements new)
          for o = (gethash (element-id e) old-table)
          when (and o (not (eq e o)) (equal (element-to-sexp e) (element-to-sexp o)))
            collect (element-id e))))

(defun expand-user (form)
  "FORM with each element form's :USER T replaced by the provenance and
confidence an edit gives (src/edits.lisp): test rows stay short."
  (cond ((atom form) form)
        ((element-form-p form)
         (cons (car form)
               (loop for (key value) on (cdr form) by #'cddr
                     nconc (if (eq key :user)
                               (list :provenance '(:source :user) :confidence 1)
                               (list key (expand-user value))))))
        (t (cons (expand-user (car form)) (expand-user (cdr form))))))

(defun ev-form (x) (if (element-form-p x) (sexp-to-element x) x))

(defun apply-op (score op)
  "(values new-score (created removed modified))."
  (multiple-value-bind (new changes) (apply-edit score op)
    (values new (change-lists changes))))

(defun voice-form (score id)
  "The :measures of the voice ID's canonical form."
  (getf (cdr (element-to-sexp (find-element score id))) :measures))

(defun form-of (score id)
  (element-to-sexp (find-element score id)))

(defun condition-of (thunk)
  "The condition THUNK signals, or NIL. Restarts are not invoked."
  (handler-case (progn (funcall thunk) nil)
    (condition (c) c)))

(defun with-restart (type restart thunk &rest args)
  "Call THUNK with a handler that invokes RESTART (with ARGS) for conditions of TYPE."
  (handler-bind ((condition (lambda (c)
                              (when (typep c type)
                                (apply #'invoke-restart (find-restart restart c) args)))))
    (funcall thunk)))

(defun measure-ids (score)
  (mapcar #'element-id (seq-list (score-measure-map score))))

(defun find-restart-p (type restart thunk)
  "True when THUNK signals a condition of TYPE with RESTART available."
  (block found
    (handler-bind ((condition (lambda (c)
                                (when (typep c type)
                                  (return-from found (and (find-restart restart c) t))))))
      (funcall thunk)
      nil)))
