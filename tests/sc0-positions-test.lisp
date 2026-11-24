;;;; SC0: bars, inherited signatures, lengths, positions and pickup arithmetic.
;;;; Rules: src/measure-map.lisp. The fixture vectors (sc0-bars, sc0-events,
;;;; sc0-anchors, sc0-pickups) were computed by music21 10.5.2 from the same
;;;; scores (tests/fixtures/PROVENANCE.md). Hand-written rows follow the rules
;;;; and were checked against a separate reference implementation.

(in-package #:score-protocol/tests)

;;; Fixture vectors -----------------------------------------------------------

(deftest bar-fixtures
  (let* ((rows (fixture "sc0-bars.sexp"))
         (bad (collect-mismatches (row rows)
                (destructuring-bind (name bar start length time key) row
                  (declare (ignore length time key))
                  (eql start (bar-start (fixture-score name) bar)))
                (destructuring-bind (name bar start length time key) row
                  (declare (ignore start time key))
                  (eql length (bar-length (fixture-score name) bar)))
                (destructuring-bind (name bar start length time key) row
                  (declare (ignore start length key))
                  (string= time (meter-string (bar-time (fixture-score name) bar))))
                (destructuring-bind (name bar start length time key) row
                  (declare (ignore start length time))
                  (string= key (key-name (bar-key (fixture-score name) bar))))
                (destructuring-bind (name bar &rest more) row
                  (declare (ignore more))
                  (let ((s (fixture-score name)))
                    (eq (bar-measure s bar)
                        (fset:@ (score-measure-map s) (- bar (score-first-bar s)))))))))
    (ok (= 48 (length rows)))
    (ok (null bad) (report bad))))

(deftest-parametrize score-extent
    ((name) :rows +fixture-scores+)
  ;; First bar, last bar and duration, from the bar vectors.
  (let* ((rows (remove name (fixture "sc0-bars.sexp") :key #'first :test-not #'string=))
         (last-row (car (last rows)))
         (s (fixture-score name)))
    (ok (= (second (first rows)) (score-first-bar s)))
    (ok (= (second last-row) (score-last-bar s)))
    (ok (= (+ (third last-row) (fourth last-row)) (score-duration s)))
    (ok (= (length rows) (fset:size (score-measure-map s))))))

(deftest event-fixtures
  (let* ((rows (fixture "sc0-events.sexp"))
         (bad (collect-mismatches (row rows)
                (destructuring-bind (name id bar offset absolute) row
                  (declare (ignore absolute))
                  (equal (cons bar offset) (element-position (fixture-score name) id)))
                (destructuring-bind (name id bar offset absolute) row
                  (declare (ignore id))
                  (eql absolute (absolute-offset (fixture-score name) (cons bar offset))))
                (destructuring-bind (name id bar offset absolute) row
                  (declare (ignore id))
                  (equal (cons bar offset) (offset-position (fixture-score name) absolute))))))
    (ok (= 153 (length rows)))
    (ok (= 153 (loop for name in +fixture-scores+
                     sum (count-if (lambda (e) (typep e 'event))
                                   (score-elements (fixture-score name)))))
        "every event has a row")
    (ok (null bad) (report bad))))

(deftest anchor-fixtures
  (let* ((rows (fixture "sc0-anchors.sexp"))
         (bad (collect-mismatches (row rows)
                (destructuring-bind (name id absolute) row
                  (let ((s (fixture-score name)))
                    (and (equal (anchor-position (find-element s id)) (element-position s id))
                         (eql absolute (absolute-offset s (element-position s id)))))))))
    (ok (= 10 (length rows)))
    (ok (null bad) (report bad))))

(defun pickup-score (meter-text pickup bars completing)
  "A one-voice score in METER-TEXT: a PICKUP-long bar 0, BARS full bars and,
when COMPLETING, a final bar of the rest of the bar; each bar holds one rest."
  (let* ((meter (parse-meter meter-text))
         (bar (meter-measure-duration meter))
         (lengths (append (list pickup) (make-list bars :initial-element bar)
                          (and completing (list (- bar pickup))))))
    (make-score
     :measures (append (list (make-measure-info :time meter :key (parse-key "C")
                                                :pickup-p t :length pickup))
                       (loop repeat bars collect (make-measure-info))
                       (and completing (list (make-measure-info :length (- bar pickup)))))
     :parts (list (make-part :staves (list (make-staff))
                             :voices (list (make-voice
                                            :measures (loop for l in lengths
                                                            collect (list (make-rest-event
                                                                           :duration l))))))))))

(deftest pickup-fixtures
  (let* ((rows (fixture "sc0-pickups.sexp"))
         (bad (collect-mismatches (row rows)
                (destructuring-bind (meter pickup bars completing starts duration samples) row
                  (declare (ignore samples))
                  (let ((s (pickup-score meter pickup bars completing)))
                    (and (= 0 (score-first-bar s))
                         (= (1- (length starts)) (score-last-bar s))
                         (eql duration (score-duration s))
                         (equal starts (loop for b from 0 below (length starts)
                                             collect (bar-start s b))))))
                (destructuring-bind (meter pickup bars completing starts duration samples) row
                  (declare (ignore starts duration))
                  (let ((s (pickup-score meter pickup bars completing)))
                    (loop for (absolute bar offset) in samples
                          always (and (equal (cons bar offset) (offset-position s absolute))
                                      (eql absolute (absolute-offset s (cons bar offset))))))))))
    (ok (= 30 (length rows)))
    (ok (null bad) (report bad))))

;;; Positions by hand: the pickup fixture -------------------------------------
;;; Bars 0..4 with lengths 1/4 3/4 3/4 3/4 1/2 start at 0 1/4 1 7/4 5/2; the
;;; score lasts 3 whole notes.

(deftest-parametrize absolute-offsets
    ((position expected)
     ('(0 . 0) 0) ('(0 . 1/8) 1/8) ('(0 . 1/4) 1/4) ('(1 . 0) 1/4) ('(1 . 3/4) 1)
     ('(2 . 0) 1) ('(2 . 3/4) 7/4) ('(3 . 1/2) 9/4) ('(4 . 0) 5/2) ('(4 . 1/2) 3))
  (ok (eql expected (absolute-offset (fixture-score "sc0-pickup") position))))

(deftest-parametrize offset-positions
    ((offset expected)
     (0 '(0 . 0)) (1/8 '(0 . 1/8)) (1/4 '(1 . 0)) (3/8 '(1 . 1/8)) (1 '(2 . 0))
     (7/4 '(3 . 0)) (5/2 '(4 . 0)) (11/4 '(4 . 1/4)) (3 '(4 . 1/2)))
  (ok (equal expected (offset-position (fixture-score "sc0-pickup") offset))))

(deftest-parametrize invalid-positions
    ((label thunk argument)
     ("bar past the end" (lambda () (absolute-offset (fixture-score "sc0-pickup") '(5 . 0))) '(5 . 0))
     ("negative bar" (lambda () (absolute-offset (fixture-score "sc0-pickup") '(-1 . 0))) '(-1 . 0))
     ("past the pickup" (lambda () (absolute-offset (fixture-score "sc0-pickup") '(0 . 1/2))) '(0 . 1/2))
     ("negative offset" (lambda () (absolute-offset (fixture-score "sc0-pickup") '(1 . -1/8))) '(1 . -1/8))
     ("past the short final bar" (lambda () (absolute-offset (fixture-score "sc0-pickup") '(4 . 3/4)))
      '(4 . 3/4))
     ("bar 0 without a pickup" (lambda () (absolute-offset (fixture-score "sc0-jumps") '(0 . 0))) '(0 . 0))
     ("before the start" (lambda () (offset-position (fixture-score "sc0-pickup") -1/8)) -1/8)
     ("after the end" (lambda () (offset-position (fixture-score "sc0-pickup") 25/8)) 25/8)
     ("length of a missing bar" (lambda () (bar-length (fixture-score "sc0-pickup") 5)) 5)
     ("start of a missing bar" (lambda () (bar-start (fixture-score "sc0-pickup") -1)) -1)
     ("time of a missing bar" (lambda () (bar-time (fixture-score "sc0-jumps") 0)) 0)
     ("key of a missing bar" (lambda () (bar-key (fixture-score "sc0-jumps") 8)) 8)
     ("measure of a missing bar" (lambda () (bar-measure (fixture-score "sc0-jumps") 8)) 8)
     ("empty score: offset 0" (lambda () (offset-position (make-score) 0)) 0)
     ("empty score: bar 1" (lambda () (bar-length (make-score) 1)) 1)
     ("empty score: position" (lambda () (absolute-offset (make-score) '(1 . 0))) '(1 . 0)))
  (let ((c (signalled thunk)))
    (ok (typep c 'invalid-position) label)
    (ok (typep c 'score-error) label)
    (ok (equal argument (and (typep c 'invalid-position) (invalid-position-position c))) label)))

(deftest invalid-position-use-value-restart
  (let ((s (fixture-score "sc0-pickup")))
    (ok (eql 42 (handler-bind ((invalid-position (lambda (c) (use-value 42 c))))
                  (absolute-offset s '(9 . 0)))))
    (ok (equal '(1 . 0) (handler-bind ((invalid-position (lambda (c) (use-value '(1 . 0) c))))
                          (offset-position s 7))))
    (ok (eql 3/4 (handler-bind ((invalid-position (lambda (c) (use-value 3/4 c))))
                   (bar-length s 12))))))

(deftest-parametrize position-type-errors
    ((label thunk)
     ("float offset in a position" (lambda () (absolute-offset (fixture-score "sc0-pickup") '(1 . 0.5))))
     ("rational bar" (lambda () (absolute-offset (fixture-score "sc0-pickup") '(1/2 . 0))))
     ("float absolute offset" (lambda () (offset-position (fixture-score "sc0-pickup") 0.5)))
     ("float bar" (lambda () (bar-length (fixture-score "sc0-pickup") 1.0)))
     ("position not a cons" (lambda () (absolute-offset (fixture-score "sc0-pickup") 1))))
  (ok (signals-type thunk 'type-error) label))

(deftest empty-score-extent
  (let ((s (make-score)))
    (ok (= 1 (score-first-bar s)))
    (ok (= 0 (score-last-bar s)))
    (ok (eql 0 (score-duration s)))))

(deftest signatures-default-and-inherit
  (let ((s (sexp-to-score
            '(:score :measures ((:measure) (:measure :key "D major") (:measure :time "6/8")
                                (:measure :length 1/8))
              :parts ((:part :staves ((:staff)) :voices ((:voice :measures (() () () ())))))))))
    (ok (equalp (make-meter) (bar-time s 1)) "4/4 when no measure gives a time")
    (ok (equalp (make-key) (bar-key s 1)) "C major when no measure gives a key")
    (ok (eql 1 (bar-length s 1)))
    (ok (equalp (parse-key "D major") (bar-key s 3)) "a key carries on")
    (ok (equalp (parse-meter "6/8") (bar-time s 4)) "a time carries on")
    (ok (eql 1/8 (bar-length s 4)) "an explicit length wins over the meter")
    (ok (equal '(0 1 2 11/4) (loop for b from 1 to 4 collect (bar-start s b))))
    (ok (eql 23/8 (score-duration s)))))

;;; Element positions -----------------------------------------------------------

(deftest-parametrize element-positions-by-kind
    ((name id position)
     ("sc0-keyboard" "m-1" '(1 . 0))
     ("sc0-keyboard" "m-3" '(3 . 0))
     ("sc0-pickup" "m-1" '(0 . 0))
     ("sc0-pickup" "m-2" '(1 . 0))
     ("sc0-keyboard" "e-8" '(2 . 0))
     ("sc0-keyboard" "e-9" '(2 . 0))
     ("sc0-keyboard" "e-b" '(2 . 1/3))
     ("sc0-keyboard" "n-s" '(1 . 1/2))
     ("sc0-keyboard" "e-15" '(2 . 1/2))
     ("sc0-pickup" "ly-e" '(1 . 1/2))
     ("sc0-pickup" "sp-q" '(1 . 1/2))
     ("sc0-keyboard" "sp-1c" '(2 . 0))
     ("sc0-chords-under-rests" "h-i" '(1 . 1/4))
     ("sc0-keyboard" "p-h" nil)
     ("sc0-keyboard" "st-j" nil)
     ("sc0-keyboard" "v-13" nil))
  (ok (equal position (element-position (fixture-score name) id))))

(deftest element-positions-without-validation
  (let ((s (sexp-to-score
            '(:score :measures ((:measure :id "m" :time "2/4" :key "C major"))
              :parts ((:part :id "p" :staves ((:staff :id "s"))
                       :voices ((:voice :id "v"
                                 :measures (((:note :id "a" :pitch "C4" :duration 1/2))
                                            ((:note :id "b" :pitch "D4" :duration 1/4)
                                             (:note :id "c" :pitch "E4" :duration 1/4)))))))
              :spanners ((:spanner :id "dangling" :kind :slur :start "gone" :end "a"))))))
    (ok (equal '(2 . 1/4) (element-position s "c")) "a voice measure past the map still counts")
    (ok (null (element-position s "dangling")) "a spanner whose start is missing")))
