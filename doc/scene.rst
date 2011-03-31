
The Graphics Scene
==================

The main structure for representing an image in 3d is *scene graph*.
By convention we assume the scene graph to be an *acyclic directed
graph* (DAG). Behavior is undefined for cyclic scenes.

A scene consists of scene nodes (:scm:class:`SceneNode`), which may
contain any number children, and scene leafs (:scm:class:`SceneLeaf`),
which can not contain children. Both have the common ancestor type:
:scm:class:`Scene`.

.. scm:class:: (Scene Object ())

.. scm:class:: (SceneLeaf Scene ())

.. scm:class:: (SceneNode Scene (children))


The system provides the following generic functions on scenes:

.. scm:generic:: (scene-add-node! (node SceneNode) (child Scene))

.. scm:generic:: (scene-remove-node! (node SceneNode) (child Scene))


