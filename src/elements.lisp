;;;; SC0 elements: parts, staves, voices, events, chord notes, lyrics, the
;;;; marks on events, chord symbols, spanners, and their provenance.
;;;;
;;;; Values are immutable: classes have readers and no writers, structs have
;;;; read-only slots. Durations and offsets are CL rationals in whole notes
;;;; (1/4 = a quarter), as in music-theory.
;;;;
;;;; What is an element. Everything a user can select or edit, and everything
;;;; an engraver draws as an object of its own, is an ELEMENT with an id
;;;; (ids.lisp): a click on the rendering finds its element by id. So the marks
;;;; on events (dynamics, fermatas, breath marks, articulations, ties) and on
;;;; measures (tempo marks, rehearsal marks, jumps, endings; measure-map.lisp)
;;;; are elements, as are notes, lyrics, chord symbols and spanners. What the
;;;; engraver derives (stems, beams, accidentals shown, tuplet brackets, clefs,
;;;; key and time signatures, barlines) belongs to the element it derives from.
;;;;
;;;; Every element has an ID, a PROVENANCE and a CONFIDENCE:
;;;;   PROVENANCE  NIL, or a PROVENANCE struct: SOURCE, a keyword (:user,
;;;;               :musicxml, :midi, :omr, :transcription, ...); BACKEND, the
;;;;               name of the system that produced the element, or NIL; PAGE,
;;;;               a page number >= 1, or NIL; BBOX, (x y width height) reals in
;;;;               the page's own units, or NIL; TIME-RANGE, (start end) seconds
;;;;               in the source audio, or NIL.
;;;;   CONFIDENCE  NIL (not recorded: treated as certain), or a real 0..1.
;;;; An edit (SC1) sets the elements it changes to provenance :user and
;;;; confidence 1.
;;;;
;;;; Constructors (MAKE-PART, MAKE-NOTE-EVENT, MAKE-FERMATA, ...) take keyword
;;;; arguments named like the readers and signal TYPE-ERROR (CHECK-TYPE, with
;;;; its STORE-VALUE restart) for an argument outside the type listed below.
;;;; They check each value on its own; everything that relates two values (a tie
;;;; and its stop note, a voice's staff and its part) is a CHECK-SCORE issue.
;;;; They store fresh lists, and normalise:
;;;;   * generalized booleans are stored as T or NIL;
;;;;   * ARTICULATIONS: stable-sorted by KIND in +ARTICULATIONS+ order (two of
;;;;     one kind are kept: a :DUPLICATE-MARK issue);
;;;;   * LYRICS: stable-sorted by verse (two of one verse are kept: a
;;;;     :DUPLICATE-VERSE issue);
;;;;   * a voice's MEASURES: a list or FSet seq of voice measures, each a list or
;;;;     FSet seq of events, stored as an FSet seq of FSet seqs.
;;;;
;;;; Classes, slots (readers), types and defaults:
;;;;   ELEMENT       ID (or null id), PROVENANCE, CONFIDENCE. In a draft (SC3,
;;;;                 builder.lisp) ID may also be a DRAFT-REF.
;;;;   PART          NAME, ABBREVIATION (or null string); STAVES, a non-empty
;;;;                 list of STAFFs; VOICES, a non-empty list of VOICEs
;;;;   STAFF         CLEF, a keyword of +CLEFS+, default :TREBLE
;;;;   VOICE         NAME (or null string); STAFF, the 1-based number of its
;;;;                 staff in the part, default 1; STEM, NIL, :UP or :DOWN (the
;;;;                 voice's stem direction when it shares a staff); MEASURES,
;;;;                 one voice measure per measure of the measure map. An empty
;;;;                 voice measure means the voice is silent there.
;;;;   EVENT         DURATION, a positive rational; TUPLET, NIL or a positive
;;;;                 ratio n/m ("n in the time of m", music-theory); FERMATA, NIL
;;;;                 or a FERMATA; DYNAMIC, NIL or a DYNAMIC-MARK (a point
;;;;                 dynamic at the event's onset); LYRICS, a list of LYRICs.
;;;;   REST-EVENT    + MEASURE-REST-P (a whole-measure rest, drawn as one
;;;;                 symbol whatever its length); HIDDEN-P (an invisible rest
;;;;                 that only fills time, MusicXML <forward>)
;;;;   SOUNDING-EVENT + GRACE, NIL or a keyword of +GRACE-KINDS+; ARTICULATIONS,
;;;;                 a list of ARTICULATIONs; BREATH-MARK, NIL or a BREATH-MARK
;;;;                 (after the event)
;;;;   NOTE-EVENT    a SOUNDING-EVENT with one pitch (PITCHED below)
;;;;   CHORD-EVENT   a SOUNDING-EVENT with NOTES, a list of CHORD-NOTEs, sharing
;;;;                 its duration
;;;;   CHORD-NOTE    an ELEMENT that is PITCHED
;;;;   PITCHED       PITCH, a music-theory SPELLED-PITCH (required);
;;;;                 ACCIDENTAL, a keyword of +ACCIDENTAL-DISPLAYS+, default
;;;;                 :AUTO; TIE, NIL or a TIE to the next note
;;;;   LYRIC         VERSE, an integer >= 1, default 1; TEXT, a string
;;;;                 (required); SYLLABIC, a keyword of +SYLLABICS+, default
;;;;                 :SINGLE; EXTENDER (a melisma line follows the syllable)
;;;;   DYNAMIC-MARK  VALUE, a keyword of +DYNAMICS+ (required)
;;;;   FERMATA       SHAPE, a keyword of +FERMATAS+, default :NORMAL
;;;;   BREATH-MARK   no slots of its own
;;;;   ARTICULATION  KIND, a keyword of +ARTICULATIONS+ (required)
;;;;   TIE           END, the id of the note it ties to (required); in a draft,
;;;;                 an id or a DRAFT-REF
;;;;   CHORD-SYMBOL-ANCHOR  POSITION, a (bar . offset) cons, bar an integer >= 0
;;;;                 and offset a rational >= 0 (required); SYMBOL, a music-theory
;;;;                 CHORD-SYMBOL, N.C. allowed (required)
;;;;   SPANNER       KIND, a keyword of +SPANNER-KINDS+ (required); START, END,
;;;;                 the ids of its first and last events (required); in a
;;;;                 draft, each an id or a DRAFT-REF
;;;;
;;;; Grace events (GRACE non-NIL) take no time: their DURATION is the notated
;;;; value, and they don't count toward a measure's rhythm.
;;;; A duration is sounding time: a triplet eighth has DURATION 1/12 and TUPLET
;;;; 3/2, and its notated value is DURATION * TUPLET = 1/8.
;;;; A tie is stored once, on its start note: a TIE element whose END is the id
;;;; of its stop note. The stop side is implied. Chord symbols are anchored to
;;;; positions, not to notes, so a chord can change under a held note or a rest.

(in-package #:score-protocol)

;;; Closed sets. Data, not rules: each is the type of a slot and, where a
;;; slot holds several, the canonical order of its values.

(defparameter +clefs+ '(:treble :treble-8vb :treble-8va :bass :bass-8vb :alto :tenor)
  "STAFF-CLEF values. Data.")

(defparameter +fermatas+ '(:normal :short :long)
  "FERMATA-SHAPE values (MusicXML normal, angled, square). Data.")

(defparameter +dynamics+
  '(:pppp :ppp :pp :p :mp :mf :f :ff :fff :ffff :fp :sf :sfp :sfz :fz :rf :rfz)
  "DYNAMIC-MARK-VALUE values. Data.")

(defparameter +grace-kinds+ '(:appoggiatura :acciaccatura)
  "EVENT-GRACE values: an acciaccatura is the slashed grace note. Data.")

(defparameter +articulations+
  '(:accent :marcato :staccato :staccatissimo :tenuto :detached-legato
    :spiccato :stress :unstress :soft-accent)
  "ARTICULATION-KIND values, in canonical order. Data.")

(defparameter +accidental-displays+ '(:auto :forced :cautionary)
  "NOTE-ACCIDENTAL values: :AUTO shows an accidental when the key and the bar
need one; :FORCED always shows it; :CAUTIONARY shows it in parentheses. Data.")

(defparameter +syllabics+ '(:single :begin :middle :end)
  "LYRIC-SYLLABIC values (MusicXML <syllabic>). Data.")

(defparameter +stems+ '(:up :down)
  "Non-NIL VOICE-STEM values. Data.")

(defparameter +spanner-kinds+ '(:slur :crescendo :diminuendo)
  "SPANNER-KIND values: a slur, or a hairpin. Data.")

;;; Provenance ---------------------------------------------------------------

(defstruct (provenance (:constructor make-provenance))
  (source :user :type keyword :read-only t)
  (backend nil :type (or null string) :read-only t)
  (page nil :type (or null (integer 1)) :read-only t)
  (bbox nil :type list :read-only t)
  (time-range nil :type list :read-only t))

;;; Classes ------------------------------------------------------------------

(defclass element ()
  ((id :initarg :id :initform nil :reader element-id :type (or null string draft-ref))
   (provenance :initarg :provenance :initform nil :reader element-provenance
               :type (or null provenance))
   (confidence :initarg :confidence :initform nil :reader element-confidence
               :type (or null (real 0 1))))
  (:documentation "Anything a score can point at by id."))

(defclass part (element)
  ((name :initarg :name :initform nil :reader part-name)
   (abbreviation :initarg :abbreviation :initform nil :reader part-abbreviation)
   (staves :initarg :staves :initform '() :reader part-staves)
   (voices :initarg :voices :initform '() :reader part-voices)))

(defclass staff (element)
  ((clef :initarg :clef :initform :treble :reader staff-clef)))

(defclass voice (element)
  ((name :initarg :name :initform nil :reader voice-name)
   (staff :initarg :staff :initform 1 :reader voice-staff)
   (stem :initarg :stem :initform nil :reader voice-stem)
   (measures :initarg :measures :reader voice-measures
             :documentation "An FSet seq of voice measures, each an FSet seq of events.")))

(defclass event (element)
  ((duration :initarg :duration :reader event-duration)
   (tuplet :initarg :tuplet :initform nil :reader event-tuplet)
   (fermata :initarg :fermata :initform nil :reader event-fermata)
   (dynamic :initarg :dynamic :initform nil :reader event-dynamic)
   (lyrics :initarg :lyrics :initform '() :reader event-lyrics)))

(defclass rest-event (event)
  ((measure-rest-p :initarg :measure-rest-p :initform nil :reader rest-event-measure-rest-p)
   (hidden-p :initarg :hidden-p :initform nil :reader rest-event-hidden-p)))

(defclass sounding-event (event)
  ((grace :initarg :grace :initform nil :reader event-grace)
   (articulations :initarg :articulations :initform '() :reader event-articulations)
   (breath-mark :initarg :breath-mark :initform nil :reader event-breath-mark)))

(defclass pitched ()
  ((pitch :initarg :pitch :reader note-pitch)
   (accidental :initarg :accidental :initform :auto :reader note-accidental)
   (tie :initarg :tie :initform nil :reader note-tie))
  (:documentation "Mixin for NOTE-EVENT and CHORD-NOTE: a spelled pitch, its
accidental display, and its TIE to the next note."))

(defclass note-event (sounding-event pitched) ())

(defclass chord-event (sounding-event)
  ((notes :initarg :notes :initform '() :reader chord-event-notes)))

(defclass chord-note (element pitched) ())

(defclass dynamic-mark (element)
  ((value :initarg :value :reader dynamic-mark-value)))

(defclass fermata (element)
  ((shape :initarg :shape :initform :normal :reader fermata-shape)))

(defclass breath-mark (element) ())

(defclass articulation (element)
  ((kind :initarg :kind :reader articulation-kind)))

(defclass tie (element)
  ((end :initarg :end :reader tie-end
        :documentation "The id of the note this tie ends on; in a draft, an id or a
DRAFT-REF (builder.lisp).")))

(defclass lyric (element)
  ((verse :initarg :verse :initform 1 :reader lyric-verse)
   (text :initarg :text :reader lyric-text)
   (syllabic :initarg :syllabic :initform :single :reader lyric-syllabic)
   (extender :initarg :extender :initform nil :reader lyric-extender)))

(defclass chord-symbol-anchor (element)
  ((position :initarg :position :reader anchor-position)
   (symbol :initarg :symbol :reader anchor-symbol)))

(defclass spanner (element)
  ((kind :initarg :kind :reader spanner-kind)
   (start :initarg :start :reader spanner-start
          :documentation "The id of its first event; in a draft, an id or a DRAFT-REF.")
   (end :initarg :end :reader spanner-end
        :documentation "The id of its last event; in a draft, an id or a DRAFT-REF.")))

(defmethod print-object ((element element) stream)
  (print-unreadable-object (element stream :type t :identity (null (element-id element)))
    (format stream "~S" (element-id element))))

;;; Argument types ------------------------------------------------------------
;;; Run-time predicates, so the closed sets stay the defparameters above and
;;; the compiler never needs their values. CHECK-TYPE names them in
;;; (satisfies ...) types with a readable description.

(defun %clef-p (object) (and (member object +clefs+) t))
(defun %fermata-shape-p (object) (and (member object +fermatas+) t))
(defun %dynamic-value-p (object) (and (member object +dynamics+) t))
(defun %grace-kind-p (object) (and (member object +grace-kinds+) t))
(defun %articulation-kind-p (object) (and (member object +articulations+) t))
(defun %accidental-display-p (object) (and (member object +accidental-displays+) t))
(defun %syllabic-p (object) (and (member object +syllabics+) t))
(defun %stem-p (object) (and (member object +stems+) t))
(defun %spanner-kind-p (object) (and (member object +spanner-kinds+) t))

(defun %list-of-p (object type &optional non-empty)
  "True when OBJECT is a proper list whose members are of TYPE, and not empty
when NON-EMPTY."
  (and (listp object)
       (or (not non-empty) (consp object))
       (loop for tail = object then (cdr tail)
             while (consp tail)
             always (typep (car tail) type)
             finally (return (null tail)))))

(defun %list-or-seq-of-p (object type)
  "True when OBJECT is a proper list or an FSet seq whose members are of TYPE."
  (typecase object
    (list (%list-of-p object type))
    (fset:seq (%list-of-p (fset:convert 'list object) type))
    (t nil)))

(defun %staves-p (object) (%list-of-p object 'staff t))
(defun %voices-p (object) (%list-of-p object 'voice t))
(defun %lyrics-p (object) (%list-of-p object 'lyric))
(defun %articulations-p (object) (%list-of-p object 'articulation))
(defun %chord-notes-p (object) (%list-of-p object 'chord-note))
(defun %events-p (object) (%list-or-seq-of-p object 'event))

(defun %voice-measures-p (object)
  "True when OBJECT is a list or FSet seq of voice measures, each a list or
FSet seq of EVENTs."
  (typecase object
    (list (and (%list-of-p object t) (every #'%events-p object)))
    (fset:seq (every #'%events-p (fset:convert 'list object)))
    (t nil)))

;;; Normalisation -------------------------------------------------------------

(defun %sort-by-set (list key set)
  "A fresh copy of LIST, stable-sorted by the position of (KEY member) in SET."
  (stable-sort (copy-list list) #'< :key (lambda (x) (position (funcall key x) set))))

(defun %sort-lyrics (lyrics)
  "A fresh copy of LYRICS, stable-sorted by verse."
  (stable-sort (copy-list lyrics) #'< :key #'lyric-verse))

(defun %seq-of-seqs (measures)
  "MEASURES (a list or seq of lists or seqs) as a fresh FSet seq of FSet seqs."
  (fset:convert 'fset:seq (mapcar (lambda (events) (fset:convert 'fset:seq events))
                                  (fset:convert 'list measures))))

(defun %make-element (class id provenance confidence &rest initargs)
  "An instance of CLASS after checking the slots every element has. The
constructors call it last, with their other slots checked and normalised."
  (check-type id (or null %id draft-ref) "NIL, an id string or a DRAFT-REF")
  (check-type provenance (or null provenance))
  (check-type confidence (or null (real 0 1)))
  (apply #'make-instance class :id id :provenance provenance :confidence confidence
         initargs))

;;; Constructors -------------------------------------------------------------

(defun make-part (&key id name abbreviation staves voices provenance confidence)
  "A PART (file header). STAVES and VOICES are non-empty lists."
  (check-type name (or null string))
  (check-type abbreviation (or null string))
  (check-type staves (satisfies %staves-p) "a non-empty list of STAFFs")
  (check-type voices (satisfies %voices-p) "a non-empty list of VOICEs")
  (%make-element 'part id provenance confidence
                 :name name :abbreviation abbreviation
                 :staves (copy-list staves) :voices (copy-list voices)))

(defun make-staff (&key id (clef :treble) provenance confidence)
  "A STAFF with CLEF from +CLEFS+."
  (check-type clef (satisfies %clef-p) "a keyword of +CLEFS+")
  (%make-element 'staff id provenance confidence :clef clef))

(defun make-voice (&key id name (staff 1) stem measures provenance confidence)
  "A VOICE. MEASURES is a list or seq of voice measures, each a list or seq of
events; it is stored as an FSet seq of FSet seqs."
  (check-type name (or null string))
  (check-type staff (integer 1))
  (check-type stem (or null (satisfies %stem-p)) "NIL, :UP or :DOWN")
  (check-type measures (satisfies %voice-measures-p)
              "a list or FSet seq of voice measures, each a list or FSet seq of EVENTs")
  (%make-element 'voice id provenance confidence
                 :name name :staff staff :stem stem :measures (%seq-of-seqs measures)))

(defun make-rest-event (&key id duration tuplet measure-rest-p hidden-p fermata
                             dynamic lyrics provenance confidence)
  "A REST-EVENT."
  (check-type duration (rational (0)))
  (check-type tuplet (or null (rational (0))))
  (check-type fermata (or null fermata))
  (check-type dynamic (or null dynamic-mark))
  (check-type lyrics (satisfies %lyrics-p) "a list of LYRICs")
  (%make-element 'rest-event id provenance confidence
                 :duration duration :tuplet tuplet
                 :measure-rest-p (and measure-rest-p t) :hidden-p (and hidden-p t)
                 :fermata fermata :dynamic dynamic :lyrics (%sort-lyrics lyrics)))

(defun make-note-event (&key id pitch duration tuplet grace (accidental :auto) tie
                             articulations fermata breath-mark dynamic lyrics
                             provenance confidence)
  "A NOTE-EVENT. PITCH is a music-theory SPELLED-PITCH."
  (check-type pitch music-theory:spelled-pitch)
  (check-type duration (rational (0)))
  (check-type tuplet (or null (rational (0))))
  (check-type grace (or null (satisfies %grace-kind-p)) "NIL or a keyword of +GRACE-KINDS+")
  (check-type accidental (satisfies %accidental-display-p)
              "a keyword of +ACCIDENTAL-DISPLAYS+")
  (check-type tie (or null tie))
  (check-type articulations (satisfies %articulations-p) "a list of ARTICULATIONs")
  (check-type fermata (or null fermata))
  (check-type breath-mark (or null breath-mark))
  (check-type dynamic (or null dynamic-mark))
  (check-type lyrics (satisfies %lyrics-p) "a list of LYRICs")
  (%make-element 'note-event id provenance confidence
                 :pitch pitch :duration duration :tuplet tuplet :grace grace
                 :accidental accidental :tie tie
                 :articulations (%sort-by-set articulations #'articulation-kind +articulations+)
                 :fermata fermata :breath-mark breath-mark :dynamic dynamic
                 :lyrics (%sort-lyrics lyrics)))

(defun make-chord-event (&key id notes duration tuplet grace articulations fermata
                              breath-mark dynamic lyrics provenance confidence)
  "A CHORD-EVENT. NOTES is a list of CHORD-NOTEs."
  (check-type notes (satisfies %chord-notes-p) "a list of CHORD-NOTEs")
  (check-type duration (rational (0)))
  (check-type tuplet (or null (rational (0))))
  (check-type grace (or null (satisfies %grace-kind-p)) "NIL or a keyword of +GRACE-KINDS+")
  (check-type articulations (satisfies %articulations-p) "a list of ARTICULATIONs")
  (check-type fermata (or null fermata))
  (check-type breath-mark (or null breath-mark))
  (check-type dynamic (or null dynamic-mark))
  (check-type lyrics (satisfies %lyrics-p) "a list of LYRICs")
  (%make-element 'chord-event id provenance confidence
                 :notes (copy-list notes) :duration duration :tuplet tuplet :grace grace
                 :articulations (%sort-by-set articulations #'articulation-kind +articulations+)
                 :fermata fermata :breath-mark breath-mark :dynamic dynamic
                 :lyrics (%sort-lyrics lyrics)))

(defun make-chord-note (&key id pitch (accidental :auto) tie provenance confidence)
  "A CHORD-NOTE, one pitch of a CHORD-EVENT."
  (check-type pitch music-theory:spelled-pitch)
  (check-type accidental (satisfies %accidental-display-p)
              "a keyword of +ACCIDENTAL-DISPLAYS+")
  (check-type tie (or null tie))
  (%make-element 'chord-note id provenance confidence
                 :pitch pitch :accidental accidental :tie tie))

(defun make-dynamic-mark (&key id value provenance confidence)
  "A DYNAMIC-MARK with VALUE from +DYNAMICS+."
  (check-type value (satisfies %dynamic-value-p) "a keyword of +DYNAMICS+")
  (%make-element 'dynamic-mark id provenance confidence :value value))

(defun make-fermata (&key id (shape :normal) provenance confidence)
  "A FERMATA with SHAPE from +FERMATAS+."
  (check-type shape (satisfies %fermata-shape-p) "a keyword of +FERMATAS+")
  (%make-element 'fermata id provenance confidence :shape shape))

(defun make-breath-mark (&key id provenance confidence)
  "A BREATH-MARK."
  (%make-element 'breath-mark id provenance confidence))

(defun make-articulation (&key id kind provenance confidence)
  "An ARTICULATION with KIND from +ARTICULATIONS+."
  (check-type kind (satisfies %articulation-kind-p) "a keyword of +ARTICULATIONS+")
  (%make-element 'articulation id provenance confidence :kind kind))

(defun make-tie (&key id end provenance confidence)
  "A TIE to the note whose id is END (in a draft, a DRAFT-REF)."
  (check-type end (or %id draft-ref) "an id string or a DRAFT-REF")
  (%make-element 'tie id provenance confidence :end end))

(defun make-lyric (&key id (verse 1) text (syllabic :single) extender provenance confidence)
  "A LYRIC syllable of verse VERSE."
  (check-type verse (integer 1))
  (check-type text string)
  (check-type syllabic (satisfies %syllabic-p) "a keyword of +SYLLABICS+")
  (%make-element 'lyric id provenance confidence
                 :verse verse :text text :syllabic syllabic :extender (and extender t)))

(defun make-chord-symbol-anchor (&key id position symbol provenance confidence)
  "A CHORD-SYMBOL-ANCHOR: SYMBOL (a music-theory CHORD-SYMBOL) at POSITION."
  (check-type position (cons (integer 0) (rational 0)) "a (bar . offset) position")
  (check-type symbol music-theory:chord-symbol)
  (%make-element 'chord-symbol-anchor id provenance confidence
                 :position (cons (car position) (cdr position)) :symbol symbol))

(defun make-spanner (&key id kind start end provenance confidence)
  "A SPANNER of KIND from the event with id START to the event with id END (in a
draft, either may be a DRAFT-REF)."
  (check-type kind (satisfies %spanner-kind-p) "a keyword of +SPANNER-KINDS+")
  (check-type start (or %id draft-ref) "an id string or a DRAFT-REF")
  (check-type end (or %id draft-ref) "an id string or a DRAFT-REF")
  (%make-element 'spanner id provenance confidence :kind kind :start start :end end))

(defun %grace-p (event)
  "True when EVENT is a grace event (it takes no time)."
  (and (typep event 'sounding-event) (event-grace event) t))
