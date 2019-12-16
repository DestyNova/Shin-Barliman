; Shin-Barliman Sub Controlling Process (SCP)

(load "pmatch.scm")

#|
Description of the Sub Controlling Process.
----------------------------------------

The MCP is responsible for coordinating communication between the
user interface (UI) and the sub-processes responsible for synthesis.

The MCP is also responsible for the policies and strategies used for
efficient synthesis.
|#


;; (define RACKET-BINARY-PATH "/usr/local/bin/racket")
(define RACKET-BINARY-PATH "/Applications/Racket\\ v7.5/bin/racket")

(define CHEZ-BINARY-PATH "/usr/local/bin/scheme")
(define CHEZ-FLAGS "-q")

(define *program* (box #f))
(define *tests* (box #f))
(define *scm-files* (box #f))

(define *mcp-out-port-box* (box #f))
(define *mcp-in-port-box* (box #f))
(define *mcp-err-port-box* (box #f))
(define *mcp-pid-port-box* (box #f))

(define number-of-synthesis-subprocesses 3)
(define *synthesis-subprocesses-box* (box '()))


(define (check-for-mcp-messages)
  (printf "SCP checking for messages from MCP...\n")

  (when (input-port-ready? (unbox *mcp-err-port-box*))
    (let ((msg (read (unbox *mcp-err-port-box*))))
      (printf "SCP read error message ~s from MCP\n" msg)
      (cond
        ((eof-object? msg)
         (printf "FIXME do nothing ~s\n" msg))
        (else
         (pmatch msg
           [,anything
            (printf "FIXME do nothing ~s\n" msg)]))
        )))
  
  (when (input-port-ready? (unbox *mcp-in-port-box*))
    (let ((msg (read (unbox *mcp-in-port-box*))))
      (printf "SCP read message ~s from MCP\n" msg)
      (cond
        ((eof-object? msg)
         (printf "FIXME do nothing ~s\n" msg))
        (else
         (pmatch msg
           [,anything
            (printf "FIXME do nothing ~s\n" msg)]))
        )))
  )

(define (check-for-synthesis-subprocess-messages)
  (printf "SCP checking for messages from synthesis subprocesses...\n")
  (let loop ((synthesis-subprocesses (unbox *synthesis-subprocesses-box*)))
    (pmatch synthesis-subprocesses
      [()
       (printf "checked for all synthesis subprocesses messages\n")]
      [((synthesis-subprocess ,i ,process-id ,to-stdin ,from-stdout ,from-stderr)
        . ,rest)

       (when (input-port-ready? from-stderr)
         (let ((msg (read from-stderr)))
           (printf "SCP read error message ~s from synthesis subprocess ~s\n" msg i)
           (cond
             ((eof-object? msg)
              (printf "FIXME do nothing ~s\n" msg))
             (else
              (pmatch msg
                [,anything
                 (printf "FIXME do nothing ~s\n" msg)]))
             )))
       
       (when (input-port-ready? from-stdout)
         (let ((msg (read from-stdout)))
           (printf "SCP read message ~s from synthesis subprocess ~s\n" msg i)
           (cond
             ((eof-object? msg)
              (printf "FIXME do nothing ~s\n" msg))
             (else
              (pmatch msg
                [(synthesis-subprocess-ready)
                 (let ((expr '(* 3 4)))
                   (write `(eval-expr ,expr) to-stdin)
                   (flush-output-port to-stdin))]
                [,anything
                 (printf "FIXME do nothing ~s\n" msg)]))
             )))
       (loop rest)])))



; call tcp-client-for-subprocess.rkt
; TODO:
; (1) get & keep information from MCP via tcp-client-for-subprocess.
;     (*program*, *tests*, *scm-files*)


;; start synthesis subprocesses as soon as SCP starts
(printf "starting ~s synthesis subprocesses\n" number-of-synthesis-subprocesses)
(let loop ((i 0))
  (cond
    ((= i number-of-synthesis-subprocesses)
     (printf "started all ~s subprocesses\n" i))
    (else
     (let ((start-synthesis-subprocess-command
            (format "exec ~a ~a synthesis.scm" CHEZ-BINARY-PATH CHEZ-FLAGS)))
       (printf "starting synthesis subprocess with command:\n~s\n" start-synthesis-subprocess-command)
       (let-values ([(to-stdin from-stdout from-stderr process-id)
	             (open-process-ports start-synthesis-subprocess-command
		                         (buffer-mode block)
		                         (make-transcoder (utf-8-codec)))])
         (printf "started synthesis subprocesses ~s with process id ~s\n" i process-id)
         (set-box! *synthesis-subprocesses-box*
                   (append (unbox *synthesis-subprocesses-box*)
                           (list `(synthesis-subprocess ,i ,process-id ,to-stdin ,from-stdout ,from-stderr))))))
     (loop (add1 i)))))


;; start TCP proxy so SCP can communicate with MCP
(let ((start-tcp-proxy-command (format "exec ~a scp-tcp-proxy.rkt" RACKET-BINARY-PATH)))
  (printf "starting tcp proxy with command:\n~s\n" start-tcp-proxy-command)
  (let-values ([(to-stdin from-stdout from-stderr process-id)
	        (open-process-ports start-tcp-proxy-command
		                    (buffer-mode block)
		                    (make-transcoder (utf-8-codec)))])
    (printf "started tcp proxy with process id ~s\n" process-id)
    (set-box! *mcp-out-port-box* to-stdin)
    (set-box! *mcp-in-port-box* from-stdout)
    (set-box! *mcp-err-port-box* from-stderr)
    (set-box! *mcp-pid-port-box* process-id)))

; make subprocess
; (1) divide work to each subprocesses (create scm code? or MCP will send scm code?)
; (2) make subprocess & send information to subprocess
; (3) receive information from subprocess 
; Keeping simple: the number of subprocess will be two

(printf "synthesis-subprocesses list:\n~s\n" (unbox *synthesis-subprocesses-box*))

;; process messages
(let loop ()
  (check-for-mcp-messages)
  (check-for-synthesis-subprocess-messages)
  (loop))