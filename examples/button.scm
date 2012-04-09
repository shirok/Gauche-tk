;; simple button example

(use tk)

(tk-init '())
(tk-button '.b :text "Click me" :command (^[] (print "Yeah!")))
(tk-pack '.b)
(tk-mainloop)
