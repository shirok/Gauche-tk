# About Gauche-tk

This is a simple Tk binding for Gauche.   It's so simple that you don't
even need to compile this package---we invoke the 'wish' command (Tcl/Tk's
interactive shell) and communicate to it via pipes.

## Prerequisites

Requires Gauche 0.9.3 or later.

## A simple example

    (use tk)

    (tk-init '())
    (tk-button '.b :text "Click me" :command (^[] (print "Yeah!")))
    (tk-pack '.b)
    (tk-mainloop)

This code creates a button and set a callback which will be called when
the button is clicked.  If you know Tcl/Tk, you can make sense, although
the syntax is slightly different.

`tk-init` initializes tk subsystem.  It invokes wish process.

`tk-button` command creates a button named ".b".  When we talk to
wish, we convert everything into strings, so it doesn't matter
whether you pass a symbol or a string here.   For the option names
(e.g. `-text`), use keywords (e.g. `:text`).

A tricky part is the callbacks---you can pass Scheme procedure where
Tk expects Tcl code to be called.  Gauche-tk does not pass the Scheme
procedure to the Tk world (Tk doesn't know what to do with it!);
instead we register a small dummy Tcl code as a callback, and when we
detect that dummy code is executed, we call Scheme procedure in our
side.  This detail may not matter much while you're writing applications,
but keeping in mind that the closures are executed in the Scheme world
(not in the Tcl/Tk world) may help troubleshooting.

`tk-mainloop` call enters the event loop.  It doesn't return until
the Tk window is closed.  You need to call `tk-mainloop` to make
callbacks work.

If you're working on REPL, it is inconvenient that `tk-mainloop`
doesn't return.  If you want REPL prompt even while running
event loop, call `tk-mainloop` with `background` keyword argument:

    (tk-mainloop :background #t)

This runs the event loop in a separate thread, enabling you to
keep working in REPL prompt.

In Tcl/Tk, the `button .b` command creates a new command `.b`,
which can be subsequently used to change the button's behavior
and to query its attributes.  In Scheme, you need to use `tk-call`
command.  The following code first queries the current text
value of the button, then change it.

    (tk-call '.b 'cget :text)
    (tk-call '.b 'configure :text "Don't click me")


## Graceful termination

Since the Tk part (wish command) is a separate process from Gauche,
it is possible that the Tk process remains after the Gauche process
terminates.  Calling `tk-shutdown` terminates the Tk process.
One way to ensure termination of Tk process is to set `exit-handler`
in your application, e.g.:

    (exit-handler (^[code fmtstr args] (tk-shutdown)))

See the documentation of `exit-handler` in Gauche manual for the
details.  It is important that it's application's responsibility
to decide what to do with exit-handler---a library shouldn't change
its value.

`tk-shutdown` is also convenient if you're working in REPL and
want to start over---call `tk-shutdown`, then `tk-init` again,
gives you a fresh Tk process.


## Callback parameters

Some callbacks needs to receive parameters; for example, mouse click
event wants to know where the mouse cursor is.  In Tcl, it is handled
by substitution---you embed a special sequence such as `%x` in the
script, and Tcl runtime substitutes it with the number before executing
the script.  In Gauche-tk, you can use a special macro `tklambda`
to receive the parameters.

    (use tk)

    (tk-init '())
    (tk-bind "." '<Key>      (tklambda (%K) (print #`"Pressed ,%K")))
    (tk-bind "." '<Button-1> (tklambda (%x %y) (print #`"Clicked at (,%x ,%y)")))
    (tk-mainloop)

The parameter name such as `%K` determines what kind of value it
receives.  See the Tk document for the available names.  Within
the Scheme code, `%x` etc. are just ordinary variables.


## Talking to Tcl/Tk world

Some APIs are provided to communicate with Tcl/Tk process.

`tk-ref varname` returns the value of Tcl variable `varname`.
Normally you want to refer to toplevel variable, and it's better to
use explicitly qualified name---e.g. `(tk-ref "::thevar")` to
ask the value of the toplevel variable "thevar".

Note that in the Tcl world, everything is a string.  You need to
interpret the returned string as you wish.

`tk-parse-list value` is a utility procedure that parses (nested)
Tcl string as a list.

    (tk-parse-list "{a b \"c d\" e} {f g}")
      => (("a" "b" "c d" "e")("f" "g"))

`tk-set! varname value` sets the Tcl variable.  The `value`
is converted to string before passed to Tcl.  Normally you want
to qualify varname as `::varname` to make sure it is a toplevel
variable.

Gauche-tk provides APIs corresponding to Tk commands available
in Tcl/Tk 8.4 (e.g. `tk-bind` for `bind` Tk command).  If you want
to use other Tcl/Tk command, you can use `tk-call`.  It takes a command
and arguments, and send it over to Tk process, then receives the result
as a string.

    (tk-call 'expr "3 + 4") => "7"

If an error occurs in the Tk side, `<tk-error>` condition is thrown
in the Scheme world.

    gosh> (tk-call 'expr "3 +")
    *** TK-ERROR: syntax error in expression "3 +": premature end of expression

If you find you invoke some Tcl command via `tk-call` often enough,
you can create a Scheme procedure to do so.

    (define-tk-command tk-expr expr)
    (tk-expr "3 + 4") => "7"

In fact, this is how `tk-bind` etc. is defined.


## Troubleshooting

### Path to wish

When Gauche-tk module is loaded by `(use tk)`, Gauche scans paths in PATH
to find 'wish' executable.  If it can't find one, `tk-init` will fail.
In certain cases that you have 'wish' command in nonstandard location
(or want to use other customized command), set up `wish-path` parameter
to tell the path to the executable to Gauche.

    (wish-path "/path/to/wish")

It should be executed before `tk-init`.

### Dumping communication

The wall of abstraction isn't strong enough and sometimes you need to
dig into the low-level communication between Gauche and Tk.  There's
a hidden variable `*tk-debug*` that helps you to do so.

    (with-module tk (set! *tk-debug* #t))

After this, all communication between Tk and Gauche is dumped to
stdout.

### Avoiding leak

Scheme closures passed as callbacks are registered in a global
hashtable.  Currently, this table won't be GC-ed.   For example,
the following code changes the callback to the button ".b":

    (button ".b" :command (^[] (foo)))
    (tk-call ".b" 'configure :command (^[] (bar)))

With this code, the initial callback `(^[] (foo))` remains in the
hashtable even it will never be called again.  This will be an issue
if you change the registered callbacks too often.

Fortunately, there's an easy workaround.  If you need to change
callback behaviors, you change it in the Scheme side:

    (define *callback* (^[] (foo)))

    (define (bridge) (*callback*))
    (button ".b" :command bridge)

    (set! *callback* (^[] (bar)))
