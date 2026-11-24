(defsystem "score-protocol"
  :version "0.2.0"
  :description "CLOS score model for cl-stack: parts, measures, voices, lyrics, chord symbols, edit operations and views"
  :author "egao1980"
  :license "MIT"
  :depends-on ((:version "music-theory" "0.5.0") "fset")
  :pathname "src"
  :serial t
  :components ((:file "package")
               (:file "conditions")
               (:file "ids")
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
               (:file "sc1-properties-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))
