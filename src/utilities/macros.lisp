(in-package #:matlisp-utilities)

(eval-when (:compile-toplevel :load-toplevel :execute)
;;Note to self: do not indent!

(defmacro define-constant (name value &optional doc)
  "
  Keeps the lisp implementation from defining constants twice.
  "
  `(defconstant ,name (if (boundp ',name) (symbol-value ',name) ,value)
     ,@(when doc (list doc))))

(defmacro with-gensyms (symlist &body body)
  "
  Binds every variable in @arg{symlist} to a (gensym).

  Example:
  @lisp
  > (macroexpand-1
       `(with-gensyms (a b c)
	   `(let ((,a 1) (,b 2) (,c 3))
		 (+ ,a ,b ,c))))
  => (LET ((A (GENSYM \"A\")) (B (GENSYM \"B\")) (C (GENSYM \"C\")))
      `(LET ((,A 1) (,B 2) (,C 3))
	  (+ ,A ,B ,C)))
  @end lisp
  "
  `(let ,(mapcar #'(lambda (sym)
		     `(,sym (gensym ,(symbol-name sym))))
		 symlist)
     ,@body))

(defmacro using-gensyms ((decl (&rest syms) &optional gensyms) &rest body)
  `(let ((,decl (zip ',(mapcar #'(lambda (x) (gensym (symbol-name x))) syms) (list ,@syms))))
     (destructuring-bind (,@syms) (mapcar #'car ,decl)
       ,(append
	 (if gensyms
	   `(with-gensyms (,@gensyms)) `(progn))
	 body))))

(defmacro binding-gensyms ((mname &optional (fname (gensym))) &rest body)
  (with-gensyms (htbl)
    `(let ((,htbl (make-hash-table)))
       (labels ((,fname (x) (or (gethash x ,htbl) (setf (gethash x ,htbl) (gensym (symbol-name x))))))
	 (macrolet ((,mname (x) `(,', fname ',x)))
	   ,@body)))))

(defmacro ziprm ((r m) &rest args)
  "
  Does reduce-map on @arg{args}.

  Example:
  @lisp
  > (macroexpand-1
       `(ziprm (and =) (a b c) (1 2 3)))
  => (AND (= A 1) (= B 2) (= C 3))
  @end lisp
  "
  `(,r ,@(apply #'mapcar #'(lambda (&rest atoms) (cons m atoms)) (mapcar #'ensure-list args))))
;;
(defmacro cart-case ((&rest vars) &body cases)
  (let ((decl (zipsym vars)))
    `(let (,@decl)
       (cond ,@(mapcar #'(lambda (clause) `((ziprm (and eql) ,(mapcar #'car decl) ,(first clause)) ,@(cdr clause))) cases)))))

(defmacro cart-ecase ((&rest vars) &body cases)
  (let ((decl (zipsym vars)))
    `(let (,@decl)
       (cond ,@(mapcar #'(lambda (clause) `((ziprm (and eql) ,(mapcar #'car decl) ,(first clause)) ,@(cdr clause))) cases)
	 (t (error "cart-ecase: Case failure."))))))

(defmacro cart-typecase (vars &body cases)
  (let* ((decl (zipsym vars)))
    `(let (,@decl)
       (cond ,@(mapcar #'(lambda (clause) `((ziprm (and typep) ,(mapcar #'car decl) ,(mapcar #'(lambda (x) `(quote ,x)) (first clause))) ,@(cdr clause))) cases)))))

(defmacro cart-etypecase (vars &body cases)
  (let* ((decl (zipsym vars)))
    `(let (,@decl)
       (cond ,@(mapcar #'(lambda (clause) `((ziprm (and typep) ,(mapcar #'car decl) ,(mapcar #'(lambda (x) `(quote ,x)) (first clause))) ,@(cdr clause))) cases)
	     (t (error "cart-etypecase: Case failure."))))))
;;
(defmacro values-n (n &rest values)
  (using-gensyms (decl (n))
    (labels ((make-cd (i rets vrets)
	       `((let ((,(first (car rets)) ,(maptree '(values-n previous-value) #'(lambda (x) (case (car x)
												 (values-n x)
												 (previous-value
												  (destructuring-bind (&optional (idx (- i 2))) (cdr x)
												    (assert (< -1 idx (length vrets)) nil 'invalid-arguments)
												    (elt (reverse vrets) idx)))))
						      (second (car rets)))))
		   ,(recursive-append
		     (when (cdr rets)
		       `(if (> ,n ,i) ,@(make-cd (1+ i) (cdr rets) (cons (caar rets) vrets))))
		     `(values ,@(reverse vrets) ,(caar rets)))))))
      `(let (,@decl)
	 (when (> ,n 0)
	   ,@(make-cd 1 (zipsym values) nil))))))

(defmacro letv* (bindings &rest body)
  "
  This macro extends the syntax of let* to handle multiple values and destructuring bind,
  it also handles type declarations. The declarations list @arg{vars} is similar to that in let:
  look at the below examples.

  Examples:
  @lisp
  > (macroexpand-1 `(letv* ((x 2 :type fixnum)
                            ((a &optional (c 2)) b (values (list 1) 3) :type (fixnum &optional (t)) t))
                      t))
  => (LET ((X 2))
           (DECLARE (TYPE FIXNUM X))
       (MULTIPLE-VALUE-BIND (#:G1120 B) (VALUES (LIST 1) 3)
         (DECLARE (TYPE T B))
         (DESTRUCTURING-BIND (A &OPTIONAL (C 2)) #:G1120
           (DECLARE (TYPE FIXNUM A)
                    (TYPE T C))
           (PROGN T))))
  @end lisp
  "
  (labels ((typedecl (syms alist)
	     (let ((decls (remove-if #'null (mapcar #'(lambda (s)
							(let ((ts (assoc s alist)))
							  (when ts
							    (if (cdr ts)
								`(type ,(cdr ts) ,s)
								`(ignore ,s)))))
						    syms))))
	       (when decls `((declare ,@decls))))))
    (apply #'recursive-append
	   (append
	    (mapcan #'(lambda (x)
			(destructuring-bind (bind expr type) (let ((tpos (position :type x)) (len (length x)))
							       (list (subseq x 0 (1- (or tpos len))) (nth (1- (or tpos len)) x) (when tpos (nthcdr (1+ tpos) x))))
			  (let* ((typa (iter (for (s ty) on (flatten (ziptree bind type)))
					     (with skip? = nil)
					     (if (or skip? (null s)) (setf skip? nil)
						 (progn (setf skip? t)
							(unless (member s cl:lambda-list-keywords)
							  (collect (cons s ty)))))))
				 (vsyms (mapcar #'(lambda (x) (if (consp x)
								  (let ((g (gensym)))
								    (list g
									  `(destructuring-bind (,@x) ,g
									     ,@(typedecl (flatten x) typa))))
								  (list x)))
						bind)))
			    (list*
			     (recursive-append
			      (if (> (length bind) 1)
				  `(multiple-value-bind (,@(mapcar #'car vsyms)) ,expr)
				  `(let ((,@(mapcar #'car vsyms) ,expr))))
			      (car (typedecl (mapcar #'car vsyms) typa)))
			     (remove-if #'null (mapcar #'cadr vsyms))))))
		    bindings)
	    `((progn ,@body))))))

(defmacro let-typed (bindings &rest body)
  "
  This macro works basically like let, but also allows type-declarations
  with the key :type.

  Example:
  @lisp
  > (macroexpand-1
      `(let-typed ((x 1 :type fixnum))
	  (+ 1 x)))
  => (LET ((X 1))
	(DECLARE (TYPE FIXNUM X))
	(+ 1 X))
  @end lisp
  "
  `(let (,@(mapcar #'(lambda (x) (subseq x 0 2)) bindings))
     ,@(let ((types (remove-if #'null (mapcar #'(lambda (x) (destructuring-bind (s e &key (type t)) x
							      (declare (ignore e))
							      (unless (eql type t)
								(if (null type)
								    `(ignore ,s)
								    `(type ,type ,s)))))
					      bindings))))
	    (when types `((declare ,@types))))
     ,@body))

(defmacro let*-typed (bindings &rest body)
  "
  This macro works basically like let*, but also allows type-declarations
  with the key :type.

  Example:
  @lisp
  > (macroexpand-1
      `(let*-typed ((x 1 :type fixnum))
	  (+ 1 x)))
  => (LET* ((X 1))
	(DECLARE (TYPE FIXNUM X))
	(+ 1 X))
  @end lisp
  "
  `(let* (,@(mapcar #'(lambda (x) (subseq x 0 2)) bindings))
     ,@(let ((types (remove-if #'null
			       (mapcar #'(lambda (x) (destructuring-bind (s e &key (type t)) x
						       (declare (ignore e))
						       (unless (eql type t)
							 (if (null type)
							     `(ignore ,s)
							     `(type ,type ,s)))))
				       bindings))))
	    (when types `((declare ,@types))))
     ,@body))

(defmacro if-ret (form &rest else-body)
  "
  If @arg{form} evaluates to non-nil, it is returned, else
  the s-expression @arg{else-body} is evaluated.

  Example:
  @lisp
  > (macroexpand-1
      `(if-ret (when (evenp x) x)
	     (+ x 1)))
  => (LET ((#:G927 (WHEN (EVENP X) X)))
	 (OR #:G927 (PROGN (+ X 1))))
  @end lisp
  "
  (let ((ret (gensym)))
    `(let ((,ret ,form))
       (or ,ret
	   (progn
	     ,@else-body)))))

(defmacro when-let ((var . form) &rest body)
  "
  Binds the result of @arg{form} to the symbol @arg{var}; if this value
  is non-nil, the s-expression @arg{body} is executed.

  Example:
  @lisp
  > (macroexpand-1
      `(when-let (parity (evenp x))
	     (+ x 1)))
  => (LET ((PARITY (EVENP X)))
	(WHEN PARITY (+ X 1)))
  @end lisp
  "
  (check-type var symbol)
  `(let ((,var ,@form))
     (when ,var
       ,@body)))

(defmacro if-let ((var . form) &rest body)
  "
  Binds the result of @arg{form} to the symbol @arg{var}; this value
  is used immediately in an if-statement with the usual semantics.

  Example:
  @lisp
  > (macroexpand-1
      `(if-let (parity (evenp x))
	     (+ x 1)
	     x))
  => (LET ((PARITY (EVENP X)))
	(IF PARITY
	   (+ X 1)
	   X))
  @end lisp
  "
  (check-type var symbol)
  `(let ((,var ,@form))
     (if ,var
	 ,@body)))

(defmacro definline (name &rest rest)
  "
  Creates a function and declaims them inline: short form for defining an inlined function.

  Example:
  @lisp
  > (macroexpand-1 `(definline f (a b) (+ a b)))
  => (INLINING (DEFUN F (A B) (+ A B)))
  "
  `(progn
     (declaim (inline ,name))
     (defun ,name ,@rest)))

;;---------------------------------------------------------------;;
;; Optimization
;;---------------------------------------------------------------;;
(defmacro with-optimization ((&rest args) &body forms)
  "
  Macro creates a local environment with optimization declarations, and
  executes form.

  Example:
  @lisp
  > (macroexpand-1
      `(with-optimization (:speed 2 :safety 3)
	  (+ 1d0 2d0)))
  => (LOCALLY (DECLARE (OPTIMIZE (SPEED 2) (SAFETY 3))) (+ 1.0d0 2.0d0))
  @end lisp
  "
  `(locally
       ,(recursive-append
	 `(declare (optimize ,@(multiple-value-call #'mapcar #'(lambda (key val) (list (intern (symbol-name key)) val))
						    (loop :for ele :in args
						       :counting t :into cnt
						       :if (oddp cnt)
							 :collect ele into key
						       :else
							 :collect (progn (assert (member ele '(0 1 2 3))) ele) into val
						       :finally (return (values key val))))))
	 (when (and (consp (car forms)) (eq (caar forms) 'declare))
	   (cdar forms)))
     ,@(if (and (consp (car forms)) (eq (caar forms) 'declare)) (cdr forms) forms)))

(defmacro very-quickly (&body forms)
  "
  Macro which encloses @arg{forms} inside
  (declare (optimize (speed 3) (safety 0) (space 0)))
  "
  #+matlisp-debug
  `(with-optimization
       #+lispworks
       (:safety 3)
       #-lispworks
       (:safety 3)
     ,@forms)
  #-matlisp-debug
  `(with-optimization
       #+lispworks
       (:safety 0 :space 0 :speed 3 :float 0 :fixnum-safety 0)
       #-lispworks
       (:safety 0 :space 0 :speed 3)
     ,@forms))

(defmacro eval-every (&body forms)
  `(eval-when (:compile-toplevel :load-toplevel :execute)
     ,@forms))

;;
(defmacro with-fslots (slots instance &rest body)
  (with-gensyms (obj args)
    `(let ((,obj ,instance))
       (flet (,@(mapcar #'(lambda (decl)
			    (destructuring-bind (name slot-name) (if (consp decl) decl (list decl decl))
			      `(,name (&rest ,args) (apply (the function (slot-value ,obj ',slot-name)) ,args))))
			slots))
	 ,@body))))

(defmacro with-marking (&rest body)
  "
 This macro basically declares local-variables globally,
 while keeping semantics and scope local.

Example:
  > (macroexpand-1
      `(with-marking
	   (loop :for i := 0 :then (1+ i)
	      :do (mark* ((xi (* 10 2) :type index-type)
			  (sum 0 :type index-type))
			 (incf sum (mark (* 10 2)))
			 (if (= i 10)
			     (return sum))))))

      (LET* ((#:G1083 (* 10 2)) (#:SUM1082 0) (#:XI1081 (* 10 2)))
	(DECLARE (TYPE INDEX-TYPE #:SUM1082)
		 (TYPE INDEX-TYPE #:XI1081))
	(LOOP :FOR I := 0 :THEN (1+ I)
	      :DO (SYMBOL-MACROLET ((XI #:XI1081) (SUM #:SUM1082))
		    (INCF SUM #:G1083)
		    (IF (= I 10)
			(RETURN SUM)))))
     T
  >
"
  (let* ((decls nil)
	 (types nil)
	 (code (maptree '(:mark* :mark :memo)
			#'(lambda (mrk)
			    (ecase (car mrk)
			      (:mark*
			       `(symbol-macrolet (,@(mapcar #'(lambda (decl) (destructuring-bind (ref code &key type) decl
									       (let ((rsym (gensym (symbol-name ref))))
										 (push `(,rsym ,code) decls)
										 (when type
										   (push `(type ,type ,rsym) types))
										 `(,ref ,rsym))))
							    (cadr mrk)))
				  ,@(cddr mrk)))
			      (:mark
			       (destructuring-bind (code &key type) (cdr mrk)
				 (let ((rsym (gensym)))
				   (push `(,rsym ,code) decls)
				   (when type
				     (push `(type ,type ,rsym) types))
				   rsym)))
			      (:memo
			       (destructuring-bind (code &key type) (cdr mrk)
				 (let ((memo (find code decls :key #'cadr :test #'tree-equal)))
				   (if memo
				       (car memo)
				       (let ((rsym (gensym)))
					 (push `(,rsym ,code) decls)
					 (when type
					   (push `(type ,type ,rsym) types))
					 rsym)))))))
			body)))
    `(let* (,@decls)
       ,@(when types `((declare ,@types)))
       ,@code)))

(defmacro make-array-allocator (allocator-name type init &optional doc)
  `(eval-when (:compile-toplevel :load-toplevel :execute)
     (definline ,allocator-name (size &optional (initial-element ,init))
       ,@(unless (null doc)
		 `(,doc))
       (make-array size
		   :element-type ,type :initial-element initial-element))))

(defmacro nconsc (var &rest args)
  "
  Macro to do setf and nconc for destructive list updates. If @arg{var}
  is null then @arg{var} is set to (apply #'nconc @arg{args}), else
  does (apply #'nconc (cons @arg{var} @arg{args})).

  Example:
  @lisp
  > (let ((x nil))
      (nconsc x (list 1 2 3) (list 'a 'b 'c))
      x)
  => (1 2 3 A B C)

  > (let ((x (list 'a 'b 'c)))
      (nconsc x (list 1 2 3))
       x)
  => (A B C 1 2 3)
  @end lisp
  "
  (assert (and (symbolp var) (not (member var '(t nil)))))
  (if (null args) var
      `(if (null ,var)
	   (progn
	     (setf ,var ,(car args))
	     (nconc ,var ,@(cdr args)))
	   (nconc ,var ,@args))))

(defmacro macrofy (lambda-func)
  "
  Macrofies a lambda function, for use later inside macros (or for symbolic math ?).
  Returns a macro-function like function which can be called later for use inside
  macros.

  DO NOT USE backquotes in the lambda function!

  Example:
  @lisp
  > (macroexpand-1 `(macrofy (lambda (x y z) (+ (sin x) y (apply #'cos (list z))))))
  =>   (LAMBDA (X Y Z)
	   (LIST '+ (LIST 'SIN X) Y (LIST 'APPLY (LIST 'FUNCTION 'COS) (LIST 'LIST Z))))
  T

  > (funcall (macrofy (lambda (x y z) (+ (sin x) y (apply #'cos (list z))))) 'a 'b 'c)
  => (+ (SIN A) B (APPLY #'COS (LIST C)))

  @end lisp
  "
  (destructuring-bind (labd args &rest body) lambda-func
    (assert (eq labd 'lambda))
    `(lambda ,args ,@(cdr (unquote-args body args)))))

)
