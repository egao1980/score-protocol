;;;; SC0 fixture: two parts. A flute with a measure rest, a slashed grace note
;;;; slurred into its main note, a triplet, articulations and a forced
;;;; accidental; a piano on two staves with chords, chord notes tied across the
;;;; barline, a cautionary accidental, a second voice that is silent or filled
;;;; with a hidden rest, and a tied bass note. Hand-built, MIT.
(:score
 :metadata (:title "Keyboard and Flute" :arranger "Test Arranger")
 :id-counter 49
 :measures
 ((:measure :id "m-1" :time "4/4" :key "C major"
   :tempo ((:bpm 108 :beat-unit 1/4 :text "Allegretto")))
  (:measure :id "m-2")
  (:measure :id "m-3" :barline :final))
 :parts
 ((:part :id "p-4" :name "Flute" :abbreviation "Fl." :staves ((:staff :id "st-5"))
   :voices
   ((:voice :id "v-6"
     :measures
     (((:rest :id "e-7" :duration 1 :measure-rest t))
      ((:note :id "e-8" :pitch "D5" :duration 1/8 :grace :acciaccatura)
       (:note :id "e-9" :pitch "E5" :duration 1/4 :articulations (:tenuto)
        :dynamic :p)
       (:note :id "e-a" :pitch "F5" :duration 1/12 :tuplet 3/2)
       (:note :id "e-b" :pitch "G5" :duration 1/12 :tuplet 3/2)
       (:note :id "e-c" :pitch "A5" :duration 1/12 :tuplet 3/2)
       (:note :id "e-d" :pitch "B5" :duration 1/4 :articulations (:accent :staccato) :breath-mark t)
       (:rest :id "e-e" :duration 1/4))
      ((:note :id "e-f" :pitch "C6" :duration 1/2 :accidental :forced)
       (:rest :id "e-g" :duration 1/2 :fermata :normal))))))
  (:part :id "p-h" :name "Piano" :abbreviation "Pno."
   :staves ((:staff :id "st-i") (:staff :id "st-j" :clef :bass))
   :voices
   ((:voice :id "v-k" :stem :up
     :measures
     (((:chord :id "e-l" :notes ((:chord-note :id "n-m" :pitch "C4") (:chord-note :id "n-n" :pitch "E4")
                       (:chord-note :id "n-o" :pitch "G4"))
        :duration 1/2 :dynamic :mf)
       (:chord :id "e-p" :notes ((:chord-note :id "n-q" :pitch "B3") (:chord-note :id "n-r" :pitch "D4")
                       (:chord-note :id "n-s" :pitch "G4" :tie "n-w"))
        :duration 1/2))
      ((:chord :id "e-t" :notes ((:chord-note :id "n-u" :pitch "C4")
                       (:chord-note :id "n-v" :pitch "E4" :accidental :cautionary)
                       (:chord-note :id "n-w" :pitch "G4"))
        :duration 1))
      ((:chord :id "e-x" :notes ((:chord-note :id "n-y" :pitch "C4") (:chord-note :id "n-z" :pitch "E4")
                       (:chord-note :id "n-10" :pitch "G4") (:chord-note :id "n-11" :pitch "C5"))
        :duration 1/2 :articulations (:marcato) :fermata :normal)
       (:rest :id "e-12" :duration 1/2))))
    (:voice :id "v-13" :stem :down
     :measures
     (()
      ((:rest :id "e-14" :duration 1/2 :hidden t) (:note :id "e-15" :pitch "G3" :duration 1/2))
      ()))
    (:voice :id "v-16" :staff 2
     :measures
     (((:note :id "e-17" :pitch "C3" :duration 1/2) (:note :id "e-18" :pitch "G2" :duration 1/2))
      ((:note :id "e-19" :pitch "C3" :duration 1 :tie "e-1a"))
      ((:note :id "e-1a" :pitch "C3" :duration 1/2) (:rest :id "e-1b" :duration 1/2)))))))
 :spanners ((:spanner :id "sp-1c" :kind :slur :start "e-8" :end "e-9")
            (:spanner :id "sp-1d" :kind :slur :start "e-9" :end "e-c")))
