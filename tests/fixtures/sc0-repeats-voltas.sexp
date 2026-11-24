;;;; SC0 fixture: two repeated sections in 4/4, D major. The first has a
;;;; two-bar first ending and a one-bar second ending; the second is played
;;;; three times, with an ending for passes 1 and 2 and another for pass 3.
;;;; Rehearsal marks. Hand-built, MIT.
(:score
 :metadata (:title "Repeats and Voltas")
 :id-counter 37
 :measures
 ((:measure :id "m-1" :time "4/4" :key "D major" :repeat-start t :rehearsal (:rehearsal :id "rh-2" :text "A"))
  (:measure :id "m-3")
  (:measure :id "m-4" :ending (:ending :id "en-5" :passes (1) :measures 2))
  (:measure :id "m-6" :repeat-end 2)
  (:measure :id "m-7" :barline :double :ending (:ending :id "en-8" :passes (2)))
  (:measure :id "m-9" :repeat-start t :rehearsal (:rehearsal :id "rh-a" :text "B"))
  (:measure :id "m-b" :repeat-end 3 :ending (:ending :id "en-c" :passes (1 2)))
  (:measure :id "m-d" :barline :final :ending (:ending :id "en-e" :passes (3))))
 :parts
 ((:part :id "p-f" :name "Recorder" :abbreviation "Rec." :staves ((:staff :id "st-g"))
   :voices
   ((:voice :id "v-h"
     :measures
     (((:note :id "e-i" :pitch "D4" :duration 1/4) (:note :id "e-j" :pitch "E4" :duration 1/4)
       (:note :id "e-k" :pitch "F#4" :duration 1/4) (:note :id "e-l" :pitch "G4" :duration 1/4))
      ((:note :id "e-m" :pitch "A4" :duration 1/2) (:note :id "e-n" :pitch "F#4" :duration 1/2))
      ((:note :id "e-o" :pitch "E4" :duration 1/2) (:note :id "e-p" :pitch "D4" :duration 1/4)
       (:note :id "e-q" :pitch "E4" :duration 1/4))
      ((:note :id "e-r" :pitch "F#4" :duration 1/2) (:note :id "e-s" :pitch "E4" :duration 1/2))
      ((:note :id "e-t" :pitch "D4" :duration 1))
      ((:note :id "e-u" :pitch "B4" :duration 1/4) (:note :id "e-v" :pitch "A4" :duration 1/4)
       (:note :id "e-w" :pitch "G4" :duration 1/4) (:note :id "e-x" :pitch "F#4" :duration 1/4))
      ((:note :id "e-y" :pitch "E4" :duration 1/2) (:note :id "e-z" :pitch "A4" :duration 1/2))
      ((:note :id "e-10" :pitch "D4" :duration 1 :fermata (:fermata :id "fe-11")))))))))
