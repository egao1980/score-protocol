;;;; SC1: edits of the measure map (keys, re-barring, measures inserted, deleted
;;;; and replaced) and transposition. Rules: src/edit-measures.lisp. The
;;;; transposition rows of sc1-transposed.sexp come from music21 10.5.2
;;;; (generate-sc1.py); the other expected values follow the rules and were
;;;; checked against a separate reference implementation.

(in-package #:score-protocol/tests)

;;; Four whole notes in 4/4, for re-barring. Counter 10: minting from "b".

(defparameter +four-bars+
  '(:score
    :id-counter 10
    :measures ((:measure :id "m1" :time "4/4" :key "C major"
                :tempo ((:tempo-mark :id "tm" :bpm 96 :beat-unit 1/4)))
               (:measure :id "m2") (:measure :id "m3") (:measure :id "m4" :barline :final))
    :parts ((:part :id "p1" :staves ((:staff :id "s1"))
             :voices ((:voice :id "v1"
                       :measures (((:note :id "c" :pitch "C4" :duration 1))
                                  ((:note :id "d" :pitch "D4" :duration 1))
                                  ((:note :id "e" :pitch "E4" :duration 1))
                                  ((:note :id "f" :pitch "F4" :duration 1 :fermata (:fermata :id "ff"))))))))
    :chord-symbols ((:chord-symbol :id "h1" :bar 2 :offset 1/2 :symbol (:root "G" :quality :major))
                    (:chord-symbol :id "h2" :bar 4 :offset 0 :symbol (:root "C" :quality :major)))))

(defun four-bars () (sexp-to-score +four-bars+))

(defun bar-lengths (score)
  (loop for bar from (score-first-bar score) to (score-last-bar score)
        collect (bar-length score bar)))

;;; Re-barring ----------------------------------------------------------------

