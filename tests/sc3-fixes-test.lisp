;;;; SC3: the small rules of 0.3.0. Rules: the REASON of ABSOLUTE-OFFSET's
;;;; INVALID-POSITION (src/measure-map.lisp), UNFOLD without a step limit
;;;; (src/views.lisp), the operation a reflowed insert is named by
;;;; (src/edits.lisp), and LOSSY-CONVERSION's DIRECTION (src/conditions.lisp).

(in-package #:score-protocol/tests)

;;; ABSOLUTE-OFFSET says which part of the position is wrong ----------------------
;;; sc0-pickup: bars 0..4 with lengths 1/4 3/4 3/4 3/4 1/2.

(deftest-parametrize absolute-offset-reasons
    ((label name position reason)
     ("past the pickup" "sc0-pickup" '(0 . 1/2) "offset past the end of bar 0 (length 1/4)")
     ("past a full bar" "sc0-pickup" '(2 . 1) "offset past the end of bar 2 (length 3/4)")
     ("past the short final bar" "sc0-pickup" '(4 . 3/4) "offset past the end of bar 4 (length 1/2)")
     ("negative offset" "sc0-pickup" '(1 . -1/8) "negative offset")
     ("bar past the end" "sc0-pickup" '(5 . 0) "no such bar")
     ("negative bar" "sc0-pickup" '(-1 . 0) "no such bar")
     ("no such bar, and a negative offset" "sc0-pickup" '(9 . -1) "no such bar")
     ("bar 0 without a pickup" "sc0-jumps" '(0 . 0) "no such bar"))
  (let ((c (signalled (lambda () (absolute-offset (fixture-score name) position)))))
    (ok (typep c 'invalid-position) label)
    (ok (equal position (and (typep c 'invalid-position) (invalid-position-position c))) label)
    (ok (equal reason (and (typep c 'score-error) (score-error-reason c))) label)))

(deftest absolute-offset-reasons-elsewhere
  (let ((c (signalled (lambda () (absolute-offset (make-score) '(1 . 0))))))
    (ok (equal "no such bar" (and (typep c 'score-error) (score-error-reason c)))
        "a score with no measures has no bars"))
  (let ((c (signalled (lambda () (absolute-offset (fixture-score "sc0-pickup") '(0 . 1/2))))))
    (ok (equal "invalid position (0 . 1/2): offset past the end of bar 0 (length 1/4)"
               (and c (princ-to-string c)))
        "the report"))
  (let ((c (signalled (lambda () (offset-position (fixture-score "sc0-pickup") 25/8)))))
    (ok (equal "outside the score" (and (typep c 'score-error) (score-error-reason c)))
        "OFFSET-POSITION's argument is an instant: its reason stays"))
  (let ((c (signalled (lambda () (bar-length (fixture-score "sc0-pickup") 5)))))
    (ok (equal "no such bar" (and (typep c 'score-error) (score-error-reason c))))))

;;; UNFOLD has no step limit ----------------------------------------------------------

(deftest-parametrize unfold-has-no-step-limit
    ((label spec order passes)
     ("one bar played 100 times" '((:repeat-start t :repeat-end 100))
      (make-list 100 :initial-element 0)
      (loop for k from 1 to 100 collect k))
     ("two bars played 80 times, then a D.C."
      '((:repeat-start t) (:repeat-end 80 :jump (:da-capo)))
      (loop repeat 81 append (list 0 1))
      (loop for k from 1 to 81 append (list k k))))
  (multiple-value-bind (view id-map view-passes)
      (handler-case (unfold (nav-score spec))
        (score-error () (values nil nil nil)))
    (ok view (format nil "~A: the walk ends without a SCORE-ERROR" label))
    (when view
      (ok (equal (mapcar (lambda (i) (format nil "m~D" i)) order) (view-sources view id-map)) label)
      (ok (equal passes (view-passes view view-passes)) label)
      (ok (null (check-score view)) label))))

;;; A reflowed insert is named as reflowed -------------------------------------------
;;; The base score (sc1-edits-test.lisp): v1 bar 2 is E4 G4 and a half rest.

(defun tied-to-nowhere (pitch duration)
  "A note event of PITCH and DURATION whose tie ends on no element."
  (make-note-event :pitch (p pitch) :duration duration :tie (make-tie :end "nowhere")))

(deftest reflowed-insert-names-itself
  (let* ((op (make-insert-event :voice "v1" :measure "m2" :event (tied-to-nowhere "A4" 3/4)))
         (c (condition-of (lambda ()
                            (handler-bind ((measure-overfull #'reflow))
                              (apply-edit (base) op)))))
         (named (and (typep c 'invalid-edit) (invalid-edit-op c))))
    (ok (typep c 'edit-breaks-score) "the reflowed insert breaks the score: its tie goes nowhere")
    (ok (typep named 'insert-event))
    (ok (and named (edit-reflow named)) "the condition names the reflowed operation")
    (ok (and named
             (equal '("v1" "m2" 0) (list (edit-voice named) (edit-measure named) (edit-offset named)))
             (equal (element-to-sexp (edit-event op)) (element-to-sexp (edit-event named))))
        "the same insert, with REFLOW true")
    (let ((c (condition-of (lambda ()
                             (handler-bind ((measure-overfull #'reflow))
                               (invert-edit (base) op))))))
      (ok (and (typep c 'edit-breaks-score) (edit-reflow (invalid-edit-op c))) "INVERT-EDIT too")))
  (let* ((op (make-insert-event :voice "v1" :measure "m3" :offset 1/2
                                :event (tied-to-nowhere "A4" 1/4)))
         (c (condition-of (lambda () (apply-edit (base) op)))))
    (ok (typep c 'edit-breaks-score))
    (ok (and (typep c 'invalid-edit) (eq op (invalid-edit-op c)))
        "an insert that needs no reflow is named as it is")))

;;; LOSSY-CONVERSION has a direction ---------------------------------------------------

(deftest lossy-conversion-direction
  (let ((to (make-condition 'lossy-conversion :format :midi :what "ids"))
        (to-given (make-condition 'lossy-conversion :format :musicxml :direction :to
                                                    :what "provenance and confidence"))
        (from (make-condition 'lossy-conversion :format :musicxml :direction :from
                                                :what "<ornaments>")))
    (ok (eq :to (lossy-conversion-direction to)) "writing is the default")
    (ok (equal "lossy conversion to midi: ids dropped" (princ-to-string to)))
    (ok (equal "lossy conversion to musicxml: provenance and confidence dropped"
               (princ-to-string to-given)))
    (ok (eq :from (lossy-conversion-direction from)))
    (ok (equal "lossy conversion from musicxml: <ornaments> dropped" (princ-to-string from))
        "a reader's report says from")
    (ok (equal "lossy conversion from midi"
               (princ-to-string (make-condition 'lossy-conversion :format :midi :direction :from)))
        "WHAT is optional")
    (ok (typep from 'score-warning))
    (ok (eq :from (block seen
                    (handler-bind ((lossy-conversion
                                     (lambda (c) (return-from seen (lossy-conversion-direction c)))))
                      (warn 'lossy-conversion :format :musicxml :direction :from :what "<ornaments>"))))
        "handlers tell the two cases apart")))
