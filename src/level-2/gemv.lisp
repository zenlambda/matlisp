(in-package #:matlisp)

(defmacro generate-typed-gemv! (func
				(matrix-class vector-class
				 blas-gemv-func
				 fortran-call-lb))
  ;;Be very careful when using functions generated by this macro.
  ;;Indexes can be tricky and this has no safety net.
  ;;Use only after checking the arguments for compatibility.
  (let* ((opt (get-tensor-class-optimization matrix-class)))
    (assert opt nil 'tensor-cannot-find-optimization :tensor-class matrix-class)
    `(defun ,func (alpha A x beta y job)
       (declare (type ,(getf opt :element-type) alpha beta)
		(type ,matrix-class A)
		(type ,vector-class x y)
		(type symbol job))
       (mlet*
	(((maj-A ld-A fop-A) (blas-matrix-compatible-p A job) :type (symbol index-type (string 1))))
	(let ((call-fortran? (> (max (nrows A) (ncols A)) ,fortran-call-lb)))
	  (cond
	    ((and maj-a call-fortran?)
	     (let-typed ((nr-A (nrows A) :type index-type)
			 (nc-A (ncols A) :type index-type))
			(when (eq maj-A :row-major)
			  (rotatef nr-A nc-A))
			(,blas-gemv-func fop-a nr-A nc-A
					 alpha (store A) ld-A
					 (store x) (aref (strides x) 0)
					 beta
					 (store y) (aref (strides y) 0)
					 (head A) (head x) (head y))))
	   (t
	    (let-typed ((nr-A (nrows A) :type index-type)
			(nc-A (ncols A) :type index-type)
			(rs-A (row-stride A) :type index-type)
			(cs-A (col-stride A) :type index-type)
			(sto-A (store A) :type ,(linear-array-type (getf opt :store-type)))
					;
			(stp-x (aref (strides x) 0) :type index-type)
			(sto-x (store x) :type ,(linear-array-type (getf opt :store-type)))
			(hd-x (head x) :type index-type)
					;
			(stp-y (aref (strides y) 0) :type index-type)
			(sto-y (store y) :type ,(linear-array-type (getf opt :store-type))))
		       (when (eq job :t)
			 (rotatef nr-A nc-A)
			 (rotatef rs-A cs-A))
		       (very-quickly
			 (loop repeat nr-A
			    for of-y of-type index-type = (head y) then (+ of-y stp-y)
			    for rof-A of-type index-type = (head A) then (+ rof-A rs-A)
			    do (let-typed ((val (* beta ,(funcall (getf opt :reader) 'sto-y 'of-y)) :type ,(getf opt :element-type)))
					  (loop repeat nc-A
					     for of-x of-type index-type = hd-x then (+ of-x stp-x)
					     for of-A of-type index-type = rof-A then (+ of-A cs-A)
					     summing (* ,(funcall (getf opt :reader) 'sto-x 'of-x)
							,(funcall (getf opt :reader) 'sto-A 'of-A)) into dotp of-type ,(getf opt :element-type)
					     finally ,(funcall (getf opt :value-writer)
							       `(+ (* alpha dotp) val) 'sto-y 'of-y))))))))))
       y)))

