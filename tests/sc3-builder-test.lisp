;;;; SC3: drafts and the score builder, MAKE-SCORE with forward references.
;;;; Rules: src/builder.lisp. Expected ids follow the minting rules of
;;;; src/ids.lisp, worked out by hand. The equivalence properties build each
;;;; score a second way, as importers did before SC3: twice, with the public API
;;;; only, reading the minted ids off the first build (TWO-PASS-BUILD below).
;;;; They run over the SC0 and SC1 fixture scores and a sample of score-parity
;;;; corpus pieces (tests/fixtures/PROVENANCE.md).

(in-package #:score-protocol/tests)

(defun c4 (&rest keys)
  "A quarter-note C4 note event with KEYS."
  (apply #'make-note-event :pitch (p "C4") :duration 1/4 keys))

(defun refs-free-p (score)
  "True when every id and every reference in SCORE is a string."
  (every (lambda (e)
           (and (stringp (element-id e))
                (typecase e
                  (tie (stringp (tie-end e)))
                  (spanner (and (stringp (spanner-start e)) (stringp (spanner-end e))))
                  (t t))))
         (score-elements score)))

;;; Redrafting a score: the same elements, built again with other ids -----------

(defun redraft (element id-of ref-of)
  "ELEMENT built again with the constructors: the ID of it and of every element
inside it is (funcall ID-OF old-element); every tie END and spanner START and
END is (funcall REF-OF old-reference); every other slot is ELEMENT's."
  (labels ((d (e) (and e (redraft e id-of ref-of)))
           (ds (list) (mapcar #'d list))
           (k (e) (list :id (funcall id-of e) :provenance (element-provenance e)
                        :confidence (element-confidence e))))
    (let ((e element))
      (etypecase e
        (measure-info
         (apply #'make-measure-info
                :number (measure-info-number e) :time (measure-info-time e)
                :key (measure-info-key e) :pickup-p (measure-info-pickup-p e)
                :length (measure-info-length e) :barline (measure-info-barline e)
                :repeat-start (measure-info-repeat-start e) :repeat-end (measure-info-repeat-end e)
                :ending (d (measure-info-ending e)) :jump (ds (measure-info-jump e))
                :rehearsal (d (measure-info-rehearsal e)) :tempo (ds (measure-info-tempo e))
                (k e)))
        (ending (apply #'make-ending :passes (ending-passes e) :measures (ending-measures e) (k e)))
        (jump-mark (apply #'make-jump-mark :kind (jump-mark-kind e) (k e)))
        (rehearsal-mark (apply #'make-rehearsal-mark :text (rehearsal-mark-text e) (k e)))
        (tempo-mark (apply #'make-tempo-mark :offset (tempo-mark-offset e) :tempo (tempo-mark-tempo e)
                           :text (tempo-mark-text e) (k e)))
        (part (apply #'make-part :name (part-name e) :abbreviation (part-abbreviation e)
                     :staves (ds (part-staves e)) :voices (ds (part-voices e)) (k e)))
        (staff (apply #'make-staff :clef (staff-clef e) (k e)))
        (voice (apply #'make-voice :name (voice-name e) :staff (voice-staff e) :stem (voice-stem e)
                      :measures (mapcar (lambda (events) (ds (seq-list events)))
                                        (seq-list (voice-measures e)))
                      (k e)))
        (rest-event (apply #'make-rest-event
                           :duration (event-duration e) :tuplet (event-tuplet e)
                           :measure-rest-p (rest-event-measure-rest-p e) :hidden-p (rest-event-hidden-p e)
                           :fermata (d (event-fermata e)) :dynamic (d (event-dynamic e))
                           :lyrics (ds (event-lyrics e)) (k e)))
        (note-event (apply #'make-note-event
                           :pitch (note-pitch e) :duration (event-duration e) :tuplet (event-tuplet e)
                           :grace (event-grace e) :accidental (note-accidental e) :tie (d (note-tie e))
                           :articulations (ds (event-articulations e)) :fermata (d (event-fermata e))
                           :breath-mark (d (event-breath-mark e)) :dynamic (d (event-dynamic e))
                           :lyrics (ds (event-lyrics e)) (k e)))
        (chord-event (apply #'make-chord-event
                            :notes (ds (chord-event-notes e)) :duration (event-duration e)
                            :tuplet (event-tuplet e) :grace (event-grace e)
                            :articulations (ds (event-articulations e)) :fermata (d (event-fermata e))
                            :breath-mark (d (event-breath-mark e)) :dynamic (d (event-dynamic e))
                            :lyrics (ds (event-lyrics e)) (k e)))
        (chord-note (apply #'make-chord-note :pitch (note-pitch e) :accidental (note-accidental e)
                           :tie (d (note-tie e)) (k e)))
        (tie (apply #'make-tie :end (funcall ref-of (tie-end e)) (k e)))
        (articulation (apply #'make-articulation :kind (articulation-kind e) (k e)))
        (fermata (apply #'make-fermata :shape (fermata-shape e) (k e)))
        (breath-mark (apply #'make-breath-mark (k e)))
        (dynamic-mark (apply #'make-dynamic-mark :value (dynamic-mark-value e) (k e)))
        (lyric (apply #'make-lyric :verse (lyric-verse e) :text (lyric-text e)
                      :syllabic (lyric-syllabic e) :extender (lyric-extender e) (k e)))
        (chord-symbol-anchor (apply #'make-chord-symbol-anchor :position (anchor-position e)
                                    :symbol (anchor-symbol e) (k e)))
        (spanner (apply #'make-spanner :kind (spanner-kind e)
                        :start (funcall ref-of (spanner-start e))
                        :end (funcall ref-of (spanner-end e)) (k e)))))))

(defun redraft-score (score id-of ref-of &key (id-counter 0))
  "MAKE-SCORE of SCORE's metadata and elements, redrafted (REDRAFT)."
  (flet ((all (seq) (mapcar (lambda (e) (redraft e id-of ref-of)) (seq-list seq))))
    (make-score :metadata (score-metadata score)
                :measures (all (score-measure-map score))
                :parts (all (score-parts score))
                :chord-symbols (all (score-chord-symbols score))
                :spanners (all (score-spanners score))
                :id-counter id-counter)))

(defun two-pass-build (score id-plan)
  "SCORE's elements built twice without refs, as an importer did before SC3.
ID-PLAN maps each element of SCORE to the string id it is given, or NIL. Pass 1
gives every reference the placeholder \"zz\" (no serial); pass 2 gives each
reference the id pass 1 gave its target, matched by document order.
(values pass-2 table), TABLE mapping each old id to its element's id."
  (let* ((pass-1 (redraft-score score id-plan (constantly "zz")))
         (table (make-hash-table :test 'equal)))
    (loop for old in (score-elements score)
          for new in (score-elements pass-1)
          do (setf (gethash (element-id old) table) (element-id new)))
    (values (redraft-score score id-plan (lambda (ref) (values (gethash ref table ref))))
            table)))

(defun referenced-ids (score)
  "An EQUAL hash set of the ids SCORE's ties and spanners refer to."
  (let ((set (make-hash-table :test 'equal)))
    (dolist (e (score-elements score) set)
      (typecase e
        (tie (setf (gethash (tie-end e) set) t))
        (spanner (setf (gethash (spanner-start e) set) t
                       (gethash (spanner-end e) set) t))))))

;;; Builders and refs ---------------------------------------------------------------

(deftest builder-refs-are-interned
  (let* ((b (make-score-builder))
         (other (make-score-builder))
         (r (builder-ref b :a)))
    (ok (typep b 'score-builder))
    (ok (typep r 'draft-ref))
    (ok (eq r (builder-ref b :a)) "one ref per key")
    (ok (eq (builder-ref b (list 1 "x")) (builder-ref b (list 1 "x"))) "keys are compared with EQUAL")
    (ok (not (eq r (builder-ref b :b))))
    (ok (not (eq r (builder-ref other :a))) "builders don't share refs")
    (ok (eq :a (draft-ref-key r)))
    (ok (null (draft-ref-prefer r)) "no preferred id by default")
    (ok (equal "P1" (draft-ref-prefer (builder-ref b :p :prefer "P1"))))
    (ok (equal "P1" (draft-ref-prefer (builder-ref b :p))) "NIL leaves the preferred id")
    (ok (equal "P2" (draft-ref-prefer (builder-ref b :p :prefer "P2"))) "a new one replaces it")
    (ok (signals-type (lambda () (builder-ref b :q :prefer "1x")) 'type-error))
    (ok (signals-type (lambda () (builder-ref b :q :prefer :p1)) 'type-error))
    (ok (signals-type (lambda () (builder-ref :not-a-builder :q)) 'type-error))))

(deftest draft-constructors-take-refs
  (let ((b (make-score-builder)))
    (ok (eq (builder-ref b :n) (element-id (c4 :id (builder-ref b :n)))) "any :ID")
    (ok (eq (builder-ref b :m) (element-id (make-measure-info :id (builder-ref b :m)))))
    (ok (eq (builder-ref b :t) (tie-end (make-tie :end (builder-ref b :t)))) "a tie's END")
    (let ((s (make-spanner :kind :slur :start (builder-ref b :s) :end (builder-ref b :e))))
      (ok (eq (builder-ref b :s) (spanner-start s)) "a spanner's START")
      (ok (eq (builder-ref b :e) (spanner-end s)) "and END"))
    (ok (signals-type (lambda () (make-tie :end :t)) 'type-error) "other objects still don't")
    (ok (signals-type (lambda () (c4 :id b)) 'type-error))))

;;; One call: ties and a slur to later notes -------------------------------------

(defun forward-score (b &key (id-counter 0))
  "Two 2/4 bars, C4 C4 | C4 D4, in one voice. The first C4 is tied to the second
and the second to the third, across the barline; a slur runs from the first C4
to the D4. Every reference names a ref of B carried by a later note."
  (make-score
   :id-counter id-counter
   :measures (list (make-measure-info :time (parse-meter "2/4") :key (parse-key "C"))
                   (make-measure-info))
   :parts (list (make-part
                 :staves (list (make-staff))
                 :voices (list (make-voice
                                :measures
                                (list (list (c4 :id (builder-ref b :a) :tie (make-tie :end (builder-ref b :b)))
                                            (c4 :id (builder-ref b :b) :tie (make-tie :end (builder-ref b :c))))
                                      (list (c4 :id (builder-ref b :c))
                                            (make-note-event :id (builder-ref b :d) :pitch (p "D4")
                                                             :duration 1/4)))))))
   :spanners (list (make-spanner :id (builder-ref b :slur) :kind :slur
                                 :start (builder-ref b :a) :end (builder-ref b :d)))))

(deftest a-tie-and-a-slur-to-later-notes
  (let* ((b (make-score-builder))
         (s (forward-score b)))
    (ok (equal '("m-1" "m-2" "p-3" "st-4" "v-5" "e-6" "ti-7" "e-8" "ti-9" "e-a" "e-b" "sp-c")
               (ids (score-elements s)))
        "carriers are minted in document order, as id-less elements")
    (ok (= 12 (score-id-counter s)))
    (ok (equal "e-8" (tie-end (find-element s "ti-7"))) "a tie to the next note")
    (ok (equal "e-a" (tie-end (find-element s "ti-9"))) "and one across the barline")
    (let ((slur (find-element s "sp-c")))
      (ok (equal '("e-6" "e-b") (list (spanner-start slur) (spanner-end slur))) "the slur's endpoints"))
    (ok (null (check-score s)) "the score is valid")
    (ok (refs-free-p s) "a score holds no refs")
    (ok (equal '("e-6" "e-8" "e-a" "e-b" "sp-c")
               (mapcar (lambda (key) (builder-id b key)) '(:a :b :c :d :slur)))
        "BUILDER-ID reads the ids back")
    (ok (score-equal s (two-pass-build s (constantly nil)))
        "the same score as two builds")
    (let* ((b2 (make-score-builder))
           (s2 (forward-score b2 :id-counter 100)))
      (ok (equal "e-2y" (builder-id b2 :a)) "the counter applies: serial 106")
      (ok (equal (builder-id b2 :b) (tie-end (note-tie (find-element s2 "e-2y"))))))))

;;; References across voices and parts -------------------------------------------

(defun crossing-score (b &optional (id-of (lambda (key) (builder-ref b key)))
                             (ref-of (lambda (key) (builder-ref b key))))
  "Two 2/4 bars; part \"P\" with two voices on one staff, part \"Q\" with one.
Voice 1 holds two chords, C4 E4 | C4 E4, the first E4 tied to the second; voice
2 holds G3 | G3; Q rests, then plays A4. A slur runs from voice 1's first chord
to voice 2's second G3, a crescendo from voice 2's first G3 to Q's A4 (two
parts: a :SPANNER-ENDPOINT issue). The spanners are built first. ID-OF and
REF-OF give the id and the reference value of each key."
  (let* ((spanners (list (make-spanner :kind :slur :start (funcall ref-of :ch1) :end (funcall ref-of :g2))
                         (make-spanner :kind :crescendo :start (funcall ref-of :g1)
                                       :end (funcall ref-of :a4))))
         (chord (lambda (key e4-key tie)
                  (make-chord-event
                   :id (funcall id-of key) :duration 1/2
                   :notes (list (make-chord-note :pitch (p "C4"))
                                (make-chord-note :id (and e4-key (funcall id-of e4-key)) :pitch (p "E4")
                                                 :tie (and tie (make-tie :end (funcall ref-of tie))))))))
         (g3 (lambda (key) (make-note-event :id (funcall id-of key) :pitch (p "G3") :duration 1/2))))
    (make-score
     :measures (list (make-measure-info :time (parse-meter "2/4") :key (parse-key "C"))
                     (make-measure-info))
     :parts (list (make-part :id "P" :staves (list (make-staff))
                             :voices (list (make-voice :stem :up
                                                       :measures (list (list (funcall chord :ch1 nil :e4b))
                                                                       (list (funcall chord :ch2 :e4b nil))))
                                           (make-voice :stem :down
                                                       :measures (list (list (funcall g3 :g1))
                                                                       (list (funcall g3 :g2))))))
                  (make-part :id "Q" :staves (list (make-staff))
                             :voices (list (make-voice
                                            :measures (list (list (make-rest-event :duration 1/2))
                                                            (list (make-note-event :id (funcall id-of :a4)
                                                                                   :pitch (p "A4")
                                                                                   :duration 1/2)))))))
     :spanners spanners)))

(deftest references-across-voices-and-parts
  (let* ((b (make-score-builder))
         (s (crossing-score b))
         (plain (crossing-score b (constantly nil) (constantly "zz")))
         (tie (find-if (lambda (e) (typep e 'tie)) (score-elements s)))
         (spanners (seq-list (score-spanners s))))
    (ok (equal (ids (score-elements plain)) (ids (score-elements s)))
        "the ids an id-less build mints")
    (ok (refs-free-p s))
    (ok (equal (builder-id b :e4b) (tie-end tie)) "a tie to a chord note")
    (ok (let ((target (find-element s (tie-end tie))))
          (and (typep target 'chord-note)
               (eq (find-element s (builder-id b :ch2)) (element-parent s (element-id target)))))
        "the E4 of the second chord")
    (destructuring-bind (slur crescendo) spanners
      (ok (equal (list (builder-id b :ch1) (builder-id b :g2))
                 (list (spanner-start slur) (spanner-end slur)))
          "a slur from voice 1 to voice 2")
      (ok (eq (find-element s (element-id (second (part-voices (first (seq-list (score-parts s)))))))
              (element-parent s (spanner-end slur))))
      (ok (equal (list (builder-id b :g1) (builder-id b :a4))
                 (list (spanner-start crescendo) (spanner-end crescendo)))
          "a crescendo from part P to part Q")
      (ok (equal (list (list :spanner-endpoint (element-id crescendo) nil))
                 (issue-triples (check-score s)))
          "only the crescendo between parts is an issue"))))

;;; Refs that resolve to nothing ---------------------------------------------------

(defun dangling-score (b &key (tie-to :nowhere) slur-to (twice nil))
  "One 2/4 bar, C4 C4: the first note tied to (builder-ref b TIE-TO) and, when
SLUR-TO, slurred to it; the second note carries the key :second, and, when
TWICE, the first note carries it too."
  (make-score
   :measures (list (make-measure-info :time (parse-meter "2/4") :key (parse-key "C")))
   :parts (list (make-part
                 :staves (list (make-staff))
                 :voices (list (make-voice
                                :measures (list (list (c4 :id (builder-ref b (if twice :second :first))
                                                          :tie (make-tie :end (builder-ref b tie-to)))
                                                      (c4 :id (builder-ref b :second))))))))
   :spanners (and slur-to (list (make-spanner :kind :slur :start (builder-ref b :first)
                                              :end (builder-ref b slur-to))))))

(deftest a-dangling-reference-signals
  (let* ((b (make-score-builder))
         (thunk (lambda () (dangling-score b)))
         (c (signalled thunk)))
    (ok (typep c 'unresolved-reference))
    (ok (typep c 'score-error))
    (ok (and (typep c 'unresolved-reference) (eq :nowhere (unresolved-reference-key c))))
    (ok (and (typep c 'score-error) (equal "no element carries it" (score-error-reason c))))
    (ok (and c (search "no element carries it" (princ-to-string c))) "the report says why")
    (ok (find-restart-p 'unresolved-reference 'use-value thunk))
    (let ((s (with-restart 'unresolved-reference 'use-value thunk "e-77")))
      (ok (equal "e-77" (tie-end (find-element s "ti-6"))) "USE-VALUE stores its id")
      (ok (= 7 (score-id-counter s)) "a reference never raises the counter")
      (ok (equal "e-5" (builder-id b :first))))
    (ok (signals-type (lambda () (with-restart 'unresolved-reference 'use-value thunk 42)) 'type-error)
        "USE-VALUE takes an id string")
    (let ((keys '()))
      (handler-bind ((unresolved-reference (lambda (c)
                                             (push (unresolved-reference-key c) keys)
                                             (use-value "zz" c))))
        (dangling-score b :tie-to :gone :slur-to :lost))
      (ok (equal '(:gone :lost) (nreverse keys)) "one condition per ref, in document order"))
    (let ((s (handler-bind ((unresolved-reference (lambda (c) (use-value "zz" c))))
               (dangling-score b :tie-to :second :slur-to :lost))))
      (ok (equal "zz" (spanner-end (first (seq-list (score-spanners s))))) "a spanner's END")
      (ok (equal (builder-id b :second) (tie-end (find-element s "ti-6")))))))

(deftest a-ref-carried-twice-signals
  (let* ((b (make-score-builder))
         (thunk (lambda () (dangling-score b :tie-to :second :twice t)))
         (c (signalled thunk)))
    (ok (typep c 'unresolved-reference))
    (ok (and (typep c 'unresolved-reference) (eq :second (unresolved-reference-key c))))
    (ok (and (typep c 'score-error) (equal "carried by more than one element" (score-error-reason c))))
    (ok (not (find-restart-p 'unresolved-reference 'use-value thunk)) "no restart")))

(deftest a-failed-build-records-nothing
  (let ((b (make-score-builder)))
    (ok (typep (signalled (lambda () (dangling-score b))) 'unresolved-reference))
    (ok (null (builder-id b :first :errorp nil)))
    (ok (null (builder-id b :second :errorp nil)))))

;;; Preferred ids -------------------------------------------------------------------

(defun preferring-score (b &optional (id-of (lambda (key prefer) (builder-ref b key :prefer prefer)))
                               (ref-of (lambda (key) (builder-ref b key))))
  "One 5/4 bar. The part prefers \"P1\", the staff \"late\" (the crescendo's given
id), the voice \"sop\"; of five quarter notes, the first prefers \"x-1\", the
second \"x-1\" too, the third is given \"given\", the fourth prefers \"given\",
the fifth \"e-20\" (serial 72). A slur (a ref, no preference) runs from the
second note to the fifth, and a crescendo given \"late\" from the first to the
third. ID-OF gives the id of a key and its preferred id, REF-OF the reference."
  (make-score
   :measures (list (make-measure-info :time (parse-meter "5/4") :key (parse-key "C")))
   :parts (list (make-part
                 :id (funcall id-of :p "P1")
                 :staves (list (make-staff :id (funcall id-of :st "late")))
                 :voices (list (make-voice
                                :id (funcall id-of :v "sop")
                                :measures (list (list (c4 :id (funcall id-of :a "x-1"))
                                                      (c4 :id (funcall id-of :b "x-1"))
                                                      (c4 :id "given")
                                                      (c4 :id (funcall id-of :c "given"))
                                                      (c4 :id (funcall id-of :d "e-20"))))))))
   :spanners (list (make-spanner :id (funcall id-of :s nil) :kind :slur
                                 :start (funcall ref-of :b) :end (funcall ref-of :d))
                   (make-spanner :id "late" :kind :crescendo
                                 :start (funcall ref-of :a) :end "given"))))

(deftest preferred-ids-first-taker
  (let* ((b (make-score-builder))
         (s (preferring-score b)))
    (ok (equal '("m-21" "P1" "st-22" "sop" "x-1" "e-23" "given" "e-24" "e-20" "sp-25" "late")
               (ids (score-elements s)))
        "the first taker wins, a given id always wins, taken serials count")
    (ok (= 77 (score-id-counter s)))
    (ok (equal '("P1" "st-22" "sop" "x-1" "e-23" "e-24" "e-20" "sp-25")
               (mapcar (lambda (key) (builder-id b key)) '(:p :st :v :a :b :c :d :s))))
    (ok (equal '("e-23" "e-20") (let ((slur (find-element s "sp-25")))
                                  (list (spanner-start slur) (spanner-end slur)))))
    (ok (equal '("x-1" "given") (let ((crescendo (find-element s "late")))
                                  (list (spanner-start crescendo) (spanner-end crescendo)))))
    (let* ((taken '((:p . "P1") (:v . "sop") (:a . "x-1") (:d . "e-20")))
           (final (lambda (key) (builder-id b key)))
           (two-pass (preferring-score b (lambda (key prefer)
                                           (declare (ignore prefer))
                                           (cdr (assoc key taken)))
                                       final)))
      (ok (score-equal s two-pass) "the score a build with the taken ids given gives")
      (ok (= (score-id-counter two-pass) (score-id-counter s))))))

(deftest preferred-ids-follow-document-order
  (let* ((b (make-score-builder))
         (note (make-note-event
                :id "n" :pitch (p "C4") :duration 1
                :articulations (list (make-articulation :id (builder-ref b :staccato :prefer "art")
                                                        :kind :staccato)
                                     (make-articulation :id (builder-ref b :accent :prefer "art")
                                                        :kind :accent))))
         (part (make-part :staves (list (make-staff :id "s"))
                          :voices (list (make-voice :id "v"
                                                    :measures (list (list note)
                                                                    (list (make-rest-event :id "r"
                                                                                           :duration 1)))))))
         (late (make-chord-symbol-anchor :id (builder-ref b :late :prefer "chord") :position '(2 . 0)
                                         :symbol (make-chord-symbol :root (pc "G") :quality :major)))
         (early (make-chord-symbol-anchor :id (builder-ref b :early :prefer "chord") :position '(1 . 0)
                                          :symbol (make-chord-symbol :root (pc "C") :quality :major)))
         (s (make-score :measures (list (make-measure-info :time (parse-meter "4/4") :key (parse-key "C"))
                                        (make-measure-info))
                        :parts (list part)
                        :chord-symbols (list late early))))
    (ok (equal "art" (builder-id b :accent)) "articulations are sorted by kind first")
    (ok (equal "ar-4" (builder-id b :staccato)))
    (ok (equal "chord" (builder-id b :early)) "the chord-symbol track is sorted first")
    (ok (equal "h-5" (builder-id b :late)))
    (ok (equal '("m-1" "m-2" "p-3" "s" "v" "n" "art" "ar-4" "r" "chord" "h-5")
               (ids (score-elements s))))))

;;; Sharing -----------------------------------------------------------------------------

(deftest untouched-subtrees-stay-eq
  (let* ((b (make-score-builder))
         (measure (make-measure-info :id "m" :time (parse-meter "2/4") :key (parse-key "C")))
         (plain-part (make-part :id "plain" :staves (list (make-staff :id "ps"))
                                :voices (list (make-voice :id "pv" :measures (list (list (c4 :id "pe")
                                                                                         (c4 :id "pf")))))))
         (kept (c4 :id "kept"))
         (draft-part (make-part :id "draft" :staves (list (make-staff :id "ds"))
                                :voices (list (make-voice :id "dv"
                                                          :measures (list (list kept
                                                                                (c4 :id (builder-ref b :r))))))))
         (plain-spanner (make-spanner :id "plain-sp" :kind :slur :start "pe" :end "pf"))
         (draft-spanner (make-spanner :id "draft-sp" :kind :slur :start "kept" :end (builder-ref b :r)))
         (s (make-score :measures (list measure) :parts (list plain-part draft-part)
                        :spanners (list plain-spanner draft-spanner))))
    (ok (eq measure (first (seq-list (score-measure-map s)))))
    (ok (eq plain-part (first (seq-list (score-parts s)))) "a part with no refs is the given object")
    (ok (eq plain-spanner (find-element s "plain-sp")))
    (ok (eq kept (find-element s "kept")) "so is an event with no refs beside a carrier")
    (let ((part (second (seq-list (score-parts s)))))
      (ok (not (eq draft-part part)) "a part that holds a carrier is rebuilt")
      (ok (equal "draft" (element-id part)) "with its id")
      (ok (eq (first (part-staves draft-part)) (first (part-staves part))) "and its untouched staff"))
    (let ((spanner (find-element s "draft-sp")))
      (ok (not (eq draft-spanner spanner)) "a spanner that refers to a ref is rebuilt")
      (ok (equal (list "kept" (builder-id b :r)) (list (spanner-start spanner) (spanner-end spanner)))))
    (ok (equal "e-1" (builder-id b :r)))))

;;; Drafts added to a score ------------------------------------------------------------

(deftest copy-score-takes-drafts
  (let* ((s (fixture-score "sc0-satb"))
         (c (score-id-counter s))
         (b (make-score-builder))
         (bars (fset:size (score-measure-map s)))
         (old-parts (seq-list (score-parts s)))
         (old-spanners (seq-list (score-spanners s)))
         (first-event (find-if (lambda (e) (typep e 'note-event)) (score-elements s)))
         (new-part (make-part
                    :staves (list (make-staff))
                    :voices (list (make-voice
                                   :measures (cons (list (c4 :id (builder-ref b :n1)
                                                             :tie (make-tie :end (builder-ref b :n2)))
                                                         (c4 :id (builder-ref b :n2)))
                                                   (make-list (1- bars)))))))
         (new (copy-score s :parts (append old-parts (list new-part))
                            :spanners (append old-spanners
                                              (list (make-spanner :id (builder-ref b :sl) :kind :slur
                                                                  :start (builder-ref b :n1)
                                                                  :end (builder-ref b :n2))
                                                    (make-spanner :kind :crescendo
                                                                  :start (element-id first-event)
                                                                  :end (builder-ref b :n2))))))
         (serial (lambda (prefix k) (format nil "~A-~(~36R~)" prefix (+ c k)))))
    (ok (every #'eq old-parts (seq-list (score-parts new))) "the score's parts are shared")
    (ok (every #'eq (seq-list (score-measure-map s)) (seq-list (score-measure-map new))))
    (ok (every #'eq old-spanners (seq-list (score-spanners new))))
    (ok (equal (list (funcall serial "e" 4) (funcall serial "e" 6) (funcall serial "sp" 7))
               (list (builder-id b :n1) (builder-id b :n2) (builder-id b :sl)))
        "new elements are minted from the score's counter, in document order")
    (ok (equal (builder-id b :n2) (tie-end (note-tie (find-element new (builder-id b :n1))))))
    (ok (equal (list (element-id first-event) (builder-id b :n2))
               (let ((crescendo (car (last (seq-list (score-spanners new))))))
                 (list (spanner-start crescendo) (spanner-end crescendo))))
        "a reference may name a score's id or a ref")
    (ok (= (+ c 8) (score-id-counter new)))))

;;; Reading ids back -------------------------------------------------------------------

(deftest builder-id-reads-the-latest-build
  (let ((b (make-score-builder)))
    (ok (null (builder-id b :a :errorp nil)) "a key with no ref")
    (let ((c (signalled (lambda () (builder-id b :a)))))
      (ok (typep c 'unresolved-reference))
      (ok (and (typep c 'unresolved-reference) (eq :a (unresolved-reference-key c))))
      (ok (and (typep c 'score-error) (equal "not carried in a built score" (score-error-reason c)))))
    (builder-ref b :a)
    (ok (null (builder-id b :a :errorp nil)) "a ref no build has carried")
    (ok (eq :none (handler-bind ((unresolved-reference (lambda (c) (use-value :none c))))
                    (builder-id b :a)))
        "USE-VALUE returns its value")
    (forward-score b)
    (ok (equal "e-6" (builder-id b :a)))
    (forward-score b :id-counter 100)
    (ok (equal "e-2y" (builder-id b :a)) "the latest build")))

;;; Refs are for building ---------------------------------------------------------------

(defun op-label (op)
  "A label for OP: its class name."
  (string-downcase (class-name (class-of op))))

(deftest edits-refuse-draft-refs
  (let* ((b (make-score-builder))
         (base (base))
         (ops (list (make-add-spanner :spanner (make-spanner :kind :slur :start "a"
                                                             :end (builder-ref b :x)))
                    (make-add-spanner :spanner (make-spanner :id (builder-ref b :w) :kind :slur
                                                             :start "f" :end "g"))
                    (make-add-mark :target "b" :mark (make-tie :end (builder-ref b :y)))
                    (make-insert-event :voice "v1" :measure "m3" :offset 1/2
                                       :event (make-note-event :id (builder-ref b :z) :pitch (p "A4")
                                                               :duration 1/4)))))
    (dolist (op ops)
      (let ((c (condition-of (lambda () (apply-edit base op)))))
        (ok (typep c 'invalid-edit) (op-label op))
        (ok (and (typep c 'invalid-edit) (eq op (invalid-edit-op c))))
        (ok (and (typep c 'score-error) (equal "draft reference" (score-error-reason c))))))
    (ok (typep (condition-of (lambda () (invert-edit base (first ops)))) 'invalid-edit)
        "INVERT-EDIT too")
    (ok (find-restart-p 'invalid-edit 'skip-edit (lambda () (apply-edit base (first ops)))))
    (let* ((member (third ops))
           (composite (make-composite-edit :ops (list (make-set-pitch :id "b" :pitch (p "F4")) member)))
           (c (condition-of (lambda () (apply-edit base composite)))))
      (ok (and (typep c 'invalid-edit) (eq member (invalid-edit-op c))) "a member names itself"))))

;;; Equivalence with two builds, over fixtures and corpus pieces -------------------------

(defparameter +sc3-corpus+
  '("sc3-corpus-hymn-split" "sc3-corpus-minuet-in-g" "sc3-corpus-new-britain")
  "Score-parity corpus pieces read by score-backend-musicxml, in canonical form.")

(defparameter +equivalence-scores+
  (append +fixture-scores+ (list "sc1-open-score") +sc3-corpus+)
  "The scores the equivalence properties run on.")

(defun mixed-plan (score)
  "A draft of SCORE's elements, by each element's index i in document order:
element i is given its own id when i mod 7 = 3; any other carries the ref keyed
by its id, preferring \"dup\" when i mod 5 = 1, \"k\" and its id when i mod 4 =
2, the id of element i - 1 when i mod 6 = 5, and nothing otherwise.
(values id-of expected-id-of ref-of keys): ID-OF and REF-OF, functions of a
builder, give the draft's ids and references; EXPECTED-ID-OF is the plan of a
build without refs, the given id or the preferred id the element takes by the
first-taker rule (worked out here), else NIL; KEYS lists the refs' keys."
  (let ((given (make-hash-table :test 'equal))   ; given id → T
        (keys (make-hash-table :test 'equal))    ; ref key → T
        (prefers (make-hash-table :test 'eq))    ; element → its preferred id
        (taken (make-hash-table :test 'equal))   ; preferred id → T once taken
        (takes (make-hash-table :test 'eq))      ; element → the id it takes
        (elements (score-elements score)))
    (loop for e in elements
          for i from 0
          for id = (element-id e)
          for previous = nil then before
          for before = id
          do (if (= 3 (mod i 7))
                 (setf (gethash id given) t)
                 (setf (gethash id keys) t
                       (gethash e prefers) (cond ((= 1 (mod i 5)) "dup")
                                                 ((= 2 (mod i 4)) (concatenate 'string "k" id))
                                                 ((= 5 (mod i 6)) previous)))))
    ;; The first taker, in document order; a given id is never taken.
    (dolist (e elements)
      (let ((prefer (gethash e prefers)))
        (when (and prefer (not (gethash prefer given)) (not (gethash prefer taken)))
          (setf (gethash prefer taken) t
                (gethash e takes) prefer))))
    (values (lambda (b)
              (lambda (e)
                (let ((id (element-id e)))
                  (if (gethash id given)
                      id
                      (builder-ref b id :prefer (gethash e prefers))))))
            (lambda (e)
              (let ((id (element-id e)))
                (if (gethash id given) id (values (gethash e takes)))))
            (lambda (b)
              (lambda (ref)
                (if (gethash ref keys) (builder-ref b ref) ref)))
            (loop for key being the hash-keys of keys collect key))))

(deftest-parametrize drafts-build-as-two-builds
    ((name) :rows +equivalence-scores+)
  (let* ((score (fixture-score name))
         (targets (referenced-ids score))
         (ref-of (lambda (b)
                   (lambda (ref)
                     (if (find-element score ref :errorp nil) (builder-ref b ref) ref)))))
    (multiple-value-bind (expected table) (two-pass-build score (constantly nil))
      (let* ((b (make-score-builder))
             (built (redraft-score score
                                   (lambda (e) (builder-ref b (element-id e)))
                                   (funcall ref-of b))))
        (ok (score-equal expected built) "every element carries a ref")
        (ok (= (score-id-counter expected) (score-id-counter built)))
        (ok (refs-free-p built))
        (ok (every (lambda (e) (equal (gethash (element-id e) table) (builder-id b (element-id e))))
                   (score-elements score))
            "BUILDER-ID gives each carrier the id the first build minted"))
      (let* ((b (make-score-builder))
             (built (redraft-score score
                                   (lambda (e) (and (gethash (element-id e) targets)
                                                    (builder-ref b (element-id e))))
                                   (funcall ref-of b))))
        (ok (score-equal expected built) "only the targets of references carry refs")))
    (multiple-value-bind (id-of expected-id-of mixed-ref-of keys) (mixed-plan score)
      (multiple-value-bind (expected table) (two-pass-build score expected-id-of)
        (let* ((b (make-score-builder))
               (built (redraft-score score (funcall id-of b) (funcall mixed-ref-of b))))
          (ok (score-equal expected built)
              "given and preferred ids, with collisions: as two builds with the taken ids given")
          (ok (= (score-id-counter expected) (score-id-counter built)))
          (ok (every (lambda (key) (equal (gethash key table) (builder-id b key))) keys)
              "BUILDER-ID agrees"))))))
