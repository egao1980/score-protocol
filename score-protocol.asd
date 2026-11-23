(defsystem "score-protocol"
  :version "0.0.1"
  :description "CLOS score model for cl-stack: parts, measures, voices, lyrics, chord symbols, edit operations and views"
  :author "egao1980"
  :license "MIT"
  :pathname "src"
  :serial t
  :components ((:file "package"))
  :in-order-to ((test-op (test-op "score-protocol/tests"))))

(defsystem "score-protocol/tests"
  :depends-on ("score-protocol" "rove")
  :pathname "tests"
  :serial t
  :components ((:file "score-protocol-test"))
  :perform (test-op (o c)
             (unless (symbol-call :rove :run c)
               (error "tests failed for ~A" (component-name c)))))