(deftest rebar-4/4-to-3/4
  (multiple-value-bind (score lists) (edit (four-bars) '(:set-time :measure "m1" :time "3/4"))
    (ok (equal (expand-user
                '(:score
                  :id-counter 22
                  :measures ((:measure :id "m1" :time "3/4" :key "C major"
                              :tempo ((:tempo-mark :id "tm" :bpm 96 :beat-unit 1/4)) :user t)
                             (:measure :id "m-b" :user t) (:measure :id "m-c" :user t)
                             (:measure :id "m-d" :user t) (:measure :id "m4" :user t)
                             (:measure :id "m-e" :length 1/4 :barline :final :user t))
                  :parts ((:part :id "p1" :staves ((:staff :id "s1"))
                           :voices ((:voice :id "v1"
                                     :measures
                                     (((:note :id "c" :pitch "C4" :duration 3/4
                                        :tie (:tie :id "ti-f" :end "e-g" :user t) :user t))
                                      ((:note :id "e-g" :pitch "C4" :duration 1/4 :user t)
                                       (:note :id "d" :pitch "D4" :duration 1/2
                                        :tie (:tie :id "ti-h" :end "e-i" :user t) :user t))
                                      ((:note :id "e-i" :pitch "D4" :duration 1/2 :user t)
                                       (:note :id "e" :pitch "E4" :duration 1/4
                                        :tie (:tie :id "ti-j" :end "e-k" :user t) :user t))
                                      ((:note :id "e-k" :pitch "E4" :duration 3/4 :user t))
                                      ((:note :id "f" :pitch "F4" :duration 3/4
                                        :tie (:tie :id "ti-l" :end "e-m" :user t)
                                        :fermata (:fermata :id "ff") :user t))
                                      ((:note :id "e-m" :pitch "F4" :duration 1/4 :user t)))))))
                  :chord-symbols ((:chord-symbol :id "h1" :bar 3 :offset 0
                                   :symbol (:root "G" :quality :major) :user t)
                                  (:chord-symbol :id "h2" :bar 5 :offset 0
                                   :symbol (:root "C" :quality :major) :user t))))
               (score-to-sexp score))
        "five full bars and a quarter, tied across the new barlines")
    (ok (equal '(("m-b" "m-c" "m-d" "m-e" "ti-f" "e-g" "ti-h" "e-i" "ti-j" "e-k" "ti-l" "e-m")
                 ("m2" "m3")
                 ("m1" "m4" "v1" "c" "d" "e" "f" "h1" "h2"))
               lists))
    (ok (equal '(3/4 3/4 3/4 3/4 3/4 1/4) (bar-lengths score)))
    (ok (= 4 (score-duration score)) "re-barring keeps the music's length")
    (ok (null (check-score score)))
    (multiple-value-bind (back lists) (edit score '(:set-time :measure "m1" :time "4/4"))
      (ok (equal '("m1" "m-n" "m-o" "m4") (measure-ids back)) "and back: m4 starts a bar again")
      (ok (eq :final (measure-info-barline (find-element back "m4"))))
      (ok (equal '(1 1 1 1) (bar-lengths back)))
      (ok (equal '(("m-n" "m-o") ("m-b" "m-c" "m-d" "m-e") ("m1" "m4" "v1" "h1" "h2")) lists)
          "the tied pieces stay: re-barring splits, it never merges")
      (ok (null (check-score back))))))

(deftest-parametrize rebar-cases
    ((label name op lengths changes)
     ("a meter of the same bar length" "sc0-pickup" '(:set-time :measure "m-1" :time "6/8")
      '(1/4 3/4 3/4 3/4 1/2) '(() () ("m-1")))
     ("one bar of 3/4 in 4/4: a short last bar" "sc0-key-change"
      '(:set-time :measure "m-6" :time "4/4")
      '(1 1 1 3/4 3/4 3/4) '(() () ("m-6"))))
  (multiple-value-bind (score lists) (edit (fixture-score name) op)
    (ok (equal lengths (bar-lengths score)) label)
    (ok (equal changes lists) label)
    (ok (null (check-score score)))))

(deftest rebar-refusals
  (ok (typep (condition-of (lambda () (edit (fixture-score "sc0-repeats-voltas")
                                            '(:set-time :measure "m-1" :time "3/4"))))
             'invalid-edit)
      "re-barring would lose an ending")
  (ok (typep (condition-of (lambda () (edit (fixture-score "sc0-jumps")
                                            '(:set-time :measure "m-1" :time "4/4"))))
             'invalid-edit)
      "re-barring would lose a segno")
  (let ((c (condition-of (lambda () (edit (four-bars) '(:set-time :measure "m1"))))))
    (ok (typep c 'edit-breaks-score) "no meter left on the first measure")
    (ok (and (typep c 'edit-breaks-score)
             (equal '((:missing-signature "m1" 1)) (issue-triples (score-invariant-violation-issues c))))))
  (ok (typep (condition-of (lambda () (edit (four-bars) '(:set-time :measure "zz" :time "3/4"))))
             'edit-target-missing)))

;;; Keys ----------------------------------------------------------------------

(deftest set-key-edits
  (multiple-value-bind (score lists) (edit (base) '(:set-key :measure "m2" :key "D major"))
    (ok (equal (expand-user '(:measure :id "m2" :key "D major" :user t)) (form-of score "m2")))
    (ok (equal '(() () ("m2")) lists))
    (ok (equal "D major" (key-name (bar-key score 4))) "the key holds from there on")
    (ok (equal "E4" (pitch-name (note-pitch (find-element score "d")))) "pitches don't change"))
  (multiple-value-bind (score lists) (edit (fixture-score "sc0-key-change") '(:set-key :measure "m-4"))
    (ok (null (measure-info-key (find-element score "m-4"))) "NIL removes the change")
    (ok (equal '(() () ("m-4")) lists)))
  (let ((c (condition-of (lambda () (edit (base) '(:set-key :measure "m1"))))))
    (ok (and (typep c 'edit-breaks-score)
             (equal '((:missing-signature "m1" 1)) (issue-triples (score-invariant-violation-issues c)))))))

;;; Measures inserted, deleted, replaced ---------------------------------------

(deftest-parametrize measure-edits
    ((label op expected changes)
     ("insert a measure: the first voice of the staff gets a rest; the tie across breaks"
      '(:insert-measures :before "m2" :measure-infos ((:measure)))
      '(("m-l" (:measure :id "m-l"))
        ("e-m" (:rest :id "e-m" :duration 1 :measure-rest t :user t))
        ("h2" (:chord-symbol :id "h2" :bar 3 :offset 1/2
               :symbol (:root "G" :quality :dominant-7 :bass "B") :user t)))
      '(("m-l" "e-m") ("tc") ("v1" "c" "v2" "h2")))
     ("insert two at the end"
      '(:insert-measures :measure-infos ((:measure) (:measure)))
      '(("m-m" (:measure :id "m-m")) ("e-o" (:rest :id "e-o" :duration 1 :measure-rest t :user t)))
      '(("m-l" "m-m" "e-n" "e-o") () ("v1" "v2")))
     ("insert a key change: the next measure keeps its key"
      '(:insert-measures :before "m2" :measure-infos ((:measure :key "G major")))
      '(("m2" (:measure :id "m2" :key "C major" :user t)))
      '(("m-l" "e-m") ("tc") ("m2" "v1" "c" "v2" "h2")))
     ("insert before the first measure: it takes the signatures"
      '(:insert-measures :before "m1" :measure-infos ((:measure)))
      '(("m-l" (:measure :id "m-l" :time "4/4" :key "C major" :user t))
        ("m1" (:measure :id "m1" :time "4/4" :key "C major"))
        ("h1" (:chord-symbol :id "h1" :bar 2 :offset 0 :symbol (:root "C" :quality :major) :user t)))
      '(("m-l" "e-m") () ("v1" "v2" "h1" "h2")))
     ("insert with contents"
      '(:insert-measures :before "m2" :measure-infos ((:measure))
        :contents (("v2" ((:note :pitch "G3" :duration 1)))))
      '(("e-n" (:note :id "e-n" :pitch "G3" :duration 1)))
      '(("m-l" "e-m" "e-n") ("tc") ("v1" "c" "v2" "h2")))
     ("delete a measure: its music, its anchors, the tie into it"
      '(:delete-measures :measure "m2")
      '(("c" (:note :id "c" :pitch "E4" :duration 1/2)))
      '(() ("m2" "tc" "d" "f" "r1" "r2" "h2") ("v1" "c" "v2")))
     ("delete the first measure: the next takes the signatures"
      '(:delete-measures :measure "m1")
      '(("m2" (:measure :id "m2" :time "4/4" :key "C major" :user t))
        ("h2" (:chord-symbol :id "h2" :bar 1 :offset 1/2
               :symbol (:root "G" :quality :dominant-7 :bass "B") :user t)))
      '(() ("m1" "a" "la" "b" "c" "tc" "h1" "sl") ("m2" "v1" "v2" "h2")))
     ("delete the last two" '(:delete-measures :measure "m3" :count 2)
      '()
      '(() ("m3" "m4" "g" "fg" "r3" "r4") ("v1" "v2")))
     ("replace a measure" '(:replace-measure :id "m3" :measure-info (:measure :id "m3" :barline :double))
      '(("m3" (:measure :id "m3" :barline :double)))
      '(() () ("m3")))
     ("replace a measure: new marks are minted"
      '(:replace-measure :id "m2" :measure-info (:measure :rehearsal (:rehearsal :text "B")))
      '(("m2" (:measure :id "m2" :rehearsal (:rehearsal :id "rh-l" :text "B"))))
      '(("rh-l") () ("m2"))))
  (multiple-value-bind (score lists) (edit (base) op)
    (ok (equal changes lists) label)
    (ok (expect-forms score expected) label)
    (ok (null (check-score score)) "the result is valid")))

(deftest measure-edits-on-fixtures
  (multiple-value-bind (score lists) (edit (fixture-score "sc0-key-change") '(:delete-measures :measure "m-4"))
    (ok (equal "D major" (key-name (measure-info-key (find-element score "m-6"))))
        "the measure after keeps the key it had")
    (ok (equal '(() ("m-4" "rh-5" "e-l" "e-m" "e-n") ("m-6" "v-e")) lists))
    (ok (null (check-score score))))
  (let ((score (edit (fixture-score "sc0-pickup")
                     '(:composite :ops ((:add-chord-symbol
                                         :anchor (:chord-symbol :bar 2 :offset 0
                                                  :symbol (:root "C" :quality :major)))
                                        (:delete-measures :measure "m-1"))))))
    (ok (= 1 (score-first-bar score)) "without its pickup the score starts at bar 1")
    (ok (equal '((2 . 0)) (mapcar #'anchor-position (seq-list (score-chord-symbols score))))
        "an anchor stays with its measure: bar 2 is still bar 2")
    (ok (equal '("3/4" "G major") (list (meter-string (measure-info-time (find-element score "m-3")))
                                        (key-name (measure-info-key (find-element score "m-3")))))
        "the new first measure takes the signatures")
    (ok (null (check-score score)))))

(deftest-parametrize measure-refusals
    ((label op type slots)
     ("insert before a missing measure" '(:insert-measures :before "zz" :measure-infos ((:measure)))
      'edit-target-missing '(:id "zz"))
     ("contents for a missing voice"
      '(:insert-measures :before "m2" :measure-infos ((:measure)) :contents (("v9" ())))
      'edit-target-missing '(:id "v9"))
     ("contents of the wrong length"
      '(:insert-measures :before "m2" :measure-infos ((:measure)) :contents (("v2" () ())))
      'invalid-edit '())
     ("delete past the end" '(:delete-measures :measure "m3" :count 3)
      'edit-position-invalid '(:position 5))
     ("delete a missing measure" '(:delete-measures :measure "zz") 'edit-target-missing '(:id "zz"))
     ("replace with another id"
      '(:replace-measure :id "m3" :measure-info (:measure :id "m2")) 'invalid-edit '())
     ("replace a measure with a shorter one"
      '(:replace-measure :id "m3" :measure-info (:measure :length 1/2))
      'edit-breaks-score '(:issues ((:measure-duration "v1" 3))))
     ("replace an event as a measure"
      '(:replace-measure :id "a" :measure-info (:measure)) 'invalid-edit '()))
  (let ((c (condition-of (lambda () (edit (base) op)))))
    (ok (typep c type) label)
    (when slots
      (ok (and (typep c type)
               (loop for (key value) on slots by #'cddr
                     always (equal value (ecase key
                                           (:id (unknown-element-id c))
                                           (:position (invalid-position-position c))
                                           (:issues (issue-triples
                                                     (score-invariant-violation-issues c)))))))
          label))))

;;; Transposition ---------------------------------------------------------------

(defun note-pitches (score)
  "(id pitch-name) for every note event and chord note of SCORE, in document order."
  (loop for e in (score-elements score)
        when (typep e '(or note-event chord-note))
          collect (list (element-id e) (pitch-name (note-pitch e)))))

(defun own-keys (score)
  (loop for m in (seq-list (score-measure-map score))
        when (measure-info-key m) collect (list (element-id m) (key-name (measure-info-key m)))))

(defun anchor-roots (score)
  "(id root bass) of every anchor, pitch-class strings or NIL; N.C. is (id nil nil)."
  (loop for a in (seq-list (score-chord-symbols score))
        for s = (anchor-symbol a)
        collect (list (element-id a)
                      (and (chord-symbol-root s) (pitch-class-string (chord-symbol-root s)))
                      (and (chord-symbol-bass s) (pitch-class-string (chord-symbol-bass s))))))

(defparameter +transposed+ (fixture "sc1-transposed.sexp")
  "(fixture op-form pitches keys anchors), computed with music21.")

(deftest-parametrize transpose-oracle
    ((name form pitches keys anchors) :rows +transposed+)
  (multiple-value-bind (score lists) (edit (fixture-score name) form)
    (ok (equal pitches (note-pitches score)) "every note, spelled by the interval")
    (ok (equal keys (own-keys score)) "key signatures")
    (ok (equal anchors (anchor-roots score)) "chord symbols respelled")
    (ok (null (check-score score)))
    (ok (null (first lists)) "nothing created")
    (ok (null (second lists)) "nothing removed")))

(deftest transpose-respells-chord-symbols
  (let ((score (edit (fixture-score "sc0-chords-under-rests") '(:transpose :interval "m2"))))
    (ok (equal '(("h-h" "Gb" nil) ("h-i" "Db" nil) ("h-j" "Cb" nil) ("h-k" "Ab" nil)
                 ("h-l" "Db" nil) ("h-m" "Gb" "Bb") ("h-n" "Gb" nil) ("h-o" nil nil))
               (anchor-roots score)))
    (ok (null (chord-symbol-text (anchor-symbol (find-element score "h-i")))) "TEXT goes")
    (ok (eq :pop (chord-symbol-dialect (anchor-symbol (find-element score "h-i")))) "DIALECT stays")
    (ok (equal '((9 . -1)) (chord-symbol-alterations (anchor-symbol (find-element score "h-l")))))
    (ok (chord-symbol-no-chord-p (anchor-symbol (find-element score "h-o"))) "N.C. stays N.C.")
    (ok (equal "Gb major" (key-name (bar-key score 1))))))

(deftest-parametrize transpose-to-key
    ((name key interval)
     ("sc0-chords-under-rests" "Eb major" "-M2")
     ("sc0-chords-under-rests" "C major" "-P4")
     ("sc0-chords-under-rests" "B major" "A4")
     ("sc0-satb" "D major" "-P4")
     ("sc0-satb" "E major" "-m3")
     ("sc0-satb" "Gb major" "d1")
     ("sc0-jumps" "D minor" "-M2")
     ("sc0-key-change" "Db major" "m2"))
  (let* ((source (fixture-score name))
         (moved (edit source `(:transpose :to-key ,key)))
         (from (bar-key source (score-first-bar source))))
    (ok (score-equal (edit source `(:transpose :interval ,interval)) moved)
        (format nil "~A to ~A is ~A" name key interval))
    (ok (every (lambda (row)
                 (equal (second row)
                        (pitch-name (transpose-to-key (note-pitch (find-element source (first row)))
                                                      from (parse-key key)))))
               (note-pitches moved))
        "every note is where music-theory's TRANSPOSE-TO-KEY puts it")))

(deftest transpose-past-seven-accidentals
  (let* ((source (fixture-score "sc0-three-verses"))
         (score (edit source '(:transpose :interval "A1"))))
    (ok (equal '(("m-1" "Ab major")) (own-keys score))
        "G# major has eight sharps: CHOOSE-ENHARMONIC-KEY gives Ab major")
    (ok (equal '("Ab4" "G4") (mapcar (lambda (id) (pitch-name (note-pitch (find-element score id))))
                                     '("e-8" "e-g")))
        "the notes are spelled for Ab major")
    (ok (score-equal score (edit source '(:transpose :interval "m2")))
        "the same as a minor second up")
    (ok (null (check-score score))))
  (let ((score (edit (fixture-score "sc0-key-change") '(:transpose :interval "A1"))))
    (ok (equal '(("m-1" "C# major") ("m-4" "Eb major") ("m-9" "B major")) (own-keys score))
        "key by key: only D# major is past seven")
    (ok (equal '(("e-f" "C#4") ("e-g" "E#4") ("e-h" "G#4") ("e-i" "C#5") ("e-j" "B#4") ("e-k" "G#4")
                 ("e-l" "G4") ("e-m" "Bb4") ("e-n" "Eb5") ("e-o" "F5") ("e-p" "D5") ("e-q" "Bb4")
                 ("e-r" "B4") ("e-s" "D#5") ("e-t" "F#5"))
               (note-pitches score))
        "the notes of the D major bars are spelled for Eb major")
    (ok (null (check-score score)))))

(deftest transpose-scopes
  (let* ((source (fixture-score "sc0-keyboard"))
         (score (edit source '(:transpose :interval "M2" :parts ("p-o")))))
    (ok (equal "D4" (pitch-name (note-pitch (find-element score "n-t")))) "the piano moves")
    (ok (equal "D3" (pitch-name (note-pitch (find-element score "e-1i")))))
    (ok (equal "E5" (pitch-name (note-pitch (find-element score "e-a")))) "the flute doesn't")
    (ok (equal '(("m-1" "C major")) (own-keys score)) "nor do the keys: not every part moves"))
  (multiple-value-bind (score lists)
      (edit (fixture-score "sc0-key-change") '(:transpose :interval "M2" :from "m-3" :to "m-4"))
    (ok (equal '(("m-1" "C major") ("m-3" "D major") ("m-4" "E major") ("m-6" "D major")
                 ("m-9" "Bb major"))
               (own-keys score))
        "the range gets its key; the measure after it keeps its own")
    (ok (equal '(("e-f" "C4") ("e-g" "E4") ("e-h" "G4") ("e-i" "C5") ("e-j" "C#5") ("e-k" "A4")
                 ("e-l" "G#4") ("e-m" "B4") ("e-n" "E5") ("e-o" "E5") ("e-p" "C#5") ("e-q" "A4")
                 ("e-r" "Bb4") ("e-s" "D5") ("e-t" "F5"))
               (note-pitches score)))
    (ok (equal '(() () ("m-3" "m-4" "m-6" "e-j" "e-k" "e-l" "e-m" "e-n")) lists))
    (ok (null (check-score score))))
  (multiple-value-bind (score lists) (edit (fixture-score "sc0-carol-6-8") '(:transpose :interval "M2" :to "m-6"))
    (ok (member "ti-19" (second lists) :test #'string=) "the tie out of the range breaks")
    (ok (equal '(("m-1" "B minor") ("m-7" "A minor")) (own-keys score)))
    (ok (null (check-score score))))
  (let ((score (edit (fixture-score "sc0-omr-result") '(:transpose :interval "P8"))))
    (ok (equal '("m-3" "ly-a" "e-d" "e-h" "h-k" "sp-m") (ids (uncertain-elements score)))
        "transposed notes are the user's now; the rest keep their confidence")
    (ok (equal "F5" (pitch-name (note-pitch (find-element score "e-7")))))
    (ok (eq :user (provenance-source (element-provenance (find-element score "e-7")))))
    (ok (eql 1 (element-confidence (find-element score "n-f"))))))

(deftest-parametrize transpose-refusals
    ((label name form type)
     ("a pitch beyond two accidentals" :base
      '(:composite :ops ((:set-pitch :id "a" :pitch "F##4") (:transpose :interval "A1")))
      'invalid-edit)
     ("both an interval and a key" "sc0-satb" '(:transpose :interval "M2" :to-key "A major")
      'invalid-edit)
     ("neither" "sc0-satb" '(:transpose) 'invalid-edit)
     ("a range backwards" "sc0-satb" '(:transpose :interval "M2" :from "m-3" :to "m-1")
      'edit-position-invalid)
     ("a missing part" "sc0-satb" '(:transpose :interval "M2" :parts ("zz")) 'edit-target-missing)
     ("a voice as a part" "sc0-satb" '(:transpose :interval "M2" :parts ("v-8")) 'invalid-edit)
     ("a missing measure" "sc0-satb" '(:transpose :interval "M2" :from "zz") 'edit-target-missing))
  (ok (typep (condition-of (lambda () (edit (if (eq name :base) (base) (fixture-score name)) form)))
             type)
      label))

(deftest transpose-backwards-range-position
  (let ((c (condition-of (lambda () (edit (fixture-score "sc0-satb")
                                          '(:transpose :interval "M2" :from "m-3" :to "m-1"))))))
    (ok (and (typep c 'edit-position-invalid) (eql 1 (invalid-position-position c)))
        "POSITION is TO's bar")))
