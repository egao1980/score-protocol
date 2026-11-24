;;;; SC1: edits of events, marks, spanners and chord symbols; change sets,
;;;; conditions and restarts, composition, the canonical form of operations.
;;;; Rules: src/edits.lisp and src/edit-events.lisp. Expected values follow those
;;;; rules and were checked against a separate reference implementation of them
;;;; (tests/fixtures/PROVENANCE.md); split-duration pieces are music-theory's.
;;;; In expected forms, :USER T stands for the provenance an edit gives
;;;; (EXPAND-USER, tests/package.lisp).

(in-package #:score-protocol/tests)

;;; The base score: four 4/4 bars in C major, two voices on one staff.
;;;   v1: a C4 q (lyric "one", slur to b), b D4 q, c E4 h tied to d |
;;;       d E4 q, f G4 q, r1 rest h | g C5 h (fermata), r3 rest h | r4 whole rest
;;;   v2 (stem down): silent | r2 whole rest | silent | silent
;;;   anchors h1 C at (1 . 0), h2 G7/B at (2 . 1/2). Counter 20: minting starts
;;;   at serial 21, "l".

(defparameter +base+
  '(:score
    :id-counter 20
    :measures ((:measure :id "m1" :time "4/4" :key "C major")
               (:measure :id "m2")
               (:measure :id "m3")
               (:measure :id "m4" :barline :final))
    :parts ((:part :id "p1" :staves ((:staff :id "s1"))
             :voices ((:voice :id "v1"
                       :measures (((:note :id "a" :pitch "C4" :duration 1/4
                                    :lyrics ((:lyric :id "la" :text "one")))
                                   (:note :id "b" :pitch "D4" :duration 1/4)
                                   (:note :id "c" :pitch "E4" :duration 1/2
                                    :tie (:tie :id "tc" :end "d")))
                                  ((:note :id "d" :pitch "E4" :duration 1/4)
                                   (:note :id "f" :pitch "G4" :duration 1/4)
                                   (:rest :id "r1" :duration 1/2))
                                  ((:note :id "g" :pitch "C5" :duration 1/2
                                    :fermata (:fermata :id "fg"))
                                   (:rest :id "r3" :duration 1/2))
                                  ((:rest :id "r4" :duration 1 :measure-rest t))))
                      (:voice :id "v2" :stem :down
                       :measures (() ((:rest :id "r2" :duration 1 :measure-rest t)) () ())))))
    :chord-symbols ((:chord-symbol :id "h1" :bar 1 :offset 0 :symbol (:root "C" :quality :major))
                    (:chord-symbol :id "h2" :bar 2 :offset 1/2
                     :symbol (:root "G" :quality :dominant-7 :bass "B")))
    :spanners ((:spanner :id "sl" :kind :slur :start "a" :end "b"))))

(defvar *base* nil)
(defun base () (or *base* (setf *base* (sexp-to-score +base+))))

