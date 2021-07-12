;;;
;;; Test Gauche-tk
;;;

(use gauche.test)

(test-start "tk")
(use tk)
(test-module 'tk)

;; TODO: more tests

(test-section "tk-parse-list")
(define *tk-string-source*
  "{-activebackground activeBackground Foreground #ececec #ececec} {-activeforeground activeForeground Background #000000 #000000} {-anchor anchor Anchor center center} {-background background Background #d9d9d9 #d9d9d9} {-bd -borderwidth} {-bg -background} {-bitmap bitmap Bitmap {} {}} {-borderwidth borderWidth BorderWidth 2 2} {-command command Command {} {}} {-compound compound Compound none none} {-cursor cursor Cursor {} {}} {-default default Default disabled disabled} {-disabledforeground disabledForeground DisabledForeground #a3a3a3 #a3a3a3} {-fg -foreground} {-font font Font {Helvetica -12 bold} {Helvetica -12 bold}} {-foreground foreground Foreground #000000 #000000} {-height height Height 0 0} {-highlightbackground highlightBackground HighlightBackground #d9d9d9 #d9d9d9} {-highlightcolor highlightColor HighlightColor #000000 #000000} {-highlightthickness highlightThickness HighlightThickness 1 1} {-image image Image {} {}} {-justify justify Justify center center} {-overrelief overRelief OverRelief {} {}} {-padx padX Pad 3m 3m} {-pady padY Pad 1m 1m} {-relief relief Relief raised raised} {-repeatdelay repeatDelay RepeatDelay 0 0} {-repeatinterval repeatInterval RepeatInterval 0 0} {-state state State normal normal} {-takefocus takeFocus TakeFocus {} {}} {-text text Text {} Yo\\ \\{\\ bo} {-textvariable textVariable Variable {} {}} {-underline underline Underline -1 -1} {-width width Width 0 0} {-wraplength wrapLength WrapLength 0 0}")
(define *tk-string-parsed*
  '(("-activebackground" "activeBackground" "Foreground" "#ececec" "#ececec") ("-activeforeground" "activeForeground" "Background" "#000000" "#000000") ("-anchor" "anchor" "Anchor" "center" "center") ("-background" "background" "Background" "#d9d9d9" "#d9d9d9") ("-bd" "-borderwidth") ("-bg" "-background") ("-bitmap" "bitmap" "Bitmap" () ()) ("-borderwidth" "borderWidth" "BorderWidth" "2" "2") ("-command" "command" "Command" () ()) ("-compound" "compound" "Compound" "none" "none") ("-cursor" "cursor" "Cursor" () ()) ("-default" "default" "Default" "disabled" "disabled") ("-disabledforeground" "disabledForeground" "DisabledForeground" "#a3a3a3" "#a3a3a3") ("-fg" "-foreground") ("-font" "font" "Font" ("Helvetica" "-12" "bold") ("Helvetica" "-12" "bold")) ("-foreground" "foreground" "Foreground" "#000000" "#000000") ("-height" "height" "Height" "0" "0") ("-highlightbackground" "highlightBackground" "HighlightBackground" "#d9d9d9" "#d9d9d9") ("-highlightcolor" "highlightColor" "HighlightColor" "#000000" "#000000") ("-highlightthickness" "highlightThickness" "HighlightThickness" "1" "1") ("-image" "image" "Image" () ()) ("-justify" "justify" "Justify" "center" "center") ("-overrelief" "overRelief" "OverRelief" () ()) ("-padx" "padX" "Pad" "3m" "3m") ("-pady" "padY" "Pad" "1m" "1m") ("-relief" "relief" "Relief" "raised" "raised") ("-repeatdelay" "repeatDelay" "RepeatDelay" "0" "0") ("-repeatinterval" "repeatInterval" "RepeatInterval" "0" "0") ("-state" "state" "State" "normal" "normal") ("-takefocus" "takeFocus" "TakeFocus" () ()) ("-text" "text" "Text" () "Yo { bo") ("-textvariable" "textVariable" "Variable" () ()) ("-underline" "underline" "Underline" "-1" "-1") ("-width" "width" "Width" "0" "0") ("-wraplength" "wrapLength" "WrapLength" "0" "0")))

(test* "tk-parse-string" *tk-string-parsed*
       (tk-parse-list *tk-string-source*))

;; epilogue
(test-end)
