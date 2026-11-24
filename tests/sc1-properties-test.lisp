;;;; SC1 properties over random edit sequences (src/edits.lisp): after every
;;;; operation the score is valid, the change set is exactly the difference,
;;;; everything unchanged is shared (EQ), the input is untouched, INVERT-EDIT
;;;; restores the score with the mirror change set, and operations and inverses
;;;; serialise. The generator is a fixed linear congruential sequence, so every
;;;; run (and every correct implementation) sees the same operations; an
;;;; operation the score refuses (INVALID-EDIT) is skipped and counted.

(in-package #:score-protocol/tests)

(defvar *seed* 1)

(defun rnd (n)
  "A pseudo-random integer in [0, N): a fixed LCG, the same on every Lisp."
  (setf *seed* (mod (+ (* *seed* 1103515245) 12345) 2147483648))
  (mod (floor *seed* 65536) n))

(defun pick (list) (and list (nth (rnd (length list)) list)))

(defun ids-of (score type)
  (loop for e in (score-elements score) when (typep e type) collect (element-id e)))

(defun non-grace-events (score)
  (loop for e in (score-elements score)
        when (and (typep e 'event) (not (and (typep e 'sounding-event) (event-grace e))))
          collect (element-id e)))

(defun voice-measure-at (score voice-id bar)
  (seq-list (fset:@ (voice-measures (find-element score voice-id)) (- bar (score-first-bar score)))))

