;;;; SC0 fixture: key, time and tempo changes: C major 4/4, D major from bar 3,
;;;; 3/4 in bar 4 with two tempo marks inside the bar, then Bb major 6/8.
;;;; Measure number labels. Hand-built, MIT.
(:score
 :metadata (:title "Changes" :composer "Test Composer")
 :id-counter 30
 :measures
 ((:measure :id "m-1" :number "1" :time "4/4" :key "C major"
   :tempo ((:tempo-mark :id "tm-2" :bpm 100 :beat-unit 1/4 :text "Moderato")))
  (:measure :id "m-3" :number "2" :barline :double)
  (:measure :id "m-4" :number "3" :key "D major" :rehearsal (:rehearsal :id "rh-5" :text "B"))
  (:measure :id "m-6" :number "4" :time "3/4"
   :tempo ((:tempo-mark :id "tm-7" :text "poco rit.") (:tempo-mark :id "tm-8" :offset 1/2 :bpm 80
                                                       :beat-unit 1/4)))
  (:measure :id "m-9" :number "5" :time "6/8" :key "Bb major"
   :tempo ((:tempo-mark :id "tm-a" :bpm 60 :beat-unit 3/8)))
  (:measure :id "m-b" :number "6" :barline :final))
 :parts
 ((:part :id "p-c" :name "Violin" :abbreviation "Vln." :staves ((:staff :id "st-d"))
   :voices
   ((:voice :id "v-e"
     :measures
     (((:note :id "e-f" :pitch "C4" :duration 1/4) (:note :id "e-g" :pitch "E4" :duration 1/4)
       (:note :id "e-h" :pitch "G4" :duration 1/4) (:note :id "e-i" :pitch "C5" :duration 1/4))
      ((:note :id "e-j" :pitch "B4" :duration 1/2) (:note :id "e-k" :pitch "G4" :duration 1/2))
      ((:note :id "e-l" :pitch "F#4" :duration 1/4) (:note :id "e-m" :pitch "A4" :duration 1/4)
       (:note :id "e-n" :pitch "D5" :duration 1/2))
      ((:note :id "e-o" :pitch "E5" :duration 1/4) (:note :id "e-p" :pitch "C#5" :duration 1/4)
       (:note :id "e-q" :pitch "A4" :duration 1/4))
      ((:note :id "e-r" :pitch "Bb4" :duration 3/8) (:note :id "e-s" :pitch "D5" :duration 3/8))
      ((:note :id "e-t" :pitch "F5" :duration 3/4 :fermata (:fermata :id "fe-u" :shape :long)))))))))
