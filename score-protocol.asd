(defsystem "score-protocol"
  :version "0.4.0"
  :description "CLOS score model for cl-stack: parts, measures, voices, lyrics, chord symbols, edit operations, views, a builder for drafts with forward references, and origins in provenance"
  :author "egao1980"
  :license "MIT"
  :depends-on ((:version "music-theory" "0.5.0") "fset")
  :pathname "src"
  :serial t
  :components ((:file "package")
               (:file "conditions")
               (:file "ids")
               (:file "builder")
               (:file "elements")
               (:file "measure-map")
               (:file "score")
               (:file "check")
               (:file "sexp")
               (:file "edits")
               (:file "edit-events")
               (:file "edit-measures")
               (:file "views"))
  :in-order-to ((test-op (test-op "score-protocol/tests"))))

(defsystem "score-protocol/tests"
  :depends-on ("score-protocol" (:version "rove" "0.11.1"))
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "sc0-model-test")
               (:file "sc0-ids-test")
               (:file "sc0-positions-test")
               (:file "sc0-check-test")
               (:file "sc1-edits-test")
               (:file "sc1-measures-test")
               (:file "sc1-views-test")
               (:file "sc1-properties-test")
               (:file "sc3-builder-test")
               (:file "sc3-fixes-test")
               (:file "sc4-origin-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))
