;;;
;;; Simple Tk binding
;;;
;;; Copyright (c) 2012  Shiro Kawai  <shiro@acm.org>
;;;
;;; Redistribution and use in source and binary forms, with or without
;;; modification, are permitted provided that the following conditions
;;; are met:
;;;
;;;  1. Redistributions of source code must retain the above copyright
;;;     notice, this list of conditions and the following disclaimer.
;;;
;;;  2. Redistributions in binary form must reproduce the above copyright
;;;     notice, this list of conditions and the following disclaimer in the
;;;     documentation and/or other materials provided with the distribution.
;;;
;;;  3. Neither the name of the authors nor the names of its contributors
;;;     may be used to endorse or promote products derived from this
;;;     software without specific prior written permission.
;;;
;;; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
;;; "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
;;; LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
;;; A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
;;; OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
;;; SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
;;; TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
;;; PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
;;; LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
;;; NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
;;; SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

(define-module tk
  (use gauche.process)
  (use gauche.threads)
  (use gauche.parameter)
  (use gauche.generator)
  (use gauche.sequence)
  (use file.util)
  (use text.tree)
  (use util.list)
  (use util.match)
  (use parser.peg)
  (use srfi-13)
  (export wish-path <tk-error> do-tk tk-parse-list tk-ref tk-set!
          tk-init tk-shutdown tk-mainloop tklambda

          define-tk-command
          tk-bell tk-bind tk-bindtags tk-bitmap tk-button tk-canvas
          tk-checkbutton tk-clipboard tk-colors tk-console tk-cursors
          tk-destory tk-entry tk-event tk-focus tk-font tk-frame tk-grab
          tk-grid tk-image tk-keysyms tk-label tk-labelframe tk-listbox
          tk-lower tk-menu tk-menubutton tk-option tk-options tk-pack
          tk-panedwindow tk-photo tk-place tk-radiobutton tk-raise
          tk-scale tk-scorllbar tk-selection tk-send tk-spinbox tk-text
          tk-tk tk-bisque tk-chooseColor tk-chooseDirectory tk-dialog
          tk-focusFollowsMouse tk-focusNext tk-focusPrev tk-getOpenFiel
          tk-getSaveFile tk-menuSetFocus tk-messageBox tk-optionMenu
          tk-popup tk-setPalette tk-textCopy tk-textCut tk-textPaste
          tk-tkerror tk-tkvars tk-tkwait tk-toplevel tk-winfo tk-wm))
(select-module tk)

;; This module enables Gauche programs to use Tk toolkit.  For the
;; simplicity, we run a 'wish' process (an interactive shell of Tcl/Tk)
;; and talk to it via pipe, instead of linking Tcl/Tk library.
;;
;; We don't provide any fancy wrapper---Tcl deals with strings, and
;; that's mostly what you see from Scheme.  An exception is Scheme
;; closures for callbacks---we can't pass Scheme closures to Tcl,
;; so we register it to a table and pass a dummy Tcl code fragment
;; to Tcl.  When the code is kicked, our mainloop calls corresponding
;; Scheme closure.
;;
;; The communication is asynchronous, since callbacks can be invoked
;; at any time.  We use stdout to receive synchronous response, while
;; use stderr to receive callback triggers.
;;
;; The callback closure is registered in the callback table (ctab), and
;; assigned a unique callback ID.  In the Tcl side, a dummy command is
;; registered, which prints out the callback ID to stderr.  The event
;; loop in the Gauche side reads it and invokes appropriate callbacks.
;;
;; Currently we don't garbage-collect ctab.  It will be a problem if
;; you swap registered callbacks too often---if you need to change the
;; behavior of a widget, it's better to handle it in the Scheme side.

;;
;; Global parameters
;;

;; API
(define wish-path
  (make-parameter (find-file-in-paths "wish")))

