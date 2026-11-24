;;;; SC0: CHECK-SCORE catches each class of bad score, VALIDATE-SCORE and its
;;;; restart, and the uncertainty report. Rules: src/check.lisp and
;;;; src/score.lisp. The issue rows follow those rules and were checked against
;;;; a separate reference implementation; sc0-uncertain.sexp was computed by
;;;; generate-sc0.py from the fixture forms.

(in-package #:score-protocol/tests)

;;; Score forms for the issue rows. The base score: two 4/4 bars, one part
;;; "p-1" with staff "st-1" and voice "v-1": C4 D4 halves ("a" "b"), then E4 whole
;;; ("c").

(defun nf (id pitch duration &rest keys) `(:note :id ,id :pitch ,pitch :duration ,duration ,@keys))
(defun rf (id duration &rest keys) `(:rest :id ,id :duration ,duration ,@keys))
(defun vf (id measures &rest keys) `(:voice :id ,id ,@keys :measures ,measures))

(defparameter +two-bars+
  '((:measure :id "m-1" :time "4/4" :key "C major") (:measure :id "m-2")))

(defun base-measures ()
  (list (list (nf "a" "C4" 1/2) (nf "b" "D4" 1/2)) (list (nf "c" "E4" 1))))

(defun sf (&key (measures +two-bars+) (voices (list (vf "v-1" (base-measures))))
                (staves '((:staff :id "st-1"))) parts chord-symbols spanners)
  `(:score :measures ,measures
           :parts ,(or parts `((:part :id "p-1" :staves ,staves :voices ,voices)))
           :chord-symbols ,chord-symbols :spanners ,spanners))

(defun slur (start end &optional (kind :slur))
  `((:spanner :id "s" :kind ,kind :start ,start :end ,end)))

(defun chord-symbol-at (id bar offset)
  `(:chord-symbol :id ,id :bar ,bar :offset ,offset :symbol (:root "C" :quality :major)))

(deftest-parametrize check-score-issues
    ((label form expected)
     ("the base score is valid" (sf) '())
     ;; Ids
     ("two notes with one id"
      (sf :voices (list (vf "v-1" (list (list (nf "a" "C4" 1/2) (nf "a" "D4" 1/2))
                                       (list (nf "c" "E4" 1))))))
      '((:duplicate-id "a" nil)))
     ("a measure and a note with one id"
      (sf :measures '((:measure :id "c" :time "4/4" :key "C major") (:measure :id "m-2")))
      '((:duplicate-id "c" nil)))
     ;; Measure map
     ("no key in the first measure"
      (sf :measures '((:measure :id "m-1" :time "4/4") (:measure :id "m-2")))
      '((:missing-signature "m-1" 1)))
     ("no time in the first measure"
      (sf :measures '((:measure :id "m-1" :key "C major") (:measure :id "m-2")))
      '((:missing-signature "m-1" 1)))
     ("a pickup without a length"
      (sf :measures '((:measure :id "m-1" :time "4/4" :key "C major" :pickup t) (:measure :id "m-2")))
      '((:bad-pickup "m-1" 0)))
     ("a pickup as long as the bar"
      (sf :measures '((:measure :id "m-1" :time "4/4" :key "C major" :pickup t :length 1)
                      (:measure :id "m-2")))
      '((:bad-pickup "m-1" 0)))
     ("a pickup flag on a later measure"
      (sf :measures '((:measure :id "m-1" :time "4/4" :key "C major")
                      (:measure :id "m-2" :pickup t)))
      '((:bad-pickup "m-2" 2)))
     ("a valid pickup"
      (sf :measures '((:measure :id "m-1" :time "4/4" :key "C major" :pickup t :length 1/4)
                      (:measure :id "m-2"))
          :voices (list (vf "v-1" (list (list (nf "a" "G3" 1/4)) (list (nf "c" "C4" 1))))))
      '())
     ;; Voices and measures
     ("a voice on a staff its part lacks"
      (sf :voices (list (vf "v-1" (base-measures) :staff 2)))
      '((:voice-staff "v-1" nil)))
     ("a voice on the second of two staves"
      (sf :staves '((:staff :id "st-1") (:staff :id "st-2" :clef :bass))
          :voices (list (vf "v-1" (base-measures) :staff 2)))
      '())
     ("too few voice measures"
      (sf :voices (list (vf "v-1" (list (list (nf "a" "C4" 1/2) (nf "b" "D4" 1/2))))))
      '((:measure-count "v-1" nil)))
     ("too many voice measures"
      (sf :voices (list (vf "v-1" (append (base-measures) (list (list (nf "d" "F4" 1/2)))))))
      '((:measure-count "v-1" nil)))
     ("an underfull measure"
      (sf :voices (list (vf "v-1" (list (list (nf "a" "C4" 1/2) (nf "b" "D4" 1/4))
                                       (list (nf "c" "E4" 1))))))
      '((:measure-duration "v-1" 1)))
     ("an overfull measure"
      (sf :voices (list (vf "v-1" (list (list (nf "a" "C4" 1/2) (nf "b" "D4" 1/2))
                                       (list (nf "c" "E4" 1) (nf "d" "F4" 1/4))))))
      '((:measure-duration "v-1" 2)))
     ("two bad measures in two voices"
      (sf :voices (list (vf "v-1" (list (list (nf "a" "C4" 1/2)) (list (nf "c" "E4" 1))))
                        (vf "v-2" (list (list (nf "d" "C4" 1)) (list (nf "e" "E4" 3/4))))))
      '((:measure-duration "v-1" 1) (:measure-duration "v-2" 2)))
     ("grace notes, hidden rests and silent voice measures"
      (sf :voices (list (vf "v-1" (list (list (nf "g" "B3" 1/8 :grace :acciaccatura)
                                             (nf "a" "C4" 1/2) (nf "b" "D4" 1/2))
                                       (list (nf "c" "E4" 1))))
                        (vf "v-2" (list '() (list (rf "h" 1/2 :hidden t) (nf "d" "C4" 1/2)))
                            :stem :down)))
      '())
     ("a measure flagged incomplete"
      (sf :measures '((:measure :id "m-1" :time "4/4" :key "C major") (:measure :id "m-2" :length 1/2))
          :voices (list (vf "v-1" (list (list (nf "a" "C4" 1/2) (nf "b" "D4" 1/2))
                                       (list (nf "c" "E4" 1/2))))))
      '())
     ("a full bar in a measure flagged incomplete"
      (sf :measures '((:measure :id "m-1" :time "4/4" :key "C major") (:measure :id "m-2" :length 1/2)))
      '((:measure-duration "v-1" 2)))
     ;; Events
     ("a five-sixteenth note"
      (sf :voices (list (vf "v-1" (list (list (nf "a" "C4" 5/16) (nf "b" "D4" 3/16)
                                             (nf "x" "E4" 1/2))
                                       (list (nf "c" "E4" 1))))))
      '((:unnotatable-duration "a" 1)))
     ("triplets without their tuplet"
      (sf :voices (list (vf "v-1" (list (list (nf "a" "C4" 1/12) (nf "b" "D4" 1/12)
                                             (nf "x" "E4" 1/12) (nf "y" "F4" 3/4))
                                       (list (nf "c" "E4" 1))))))
      '((:unnotatable-duration "a" 1) (:unnotatable-duration "b" 1)
        (:unnotatable-duration "x" 1)))
     ("triplets with their tuplet"
      (sf :voices (list (vf "v-1" (list (list (nf "a" "C4" 1/12 :tuplet 3/2)
                                             (nf "b" "D4" 1/12 :tuplet 3/2)
                                             (nf "x" "E4" 1/12 :tuplet 3/2) (nf "y" "F4" 3/4))
                                       (list (nf "c" "E4" 1))))))
      '())
     ("a measure rest of any length"
      (sf :measures '((:measure :id "m-1" :time "4/4" :key "C major") (:measure :id "m-2" :length 5/8))
          :voices (list (vf "v-1" (list (list (nf "a" "C4" 1/2) (nf "b" "D4" 1/2))
                                       (list (rf "r" 5/8 :measure-rest t))))))
      '())
     ("a plain rest of five eighths"
      (sf :measures '((:measure :id "m-1" :time "4/4" :key "C major") (:measure :id "m-2" :length 5/8))
          :voices (list (vf "v-1" (list (list (nf "a" "C4" 1/2) (nf "b" "D4" 1/2))
                                       (list (rf "r" 5/8))))))
      '((:unnotatable-duration "r" 2)))
     ("a chord of one note"
      (sf :voices (list (vf "v-1" (list (list (nf "a" "C4" 1/2) (nf "b" "D4" 1/2))
                                       (list '(:chord :id "c" :notes ((:chord-note :id "cn" :pitch "E4"))
                                               :duration 1))))))
      '((:degenerate-chord "c" 2)))
     ("a chord of no notes"
      (sf :voices (list (vf "v-1" (list (list (nf "a" "C4" 1/2) (nf "b" "D4" 1/2))
                                       (list '(:chord :id "c" :notes () :duration 1))))))
      '((:degenerate-chord "c" 2)))
     ;; Lyrics
     ("a lyric on a rest"
      (sf :voices (list (vf "v-1" (list (list (nf "a" "C4" 1/2) (nf "b" "D4" 1/2))
                                       (list (rf "c" 1 :lyrics '((:lyric :id "ly" :text "oh"))))))))
      '((:misplaced-lyric "ly" 2)))
     ("a lyric on a grace note"
      (sf :voices (list (vf "v-1" (list (list (nf "g" "B3" 1/8 :grace :appoggiatura
                                                 :lyrics '((:lyric :id "lg" :text "ah")))
                                             (nf "a" "C4" 1/2) (nf "b" "D4" 1/2))
                                       (list (nf "c" "E4" 1))))))
      '((:misplaced-lyric "lg" 1)))
     ("two lyrics of one verse"
      (sf :voices (list (vf "v-1" (list (list (nf "a" "C4" 1/2 :lyrics '((:lyric :id "l1" :text "x")
                                                                        (:lyric :id "l2" :text "y")))
                                             (nf "b" "D4" 1/2))
                                       (list (nf "c" "E4" 1))))))
      '((:duplicate-verse "a" 1)))
     ("lyrics of three verses"
      (sf :voices (list (vf "v-1" (list (list (nf "a" "C4" 1/2 :lyrics '((:lyric :id "l1" :text "x")
                                                                        (:lyric :id "l2" :verse 2 :text "y")
                                                                        (:lyric :id "l3" :verse 3 :text "z")))
                                             (nf "b" "D4" 1/2))
                                       (list (nf "c" "E4" 1))))))
      '())
     ;; Ties
     ("a tie across the barline"
      (sf :voices (list (vf "v-1" (list (list (nf "a" "C4" 1/2) (nf "b" "D4" 1/2 :tie "c"))
                                       (list (nf "c" "D4" 1))))))
      '())
     ("a tie to a missing note"
      (sf :voices (list (vf "v-1" (list (list (nf "a" "C4" 1/2) (nf "b" "D4" 1/2 :tie "zz"))
                                       (list (nf "c" "E4" 1))))))
      '((:tie-target "b" 1)))
     ("a tie to a rest"
      (sf :voices (list (vf "v-1" (list (list (nf "a" "C4" 1/2) (nf "b" "D4" 1/2 :tie "c"))
                                       (list (rf "c" 1))))))
      '((:tie-target "b" 1)))
     ("a tie to a measure"
      (sf :voices (list (vf "v-1" (list (list (nf "a" "C4" 1/2) (nf "b" "D4" 1/2 :tie "m-2"))
                                       (list (nf "c" "E4" 1))))))
      '((:tie-target "b" 1)))
     ("a tie to a note that doesn't follow"
      (sf :voices (list (vf "v-1" (list (list (nf "a" "C4" 1/2 :tie "c") (nf "b" "D4" 1/2))
                                       (list (nf "c" "C4" 1))))))
      '((:tie-target "a" 1)))
     ("a tie to a note in another voice"
      (sf :voices (list (vf "v-1" (list (list (nf "a" "C4" 1/2) (nf "b" "D4" 1/2 :tie "d"))
                                       (list (nf "c" "E4" 1))))
                        (vf "v-2" (list (list (rf "h" 1 :hidden t)) (list (nf "d" "D4" 1))))))
      '((:tie-target "b" 1)))
     ("a tie between different pitches"
      (sf :voices (list (vf "v-1" (list (list (nf "a" "C4" 1/2) (nf "b" "D4" 1/2 :tie "c"))
                                       (list (nf "c" "E4" 1))))))
      '((:tie-pitch "b" 1)))
     ("a tie between enharmonic spellings"
      (sf :voices (list (vf "v-1" (list (list (nf "a" "C4" 1/2) (nf "b" "C#4" 1/2 :tie "c"))
                                       (list (nf "c" "Db4" 1))))))
      '((:tie-pitch "b" 1)))
     ("a tie between different pitches that don't follow"
      (sf :voices (list (vf "v-1" (list (list (nf "a" "C4" 1/2 :tie "c") (nf "b" "D4" 1/2))
                                       (list (nf "c" "E4" 1))))))
      '((:tie-target "a" 1) (:tie-pitch "a" 1)))
     ("two ties into one note"
      (sf :voices (list (vf "v-1" (list (list (nf "a" "C4" 1/2)
                                             '(:chord :id "ch" :notes ((:chord-note :id "n-1" :pitch "C4" :tie "c")
                                                                       (:chord-note :id "n-2" :pitch "C4" :tie "c"))
                                               :duration 1/2))
                                       (list (nf "c" "C4" 1))))))
      '((:tie-target "n-2" 1)))
     ("chord notes tied across the barline"
      (sf :voices (list (vf "v-1" (list (list (nf "a" "C4" 1/2)
                                             '(:chord :id "ch" :notes ((:chord-note :id "n-1" :pitch "C4" :tie "n-3")
                                                                       (:chord-note :id "n-2" :pitch "E4" :tie "n-4"))
                                               :duration 1/2))
                                       (list '(:chord :id "c" :notes ((:chord-note :id "n-3" :pitch "C4")
                                                                      (:chord-note :id "n-4" :pitch "E4"))
                                               :duration 1))))))
      '())
     ("a tie from a grace note"
      (sf :voices (list (vf "v-1" (list (list (nf "g" "C4" 1/8 :grace :acciaccatura :tie "a")
                                             (nf "a" "C4" 1/2) (nf "b" "D4" 1/2))
                                       (list (nf "c" "E4" 1))))))
      '((:tie-target "g" 1)))
     ;; Spanners
     ("a slur to a missing event" (sf :spanners (slur "a" "zz")) '((:spanner-endpoint "s" nil)))
     ("a slur from a measure" (sf :spanners (slur "m-1" "c")) '((:spanner-endpoint "s" nil)))
     ("a slur to a chord note"
      (sf :voices (list (vf "v-1" (list (list (nf "a" "C4" 1/2)
                                             '(:chord :id "ch" :notes ((:chord-note :id "n-1" :pitch "C4")
                                                                       (:chord-note :id "n-2" :pitch "E4"))
                                               :duration 1/2))
                                       (list (nf "c" "E4" 1)))))
          :spanners (slur "a" "n-1"))
      '((:spanner-endpoint "s" nil)))
     ("a slur to a rest"
      (sf :voices (list (vf "v-1" (list (list (nf "a" "C4" 1/2) (nf "b" "D4" 1/2)) (list (rf "c" 1)))))
          :spanners (slur "a" "c"))
      '((:spanner-endpoint "s" nil)))
     ("a hairpin to a rest"
      (sf :voices (list (vf "v-1" (list (list (nf "a" "C4" 1/2) (nf "b" "D4" 1/2)) (list (rf "c" 1)))))
          :spanners (slur "a" "c" :diminuendo))
      '())
     ("a slur across parts"
      (sf :parts `((:part :id "p-1" :staves ((:staff :id "st-1")) :voices (,(vf "v-1" (base-measures))))
                   (:part :id "p-2" :staves ((:staff :id "st-2"))
                    :voices (,(vf "v-2" (list (list (nf "d" "C5" 1)) (list (nf "e" "C5" 1)))))))
          :spanners (slur "a" "e"))
      '((:spanner-endpoint "s" nil)))
     ("a slur to an event past the map"
      (sf :voices (list (vf "v-1" (append (base-measures) (list (list (nf "d" "F4" 1))))))
          :spanners (slur "a" "d"))
      '((:measure-count "v-1" nil) (:spanner-endpoint "s" nil)))
     ("a slur between voices of one part"
      (sf :voices (list (vf "v-1" (base-measures))
                        (vf "v-2" (list (list (nf "d" "G3" 1)) (list (nf "e" "G3" 1)))))
          :spanners (slur "d" "c"))
      '())
     ("a slur that runs backwards" (sf :spanners (slur "c" "a")) '((:spanner-order "s" nil)))
     ("a slur on one note" (sf :spanners (slur "a" "a")) '((:spanner-order "s" nil)))
     ("a hairpin on one note" (sf :spanners (slur "a" "a" :crescendo)) '())
     ("a slur from a grace note to its main note"
      (sf :voices (list (vf "v-1" (list (list (nf "g" "B3" 1/8 :grace :acciaccatura)
                                             (nf "a" "C4" 1/2) (nf "b" "D4" 1/2))
                                       (list (nf "c" "E4" 1)))))
          :spanners (slur "g" "a"))
      '())
     ("a slur from a main note back to its grace note"
      (sf :voices (list (vf "v-1" (list (list (nf "g" "B3" 1/8 :grace :acciaccatura)
                                             (nf "a" "C4" 1/2) (nf "b" "D4" 1/2))
                                       (list (nf "c" "E4" 1)))))
          :spanners (slur "a" "g"))
      '((:spanner-order "s" nil)))
     ("a slur between voices at one onset"
      (sf :voices (list (vf "v-1" (base-measures))
                        (vf "v-2" (list (list (nf "d" "G3" 1)) (list (nf "e" "G3" 1)))))
          :spanners (slur "a" "d"))
      '((:spanner-order "s" nil)))
     ;; Chord symbols
     ("chord symbols inside the bars"
      (sf :chord-symbols (list (chord-symbol-at "h-1" 1 0) (chord-symbol-at "h-2" 1 3/4)
                               (chord-symbol-at "h-3" 2 1/3)))
      '())
     ("a chord symbol past the last bar"
      (sf :chord-symbols (list (chord-symbol-at "h-1" 3 0)))
      '((:chord-symbol-position "h-1" nil)))
     ("a chord symbol at the end of a bar"
      (sf :chord-symbols (list (chord-symbol-at "h-1" 1 1)))
      '((:chord-symbol-position "h-1" nil)))
     ("a chord symbol in bar 0 without a pickup"
      (sf :chord-symbols (list (chord-symbol-at "h-1" 0 0)))
      '((:chord-symbol-position "h-1" nil)))
     ("two chord symbols at one position"
      (sf :chord-symbols (list (chord-symbol-at "h-1" 1 1/2) (chord-symbol-at "h-2" 1 1/2)))
      '((:chord-symbol-position "h-2" nil)))
     ;; Several at once
     ("a missing key and an underfull bar"
      (sf :measures '((:measure :id "m-1" :time "4/4") (:measure :id "m-2"))
          :voices (list (vf "v-1" (list (list (nf "a" "C4" 1/2)) (list (nf "c" "E4" 1))))))
      '((:missing-signature "m-1" 1) (:measure-duration "v-1" 1))))
  (let ((issues (check-score (sexp-to-score form))))
    (ok (every #'score-issue-p issues) label)
    (ok (equal (sorted-triples expected) (issue-triples issues)) label)))

(deftest issue-details
  (let ((count (first (check-score
                       (sexp-to-score
                        (sf :voices (list (vf "v-1" (list (list (nf "a" "C4" 1)))))))))))
    (ok (eq :measure-count (score-issue-kind count)))
    (ok (equal '(:expected 2 :actual 1) (score-issue-detail count))))
  (let ((duration (first (check-score
                          (sexp-to-score
                           (sf :voices (list (vf "v-1" (list (list (nf "a" "C4" 1/2) (nf "b" "D4" 1/4))
                                                            (list (nf "c" "E4" 1)))))))))))
    (ok (eq :measure-duration (score-issue-kind duration)))
    (ok (equal '(:expected 1 :actual 3/4) (score-issue-detail duration))))
  (let ((pitch (first (check-score
                       (sexp-to-score
                        (sf :voices (list (vf "v-1" (list (list (nf "a" "C4" 1/2) (nf "b" "D4" 1/2 :tie "c"))
                                                         (list (nf "c" "E4" 1)))))))))))
    (ok (eq :tie-pitch (score-issue-kind pitch)))
    (ok (null (score-issue-detail pitch)))))

(deftest-parametrize fixtures-are-valid
    ((name) :rows +fixture-scores+)
  (let ((s (fixture-score name)))
    (ok (null (check-score s)) name)
    (ok (eq s (validate-score s)) name)))

(deftest validate-score-signals-and-continues
  (let* ((s (sexp-to-score (sf :voices (list (vf "v-1" (list (list (nf "a" "C4" 1/2))
                                                            (list (nf "c" "E4" 1))))))))
         (c (signalled (lambda () (validate-score s)))))
    (ok (typep c 'score-invariant-violation))
    (ok (typep c 'score-error))
    (ok (equal '((:measure-duration "v-1" 1))
               (and (typep c 'score-invariant-violation)
                    (issue-triples (score-invariant-violation-issues c)))))
    (ok (eq s (handler-bind ((score-invariant-violation (lambda (c) (continue c))))
                (validate-score s)))
        "CONTINUE returns the score as it is")))

;;; The uncertainty report ------------------------------------------------------

(deftest uncertainty-fixtures
  (let* ((rows (fixture "sc0-uncertain.sexp"))
         (bad (collect-mismatches (row rows)
                (destructuring-bind (name below expected) row
                  (equal expected (ids (uncertain-elements (fixture-score name) :below below)))))))
    (ok (= 90 (length rows)))
    (ok (null bad) (report bad))))

(deftest uncertainty-default-threshold
  (let ((s (fixture-score "sc0-omr-result")))
    (ok (equal '("m-3" "e-9" "ly-a" "e-d" "n-f" "e-h" "h-j" "sp-l") (ids (uncertain-elements s)))
        "below 0.8 by default, and 0.8 itself is not below it")
    (ok (every (lambda (e) (typep e 'element)) (uncertain-elements s)))
    (ok (null (uncertain-elements (fixture-score "sc0-satb") :below 2))
        "no recorded confidence counts as certain")))
