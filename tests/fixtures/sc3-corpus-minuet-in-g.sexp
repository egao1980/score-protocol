(:score :metadata (:title "Minuet in G" :composer "Christian Petzold") :id-counter 70 :measures
 ((:measure :id "m-1" :time "3/4" :key "G major" :repeat-start t :tempo
   ((:tempo-mark :id "tm-2" :bpm 100 :beat-unit 1/4 :text "Moderato")))
  (:measure :id "m-3") (:measure :id "m-4") (:measure :id "m-5") (:measure :id "m-6")
  (:measure :id "m-7") (:measure :id "m-8") (:measure :id "m-9" :barline :final :repeat-end 2))
 :parts
 ((:part :id "P1" :name "Keyboard" :abbreviation "Kbd." :staves
   ((:staff :id "st-a") (:staff :id "st-b" :clef :bass)) :voices
   ((:voice :id "v-c" :measures
     (((:note :id "e-d" :pitch "D5" :duration 1/4 :dynamic (:dynamic :id "dy-e" :value :mf))
       (:note :id "e-f" :pitch "G4" :duration 1/8) (:note :id "e-g" :pitch "A4" :duration 1/8)
       (:note :id "e-h" :pitch "B4" :duration 1/8) (:note :id "e-i" :pitch "C5" :duration 1/8))
      ((:note :id "e-j" :pitch "D5" :duration 1/4)
       (:note :id "e-k" :pitch "G4" :duration 1/4 :articulations
        ((:articulation :id "ar-l" :kind :staccato)))
       (:note :id "e-m" :pitch "G4" :duration 1/4 :articulations
        ((:articulation :id "ar-n" :kind :staccato))))
      ((:note :id "e-o" :pitch "E5" :duration 1/4) (:note :id "e-p" :pitch "C5" :duration 1/8)
       (:note :id "e-q" :pitch "D5" :duration 1/8) (:note :id "e-r" :pitch "E5" :duration 1/8)
       (:note :id "e-s" :pitch "F#5" :duration 1/8))
      ((:note :id "e-t" :pitch "G5" :duration 1/4)
       (:note :id "e-u" :pitch "G4" :duration 1/4 :articulations
        ((:articulation :id "ar-v" :kind :staccato)))
       (:note :id "e-w" :pitch "G4" :duration 1/4 :articulations
        ((:articulation :id "ar-x" :kind :staccato))))
      ((:note :id "e-y" :pitch "C5" :duration 1/4) (:note :id "e-z" :pitch "D5" :duration 1/8)
       (:note :id "e-10" :pitch "C5" :duration 1/8) (:note :id "e-11" :pitch "B4" :duration 1/8)
       (:note :id "e-12" :pitch "A4" :duration 1/8))
      ((:note :id "e-13" :pitch "B4" :duration 1/4) (:note :id "e-14" :pitch "C5" :duration 1/8)
       (:note :id "e-15" :pitch "B4" :duration 1/8) (:note :id "e-16" :pitch "A4" :duration 1/8)
       (:note :id "e-17" :pitch "G4" :duration 1/8))
      ((:note :id "e-18" :pitch "F#4" :duration 1/4) (:note :id "e-19" :pitch "G4" :duration 1/8)
       (:note :id "e-1a" :pitch "A4" :duration 1/8) (:note :id "e-1b" :pitch "B4" :duration 1/8)
       (:note :id "e-1c" :pitch "G4" :duration 1/8))
      ((:note :id "e-1d" :pitch "A4" :duration 3/4))))
    (:voice :id "v-1e" :staff 2 :stem :down :measures
     (((:chord :id "e-1f" :notes
        ((:chord-note :id "n-1g" :pitch "G3") (:chord-note :id "n-1h" :pitch "B3")) :duration 1/2)
       (:note :id "e-1i" :pitch "A3" :duration 1/4))
      ((:note :id "e-1j" :pitch "B3" :duration 3/4)) ((:note :id "e-1k" :pitch "C4" :duration 3/4))
      ((:note :id "e-1l" :pitch "B3" :duration 3/4)) ((:note :id "e-1m" :pitch "A3" :duration 3/4))
      ((:note :id "e-1n" :pitch "G3" :duration 3/4))
      ((:note :id "e-1o" :pitch "D4" :duration 1/4) (:note :id "e-1p" :pitch "B3" :duration 1/4)
       (:note :id "e-1q" :pitch "G3" :duration 1/4))
      ((:note :id "e-1r" :pitch "D4" :duration 1/4) (:note :id "e-1s" :pitch "D3" :duration 1/4)
       (:note :id "e-1t" :pitch "C4" :duration 1/4)))))))
 :spanners
 ((:spanner :id "sp-1u" :kind :slur :start "e-f" :end "e-i")
  (:spanner :id "sp-1v" :kind :slur :start "e-p" :end "e-s")
  (:spanner :id "sp-1w" :kind :slur :start "e-z" :end "e-12")
  (:spanner :id "sp-1x" :kind :slur :start "e-14" :end "e-17")
  (:spanner :id "sp-1y" :kind :slur :start "e-19" :end "e-1c")))
