;;;; SC0 fixture: a lead sheet in F major whose chord symbols change under
;;;; rests and held notes, at offsets where no note starts: a slash chord, an
;;;; altered dominant, a symbol with source text and dialect, and N.C.
;;;; Hand-built, MIT.
(:score
 :metadata (:title "Chords Under Rests")
 :id-counter 24
 :measures
 ((:measure :id "m-1" :time "4/4" :key "F major")
  (:measure :id "m-2")
  (:measure :id "m-3")
  (:measure :id "m-4" :barline :final))
 :parts
 ((:part :id "p-5" :name "Lead" :staves ((:staff :id "st-6"))
   :voices
   ((:voice :id "v-7"
     :measures
     (((:rest :id "e-8" :duration 1/2) (:note :id "e-9" :pitch "A4" :duration 1/4)
       (:note :id "e-a" :pitch "C5" :duration 1/4))
      ((:note :id "e-b" :pitch "D5" :duration 1))
      ((:note :id "e-c" :pitch "C5" :duration 1/2) (:rest :id "e-d" :duration 1/4)
       (:note :id "e-e" :pitch "A4" :duration 1/4))
      ((:note :id "e-f" :pitch "F4" :duration 1/2) (:rest :id "e-g" :duration 1/2)))))))
 :chord-symbols
 ((:chord-symbol :id "h-h" :bar 1 :offset 0 :symbol (:root "F" :quality :major))
  (:chord-symbol :id "h-i" :bar 1 :offset 1/4
   :symbol (:root "C" :quality :dominant-7 :text "C7" :dialect :pop))
  (:chord-symbol :id "h-j" :bar 2 :offset 0 :symbol (:root "Bb" :quality :major))
  (:chord-symbol :id "h-k" :bar 2 :offset 1/2 :symbol (:root "G" :quality :minor-7))
  (:chord-symbol :id "h-l" :bar 3 :offset 0
   :symbol (:root "C" :quality :dominant-7 :alterations ((9 . -1))))
  (:chord-symbol :id "h-m" :bar 3 :offset 1/2 :symbol (:root "F" :quality :major :bass "A"))
  (:chord-symbol :id "h-n" :bar 4 :offset 0 :symbol (:root "F" :quality :major))
  (:chord-symbol :id "h-o" :bar 4 :offset 3/4 :symbol (:no-chord-p t))))
