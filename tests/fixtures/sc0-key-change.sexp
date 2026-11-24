;;;; SC0 fixture: key, time and tempo changes: C major 4/4, D major from bar 3,
;;;; 3/4 in bar 4 with two tempo marks inside the bar, then Bb major 6/8.
;;;; Measure number labels. Hand-built, MIT.
(:score
 :metadata (:title "Changes" :composer "Test Composer")
 :id-counter 24
 :measures
 ((:measure :id "m-1" :number "1" :time "4/4" :key "C major"
   :tempo ((:bpm 100 :beat-unit 1/4 :text "Moderato")))
  (:measure :id "m-2" :number "2" :barline :double)
  (:measure :id "m-3" :number "3" :key "D major" :rehearsal "B")
  (:measure :id "m-4" :number "4" :time "3/4"
   :tempo ((:text "poco rit.") (:offset 1/2 :bpm 80 :beat-unit 1/4)))
  (:measure :id "m-5" :number "5" :time "6/8" :key "Bb major"
   :tempo ((:bpm 60 :beat-unit 3/8)))
  (:measure :id "m-6" :number "6" :barline :final))
 :parts
 ((:part :id "p-7" :name "Violin" :abbreviation "Vln." :staves ((:staff :id "st-8"))
   :voices
   ((:voice :id "v-9"
     :measures
     (((:note :id "e-a" :pitch "C4" :duration 1/4) (:note :id "e-b" :pitch "E4" :duration 1/4)
       (:note :id "e-c" :pitch "G4" :duration 1/4) (:note :id "e-d" :pitch "C5" :duration 1/4))
      ((:note :id "e-e" :pitch "B4" :duration 1/2) (:note :id "e-f" :pitch "G4" :duration 1/2))
      ((:note :id "e-g" :pitch "F#4" :duration 1/4) (:note :id "e-h" :pitch "A4" :duration 1/4)
       (:note :id "e-i" :pitch "D5" :duration 1/2))
      ((:note :id "e-j" :pitch "E5" :duration 1/4) (:note :id "e-k" :pitch "C#5" :duration 1/4)
       (:note :id "e-l" :pitch "A4" :duration 1/4))
      ((:note :id "e-m" :pitch "Bb4" :duration 3/8) (:note :id "e-n" :pitch "D5" :duration 3/8))
      ((:note :id "e-o" :pitch "F5" :duration 3/4 :fermata :long))))))))
