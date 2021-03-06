;; Load this file in Chez Scheme to test 'synthesis.scm' by itself.

;; Here we synthesize part of `append`.  We expect the answer to
;; contain fresh logic variables and side-conditions.

(define (print-error-messages err-port)
  (let loop ()
    (when (input-port-ready? err-port)
      (let ((c (read-char err-port)))
        (unless (eof-object? c)
          (printf "~a" c)
          (loop))))))

(let-values ([(to-stdin from-stdout from-stderr process-id)
              (open-process-ports "/usr/local/bin/scheme -q synthesis.scm"
                                  (buffer-mode block)
                                  (make-transcoder (utf-8-codec)))])
  (print-error-messages from-stderr)
  (printf "read msg: ~s\n" (read from-stdout))
  (print-error-messages from-stderr)
  (write `(get-status) to-stdin)
  (flush-output-port to-stdin)
  (print-error-messages from-stderr)
  (printf "read msg: ~s\n" (read from-stdout))
  (print-error-messages from-stderr)
  (let ((definitions '((define ,A
                         (lambda ,B
                           ,C))))
        (inputs '((append '() '())
                  (append '(cat) '(猫))))
        (outputs '(()
                   (cat 猫)))
        (synthesis-id 1))
    (print-error-messages from-stderr)    
    (write `(synthesize (,definitions ,inputs ,outputs) ,synthesis-id) to-stdin)    
    (flush-output-port to-stdin)
    (printf "wrote synthesize message\n")
    (print-error-messages from-stderr)
    (write `(get-status) to-stdin)
    (flush-output-port to-stdin)
    (printf "wrote get-status message\n")
    (print-error-messages from-stderr)
    (printf "read msg: ~s\n" (read from-stdout))
    (print-error-messages from-stderr)
    (printf "read msg: ~s\n" (read from-stdout))
    (print-error-messages from-stderr)    
    (write `(get-status) to-stdin)
    (flush-output-port to-stdin)
    (printf "wrote get-status message\n")
    (print-error-messages from-stderr)
    (printf "read msg: ~s\n" (read from-stdout))
    (printf "read msg: ~s\n" (read from-stdout))
    (printf "read msg: ~s\n" (read from-stdout))
    ))
