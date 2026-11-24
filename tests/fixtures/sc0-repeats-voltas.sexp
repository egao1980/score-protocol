;;;; SC0 fixture: two repeated sections in 4/4, D major. The first has first and
;;;; second endings; the second is played three times, with an ending for
;;;; passes 1 and 2 and another for pass 3. Rehearsal marks. Hand-built, MIT.
(:score
 :metadata (:title "Repeats and Voltas")
 :id-counter 27
 :measures
 ((:measure :id "m-1" :time "4/4" :key "D major" :repeat-start t :rehearsal "A")
  (:measure :id "m-2")
  (:measure :id "m-3" :repeat-end 2 :volta (1))
  (:measure :id "m-4" :barline :double :volta (2))
  (:measure :id "m-5" :repeat-start t :rehearsal "B")
  (:measure :id "m-6" :repeat-end 3 :volta (1 2))
  (:measure :id "m-7" :barline :final :volta (3)))
 :parts
 ((:part :id "p-8" :name "Recorder" :abbreviation "Rec." :staves ((:staff :id "st-9"))
   :voices
   ((:voice :id "v-a"
     :measures
     (((:note :id "e-b" :pitch "D4" :duration 1/4) (:note :id "e-c" :pitch "E4" :duration 1/4)
       (:note :id "e-d" :pitch "F#4" :duration 1/4) (:note :id "e-e" :pitch "G4" :duration 1/4))
      ((:note :id "e-f" :pitch "A4" :duration 1/2) (:note :id "e-g" :pitch "F#4" :duration 1/2))
      ((:note :id "e-h" :pitch "E4" :duration 1/2) (:note :id "e-i" :pitch "D4" :duration 1/4)
       (:note :id "e-j" :pitch "E4" :duration 1/4))
      ((:note :id "e-k" :pitch "D4" :duration 1))
      ((:note :id "e-l" :pitch "B4" :duration 1/4) (:note :id "e-m" :pitch "A4" :duration 1/4)
       (:note :id "e-n" :pitch "G4" :duration 1/4) (:note :id "e-o" :pitch "F#4" :duration 1/4))
      ((:note :id "e-p" :pitch "E4" :duration 1/2) (:note :id "e-q" :pitch "A4" :duration 1/2))
      ((:note :id "e-r" :pitch "D4" :duration 1 :fermata :normal))))))))
