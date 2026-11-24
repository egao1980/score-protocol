(defsystem "score-protocol"
  :version "0.1.0"
  :description "CLOS score model for cl-stack: parts, measures, voices, lyrics, chord symbols, edit operations and views"
  :author "egao1980"
  :license "MIT"
  :depends-on ((:version "music-theory" "0.4.0") "fset")
  :pathname "src"
  :serial t
  :components ((:file "package")
               (:file "conditions")
               (:file "ids")
               (:file "elements")
               (:file "measure-map")
               (:file "score")
               (:file "check")
               (:file "sexp"))
  :in-order-to ((test-op (test-op "score-protocol/tests"))))

(defsystem "score-protocol/tests"
  :depends-on ("score-protocol" "rove")
  :pathname "tests"
  :serial t
  :components ((:file "package")
               (:file "sc0-model-test")
               (:file "sc0-ids-test")
               (:file "sc0-positions-test")
               (:file "sc0-check-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))
