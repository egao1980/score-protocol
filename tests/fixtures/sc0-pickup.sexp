;;;; SC0 fixture: a quarter-note pickup in 3/4, completed by a half-bar final
;;;; measure; a slurred melisma with an extender. Melody and text after the
;;;; public-domain hymn "Amazing Grace" (tune 1829, text 1779). Hand-built, MIT.
(:score
 :metadata (:title "Amazing Grace" :composer "Traditional" :lyricist "John Newton")
 :id-counter 26
 :measures
 ((:measure :id "m-1" :time "3/4" :key "G major" :pickup t :length 1/4
   :tempo ((:bpm 72 :beat-unit 1/4)))
  (:measure :id "m-2")
  (:measure :id "m-3")
  (:measure :id "m-4")
  (:measure :id "m-5" :length 1/2 :barline :final))
 :parts
 ((:part :id "p-6" :name "Voice" :staves ((:staff :id "st-7"))
   :voices
   ((:voice :id "v-8"
     :measures
     (((:note :id "e-9" :pitch "D4" :duration 1/4 :lyrics ((:lyric :id "ly-a" :text "A" :syllabic :begin))))
      ((:note :id "e-b" :pitch "G4" :duration 1/2 :lyrics ((:lyric :id "ly-c" :text "maz" :syllabic :middle)))
       (:note :id "e-d" :pitch "B4" :duration 1/8
        :lyrics ((:lyric :id "ly-e" :text "ing" :syllabic :end :extender t)))
       (:note :id "e-f" :pitch "G4" :duration 1/8))
      ((:note :id "e-g" :pitch "B4" :duration 1/2 :lyrics ((:lyric :id "ly-h" :text "grace")))
       (:note :id "e-i" :pitch "A4" :duration 1/4 :lyrics ((:lyric :id "ly-j" :text "how"))))
      ((:note :id "e-k" :pitch "G4" :duration 1/2 :lyrics ((:lyric :id "ly-l" :text "sweet")))
       (:note :id "e-m" :pitch "E4" :duration 1/4 :lyrics ((:lyric :id "ly-n" :text "the"))))
      ((:note :id "e-o" :pitch "D4" :duration 1/2 :fermata :normal
        :lyrics ((:lyric :id "ly-p" :text "sound")))))))))
 :spanners ((:spanner :id "sp-q" :kind :slur :start "e-d" :end "e-f")))
