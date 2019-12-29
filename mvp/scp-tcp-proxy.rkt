#lang racket/base

; This is a code between mcp(client) and subprocess

(require
  racket/tcp
  "common.rkt")

(provide  
  (all-from-out racket/tcp)
  (all-defined-out))


(print-as-expression #f)

;; Loading will occur at first use if not explicitly forced like this.
(load-config #t)

(define DEFAULT-TCP-IP-ADDRESS (config-ref 'scp-tcp-ip-address))
(define DEFAULT-TCP-PORT (config-ref 'scp-tcp-port))

; (define *program* (box #f))
; (define *tests* (box #f))
; (define *scm-files* (box #f))

(define *data* (box #f))
(define *tcp-out* #f)

(define (handle-scp)
   (let loop ((msg (read (current-input-port))))
     ; (printf "subprocess-client received message from SCP ~s\n" msg)
     (write msg *tcp-out*)
     (flush-output *tcp-out*)
     ; (printf "subprocess-client sent message from MCP ~s\n" msg)
     (loop (read (current-input-port))))
)

(define (handle-tcp tcp-in tcp-out)
  (lambda ()
   (let loop ((msg (read tcp-in)))
      (write msg (current-output-port))
      (flush-output (current-output-port))
      (loop (read tcp-in))
     )
  ))

;   (cond
;     ((eof-object? msg)
;      (write '(goodbye) tcp-out)
;      (printf "subprocess-client sent goodbye message\n")
;	)	
;     ((eq? msg 'finished)
;      (loop (read tcp-in)))
;     ((eq? (car msg) 'data-sending)
;       (set! *program* (cdr (car (cdr msg))))
;       (set! *tests* (cdr (car (cdr (cdr msg)))))
;       (set! *scm-files* (cdr (car (cdr (cdr (cdr msg))))))
;        (set! *data* (cadr msg))
;	(open-input-string "~s\n" (cdr *data*))
;       (loop (read tcp-in)))
;      (else 
;       (printf "error : ~s\n" msg)       
;       (loop (read tcp-in))))))

(define (connect address port)
  (define-values (tcp-in tcp-out) (tcp-connect address port))
;  (printf "client writing hello message\n")
   (write '(hello) tcp-out)
   (set! *tcp-out* tcp-out)
   (flush-output tcp-out)
;  (printf "client wrote hello message\n")

   (thread (handle-tcp tcp-in tcp-out))
   (handle-scp)
   



;   (close-input-port tcp-in)
;   (close-output-port tcp-out)

)

(connect DEFAULT-TCP-IP-ADDRESS DEFAULT-TCP-PORT)

;; > (require "scp-tcp-proxy.rkt")
;; > (connect "localhost" 8082)
