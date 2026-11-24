;;;; SC0 fixture: navigation marks in 2/4, E minor: a segno, "To Coda", a D.S. al
;;;; Coda at the end of bar 5, and the coda. Number labels, rehearsal marks and
;;;; barline styles. Hand-built, MIT.
(:score
 :metadata (:title "Dal Segno al Coda")
 :id-counter 29
 :measures
 ((:measure :id "m-1" :number "1" :time "2/4" :key "E minor" :rehearsal (:rehearsal :id "rh-2" :text "Intro"))
  (:measure :id "m-3" :number "2" :jump ((:jump :id "jm-4" :kind :segno))
   :rehearsal (:rehearsal :id "rh-5" :text "A"))
  (:measure :id "m-6" :number "3")
  (:measure :id "m-7" :number "4" :jump ((:jump :id "jm-8" :kind :to-coda)))
  (:measure :id "m-9" :number "5" :barline :double :jump ((:jump :id "jm-a" :kind :dal-segno-al-coda)))
  (:measure :id "m-b" :number "6" :jump ((:jump :id "jm-c" :kind :coda))
   :rehearsal (:rehearsal :id "rh-d" :text "Coda"))
  (:measure :id "m-e" :number "7" :barline :final))
 :parts
 ((:part :id "p-f" :name "Oboe" :abbreviation "Ob." :staves ((:staff :id "st-g"))
   :voices
   ((:voice :id "v-h"
     :measures
     (((:note :id "e-i" :pitch "E4" :duration 1/4) (:note :id "e-j" :pitch "G4" :duration 1/4))
      ((:note :id "e-k" :pitch "B4" :duration 1/2))
      ((:note :id "e-l" :pitch "A4" :duration 1/4) (:note :id "e-m" :pitch "G4" :duration 1/4))
      ((:note :id "e-n" :pitch "F#4" :duration 1/2))
      ((:note :id "e-o" :pitch "E4" :duration 1/4) (:note :id "e-p" :pitch "D#4" :duration 1/4))
      ((:note :id "e-q" :pitch "G4" :duration 1/4) (:note :id "e-r" :pitch "F#4" :duration 1/4))
      ((:note :id "e-s" :pitch "E4" :duration 1/2 :fermata (:fermata :id "fe-t")))))))))
