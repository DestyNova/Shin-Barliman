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


(define RACKET-BINARY-PATH "/usr/local/bin/racket")
;;(define RACKET-BINARY-PATH "/Applications/Racket\\ v7.5/bin/racket")

(define CHEZ-BINARY-PATH "/usr/local/bin/scheme")
(define CHEZ-FLAGS "-q")

(define *program* (box #f))
(define *tests* (box #f))
(define *scm-files* (box #f))

(define *mcp-out-port-box* (box #f))
(define *mcp-in-port-box* (box #f))
(define *mcp-err-port-box* (box #f))
(define *mcp-pid-port-box* (box #f))

; Currently this number is fixed
(define number-of-synthesis-subprocesses 3)

(define *synthesis-subprocesses-box* (box '()))
; *synthesis-subprocesses-box* is the following
; (list `(synthesis-subprocess ,i ,process-id ,to-stdin ,from-stdout ,from-stderr ,status))
;; status is 'free or 'working

(define *scp-id* #f)
(define *synthesis-task-table* '())
; *synthesis-task-table* is the following
; ((,synthesis-id ,subprocess-id ,definitions ,examples ,status) . ,rest)
; status is only 'started (now)

(define *task-queue* '())
; ((,definitions ,inputs ,outputs ,synthesis-id) ...)
; This should be the same structure with the data that MCP sends.

; send number-of-synthesis-subprocesses to MCP
(define (send-number-of-subprocess-to-mcp)
  (let ((out (unbox *mcp-out-port-box*)))
    (write `(num-processes ,number-of-synthesis-subprocesses ,*scp-id*) out)
    (flush-output-port out)))

; send synthesis-finished message to MCP
(define (send-synthesis-finished-to-mcp synthesis-id val statistics)
  (let ((out (unbox *mcp-out-port-box*)))
    (write `(synthesis-finished ,*scp-id* ,synthesis-id ,val ,statistics) out)
    (flush-output-port out)))

; check messages from MCP
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
           [(unexpected-eof)
            (printf "SCP receive unexpected EOF from MCP\n")
            ]
           [(unknown-message-type ,msg)
            (printf "SCP receive unknown error message ~s from MCP\n" msg)
            ]
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
           [(scp-id ,scp-id)
            ; receive scp-id from MCP, keep it in *scp-id* and 
            ; send number-of-subprocess (Sent to MCP)
            (set! *scp-id* scp-id)
            (send-number-of-subprocess-to-mcp)
            ]
           [(synthesize ,def-inoutputs-synid)
            ; receive synthesize message from MCP
            ; add them to *task-queue* 
            (set! *task-queue* (append *task-queue* def-inoutputs-synid))
            ; and start synthesis if here are free subprocesses
            (start-synthesis-with-free-subprocesses)
            ]
           [(stop-all-synthesis)
            ; receive stop-all-synthesis message from MCP
            ; empty *task-queue*
            (set! *task-queue* '())
            ; stop all subprocesses
            (stop-all-subprocess)]
           [(stop-one-task ,synthesis-id)
            ; receive sto-one-task message from MCP
            ; stop the task with synthesis-id
            (stop-one-task synthesis-id)]
           [,anything
            (printf "FIXME do nothing ~s\n" msg)]))
        )))
  )

(define (start-synthesis-with-free-subprocesses)
  (let loop ((synthesis-subprocesses (unbox *synthesis-subprocesses-box*)))
    (pmatch synthesis-subprocesses
      [()
       (printf "started synthesis with all free synthesis subprocesses\n")]
      [((synthesis-subprocess ,i ,process-id ,to-stdin ,from-stdout ,from-stderr free)
        . ,subprocess-rest)
       (pmatch *task-queue*
         [() (printf "there is no more job in *task-queue*\n")]
         [((,definitions ,inputs ,outputs ,synthesis-id) . ,rest)
          (printf "there is at least one job\n")
          (write `(synthesize (,definitions ,inputs ,outputs) ,synthesis-id) to-stdin)
          (flush-output-port to-stdin)
          ; update subprocess status to working
          (update-status 'working process-id)
          (printf "Process-id ~s started working\n" process-id)
          ; for debugging:                              ;
          ; (printf "~s\n" (unbox *synthesis-subprocesses-box*))
          (set! *task-queue* rest)
          (set! *synthesis-task-table* (cons `(,synthesis-id ,process-id ,definitions ,inputs ,outputs started) *synthesis-task-table*))
          (loop subprocess-rest)
          ])
       ]
      [((synthesis-subprocess ,i ,process-id ,to-stdin ,from-stdout ,from-stderr working)
        . ,rest)
       (loop rest)
       ])))

; 'working -> 'free / 'free -> 'working
(define (opposite status)
  (cond ((equal? status 'working) 'free)
        ((equal? status 'free) 'working)
        (else (printf "opposite: status error"))))


(define (update-status-aux status id)
  (let loop ((synthesis-subprocesses (unbox *synthesis-subprocesses-box*)))
    (pmatch synthesis-subprocesses
      [()
       (printf "tried update-status-to ~s, but the given id ~s is not found\n" status id)
       '()]
      [((synthesis-subprocess ,i ,process-id ,to-stdin ,from-stdout ,from-stderr ,current-status)
        . ,rest)
       (cond
        ((equal? process-id id)
         (cond ((equal? status current-status) ; if status = current-status
                (printf "tried update-status-to ~s, but ~s is already ~s\n" status process-id current-status)
                (cons `(synthesis-subprocess ,i ,process-id ,to-stdin ,from-stdout ,from-stderr ,current-status) rest))
               ((equal? status (opposite current-status)) ; if status <> current-status
                (printf "update-status-to ~s: updated! id = ~s\n" (opposite current-status) process-id)
                (cons `(synthesis-subprocess ,i ,process-id ,to-stdin ,from-stdout ,from-stderr ,(opposite current-status)) rest))
               (else (printf "status error"))))
        (else (cons `(synthesis-subprocess ,i ,process-id ,to-stdin ,from-stdout ,from-stderr ,current-status) (loop rest))))
       ])))

(define (update-status status id)
  (set-box! *synthesis-subprocesses-box* (update-status-aux status id)))

; remove the given id from synthesis-subprocesses
(define (remove-subprocess-from-box-aux id synthesis-subprocesses)
  (pmatch synthesis-subprocesses
    [()
     (printf "remove-subprocess-from-box-aux checked all, but id ~s can not be could.\n" process-id)
     '()]
    [((synthesis-subprocess ,i ,process-id ,to-stdin ,from-stdout ,from-stderr ,status)
      . ,rest)
     (cond ((equal? process-id id)
            rest)
           (else (cons `(synthesis-subprocess ,i ,process-id ,to-stdin ,from-stdout ,from-stderr ,status) (remove-subprocess-from-box-aux id rest))))]))                                                                          
(define (remove-subprocess-from-box id)
  (set-box! *synthesis-subprocesses-box* (remove-subprocess-from-box-aux id (unbox *synthesis-subprocesses-box*))))


(define (check-for-synthesis-subprocess-messages)
  (printf "SCP checking for messages from synthesis subprocesses...\n")
  (let loop ((synthesis-subprocesses (unbox *synthesis-subprocesses-box*)))
    (pmatch synthesis-subprocesses
      [()
       (printf "checked for all synthesis subprocesses messages\n")]
      [((synthesis-subprocess ,i ,process-id ,to-stdin ,from-stdout ,from-stderr ,status)
        . ,rest)
       (when (input-port-ready? from-stderr)
         (let ((msg (read from-stderr)))
           (printf "SCP read error message ~s from synthesis subprocess ~s\n" msg i)
           (cond
             ((eof-object? msg)
              (printf "FIXME do nothing ~s\n" msg))
             (else
              (pmatch msg
                [(unexpected-eof)
                 (printf "SCP receive unexpected EOF from subprocess\n")]
                [(unknown-message-type ,msg)
                 (printf "SCP receive error message ~s from subprocess\n" msg)]
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
                 ; TODO?: what SCP should do after receiving this message?
                 ; when subprocesses send this message?
                 (update-status 'free process-id)
                 ; (let ((expr '(* 3 4)))
                 ;   (write `(eval-expr ,expr) to-stdin)
                 ;   (flush-output-port to-stdin))
                 ]
                [(stopped)
                 (printf "SCP received stop message from ~s\n" process-id)
                 ; remove this process-id from *synthesis-subprocesses-box*
                 (remove-subprocess-from-box process-id)
                 ]
                [(synthesis-finished ,synthesis-id ,val ,statistics)
                 (printf "SCP received synthesis-finished message from ~s\n" synthesis-id)
                 ; Sent to MCP:
                 (send-synthesis-finished-to-mcp synthesis-id val statistics)
                 ; update the status and start working with the free subprocesses
                 (update-status 'free process-id)
                 (start-synthesis-with-free-subprocesses)
                ]
                [(status ,stat)
                 ; TODO?: what SCP should do after receiving this status message?
                 (printf "SCP received status message ~s from ~s\n" stat process-id)]
                [,anything
                 (printf "FIXME do nothing ~s: anything\n" msg)]))
             )))
       (loop rest)])))


(define (stop-all-subprocess)
  (let loop ((synthesis-subprocesses (unbox *synthesis-subprocesses-box*)))
    (pmatch synthesis-subprocesses
      [() (printf "stopped all synthesis subprocesses\n")]
      [((synthesis-subprocess ,i ,process-id ,to-stdin ,from-stdout ,from-stderr ,status)
        . ,rest)
       (write `(stop) to-stdin)
       (flush-output-port to-stdin)
       (loop rest)])))

; apply func to (each element of the lst) and
; divide them ((positive-ones) (negative-ones))
; e.g., (partition (lambda (x) (equal? x 2)) (list 2 3 2 4 5)) =>
; ((2 2) (3 4 5))
(define (partition func lst)
  ; for debugging:
   (printf "partition: ~s\n" lst)
   (pmatch lst
     [() '()]
     [(()) `(() ())]
     [(,a)
      (if (func a)
          `(((,a)) ())
          `(() (,a)))]
     [(,a . ,rest)
      (let ((result (partition func rest)))
       ; for debugging:
        (printf "result: ~s\n" result)
        (pmatch result
          [(,b . (,c))
           (if (func a)
               `(,(cons a b) ,c)
               `(,b ,(cons a c)))]))
      ]))

(define (searching-subprocess-out lst id)
  (pmatch lst
    [() (printf "Searching-subprocess-out: there is no subprocess id ~s\n" id)]
    [((synthesis-subprocess ,i ,process-id ,to-stdin ,from-stdout ,from-stderr ,status)
      . ,rest)
     (if (equal? id process-id)
           to-stdin
           (searching-subprocess-out rest id))]
    ))

(define (stop-running-one-task id)
  ; find the information in systhesis table and quit that job
  ; for debugging:
  (printf "task-table:~s\n" *synthesis-task-table*)
  (pmatch *synthesis-task-table*
    [() (printf "Error :received id is not found in synthesis table\n")]
    [,else 
     (let ((lst (partition (lambda (x) (equal? id (car (cdr x)))) *synthesis-task-table*)))
       ; for debugging
       (printf "Partition: ~s\n" lst)
       (pmatch lst
         [(() . ,rest)
         ; the id is not found in the table
          (printf "stop-runnning-one-task: received id is not found in queue and task table\n")
          ]
         [(((,synthesis-id ,subprocess-id ,definitions ,inputs ,outputs ,status)). ,rest)
          ; the id is found in the table
          (set! *synthesis-task-table* rest)
          (printf "ID ~s found!\n" subprocess-id)
          (let ((out (searching-subprocess-out (unbox *synthesis-subprocesses-box*) id)))
            (write `(stop) out)
            (flush-output-port out)
            (printf "Sent stop to id ~s\n" subprocess-id)
            (set! *synthesis-task-table* rest))
       ; TODO?: shall we start another process?      
       ]))]))

(define (stop-one-task id)
  ; in the case, that task is in the queue
  (let ((lst (partition (lambda (x) (equal? id (car (cdr (cdr (cdr x)))))) *task-queue*)))
    (pmatch lst
      [()
       ; the id is not found in the queue
       (stop-running-one-task id)
       ]
      [(,a . ,rest)
       ; the id is found in the queue
       (set! *task-queue* rest)])))


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


(printf "synthesis-subprocesses list:\n~s\n" (unbox *synthesis-subprocesses-box*))


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
                           (list `(synthesis-subprocess ,i ,process-id ,to-stdin ,from-stdout ,from-stderr free))))))
     (loop (add1 i)))))




#!eof

;; process messages
(let loop ()
  (check-for-mcp-messages)
  (check-for-synthesis-subprocess-messages)
  (loop))
