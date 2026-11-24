;;;; Conditions for every score-protocol slice (CLHS 9). The protocol owns the
;;;; types; backends signal them. Restarts are established at the signal site:
;;;;
;;;;   FIND-ELEMENT, ELEMENT-PARENT, ELEMENT-POSITION (SC0): UNKNOWN-ELEMENT
;;;;     inside a USE-VALUE restart; its value is returned.
;;;;   ABSOLUTE-OFFSET, OFFSET-POSITION and the BAR-* functions (SC0):
;;;;     INVALID-POSITION inside a USE-VALUE restart; its value is returned.
;;;;   VALIDATE-SCORE (SC0): SCORE-INVARIANT-VIOLATION inside a CONTINUE
;;;;     restart, which returns the score as it is.
;;;;   APPLY-EDIT and INVERT-EDIT (SC1): INVALID-EDIT, and each of its
;;;;     subtypes, inside SKIP-EDIT (the score is returned unchanged with an
;;;;     empty change set) and USE-VALUE (an operation to apply instead).
;;;;     MEASURE-OVERFULL adds REFLOW (the same INSERT-EVENT with REFLOW true).
;;;;     Which operation signals which subtype, and when: edits.lisp.
;;;;   MusicXML readers (SC2): MUSICXML-UNSUPPORTED inside SKIP-ELEMENT.
;;;;
;;;; Warnings: LOSSY-CONVERSION is signalled with WARN. LOW-CONFIDENCE-GUESS is
;;;; signalled with SIGNAL, so it is silent unless a handler is bound (importers
;;;; record the guess in the element's confidence either way).
;;;;
;;;; Malformed SMF input belongs to midi-protocol, which has nothing
;;;; score-specific; score-backend-midi reports it as a SCORE-FORMAT-ERROR whose
;;;; CAUSE is midi-protocol's condition.

(in-package #:score-protocol)

(define-condition score-error (error)
  ((reason :initarg :reason :initform nil :reader score-error-reason
           :documentation "A short lower-case explanation, or NIL."))
  (:report (lambda (c s)
             (format s "~A~@[: ~A~]"
                     (string-downcase (symbol-name (type-of c)))
                     (score-error-reason c)))))

(define-condition invalid-position (score-error)
  ((position :initarg :position :initform nil :reader invalid-position-position
             :documentation "The rejected argument: a (bar . offset) cons, a bar
number, or an absolute offset."))
  (:report (lambda (c s)
             (format s "invalid position ~S~@[: ~A~]"
                     (invalid-position-position c) (score-error-reason c)))))

(define-condition unknown-element (score-error)
  ((id :initarg :id :initform nil :reader unknown-element-id))
  (:report (lambda (c s)
             (format s "no element with id ~S" (unknown-element-id c)))))

(define-condition score-invariant-violation (score-error)
  ((issues :initarg :issues :initform '() :reader score-invariant-violation-issues
           :documentation "The SCORE-ISSUEs CHECK-SCORE found."))
  (:report (lambda (c s)
             (let ((issues (score-invariant-violation-issues c)))
               (format s "score invariant violated: ~D issue~:P~@[, first ~S~]"
                       (length issues) (first issues))))))

(define-condition invalid-edit (score-error)
  ((op :initarg :op :initform nil :reader invalid-edit-op
       :documentation "The edit operation that can't be applied."))
  (:report (lambda (c s)
             (format s "invalid edit ~S~@[: ~A~]"
                     (invalid-edit-op c) (score-error-reason c)))))

(define-condition edit-target-missing (invalid-edit unknown-element) ()
  (:documentation "An id the operation names is not in the score.")
  (:report (lambda (c s)
             (format s "invalid edit ~S: no element with id ~S"
                     (invalid-edit-op c) (unknown-element-id c)))))

(define-condition edit-position-invalid (invalid-edit invalid-position) ()
  (:documentation "A position, bar range or duration of the operation lies outside
the score or off the voice's event boundaries.")
  (:report (lambda (c s)
             (format s "invalid edit ~S: position ~S~@[: ~A~]"
                     (invalid-edit-op c) (invalid-position-position c)
                     (score-error-reason c)))))

(define-condition measure-overfull (invalid-edit)
  ((voice :initarg :voice :initform nil :reader measure-overfull-voice
          :documentation "The id of the voice.")
   (bar :initarg :bar :initform nil :reader measure-overfull-bar
        :documentation "The bar that would overflow.")
   (excess :initarg :excess :initform nil :reader measure-overfull-excess
           :documentation "How much sounding music would pass its barline, in whole notes."))
  (:documentation "INSERT-EVENT without REFLOW would push sounding music past the
barline of its voice measure.")
  (:report (lambda (c s)
             (format s "invalid edit ~S: voice ~S overfills bar ~S by ~S"
                     (invalid-edit-op c) (measure-overfull-voice c)
                     (measure-overfull-bar c) (measure-overfull-excess c)))))

(define-condition edit-breaks-score (invalid-edit score-invariant-violation) ()
  (:documentation "The edited score has CHECK-SCORE issues the score before the
edit did not have (edits.lisp). ISSUES holds them.")
  (:report (lambda (c s)
             (let ((issues (score-invariant-violation-issues c)))
               (format s "invalid edit ~S: ~D new issue~:P~@[, first ~S~]"
                       (invalid-edit-op c) (length issues) (first issues))))))

(define-condition score-format-error (score-error)
  ((format :initarg :format :initform nil :reader score-format-error-format
           :documentation "The format keyword: :SEXP, :MUSICXML, :MXL, :MIDI.")
   (position :initarg :position :initform nil :reader score-format-error-position
             :documentation "Where decoding stopped, in the format's own terms: for
:SEXP the offending sub-form.")
   (cause :initarg :cause :initform nil :reader score-format-error-cause
          :documentation "The underlying condition, or NIL."))
  (:report (lambda (c s)
             (format s "~(~A~) format error~@[: ~A~]~@[ at ~S~]"
                     (score-format-error-format c) (score-error-reason c)
                     (score-format-error-position c)))))

(define-condition musicxml-unsupported (score-format-error)
  ((element :initarg :element :initform nil :reader musicxml-unsupported-element
            :documentation "The MusicXML element name outside the mapping.")))

(define-condition score-warning (warning) ())

(define-condition lossy-conversion (score-warning)
  ((format :initarg :format :initform nil :reader lossy-conversion-format)
   (what :initarg :what :initform nil :reader lossy-conversion-what
         :documentation "A short description of what was dropped, e.g. \"ids\"."))
  (:report (lambda (c s)
             (format s "lossy conversion to ~(~A~)~@[: ~A dropped~]"
                     (lossy-conversion-format c) (lossy-conversion-what c)))))

(define-condition low-confidence-guess (score-warning)
  ((element-id :initarg :element-id :initform nil :reader low-confidence-guess-element-id)
   (what :initarg :what :initform nil :reader low-confidence-guess-what)
   (confidence :initarg :confidence :initform nil :reader low-confidence-guess-confidence))
  (:report (lambda (c s)
             (format s "low-confidence guess~@[ for ~S~]~@[ (~A)~]~@[: ~A~]"
                     (low-confidence-guess-element-id c) (low-confidence-guess-what c)
                     (low-confidence-guess-confidence c)))))

(defun skip-edit (&optional condition)
  "Invoke the SKIP-EDIT restart (established by APPLY-EDIT, SC1)."
  (let ((restart (find-restart 'skip-edit condition)))
    (when restart (invoke-restart restart))))

(defun reflow (&optional condition)
  "Invoke the REFLOW restart (established by APPLY-EDIT for MEASURE-OVERFULL, SC1)."
  (let ((restart (find-restart 'reflow condition)))
    (when restart (invoke-restart restart))))

(defun skip-element (&optional condition)
  "Invoke the SKIP-ELEMENT restart (established by the MusicXML reader, SC2)."
  (let ((restart (find-restart 'skip-element condition)))
    (when restart (invoke-restart restart))))
