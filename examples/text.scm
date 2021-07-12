;; Text widget example.
(use file.util)
(use tk)

(define *current-file* #f)

(define (set-current-file! file)
  (set! *current-file* file)
  (tk-wm 'title "." (or file "(Untitled)")))

(define (newfile)
  (set-current-file! #f)
  (tk-call '.t 'delete "1.0" 'end))

(define (openfile)
  (let1 path (tk-getOpenFile)
    (unless (equal? path "")
      (tk-call '.t 'delete "1.0" 'end)
      (tk-call '.t 'insert 'end (file->string path))
      (set-current-file! path))))

(define (commitfile :optional (path *current-file*))
  (if (not path)
    (saveasfile)
    (let1 data (tk-call '.t 'get "1.0" 'end)
      (with-output-to-file path (cut display data)))))

(define (saveasfile)
  (let1 path (tk-getSaveFile :initialfile (or *current-file* ""))
    (unless (equal? path "")
      (set-current-file! path)
      (commitfile path))))

(define (quit)
  (tk-shutdown)
  (exit 0))

(define (main args)
  (tk-init '())
  ;; Menu
  (tk-menu '.m :type 'menubar :bd 1)
  (tk-call '.m 'add 'cascade :label "File" :menu '.m.f :underline 0)
  (tk-menu '.m.f :tearoff 0 :bd 1)
  (tk-call '.m.f 'add 'command :label "New" :underline 0 :command newfile)
  (tk-call '.m.f 'add 'command :label "Open..." :underline 0 :command openfile)
  (tk-call '.m.f 'add 'command :label "Save" :underline 0 :command commitfile)
  (tk-call '.m.f 'add 'command :label "Save as..." :underline 5 :command saveasfile)
  (tk-call '.m.f 'add 'separator)
  (tk-call '.m.f 'add 'command :label "Quit" :underline 0 :command quit)

  ;; Textarea
  (tk-text '.t :bd 1)

  (tk-pack '.m :expand 1 :fill 'x)
  (tk-pack '.t :expand 1 :fill 'both)
  (tk-tk 'appname "Edit")
  (tk-mainloop)
  0)
