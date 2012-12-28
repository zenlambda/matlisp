(in-package #:matlisp)

;;Alias for fixnum.
(deftype index-type ()
  'fixnum)

(deftype index-store-vector (&optional (size '*))
  `(simple-array index-type (,size)))

(make-array-allocator allocate-index-store 'index-type 0
"
  Syntax
  ======
  (ALLOCATE-INDEX-STORE SIZE [INITIAL-ELEMENT 0])

  Purpose
  =======
  Allocates index storage.")

(definline make-index-store (contents)
  "
  Syntax
  ======
  (MAKE-INDEX-STORE &rest CONTENTS)

  Purpose
  =======
  Allocates index storage with initial elements from the list CONTENTS.
  "
  (make-array (length contents) :element-type 'index-type
	      :initial-contents contents))

(definline idxv (&rest contents)
  (make-index-store contents))

;;
(defclass standard-tensor ()
  ((rank
    :accessor rank
    :type index-type
    :documentation "Rank of the tensor: number of arguments for the tensor")
   (dimensions
    :accessor dimensions
    :initarg :dimensions
    :type index-store-vector
    :documentation "Dimensions of the vector spaces in which the tensor's arguments reside.")
   (number-of-elements
    :accessor number-of-elements
    :type index-type
    :documentation "Total number of elements in the tensor.")
   ;;
   (parent-tensor
    :accessor parent-tensor
    :initarg :parent-tensor
    :type standard-tensor
    :documentation "If the tensor is a view of another tensor, then this slot is bound.")
   ;;
   (head
    :initarg :head
    :initform 0
    :accessor head
    :type index-type
    :documentation "Head for the store's accessor.")
   (strides
    :initarg :strides
    :accessor strides
    :type index-store-vector
    :documentation "Strides for accesing elements of the tensor.")
   (store-size
    :accessor store-size
    :type index-type
    :documentation "Size of the store.")
   (store
    :initarg :store
    :accessor store
    :documentation "The actual storage for the tensor."))
  (:documentation "Basic tensor class."))

(defclass standard-matrix (standard-tensor)
  ((rank
    :accessor rank
    :allocation :class
    :type index-type
    :initform 2
    :documentation "For a matrix, rank = 2."))
  (:documentation "Basic matrix class."))

;;
(defmethod initialize-instance :after ((matrix standard-matrix) &rest initargs)
  (declare (ignore initargs))
  (let-typed
   ((rank (rank matrix) :type index-type))
   (unless (= rank 2)
     (error 'tensor-not-matrix :rank rank :tensor matrix))))

(defmethod update-instance-for-different-class :before ((old standard-tensor) (new standard-matrix) &rest initargs)
  (declare (ignore initargs))
  (unless (= (rank old) 2)
    (error 'tensor-not-matrix :rank (rank old))))

;;
(defclass standard-vector (standard-tensor)
  ((rank
    :accessor rank
    :allocation :class
    :type index-type
    :initform 1
    :documentation "For a vector, rank = 1."))
  (:documentation "Basic vector class."))

(defmethod initialize-instance :after ((vector standard-vector) &rest initargs)
  (declare (ignore initargs))
  (mlet*
   ((rank (rank vector) :type index-type))
   (unless (= rank 1)
     (error 'tensor-not-vector :rank rank :tensor vector))))

(defmethod update-instance-for-different-class :before ((old standard-tensor) (new standard-vector) &rest initargs)
  (declare (ignore initargs))
  (unless (= (rank old) 1)
    (error 'tensor-not-vector :rank (rank old))))

;;
(defvar *tensor-class-optimizations* (make-hash-table)
  "
  Contains a either:
  o A property list containing:  
  :field-type -> Field type
  :f+ (a b) -> a + b
  :f- (a b) -> a + (- b)
  :finv+ (a) -> -a
  :fid+ () -> + identity
  :f* (a b) -> a * b
  :f/ (a b) -> a * b^{-1}
  :finv* (a) -> 1/a
  :fid* () -> * identity

  :coercer (ele) -> Coerced to store-type, with error checking
  :coercer-unforgiving (ele) -> Coerced to store-type, no error checking

  :store-allocator (n) -> Allocates a store of size n
  :store-type
  :reader (store idx) => result
  :value-writer (value store idx) => (store idx) <- value
  :reader-writer (fstore fidx tstore tidx) => (tstore tidx) <- (fstore fidx)
  :swapper       (fstore fidx tstore tidx) => (tstore tidx) <-> (fstore fidx)
  o class-name (symbol) of the superclass whose optimizations
  are to be made use of.")

(definline get-tensor-class-optimization (clname)
  (declare (type symbol clname))
  (symbol-plist clname))

(definline get-tensor-object-optimization (obj)
  (symbol-plist (class-name (class-of obj))))

(defun get-tensor-class-optimization-hashtable (clname)
  (let ((opt (gethash clname *tensor-class-optimizations*)))
    (cond
      ((null opt) nil)
      ((symbolp opt)
       (get-tensor-class-optimization opt))
      (t (values opt clname)))))

(defun (setf get-tensor-class-optimization) (value clname)
  (setf (gethash clname *tensor-class-optimizations*) value)
  (let ((opt (if (symbolp value)
		 (get-tensor-class-optimization-hashtable clname)
		 value)))
    (setf (symbol-plist clname) opt
	  (symbol-plist (getf opt :matrix)) opt
	  (symbol-plist (getf opt :vector)) opt)))

;; Akshay: I have no idea what this does, or why we want it
;; (inherited from standard-matrix.lisp
(defmethod make-load-form ((tensor standard-tensor) &optional env)
  "
  MAKE-LOAD-FORM allows us to determine a load time value for
  tensor, for example #.(make-tensors ...)"
  (make-load-form-saving-slots tensor :environment env))

;;
(defun store-indexing-vec (idx hd strides dims)
"
  Syntax
  ======
  (STORE-INDEXING-VEC IDX HD STRIDES DIMS)

  Purpose
  =======
  Does error checking to make sure IDX is not out of bounds.
  Returns the sum:

    length(STRIDES)
       __
  HD + \  STRIDE  * IDX
       /_        i      i
     i = 0
"
  (declare (type index-type hd)
	   (type index-store-vector idx strides dims))
  (let ((rank (length strides)))
    (declare (type index-type rank))
    (if (not (= rank (length idx) (length dims)))
	(error 'tensor-index-rank-mismatch :index-rank (length idx) :rank rank)
	(very-quickly
	  (loop
	     for i of-type index-type from 0 below rank
	     for cidx across idx
	     with sto-idx of-type index-type = hd
	     do (if (< -1 cidx (aref dims i))
		    (incf sto-idx (the index-type (* (aref strides i) cidx)))
		    (error 'tensor-index-out-of-bounds :argument i :index cidx :dimension (aref dims i)))
	     finally (return sto-idx))))))

(defun store-indexing-lst (idx hd strides dims)
"
  Syntax
  ======
  (STORE-INDEXING-LST IDX HD STRIDES DIMS)

  Purpose
  =======
  Does error checking to make sure idx is not out of bounds.
  Returns the sum:

    length(STRIDES)
       __
  HD + \  STRIDE  * IDX
       /_        i      i
     i = 0
"
  (declare (type index-type hd)
	   (type index-store-vector strides dims)
	   (type cons idx))
  (let ((rank (length strides)))
    (declare (type index-type rank))
    (labels ((rec-sum (sum i lst)
	       (cond
		 ((consp lst)
		  (let ((cidx (car lst)))
		    (declare (type index-type cidx))
		    (unless (< -1 cidx (aref dims i))
		      (error 'tensor-index-out-of-bounds :argument i :index cidx :dimension (aref dims i)))
		    (rec-sum (+ sum (* (aref strides i) cidx)) (1+ i) (cdr lst))))
		 ((and (null lst) (= i rank)) sum)
		 (t
		  (error 'tensor-index-rank-mismatch :index-rank (length idx) :rank rank)))))
      (rec-sum (the index-type hd) (the index-type 0) idx))))

(defun store-indexing (idx tensor)
"
  Syntax
  ======
  (STORE-INDEXING IDX TENSOR)

  Purpose
  =======
  Returns the linear index of the element pointed by IDX.
  Does error checking to make sure idx is not out of bounds.
  Returns the sum:

    length(STRIDES)
       __
  HD + \  STRIDES  * IDX
       /_        i      i
     i = 0
"
  (declare (type standard-tensor tensor)
	   (type (or index-store-vector cons) idx))
  (typecase idx
    (cons (store-indexing-lst idx (head tensor) (strides tensor) (dimensions tensor)))
    (vector (store-indexing-vec idx (head tensor) (strides tensor) (dimensions tensor)))))

;;
(defmethod initialize-instance :before ((tensor standard-tensor) &rest initargs)
  (assert (getf initargs :dimensions) nil 'invalid-arguments :argnum :dimensions
	  :message "Dimensions are necessary for creating the tensor object."))

(defmethod initialize-instance :after ((tensor standard-tensor) &rest initargs)
  (declare (ignore initargs))
  (let ((dims (dimensions tensor)))
    (when (consp dims)
      (setf (slot-value tensor 'dimensions) (make-index-store dims))))
  (mlet*
   (((dims hd ss) (slot-values tensor '(dimensions head store-size))
     :type (index-store-vector index-type index-type))
    (rank (length dims) :type index-type))
   ;;Let the object be consistent.
   (setf (rank tensor) rank)
   ;;Row-ordered by default.
   (unless (and (slot-boundp tensor 'strides)
		(= (length (strides tensor)) rank))
     (let-typed ((stds (allocate-index-store rank) :type index-store-vector))
         (setf (strides tensor) stds)
	 (very-quickly
	   (loop
	      :for i :downfrom (1- rank) :to 0
	      :and st = 1 :then (the index-type (* st (aref dims i)))
	      :do (setf (aref stds i) st)))))
   ;;
   (mlet* ((stds (strides tensor) :type index-store-vector)
	   (L-idx (store-indexing-vec (map `index-store-vector #'1- dims) hd stds dims) :type index-type))
	  ;;Error checking is good if we use foreign-pointers as store types.
	  (cond
	    ((< hd 0) (error 'tensor-invalid-head-value :head hd :tensor tensor))
	    ((<= ss L-idx) (error 'tensor-insufficient-store :store-size ss :max-idx L-idx :tensor tensor)))
	  ;;
	  ;;--*TODO: Add checks to see if there is index-collision.*--
	  ;;   This is a hard (NP ?) search problem
	  ;;   Note to future self: Come back here after experience with AI.
	  (dotimes (i rank)
	    (let ((ns (aref dims i))
		  (st (aref stds i)))
	      (cond
		((<= ns 0) (error 'tensor-invalid-dimension-value :argument i :dimension ns :tensor tensor))
		((< st 0) (error 'tensor-invalid-stride-value :argument i :stride st :tensor tensor))))))
   (setf (number-of-elements tensor) (reduce #'* dims))))

;;
(defgeneric tensor-store-ref (tensor store-idx)
  (:documentation "
  Syntax
  ======
  (tensor-ref-1d store store-idx)

  Purpose
  =======
  Return the element store-idx of the tensor store.")
  (:method :before ((tensor standard-tensor) idx)
	   (declare (type index-type idx))
	   (unless (< -1 idx (store-size tensor))
	     (error 'tensor-store-index-out-of-bounds :index idx :store-size (store-size tensor) :tensor tensor))))

(defgeneric (setf tensor-store-ref) (value tensor idx)
  (:method :before (value (tensor standard-tensor) idx)
	   (declare (type index-type idx))
	   (unless (< -1 idx (store-size tensor))
	     (error 'tensor-store-index-out-of-bounds :index idx :store-size (store-size tensor) :tensor tensor))))

(defmacro define-tensor
  ((tensor-class element-type store-element-type store-type &rest class-decls) &key
    f+ f- finv+ fid+ f* f/ finv* fid* fconj
    matrix vector
    store-allocator coercer coercer-unforgiving reader value-writer reader-writer swapper)
  ;;Error checking
  (assert (and f+ f- finv+ fid+ f* f/ finv* fid* store-allocator coercer coercer-unforgiving matrix vector reader value-writer reader-writer swapper))
  ;;
  `(progn
     ;;Class definitions
     (defclass ,tensor-class (standard-tensor)
       ((store :type ,store-type))
       ,@class-decls)
     (defclass ,matrix (standard-matrix ,tensor-class)
       ())
     (defclass ,vector (standard-vector ,tensor-class)
       ())
     ;;Store refs
     (defmethod tensor-store-ref ((tensor ,tensor-class) idx)
       (declare (type index-type idx))
       (let-typed ((store (store tensor) :type ,store-type))
		  (,reader store idx)))
     (defmethod (setf tensor-store-ref) (value (tensor ,tensor-class) idx)
       (declare (type index-type idx)
		(type ,element-type value))
       (let-typed ((store (store tensor) :type ,store-type))
		  (,value-writer value store idx)))
     ;;
     (let ((hst (list
		 :tensor ',tensor-class
		 :matrix ',matrix
		 :vector ',vector
		 :element-type ',element-type
		 :f+ ',f+
		 :f- ',f-
		 :finv+ ',finv+
		 :fid+ ',fid+
		 :f* ',f*
		 :f/ ',f/
		 :finv* ',finv*
		 :fid* ',fid*
		 :fconj ',fconj
		 :reader ',reader
		 :value-writer ',value-writer
		 :reader-writer ',reader-writer
		 :swapper ',swapper
		 :store-allocator ',store-allocator
		 :coercer ',coercer
		 :coercer-unforgiving ',coercer-unforgiving
		 :store-type ',store-element-type)))
       (setf (get-tensor-class-optimization ',tensor-class) hst
	     (get-tensor-class-optimization ',matrix) ',tensor-class
	     (get-tensor-class-optimization ',vector) ',tensor-class)
       (setf (symbol-plist ',tensor-class) hst))))

;;
(defgeneric tensor-ref (tensor subscripts)
  (:documentation "
  Syntax
  ======
  (tensor-ref store subscripts)

  Purpose
  =======
  Return the element:

    (rank - 1)
       __
  hd + \   stride  * sub
       /_        i      i
      i = 0

  of the store.")
  (:method ((tensor standard-tensor) subscripts)
    (let ((sto-idx (store-indexing subscripts tensor)))
      (tensor-store-ref tensor sto-idx))))

(defgeneric (setf tensor-ref) (value tensor subscripts)
  (:method ((value t) (tensor standard-tensor) subscripts)
    (let ((sto-idx (store-indexing subscripts tensor)))
      (setf (tensor-store-ref tensor sto-idx) value))))

;;
(defgeneric print-element (tensor
			   element stream)
  (:documentation "
  Syntax
  ======
  (PRINT-ELEMENT tensor element stream)

  Purpose
  =======
  This generic function is specialized to TENSOR to
  print ELEMENT to STREAM.  Called by PRINT-TENSOR/MATRIX
  to format a tensor into the STREAM.")
  (:method (tensor element stream)
    (format stream "~a" element)))

;;

(defun tensor-typep (tensor subscripts)
  "
  Syntax
  ======
  (tensor-typep tensor subscripts)

  Purpose
  =======
  Check if the given tensor is of a particular size in particular
  arguments.

  Examples
  ========
  Checking for a vector:
  > (tensor-typep ten '(*))

  Checking for a matrix with 2 columns:
  > (tensor-typep ten '(* 2))

  Also does symbolic association; checking for
  a square matrix:
  > (tensor-typep ten '(a a))
  "
  (declare (type standard-tensor tensor))
  (mlet* (((rank dims) (slot-values tensor '(rank dimensions))
	   :type (index-type index-store-vector)))
	 (let ((syms->val (make-hash-table)))
	   (labels ((parse-sub (lst i)
		      (let ((val (car lst)))
			(cond
			  ((= i rank) t)
			  ((null val) nil)
			  ((eq val '*) (parse-sub (cdr lst) (1+ i)))
			  (t (progn
			       (when (symbolp val)
				 (multiple-value-bind (hash-val existp) (gethash val syms->val)
				   (if existp
				       (setq val hash-val)
				       (setf (gethash val syms->val) (aref dims i)
					     val (aref dims i)))))
			       (if (= val (aref dims i))
				   (parse-sub (cdr lst) (1+ i))
				   nil)))))))
	     (parse-sub subscripts 0)))))

(definline matrix-p (ten)
  (declare (type standard-tensor ten))
  (= (slot-value ten 'rank) 2))

(definline vector-p (ten)
  (declare (type standard-tensor ten))
  (= (slot-value ten 'rank) 1))

(definline square-p (tensor)
  (let-typed ((dims (dimensions tensor) :type index-store-vector))
    (lvec-foldr #'(lambda (a b) (if (eq a b) a nil)) dims)))

;;---------------------------------------------------------------;;

(define-constant +array-slicing-symbols+ '(\:)
"
  Symbols which are used to refer to slicing operations.")

(defun sub-tensor~ (tensor subscripts &optional (preserve-rank nil))
"
  Syntax
  ======
  (SUB-TENSOR~ TENSOR SUBSCRIPTS)

  Purpose
  =======
  Creates a new tensor data structure, sharing store with
  TENSOR but with different strides and dimensions, as defined
  in the subscript-list SUBSCRIPTS.

  Examples
  ========
  > (defvar X (make-real-tensor 10 10 10))
  X

  ;; Get [:, 0, 0]
  > (sub-tensor~ X '(\: 0 0))

  ;; Get [:, 2:5, :]
  > (sub-tensor~ X '(\: (\: 2 5) \:))

  ;; Get [:, :, 0:10:2] (0:10:2 = [i : 0 <= i < 10, i % 2 = 0])
  > (sub-tensor~ X '(\: \: ((\: 2) 0 *)))
"
  (declare (type standard-tensor tensor)
	   (type list subscripts)
	   (type boolean preserve-rank))
  (let ((rank (rank tensor))
	(dims (dimensions tensor))
	(stds (strides tensor))
	(hd (head tensor)))
    (declare (type index-type rank hd)
	     (type index-store-vector dims stds))
    (labels ((sub-tread (i subs nhd ndims nstds)
	       (if (null subs)
		   (progn
		     (assert (= i rank) nil 'tensor-index-rank-mismatch
			     :index-rank i :rank rank)
		     (values nhd (nreverse ndims) (nreverse nstds)))
		   (let ((csub (car subs)))
		     (cond
		       ((or (consp csub)
			    (and (symbolp csub) (member csub +array-slicing-symbols+)))
			(destructuring-bind ((op &optional (step 1)) &optional (ori 0) (end (aref dims i))) (if (consp csub)
														(cons (ensure-list (car csub)) (cdr csub))
														(list (ensure-list csub)))
			  (assert (and (typep ori 'index-type) (< -1 ori (aref dims i))) nil 'tensor-index-out-of-bounds
				  :argument i :index ori :dimension (aref dims i))
			  (assert (and (typep ori 'index-type) (< ori end (1+ (aref dims i)))) nil 'invalid-value
				  :given end :expected `(> ,ori end ,(1+ (aref dims i))) :message "END is outside allowed bounds.")
			  (assert (and (typep step 'index-type) (< 0 step)) nil 'invalid-value
				  :given step :expected '(< 0 step) :message "STEP cannot be <= 0.")
			  (assert (member op +array-slicing-symbols+) nil 'invalid-value
				  :message "Cannot find OP in +array-slicing-symbols+"
				  :given op :expected `(member op ,+array-slicing-symbols+))
			  (let ((dim (ceiling (- end ori) step)))
			    (sub-tread (1+ i) (cdr subs) (+ nhd (* ori (aref stds i)))
				       (if (and (= dim 1) (not preserve-rank)) ndims (cons dim ndims))
				       (if (and (= dim 1) (not preserve-rank)) nstds (cons (* step (aref stds i)) nstds))))))
		       ((typep csub 'index-type)
			(assert (< -1 csub (aref dims i)) nil 'tensor-index-out-of-bounds
				:argument i :index csub :dimension (aref dims i))
			(sub-tread (1+ i) (cdr subs) (+ nhd (* csub (aref stds i)))
				   (if (not preserve-rank) ndims (cons 1 ndims))
				   (if (not preserve-rank) nstds (cons (aref stds i) nstds))))
		       (t
			(error 'parser-error :message "Error parsing subscript-list.")))))))
      (multiple-value-bind (nhd ndim nstd) (sub-tread 0 subscripts hd nil nil)
	(if (null ndim) (tensor-store-ref tensor nhd)
	    (make-instance
	     (let ((nrnk (length ndim)))
	       (if (> nrnk 2) (class-name (class-of tensor))
		   (let ((cocl (getf (symbol-plist (class-name (class-of tensor))) (ecase nrnk (2 :matrix) (1 :vector)))))
		     (assert cocl nil 'tensor-cannot-find-optimization :tensor-class (class-name (class-of tensor)))
		     cocl)))
	     :parent-tensor tensor :store (store tensor) :head nhd
	     :dimensions (make-index-store ndim) :strides (make-index-store nstd)))))))