(defun build-op (form)
  "The operation FORM describes, built with the constructors (independently of
SEXP-TO-EDIT)."
  (destructuring-bind (kind &rest plist) form
    (labels ((g (key) (getf plist key))
             (el (key) (let ((v (g key))) (and v (sexp-to-element v))))
             (events (measures) (mapcar (lambda (m) (mapcar #'sexp-to-element m)) measures)))
      (ecase kind
        (:insert-event (make-insert-event :voice (g :voice) :measure (g :measure)
                                          :offset (or (g :offset) 0) :event (el :event)
                                          :reflow (g :reflow)))
        (:delete-event (make-delete-event :id (g :id)))
        (:replace-event (make-replace-event :id (g :id) :event (el :event)))
        (:set-voice-measures (make-set-voice-measures :voice (g :voice) :measure (g :measure)
                                                      :measures (events (g :measures))))
        (:set-pitch (make-set-pitch :id (g :id) :pitch (parse-pitch (g :pitch))))
        (:set-accidental (make-set-accidental :id (g :id) :accidental (g :accidental)))
        (:set-duration (make-set-duration :id (g :id) :duration (g :duration) :tuplet (g :tuplet)))
        (:add-mark (make-add-mark :target (g :target) :mark (el :mark)))
        (:remove-mark (make-remove-mark :id (g :id)))
        (:add-spanner (make-add-spanner :spanner (el :spanner)))
        (:remove-spanner (make-remove-spanner :id (g :id)))
        (:add-chord-symbol (make-add-chord-symbol :anchor (el :anchor)))
        (:remove-chord-symbol (make-remove-chord-symbol :id (g :id)))
        (:set-key (make-set-key :measure (g :measure) :key (and (g :key) (parse-key (g :key)))))
        (:set-time (make-set-time :measure (g :measure)
                                  :time (and (g :time) (parse-meter (g :time)))))
        (:replace-measure (make-replace-measure :id (g :id) :measure-info (el :measure-info)))
        (:insert-measures (make-insert-measures
                           :before (g :before)
                           :measure-infos (mapcar #'sexp-to-element (g :measure-infos))
                           :contents (mapcar (lambda (entry) (cons (car entry) (events (cdr entry))))
                                             (g :contents))))
        (:delete-measures (make-delete-measures :measure (g :measure) :count (or (g :count) 1)))
        (:transpose (make-transpose :interval (and (g :interval) (parse-interval (g :interval)))
                                    :to-key (and (g :to-key) (parse-key (g :to-key)))
                                    :parts (g :parts) :from (g :from) :to (g :to)))
        (:composite (make-composite-edit :ops (mapcar #'build-op (g :ops))))))))

(defun edit (score form)
  "(values new-score change-lists) for the operation FORM on SCORE."
  (apply-op score (build-op form)))

(defun expect-forms (score expected)
  "True when every (id form) of EXPECTED is the canonical form of SCORE's element
with that id (forms through EXPAND-USER)."
  (every (lambda (row) (equal (expand-user (second row)) (form-of score (first row))))
         expected))

(defun expect-measures (score voice expected)
  (equal (expand-user expected) (voice-form score voice)))

;;; Successful edits: the result's forms and the change set -----------------
;;; Each row: label, operation, what to compare (:voice id measures, or
;;; :forms ((id form)...)), the change set (created removed modified).

(deftest-parametrize base-edits
    ((label op what voice expected changes)
     ;; SET-PITCH, SET-ACCIDENTAL
     ("set-pitch" '(:set-pitch :id "b" :pitch "F4")
      :forms nil '(("b" (:note :id "b" :pitch "F4" :duration 1/4 :user t)))
      '(() () ("b")))
     ("set-pitch breaks the tie from the note"
      '(:set-pitch :id "c" :pitch "F4")
      :forms nil '(("c" (:note :id "c" :pitch "F4" :duration 1/2 :user t)))
      '(() ("tc") ("c")))
     ("set-pitch breaks the tie into the note"
      '(:set-pitch :id "d" :pitch "F4")
      :forms nil '(("d" (:note :id "d" :pitch "F4" :duration 1/4 :user t))
               ("c" (:note :id "c" :pitch "E4" :duration 1/2)))
      '(() ("tc") ("c" "d")))
     ("set-accidental" '(:set-accidental :id "a" :accidental :forced)
      :forms nil '(("a" (:note :id "a" :pitch "C4" :duration 1/4 :accidental :forced
                     :lyrics ((:lyric :id "la" :text "one")) :user t)))
      '(() () ("a")))
     ;; SET-DURATION
     ("shorter: the rest of the old span is filled"
      '(:set-duration :id "c" :duration 1/4)
      :voice "v1"
      '(((:note :id "a" :pitch "C4" :duration 1/4 :lyrics ((:lyric :id "la" :text "one")))
         (:note :id "b" :pitch "D4" :duration 1/4)
         (:note :id "c" :pitch "E4" :duration 1/4 :user t)
         (:rest :id "e-l" :duration 1/4 :user t))
        ((:note :id "d" :pitch "E4" :duration 1/4) (:note :id "f" :pitch "G4" :duration 1/4)
         (:rest :id "r1" :duration 1/2))
        ((:note :id "g" :pitch "C5" :duration 1/2 :fermata (:fermata :id "fg"))
         (:rest :id "r3" :duration 1/2))
        ((:rest :id "r4" :duration 1 :measure-rest t)))
      '(("e-l") ("tc") ("v1" "c")))
     ("longer: overwrites, the remainder becomes rests"
      '(:set-duration :id "b" :duration 1/2)
      :voice "v1"
      '(((:note :id "a" :pitch "C4" :duration 1/4 :lyrics ((:lyric :id "la" :text "one")))
         (:note :id "b" :pitch "D4" :duration 1/2 :user t)
         (:rest :id "e-l" :duration 1/4 :user t))
        ((:note :id "d" :pitch "E4" :duration 1/4) (:note :id "f" :pitch "G4" :duration 1/4)
         (:rest :id "r1" :duration 1/2))
        ((:note :id "g" :pitch "C5" :duration 1/2 :fermata (:fermata :id "fg"))
         (:rest :id "r3" :duration 1/2))
        ((:rest :id "r4" :duration 1 :measure-rest t)))
      '(("e-l") ("c" "tc") ("v1" "b")))
     ("overflow ties across the barline"
      '(:set-duration :id "f" :duration 1)
      :voice "v1"
      '(((:note :id "a" :pitch "C4" :duration 1/4 :lyrics ((:lyric :id "la" :text "one")))
         (:note :id "b" :pitch "D4" :duration 1/4)
         (:note :id "c" :pitch "E4" :duration 1/2 :tie (:tie :id "tc" :end "d")))
        ((:note :id "d" :pitch "E4" :duration 1/4)
         (:note :id "f" :pitch "G4" :duration 3/4 :tie (:tie :id "ti-l" :end "e-m" :user t) :user t))
        ((:note :id "e-m" :pitch "G4" :duration 1/4 :user t)
         (:rest :id "e-n" :duration 1/4 :user t)
         (:rest :id "r3" :duration 1/2))
        ((:rest :id "r4" :duration 1 :measure-rest t)))
      '(("ti-l" "e-m" "e-n") ("r1" "g" "fg") ("v1" "f")))
     ("overflow keeps the marks on the first piece"
      '(:set-duration :id "g" :duration 3/2)
      :voice "v1"
      '(((:note :id "a" :pitch "C4" :duration 1/4 :lyrics ((:lyric :id "la" :text "one")))
         (:note :id "b" :pitch "D4" :duration 1/4)
         (:note :id "c" :pitch "E4" :duration 1/2 :tie (:tie :id "tc" :end "d")))
        ((:note :id "d" :pitch "E4" :duration 1/4) (:note :id "f" :pitch "G4" :duration 1/4)
         (:rest :id "r1" :duration 1/2))
        ((:note :id "g" :pitch "C5" :duration 1 :tie (:tie :id "ti-l" :end "e-m" :user t)
          :fermata (:fermata :id "fg") :user t))
        ((:note :id "e-m" :pitch "C5" :duration 1/2 :user t)
         (:rest :id "e-n" :duration 1/2 :user t)))
      '(("ti-l" "e-m" "e-n") ("r3" "r4") ("v1" "g")))
     ("up to the end of the score"
      '(:set-duration :id "g" :duration 1)
      :voice "v1"
      '(((:note :id "a" :pitch "C4" :duration 1/4 :lyrics ((:lyric :id "la" :text "one")))
         (:note :id "b" :pitch "D4" :duration 1/4)
         (:note :id "c" :pitch "E4" :duration 1/2 :tie (:tie :id "tc" :end "d")))
        ((:note :id "d" :pitch "E4" :duration 1/4) (:note :id "f" :pitch "G4" :duration 1/4)
         (:rest :id "r1" :duration 1/2))
        ((:note :id "g" :pitch "C5" :duration 1 :fermata (:fermata :id "fg") :user t))
        ((:rest :id "r4" :duration 1 :measure-rest t)))
      '(() ("r3") ("v1" "g")))
     ("an unnotatable value splits by the meter; the slur loses its end"
      '(:set-duration :id "a" :duration 5/16)
      :voice "v1"
      '(((:note :id "a" :pitch "C4" :duration 1/4 :tie (:tie :id "ti-l" :end "e-m" :user t)
          :lyrics ((:lyric :id "la" :text "one")) :user t)
         (:note :id "e-m" :pitch "C4" :duration 1/16 :user t)
         (:rest :id "e-n" :duration 1/16 :user t)
         (:rest :id "e-o" :duration 1/8 :user t)
         (:note :id "c" :pitch "E4" :duration 1/2 :tie (:tie :id "tc" :end "d")))
        ((:note :id "d" :pitch "E4" :duration 1/4) (:note :id "f" :pitch "G4" :duration 1/4)
         (:rest :id "r1" :duration 1/2))
        ((:note :id "g" :pitch "C5" :duration 1/2 :fermata (:fermata :id "fg"))
         (:rest :id "r3" :duration 1/2))
        ((:rest :id "r4" :duration 1 :measure-rest t)))
      '(("ti-l" "e-m" "e-n" "e-o") ("b" "sl") ("v1" "a")))
     ("a rest shortens like a note"
      '(:set-duration :id "r1" :duration 1/4)
      :forms nil '(("r1" (:rest :id "r1" :duration 1/4 :user t))
               ("e-l" (:rest :id "e-l" :duration 1/4 :user t)))
      '(("e-l") () ("v1" "r1")))
     ;; INSERT-EVENT
     ("insert: the trailing rests make room"
      '(:insert-event :voice "v1" :measure "m2" :offset 1/4
        :event (:note :pitch "A4" :duration 1/4))
      :voice "v1"
      '(((:note :id "a" :pitch "C4" :duration 1/4 :lyrics ((:lyric :id "la" :text "one")))
         (:note :id "b" :pitch "D4" :duration 1/4)
         (:note :id "c" :pitch "E4" :duration 1/2 :tie (:tie :id "tc" :end "d")))
        ((:note :id "d" :pitch "E4" :duration 1/4) (:note :id "e-l" :pitch "A4" :duration 1/4)
         (:note :id "f" :pitch "G4" :duration 1/4) (:rest :id "e-m" :duration 1/4 :user t))
        ((:note :id "g" :pitch "C5" :duration 1/2 :fermata (:fermata :id "fg"))
         (:rest :id "r3" :duration 1/2))
        ((:rest :id "r4" :duration 1 :measure-rest t)))
      '(("e-l" "e-m") ("r1") ("v1")))
     ("insert: the rests are used up exactly; moving d breaks the tie into it"
      '(:insert-event :voice "v1" :measure "m2" :event (:note :pitch "A4" :duration 1/2))
      :voice "v1"
      '(((:note :id "a" :pitch "C4" :duration 1/4 :lyrics ((:lyric :id "la" :text "one")))
         (:note :id "b" :pitch "D4" :duration 1/4)
         (:note :id "c" :pitch "E4" :duration 1/2))
        ((:note :id "e-l" :pitch "A4" :duration 1/2) (:note :id "d" :pitch "E4" :duration 1/4)
         (:note :id "f" :pitch "G4" :duration 1/4))
        ((:note :id "g" :pitch "C5" :duration 1/2 :fermata (:fermata :id "fg"))
         (:rest :id "r3" :duration 1/2))
        ((:rest :id "r4" :duration 1 :measure-rest t)))
      '(("e-l") ("tc" "r1") ("v1" "c")))
     ("insert with reflow: the voice moves on, the end is cut"
      '(:insert-event :voice "v1" :measure "m2" :offset 1/4
        :event (:note :pitch "A4" :duration 1/4) :reflow t)
      :voice "v1"
      '(((:note :id "a" :pitch "C4" :duration 1/4 :lyrics ((:lyric :id "la" :text "one")))
         (:note :id "b" :pitch "D4" :duration 1/4)
         (:note :id "c" :pitch "E4" :duration 1/2 :tie (:tie :id "tc" :end "d")))
        ((:note :id "d" :pitch "E4" :duration 1/4) (:note :id "e-l" :pitch "A4" :duration 1/4)
         (:note :id "f" :pitch "G4" :duration 1/4) (:rest :id "r1" :duration 1/4 :user t))
        ((:rest :id "e-m" :duration 1/4 :user t)
         (:note :id "g" :pitch "C5" :duration 1/2 :fermata (:fermata :id "fg"))
         (:rest :id "r3" :duration 1/4 :user t))
        ((:rest :id "e-n" :duration 1/4 :user t) (:rest :id "e-o" :duration 1/4 :user t)
         (:rest :id "e-p" :duration 1/2 :user t)))
      '(("e-l" "e-m" "e-n" "e-o" "e-p") ("r4") ("v1" "r1" "r3")))
     ("insert into a silent voice measure"
      '(:insert-event :voice "v2" :measure "m1" :offset 1/2
        :event (:note :pitch "B3" :duration 1/4))
      :voice "v2"
      '(((:rest :id "e-l" :duration 1/2 :user t) (:note :id "e-m" :pitch "B3" :duration 1/4)
         (:rest :id "e-n" :duration 1/4 :user t))
        ((:rest :id "r2" :duration 1 :measure-rest t)) () ())
      '(("e-l" "e-m" "e-n") () ("v2")))
     ("insert a grace note"
      '(:insert-event :voice "v1" :measure "m1" :offset 1/4
        :event (:note :pitch "C4" :duration 1/8 :grace :acciaccatura))
      :forms nil '(("e-l" (:note :id "e-l" :pitch "C4" :duration 1/8 :grace :acciaccatura)))
      '(("e-l") () ("v1")))
     ;; DELETE-EVENT
     ("delete: the note becomes a rest; the slur goes"
      '(:delete-event :id "b")
      :forms nil '(("b" (:rest :id "b" :duration 1/4 :user t)))
      '(() ("sl") ("b")))
     ("delete: the tie into the note goes"
      '(:delete-event :id "d")
      :forms nil '(("d" (:rest :id "d" :duration 1/4 :user t)))
      '(() ("tc") ("c" "d")))
     ("delete: lyrics and marks go with the note"
      '(:delete-event :id "a")
      :forms nil '(("a" (:rest :id "a" :duration 1/4 :user t)))
      '(() ("la" "sl") ("a")))
     ("delete: a fermata goes too"
      '(:delete-event :id "g")
      :forms nil '(("g" (:rest :id "g" :duration 1/2 :user t)))
      '(() ("fg") ("g")))
     ("delete the rest of a voice measure of rests: silence"
      '(:delete-event :id "r2")
      :voice "v2" '(() () () ())
      '(() ("r2") ("v2")))
     ;; REPLACE-EVENT
     ("replace: a note becomes a chord with its id"
      '(:replace-event :id "b"
        :event (:chord :notes ((:chord-note :pitch "D4") (:chord-note :pitch "F4")) :duration 1/4))
      :forms nil '(("b" (:chord :id "b" :notes ((:chord-note :id "n-l" :pitch "D4")
                                           (:chord-note :id "n-m" :pitch "F4"))
                     :duration 1/4)))
      '(("n-l" "n-m") () ("b")))
     ("replace: what the new event lacks is removed"
      '(:replace-event :id "a" :event (:note :pitch "C4" :duration 1/4))
      :forms nil '(("a" (:note :id "a" :pitch "C4" :duration 1/4)))
      '(() ("la") ("a")))
     ("replace by a rest: the slur goes"
      '(:replace-event :id "b" :event (:rest :duration 1/4))
      :forms nil '(("b" (:rest :id "b" :duration 1/4)))
      '(() ("sl") ("b")))
     ;; SET-VOICE-MEASURES
     ("set voice measures: a bar regenerated"
      '(:set-voice-measures :voice "v1" :measure "m2"
        :measures (((:note :pitch "B4" :duration 1))))
      :forms nil '(("e-l" (:note :id "e-l" :pitch "B4" :duration 1))
               ("c" (:note :id "c" :pitch "E4" :duration 1/2)))
      '(("e-l") ("tc" "d" "f" "r1") ("v1" "c")))
     ("set voice measures: a rest bar and silence"
      '(:set-voice-measures :voice "v2" :measure "m1"
        :measures (((:rest :duration 1 :measure-rest t)) () ()))
      :voice "v2" '(((:rest :id "e-l" :duration 1 :measure-rest t)) () () ())
      '(("e-l") ("r2") ("v2")))
     ;; ADD-MARK, REMOVE-MARK
     ("add a dynamic" '(:add-mark :target "b" :mark (:dynamic :value :f))
      :forms nil '(("b" (:note :id "b" :pitch "D4" :duration 1/4 :dynamic (:dynamic :id "dy-l" :value :f))))
      '(("dy-l") () ("b")))
     ("a fermata replaces the fermata, keeping its id"
      '(:add-mark :target "g" :mark (:fermata :shape :long))
      :forms nil '(("fg" (:fermata :id "fg" :shape :long)))
      '(() () ("fg")))
     ("a lyric replaces the lyric of its verse"
      '(:add-mark :target "a" :mark (:lyric :text "uno"))
      :forms nil '(("la" (:lyric :id "la" :text "uno")))
      '(() () ("la")))
     ("a lyric of another verse joins"
      '(:add-mark :target "a" :mark (:lyric :verse 2 :text "two"))
      :forms nil '(("a" (:note :id "a" :pitch "C4" :duration 1/4
                     :lyrics ((:lyric :id "la" :text "one") (:lyric :id "ly-l" :verse 2 :text "two")))))
      '(("ly-l") () ("a")))
     ("add an articulation" '(:add-mark :target "b" :mark (:articulation :kind :staccato))
      :forms nil '(("ar-l" (:articulation :id "ar-l" :kind :staccato)))
      '(("ar-l") () ("b")))
     ("add a tempo mark" '(:add-mark :target "m2" :mark (:tempo-mark :offset 1/2 :text "rit."))
      :forms nil '(("m2" (:measure :id "m2" :tempo ((:tempo-mark :id "tm-l" :offset 1/2 :text "rit.")))))
      '(("tm-l") () ("m2")))
     ("add a rehearsal mark" '(:add-mark :target "m3" :mark (:rehearsal :text "B"))
      :forms nil '(("rh-l" (:rehearsal :id "rh-l" :text "B")))
      '(("rh-l") () ("m3")))
     ("add a jump mark" '(:add-mark :target "m2" :mark (:jump :kind :segno))
      :forms nil '(("jm-l" (:jump :id "jm-l" :kind :segno)))
      '(("jm-l") () ("m2")))
     ("add an ending" '(:add-mark :target "m2" :mark (:ending :passes (1)))
      :forms nil '(("en-l" (:ending :id "en-l" :passes (1))))
      '(("en-l") () ("m2")))
     ("remove a fermata" '(:remove-mark :id "fg")
      :forms nil '(("g" (:note :id "g" :pitch "C5" :duration 1/2)))
      '(() ("fg") ("g")))
     ("remove a tie" '(:remove-mark :id "tc") :forms nil '()
      '(() ("tc") ("c")))
     ("remove a lyric" '(:remove-mark :id "la") :forms nil '()
      '(() ("la") ("a")))
     ;; Spanners and chord symbols
     ("add a slur" '(:add-spanner :spanner (:spanner :kind :slur :start "d" :end "f"))
      :forms nil '(("sp-l" (:spanner :id "sp-l" :kind :slur :start "d" :end "f")))
      '(("sp-l") () ()))
     ("remove a slur" '(:remove-spanner :id "sl") :forms nil '()
      '(() ("sl") ()))
     ("add a chord symbol"
      '(:add-chord-symbol :anchor (:chord-symbol :bar 3 :offset 0 :symbol (:root "F" :quality :major)))
      :forms nil '(("h-l" (:chord-symbol :id "h-l" :bar 3 :offset 0 :symbol (:root "F" :quality :major))))
      '(("h-l") () ()))
     ("a chord symbol at an anchor's position replaces it, keeping its id"
      '(:add-chord-symbol :anchor (:chord-symbol :bar 1 :offset 0 :symbol (:root "A" :quality :minor)))
      :forms nil '(("h1" (:chord-symbol :id "h1" :bar 1 :offset 0 :symbol (:root "A" :quality :minor))))
      '(() () ("h1")))
     ("remove a chord symbol" '(:remove-chord-symbol :id "h2") :forms nil '()
      '(() ("h2") ())))
  (multiple-value-bind (score lists) (edit (base) op)
    (ok (equal changes lists) label)
    (ok (if (eq what :voice)
            (expect-measures score voice expected)
            (expect-forms score expected))
        label)
    (ok (null (check-score score)) "the result is valid")))

;;; Edits on the fixture scores ---------------------------------------------

(deftest-parametrize fixture-edits
    ((label name op expected changes)
     ("set-pitch of a chord note" "sc0-keyboard" '(:set-pitch :id "n-14" :pitch "Eb4")
      '(("n-14" (:chord-note :id "n-14" :pitch "Eb4" :accidental :cautionary :user t)))
      '(() () ("n-14")))
     ("set-duration of a grace note: nothing moves" "sc0-keyboard"
      '(:set-duration :id "e-9" :duration 1/16)
      '(("e-9" (:note :id "e-9" :pitch "D5" :duration 1/16 :grace :acciaccatura :user t)))
      '(() () ("e-9")))
     ("delete a grace note: its slur goes" "sc0-keyboard" '(:delete-event :id "e-9")
      '() '(() ("e-9" "sp-1o") ("v-7")))
     ("delete a whole note: a measure rest" "sc0-three-verses" '(:delete-event :id "e-18")
      '(("e-18" (:rest :id "e-18" :duration 1 :measure-rest t :user t)))
      '(() ("fe-19" "ly-1a" "ly-1b" "ly-1c") ("e-18")))
     ("tie two equal notes" "sc0-three-verses" '(:add-mark :target "e-8" :mark (:tie :end "e-c"))
      '(("ti-1e" (:tie :id "ti-1e" :end "e-c")))
      '(("ti-1e") () ("e-8")))
     ("remove a tempo mark" "sc0-key-change" '(:remove-mark :id "tm-8")
      '() '(() ("tm-8") ("m-6"))))
  (let ((source (fixture-score name)))
    (multiple-value-bind (score lists) (edit source op)
      (ok (equal changes lists) label)
      (ok (expect-forms score expected) label)
      (ok (null (check-score score)) "the result is valid"))))

;;; Refusals: the condition type, its slots ----------------------------------

(deftest-parametrize base-refusals
    ((label op type slots)
     ("set-pitch of a rest" '(:set-pitch :id "r1" :pitch "C4") 'invalid-edit '())
     ("set-pitch of a missing note" '(:set-pitch :id "zz" :pitch "C4")
      'edit-target-missing '(:id "zz"))
     ("past the end of the score" '(:set-duration :id "g" :duration 5/2)
      'edit-position-invalid '(:position 9/2))
     ("a gap that needs a tuplet" '(:set-duration :id "b" :duration 1/12 :tuplet 3/2)
      'invalid-edit '())
     ("insert overfills the measure"
      '(:insert-event :voice "v1" :measure "m2" :event (:note :pitch "A4" :duration 3/4))
      'measure-overfull '(:voice "v1" :bar 2 :excess 1/4))
     ("insert overfills a silent voice measure"
      '(:insert-event :voice "v2" :measure "m1" :offset 1/2 :event (:note :pitch "B3" :duration 3/4))
      'measure-overfull '(:voice "v2" :bar 1 :excess 1/4))
     ("insert off the event boundaries"
      '(:insert-event :voice "v1" :measure "m1" :offset 1/8 :event (:note :pitch "A4" :duration 1/8))
      'edit-position-invalid '(:position (1 . 1/8)))
     ("insert at the barline"
      '(:insert-event :voice "v1" :measure "m1" :offset 1 :event (:note :pitch "A4" :duration 1/8))
      'edit-position-invalid '(:position (1 . 1)))
     ("insert into a missing voice"
      '(:insert-event :voice "v9" :measure "m1" :event (:note :pitch "A4" :duration 1/4))
      'edit-target-missing '(:id "v9"))
     ("insert into a missing measure"
      '(:insert-event :voice "v1" :measure "m9" :event (:note :pitch "A4" :duration 1/4))
      'edit-target-missing '(:id "m9"))
     ("insert into a part"
      '(:insert-event :voice "p1" :measure "m1" :event (:note :pitch "A4" :duration 1/4))
      'invalid-edit '())
     ("insert an id the score has"
      '(:insert-event :voice "v2" :measure "m1" :event (:note :id "a" :pitch "A4" :duration 1/4))
      'invalid-edit '())
     ("delete a rest among notes" '(:delete-event :id "r1") 'invalid-edit '())
     ("replace with another duration"
      '(:replace-event :id "b" :event (:note :pitch "D4" :duration 1/2)) 'invalid-edit '())
     ("replace with another id"
      '(:replace-event :id "b" :event (:note :id "zz" :pitch "D4" :duration 1/4)) 'invalid-edit '())
     ("voice measures that don't fill their bar"
      '(:set-voice-measures :voice "v1" :measure "m2" :measures (((:note :pitch "B4" :duration 1/2))))
      'edit-breaks-score '(:issues ((:measure-duration "v1" 2))))
     ("voice measures past the end"
      '(:set-voice-measures :voice "v1" :measure "m4"
        :measures (((:rest :duration 1 :measure-rest t)) ((:rest :duration 1 :measure-rest t))))
      'edit-position-invalid '(:position 5))
     ("an articulation on a rest" '(:add-mark :target "r1" :mark (:articulation :kind :accent))
      'invalid-edit '())
     ("a dynamic on a measure" '(:add-mark :target "m1" :mark (:dynamic :value :p)) 'invalid-edit '())
     ("a lyric on a rest" '(:add-mark :target "r1" :mark (:lyric :text "oh"))
      'edit-breaks-score '(:issues ((:misplaced-lyric "ly-l" 2))))
     ("a tie between different pitches" '(:add-mark :target "b" :mark (:tie :end "c"))
      'edit-breaks-score '(:issues ((:tie-pitch "ti-l" 1))))
     ("a mark with an id the score has" '(:add-mark :target "b" :mark (:dynamic :id "la" :value :p))
      'invalid-edit '())
     ("a mark on a missing element" '(:add-mark :target "zz" :mark (:dynamic :value :p))
      'edit-target-missing '(:id "zz"))
     ("remove-mark of an event" '(:remove-mark :id "a") 'invalid-edit '())
     ("remove-mark of a missing mark" '(:remove-mark :id "zz") 'edit-target-missing '(:id "zz"))
     ("a spanner with an id the score has"
      '(:add-spanner :spanner (:spanner :id "sl" :kind :crescendo :start "d" :end "f"))
      'invalid-edit '())
     ("a spanner to nowhere" '(:add-spanner :spanner (:spanner :kind :slur :start "d" :end "zz"))
      'edit-breaks-score '(:issues ((:spanner-endpoint "sp-l" nil))))
     ("remove-spanner of an event" '(:remove-spanner :id "a") 'invalid-edit '())
     ("a chord symbol at the end of a bar"
      '(:add-chord-symbol :anchor (:chord-symbol :bar 2 :offset 1 :symbol (:root "F" :quality :major)))
      'edit-breaks-score '(:issues ((:chord-symbol-position "h-l" nil))))
     ("remove-chord-symbol of a spanner" '(:remove-chord-symbol :id "sl") 'invalid-edit '()))
  (let ((c (condition-of (lambda () (edit (base) op)))))
    (ok (typep c type) label)
    (ok (typep c 'invalid-edit) "every refusal is an INVALID-EDIT")
    (ok (and (typep c 'invalid-edit) (typep (invalid-edit-op c) 'edit-operation))
        "OP is the operation")
    (when slots
      (ok (and (typep c type)
               (loop for (key value) on slots by #'cddr
                     always (equal value
                                   (ecase key
                                     (:id (unknown-element-id c))
                                     (:position (invalid-position-position c))
                                     (:voice (measure-overfull-voice c))
                                     (:bar (measure-overfull-bar c))
                                     (:excess (measure-overfull-excess c))
                                     (:issues (issue-triples (score-invariant-violation-issues c)))))))
          label))))

(deftest edit-type-errors
  (ok (signals (make-set-pitch :id "b" :pitch "F4") 'type-error) "a pitch value, not text")
  (ok (signals (make-set-pitch :id "m-3.p-4" :pitch (parse-pitch "F4")) 'type-error))
  (ok (signals (make-set-duration :id "b" :duration 0) 'type-error))
  (ok (signals (make-set-duration :id "b" :duration 1/4 :tuplet -1) 'type-error))
  (ok (signals (make-set-accidental :id "b" :accidental :sharp) 'type-error))
  (ok (signals (make-insert-event :voice "v1" :measure "m1" :offset -1/4
                                  :event (sexp-to-element '(:rest :duration 1/4)))
               'type-error))
  (ok (signals (make-add-mark :target "b" :mark (sexp-to-element '(:spanner :kind :slur :start "a" :end "b")))
               'type-error)
      "a spanner is not a mark")
  (ok (signals (make-set-voice-measures :voice "v1" :measure "m1" :measures '((1/4))) 'type-error))
  (ok (signals (make-composite-edit :ops (list 1)) 'type-error))
  (ok (signals (make-set-key :measure "m1" :key (make-key :tonic (parse-pitch-class "G#"))) 'type-error)
      "G# major has eight sharps")
  (ok (signals (make-transpose :interval (make-interval :steps 0 :semitones 3)) 'type-error)
      "an interval without a name")
  (ok (signals (make-delete-measures :measure "m1" :count 0) 'type-error))
  (ok (signals (make-insert-measures :measure-infos '()) 'type-error)))

;;; Restarts ----------------------------------------------------------------

(deftest edit-restarts
  (let ((base (base)))
    (multiple-value-bind (score changes)
        (with-restart 'invalid-edit 'skip-edit
          (lambda () (apply-edit base (build-op '(:set-pitch :id "r1" :pitch "C4")))))
      (ok (eq base score) "SKIP-EDIT returns the score")
      (ok (change-set-empty-p changes) "with an empty change set"))
    (multiple-value-bind (score changes)
        (with-restart 'edit-target-missing 'use-value
          (lambda () (apply-edit base (build-op '(:set-pitch :id "zz" :pitch "C4"))))
          (build-op '(:set-pitch :id "b" :pitch "F4")))
      (ok (equal "F4" (pitch-name (note-pitch (find-element score "b")))) "USE-VALUE applies its operation")
      (ok (equal '(() () ("b")) (change-lists changes))))
    (multiple-value-bind (score changes)
        (with-restart 'measure-overfull 'reflow
          (lambda () (apply-edit base (build-op '(:insert-event :voice "v1" :measure "m2"
                                                   :event (:note :pitch "A4" :duration 3/4))))))
      (ok (expect-measures
           score "v1"
           '(((:note :id "a" :pitch "C4" :duration 1/4 :lyrics ((:lyric :id "la" :text "one")))
              (:note :id "b" :pitch "D4" :duration 1/4)
              (:note :id "c" :pitch "E4" :duration 1/2))
             ((:note :id "e-l" :pitch "A4" :duration 3/4) (:note :id "d" :pitch "E4" :duration 1/4))
             ((:note :id "f" :pitch "G4" :duration 1/4) (:rest :id "r1" :duration 1/2)
              (:note :id "g" :pitch "C5" :duration 1/4 :tie (:tie :id "ti-m" :end "e-n" :user t)
               :fermata (:fermata :id "fg") :user t))
             ((:note :id "e-n" :pitch "C5" :duration 1/4 :user t) (:rest :id "r3" :duration 1/2)
              (:rest :id "e-o" :duration 1/4 :user t))))
          "REFLOW re-flows the voice")
      (ok (equal '(("e-l" "ti-m" "e-n" "e-o") ("tc" "r4") ("v1" "c" "g")) (change-lists changes))))
    (let ((c (condition-of
              (lambda ()
                (handler-bind ((measure-overfull #'reflow))
                  (apply-edit base (build-op '(:insert-event :voice "v1" :measure "m2"
                                               :event (:note :pitch "A4" :duration 2)))))))))
      (ok (typep c 'edit-position-invalid) "re-flowing sound past the end of the score is refused")
      (ok (and (typep c 'edit-position-invalid) (eql 9/2 (invalid-position-position c)))
          "POSITION is where the first sounding event would end"))
    (ok (typep (condition-of (lambda () (apply-edit base (build-op '(:set-pitch :id "zz" :pitch "C4")))))
               'unknown-element)
        "EDIT-TARGET-MISSING is an UNKNOWN-ELEMENT")
    (ok (find-restart-p 'invalid-edit 'use-value
                        (lambda () (apply-edit base (build-op '(:delete-event :id "r1"))))))
    (ok (find-restart-p 'measure-overfull 'reflow
                        (lambda () (apply-edit base (build-op '(:insert-event :voice "v1" :measure "m2"
                                                                 :event (:note :pitch "A4" :duration 3/4)))))))))

;;; Composition --------------------------------------------------------------

(deftest composite-edits
  (let ((base (base)))
    (multiple-value-bind (score lists)
        (edit base '(:composite :ops ((:set-pitch :id "a" :pitch "G4")
                                      (:set-pitch :id "b" :pitch "A4"))))
      (ok (equal '(() () ("a" "b")) lists) "one change set for the whole")
      (ok (equal '("G4" "A4") (mapcar (lambda (id) (pitch-name (note-pitch (find-element score id))))
                                      '("a" "b")))))
    (multiple-value-bind (score lists)
        (edit base '(:composite :ops ((:set-voice-measures :voice "v1" :measure "m2"
                                       :measures (((:note :id "x" :pitch "B4" :duration 1/2))))
                                      (:set-voice-measures :voice "v1" :measure "m2"
                                       :measures (((:note :id "x" :pitch "B4" :duration 1/2)
                                                   (:rest :duration 1/2)))))))
      (ok (null (check-score score)) "the check runs once, after the last member")
      (ok (equal '(("x" "e-l") ("tc" "d" "f" "r1") ("v1" "c")) lists)))
    (multiple-value-bind (score lists)
        (edit base '(:composite :ops ((:delete-event :id "d")
                                      (:replace-event :id "d" :event (:note :pitch "E4" :duration 1/4)))))
      (ok (equal '(() () ()) lists) "the cascade runs once: the tie survives")
      (ok (score-equal base score))
      (ok (eq (find-element base "d") (find-element score "d"))
          "an element equal to the one it replaces is that element"))
    (multiple-value-bind (score lists)
        (with-restart 'invalid-edit 'skip-edit
          (lambda () (edit base '(:composite :ops ((:set-pitch :id "a" :pitch "G4")
                                                   (:delete-event :id "r1")
                                                   (:set-pitch :id "b" :pitch "A4"))))))
      (ok (equal '(() () ("a" "b")) lists) "SKIP-EDIT skips the failing member only")
      (ok (equal "A4" (pitch-name (note-pitch (find-element score "b"))))))
    (multiple-value-bind (score lists) (edit base '(:composite :ops ()))
      (ok (score-equal base score) "an empty composite changes nothing")
      (ok (equal '(() () ()) lists)))
    (let* ((a (build-op '(:set-pitch :id "a" :pitch "G4")))
           (b (build-op '(:set-pitch :id "b" :pitch "A4")))
           (c (build-op '(:delete-event :id "c")))
           (composed (compose-edits a (compose-edits b c))))
      (ok (typep composed 'composite-edit))
      (ok (equal (list a b c) (edit-ops composed)) "nested composites are spliced")
      (ok (eq a (compose-edits a)) "one operation is itself")
      (ok (eq a (compose-edits (make-composite-edit :ops (list a)))))
      (ok (null (edit-ops (compose-edits)))))))

;;; Ids --------------------------------------------------------------------

(deftest edit-ids
  (let ((base (base)))
    (multiple-value-bind (score lists)
        (edit base '(:insert-event :voice "v2" :measure "m1"
                     :event (:note :id "kept" :pitch "B3" :duration 1/4)))
      (ok (equal '(("kept" "e-l" "e-m") () ("v2")) lists) "a given id is kept, the fill rests minted")
      (ok (= 22 (score-id-counter score))))
    (ok (= 20 (score-id-counter (edit base '(:delete-event :id "b")))) "nothing minted, counter kept")
    (let* ((one (edit base '(:set-duration :id "c" :duration 1/4)))
           (two (edit one '(:set-duration :id "c" :duration 1/2))))
      (ok (null (find-element two "e-l" :errorp nil)) "the fill rest is overwritten")
      (ok (= 21 (score-id-counter two)))
      (multiple-value-bind (three lists) (edit two '(:set-duration :id "b" :duration 1/8))
        (declare (ignore three))
        (ok (equal '(("e-m") () ("v1" "b")) lists) "serials are never reused")))))

;;; Sharing ----------------------------------------------------------------

(deftest edit-sharing
  (let ((base (base)))
    (let ((score (edit base '(:set-pitch :id "f" :pitch "A4"))))
      (ok (null (unshared base score)) "everything equal is EQ")
      (ok (eq (fset:@ (score-measure-map base) 0) (fset:@ (score-measure-map score) 0)))
      (ok (eq (find-element base "a") (find-element score "a")))
      (ok (eq (find-element base "v2") (find-element score "v2")) "the other voice is shared")
      (ok (not (eq (find-element base "v1") (find-element score "v1")))))
    (let ((score (edit base '(:insert-event :voice "v1" :measure "m2" :offset 1/4
                              :event (:note :pitch "A4" :duration 1/4) :reflow t))))
      (ok (null (unshared base score)) "moved, unchanged events are EQ")
      (ok (eq (find-element base "g") (find-element score "g"))))))

;;; The canonical form of operations ------------------------------------------

(deftest-parametrize edit-forms
    ((form)
     ('(:insert-event :voice "v1" :measure "m2" :offset 1/4 :event (:note :pitch "A4" :duration 1/4)))
     ('(:insert-event :voice "v1" :measure "m2" :event (:rest :duration 1/4) :reflow t))
     ('(:delete-event :id "b"))
     ('(:replace-event :id "b" :event (:chord :notes ((:chord-note :pitch "D4") (:chord-note :pitch "F4"))
                                       :duration 1/4)))
     ('(:set-voice-measures :voice "v1" :measure "m2" :measures (((:note :pitch "B4" :duration 1)) ())))
     ('(:set-pitch :id "b" :pitch "F#4"))
     ('(:set-accidental :id "b" :accidental :cautionary))
     ('(:set-duration :id "b" :duration 1/12 :tuplet 3/2))
     ('(:add-mark :target "b" :mark (:dynamic :value :mf)))
     ('(:remove-mark :id "fg"))
     ('(:add-spanner :spanner (:spanner :kind :crescendo :start "d" :end "f")))
     ('(:remove-spanner :id "sl"))
     ('(:add-chord-symbol :anchor (:chord-symbol :bar 3 :offset 1/2 :symbol (:root "F" :quality :major :bass "A"))))
     ('(:remove-chord-symbol :id "h2"))
     ('(:set-key :measure "m2" :key "Eb major"))
     ('(:set-key :measure "m2"))
     ('(:set-time :measure "m2" :time "6/8"))
     ('(:replace-measure :id "m3" :measure-info (:measure :id "m3" :barline :double)))
     ('(:insert-measures :before "m2" :measure-infos ((:measure) (:measure :key "G major"))
        :contents (("v2" ((:rest :duration 1 :measure-rest t)) ()))))
     ('(:insert-measures :measure-infos ((:measure))))
     ('(:delete-measures :measure "m2"))
     ('(:delete-measures :measure "m2" :count 2))
     ('(:transpose :interval "-m3"))
     ('(:transpose :to-key "A minor" :parts ("p1") :from "m2" :to "m3"))
     ('(:composite :ops ((:set-pitch :id "a" :pitch "G4") (:delete-event :id "c"))))
     ('(:composite :ops ())))
  (let ((op (build-op form)))
    (ok (equal form (edit-to-sexp op)) "EDIT-TO-SEXP writes the canonical form")
    (ok (equal form (edit-to-sexp (sexp-to-edit form))) "SEXP-TO-EDIT reads it back")
    (ok (typep (sexp-to-edit form) (class-of op)))))

(deftest edit-forms-apply-alike
  (let ((base (base)))
    (dolist (form '((:set-duration :id "f" :duration 1)
                    (:insert-event :voice "v1" :measure "m2" :offset 1/4
                     :event (:note :pitch "A4" :duration 1/4) :reflow t)
                    (:transpose :interval "M2")))
      (multiple-value-bind (a ca) (apply-edit base (build-op form))
        (multiple-value-bind (b cb) (apply-edit base (sexp-to-edit form))
          (ok (score-equal a b) (format nil "~S" (car form)))
          (ok (equal (change-lists ca) (change-lists cb))))))))

(deftest edit-form-errors
  (ok (signals (sexp-to-edit '(:no-such-op :id "b")) 'score-format-error))
  (ok (signals (sexp-to-edit '(:set-pitch :id "b" :pitch "F4" :colour :red)) 'score-format-error))
  (ok (signals (sexp-to-edit '(:set-pitch :id "b" :id "c" :pitch "F4")) 'score-format-error))
  (ok (signals (sexp-to-edit '(:set-pitch :id "b" :pitch)) 'score-format-error))
  (ok (signals (sexp-to-edit '(:composite :ops ((:bogus)))) 'score-format-error))
  (ok (signals (sexp-to-edit '"set-pitch") 'score-format-error))
  (let ((c (condition-of (lambda () (sexp-to-edit '(:set-pitch :id "b" :pitch "F4" :colour :red))))))
    (ok (and (typep c 'score-format-error) (eq :sexp (score-format-error-format c))))
    (ok (and (typep c 'score-format-error)
             (equal '(:set-pitch :id "b" :pitch "F4" :colour :red) (score-format-error-position c)))))
  (ok (signals (sexp-to-edit '(:set-pitch :id "b" :pitch "H4")) 'invalid-pitch)
      "music-theory's parse errors are not wrapped"))

;;; INVERT-EDIT on chosen operations (every operation: sc1-properties-test) ------

(deftest-parametrize invert-chosen
    ((form)
     ('(:set-duration :id "f" :duration 1))
     ('(:set-duration :id "a" :duration 5/16))
     ('(:insert-event :voice "v1" :measure "m2" :offset 1/4 :event (:note :pitch "A4" :duration 1/4) :reflow t))
     ('(:delete-event :id "a"))
     ('(:delete-event :id "r2"))
     ('(:replace-event :id "b" :event (:rest :duration 1/4)))
     ('(:add-mark :target "g" :mark (:fermata :shape :long)))
     ('(:remove-chord-symbol :id "h2")))
  (let* ((base (base))
         (op (build-op form)))
    (multiple-value-bind (after changes) (apply-edit base op)
      (let ((inverse (invert-edit base op)))
        (ok (typep inverse 'edit-operation))
        (multiple-value-bind (back back-changes) (apply-edit after inverse)
          (ok (score-equal base back) "the inverse restores the score")
          (ok (equal (change-set-created back-changes) (change-set-removed changes)))
          (ok (equal (change-set-removed back-changes) (change-set-created changes)))
          (ok (null (set-exclusive-or (change-set-modified back-changes) (change-set-modified changes)
                                      :test #'string=))))
        (ok (score-equal base (apply-edit after (sexp-to-edit (edit-to-sexp inverse))))
            "the inverse serialises")))))

(deftest invert-after-a-restart
  (let* ((base (base))
         (op (build-op '(:set-pitch :id "r1" :pitch "C4")))
         (inverse (with-restart 'invalid-edit 'skip-edit (lambda () (invert-edit base op)))))
    (ok (typep inverse 'composite-edit) "SKIP-EDIT: the inverse of nothing")
    (ok (null (edit-ops inverse)))))
