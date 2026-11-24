;;;; SC0 fixture: a 6/8 carol in A minor with an eighth-note pickup, dotted
;;;; rhythms, a tie across the barline and a final bar that completes the
;;;; pickup. Melody and text after the public-domain carol "What Child Is This"
;;;; (Greensleeves; text 1865). Hand-built, MIT.
(:score
 :metadata (:title "What Child Is This" :composer "Traditional"
            :lyricist "William Chatterton Dix")
 :id-counter 49
 :measures
 ((:measure :id "m-1" :time "6/8" :key "A minor" :pickup t :length 1/8
   :tempo ((:tempo-mark :id "tm-2" :bpm 60 :beat-unit 3/8 :text "Andante")))
  (:measure :id "m-3")
  (:measure :id "m-4")
  (:measure :id "m-5")
  (:measure :id "m-6")
  (:measure :id "m-7" :length 5/8 :barline :final))
 :parts
 ((:part :id "p-8" :name "Voice" :staves ((:staff :id "st-9"))
   :voices
   ((:voice :id "v-a"
     :measures
     (((:note :id "e-b" :pitch "A4" :duration 1/8 :lyrics ((:lyric :id "ly-c" :text "What"))))
      ((:note :id "e-d" :pitch "C5" :duration 1/4 :lyrics ((:lyric :id "ly-e" :text "Child")))
       (:note :id "e-f" :pitch "D5" :duration 1/8 :lyrics ((:lyric :id "ly-g" :text "is")))
       (:note :id "e-h" :pitch "E5" :duration 3/16
        :lyrics ((:lyric :id "ly-i" :text "this" :extender t)))
       (:note :id "e-j" :pitch "F5" :duration 1/16)
       (:note :id "e-k" :pitch "E5" :duration 1/8 :lyrics ((:lyric :id "ly-l" :text "who"))))
      ((:note :id "e-m" :pitch "D5" :duration 1/4 :lyrics ((:lyric :id "ly-n" :text "laid")))
       (:note :id "e-o" :pitch "B4" :duration 1/8 :lyrics ((:lyric :id "ly-p" :text "to")))
       (:note :id "e-q" :pitch "G4" :duration 3/16
        :lyrics ((:lyric :id "ly-r" :text "rest," :extender t)))
       (:note :id "e-s" :pitch "A4" :duration 1/16)
       (:note :id "e-t" :pitch "B4" :duration 1/8 :lyrics ((:lyric :id "ly-u" :text "On"))))
      ((:note :id "e-v" :pitch "C5" :duration 1/4 :lyrics ((:lyric :id "ly-w" :text "Ma" :syllabic :begin)))
       (:note :id "e-x" :pitch "A4" :duration 1/8 :lyrics ((:lyric :id "ly-y" :text "ry's" :syllabic :end)))
       (:note :id "e-z" :pitch "A4" :duration 3/16 :lyrics ((:lyric :id "ly-10" :text "lap")))
       (:note :id "e-11" :pitch "G#4" :duration 1/16)
       (:note :id "e-12" :pitch "A4" :duration 1/8 :lyrics ((:lyric :id "ly-13" :text "is"))))
      ((:note :id "e-14" :pitch "B4" :duration 1/4 :lyrics ((:lyric :id "ly-15" :text "sleep"
                                                             :syllabic :begin)))
       (:note :id "e-16" :pitch "G#4" :duration 1/8 :lyrics ((:lyric :id "ly-17" :text "ing?"
                                                              :syllabic :end)))
       (:note :id "e-18" :pitch "E4" :duration 3/8 :tie (:tie :id "ti-19" :end "e-1a")))
      ((:note :id "e-1a" :pitch "E4" :duration 1/4)
       (:rest :id "e-1b" :duration 3/8)))))))
 :spanners ((:spanner :id "sp-1c" :kind :slur :start "e-h" :end "e-j")
            (:spanner :id "sp-1d" :kind :slur :start "e-q" :end "e-s")))
