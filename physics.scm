;; bounding geometry
(define-class AABB Object
  ([= min :immutable]
   [= max :immutable]))

(define-class Plane Object
  ([= normal   :immutable]
   [= distance :immutable]))

(define-class RigidBody Object
  ([= transformation :immutable]
   [= physics :immutable]
   [= geometry :immutable]))

(define-method (rotate! (o RigidBody) angle vec)
  (rotate! (RigidBody-transformation o) angle vec)
  (synchronize-transform! o))

(define-method (translate! (o RigidBody) x y z)
  (translate! (RigidBody-transformation o) x y z)
  (synchronize-transform! o))

;; internal helpers
;; maybe we can use transformations generic function instead?
(c-define (bullet-set-translation! rigid-body x y z)
    (scheme-object float float float) void "set_translation_scm" ""
  (with-access rigid-body (RigidBody transformation)
    (with-access transformation (Transformation translation)
      (set! translation (vec x y z)))))

(c-define (bullet-set-rotation! rigid-body w x y z)
    (scheme-object float float float float) void "set_rotation_scm" ""
  (with-access rigid-body (RigidBody transformation)
    (with-access transformation (Transformation rotation)
      (set! rotation (quat w x y z)))))

(c-define (bullet-get-translation! rigid-body)
    (scheme-object) void "get_translation_scm" ""
  (with-access rigid-body (RigidBody transformation)
    (with-access transformation (Transformation translation)
      ((c-lambda (float float float) void
         "p[0] = ___arg1; p[1] = ___arg2; p[2] = ___arg3;")
       (vec-ref translation 0)
       (vec-ref translation 1)
       (vec-ref translation 2)))))
  
(c-define (bullet-get-rotation! rigid-body)
    (scheme-object) void "get_rotation_scm" ""
  (with-access rigid-body (RigidBody transformation)
    (quat-deref (Transformation-rotation transformation)
      (c-lambda (float float float float) void
        "q[0] = ___arg1; q[1] = ___arg2; q[2] = ___arg3; q[3] = ___arg4;"))))

(c-declare #<<C-DECLARE-END
#include <btBulletDynamicsCommon.h>
#include <btBulletCollisionCommon.h>

#include <Meta/OpenGL.h>

btDynamicsWorld*       world = NULL;
btBroadphaseInterface* broadphase = NULL;
btCollisionDispatcher* dispatcher = NULL;
btConstraintSolver*    solver = NULL;
btDefaultCollisionConfiguration* conf = NULL;

float q[4];
float p[3];

class OEMotionState: public btMotionState {
private:
    ___SCMOBJ rb;
public:
    OEMotionState(___SCMOBJ rb): rb(rb) {}
    virtual ~OEMotionState() {}
    virtual void getWorldTransform (btTransform &worldTrans) const {
        get_rotation_scm(rb);
        worldTrans.setRotation(btQuaternion(q[1], q[2], q[3], q[0]));
        get_translation_scm(rb);
        worldTrans.setOrigin(btVector3(p[0], p[1], p[2]));
    }
    virtual void setWorldTransform (const btTransform &worldTrans) {
        btQuaternion q = worldTrans.getRotation();
        set_rotation_scm(rb, q.w(), q.x(), q.y(), q.z());
        btVector3 p = worldTrans.getOrigin();
        set_translation_scm(rb, p.x(), p.y(), p.z());
    }
    ___SCMOBJ getSchemeObject() {return rb;} 
};

class BulletDebugDrawer : public btIDebugDraw {
private:
    int debugMode;
public:
    BulletDebugDrawer(): debugMode(1) {}
    virtual ~BulletDebugDrawer() {};
    
    void drawLine(const btVector3& from,const btVector3& to,const btVector3& color) {
        GLboolean t = glIsEnabled(GL_TEXTURE_2D);
        GLboolean l = glIsEnabled(GL_LIGHTING);
        CHECK_FOR_GL_ERROR();
        glDisable(GL_TEXTURE_2D);
        glDisable(GL_LIGHTING);
        CHECK_FOR_GL_ERROR();

        glLineWidth(2.0);
        CHECK_FOR_GL_ERROR();

        //printf("from: (%f, %f, %f) to (%f, %f, %f)\n", from[0], from[1], from[2], to[0], to[1], to[2]);
        glBegin(GL_LINES);
            glColor3f(color[0],color[1],color[2]);
            glVertex3f(from[0], from[1], from[2]);
            glVertex3f(to[0], to[1], to[2]);
        glEnd();
        CHECK_FOR_GL_ERROR();

        // reset state 
        if (t) glEnable(GL_TEXTURE_2D);
        if (l) glEnable(GL_LIGHTING);
        CHECK_FOR_GL_ERROR();
    }

    void drawContactPoint(const btVector3& PointOnB, const btVector3& normalOnB, 
                          btScalar distance, int lifeTime, const btVector3& color) {}
    void reportErrorWarning(const char* warningString) {
        printf("%s\n", warningString);
    }
    void draw3dText(const btVector3& location, const char* textString) {}
    void setDebugMode(int debugMode) {
        this->debugMode = debugMode;
    }
    int getDebugMode() const {
        return debugMode;
    }
} debug_draw;
C-DECLARE-END
)

