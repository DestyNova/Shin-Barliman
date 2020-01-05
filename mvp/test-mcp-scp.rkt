#lang racket

;; Simulates an SCP interaction with the MCP, in order to test the MCP.

(provide
  (all-from-out racket/tcp)
  (all-defined-out))

(require
  racket/tcp
  "common.rkt")

(print-as-expression #f)

;; Loading will occur at first use if not explicitly forced like this.
(load-config #t)

(define DEFAULT-TCP-IP-ADDRESS (config-ref 'scp-tcp-ip-address))
(define DEFAULT-TCP-PORT (config-ref 'scp-tcp-port))

(define (simulate-scp address port)
  (printf "fake scp connecting to mcp at ~s:~s...\n" address port)
  (define-values (in out) (tcp-connect address port))
  (printf "fake scp connected to mcp at ~s:~s\n" address port)
  ;;
  (define hello-msg `(hello))
  (printf "fake scp writing hello message ~s\n" hello-msg)
  (write hello-msg out)
  (flush-output out)
  (printf "fake scp wrote hello message ~s\n" hello-msg)
  ;;
  (define msg1 (read in))
  (printf "fake scp received message ~s\n" msg1)
  ;;

  ;; TODO respond to MCP messages, pretend to perform synthesis, and
  ;; return a message with the synthesized program
  
  ;; cleanup
  (close-input-port in)
  (close-output-port out)
  )

(simulate-scp DEFAULT-TCP-IP-ADDRESS DEFAULT-TCP-PORT)