;;Tweakable
(defparameter *real-gemv-fortran-call-lower-bound* 1000
  "
  If the maximum dimension in the MV is lower than this
  parameter, then the lisp code is used by default, instead of
  calling BLAS. Used to avoid the FFI overhead when calling
  MM with small matrices.
  Default set with SBCL on x86-64 linux. A reasonable value
  is something between 800 and 2000.")
(generate-typed-gemv! real-typed-gemv! (real-matrix real-vector
					dgemv
					*real-gemv-fortran-call-lower-bound*))

;;Tweakable
(defparameter *complex-gemv-fortran-call-lower-bound* 600
  "
  If the maximum dimension in the MV is lower than this
  parameter, then the lisp code is used by default, instead of
  calling BLAS. Used to avoid the FFI overhead when calling
  MM with small matrices.
  Default set with SBCL on x86-64 linux. A reasonable value
  is something between 400 and 1000.")
(generate-typed-gemv! complex-typed-gemv! (complex-matrix complex-vector
					   zgemv
					   *complex-gemv-fortran-call-lower-bound*))
;;---------------------------------------------------------------;;

;;Can't support "C" because the dual isn't supported by BLAS.
(defgeneric gemv! (alpha A x beta y &optional job)
  (:documentation
"
  Syntax
  ======
  (GEMV! alpha A x beta y [job])

  Purpose
  =======
  Performs the GEneral Matrix Vector operation given by
               --      -      -

            Y <- alpha * op(A) * x + beta * y
     
  and returns y.

  alpha,beta are scalars,
  A is a matrix, and x,y are vectors.

  op(A) means either A or A'.

     JOB                    Operation
  ---------------------------------------------------
     :N (default)      alpha * A * x + beta * y
     :T                alpha * A'* x + beta * y
")
  (:method :before ((alpha number) (A standard-matrix) (x standard-vector)
		    (beta number) (y standard-vector)
		    &optional (job :n))
	   (assert (member job '(:n :t)) nil 'invalid-value
		   :given job :expected `(member job '(:n :t))
		   :message "Inside gemv!")
	   (assert (not (eq x y)) nil 'invalid-arguments
		   :message "GEMV!: x and y cannot be the same vector")
	   (assert (and
		    (= (aref (dimensions x) 0)
		       (aref (dimensions A) (if (eq job :t) 0 1)))
		    (= (aref (dimensions y) 0)
		       (aref (dimensions A) (if (eq job :t) 1 0))))
		   nil 'tensor-dimension-mismatch)))

(defmethod gemv! ((alpha number) (A real-matrix) (x real-vector)
		  (beta number) (y real-vector) &optional (job :n))
  (real-typed-gemv! (coerce-real alpha) A x
		    (coerce-real beta) y job))

(defmethod gemv! ((alpha number) (A complex-matrix) (x complex-vector)
		  (beta number) (y complex-vector) &optional (job :n))
  (complex-typed-gemv! (coerce-complex alpha) A x
		       (coerce-complex beta) y job))

(defmethod gemv! ((alpha number) (A real-matrix) (x real-vector)
		  (beta number) (y complex-vector) &optional (job :n))
  (unless (= beta 1)
    (complex-typed-scal! (coerce-complex beta) y))
  (unless (= alpha 0)
    (if (complexp alpha)
	(let ((A.x (make-real-tensor (aref (dimensions y) 0)))
	      (vw-y (tensor-realpart~ y)))
	  (real-typed-gemv! (coerce-real 1) A x (coerce-real 0) A.x job)
	  ;;
	  (real-typed-axpy! (coerce-real (realpart alpha)) A.x vw-y)
	  ;;Move view to the imaginary part
	  (incf (head vw-y))
	  (real-typed-axpy! (coerce-real (imagpart alpha)) A.x vw-y))
	(real-typed-gemv! (coerce-real alpha) A x
			  (coerce-real 1) (tensor-realpart~ y) job)))
  y)

(defmethod gemv! ((alpha number) (A real-matrix) (x complex-vector)
		  (beta number) (y complex-matrix) &optional (job :n))
  (unless (= beta 1)
    (complex-typed-scal! (coerce-complex beta) y))
  (unless (= alpha 0)
    (let ((A.x (make-complex-tensor (aref (dimensions y) 0))))
      (let ((vw-x (tensor-realpart~ x))
	    (vw-A.x (tensor-realpart~ x)))
	;;Re
	(real-typed-gemv! (coerce-real 1) A vw-x (coerce-real 0) vw-A.x job)
	;;Im
	(incf (head vw-x))
	(incf (head vw-A.x))
	(real-typed-gemv! (coerce-real 1) A vw-x (coerce-real 0) vw-A.x job))
      (complex-typed-axpy! (coerce-complex alpha) A.x y)))
  y)

(defmethod gemv! ((alpha number) (A complex-matrix) (x real-vector)
		  (beta number) (y complex-vector) &optional (job :n))
  (let ((cplx-x (make-complex-tensor (aref (dimensions x) 0))))
    (real-typed-copy! x (tensor-realpart~ cplx-x))
    (complex-typed-gemv! (coerce-complex alpha) A cplx-x
			 (coerce-complex beta) y job))
  y)

;;---------------------------------------------------------------;;
(defgeneric gemv (alpha A x beta y &optional job)
  (:documentation
"
  Syntax
  ======
  (GEMV alpha A x beta y [job])

  Purpose
  =======
  Returns the GEneral Matrix Vector operation given by

            alpha * op(A) * x + beta * y

  alpha,beta are scalars,
  A is a matrix, and x,y are vectors.

  op(A) means either A or A'.

     JOB                    Operation
  ---------------------------------------------------
     :N (default)      alpha * A * x + beta * y
     :T                alpha * A'* x + beta * y
"))

(defmethod gemv ((alpha number) (A standard-matrix) (x standard-vector)
		 (beta number) (y complex-vector) &optional (job :n))
  (let ((result (copy y)))
    (gemv! alpha A x 1d0 result job)))

(defmethod gemv ((alpha number) (A standard-matrix) (x standard-vector)
		 (beta number) (y real-vector) &optional (job :n))
  (let ((result (if (or (complexp alpha) (complexp beta)
			(typep A 'complex-matrix) (typep x 'complex-vector))
		    (make-complex-tensor (aref (dimensions y) 0))
		    (make-real-tensor (aref (dimensions y) 0)))))
    (scal! y result)
    (gemv! alpha A x beta result job)))

(defmethod gemv ((alpha number) (A standard-matrix) (x standard-vector)
		 (beta (eql nil)) (y (eql nil)) &optional (job :n))
  (let ((result (apply
		 (if (or (complexp alpha) (complexp beta)
			 (typep A 'complex-matrix) (typep x 'complex-vector))
		     #'make-complex-tensor
		     #'make-real-tensor)
		 (list (ecase job (:n (nrows A)) (:t (ncols A)))))))
    (gemv! alpha A x beta result job)))