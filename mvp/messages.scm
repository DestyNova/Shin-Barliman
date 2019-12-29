#|

Message types sent and received from UI, MCP, SCP, Synthesis subprocesses

|#

;===================
UI
;===================

;--------------------
Received from MCP
;--------------------
(synthesizing)
(stopped)

;--------------------
Sent to MCP
;--------------------
(synthesize (,definitions ,inputs ,outputs))
(stop)


;===================
MCP
;===================

;--------------------
Received from UI
;--------------------
(synthesize (,definitions ,inputs ,outputs))
(stop)

;--------------------
Sent to UI
;--------------------
(synthesizing)
(stopped)

;--------------------
Received from SCP
;--------------------
(hello) ;; ??? do we really need this message for the mvp?
(num-processes ,number-of-synthesis-subprocesses ,scp-id)
(synthesis-finished ,scp-id ,synthesis-id ,val ,statistics)
;; error messages sent to MCP (using error port):
(unexpected-eof) ;; ??? do we really need this message for the mvp?
(unknown-message-type ,msg) ;; ??? do we really need this message for the mvp?

;--------------------
Sent to SCP
;--------------------
(scp-id ,scp-id) ;; scp-id is an integer
(synthesize ((,definitions ,inputs ,outputs ,synthesis-id) ...))
(stop-all-synthesis)
(stop-one-task ,synthesis-id)


;===================
SCP
;===================

;--------------------
Received from MCP
;--------------------
(scp-id ,scp-id) ;; scp-id is an integer
(synthesize ((,definitions ,inputs ,outputs ,synthesis-id) ...))
(stop-all-synthesis)
(stop-one-task ,synthesis-id)
;; error messages sent to MCP (using error port):
(unexpected-eof) ;; ??? do we really need this message for the mvp?
(unknown-message-type ,msg) ;; ??? do we really need this message for the mvp?

;--------------------
Sent to MCP
;--------------------
(hello) ;; ??? do we really need this message for the mvp?
(num-processes ,number-of-synthesis-subprocesses ,scp-id)
(synthesis-finished ,scp-id ,synthesis-id ,val ,statistics)
;; error messages sent to MCP (using error port):
(unexpected-eof)
(unknown-message-type ,msg)

;--------------------
Received from Synthesis subprocess
;--------------------
(stopped-synthesis)
(synthesis-finished ,synthesis-id ,val ,statistics)
(status ,stat) ;; stat is either 'synthesizing or 'running
;; error messages sent to SCP (using error port):
(unexpected-eof)
(unknown-message-type ,msg)

;--------------------
Sent to Synthesis subprocess
;--------------------
(stop-synthesis)
(synthesize (,definitions ,inputs ,outputs) ,synthesis-id)
(get-status) ; when will we send this?


;===================
Synthesis subprocess
;===================

;--------------------
Received from SCP
;--------------------
(stop-synthesis)
(synthesize (,definitions ,inputs ,outputs) ,synthesis-id)
(get-status)

;--------------------
Sent to SCP
;--------------------
(stopped-synthesis)
(synthesis-finished ,synthesis-id ,val ,statistics)
(status ,stat) ;; stat is either 'synthesizing or 'running
;; error messages sent to SCP:
(unexpected-eof)
(unknown-message-type ,msg)
