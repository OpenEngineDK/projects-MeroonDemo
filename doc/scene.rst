
The Graphics Scene
==================

The main structure for representing an image in 3d is *scene graph*.
By convention we assume the scene graph to be an *acyclic directed
graph* (DAG). Behavior is undefined for cyclic scenes.

A scene consists of scene nodes (:scm:class:`SceneNode`), which may
contain any number children, and scene leafs (:scm:class:`SceneLeaf`),
which can not contain children. Both have the common ancestor type:
:scm:class:`Scene`.

Base types
----------

.. class:: (Scene Object (name info))

   :field name: node name string or #f (default #f)
   :field info: additional information string or #f (default #f)

   The :class:`Scene` class is the base type of all scene nodes but
   should not be subtyped. Any subtype should inherit from
   :class:`SceneNode` or :class:`SceneLeaf`.

.. class:: (SceneLeaf Scene ())

   The :class:`SceneLeaf` is the base type for all terminal elements,
   ie, elements with no children. See fx :class:`MeshNode`.

.. class:: (SceneNode Scene (children))

   :field children: a list of children (default '())

   The :class:`SceneNode` is the base type for all composite elements,
   ie, elements with children. See fx :class:`TransformationNode`.


Generic functions
-----------------

The system provides the following generic functions on scenes:

.. generic:: (scene-add-node! (node SceneNode) (child Scene))

   Add *child* to the scene *node*. The child is added even if it is
   already a child of *node*.

.. generic:: (scene-remove-node! (node SceneNode) (child Scene))

   Remove *child* from the scene *node*. Nothing happens if *child* is
   not an actual child.


Derived types
-------------

.. DERIVED LEAFS ..............................

.. class:: (MeshLeaf SceneLeaf (mesh))

.. class:: (LightLeaf SceneLeaf (light))

.. DERIVED NODES ..............................

.. class:: (TransformationNode SceneNode (transformation))

   :field transformation: a :class:`Transformation` element

.. class:: (BoneNode SceneNode (???))

