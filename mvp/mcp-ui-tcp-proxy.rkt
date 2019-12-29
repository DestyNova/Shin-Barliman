#lang racket/base

;; Proxy started by MCP for TCP communication with UI

;; This proxy uses a single-threaded architecture, and only supports 1
;; UI connection at a time.  We might want to relax this restriction
;; in the future.

;; Adapted from https://docs.racket-lang.org/more/

(require
  racket/tcp
  "common.rkt")

(provide  
  (all-from-out racket/tcp)
  (all-defined-out))


(print-as-expression #f)

;; Loading will occur at first use if not explicitly forced like this.
(load-config #t)

(define DEFAULT-TCP-PORT (config-ref 'ui-tcp-port))

;; MAX-CONNECTIONS is hard-coded, instead of user-configurable, since
;; the MVP currently only supports 1 UI connection at a time
(define MAX-CONNECTIONS 1) 

(define (serve port-no)
  (define listener (tcp-listen port-no MAX-CONNECTIONS #t))
  (define (loop)
    (accept-and-handle listener)
    (loop))
  (loop))

(define (accept-and-handle listener)
  (define-values (in out) (tcp-accept listener))
  (logf "mcp-ui-tcp-proxy accepted tcp connection")
  (handle in out)
  (logf "mcp-ui-tcp-proxy closing tcp connection")
  (close-input-port in)
  (close-output-port out))

(define (forward-from-mcp-to-ui out)
  (lambda ()
    (let loop ((msg (read)))
      (logf "mcp-ui-tcp-proxy received message from mcp ~s\n" msg)
      (cond
        ((eof-object? msg)
         ;; TODO
         )
        (else
         ;; forward message to UI
         (write msg out)
         (flush-output-port out)
         (logf "mcp-ui-tcp-proxy forwarded message to ui ~s\n" msg)
         (loop (read)))))))

(define (forward-from-ui-to-mcp in)
  (let loop ((msg (read in)))
    (logf "mcp-ui-tcp-proxy received message from ui ~s\n" msg)
    (cond
      ((eof-object? msg)
       ;; TODO
       )
      (else
       ;; forward message to MCP
       (write msg)
       (flush-output-port)
       (logf "mcp-ui-tcp-proxy forwarded message to mcp ~s\n" msg)
       (loop (read in))))))

(define (handle in out)
  (logf "handle called for mcp-ui-tcp-proxy\n")
  (define mcp-to-ui-thread (thread (forward-from-mcp-to-ui out)))
  (forward-from-ui-to-mcp in)
  ;; perhaps should use a custodian for thread cleanup
  (kill-thread mcp-to-ui-thread))

(serve DEFAULT-TCP-PORT)
