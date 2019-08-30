
;; Peano arithmetic
;; n ::= z
;;     | (s n)

;; Arabic -> Peano
(define build-num
  (lambda (n)
    (cond
      ((zero? n) 'z)
      (else (cons 's (build-num (sub1 n)))))))

;;;;;;;;;;;;;;;;;;;;;;;;

;;; Peano code
(define zero?
  (lambda (n)
    (equal? 'z n)))

(define add1
  (lambda (n)
    (cons 's n)))

(define sub1
  (lambda (n)
    (and (equal? (car n) 's)
         (cdr n))))

(define =
  (lambda (n m)
    (if (and (zero? n) (zero? m))
        #t
        (if (zero? n)
            #f
            (if (zero? m)
                #f
                (= (sub1 n) (sub1 m)))))))

(define +
  (lambda (n m)
    (if (zero? n)
        m
        (add1 (+ (sub1 n) m)))))

(define -
  (lambda (n m)
    (if (zero? m)
        n
        (sub1 (- n (sub1 m))))))

(define *
  (lambda (n m)
    (if (zero? n)
        (zero)
        (+ (* (sub1 n) m) m))))


(define zero
  (lambda ()
    'z))
(define one
  (lambda ()
    (add1 (zero))))
(define two
  (lambda ()
    (add1 (add1 (zero)))))


(define !
  (lambda (n)
    (if (zero? n)
        (one)
        (* n (! (sub1 n))))))

(define !-aps
  (lambda (n a)
    (if (zero? n)
        a
        (!-aps (sub1 n) (* n a)))))

(define fib
  (lambda (n)
    (if (= (zero) n)
        (zero)
        (if (= (one) n)
            (one)
            (+ (fib (- n (one))) (fib (- n (two))))))))

#|
(define fib-aps
  (lambda (n a1 a2)
    (if (= n 'z)
        a1
        (if (= n '(s . z))
            a2
            (fib-aps (- n '(s . z)) a2 (+ a1 a2))))))
|#

(define fib-aps
  (lambda (n a1 a2)
    (if (zero? n)
        a1
        (if (zero? (sub1 n))
            a2
            (fib-aps (- n '(s . z)) a2 (+ a1 a2))))))

(! 'z)

(!-aps '(s s s . z) '(s . z))

(fib '(s s s s s s . z))
(fib '(s s s s s . z))
(fib '(s s s s . z))

(fib-aps '(s s s s s s . z) 'z '(s . z))
;; => (s s s s s s s s . z)
