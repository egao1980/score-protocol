(:score :metadata (:title "Tallis's Canon" :composer "Thomas Tallis" :lyricist "Thomas Ken")
 :id-counter 70 :measures
 ((:measure :id "m-1" :time "4/4" :key "G major") (:measure :id "m-2") (:measure :id "m-3")
  (:measure :id "m-4" :barline :final))
 :parts
 ((:part :id "P1" :name "Choir" :abbreviation "Ch." :staves
   ((:staff :id "st-5") (:staff :id "st-6" :clef :bass)) :voices
   ((:voice :id "v-7" :stem :up :measures
     (((:note :id "e-8" :pitch "G4" :duration 1/2 :dynamic (:dynamic :id "dy-9" :value :mf) :lyrics
        ((:lyric :id "ly-a" :text "Glo" :syllabic :begin)))
       (:note :id "e-b" :pitch "G4" :duration 1/4 :lyrics
        ((:lyric :id "ly-c" :text "ry" :syllabic :end)))
       (:note :id "e-d" :pitch "F#4" :duration 1/4 :lyrics ((:lyric :id "ly-e" :text "to"))))
      ((:note :id "e-f" :pitch "G4" :duration 1/2 :lyrics ((:lyric :id "ly-g" :text "thee,")))
       (:note :id "e-h" :pitch "A4" :duration 1/2 :breath-mark (:breath-mark :id "br-i") :lyrics
        ((:lyric :id "ly-j" :text "my"))))
      ((:note :id "e-k" :pitch "A4" :duration 1/4 :lyrics ((:lyric :id "ly-l" :text "God,")))
       (:note :id "e-m" :pitch "B4" :duration 1/4 :lyrics ((:lyric :id "ly-n" :text "this")))
       (:note :id "e-o" :pitch "B4" :duration 1/4 :lyrics ((:lyric :id "ly-p" :text "night,")))
       (:note :id "e-q" :pitch "A4" :duration 1/4 :lyrics ((:lyric :id "ly-r" :text "for"))))
      ((:note :id "e-s" :pitch "B4" :duration 1 :fermata (:fermata :id "fe-t") :lyrics
        ((:lyric :id "ly-u" :text "light"))))))
    (:voice :id "v-v" :stem :down :measures
     (((:note :id "e-w" :pitch "D4" :duration 1/2 :dynamic (:dynamic :id "dy-x" :value :mf))
       (:note :id "e-y" :pitch "D4" :duration 1/4) (:note :id "e-z" :pitch "D4" :duration 1/4))
      ((:note :id "e-10" :pitch "G4" :duration 1/2)
       (:note :id "e-11" :pitch "F#4" :duration 1/2 :breath-mark (:breath-mark :id "br-12")))
      ((:note :id "e-13" :pitch "F#4" :duration 1/2) (:note :id "e-14" :pitch "G4" :duration 1/4)
       (:note :id "e-15" :pitch "F#4" :duration 1/4))
      ((:note :id "e-16" :pitch "G4" :duration 1 :fermata (:fermata :id "fe-17")))))
    (:voice :id "v-18" :staff 2 :stem :up :measures
     (((:note :id "e-19" :pitch "B3" :duration 1/2 :dynamic (:dynamic :id "dy-1a" :value :mf))
       (:note :id "e-1b" :pitch "B3" :duration 1/4) (:note :id "e-1c" :pitch "A3" :duration 1/4))
      ((:note :id "e-1d" :pitch "B3" :duration 1/2) (:note :id "e-1e" :pitch "D4" :duration 1/2))
      ((:note :id "e-1f" :pitch "D4" :duration 1/4) (:note :id "e-1g" :pitch "D4" :duration 1/4)
       (:note :id "e-1h" :pitch "D4" :duration 1/4)
       (:note :id "e-1i" :pitch "D4" :duration 1/4 :tie (:tie :id "ti-1j" :end "e-1k")))
      ((:note :id "e-1k" :pitch "D4" :duration 1 :fermata (:fermata :id "fe-1l")))))
    (:voice :id "v-1m" :staff 2 :stem :down :measures
     (((:note :id "e-1n" :pitch "G3" :duration 1/2 :dynamic (:dynamic :id "dy-1o" :value :mf))
       (:note :id "e-1p" :pitch "G3" :duration 1/4) (:note :id "e-1q" :pitch "D3" :duration 1/4))
      ((:note :id "e-1r" :pitch "G3" :duration 1/2) (:note :id "e-1s" :pitch "D3" :duration 1/2))
      ((:note :id "e-1t" :pitch "D3" :duration 1/4) (:note :id "e-1u" :pitch "G3" :duration 1/4)
       (:note :id "e-1v" :pitch "B2" :duration 1/4) (:note :id "e-1w" :pitch "D3" :duration 1/4))
      ((:note :id "e-1x" :pitch "G2" :duration 1 :fermata (:fermata :id "fe-1y")))))))))
