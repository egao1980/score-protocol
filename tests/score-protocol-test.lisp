(defpackage #:score-protocol/tests
  (:use #:cl #:rove))

(in-package #:score-protocol/tests)

(deftest skeleton-loads
  (ok (find-package '#:score-protocol)))
