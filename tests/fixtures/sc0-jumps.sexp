;;;; SC0 fixture: navigation marks in 2/4, E minor: a segno, "To Coda", a D.S. al
;;;; Coda at the end of bar 5, and the coda. Number labels, rehearsal marks and
;;;; barline styles. Hand-built, MIT.
(:score
 :metadata (:title "Dal Segno al Coda")
 :id-counter 21
 :measures
 ((:measure :id "m-1" :number "1" :time "2/4" :key "E minor" :rehearsal "Intro")
  (:measure :id "m-2" :number "2" :jump (:segno) :rehearsal "A")
  (:measure :id "m-3" :number "3")
  (:measure :id "m-4" :number "4" :jump (:to-coda))
  (:measure :id "m-5" :number "5" :barline :double :jump (:dal-segno-al-coda))
  (:measure :id "m-6" :number "6" :jump (:coda) :rehearsal "Coda")
  (:measure :id "m-7" :number "7" :barline :final))
 :parts
 ((:part :id "p-8" :name "Oboe" :abbreviation "Ob." :staves ((:staff :id "st-9"))
   :voices
   ((:voice :id "v-a"
     :measures
     (((:note :id "e-b" :pitch "E4" :duration 1/4) (:note :id "e-c" :pitch "G4" :duration 1/4))
      ((:note :id "e-d" :pitch "B4" :duration 1/2))
      ((:note :id "e-e" :pitch "A4" :duration 1/4) (:note :id "e-f" :pitch "G4" :duration 1/4))
      ((:note :id "e-g" :pitch "F#4" :duration 1/2))
      ((:note :id "e-h" :pitch "E4" :duration 1/4) (:note :id "e-i" :pitch "D#4" :duration 1/4))
      ((:note :id "e-j" :pitch "G4" :duration 1/4) (:note :id "e-k" :pitch "F#4" :duration 1/4))
      ((:note :id "e-l" :pitch "E4" :duration 1/2 :fermata :normal))))))))
