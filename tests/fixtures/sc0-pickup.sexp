;;;; SC0 fixture: a quarter-note pickup in 3/4, completed by a half-bar final
;;;; measure; a slurred melisma with an extender. Melody and text after the
;;;; public-domain hymn "Amazing Grace" (tune 1829, text 1779). Hand-built, MIT.
(:score
 :metadata (:title "Amazing Grace" :composer "Traditional" :lyricist "John Newton")
 :id-counter 28
 :measures
 ((:measure :id "m-1" :time "3/4" :key "G major" :pickup t :length 1/4
   :tempo ((:tempo-mark :id "tm-2" :bpm 72 :beat-unit 1/4)))
  (:measure :id "m-3")
  (:measure :id "m-4")
  (:measure :id "m-5")
  (:measure :id "m-6" :length 1/2 :barline :final))
 :parts
 ((:part :id "p-7" :name "Voice" :staves ((:staff :id "st-8"))
   :voices
   ((:voice :id "v-9"
     :measures
     (((:note :id "e-a" :pitch "D4" :duration 1/4 :lyrics ((:lyric :id "ly-b" :text "A" :syllabic :begin))))
      ((:note :id "e-c" :pitch "G4" :duration 1/2 :lyrics ((:lyric :id "ly-d" :text "maz" :syllabic :middle)))
       (:note :id "e-e" :pitch "B4" :duration 1/8
        :lyrics ((:lyric :id "ly-f" :text "ing" :syllabic :end :extender t)))
       (:note :id "e-g" :pitch "G4" :duration 1/8))
      ((:note :id "e-h" :pitch "B4" :duration 1/2 :lyrics ((:lyric :id "ly-i" :text "grace")))
       (:note :id "e-j" :pitch "A4" :duration 1/4 :lyrics ((:lyric :id "ly-k" :text "how"))))
      ((:note :id "e-l" :pitch "G4" :duration 1/2 :lyrics ((:lyric :id "ly-m" :text "sweet")))
       (:note :id "e-n" :pitch "E4" :duration 1/4 :lyrics ((:lyric :id "ly-o" :text "the"))))
      ((:note :id "e-p" :pitch "D4" :duration 1/2 :fermata (:fermata :id "fe-q")
        :lyrics ((:lyric :id "ly-r" :text "sound")))))))))
 :spanners ((:spanner :id "sp-s" :kind :slur :start "e-e" :end "e-g")))
