;;;; SC0: element ids: syntax, minting in document order, the counter, stability
;;;; under copies and serialization, lookups. Rules: src/ids.lisp and
;;;; src/score.lisp. The fixture ids were assigned by generate-sc0.py, an
;;;; implementation of the minting rules written in Python, independent of the
;;;; Lisp code.

(in-package #:score-protocol/tests)

(deftest-parametrize id-syntax
    ((text expected)
     ("e-1" t) ("m-c" t) ("sp-1k3" t) ("P1" t) ("tenor-1" t) ("a_b-c" t) ("x" t) ("Z9" t)
     ("e12" t) ("e-0c" t) ("A-" t)
     ("" nil) ("1e" nil) ("-a" nil) ("_x" nil) ("_" nil) ("a.b" nil) ("m-3.p-4" nil)
     ("a b" nil) ("a:b" nil) ("é1" nil) ("aé" nil) ("a/b" nil) ("a\"b" nil) (" e-1" nil)
     ("e-1 " nil))
  (ok (eq expected (and (valid-id-p text) t)) text))

(deftest id-syntax-needs-a-string
  (ok (null (valid-id-p :e1)))
  (ok (null (valid-id-p 12)))
  (ok (null (valid-id-p nil)))
  (ok (null (valid-id-p '("e-1"))))
  (ok (valid-id-p (coerce "e-1" 'simple-base-string))))

;;; Minting -----------------------------------------------------------------

(defun id-less-score ()
  "A score built with no ids: two measures, a part with two staves and two
voices (lyrics given out of verse order, a chord), a part with a silent voice,
and two chord symbols given out of track order."
  (make-score
   :measures (list (make-measure-info :time (parse-meter "3/4") :key (parse-key "F"))
                   (make-measure-info))
   :parts (list (make-part
                 :name "A"
                 :staves (list (make-staff) (make-staff :clef :bass))
                 :voices (list (make-voice
                                :measures
                                (list (list (make-note-event
                                             :pitch (p "F4") :duration 1/2
                                             :lyrics (list (make-lyric :verse 2 :text "b")
                                                           (make-lyric :text "a")))
                                            (make-chord-event
                                             :notes (list (make-chord-note :pitch (p "A4"))
                                                          (make-chord-note :pitch (p "C5")))
                                             :duration 1/4 :lyrics (list (make-lyric :text "c"))))
                                      (list (make-rest-event :duration 3/4))))
                               (make-voice
                                :staff 2
                                :measures (list (list (make-rest-event :duration 3/4))
                                                (list (make-note-event :pitch (p "F3")
                                                                       :duration 3/4))))))
                (make-part :staves (list (make-staff))
                           :voices (list (make-voice :measures '(() ())))))
   :chord-symbols (list (make-chord-symbol-anchor
                         :position '(2 . 0)
                         :symbol (make-chord-symbol :root (pc "C") :quality :dominant-7))
                        (make-chord-symbol-anchor
                         :position '(1 . 0)
                         :symbol (make-chord-symbol :root (pc "F") :quality :major)))))

(deftest minting-follows-document-order
  (let ((s (id-less-score)))
    (ok (equal '("m-1" "m-2" "p-3" "st-4" "st-5" "v-6" "e-7" "ly-8" "ly-9" "e-a" "n-b" "n-c" "ly-d"
                 "e-e" "v-f" "e-g" "e-h" "p-i" "st-j" "v-k" "h-l" "h-m")
               (ids (score-elements s))))
    (ok (= 22 (score-id-counter s)))
    (ok (equal "a" (lyric-text (find-element s "ly-8"))) "verse 1 comes first")
    (ok (eq :major (chord-symbol-quality (anchor-symbol (find-element s "h-l"))))
        "the track is sorted before minting")
    (ok (typep (find-element s "e-a") 'chord-event))
    (ok (typep (find-element s "n-c") 'chord-note))))

(deftest minting-is-deterministic
  (let ((a (id-less-score))
        (b (id-less-score)))
    (ok (equal (ids (score-elements a)) (ids (score-elements b))))
    (ok (score-equal a b))
    (ok (equal (score-to-sexp a) (score-to-sexp b)))))

(deftest-parametrize fixture-ids-are-minted-ids
    ((name) :rows +fixture-scores+)
  (let* ((form (fixture-form name))
         (s (fixture-score name))
         (elements (score-elements s)))
    (ok (equal form (score-to-sexp (sexp-to-score (strip-ids form))))
        "minting an id-less copy gives the fixture's ids")
    (ok (= (length elements) (score-id-counter s)))
    (ok (loop for e in elements
              for k from 1
              always (string= (format nil "~A-~(~36R~)" (minted-prefix e) k) (element-id e)))
        "SCORE-ELEMENTS lists the elements in document order")))

(deftest-parametrize fixture-ids-are-unique-and-found
    ((name) :rows +fixture-scores+)
  (let* ((s (fixture-score name))
         (elements (score-elements s))
         (ids (ids elements)))
    (ok (every #'valid-id-p ids))
    (ok (= (length ids) (length (remove-duplicates ids :test #'string=))))
    (ok (every (lambda (e) (eq e (find-element s (element-id e)))) elements))))

(defun mini-score (&rest keys)
  "A one-bar score whose elements are given ids by KEYS: :MEASURE, :PART,
:STAFF, :VOICE, :NOTE, :REST (NIL for none), plus :ID-COUNTER and :TIE (the
note's tie)."
  (destructuring-bind (&key measure part staff voice note rest tie (id-counter 0)) keys
    (make-score
     :id-counter id-counter
     :measures (list (make-measure-info :id measure :time (parse-meter "2/4")
                                        :key (parse-key "C")))
     :parts (list (make-part
                   :id part :staves (list (make-staff :id staff))
                   :voices (list (make-voice
                                  :id voice
                                  :measures (list (list (make-note-event :id note :pitch (p "C4")
                                                                         :duration 1/4 :tie tie)
                                                        (make-rest-event :id rest
                                                                         :duration 1/4))))))))))

(deftest-parametrize the-counter-starts-above-given-serials
    ((label keys expected counter)
     ("no ids" '() '("m-1" "p-2" "st-3" "v-4" "e-5" "e-6") 6)
     ("a serial id" '(:part "e-14") '("m-15" "e-14" "st-16" "v-17" "e-18" "e-19") 45)
     ("serials of other prefixes" '(:measure "sp-7" :staff "ly-3")
      '("sp-7" "p-8" "ly-3" "v-9" "e-a" "e-b") 11)
     ("ids without serials" '(:measure "e-0c" :part "E-C" :staff "x-99" :voice "st-0")
      '("e-0c" "E-C" "x-99" "st-0" "e-1" "e-2") 2)
     ("more ids without serials" '(:measure "e12" :part "l-3" :staff "s-5" :voice "v-4A")
      '("e12" "l-3" "s-5" "v-4A" "e-1" "e-2") 2)
     ("an :id-counter argument" '(:id-counter 100)
      '("m-2t" "p-2u" "st-2v" "v-2w" "e-2x" "e-2y") 106)
     ("a counter below a serial" '(:id-counter 3 :note "v-9")
      '("m-a" "p-b" "st-c" "v-d" "v-9" "e-e") 14)
     ("references don't count" '(:note "a" :tie "e-25") '("m-1" "p-2" "st-3" "v-4" "a" "e-5") 5))
  (let ((s (apply #'mini-score keys)))
    (ok (equal expected (ids (score-elements s))) label)
    (ok (= counter (score-id-counter s)) label)))

;;; Slice ids -----------------------------------------------------------------

(deftest slice-ids
  (ok (equal "m-3.p-4" (slice-id "m-3" "p-4")))
  (ok (equal "bar-one.Tenor" (slice-id "bar-one" "Tenor")))
  (ok (null (valid-id-p (slice-id "m-3" "p-4"))) "no element can have a slice id")
  (ok (signals-type (lambda () (slice-id "m-3" "a.b")) 'type-error))
  (ok (signals-type (lambda () (slice-id nil "p-4")) 'type-error))
  (ok (signals-type (lambda () (slice-id "m-3" :p-4)) 'type-error)))

(deftest-parametrize find-slice-finds-measure-and-element
    ((measure element)
     ("m-1" "p-4") ("m-2" "p-h") ("m-3" "st-j") ("m-2" "v-13") ("m-1" "v-6"))
  (let ((s (fixture-score "sc0-keyboard")))
    (multiple-value-bind (m e) (find-slice s (slice-id measure element))
      (ok (eq (find-element s measure) m))
      (ok (eq (find-element s element) e)))))

(deftest-parametrize find-slice-rejects
    ((text)
     ("m-2.e-c") ("m-2.m-3") ("p-h.m-2") ("e-8.p-h") ("m-9.p-h") ("m-2.p-zz") ("m-2") ("p-h")
     ("m-2.p-h.st-j") (".p-h") ("m-2.") (""))
  (let ((s (fixture-score "sc0-keyboard")))
    (ok (null (find-slice s text :errorp nil)) text)
    (ok (equal text (let ((c (signalled (lambda () (find-slice s text)))))
                      (and (typep c 'unknown-element) (unknown-element-id c))))
        text)
    (ok (eq :none (handler-bind ((unknown-element (lambda (c) (use-value :none c))))
                    (find-slice s text)))
        text)))

;;; Stability ---------------------------------------------------------------

(deftest copy-score-keeps-ids-and-shares-structure
  (let* ((s (fixture-score "sc0-keyboard"))
         (c (copy-score s)))
    (ok (score-equal s c))
    (ok (= (score-id-counter s) (score-id-counter c)))
    (ok (equal (ids (score-elements s)) (ids (score-elements c))))
    (ok (eq (fset:@ (score-parts s) 1) (fset:@ (score-parts c) 1))
        "an element that had its id is the same object")
    (ok (eq (fset:@ (score-measure-map s) 0) (fset:@ (score-measure-map c) 0)))
    (ok (eq (find-element s "n-w") (find-element c "n-w")))))

(deftest copy-score-mints-from-the-counter
  (let* ((s (fixture-score "sc0-pickup"))
         (n (score-id-counter s))
         (anchor (make-chord-symbol-anchor :position '(1 . 0)
                                           :symbol (make-chord-symbol :root (pc "G")
                                                                      :quality :major)))
         (c (copy-score s :chord-symbols (list anchor))))
    (ok (= 26 n))
    (ok (equal "h-r" (element-id (fset:@ (score-chord-symbols c) 0))))
    (ok (= 27 (score-id-counter c)))
    (ok (null (element-id anchor)) "the argument itself is not changed")
    (ok (equal (ids (score-elements s)) (remove "h-r" (ids (score-elements c)) :test #'string=)))))

(deftest a-new-element-inside-an-old-one
  ;; Put an id-less grace note in front of bar 1 of the pickup fixture's voice.
  (let* ((s (fixture-score "sc0-pickup"))
         (part (fset:@ (score-parts s) 0))
         (voice (first (part-voices part)))
         (grace (make-note-event :pitch (p "A4") :duration 1/8 :grace :acciaccatura))
         (measures (fset:with (voice-measures voice) 1
                              (fset:with-first (fset:@ (voice-measures voice) 1) grace)))
         (new-voice (make-voice :id (element-id voice) :measures measures))
         (new-part (make-part :id (element-id part) :name (part-name part)
                              :staves (part-staves part) :voices (list new-voice)))
         (c (copy-score s :parts (list new-part))))
    (ok (equal "e-r" (element-id (find-element c "e-r"))))
    (ok (typep (find-element c "e-r") 'note-event))
    (ok (eq (find-element c "v-8") (element-parent c "e-r")))
    (ok (equal '(1 . 0) (element-position c "e-r")))
    (ok (equal (ids (score-elements s)) (remove "e-r" (ids (score-elements c)) :test #'string=))
        "every other element keeps its id")
    (ok (eq (find-element s "e-d") (find-element c "e-d")) "untouched events are shared")))

(deftest serials-are-never-reused
  (let* ((s (fixture-score "sc0-pickup"))
         (without (copy-score s :spanners '()))
         (slur (make-spanner :kind :slur :start "e-d" :end "e-f"))
         (again (copy-score without :spanners (list slur))))
    (ok (null (find-element without "sp-q" :errorp nil)))
    (ok (= 26 (score-id-counter without)) "removing an element keeps the counter")
    (ok (equal "sp-r" (element-id (fset:@ (score-spanners again) 0))))
    (ok (not (score-equal s again)))))

(deftest serialization-keeps-ids-and-the-counter
  (let* ((s (copy-score (fixture-score "sc0-pickup") :spanners '()))
         (back (sexp-to-score (score-to-sexp s)))
         (slur (make-spanner :kind :slur :start "e-d" :end "e-f")))
    (ok (= 26 (getf (rest (score-to-sexp s)) :id-counter)))
    (ok (= 26 (score-id-counter back)))
    (ok (equal (ids (score-elements s)) (ids (score-elements back))))
    (ok (score-equal s back))
    (ok (equal (element-id (fset:@ (score-spanners (copy-score s :spanners (list slur))) 0))
               (element-id (fset:@ (score-spanners (copy-score back :spanners (list slur))) 0)))
        "the copy mints the same next id as the original")))

;;; Lookups -----------------------------------------------------------------

(deftest unknown-ids
  (let ((s (fixture-score "sc0-jumps")))
    (ok (signals (find-element s "nope") 'unknown-element))
    (let ((c (signalled (lambda () (find-element s "nope")))))
      (ok (typep c 'score-error))
      (ok (equal "nope" (unknown-element-id c))))
    (ok (null (find-element s "nope" :errorp nil)))
    (ok (eq :fallback (handler-bind ((unknown-element (lambda (c) (use-value :fallback c))))
                        (find-element s "nope"))))
    (ok (signals (element-parent s "nope") 'unknown-element))
    (ok (signals (element-position s "nope") 'unknown-element))
    (ok (eq :here (handler-bind ((unknown-element (lambda (c) (use-value :here c))))
                    (element-position s "nope"))))))

(deftest duplicate-ids-find-the-first
  (let ((s (sexp-to-score
            '(:score :measures ((:measure :id "m" :time "2/4" :key "C major"))
              :parts ((:part :id "p" :staves ((:staff :id "s"))
                       :voices ((:voice :id "v"
                                 :measures (((:note :id "dup" :pitch "C4" :duration 1/4)
                                             (:note :id "dup" :pitch "D4" :duration 1/4)))))))))))
    (ok (equalp (p "C4") (note-pitch (find-element s "dup"))))
    (ok (equal '(1 . 0) (element-position s "dup")))))

(deftest-parametrize element-parents
    ((name id parent)
     ("sc0-keyboard" "n-m" "e-l")
     ("sc0-keyboard" "e-l" "v-k")
     ("sc0-keyboard" "v-k" "p-h")
     ("sc0-keyboard" "st-j" "p-h")
     ("sc0-keyboard" "e-15" "v-13")
     ("sc0-keyboard" "p-h" nil)
     ("sc0-keyboard" "m-2" nil)
     ("sc0-keyboard" "sp-1c" nil)
     ("sc0-pickup" "ly-e" "e-d")
     ("sc0-chords-under-rests" "h-o" nil))
  (let ((s (fixture-score name)))
    (ok (equal parent (let ((e (element-parent s id))) (and e (element-id e)))))))

(deftest-parametrize parents-match-the-tree
    ((name) :rows +fixture-scores+)
  ;; Walk the tree with the accessors and compare every parent link.
  (let* ((s (fixture-score name))
         (expected '()))
    (fset:do-seq (part (score-parts s))
      (dolist (staff (part-staves part)) (push (cons staff part) expected))
      (dolist (voice (part-voices part))
        (push (cons voice part) expected)
        (fset:do-seq (vm (voice-measures voice))
          (fset:do-seq (event vm)
            (push (cons event voice) expected)
            (when (typep event 'chord-event)
              (dolist (n (chord-event-notes event)) (push (cons n event) expected)))
            (dolist (l (event-lyrics event)) (push (cons l event) expected))))))
    (ok (every (lambda (pair) (eq (cdr pair) (element-parent s (element-id (car pair)))))
               expected))
    (ok (every (lambda (e) (null (element-parent s (element-id e))))
               (append (seq-list (score-measure-map s)) (seq-list (score-parts s))
                       (seq-list (score-chord-symbols s)) (seq-list (score-spanners s)))))))
