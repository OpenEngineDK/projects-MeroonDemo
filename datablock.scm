(c-declare #<<c-declare-end
#include <cstdio>
#include <Resources/DataBlock.h>
using namespace OpenEngine::Resources;
c-declare-end
)

(c-define-type DataBlock (pointer "IDataBlock"))

(define (new-datablock size dim type)
  (cond
    [(= dim 1)
     (case type
       [(int) ((c-lambda (int) DataBlock 
                 "___result_voidstar = new DataBlock<1,unsigned int>  (___arg1);") size)]
       [else (error "Unknown data block type: " type)])]
    [(= dim 3)
     (case type
       [(float) ((c-lambda (int) DataBlock
                   "___result_voidstar = new DataBlock<3,float>(___arg1);") size)]
       [else (error "Unknown data block type: " type)])]
    [else (error "Unsupported dimension: " dim)]))

(define (datablock-set db i v type)
  (case type
    [(int)
     (let loop ([i (* i (length v))] [v v])
       (or (null? v)
           (begin
             ((c-lambda (DataBlock int unsigned-int) void
                "((int*)(___arg1->GetVoidData()))[___arg2] = ___arg3;")
              db i (car v))
             (loop (+ 1 i) (cdr v)))))]
    [(float)
     (let loop ([i (* i (length v))] [v v])
       (or (null? v)
           (begin
             ((c-lambda (DataBlock int float) void
                "((float*)(___arg1->GetVoidData()))[___arg2] = ___arg3;")
              db i (car v))
             (loop (+ 1 i) (cdr v)))))]
    [else (error "Unknown type used in data block")]))

(define (check-elm elm size type)
  (let loop ([i 0] [elm elm])
    (if (null? elm)
        (= size i)
        (and (case type
               [(int) (integer? (car elm))]
               [(float) (real? (car elm))]
               [else (error "Unknown type for data block: " type)])
             (loop (+ i 1) (cdr elm))))))
  
(define (make-datablock pts)
  (cond
    [(not (pair? pts))
     (error "Attempt to create an empty data block")]
    [(not (pair? (car pts)))
     (error "Invalid vector given to data block")]
    [else
     (let* ([fst (caar pts)]
            [type (or (and (fixnum? fst) 'int)
                      (and (flonum? fst) 'float)
                      (error "Unsupported number representation"))]
            [elm-len  (length pts)]
            [elm-size (length (car pts))]
            [db (new-datablock elm-len elm-size type)])
       (let setter ([i 0]
                    [pts pts])
         (if (null? pts)
             db
             (begin
               (or (check-elm (car pts) elm-size type)
                   (error "Invalid element in datablock at index: " i))
               (datablock-set db i (car pts) type)
               (setter (+ 1 i) (cdr pts))))))]))
