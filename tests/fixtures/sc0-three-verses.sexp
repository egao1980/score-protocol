;;;; SC0 fixture: a hymn line in 4/4, G major, with three verses. Verses 1 and 3
;;;; hold a word over a slurred melisma (extender); verse 2 sets a syllable on
;;;; the second note instead, and has a three-syllable word (begin, middle,
;;;; end). Hand-built, MIT.
(:score
 :metadata (:title "Hymn in Three Verses")
 :id-counter 49
 :measures
 ((:measure :id "m-1" :time "4/4" :key "G major")
  (:measure :id "m-2")
  (:measure :id "m-3")
  (:measure :id "m-4" :barline :final))
 :parts
 ((:part :id "p-5" :name "Melody" :staves ((:staff :id "st-6"))
   :voices
   ((:voice :id "v-7"
     :measures
     (((:note :id "e-8" :pitch "G4" :duration 1/2
        :lyrics ((:lyric :id "ly-9" :text "All") (:lyric :id "ly-a" :verse 2 :text "Sing")
                 (:lyric :id "ly-b" :verse 3 :text "Him")))
       (:note :id "e-c" :pitch "G4" :duration 1/4
        :lyrics ((:lyric :id "ly-d" :text "peo" :syllabic :begin) (:lyric :id "ly-e" :verse 2 :text "to")
                 (:lyric :id "ly-f" :verse 3 :text "serve")))
       (:note :id "e-g" :pitch "F#4" :duration 1/4
        :lyrics ((:lyric :id "ly-h" :text "ple" :syllabic :end) (:lyric :id "ly-i" :verse 2 :text "the")
                 (:lyric :id "ly-j" :verse 3 :text "with"))))
      ((:note :id "e-k" :pitch "E4" :duration 1/4
        :lyrics ((:lyric :id "ly-l" :text "that") (:lyric :id "ly-m" :verse 2 :text "Lord")
                 (:lyric :id "ly-n" :verse 3 :text "mirth,")))
       (:note :id "e-o" :pitch "D4" :duration 1/2
        :lyrics ((:lyric :id "ly-p" :text "on") (:lyric :id "ly-q" :verse 2 :text "with")
                 (:lyric :id "ly-r" :verse 3 :text "his")))
       (:note :id "e-s" :pitch "G4" :duration 1/4
        :lyrics ((:lyric :id "ly-t" :text "earth") (:lyric :id "ly-u" :verse 2 :text "ev" :syllabic :begin)
                 (:lyric :id "ly-v" :verse 3 :text "praise"))))
      ((:note :id "e-w" :pitch "A4" :duration 1/4
        :lyrics ((:lyric :id "ly-x" :text "do") (:lyric :id "ly-y" :verse 2 :text "er" :syllabic :middle)
                 (:lyric :id "ly-z" :verse 3 :text "forth")))
       (:note :id "e-10" :pitch "B4" :duration 1/4
        :lyrics ((:lyric :id "ly-11" :text "dwell," :extender t)
                 (:lyric :id "ly-12" :verse 2 :text "y" :syllabic :end)
                 (:lyric :id "ly-13" :verse 3 :text "tell," :extender t)))
       (:note :id "e-14" :pitch "A4" :duration 1/4 :breath-mark (:breath-mark :id "br-15")
        :lyrics ((:lyric :id "ly-16" :verse 2 :text "voice;")))
       (:rest :id "e-17" :duration 1/4))
      ((:note :id "e-18" :pitch "G4" :duration 1 :fermata (:fermata :id "fe-19")
        :lyrics ((:lyric :id "ly-1a" :text "Sing") (:lyric :id "ly-1b" :verse 2 :text "Him")
                 (:lyric :id "ly-1c" :verse 3 :text "Come")))))))))
 :spanners ((:spanner :id "sp-1d" :kind :slur :start "e-10" :end "e-14")))