;; some bullet types to configure and drive the physics
;; (c-define-type DynamicsWorld (pointer "btDynamicsWorld"))
;; (c-define-type BroadPhase (pointer "btBroadphaseInterface"))
;; (c-define-type CollisionDispatcher (pointer "btCollisionDispatcher"))
;; (c-define-type ConstraintSolver (pointer "btConstraintSolver"))
;; (c-define-type CollisionConfiguration (pointer "btDefaultCollisionConfiguration"))

(define-class BulletPhysics Object
  ([= world-box 
      :immutable 
      :initializer 
      (lambda () 
        (instantiate AABB
            :min (vec -100. -100. -100.)
            :max (vec 100. 100. 100.)))]
   [= rigid-bodies :initializer list]))

(define-method (initialize! (o BulletPhysics))
  (with-access (BulletPhysics-world-box o) (AABB min max)
    ((c-lambda (float float float float float float) void
#<<BULLET-INIT-END
const float min_x = ___arg1;
const float min_y = ___arg2;
const float min_z = ___arg3;
const float max_x = ___arg4;
const float max_y = ___arg5;
const float max_z = ___arg6;

conf = new btDefaultCollisionConfiguration();

broadphase = new bt32BitAxisSweep3(btVector3(min_x, min_y, min_z), btVector3(max_x, max_y, max_z));
dispatcher = new btCollisionDispatcher(conf);
solver     = new btSequentialImpulseConstraintSolver();

world = new btDiscreteDynamicsWorld(dispatcher,
                                    broadphase,
                                    solver,
                                    conf);
BULLET-INIT-END
) (vec-ref min 0)
  (vec-ref min 1)
  (vec-ref min 2)
  (vec-ref max 0)
  (vec-ref max 1)
  (vec-ref max 2)))
  (call-next-method))


;; conversion from scheme geometry to bullet geometry
(define-generic (make-bt-geometry (o))
  (error "Unsupported bounding geometry"))

(define-method (make-bt-geometry (geometry Heightmap))
  (with-access geometry (Heightmap data-width data-height height-data height-offset height-scale xy-scale) 
    ((c-lambda (int int (pointer "float") float float float) (pointer "btCollisionShape")
#<<MAKE-BT-GEOMETRY-END
const int width           = ___arg1;
const int height          = ___arg2;
float* data               = ___arg3;
const float height_offset = ___arg4;
const float xy_scale      = ___arg5;
const float max_height    = ___arg6;

btHeightfieldTerrainShape* hf = new btHeightfieldTerrainShape(width, height, data, 1.0, height_offset, max_height, 1, PHY_FLOAT, true);
hf->setLocalScaling(btVector3(xy_scale, 1.0f, xy_scale));
___result_voidstar = hf;

MAKE-BT-GEOMETRY-END
)
     data-width 
     data-height
     height-data
     height-offset
     xy-scale
     (+ height-scale height-offset))))


