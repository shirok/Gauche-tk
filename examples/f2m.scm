;;
;; An example on http://www.tkdocs.com/tutorial/firstexample.html
;;

(use tk)

(define (calculate)
  (if-let1 feet (string->number (tk-ref "::feet"))
    (tk-set! "::meters" (/ (round (* feet 0.3048 10000.0)) 10000.0))
    (tk-set! "::meters" "")))

(define (main args)
  (tk-init '())

  (tk-wm 'title "." "Feet to Meters")
  (tk-grid (tk-frame '.c :padx 12 :pady 3) :column 0 :row 0 :sticky 'nwes)
  (tk-grid 'columnconfigure "." 0 :weight 1)
  (tk-grid (tk-entry '.c.feet :width 7 :textvariable 'feet) :column 2 :row 1 :sticky 'we)
  (tk-grid (tk-label '.c.meters :textvariable 'meters) :column 2 :row 2 :sticky 'we)
  (tk-grid (tk-button '.c.calc :text "Calculate" :command calculate) :column 3 :row 3 :sticky 'w)
  (tk-grid (tk-label '.c.flbl :text "feet") :column 3 :row 1 :sticky 'w)
  (tk-grid (tk-label '.c.islbl :text "is equivalent to") :column 1 :row 2 :sticky 'e)
  (tk-grid (tk-label '.c.mlbl :text "meters") :column 3 :row 2 :sticky 'w)

  (dolist [w (tk-parse-list (tk-winfo 'children '.c))]
    (tk-grid 'configure w :padx 5 :pady 5))
  (tk-focus '.c.feet)
  (tk-bind "." '<Return> calculate)

  (tk-mainloop)
  0)
