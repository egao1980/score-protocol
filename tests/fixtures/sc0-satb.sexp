;;;; SC0 fixture: a four-part hymn in hymnal layout: one part, two staves, four
;;;; voices (soprano and alto share the treble staff, tenor and bass the bass
;;;; staff, stems up and down). Dynamics, hairpins, a breath mark and final
;;;; fermatas; the soprano carries the words. Text after Thomas Ken (1674,
;;;; public domain). Hand-built, MIT.
(:score
 :metadata (:title "Four-Part Hymn" :lyricist "Thomas Ken")
 :id-counter 62
 :measures
 ((:measure :id "m-1" :time "4/4" :key "G major" :tempo ((:tempo-mark :id "tm-2" :bpm 84 :beat-unit 1/4)))
  (:measure :id "m-3")
  (:measure :id "m-4" :barline :final))
 :parts
 ((:part :id "p-5" :name "Choir" :abbreviation "Ch."
   :staves ((:staff :id "st-6") (:staff :id "st-7" :clef :bass))
   :voices
   ((:voice :id "v-8" :name "Soprano" :stem :up
     :measures
     (((:note :id "e-9" :pitch "B4" :duration 1/4 :dynamic (:dynamic :id "dy-a" :value :mf)
        :lyrics ((:lyric :id "ly-b" :text "Praise")))
       (:note :id "e-c" :pitch "A4" :duration 1/4 :lyrics ((:lyric :id "ly-d" :text "God")))
       (:note :id "e-e" :pitch "G4" :duration 1/4 :lyrics ((:lyric :id "ly-f" :text "from")))
       (:note :id "e-g" :pitch "B4" :duration 1/4 :lyrics ((:lyric :id "ly-h" :text "whom"))))
      ((:note :id "e-i" :pitch "C5" :duration 1/4 :lyrics ((:lyric :id "ly-j" :text "all")))
       (:note :id "e-k" :pitch "B4" :duration 1/4
        :lyrics ((:lyric :id "ly-l" :text "bless" :syllabic :begin)))
       (:note :id "e-m" :pitch "A4" :duration 1/2 :breath-mark (:breath-mark :id "br-n")
        :lyrics ((:lyric :id "ly-o" :text "ings" :syllabic :end))))
      ((:note :id "e-p" :pitch "G4" :duration 1 :fermata (:fermata :id "fe-q")
        :lyrics ((:lyric :id "ly-r" :text "flow"))))))
    (:voice :id "v-s" :name "Alto" :stem :down
     :measures
     (((:note :id "e-t" :pitch "G4" :duration 1/4 :dynamic (:dynamic :id "dy-u" :value :mf))
       (:note :id "e-v" :pitch "F#4" :duration 1/4)
       (:note :id "e-w" :pitch "E4" :duration 1/4) (:note :id "e-x" :pitch "G4" :duration 1/4))
      ((:note :id "e-y" :pitch "E4" :duration 1/4) (:note :id "e-z" :pitch "G4" :duration 1/4)
       (:note :id "e-10" :pitch "F#4" :duration 1/2))
      ((:note :id "e-11" :pitch "D4" :duration 1 :fermata (:fermata :id "fe-12")))))
    (:voice :id "v-13" :name "Tenor" :staff 2 :stem :up
     :measures
     (((:note :id "e-14" :pitch "D4" :duration 1/4 :dynamic (:dynamic :id "dy-15" :value :mf))
       (:note :id "e-16" :pitch "D4" :duration 1/4)
       (:note :id "e-17" :pitch "B3" :duration 1/4) (:note :id "e-18" :pitch "D4" :duration 1/4))
      ((:note :id "e-19" :pitch "C4" :duration 1/4) (:note :id "e-1a" :pitch "D4" :duration 1/4)
       (:note :id "e-1b" :pitch "D4" :duration 1/2))
      ((:note :id "e-1c" :pitch "B3" :duration 1 :fermata (:fermata :id "fe-1d")))))
    (:voice :id "v-1e" :name "Bass" :staff 2 :stem :down
     :measures
     (((:note :id "e-1f" :pitch "G3" :duration 1/4 :dynamic (:dynamic :id "dy-1g" :value :mf))
       (:note :id "e-1h" :pitch "D3" :duration 1/4)
       (:note :id "e-1i" :pitch "E3" :duration 1/4) (:note :id "e-1j" :pitch "G3" :duration 1/4))
      ((:note :id "e-1k" :pitch "A3" :duration 1/4) (:note :id "e-1l" :pitch "G3" :duration 1/4)
       (:note :id "e-1m" :pitch "D3" :duration 1/2))
      ((:note :id "e-1n" :pitch "G2" :duration 1 :fermata (:fermata :id "fe-1o"))))))))
 :spanners ((:spanner :id "sp-1p" :kind :crescendo :start "e-e" :end "e-i")
            (:spanner :id "sp-1q" :kind :diminuendo :start "e-m" :end "e-p")))