(define-method (make-bt-geometry (geometry AABB))
  (with-access geometry (AABB min max)
    ((c-lambda (float float float float float float) (pointer "btCollisionShape")
#<<MAKE-BT-GEOMETRY-END

const float min_x = ___arg1;
const float min_y = ___arg2;
const float min_z = ___arg3;
const float max_x = ___arg4;
const float max_y = ___arg5;
const float max_z = ___arg6;

const float corner_x = (max_x - min_x) * 0.5;
const float corner_y = (max_y - min_y) * 0.5;
const float corner_z = (max_z - min_z) * 0.5;
//todo: set offset transform
//btVector3(max_x - corner_x, max_y - corner_y, max_z - corner_z);
___result_voidstar = new btBoxShape(btVector3(corner_x, corner_y, corner_z));

MAKE-BT-GEOMETRY-END
) (vec-ref min 0)
  (vec-ref min 1)
  (vec-ref min 2)
  (vec-ref max 0)
  (vec-ref max 1)
  (vec-ref max 2))))

(define-method (make-bt-geometry (geometry Plane))
  (with-access geometry (Plane normal distance)
    ((c-lambda (float float float float) (pointer "btCollisionShape")
#<<MAKE-BT-GEOMETRY-END

const float x = ___arg1;
const float y = ___arg2;
const float z = ___arg3;
const float d = ___arg4;
___result_voidstar = new btStaticPlaneShape(btVector3(x, y, z), d);

MAKE-BT-GEOMETRY-END
) (vec-ref normal 0)
  (vec-ref normal 1)
  (vec-ref normal 2)
  distance)))

(define-generic (make-rigid-body (physics BulletPhysics) geometry)
  (let* ([transformation (instantiate Transformation)]
         [bt-geometry (make-bt-geometry geometry)]
         ;; make a still copy of rigid body so we can keep a ref in C++
         [rigid-body  (##still-copy (instantiate RigidBody 
                                        :transformation transformation
                                        :physics physics
                                        :geometry geometry))]
         [bt-rigid-body     
          ((c-lambda (scheme-object                 ;; scheme transformation object
                      (pointer "btCollisionShape")) ;; bullet collision shape
               (pointer "btRigidBody")
#<<ADD-RIGID-BODY-END
    const float mass = 1.0;

    btMotionState* motionState = new OEMotionState(___arg1);
    //btMotionState* motionState = new btDefaultMotionState();
    btTransform trans;

    btCollisionShape* btShape = ___arg2;
    btVector3 localInertia;
    btShape->calculateLocalInertia(mass, localInertia);
    btRigidBody::btRigidBodyConstructionInfo cInfo(mass, motionState, btShape, localInertia);
    btRigidBody* body = new btRigidBody(cInfo);
    //body->setCenterOfMassTransform(trans);
    world->addRigidBody(body);

    ___result_voidstar = body;
ADD-RIGID-BODY-END
) rigid-body bt-geometry)])
    (with-access physics (BulletPhysics rigid-bodies)
      (set! rigid-bodies (cons (cons rigid-body bt-rigid-body) rigid-bodies)))
    rigid-body))

(define-generic (gravity-set! (physics BulletPhysics) x y z)
  ((c-lambda (float float float) void
     "world->setGravity(btVector3(___arg1, ___arg2, ___arg3));")
   x y z))

(define (bt-lookup-rigid-body rigid-body physics)
  (cond
    [(assoc rigid-body (BulletPhysics-rigid-bodies physics))
     => (lambda (p) (cdr p))]
    [else (error "Rigid body was not created by bullet")]))