(defun boundaries (score voice-id bar)
  "The event boundaries of the voice measure (0 for a silent one)."
  (let ((at 0) (out '()))
    (dolist (e (voice-measure-at score voice-id bar) (or (nreverse out) (list 0)))
      (unless (and (typep e 'sounding-event) (event-grace e))
        (push at out)
        (incf at (event-duration e))))))

(defun random-pitch-near (pitch)
  (transpose-pitch pitch (parse-interval (pick '("M2" "-M2" "m3" "-m3" "P1")))))

(defun random-bar (score)
  (+ (score-first-bar score) (rnd (1+ (- (score-last-bar score) (score-first-bar score))))))

(defun random-op (score)
  "An operation for SCORE, usually one it accepts."
  (let ((kind (rnd 19)))
    (flet ((mid (bar) (element-id (bar-measure score bar))))
      (case kind
        (0 (let ((id (pick (ids-of score '(or note-event chord-note)))))
             (and id (make-set-pitch :id id :pitch (random-pitch-near (note-pitch (find-element score id)))))))
        (1 (let ((id (pick (ids-of score '(or note-event chord-note)))))
             (and id (make-set-accidental :id id :accidental (pick '(:auto :forced :cautionary))))))
        (2 (let ((id (pick (non-grace-events score))))
             (and id (make-set-duration :id id :duration (pick '(1/8 1/4 3/8 1/2 3/4 1))))))
        ((3 4) (let* ((voice (pick (ids-of score 'voice)))
                      (bar (random-bar score)))
                 (make-insert-event :voice voice :measure (mid bar)
                                    :offset (pick (boundaries score voice bar))
                                    :event (make-note-event :pitch (parse-pitch (pick '("C4" "E4" "G4" "B3")))
                                                            :duration (pick '(1/8 1/4)))
                                    :reflow (= kind 4))))
        (5 (let ((id (pick (ids-of score '(or note-event chord-event)))))
             (and id (make-delete-event :id id))))
        (6 (let* ((id (pick (ids-of score 'note-event)))
                  (note (and id (find-element score id))))
             (and note (null (event-grace note))
                  (make-replace-event
                   :id id
                   :event (make-chord-event
                           :notes (list (make-chord-note :pitch (note-pitch note))
                                        (make-chord-note :pitch (transpose-pitch (note-pitch note)
                                                                                 (parse-interval "M3"))))
                           :duration (event-duration note) :tuplet (event-tuplet note))))))
        (7 (let ((id (pick (ids-of score 'sounding-event))))
             (and id (make-add-mark :target id
                                    :mark (ecase (rnd 4)
                                            (0 (make-dynamic-mark :value (pick '(:p :mf :f))))
                                            (1 (make-fermata))
                                            (2 (make-articulation :kind (pick '(:accent :staccato))))
                                            (3 (make-lyric :verse (1+ (rnd 2)) :text "la")))))))
        (8 (make-add-mark :target (mid (random-bar score))
                          :mark (if (zerop (rnd 2))
                                    (make-tempo-mark :text "a tempo")
                                    (make-rehearsal-mark :text "X"))))
        (9 (let ((id (pick (ids-of score '(or dynamic-mark fermata breath-mark articulation tie lyric
                                           tempo-mark rehearsal-mark)))))
             (and id (make-remove-mark :id id))))
        (10 (let* ((voice (pick (ids-of score 'voice)))
                   (notes (and voice (remove-if-not (lambda (e) (and (typep e 'note-event) (null (event-grace e))))
                                                    (voice-measure-at score voice (random-bar score))))))
              (and (second notes)
                   (make-add-spanner :spanner (make-spanner :kind :slur :start (element-id (first notes))
                                                            :end (element-id (second notes)))))))
        (11 (let ((id (pick (ids-of score 'spanner)))) (and id (make-remove-spanner :id id))))
        (12 (make-add-chord-symbol
             :anchor (make-chord-symbol-anchor
                      :position (cons (random-bar score) 0)
                      :symbol (make-chord-symbol :root (parse-pitch-class (pick '("C" "F" "G" "Bb")))
                                                 :quality :major))))
        (13 (let ((id (pick (ids-of score 'chord-symbol-anchor)))) (and id (make-remove-chord-symbol :id id))))
        (14 (let ((bar (random-bar score)))
              (if (zerop (rnd 2))
                  (make-set-key :measure (mid bar)
                                :key (parse-key (pick '("G major" "F major" "D minor"))))
                  (make-set-time :measure (mid bar) :time (parse-meter (pick '("3/4" "2/4" "6/8" "4/4")))))))
        (15 (if (zerop (rnd 2))
                (make-insert-measures :before (mid (random-bar score)) :count 1)
                (make-insert-measures :count 1)))
        (16 (and (> (score-last-bar score) (score-first-bar score))
                 (make-delete-measures :measure (mid (random-bar score)))))
        (17 (let* ((a (random-bar score)) (b (random-bar score)))
              (make-transpose :interval (parse-interval (pick '("M2" "-m3" "P4" "-P5" "m2")))
                              :from (and (zerop (rnd 2)) (mid (min a b)))
                              :to (and (zerop (rnd 2)) (mid (max a b))))))
        (18 (let* ((voice (pick (ids-of score 'voice)))
                   (bar (random-bar score)))
              (if (zerop (rnd 3))
                  (make-composite-edit :ops (remove nil (list (random-op score) (random-op score))))
                  (make-set-voice-measures
                   :voice voice :measure (mid bar)
                   :measures (list (list (make-rest-event :duration (bar-length score bar)
                                                          :measure-rest-p t)))))))))))

(defparameter +property-scores+
  (append +fixture-scores+ '("sc1-open-score" :base :four-bars)))

(defun property-score (name)
  (case name
    (:base (base))
    (:four-bars (four-bars))
    (t (fixture-score name))))

(defun check-step (before op)
  "Apply OP to BEFORE and check every property. (values after failures), or
(values nil :skipped) when the score refuses OP."
  (let ((form-before (score-to-sexp before)))
    (multiple-value-bind (after changes)
        (handler-case (apply-edit before op)
          (invalid-edit () (return-from check-step (values nil :skipped))))
      (let ((failures '()))
        (flet ((fail (what) (push what failures)))
          (unless (null (check-score after)) (fail :invalid))
          (unless (equal (expected-change-set before after) (change-lists changes)) (fail :change-set))
          (when (unshared before after) (fail :sharing))
          (unless (equal form-before (score-to-sexp before)) (fail :input-changed))
          (unless (score-equal after (apply-edit before (sexp-to-edit (edit-to-sexp op))))
            (fail :op-form))
          (let ((inverse (invert-edit before op)))
            (multiple-value-bind (back back-changes) (apply-edit after inverse)
              (unless (score-equal back before) (fail :inverse))
              (unless (and (equal (change-set-created back-changes) (change-set-removed changes))
                           (equal (change-set-removed back-changes) (change-set-created changes))
                           (null (set-exclusive-or (change-set-modified back-changes)
                                                   (change-set-modified changes) :test #'string=)))
                (fail :inverse-change-set)))
            (let ((form (edit-to-sexp inverse)))
              (unless (equal form (edit-to-sexp (sexp-to-edit form))) (fail :inverse-form)))))
        (values after (nreverse failures))))))

(defvar *applied-kinds* (make-hash-table))

(deftest-parametrize random-edit-sequences
    ((name) :rows +property-scores+)
  (let ((*seed* (1+ (position name +property-scores+ :test #'equal)))
        (score (property-score name))
        (applied 0) (skipped 0) (bad '()))
    (dotimes (step 24)
      (let ((op (random-op score)))
        (when op
          (multiple-value-bind (after failures) (check-step score op)
            (cond ((eq failures :skipped) (incf skipped))
                  (t (incf applied)
                     (setf (gethash (class-name (class-of op)) *applied-kinds*) t)
                     (when failures (push (list step (edit-to-sexp op) failures) bad))
                     (setf score after)))))))
    (ok (null bad) (format nil "~A: ~D failing steps~@[, first ~S~]" name (length bad)
                           (first (last bad))))
    (ok (>= applied 12) (format nil "~A: ~D applied, ~D refused" name applied skipped))))

(deftest random-edits-cover-every-operation
  (ok (null (set-difference '(insert-event delete-event replace-event set-voice-measures set-pitch
                              set-accidental set-duration add-mark remove-mark add-spanner remove-spanner
                              add-chord-symbol remove-chord-symbol set-key set-time insert-measures
                              delete-measures transpose composite-edit)
                            (loop for k being the hash-keys of *applied-kinds* collect k)))
      "the sequences above applied every kind of operation"))
