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
(goodbye)

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
(goodbye)

;--------------------
Received from SCP
;--------------------

;--------------------
Sent to SCP
;--------------------



;===================
SCP
;===================

;--------------------
Received from MCP
;--------------------
(synthesize ,def-inoutputs-synid)
(stop-all-synthesis)
(stop-one-task ,synthesis-id)
(ping)

;--------------------
Sent to MCP
;--------------------
(num-processes ,number-of-synthesis-subprocesses ,*scp-id*)
(synthesis-finished ,*scp-id* ,synthesis-id ,val ,statistics)
(ping)

;--------------------
Received from Synthesis subprocess
;--------------------
(ping)
(stopped)
;; error messages sent to SCP:
(unexpected-eof)
(unknown-message-type ,msg)

;--------------------
Sent to Synthesis subprocess
;--------------------
(ping)
(stop)
(synthesize (,definitions ,inputs ,outputs) ,synthesis-id)


;===================
Synthesis subprocess
;===================

;--------------------
Received from SCP
;--------------------
(ping)
(stop)
(synthesize (,definitions ,inputs ,outputs) ,synthesis-id)

;--------------------
Sent to SCP
;--------------------
(ping)
(stopped)
(synthesis-finished ,synthesis-id ,val ,statistics)
;; error messages sent to SCP:
(unexpected-eof)
(unknown-message-type ,msg)
