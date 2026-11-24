;;;; SC0 fixture: a four-part hymn in hymnal layout: one part, two staves, four
;;;; voices (soprano and alto share the treble staff, tenor and bass the bass
;;;; staff, stems up and down). Dynamics, hairpins, a breath mark and final
;;;; fermatas; the soprano carries the words. Text after Thomas Ken (1674,
;;;; public domain). Hand-built, MIT.
(:score
 :metadata (:title "Four-Part Hymn" :lyricist "Thomas Ken")
 :id-counter 52
 :measures
 ((:measure :id "m-1" :time "4/4" :key "G major" :tempo ((:bpm 84 :beat-unit 1/4)))
  (:measure :id "m-2")
  (:measure :id "m-3" :barline :final))
 :parts
 ((:part :id "p-4" :name "Choir" :abbreviation "Ch."
   :staves ((:staff :id "st-5") (:staff :id "st-6" :clef :bass))
   :voices
   ((:voice :id "v-7" :name "Soprano" :stem :up
     :measures
     (((:note :id "e-8" :pitch "B4" :duration 1/4 :dynamic :mf :lyrics ((:lyric :id "ly-9" :text "Praise")))
       (:note :id "e-a" :pitch "A4" :duration 1/4 :lyrics ((:lyric :id "ly-b" :text "God")))
       (:note :id "e-c" :pitch "G4" :duration 1/4 :lyrics ((:lyric :id "ly-d" :text "from")))
       (:note :id "e-e" :pitch "B4" :duration 1/4 :lyrics ((:lyric :id "ly-f" :text "whom"))))
      ((:note :id "e-g" :pitch "C5" :duration 1/4 :lyrics ((:lyric :id "ly-h" :text "all")))
       (:note :id "e-i" :pitch "B4" :duration 1/4 :lyrics ((:lyric :id "ly-j" :text "bless" :syllabic :begin)))
       (:note :id "e-k" :pitch "A4" :duration 1/2 :breath-mark t
        :lyrics ((:lyric :id "ly-l" :text "ings" :syllabic :end))))
      ((:note :id "e-m" :pitch "G4" :duration 1 :fermata :normal
        :lyrics ((:lyric :id "ly-n" :text "flow"))))))
    (:voice :id "v-o" :name "Alto" :stem :down
     :measures
     (((:note :id "e-p" :pitch "G4" :duration 1/4 :dynamic :mf) (:note :id "e-q" :pitch "F#4" :duration 1/4)
       (:note :id "e-r" :pitch "E4" :duration 1/4) (:note :id "e-s" :pitch "G4" :duration 1/4))
      ((:note :id "e-t" :pitch "E4" :duration 1/4) (:note :id "e-u" :pitch "G4" :duration 1/4)
       (:note :id "e-v" :pitch "F#4" :duration 1/2))
      ((:note :id "e-w" :pitch "D4" :duration 1 :fermata :normal))))
    (:voice :id "v-x" :name "Tenor" :staff 2 :stem :up
     :measures
     (((:note :id "e-y" :pitch "D4" :duration 1/4 :dynamic :mf) (:note :id "e-z" :pitch "D4" :duration 1/4)
       (:note :id "e-10" :pitch "B3" :duration 1/4) (:note :id "e-11" :pitch "D4" :duration 1/4))
      ((:note :id "e-12" :pitch "C4" :duration 1/4) (:note :id "e-13" :pitch "D4" :duration 1/4)
       (:note :id "e-14" :pitch "D4" :duration 1/2))
      ((:note :id "e-15" :pitch "B3" :duration 1 :fermata :normal))))
    (:voice :id "v-16" :name "Bass" :staff 2 :stem :down
     :measures
     (((:note :id "e-17" :pitch "G3" :duration 1/4 :dynamic :mf) (:note :id "e-18" :pitch "D3" :duration 1/4)
       (:note :id "e-19" :pitch "E3" :duration 1/4) (:note :id "e-1a" :pitch "G3" :duration 1/4))
      ((:note :id "e-1b" :pitch "A3" :duration 1/4) (:note :id "e-1c" :pitch "G3" :duration 1/4)
       (:note :id "e-1d" :pitch "D3" :duration 1/2))
      ((:note :id "e-1e" :pitch "G2" :duration 1 :fermata :normal)))))))
 :spanners ((:spanner :id "sp-1f" :kind :crescendo :start "e-c" :end "e-g")
            (:spanner :id "sp-1g" :kind :diminuendo :start "e-k" :end "e-m")))
