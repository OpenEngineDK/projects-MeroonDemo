========================================
Meroon V3 -- An object system for Scheme
========================================

Meroon is a small and fairly efficient object system for Scheme.  It
is single inheritance and features multiple dispatch.

The following descriptions are not complete. For a light but more
in-depth account please consult the manual which can be found from
your OpenEngine installation root at:

  `dependencies/GambitDep/MeroonV3-2008Mar01/Doc/MeroonV3.pdf`


.. syntax:: (define-class Class Super ([= field :options] ...))

   Defines a class *Class* as a subtype of *Super*.  For each 
   `[= field :options]` list *field* becomes a field of the class.
   The options include:

   - `:mutable` -- The field is mutable *(default)*
   - `:immutable` -- The field is immutable
   - `:initializer (lambda () init)` -- The field is default initialized to *init*

   For each field a *getter* is defined with the form::

     (Class-field obj)

   For each mutable field a *setter* is defined with the form::

     (set-Class-field! obj new-val)

   Furthermore, a *constructor* is defined with the form::

     (make-Class field-init ...)

   For example, we might create a class for shapes with some subtypes
   thereof::

     > (define-class Shape Object ())
     > (define-class Point Shape ([= x] [= y]))
     > (define-class Triangle Shape ([= x] [= y] [= z]))
     > (define p1 (make-Point 10 20))
     > (define p2 (make-Point 30 40))
     > (Point-x p1)
     10

.. syntax:: (define-generic (name (var Class) ...) body)

   Defines a new generic function (ie, virtual function) named *name*.
   Each `(var Class)` pair specifies a formal parameter with
   dispatching. The formal *var* must be of type *Class* or a subtype
   thereof. The *body* expression is the default implementation.
   For example, we might have a generic draw function on shapes::
   
     > (define-generic (draw (shape Shape))
         (error "not implemented yet"))

   There can only exist one generic function named *name*. Derived
   forms are defined using :syn:`define-method`.

.. syntax:: (define-method (name (var Class) ...) body)

   Defines a refined implementation of a generic function named
   *name*. Each `(var Class)` must match those of the generic function
   in that *Class* must be a subtype of the class specified by the
   generic function. For example, we can define draw methods for each
   of our shapes::

     > (define-method (draw (shape Point))
         ... draw the point here ... )
     > (define-method (draw (shape Triangle))
         ... draw the triangle here ... )

.. syntax:: (instantiate Class :field init ...)

