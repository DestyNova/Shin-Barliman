#lang racket

;;; Racket port of the "Classic" Barliman GUI.

;;; Code adapted from the mediKanren Racket GUI
;;; (https://github.com/webyrd/mediKanren).

(require
  racket/gui/base
  framework
  ;racket/engine
  ;(except-in racket/match ==)
  )

(provide
  launch-gui)

(define CLASSIC_GUI_VERSION_STRING "Shin-Barliman Classic 4.3")

(displayln "Starting Shin-Barliman Classic...")
(displayln CLASSIC_GUI_VERSION_STRING)

;;; Initial window size
(define HORIZ-SIZE 1200)
(define VERT-SIZE 800)

(define *verbose* #t)

(define MAX_UNDO_DEPTH 1000)

(define MAX-CHAR-WIDTH 150)

(define TEXT-FIELD-FONT-SIZE 16)
(define TEXT-FIELD-FONT (make-font #:size TEXT-FIELD-FONT-SIZE))

(define DEFAULT-PROGRAM-TEXT "(define ,A\n  (lambda ,B\n    ,C))")

(define *current-focus-box* (box #f))
(define *tab-focus-order-box* (box '()))

(define smart-top-level-window%
 (class frame%
   (super-new)
   (define (on-subwindow-focus receiver on?)
     (if on?
         (set-box! *current-focus-box* receiver)
         (set-box! *current-focus-box* #f))
     (void))
   (define (on-traverse-char event)
     (let ((key-code (send event get-key-code)))
       (if (eqv? #\tab key-code)
           (let ((current-focus (unbox *current-focus-box*)))             
             (if current-focus
                 (let* ((tfo (unbox *tab-focus-order-box*))
                        (shift-down? (send event get-shift-down))
                        (tfo (if shift-down? (reverse tfo) tfo))
                        (o* (member current-focus tfo)))
                   (if o*
                       (send (cadr o*) focus)
                       #f))   
                 #f))
           #f)))
   (override on-traverse-char)
   (override on-subwindow-focus)))

(define (make-smart-text% name)
  (class racket:text%
    (super-new)
    (define (after-insert start len)
      (printf "Hello from ~s\n" name))
    (define (after-edit-sequence)
      (printf "after-edit-sequence called for ~s\n" name)
      (define str (send this get-text))
      (printf "text for ~s: ~s\n" name str)
      (define expr-in-list (with-handlers ([exn:fail? (lambda (exn)
                                                        (printf "exn for ~s: ~s\n" name exn)
                                                        'invalid-expression)])
                             (list (read (open-input-string str)))))
      (printf "~s expr-in-list: ~s\n" name expr-in-list)
      (when (pair? expr-in-list)
        (printf "~s raw expr: ~s\n" name (car expr-in-list)))
      (void))
    (augment after-insert)
    (augment after-edit-sequence)))



(define (launch-main-window)
  (let ((top-window (new smart-top-level-window%
                         (label CLASSIC_GUI_VERSION_STRING)
                         (width HORIZ-SIZE)
                         (height VERT-SIZE))))

    (define outermost-hor-draggable-panel (new panel:horizontal-dragable%
                                               (parent top-window)
                                               (alignment '(left center))
                                               (stretchable-height #t)))

    (define left-vert-draggable-panel (new panel:vertical-dragable%
                                           (parent outermost-hor-draggable-panel)
                                           (alignment '(left center))))

    (define right-panel (new vertical-pane%
                             (parent outermost-hor-draggable-panel)
                             (alignment '(left top))
                             (stretchable-height #f)))

    (define left-top-panel (new vertical-pane%
                                (parent left-vert-draggable-panel)
                                (alignment '(left center))))

    (define left-bottom-panel (new vertical-pane%
                                   (parent left-vert-draggable-panel)
                                   (alignment '(left center))))
    
    (define definitions-message (new message%
                                     (parent left-top-panel)
                                     (label "Definitions")))
    
    (define definitions-editor-canvas (new editor-canvas%
                                           (parent left-top-panel)
                                           (label "Definitions")))
    (define definitions-text (new (make-smart-text% 'definitions)))
    (send definitions-text insert DEFAULT-PROGRAM-TEXT)
    (send definitions-editor-canvas set-editor definitions-text)
    (send definitions-text set-max-undo-history MAX_UNDO_DEPTH)




    (define best-guess-message (new message%
                                    (parent left-bottom-panel)
                                    (label "Best Guess")))
    
    (define best-guess-editor-canvas (new editor-canvas%
                                          (parent left-bottom-panel)
                                          (label "Best Guess")
					  (enabled #f)))
    (define best-guess-text (new (make-smart-text% 'best-guess)))
    (send best-guess-text insert "")
    (send best-guess-editor-canvas set-editor best-guess-text)


    
    (define (make-test-message/expression/value n parent-panel)

      (define (make-test-editor-canvas n parent-panel format-str)
        (define test-editor-canvas (new editor-canvas%
                                        (parent parent-panel)))
        (define test-text (new (make-smart-text%
                                 (string->symbol
                                   (format format-str n)))))
        (send test-editor-canvas set-editor test-text)
        (send test-text set-max-undo-history MAX_UNDO_DEPTH)

        test-editor-canvas)
      
      (define test-message (new message%
                                (parent parent-panel)
                                (label (format "Test ~s" n))))

      (define test-expression-editor-canvas
        (make-test-editor-canvas n parent-panel "test-expression-~s"))
      (define test-value-editor-canvas
        (make-test-editor-canvas n parent-panel "test-value-~s"))
      
      (list test-message test-expression-editor-canvas test-value-editor-canvas))


    (define test-1-message/expression/value (make-test-message/expression/value 1 right-panel))
    (define test-1-message (car test-1-message/expression/value))
    (define test-expression-1-editor-canvas (cadr test-1-message/expression/value))
    (define test-value-1-editor-canvas (caddr test-1-message/expression/value))

    (define test-2-message/expression/value (make-test-message/expression/value 2 right-panel))
    (define test-2-message (car test-2-message/expression/value))
    (define test-expression-2-editor-canvas (cadr test-2-message/expression/value))
    (define test-value-2-editor-canvas (caddr test-2-message/expression/value))

    (define test-3-message/expression/value (make-test-message/expression/value 3 right-panel))
    (define test-3-message (car test-3-message/expression/value))
    (define test-expression-3-editor-canvas (cadr test-3-message/expression/value))
    (define test-value-3-editor-canvas (caddr test-3-message/expression/value))

    (define test-4-message/expression/value (make-test-message/expression/value 4 right-panel))
    (define test-4-message (car test-4-message/expression/value))
    (define test-expression-4-editor-canvas (cadr test-4-message/expression/value))
    (define test-value-4-editor-canvas (caddr test-4-message/expression/value))

    (define test-5-message/expression/value (make-test-message/expression/value 5 right-panel))
    (define test-5-message (car test-5-message/expression/value))
    (define test-expression-5-editor-canvas (cadr test-5-message/expression/value))
    (define test-value-5-editor-canvas (caddr test-5-message/expression/value))

    (define test-6-message/expression/value (make-test-message/expression/value 6 right-panel))
    (define test-6-message (car test-6-message/expression/value))
    (define test-expression-6-editor-canvas (cadr test-6-message/expression/value))
    (define test-value-6-editor-canvas (caddr test-6-message/expression/value))

    
    (define tabbable-items
      (list
        definitions-editor-canvas
        ;;
        test-expression-1-editor-canvas
        test-value-1-editor-canvas
        ;;
        test-expression-2-editor-canvas
        test-value-2-editor-canvas
        ;;
        test-expression-3-editor-canvas
        test-value-3-editor-canvas
        ;;
        test-expression-4-editor-canvas
        test-value-4-editor-canvas
        ;;
        test-expression-5-editor-canvas
        test-value-5-editor-canvas
        ;;
        test-expression-6-editor-canvas
        test-value-6-editor-canvas
        ))

    (define wrappable-tabbable-items
      (append
        ;; wrap around (reverse)
       (list (car (reverse tabbable-items)))
       tabbable-items
       ;; wrap around (forward)
       (list (car tabbable-items))))
    
    (set-box! *tab-focus-order-box* wrappable-tabbable-items)

    ;; trigger reflowing of object sizes
    (send top-window reflow-container)
    
    (send top-window show #t)
    (send definitions-editor-canvas focus)
    ))


(define (launch-gui)
  (launch-main-window))

(displayln
  "Launching GUI")

(launch-gui)
