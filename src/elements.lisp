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
;;;;   ELEMENT       ID (or null id), PROVENANCE, CONFIDENCE
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
;;;;   TIE           END, the id of the note it ties to (required)
;;;;   CHORD-SYMBOL-ANCHOR  POSITION, a (bar . offset) cons, bar an integer >= 0
;;;;                 and offset a rational >= 0 (required); SYMBOL, a music-theory
;;;;                 CHORD-SYMBOL, N.C. allowed (required)
;;;;   SPANNER       KIND, a keyword of +SPANNER-KINDS+ (required); START, END,
;;;;                 the ids of its first and last events (required)
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
  ((id :initarg :id :initform nil :reader element-id :type (or null string))
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
        :documentation "The id of the note this tie ends on.")))

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
   (start :initarg :start :reader spanner-start)
   (end :initarg :end :reader spanner-end)))

(defmethod print-object ((element element) stream)
  (print-unreadable-object (element stream :type t :identity (null (element-id element)))
    (format stream "~S" (element-id element))))

;;; Constructors -------------------------------------------------------------

(defun make-part (&key id name abbreviation staves voices provenance confidence)
  "A PART (file header). STAVES and VOICES are non-empty lists."
  (declare (ignorable id name abbreviation staves voices provenance confidence))
  (%sc0-pending 'make-part))

(defun make-staff (&key id (clef :treble) provenance confidence)
  "A STAFF with CLEF from +CLEFS+."
  (declare (ignorable id clef provenance confidence))
  (%sc0-pending 'make-staff))

(defun make-voice (&key id name (staff 1) stem measures provenance confidence)
  "A VOICE. MEASURES is a list or seq of voice measures, each a list or seq of
events; it is stored as an FSet seq of FSet seqs."
  (declare (ignorable id name staff stem measures provenance confidence))
  (%sc0-pending 'make-voice))

(defun make-rest-event (&key id duration tuplet measure-rest-p hidden-p fermata
                             dynamic lyrics provenance confidence)
  "A REST-EVENT."
  (declare (ignorable id duration tuplet measure-rest-p hidden-p fermata dynamic
                      lyrics provenance confidence))
  (%sc0-pending 'make-rest-event))

(defun make-note-event (&key id pitch duration tuplet grace (accidental :auto) tie
                             articulations fermata breath-mark dynamic lyrics
                             provenance confidence)
  "A NOTE-EVENT. PITCH is a music-theory SPELLED-PITCH."
  (declare (ignorable id pitch duration tuplet grace accidental tie articulations
                      fermata breath-mark dynamic lyrics provenance confidence))
  (%sc0-pending 'make-note-event))

(defun make-chord-event (&key id notes duration tuplet grace articulations fermata
                              breath-mark dynamic lyrics provenance confidence)
  "A CHORD-EVENT. NOTES is a list of CHORD-NOTEs."
  (declare (ignorable id notes duration tuplet grace articulations fermata
                      breath-mark dynamic lyrics provenance confidence))
  (%sc0-pending 'make-chord-event))

(defun make-chord-note (&key id pitch (accidental :auto) tie provenance confidence)
  "A CHORD-NOTE, one pitch of a CHORD-EVENT."
  (declare (ignorable id pitch accidental tie provenance confidence))
  (%sc0-pending 'make-chord-note))

(defun make-dynamic-mark (&key id value provenance confidence)
  "A DYNAMIC-MARK with VALUE from +DYNAMICS+."
  (declare (ignorable id value provenance confidence))
  (%sc0-pending 'make-dynamic-mark))

(defun make-fermata (&key id (shape :normal) provenance confidence)
  "A FERMATA with SHAPE from +FERMATAS+."
  (declare (ignorable id shape provenance confidence))
  (%sc0-pending 'make-fermata))

(defun make-breath-mark (&key id provenance confidence)
  "A BREATH-MARK."
  (declare (ignorable id provenance confidence))
  (%sc0-pending 'make-breath-mark))

(defun make-articulation (&key id kind provenance confidence)
  "An ARTICULATION with KIND from +ARTICULATIONS+."
  (declare (ignorable id kind provenance confidence))
  (%sc0-pending 'make-articulation))

(defun make-tie (&key id end provenance confidence)
  "A TIE to the note whose id is END."
  (declare (ignorable id end provenance confidence))
  (%sc0-pending 'make-tie))

(defun make-lyric (&key id (verse 1) text (syllabic :single) extender provenance confidence)
  "A LYRIC syllable of verse VERSE."
  (declare (ignorable id verse text syllabic extender provenance confidence))
  (%sc0-pending 'make-lyric))

(defun make-chord-symbol-anchor (&key id position symbol provenance confidence)
  "A CHORD-SYMBOL-ANCHOR: SYMBOL (a music-theory CHORD-SYMBOL) at POSITION."
  (declare (ignorable id position symbol provenance confidence))
  (%sc0-pending 'make-chord-symbol-anchor))

(defun make-spanner (&key id kind start end provenance confidence)
  "A SPANNER of KIND from the event with id START to the event with id END."
  (declare (ignorable id kind start end provenance confidence))
  (%sc0-pending 'make-spanner))
