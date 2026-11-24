;;;; SC1 fixture: a chorale phrase in open score, for the condensed view: four
;;;; parts on four staves (soprano, alto, tenor on a treble-8vb staff, bass), 3/4
;;;; in D major. A slur in the alto, a tie across the barline in the tenor, the
;;;; words in the soprano, chord symbols, final fermatas. Hand-built, MIT.
(:score
 :metadata (:title "Chorale in Open Score")
 :id-counter 54
 :measures
 ((:measure :id "m-1" :time "3/4" :key "D major")
  (:measure :id "m-2")
  (:measure :id "m-3" :barline :final))
 :parts
 ((:part :id "p-4" :name "Soprano" :abbreviation "S." :staves ((:staff :id "st-5"))
   :voices
   ((:voice :id "v-6" :name "Soprano"
     :measures
     (((:note :id "e-7" :pitch "F#4" :duration 1/4 :lyrics ((:lyric :id "ly-8" :text "Now")))
       (:note :id "e-9" :pitch "E4" :duration 1/4 :lyrics ((:lyric :id "ly-a" :text "the")))
       (:note :id "e-b" :pitch "D4" :duration 1/4 :lyrics ((:lyric :id "ly-c" :text "day"))))
      ((:note :id "e-d" :pitch "E4" :duration 1/2 :lyrics ((:lyric :id "ly-e" :text "is")))
       (:note :id "e-f" :pitch "F#4" :duration 1/4 :lyrics ((:lyric :id "ly-g" :text "o"))))
      ((:note :id "e-h" :pitch "D4" :duration 3/4 :fermata (:fermata :id "fe-i") :lyrics ((:lyric :id "ly-j" :text "ver"))))))))
  (:part :id "p-k" :name "Alto" :abbreviation "A." :staves ((:staff :id "st-l"))
   :voices
   ((:voice :id "v-m" :name "Alto"
     :measures
     (((:note :id "e-n" :pitch "D4" :duration 1/4) (:note :id "e-o" :pitch "C#4" :duration 1/4)
       (:note :id "e-p" :pitch "D4" :duration 1/4))
      ((:note :id "e-q" :pitch "C#4" :duration 1/2) (:note :id "e-r" :pitch "D4" :duration 1/4))
      ((:note :id "e-s" :pitch "A3" :duration 3/4 :fermata (:fermata :id "fe-t")))))))
  (:part :id "p-u" :name "Tenor" :abbreviation "T." :staves ((:staff :id "st-v" :clef :treble-8vb))
   :voices
   ((:voice :id "v-w" :name "Tenor"
     :measures
     (((:note :id "e-x" :pitch "A3" :duration 1/4) (:note :id "e-y" :pitch "A3" :duration 1/2 :tie (:tie :id "ti-z" :end "e-10")))
      ((:note :id "e-10" :pitch "A3" :duration 1/4) (:note :id "e-11" :pitch "G3" :duration 1/4)
       (:note :id "e-12" :pitch "A3" :duration 1/4))
      ((:note :id "e-13" :pitch "F#3" :duration 3/4 :fermata (:fermata :id "fe-14")))))))
  (:part :id "p-15" :name "Bass" :abbreviation "B." :staves ((:staff :id "st-16" :clef :bass))
   :voices
   ((:voice :id "v-17" :name "Bass"
     :measures
     (((:note :id "e-18" :pitch "D3" :duration 1/4) (:note :id "e-19" :pitch "A2" :duration 1/4) (:note :id "e-1a" :pitch "B2" :duration 1/4))
      ((:note :id "e-1b" :pitch "A2" :duration 1/2) (:note :id "e-1c" :pitch "D3" :duration 1/4))
      ((:note :id "e-1d" :pitch "D3" :duration 3/4 :fermata (:fermata :id "fe-1e"))))))))
 :chord-symbols
 ((:chord-symbol :id "h-1f" :bar 1 :offset 0 :symbol (:root "D" :quality :major))
  (:chord-symbol :id "h-1g" :bar 2 :offset 0 :symbol (:root "A" :quality :dominant-7))
  (:chord-symbol :id "h-1h" :bar 3 :offset 0 :symbol (:root "D" :quality :major)))
 :spanners ((:spanner :id "sp-1i" :kind :slur :start "e-o" :end "e-p")))
