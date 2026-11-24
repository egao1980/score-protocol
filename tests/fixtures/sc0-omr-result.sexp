;;;; SC0 fixture: a score as a recogniser might return it: provenance (optical
;;;; recognition with page and bounding box, audio transcription with a time
;;;; range) and confidences on measures, events, chord notes, lyrics, a chord
;;;; symbol and a slur. Confidences are floats, a ratio and integers; one equals
;;;; the default report threshold 0.8. Hand-built, MIT.
(:score
 :metadata (:title "Recognised Page")
 :id-counter 22
 :measures
 ((:measure :id "m-1" :time "3/4" :key "F major"
   :provenance (:source :omr :backend "omr-example" :page 1 :bbox (40 120 600 180))
   :confidence 0.99)
  (:measure :id "m-2"
   :provenance (:source :omr :backend "omr-example" :page 1 :bbox (640 120 600 180))
   :confidence 0.9)
  (:measure :id "m-3" :barline :final
   :provenance (:source :omr :backend "omr-example" :page 1 :bbox (1240 120 560 180))
   :confidence 0.75))
 :parts
 ((:part :id "p-4" :name "Voice" :staves ((:staff :id "st-5"))
   :voices
   ((:voice :id "v-6"
     :measures
     (((:note :id "e-7" :pitch "F4" :duration 1/4
        :lyrics ((:lyric :id "ly-8" :text "Glo" :syllabic :begin :confidence 0.9))
        :provenance (:source :omr :backend "omr-example" :page 1 :bbox (60 140 20 40))
        :confidence 0.95)
       (:note :id "e-9" :pitch "A4" :duration 1/4
        :lyrics ((:lyric :id "ly-a" :text "ri" :syllabic :middle :confidence 0.55))
        :provenance (:source :omr :backend "omr-example" :page 1 :bbox (100 130 20 40))
        :confidence 0.62)
       (:note :id "e-b" :pitch "C5" :duration 1/4
        :lyrics ((:lyric :id "ly-c" :text "a" :syllabic :end))
        :confidence 0.8))
      ((:chord :id "e-d" :notes ((:chord-note :id "n-e" :pitch "F4")
                       (:chord-note :id "n-f" :pitch "A4" :confidence 1/2)
                       (:chord-note :id "n-g" :pitch "C5" :confidence 1))
        :duration 1/2 :confidence 0.45)
       (:rest :id "e-h" :duration 1/4 :confidence 0))
      ((:note :id "e-i" :pitch "F4" :duration 3/4 :fermata (:fermata :id "fe-j")
        :provenance (:source :transcription :backend "pitch-tracker"
                     :time-range (4.5 6.75)))))))
   :provenance (:source :omr :backend "omr-example" :page 1)
   :confidence 0.97))
 :chord-symbols
 ((:chord-symbol :id "h-k" :bar 1 :offset 0 :symbol (:root "F" :quality :major)
   :confidence 0.7)
  (:chord-symbol :id "h-l" :bar 2 :offset 1/2 :symbol (:root "C" :quality :dominant-7)
   :confidence 0.85))
 :spanners ((:spanner :id "sp-m" :kind :slur :start "e-7" :end "e-b"
             :confidence 0.3)))
