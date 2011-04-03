========================================
Features and Files
========================================

This section is meant to give an overview of the core features
of OpenEngine as they emerge, as well as uncovering how the features
are distributed across the various scheme source files.

Basic Structures
----------------

The most important part of the engine is the internal data structures
used to represent the scene and in general the structures required for
rendering, and the design choices greatly affects modularity and
performance.

OpenEngine currently has early representations of a scene graph, as
well as structures to represent cameras, geometry, and animations. The
overall design philosophy (so far) is to represent as many structures
as possible in scheme, using clean and simple interfaces in order to
make as many aspects of the engine scriptable using either scripts
written in scheme or simply using the scheme REPL for live
interaction.

To maintain a reasonable performance level, large data structures such
as vertex attribute lists, and vertex weight lists (used for skinning)
are maintained entirely in C/C++, to enable low level optimized
routines to work directly on the representation without any need for
data conversion.

The basic structures including scene graph, camera, and geometry
representations are implemented in `scene.scm`, `camera.scm`,
`geometry.scm`, respectively.


Asset Importer
--------------

OpenEngine relies on Assimp for importing resources such as
three-dimensional geometry and animations. This enables support for a
wide variety of popular file formats, such as collada (`.dae`) and
Wavefront (`.obj`). 

Scheme bindings can be found in `assimp.scm`.

Texture Loading
---------------

For two-dimensional image loading, OpenEngine currently uses
FreeImage. With this library we can import textures stored in most of
the popular image formats, such as `.jpg`, `.png`, .and `.tga`.

Scheme bindings can be found in `texture.scm`, together with a
light-weight object representation of an image and texture resource.

OpenGL Renderer
---------------

OpenGL is currently the way to render a three-dimensional scene in
OpenEngine. The renderer traverses the scene graph in scheme code and
dispatches to low-level C++ routines for issuing OpenGL
commands. Currently the renderer supports automatic loading of
textures onto the GPU and automatic loading of geometry onto the GPU
(only if vbo support is detected). Planned features include: GLSL shader
support, automatic unloading of textures and VBOs. The entire renderer
can be found in `opengl.scm`.

Bone Animation and Skinning
-----------------------

OpenEngine includes a subsystem for doing bone animation. The bone
joints and keyframes are imported via Assimp into scheme structures
and the animation system is written entirely in scheme. All structures and
operations can be found in `animation.scm` except for the bone
representation which can be found in `scene.scm`.

The skinning subsystem is implemented in `C++` and right now only a
CPU version exists. The process of skinning has been integrated into
the rendering pass in order to support GPU-skinning later
on. Currently the skinning code can be found in `opengl.scm`.

Math - Structures and Operations
--------------------------------

Two basic math structures are used throughout the entire engine,
namely the three-dimensional vector and the quaternion. Currently the
vector is simply represented by a scheme vector (maybe the gambit
f32vector should be used instead) and operations are implemented in
`vector.scm`. 

The quaternion is implemented as a Meroon object (maybe
this should simply also be a f32vector) and operations and various
constructors can be found in `quaternion.scm`. 

These basic structures are mainly used through the transformation
abstraction, which defines a three-dimensional spatial transformation
using a translation vector, a scaling vector together with a rotation
defined by a pivot vector and a quaternion. This abstraction, together
with C++ routines for constructing low level matrix representations,
can be found in `transformation.scm`.

.. Meroon is a small and fairly efficient object system for Scheme.  It
.. is single inheritance and features multiple dispatch.

.. The following descriptions are not complete. For a light but more
.. in-depth account please consult the manual which can be found from
.. your OpenEngine installation root at:

..   `dependencies/GambitDep/MeroonV3-2008Mar01/Doc/MeroonV3.pdf`


.. .. syntax:: (define-class Class Super ([= field :options] ...))

..    Defines a class *Class* as a subtype of *Super*.  For each 
..    `[= field :options]` list *field* becomes a field of the class.
..    The options include:

..    - `:mutable` -- The field is mutable *(default)*
..    - `:immutable` -- The field is immutable
..    - `:initializer (lambda () init)` -- The field is default initialized to *init*

..    For each field a *getter* is defined with the form::

..      (Class-field obj)

..    For each mutable field a *setter* is defined with the form::

..      (set-Class-field! obj new-val)

..    Furthermore, a *constructor* is defined with the form::

..      (make-Class field-init ...)

..    For example, we might create a class for shapes with some subtypes
..    thereof::

..      > (define-class Shape Object ())
..      > (define-class Point Shape ([= x] [= y]))
..      > (define-class Triangle Shape ([= x] [= y] [= z]))
..      > (define p1 (make-Point 10 20))
..      > (define p2 (make-Point 30 40))
..      > (Point-x p1)
..      10

.. .. syntax:: (define-generic (name (var Class) ...) body)

..    Defines a new generic function (ie, virtual function) named *name*.
..    Each `(var Class)` pair specifies a formal parameter with
..    dispatching. The formal *var* must be of type *Class* or a subtype
..    thereof. The *body* expression is the default implementation.
..    For example, we might have a generic draw function on shapes::
   
..      > (define-generic (draw (shape Shape))
..          (error "not implemented yet"))

..    There can only exist one generic function named *name*. Derived
..    forms are defined using :syn:`define-method`.

.. .. syntax:: (define-method (name (var Class) ...) body)

..    Defines a refined implementation of a generic function named
..    *name*. Each `(var Class)` must match those of the generic function
..    in that *Class* must be a subtype of the class specified by the
..    generic function. For example, we can define draw methods for each
..    of our shapes::

..      > (define-method (draw (shape Point))
..          ... draw the point here ... )
..      > (define-method (draw (shape Triangle))
..          ... draw the triangle here ... )

.. .. syntax:: (instantiate Class :field init ...)