(define *wish*       ;(<process> <callback-table>)
  (atom #f (make-hash-table 'eqv?)))

;; set this #t to dump communication with wish
(define *tk-debug* #f)

;;;
;;; Communication layer
;;;

;; API
(define-condition-type <tk-error> <error> #f)

;; wrap response from wish
(define (wish-initialize tkproc)
  (display "proc gauche__tk__do args {\n\
              set r [catch {eval $args} gauche__tk__result]  \n\
              set lines [split $gauche__tk__result \"\\n\"]  \n\
              if { $r == 0 || $r == 2 } {                    \n\
                puts \"ok\"                                  \n\
              } {                                            \n\
                puts \"error\"                               \n\
              }                                              \n\
              foreach l $lines {                             \n\
                puts -nonewline \";\"                        \n\
                puts $l                                      \n\
              }                                              \n\
              puts \"end\"                                   \n\
            }\n" (process-input tkproc))
  (display "proc gauche__tk__callback args {\n\
              puts stderr $args             \n\
            }\n" (process-input tkproc))
  (display "proc gauche__tk__varref {name} {                 \n\
              if {[info exists $name]} {                     \n\
                upvar $name x                                \n\
                return $x                                    \n\
              } {                                            \n\
                error \"no such variable: $name\"            \n\
              }                                              \n\
            }\n" (process-input tkproc))
  (flush (process-input tkproc)))

(define (tk-debug fmt . args)
  (when *tk-debug*
    (apply format (current-error-port) fmt args)))

;; we wrap Scheme procedure by <tk-callback>
(define-class <tk-callback> ()
  ((id)
   (proc     :init-keyword :proc)
   (substs   :init-keyword :substs :init-value '())
   (id-counter :allocation :class :init-value (atom 0))))

(define-method initialize ((c <tk-callback>) initargs)
  (next-method)
  (set! (~ c'id) (atomic-update! (~ c'id-counter) (cut + <> 1))))

;; Scheme object -> Tcl object
(define-method encode ((x <keyword>)) #`"-,x") ;; :foo => -foo
(define-method encode ((x <boolean>)) (if x "1" "0"))
(define-method encode ((x <string>))  (format "~s" x))
(define-method encode ((x <list>)) `("{",@(intersperse " "(map encode x))"}"))
(define-method encode ((x <tk-callback>))
  `("\"gauche__tk__callback ",(x->integer (~ x'id))
    " ",@(intersperse " "(map x->string (~ x'substs)))"\""))
(define-method encode ((x <top>)) (x->string x))

(define (send-to-wish tkproc ctab args)
  (let1 s (tree->string
           `("gauche__tk__do " ,(intersperse " "(map encode args))"\n"))
    (tk-debug "> ~a" s)
    (display s (process-input tkproc)))
  (let* ([gen (cute read-line (process-output tkproc))]
         [status (gen)]
         [results (string-join ($ map (cut string-drop <> 1) $ generator->list
                                  $ gtake-while (^s (not (equal? s "end"))) gen)
                               "\n")])
    (tk-debug "< ~a\n~a\n" status results)
    (if (equal? status "ok")
      (begin
        (dolist [cb (filter (cut is-a? <> <tk-callback>) args)]
          (hash-table-put! ctab (~ cb'id) cb))
        (rxmatch-case results
          [#/^gauche__tk__callback (\d+)/ (_ n)
           (if-let1 cb (hash-table-get ctab (x->integer n) #f)
             (~ cb'proc)
             (error <tk-error> "Stray callback" results))]
          [else results]))
      (error <tk-error> results))))

;; API
(define (do-tk command)
  (let1 args (map (^c (if (procedure? c)
                        (make <tk-callback> :proc c)
                        c))
                  command)
    (atomic *wish* (^[p c] (send-to-wish p c args)))))

;; API
;;  Turn string representation of Tcl list to Scheme list
;;  Tcl has two kind of quoting characters, so we can't do a simple
;;  string-split.
(define (tk-parse-list string)
  (peg-parse-string %tk-list string))

;; NB: parser.peg is unofficial and their API may be changed at any time;
;; these code will need to be rewritten in such a case.
(define %tk-word ($->rope ($many1 ($or ($one-of #[^\\\s\{\}])
                                       ($seq ($char #\\) anychar)))))
(define %tk-braced ($between ($char #\{) ($lazy %tk-list) ($char #\})))
(define %tk-quoted ($between ($char #\")
                             ($->rope ($many ($or ($one-of #[^\\\"])
                                                  ($seq ($char #\\) anychar))))
                             ($char #\")))
(define %tk-term ($between ($skip-many ($one-of #[\s]))
                           ($or %tk-braced %tk-quoted %tk-word)
                           ($skip-many ($one-of #[\s]))))
(define %tk-list ($many %tk-term))

;; API
(define (tk-ref var) (do-tk `(gauche__tk__varref ,var)))
;; API
(define (tk-set! var val) (do-tk `(set ,var ,val)))

;; API
(define-syntax tklambda
  (syntax-rules ()
    [(_ (formals ...) body ...)
     (make <tk-callback>
       :proc (lambda (formals ...) body ...)
       :substs '(formals ...))]))
     

;;;
;;; Initialization and main loop
;;;

;; API
(define (tk-init argv)
  (unless (wish-path)
    (error "cannot find `wish' binary.  Set the parameter `wish-path'"))
  (atomic-update! *wish*
                  (^[p c]
                    (when p (error "tk is already initialized"))
                    (let1 p (run-process `(,(wish-path) ,@argv)
                                         :input :pipe :output :pipe
                                         :error :pipe)
                      (wish-initialize p)
                      (values p c))))
  #t)

;; API
(define (tk-shutdown)
  (atomic-update! *wish*
                  (^[p c]
                    (when p
                      (display "exit\n" (process-input p))
                      (close-output-port (process-input p))
                      (process-wait p))
                    (values #f (make-hash-table 'eqv?))))
  #t)

;; API
;;   Returns when the pipe is closed (= when wish exits)
(define (tk-mainloop :key (background #f))
  (define (mainloop)
    (let1 port (process-error (atom-ref *wish* 0))
      (let loop ([msg (read-line port)])  ;this blocks
        (when (string? msg)
          (tk-debug "! ~a\n" msg)
          (let* ([items (string-split msg #[\s])]
                 [cnum  (string->number (car items))])
            (if cnum
              (if-let1 cb (atomic *wish* (^[p c] (hash-table-get c cnum #f)))
                (guard (e [else (tk-bgerror "~a" (~ e'message))])
                  (apply (~ cb'proc) (cdr items)))
                (tk-bgerror "bogus callback: ~a" msg))
              (tk-bgerror "~a" msg)))
          (loop (read-line port))))))
  (if background
    (thread-start! (make-thread mainloop))
    (mainloop)))

;; Background error handler.
;; TODO: Make this customizable!
(define (tk-bgerror fmt . args)
  (apply format (current-error-port) #`"TK Error: ,fmt" args))

;;;
;;; For the convenience
;;;

(define-syntax define-tk-command
  (syntax-rules ()
    [(_ name tkname)
     (define (name . args)
       (do-tk (cons 'tkname args)))]))
(define-syntax define-tk-commands
  (syntax-rules ()
    [(_ (name tkname) ...)
     (begin (define-tk-command name tkname) ...)]))

(define-tk-commands
  (tk-bell bell)
  (tk-bind bind)
  (tk-bindtags bindtags)
  (tk-bitmap bitmap)
  (tk-button button)
  (tk-canvas canvas)
  (tk-checkbutton checkbutton)
  (tk-clipboard clipboard)
  (tk-colors colors)
  (tk-console console)
  (tk-cursors cursors)
  (tk-destory destroy)
  (tk-entry entry)
  (tk-event event)
  (tk-focus focus)
  (tk-font font)
  (tk-frame frame)
  (tk-grab grab)
  (tk-grid grid)
  (tk-image image)
  (tk-keysyms keysyms)
  (tk-label label)
  (tk-labelframe labelframe)
  (tk-listbox listbox)
  (tk-lower lower)
  (tk-menu menu)
  (tk-menubutton menubutton)
  (tk-option option)
  (tk-options options)
  (tk-pack pack)
  (tk-panedwindow panedwindow)
  (tk-photo photo)
  (tk-place place)
  (tk-radiobutton radiobutton)
  (tk-raise raise)
  (tk-scale scale)
  (tk-scorllbar scrollbar)
  (tk-selection selection)
  (tk-send send)
  (tk-spinbox spinbox)
  (tk-text text)
  (tk-tk tk)
  (tk-bisque tk_bisque)
  (tk-chooseColor tk_chooseColor)
  (tk-chooseDirectory tk_chooseDirectory)
  (tk-dialog tk_dialog)
  (tk-focusFollowsMouse tk_focusFollowsMouse)
  (tk-focusNext tk_focusNext)
  (tk-focusPrev tk_focusPrev)
  (tk-getOpenFiel tk_getOpenFile)
  (tk-getSaveFile tk_getSaveFile)
  (tk-menuSetFocus tk_menuSetFocus)
  (tk-messageBox tk_messageBox)
  (tk-optionMenu tk_optionMenu)
  (tk-popup tk_popup)
  (tk-setPalette tk_setPalette)
  (tk-textCopy tk_textCopy)
  (tk-textCut tk_textCut)
  (tk-textPaste tk_textPaste)
  (tk-tkerror tkerror)
  (tk-tkvars tkvars)
  (tk-tkwait tkwait)
  (tk-toplevel toplevel)
  (tk-winfo winfo)
  (tk-wm wm))
  
