;;;; SC1 views: EXTRACT-PART, CONDENSED-VIEW and UNFOLD.
;;;;
;;;; A view is a pure function of a source score. It returns a new score and an
;;;; ID MAP: an FSet map from the id of every element of the view that comes
;;;; from the source to the id of the source element it comes from. A view
;;;; keeps the ids of the elements it carries over (ids.lisp), and an element it
;;;; carries over unchanged is the source's own object (EQ). Elements a view
;;;; makes, and every copy of an element after the first, get minted ids:
;;;; PREFIX-(c + k), c the source's SCORE-ID-COUNTER and k = 1, 2, ... in the
;;;; view's document order; the view's counter is computed as MAKE-SCORE does.
;;;; The view's metadata is the source's. The view of a valid score is valid
;;;; (CHECK-SCORE returns ()).
;;;;
;;;; EXTRACT-PART score id → (values view id-map). ID names a part or a voice;
;;;; another id signals UNKNOWN-ELEMENT (ID = the id) inside a USE-VALUE restart
;;;; that takes an id to extract instead. The view has the source's measure map
;;;; (the same measures), every chord-symbol anchor (chord symbols belong to the
;;;; whole score), the spanners whose two endpoints are events of what is
;;;; extracted, and one part:
;;;;   for a part, that part itself;
;;;;   for a voice, its part's id, abbreviation and name (the voice's NAME
;;;;   instead, when it has one), with one staff, the voice's own (the same
;;;;   staff), and the voice alone, with STAFF 1 and STEM NIL.
;;;; Every element of the view comes from the source; the id map sends each id
;;;; to itself. So the alto of a hymn on two staves is (extract-part s "alto-id").
;;;;
;;;; CONDENSED-VIEW score &key voices → (values view id-map): up to four voices
;;;; on two staves, the hymnal reduction. VOICES is a list of one to four voice
;;;; ids, highest first (soprano, alto, tenor, bass); by default the first four
;;;; voices of the score in document order, or all of them when it has fewer.
;;;; An id that isn't in the score signals UNKNOWN-ELEMENT inside a USE-VALUE
;;;; restart that takes a list of voice ids to use instead; an id of another
;;;; kind, the same voice twice, more than four, and a score without voices
;;;; signal SCORE-ERROR. The view has the source's measure map, every anchor,
;;;; the spanners whose two endpoints lie in those voices, and one new part
;;;; (minted, with the NAME and ABBREVIATION of the voices' part when they all
;;;; come from one part, else none). Its staves are new: one :TREBLE staff for
;;;; one or two voices, a :TREBLE and a :BASS staff for three or four. The voices
;;;; are VOICES, in order, carried over whole: the first two on staff 1, the
;;;; others on staff 2. A voice that shares its staff has STEM :UP when it is
;;;; the upper of the two and :DOWN when it is the lower; a voice alone on its
;;;; staff has STEM NIL. Unisons and differing rhythms between the two voices of
;;;; a staff are the engraver's: both voices stay whole, and the engraver draws
;;;; a shared notehead or offset heads from their events. The id map sends
;;;; every carried id to itself; the part and staves are not in it.
;;;;
;;;; UNFOLD score → (values view id-map passes): repeats, endings and jumps
;;;; expanded into playback order.
;;;;   Ending groups. Endings that each start on the measure after the last
;;;;   measure of the one before form a group. A REPEAT-END measure e belongs to
;;;;   the group that contains e or starts on the measure after e; g(e) is that
;;;;   group's last measure, or e when there is none.
;;;;   Sections. Each REPEAT-END measure e ends a section, which starts at s(e):
;;;;   the last measure with REPEAT-START in (g(p), e], p the REPEAT-END measure
;;;;   before e; when there is none, at g(p) + 1. For the first section, g(p) is
;;;;   taken as -1: a backward repeat with no forward repeat goes back to the
;;;;   beginning of the score, or to the end of the section before.
;;;;   The walk keeps PASS (the time through the current section, from 1),
;;;;   whether a jump has been taken (JUMPED), and the MODE of that jump (NIL,
;;;;   :FINE or :CODA). It starts at the first measure, and at each measure m:
;;;;    1. When m starts an ENDING: it is played when PASS is among its PASSES
;;;;       or, once JUMPED, when it is the last ending of its group; otherwise
;;;;       the walk goes on at the measure after the ending's measures.
;;;;    2. Entering a section start s(e) other than by repeating sets PASS to 1.
;;;;    3. m is played: it is the next measure of the view.
;;;;    4. At the end of m, the first of these that applies:
;;;;       a. m has REPEAT-END n, not JUMPED, PASS < n: PASS + 1, back to s(m).
;;;;       b. m has :FINE and MODE is :FINE: the walk ends.
;;;;       c. m has :TO-CODA and MODE is :CODA: on at the first measure after m
;;;;          with a :CODA mark, or the walk ends when there is none.
;;;;       d. m has a D.C. or D.S. mark not taken before (the first in +JUMPS+
;;;;          order): it is taken, JUMPED becomes true, MODE becomes :FINE for
;;;;          :DA-CAPO-AL-FINE and :DAL-SEGNO-AL-FINE, :CODA for
;;;;          :DA-CAPO-AL-CODA and :DAL-SEGNO-AL-CODA, NIL for :DA-CAPO and
;;;;          :DAL-SEGNO; on at the first measure (D.C.) or at the last measure
;;;;          at or before m with a :SEGNO mark (D.S.; with none, SCORE-ERROR).
;;;;       e. on at the next measure; after the last one the walk ends.
;;;;   So after a jump repeats are not taken again and the last ending of each
;;;;   group is played; a plain D.C. or D.S. plays to the end; Fine and To Coda
;;;;   act only after a jump that asks for them.
;;;;   The PASS of a measure of the view is how many times its source measure
;;;;   has been played up to and including it (1 the first time).
;;;;   The view. Its measures are copies of the played measures, in order: the
;;;;   same slots and marks, minus REPEAT-START, REPEAT-END, the ENDING and the
;;;;   JUMP marks (the view has nothing left to navigate); PICKUP-P only on the
;;;;   first; TIME (KEY) its own, else the one in force at its source when that
;;;;   differs from the one in force at the source of the view measure before it,
;;;;   and always both for the first. Each voice's voice measure k is a copy of
;;;;   its source voice measure. A tie keeps its END when the target's copy is
;;;;   in the same view measure, or in the next one when that one is the source
;;;;   measure right after; otherwise the copy has no tie. A spanner is copied
;;;;   for each copy of its START event whose END event has a copy in the same
;;;;   view measure or in a following one reached through source measures that
;;;;   follow each other, with no jump; that END copy is its END. Each anchor is
;;;;   copied into every view bar whose source bar holds it, at the same offset.
;;;;   Parts, staves and voices are carried over with their ids.
;;;;   The first copy of an element in the view's document order keeps its id;
;;;;   the id map sends every copy to its source. PASSES is an FSet map from each
;;;;   view id to a pass: a measure's, for the measure, what is on it, the
;;;;   events of its voice measures and what is in them, and the anchors in its
;;;;   bar; for a spanner, the pass of its START copy; 1 for parts, staves and
;;;;   voices. So (bar . offset) in the view, the pass, and the source id
;;;;   together say where in the score playback is. UNFOLD of a view gives the
;;;;   same measures again.

(in-package #:score-protocol)

(defun extract-part (score id)
  "(values view id-map): the part or voice ID of SCORE on its own (file header)."
  (declare (ignorable score id))
  (%sc1-pending 'extract-part))

(defun condensed-view (score &key voices)
  "(values view id-map): up to four VOICES on two staves (file header)."
  (declare (ignorable score voices))
  (%sc1-pending 'condensed-view))

(defun unfold (score)
  "(values view id-map passes): SCORE in playback order (file header)."
  (declare (ignorable score))
  (%sc1-pending 'unfold))
