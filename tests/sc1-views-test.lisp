;;;; SC1: the views. Rules: src/views.lisp. Playback orders and the unfolded and
;;;; extracted music come from music21 10.5.2 (generate-sc1.py, sc1-unfolded.sexp
;;;; and sc1-parts.sexp) where music21 follows the same conventions; the rows
;;;; marked "rules" are cases where it doesn't (PROVENANCE.md), computed by the
;;;; rules and checked against a separate reference implementation.

(in-package #:score-protocol/tests)

(defun lookup (map key)
  (values (fset:lookup map key)))

(defun view-sources (view id-map)
  "The source measure id of every measure of VIEW."
  (mapcar (lambda (id) (lookup id-map id)) (measure-ids view)))

(defun view-passes (view passes)
  (mapcar (lambda (id) (lookup passes id)) (measure-ids view)))

(defun notes-text (row) (format nil "~{~A~^ ~}" (rest row)))

(defun sounding-notes (score)
  "(onset pitch-name...) of every non-grace note and chord of SCORE, sorted by
onset and then by the pitch text, as generate-sc1.py sorts music21's notes."
  (let ((rows '()))
    (dolist (part (seq-list (score-parts score)))
      (dolist (voice (part-voices part))
        (let ((measures (seq-list (voice-measures voice))))
          (loop for events in measures
                for bar from (score-first-bar score)
                do (let ((at (bar-start score bar)))
                     (dolist (e (seq-list events))
                       (unless (and (typep e 'sounding-event) (event-grace e))
                         (typecase e
                           (note-event (push (list at (pitch-name (note-pitch e))) rows))
                           (chord-event (push (cons at (mapcar (lambda (n) (pitch-name (note-pitch n)))
                                                               (chord-event-notes e)))
                                              rows)))
                         (incf at (event-duration e)))))))))
    (sort rows (lambda (a b) (or (< (first a) (first b))
                                 (and (= (first a) (first b)) (string< (notes-text a) (notes-text b))))))))

;;; UNFOLD: playback order ------------------------------------------------------

(defun nav-score (spec)
  "A score of one 1/4 bar per member of SPEC, a plist per measure (:repeat-start
:repeat-end :ending (passes measures) :jump (kinds...)). Measure i is \"m<i>\"
and holds one C4."
  (sexp-to-score
   `(:score
     :measures ,(loop for m in spec
                      for i from 0
                      collect `(:measure :id ,(format nil "m~D" i)
                                ,@(when (zerop i) '(:time "1/4" :key "C major"))
                                ,@(when (getf m :repeat-start) '(:repeat-start t))
                                ,@(when (getf m :repeat-end) `(:repeat-end ,(getf m :repeat-end)))
                                ,@(when (getf m :ending)
                                    `(:ending (:ending :passes ,(first (getf m :ending))
                                               :measures ,(second (getf m :ending)))))
                                ,@(when (getf m :jump)
                                    `(:jump ,(mapcar (lambda (k) `(:jump :kind ,k)) (getf m :jump))))))
     :parts ((:part :id "p" :staves ((:staff :id "s"))
              :voices ((:voice :id "v"
                        :measures ,(loop for i below (length spec)
                                         collect `((:note :id ,(format nil "n~D" i)
                                                    :pitch "C4" :duration 1/4))))))))))

(defparameter +unfold-cases+ (getf (fixture "sc1-unfolded.sexp") :cases)
  "(name source spec order): ORDER, the measure indices in playback order, from
music21 or (source :rules) from the rules.")

(deftest-parametrize unfold-orders
    ((name source spec order) :rows (quoted-rows +unfold-cases+))
  (declare (ignorable source))
  (multiple-value-bind (view id-map) (unfold (nav-score spec))
    (ok (equal (mapcar (lambda (i) (format nil "m~D" i)) order) (view-sources view id-map)) name)
    (ok (null (check-score view)) "the unfolded score is valid")))

(defparameter +unfold-fixtures+ (getf (fixture "sc1-unfolded.sexp") :fixtures)
  "(fixture source-measure-ids notes), from music21's expandRepeats.")

(deftest-parametrize unfold-fixtures
    ((name sources notes) :rows (quoted-rows +unfold-fixtures+))
  (multiple-value-bind (view id-map passes) (unfold (fixture-score name))
    (ok (equal sources (view-sources view id-map)) "the playback order")
    (ok (equal notes (sounding-notes view)) "the music, note by note")
    (ok (null (check-score view)))
    (ok (every (lambda (id) (integerp (lookup passes id))) (ids (score-elements view)))
        "every element has a pass")
    (ok (every (lambda (m) (and (null (measure-info-repeat-start m)) (null (measure-info-repeat-end m))
                                (null (measure-info-ending m)) (null (measure-info-jump m))))
               (seq-list (score-measure-map view)))
        "nothing is left to navigate")))

(deftest unfold-voltas
  (multiple-value-bind (view id-map passes) (unfold (fixture-score "sc0-repeats-voltas"))
    (ok (equal '("m-1" "m-3" "m-4" "m-6" "m-12" "m-14" "m-7" "m-9" "m-b" "m-15" "m-17" "m-18" "m-d")
               (measure-ids view))
        "first copies keep their ids, later ones are minted in document order")
    (ok (equal '(1 1 1 1 2 2 1 1 1 2 2 3 1) (view-passes view passes)))
    (ok (equal "m-1" (lookup id-map "m-12")))
    (ok (equal "rh-2" (lookup id-map "rh-13")) "a rehearsal mark is copied with its measure")
    (ok (equal "A" (rehearsal-mark-text (find-element view "rh-13"))))
    (ok (equal "m-9" (lookup id-map "m-18")))
    (ok (eql 3 (lookup passes "rh-19")))
    (ok (eq (find-element (fixture-score "sc0-repeats-voltas") "e-i") (find-element view "e-i"))
        "an event carried over unchanged is the source's")
    (ok (equal "e-i" (lookup id-map "e-i")))
    (ok (equal "D major" (key-name (measure-info-key (find-element view "m-12")))))
    (ok (null (measure-info-pickup-p (find-element view "m-12"))))))

(deftest unfold-dal-segno-al-coda
  (multiple-value-bind (view id-map passes) (unfold (fixture-score "sc0-jumps"))
    (ok (equal '("m-1" "m-3" "m-6" "m-7" "m-9" "m-u" "m-w" "m-x" "m-b" "m-e") (measure-ids view)))
    (ok (equal '("m-1" "m-3" "m-6" "m-7" "m-9" "m-3" "m-6" "m-7" "m-b" "m-e") (view-sources view id-map)))
    (ok (equal '(1 1 1 1 1 2 2 2 1 1) (view-passes view passes)))
    (ok (equal "rh-5" (lookup id-map "rh-v")))
    (ok (null (measure-info-time (find-element view "m-u"))) "the meter and key are already in force")
    (ok (equal '("e-y" "e-z" "e-10" "e-11")
               (loop for id in '("m-u" "m-w" "m-x")
                     for i = (position id (measure-ids view) :test #'string=)
                     append (ids (seq-list (fset:@ (voice-measures (find-element view "v-h")) i))))))
    (ok (equal "e-k" (lookup id-map "e-y")))
    (ok (eql 2 (lookup passes "e-y")))))

(defparameter +tie-repeat+
  '(:score
    :measures ((:measure :id "m0" :time "4/4" :key "C major" :repeat-start t)
               (:measure :id "m1" :repeat-end 2)
               (:measure :id "m2" :barline :final))
    :parts ((:part :id "p" :staves ((:staff :id "s"))
             :voices ((:voice :id "v"
                       :measures (((:note :id "c0" :pitch "C4" :duration 1))
                                  ((:note :id "n1" :pitch "E4" :duration 1/2)
                                   (:note :id "n2" :pitch "G4" :duration 1/2 :tie (:tie :id "t2" :end "n3")))
                                  ((:note :id "n3" :pitch "G4" :duration 1/2)
                                   (:note :id "n4" :pitch "A4" :duration 1/2)))))))
    :chord-symbols ((:chord-symbol :id "h" :bar 1 :offset 1/2 :symbol (:root "C" :quality :major)))
    :spanners ((:spanner :id "sl" :kind :slur :start "n1" :end "n4"))))

(deftest unfold-ties-and-spanners
  (multiple-value-bind (view id-map passes) (unfold (sexp-to-score +tie-repeat+))
    (ok (equal '("m0" "m1" "m-1" "m-2" "m2") (measure-ids view)))
    (ok (null (note-tie (find-element view "n2"))) "no tie where the repeat jumps back")
    (ok (equal "t2" (element-id (note-tie (find-element view "e-5"))))
        "the tie's first copy is on the second pass, and keeps its id")
    (ok (equal "n3" (tie-end (find-element view "t2"))))
    (ok (equal "n2" (lookup id-map "e-5")))
    (ok (equal '(("sl" "e-4" "n4"))
               (mapcar (lambda (sp) (list (element-id sp) (spanner-start sp) (spanner-end sp)))
                       (seq-list (score-spanners view))))
        "the slur only where its two ends follow each other")
    (ok (eql 2 (lookup passes "sl")))
    (ok (eql 2 (lookup passes "t2")))
    (ok (eql 1 (lookup passes "n1")))
    (ok (equal '(("h" (1 . 1/2)) ("h-6" (3 . 1/2)))
               (mapcar (lambda (a) (list (element-id a) (anchor-position a)))
                       (seq-list (score-chord-symbols view))))
        "anchors are copied into every pass")
    (ok (equal "h" (lookup id-map "h-6")))
    (ok (null (check-score view)))))

(deftest unfold-without-navigation
  (dolist (name '("sc0-three-verses" "sc0-satb" "sc0-pickup"))
    (let ((source (fixture-score name)))
      (multiple-value-bind (view id-map passes) (unfold source)
        (ok (score-equal source view) (format nil "~A: nothing to unfold" name))
        (ok (every (lambda (e) (equal (element-id e) (lookup id-map (element-id e))))
                   (score-elements view)))
        (ok (every (lambda (e) (eql 1 (lookup passes (element-id e)))) (score-elements view)))
        (ok (eq (fset:@ (score-measure-map source) 0) (fset:@ (score-measure-map view) 0))))))
  (let ((view (unfold (fixture-score "sc0-repeats-voltas"))))
    (ok (equal (measure-ids view) (measure-ids (unfold view))) "unfolding twice changes nothing")))

(deftest unfold-refusal
  (ok (typep (condition-of (lambda () (unfold (nav-score '(() (:jump (:dal-segno)))))))
             'score-error)
      "D.S. without a segno"))

;;; CONDENSED-VIEW ----------------------------------------------------------------

(defun staff-stems (part)
  (mapcar (lambda (v) (list (element-id v) (voice-staff v) (voice-stem v))) (part-voices part)))

(deftest condensed-satb
  (let ((source (fixture-score "sc0-satb")))
    (multiple-value-bind (view id-map) (condensed-view source)
      (let ((part (fset:@ (score-parts view) 0)))
        (ok (= 1 (fset:size (score-parts view))))
        (ok (equal '(:part :id "p-1r" :name "Choir" :abbreviation "Ch."
                     :staves ((:staff :id "st-1s") (:staff :id "st-1t" :clef :bass)))
                   (subseq (element-to-sexp part) 0 9))
            "a new part on two new staves, named for the voices' part")
        (ok (equal '(("v-8" 1 :up) ("v-s" 1 :down) ("v-13" 2 :up) ("v-1e" 2 :down)) (staff-stems part))
            "soprano and alto above, stems up and down; tenor and bass below")
        (ok (every (lambda (id) (eq (find-element source id) (find-element view id)))
                   '("v-8" "v-s" "v-13" "v-1e" "e-9" "ly-b"))
            "voices already in place are carried over as they are")
        (ok (equal '("sp-1p" "sp-1q") (ids (seq-list (score-spanners view)))))
        (ok (equal "v-s" (lookup id-map "v-s")))
        (ok (null (lookup id-map "p-1r")) "the new part has no source")
        (ok (every #'eq (seq-list (score-measure-map source)) (seq-list (score-measure-map view)))
            "the measure map is the source's")
        (ok (null (check-score view)))))))

(deftest condensed-open-score
  (let ((source (fixture-score "sc1-open-score")))
    (multiple-value-bind (view id-map) (condensed-view source)
      (let ((part (fset:@ (score-parts view) 0)))
        (ok (null (part-name part)) "voices of four parts: no name")
        (ok (equal '(:treble :bass) (mapcar #'staff-clef (part-staves part))))
        (ok (equal '((1 :up) (1 :down) (2 :up) (2 :down)) (mapcar #'rest (staff-stems part))))
        (ok (equal (mapcar #'element-id (mapcar (lambda (p) (first (part-voices p)))
                                                (seq-list (score-parts source))))
                   (mapcar #'element-id (part-voices part))))
        (ok (equal (ids (seq-list (score-spanners source))) (ids (seq-list (score-spanners view))))
            "slurs inside the voices stay")
        (ok (equal (ids (seq-list (score-chord-symbols source)))
                   (ids (seq-list (score-chord-symbols view)))))
        (ok (every (lambda (v) (equal (element-id v) (lookup id-map (element-id v)))) (part-voices part)))
        (ok (equal (sounding-notes source) (sounding-notes view)) "the same music")
        (ok (null (check-score view)))))))

(deftest-parametrize condensed-voice-counts
    ((voices stems clefs)
     ('("v-8" "v-s") '((1 :up) (1 :down)) '(:treble))
     ('("v-8" "v-s" "v-13") '((1 :up) (1 :down) (2 nil)) '(:treble :bass))
     ('("v-1e") '((1 nil)) '(:treble))
     ('("v-1e" "v-8") '((1 :up) (1 :down)) '(:treble)))
  (let* ((view (condensed-view (fixture-score "sc0-satb") :voices voices))
         (part (fset:@ (score-parts view) 0)))
    (ok (equal voices (ids (part-voices part))))
    (ok (equal stems (mapcar #'rest (staff-stems part))))
    (ok (equal clefs (mapcar #'staff-clef (part-staves part))))
    (ok (null (check-score view)))))

(deftest condensed-refusals
  (let ((source (fixture-score "sc0-satb")))
    (ok (typep (condition-of (lambda () (condensed-view source :voices '("v-8" "zz")))) 'unknown-element))
    (ok (equal '("v-8" "v-s")
               (ids (part-voices (fset:@ (score-parts
                                          (with-restart 'unknown-element 'use-value
                                            (lambda () (condensed-view source :voices '("v-8" "zz")))
                                            '("v-8" "v-s")))
                                         0))))
        "USE-VALUE gives the voices to use")
    (ok (typep (condition-of (lambda () (condensed-view source :voices '("p-5")))) 'score-error))
    (ok (typep (condition-of (lambda () (condensed-view source :voices '("v-8" "v-8")))) 'score-error))
    (ok (typep (condition-of (lambda () (condensed-view source :voices '("v-8" "v-s" "v-13" "v-1e" "v-8"))))
               'score-error))
    (ok (typep (condition-of (lambda () (condensed-view source :voices '()))) 'score-error))))

;;; EXTRACT-PART ------------------------------------------------------------------

(defparameter +parts+ (fixture "sc1-parts.sexp")
  "(fixture id notes): the notes of a part or voice, from music21.")

(deftest-parametrize extract-oracle
    ((name id notes) :rows (quoted-rows +parts+))
  (multiple-value-bind (view id-map) (extract-part (fixture-score name) id)
    (ok (equal notes (sounding-notes view)))
    (ok (= 1 (fset:size (score-parts view))))
    (ok (every (lambda (e) (equal (element-id e) (lookup id-map (element-id e)))) (score-elements view))
        "every id maps to itself")
    (ok (null (check-score view)))))

(deftest extract-a-part
  (let ((source (fixture-score "sc0-keyboard")))
    (let ((view (extract-part source "p-5")))
      (ok (eq (find-element source "p-5") (fset:@ (score-parts view) 0)) "the part itself")
      (ok (every #'eq (seq-list (score-measure-map source)) (seq-list (score-measure-map view))))
      (ok (equal '("sp-1o" "sp-1p") (ids (seq-list (score-spanners view)))))
      (ok (equal (score-metadata source) (score-metadata view))))
    (let ((view (extract-part source "p-o")))
      (ok (null (seq-list (score-spanners view))) "the flute's slurs stay with the flute"))))

(deftest extract-a-voice
  (let ((source (fixture-score "sc0-satb")))
    (let* ((view (extract-part source "v-s"))
           (part (fset:@ (score-parts view) 0)))
      (ok (equal '(:part :id "p-5" :name "Alto" :abbreviation "Ch." :staves ((:staff :id "st-6")))
                 (subseq (element-to-sexp part) 0 9))
          "the part's id, the voice's name, the voice's staff")
      (ok (eq (find-element source "st-6") (first (part-staves part))))
      (ok (equal '(("v-s" 1 nil)) (staff-stems part)) "alone: no stem direction")
      (ok (null (seq-list (score-spanners view))) "the hairpins are on the soprano")
      (ok (eq (find-element source "e-t") (find-element view "e-t")))
      (ok (null (check-score view))))
    (let* ((view (extract-part source "v-13"))
           (part (fset:@ (score-parts view) 0)))
      (ok (equal '(:bass) (mapcar #'staff-clef (part-staves part))) "the tenor's staff is the bass staff")
      (ok (equal '(("v-13" 1 nil)) (staff-stems part))))
    (ok (typep (condition-of (lambda () (extract-part source "zz"))) 'unknown-element))
    (ok (equal '("v-8")
               (ids (part-voices (fset:@ (score-parts (with-restart 'unknown-element 'use-value
                                                        (lambda () (extract-part source "zz"))
                                                        "v-8"))
                                         0))))
        "USE-VALUE gives the id to extract")))
