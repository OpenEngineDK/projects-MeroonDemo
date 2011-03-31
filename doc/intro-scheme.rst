===================================
A very brief introduction to Scheme
===================================

This page briefly describes some commonly used features of Scheme.
The following resources provide a more in-depth and complete account
of Scheme:

- http://scheme.com/tspl3/
- http://scheme.com/tspl4/
- http://schemers.org/


Recursion and iteration
-----------------------

There are several special forms available to implement an iterative or
recursive process. The most general from is `letrec` which
introduces recursive bindings while a named-`let` and `do` provide
forms for simpler uses of recursion and iteration.

.. syntax:: (letrec ([var (lambda (formal ...) fbody)] ...) body)

   The `letrec` form binds a series of variable names to procedures
   [1]_. The bound names (ie, `var` in the above) are lexically
   visible in both the bodies of the procedures (ie, `fbody`) and in
   the body of the letrec (ie, `body`).  For example, we might define
   the two mutually recursive functions `even` and `odd` over the
   structure of natural numbers::

      > (letrec ([even (lambda (n) (or (= n 0) (odd  (- n 1))))]
                 [odd  (lambda (n) (or (= n 1) (even (- n 1))))])
          (even 42))
      #t


.. syntax:: (let name ([var init] ...) body)

   A named-`let` (not to be confused with the usual `let`) is related
   to `letrec` but only allows us one recursive function named *name*
   as follows: The list of `[var init]` pairs define the initial value
   *init* of the variable *var*. In *body* the variables are made
   lexically visible as well as the procedure named *name* which takes
   as many arguments as there are variables and if invoked performs
   *body* with the updated value given as arguments. For example, let
   us iteratively sum a list using an accumulator::

     > (let do-sum ([lst '(1 2 3 4 5)]
                    [acc 0])
         (if (null? lst)
             acc
	     (do-sum (cdr lst) (+ acc (car lst)))))
     15

   The above code is *exactly* equivalent to::

     > (letrec ([do-sum (lambda (lst acc)
                           (if (null? lst)
                               acc
                               (do-sum (cdr lst) (+ acc (car lst)))))])
          (do-sum '(1 2 3 4 5) 0))
     15


.. syntax:: (do ([var init update] ...) (term result) body)

   Finally the `do`-form allows an even more concise notation for
   common loops. Here each `[var init update]` list specifies the
   initial value *init* of *var* and an update expression *update*.
   The loop terminates when *term* evaluates to a non-`#f` value and
   the result is *result* (or unspecified if *result* is omitted).
   Each iteration the optional *body* is evaluated. For example, our
   example from before becomes::

     > (do ([lst '(1 2 3 4 5) (cdr lst)]
            [acc 0 (+ acc (car lst))])
         ((null? lst) acc))
     15


.. [1] The `letrec` special form can bind more then just procedures,
       but such bindings are often ill-defined since Scheme is strict.
