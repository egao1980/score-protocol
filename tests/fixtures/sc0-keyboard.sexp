;;;; SC0 fixture: two parts. A flute with a measure rest, a slashed grace note
;;;; slurred into its main note, a triplet, articulations and a forced
;;;; accidental; a piano on two staves with chords, chord notes tied across the
;;;; barline, a cautionary accidental, a second voice that is silent or filled
;;;; with a hidden rest, and a tied bass note. Hand-built, MIT.
(:score
 :metadata (:title "Keyboard and Flute" :arranger "Test Arranger")
 :id-counter 61
 :measures
 ((:measure :id "m-1" :time "4/4" :key "C major"
   :tempo ((:tempo-mark :id "tm-2" :bpm 108 :beat-unit 1/4 :text "Allegretto")))
  (:measure :id "m-3")
  (:measure :id "m-4" :barline :final))
 :parts
 ((:part :id "p-5" :name "Flute" :abbreviation "Fl." :staves ((:staff :id "st-6"))
   :voices
   ((:voice :id "v-7"
     :measures
     (((:rest :id "e-8" :duration 1 :measure-rest t))
      ((:note :id "e-9" :pitch "D5" :duration 1/8 :grace :acciaccatura)
       (:note :id "e-a" :pitch "E5" :duration 1/4 :articulations ((:articulation :id "ar-b" :kind :tenuto))
        :dynamic (:dynamic :id "dy-c" :value :p))
       (:note :id "e-d" :pitch "F5" :duration 1/12 :tuplet 3/2)
       (:note :id "e-e" :pitch "G5" :duration 1/12 :tuplet 3/2)
       (:note :id "e-f" :pitch "A5" :duration 1/12 :tuplet 3/2)
       (:note :id "e-g" :pitch "B5" :duration 1/4
        :articulations ((:articulation :id "ar-h" :kind :accent)
                        (:articulation :id "ar-i" :kind :staccato))
        :breath-mark (:breath-mark :id "br-j"))
       (:rest :id "e-k" :duration 1/4))
      ((:note :id "e-l" :pitch "C6" :duration 1/2 :accidental :forced)
       (:rest :id "e-m" :duration 1/2 :fermata (:fermata :id "fe-n")))))))
  (:part :id "p-o" :name "Piano" :abbreviation "Pno."
   :staves ((:staff :id "st-p") (:staff :id "st-q" :clef :bass))
   :voices
   ((:voice :id "v-r" :stem :up
     :measures
     (((:chord :id "e-s" :notes ((:chord-note :id "n-t" :pitch "C4") (:chord-note :id "n-u" :pitch "E4")
                       (:chord-note :id "n-v" :pitch "G4"))
        :duration 1/2 :dynamic (:dynamic :id "dy-w" :value :mf))
       (:chord :id "e-x" :notes ((:chord-note :id "n-y" :pitch "B3") (:chord-note :id "n-z" :pitch "D4")
                       (:chord-note :id "n-10" :pitch "G4" :tie (:tie :id "ti-11" :end "n-15")))
        :duration 1/2))
      ((:chord :id "e-12" :notes ((:chord-note :id "n-13" :pitch "C4")
                       (:chord-note :id "n-14" :pitch "E4" :accidental :cautionary)
                       (:chord-note :id "n-15" :pitch "G4"))
        :duration 1))
      ((:chord :id "e-16" :notes ((:chord-note :id "n-17" :pitch "C4") (:chord-note :id "n-18" :pitch "E4")
                       (:chord-note :id "n-19" :pitch "G4") (:chord-note :id "n-1a" :pitch "C5"))
        :duration 1/2 :articulations ((:articulation :id "ar-1b" :kind :marcato))
        :fermata (:fermata :id "fe-1c"))
       (:rest :id "e-1d" :duration 1/2))))
    (:voice :id "v-1e" :stem :down
     :measures
     (()
      ((:rest :id "e-1f" :duration 1/2 :hidden t) (:note :id "e-1g" :pitch "G3" :duration 1/2))
      ()))
    (:voice :id "v-1h" :staff 2
     :measures
     (((:note :id "e-1i" :pitch "C3" :duration 1/2) (:note :id "e-1j" :pitch "G2" :duration 1/2))
      ((:note :id "e-1k" :pitch "C3" :duration 1 :tie (:tie :id "ti-1l" :end "e-1m")))
      ((:note :id "e-1m" :pitch "C3" :duration 1/2) (:rest :id "e-1n" :duration 1/2)))))))
 :spanners ((:spanner :id "sp-1o" :kind :slur :start "e-9" :end "e-a")
            (:spanner :id "sp-1p" :kind :slur :start "e-a" :end "e-f")))
