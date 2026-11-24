;;;; SC0 fixture: a 6/8 carol in A minor with an eighth-note pickup, dotted
;;;; rhythms, a tie across the barline and a final bar that completes the
;;;; pickup. Melody and text after the public-domain carol "What Child Is This"
;;;; (Greensleeves; text 1865). Hand-built, MIT.
(:score
 :metadata (:title "What Child Is This" :composer "Traditional"
            :lyricist "William Chatterton Dix")
 :id-counter 47
 :measures
 ((:measure :id "m-1" :time "6/8" :key "A minor" :pickup t :length 1/8
   :tempo ((:bpm 60 :beat-unit 3/8 :text "Andante")))
  (:measure :id "m-2")
  (:measure :id "m-3")
  (:measure :id "m-4")
  (:measure :id "m-5")
  (:measure :id "m-6" :length 5/8 :barline :final))
 :parts
 ((:part :id "p-7" :name "Voice" :staves ((:staff :id "st-8"))
   :voices
   ((:voice :id "v-9"
     :measures
     (((:note :id "e-a" :pitch "A4" :duration 1/8 :lyrics ((:lyric :id "ly-b" :text "What"))))
      ((:note :id "e-c" :pitch "C5" :duration 1/4 :lyrics ((:lyric :id "ly-d" :text "Child")))
       (:note :id "e-e" :pitch "D5" :duration 1/8 :lyrics ((:lyric :id "ly-f" :text "is")))
       (:note :id "e-g" :pitch "E5" :duration 3/16
        :lyrics ((:lyric :id "ly-h" :text "this" :extender t)))
       (:note :id "e-i" :pitch "F5" :duration 1/16)
       (:note :id "e-j" :pitch "E5" :duration 1/8 :lyrics ((:lyric :id "ly-k" :text "who"))))
      ((:note :id "e-l" :pitch "D5" :duration 1/4 :lyrics ((:lyric :id "ly-m" :text "laid")))
       (:note :id "e-n" :pitch "B4" :duration 1/8 :lyrics ((:lyric :id "ly-o" :text "to")))
       (:note :id "e-p" :pitch "G4" :duration 3/16
        :lyrics ((:lyric :id "ly-q" :text "rest," :extender t)))
       (:note :id "e-r" :pitch "A4" :duration 1/16)
       (:note :id "e-s" :pitch "B4" :duration 1/8 :lyrics ((:lyric :id "ly-t" :text "On"))))
      ((:note :id "e-u" :pitch "C5" :duration 1/4 :lyrics ((:lyric :id "ly-v" :text "Ma" :syllabic :begin)))
       (:note :id "e-w" :pitch "A4" :duration 1/8 :lyrics ((:lyric :id "ly-x" :text "ry's" :syllabic :end)))
       (:note :id "e-y" :pitch "A4" :duration 3/16 :lyrics ((:lyric :id "ly-z" :text "lap")))
       (:note :id "e-10" :pitch "G#4" :duration 1/16)
       (:note :id "e-11" :pitch "A4" :duration 1/8 :lyrics ((:lyric :id "ly-12" :text "is"))))
      ((:note :id "e-13" :pitch "B4" :duration 1/4 :lyrics ((:lyric :id "ly-14" :text "sleep" :syllabic :begin)))
       (:note :id "e-15" :pitch "G#4" :duration 1/8 :lyrics ((:lyric :id "ly-16" :text "ing?" :syllabic :end)))
       (:note :id "e-17" :pitch "E4" :duration 3/8 :tie "e-18"))
      ((:note :id "e-18" :pitch "E4" :duration 1/4)
       (:rest :id "e-19" :duration 3/8)))))))
 :spanners ((:spanner :id "sp-1a" :kind :slur :start "e-g" :end "e-i")
            (:spanner :id "sp-1b" :kind :slur :start "e-p" :end "e-r")))