(define-generic (apply-force! (physics BulletPhysics) rigid-body v)
  (let ([bt-rigid-body (bt-lookup-rigid-body rigid-body physics)])
    ((c-lambda ((pointer "btRigidBody") float float float) void
       "___arg1->applyForce(btVector3(___arg2, ___arg3, ___arg4), btVector3(0.0, 0.0, 0.0));
        ___arg1->setActivationState(1);")
     bt-rigid-body (vec-ref v 0) (vec-ref v 1) (vec-ref v 2))))

(define-generic (apply-force-relative! (physics BulletPhysics) rigid-body force point)
  (let ([bt-rigid-body (bt-lookup-rigid-body rigid-body physics)])
    ((c-lambda ((pointer "btRigidBody") float float float float float float) void
       "___arg1->applyForce(btVector3(___arg2, ___arg3, ___arg4), btVector3(___arg5, ___arg6, ___arg7));
        ___arg1->setActivationState(1);")
     bt-rigid-body 
     (vec-ref force 0) 
     (vec-ref force 1) 
     (vec-ref force 2) 
     (vec-ref point 0) 
     (vec-ref point 1) 
     (vec-ref point 2))))

(define-generic (apply-torque! (physics BulletPhysics) rigid-body x y z)
  (let ([bt-rigid-body (bt-lookup-rigid-body rigid-body physics)])
    ((c-lambda ((pointer "btRigidBody") float float float) void
       "___arg1->applyTorque(btVector3(___arg2, ___arg3, ___arg4));
        ___arg1->setActivationState(1);")
     bt-rigid-body x y z)))
        
(define-generic (linear-damping-set! (physics BulletPhysics) rigid-body v)
  (let ([bt-rigid-body (bt-lookup-rigid-body rigid-body physics)])
    ((c-lambda ((pointer "btRigidBody") float) void
       "___arg1->setDamping(___arg2, ___arg1->getAngularDamping());")
     bt-rigid-body v)))

(define-generic (angular-damping-set! (physics BulletPhysics) rigid-body v)
  (let ([bt-rigid-body (bt-lookup-rigid-body rigid-body physics)])
    ((c-lambda ((pointer "btRigidBody") float) void
       "___arg1->setDamping(___arg1->getLinearDamping(), ___arg2);")
     bt-rigid-body v)))

(define-generic (linear-velocity-set! (physics BulletPhysics) rigid-body v)
  (let ([bt-rigid-body (bt-lookup-rigid-body rigid-body physics)])
    ((c-lambda ((pointer "btRigidBody") float float float) void
       "___arg1->setLinearVelocity(btVector3(___arg2, ___arg3, ___arg4));
        ___arg1->setActivationState(1);")
     bt-rigid-body (vec-ref v 0) (vec-ref v 1) (vec-ref v 2))))

;; temporary hack for all the vector getters
(define *tmp-vec* #f)
(c-define (bullet-set-vector! x y z)
    (float float float) void "set_bullet_tmp_vector_scm" ""
  (set! *tmp-vec* (vec x y z)))

(define-generic (linear-velocity (physics BulletPhysics) rigid-body)
  (let ([bt-rigid-body (bt-lookup-rigid-body rigid-body physics)])
    ((c-lambda ((pointer "btRigidBody")) void
       "btVector3 v = ___arg1->getLinearVelocity();
        set_bullet_tmp_vector_scm(v[0], v[1], v[2]);")
     bt-rigid-body)
  *tmp-vec*))

(define-generic (mass-set! (physics BulletPhysics) rigid-body v)
  (let ([bt-rigid-body (bt-lookup-rigid-body rigid-body physics)])
    ((c-lambda ((pointer "btRigidBody") float) void
       "btVector3 localInertia;
        ___arg1->getCollisionShape()->calculateLocalInertia(___arg2, localInertia);
        ___arg1->setMassProps(___arg2, localInertia);")
     bt-rigid-body v)))

(define (synchronize-transform! rigid-body)
  (with-access rigid-body (RigidBody physics)
    (let ([bt-rigid-body (bt-lookup-rigid-body rigid-body physics)])
      ((c-lambda ((pointer "btRigidBody")) void
         "___arg1->getMotionState()->getWorldTransform(___arg1->getWorldTransform());")
       bt-rigid-body))))


;; @todo the world and various runtime parameters should be placed in
;; the BulletPhysics class.
(define-generic (make-physics-module (physics BulletPhysics))
  (c-lambda (float) void "world->stepSimulation(___arg1, 10, btScalar(1.)/btScalar(30.));"))
(define bullet-debug-draw
  (c-lambda () void 
    "world->setDebugDrawer(&debug_draw); world->debugDrawWorld();"))

(define pt-eq? 
  (c-lambda ((pointer "btRigidBody") (pointer "btRigidBody"))  bool
    "___result = (___arg1 == ___arg2);"))

(define (find-rigid-body bt-rigid-body physics)
  (with-access physics (BulletPhysics rigid-bodies)
    (letrec([visit (lambda (xs)
                     (cond 
                       [(null? xs)
                        #f]
                       [(pair? xs)
                        (let ([p (car xs)])
                          (if (and (pair? p) (pt-eq? bt-rigid-body (cdr p)))
                              (car p)
                              (visit (cdr xs))))]
                       [else (error "Invalid list")]))])
      (visit rigid-bodies))))
      
(define-generic (grab-rigid-body begin end (physics BulletPhysics))
  (let ([bt-rigid-body ((c-lambda (float float float float float float) (pointer "btRigidBody")
#<<GRAB-RIGID-BODY-END

    btVector3 begin(___arg1, ___arg2, ___arg3);
    btVector3 end(___arg4, ___arg5, ___arg6);
    btCollisionWorld::ClosestRayResultCallback cb(begin, end);
    world->rayTest(begin, end, cb);
    btVector3 v = cb.m_hitPointWorld;
    set_bullet_tmp_vector_scm(v[0], v[1], v[2]);
    ___result_voidstar = cb.m_collisionObject;
    
GRAB-RIGID-BODY-END
)
                        (vec-ref begin 0)
                        (vec-ref begin 1)
                        (vec-ref begin 2)
                        (vec-ref end 0)
                        (vec-ref end 1)
                        (vec-ref end 2))])
    (let ([rb (find-rigid-body bt-rigid-body physics)])
      (if rb
          (cons rb *tmp-vec*)
          #f))))


(define (dist-2d x y)
  (sqrt (+ (* x x) (* y y))))

;; the grabber module - fun stuff!
(define (make-physics-grabber add-mouse-handler add-motion-handler canvas3d physics)
  (let ([prev-x 0]
        [prev-y 0]
        [rel-pos (vec 0. 0. 0.)]
        [rigid-body #f]
        [last-btn #f])
    (let ([grab (lambda (btn state x y) 
                  (let ([cam (Canvas3D-camera canvas3d)]
                        [win-x (exact->inexact (/ x (Canvas3D-width canvas3d)))]
                        [win-y (exact->inexact (/ (- (Canvas3D-height canvas3d) y) 
                                                  (Canvas3D-height canvas3d)))])
                    (cond 
                      [(eqv? state 'down)
                       (set! last-btn btn)
                       (set! pos (unproject cam win-x win-y 0.0))
                       (set! prev-x win-x)
                       (set! prev-y win-y)
                       (let ([hit (grab-rigid-body pos
                                                   (unproject cam win-x win-y 1.0) 
                                                   physics)])
                         (if hit
                             (begin
                               (set! rigid-body (car hit))
                               (set! rel-pos (vec- 
                                              (cdr hit) 
                                              (Transformation-translation 
                                               (RigidBody-transformation rigid-body)))))
                             (set! rigid-body #f)))]
                      [(eqv? state 'up)
                       (set! rigid-body #f)])))])
      (add-mouse-handler grab))
    (let ([move (lambda (x y)
                  (if rigid-body
                      (let* ([cam (Canvas3D-camera canvas3d)]
                             [win-x (exact->inexact (/ x (Canvas3D-width canvas3d)))]
                             [win-y (exact->inexact (/ (- (Canvas3D-height canvas3d) y) 
                                                       (Canvas3D-height canvas3d)))]
                             [pos (unproject cam prev-x prev-y 0.0)]
                             [new-pos (unproject cam win-x win-y 0.0)])
                        (if (eqv? last-btn 'right)
                            (let ([force (vec-scalar*  30.0 (vec- new-pos pos))])
                              (apply-force-relative! physics rigid-body 
                                                     force rel-pos))
                            (let ([force (vec-scalar*  1000.0 (vec- new-pos pos))])
                              (apply-force! physics rigid-body force))))))])
      (add-motion-handler move))))
 