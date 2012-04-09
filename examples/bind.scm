;; binding event callback

(use tk)

(tk-init '())
(tk-bind "." '<Key>      (tklambda (%K) (print #`"Pressed ,%K")))
(tk-bind "." '<Button-1> (tklambda (%x %y) (print #`"Clicked at (,%x ,%y)")))
(tk-mainloop)
