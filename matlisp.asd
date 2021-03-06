;;; -*- Mode: lisp; Syntax: ansi-common-lisp; Base: 10 -*-
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Copyright (c) 2000 The Regents of the University of California.
;;; All rights reserved.
;;;
;;; Permission is hereby granted, without written agreement and without
;;; license or royalty fees, to use, copy, modify, and distribute this
;;; software and its documentation for any purpose, provided that the
;;; above copyright notice and the following two paragraphs appear in all
;;; copies of this software.
;;;
;;; IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY
;;; FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES
;;; ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF
;;; THE UNIVERSITY OF CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF
;;; SUCH DAMAGE.
;;;
;;; THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
;;; INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
;;; MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE
;;; PROVIDED HEREUNDER IS ON AN "AS IS" BASIS, AND THE UNIVERSITY OF
;;; CALIFORNIA HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT, UPDATES,
;;; ENHANCEMENTS, OR MODIFICATIONS.
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(in-package #:common-lisp-user)
(defpackage #:matlisp-system (:use #:cl :asdf))
(in-package #:matlisp-system)

(asdf:defsystem :matlisp-basic
  :depends-on (#:cffi #:iterate #:optima #:named-readtables #:lambda-reader #:yacc #:trivial-garbage)
  :pathname "src"
  :components
  ((:file "packages")
   (:file "conditions" :depends-on ("packages"))
   (:module "utilities" 
	    :pathname "utilities" :depends-on ("conditions")
	    :components ((:file "functions")
			 (:file "string")
			 (:file "macros" :depends-on ("functions"))
			 (:file "dlist" :depends-on ("macros" "functions"))
			 (:file "lvec" :depends-on ("macros" "functions"))
			 (:file "template" :depends-on ("macros" "functions"))))
   (:file "lazy-loader" :depends-on ("utilities"))))

(asdf:defsystem :matlisp
  :depends-on ("matlisp-basic")
  :pathname "src"
  :components
  ((:module "foreign-interface"
	    :pathname "ffi"
	    :components ((:file "foreign-vector")
			 (:file "cffi")
			 (:file "ffi")
			 #+nil(:file "f77-parser")))
   (:module "matlisp-base"
	    :pathname "base"
	    :components ((:file "tweakable")
			 (:file "base-tensor")
			 (:file "numeric-template")
			 (:file "tensor-template")
			 (:file "standard-tensor"
				:depends-on ("tweakable" "base-tensor" "numeric-template" "tensor-template"))
			 ;;
			 (:file "loopy"
				:depends-on ("standard-tensor"))
			 (:file "einstein"
				:depends-on ("standard-tensor"))
			 (:file "generic-copy"
				:depends-on ("standard-tensor" "loopy"))
			 (:file "generic-swap"
				:depends-on ("standard-tensor" "loopy"))
			 (:file "permutation"
				:depends-on ("standard-tensor" "generic-copy" "generic-swap"))
			 (:file "blas-helpers"
				:depends-on ("standard-tensor" "permutation"))
			 (:file "print"
				:depends-on ("base-tensor" "standard-tensor"))
			 (:file "coordinate-sparse")
			 (:file "compressed-sparse")))
   (:module "matlisp-classes"
	    :pathname "classes"
	    :depends-on ("matlisp-base")
	    :components ((:file "numeric")
			 (:file "sparse")
			 #+maxima
			 (:file "symbolic-tensor")
			 (:file "matrix"
				:depends-on ("numeric"))))
   (:module "matlisp-blas"
	    :pathname "blas"
	    :depends-on ("matlisp-base" "matlisp-classes")
	    :components ((:file "maker")
			 (:file "copy"
				:depends-on ("maker"))
			 (:file "dot"
				:depends-on ("maker"))
			 (:file "swap")
			 (:file "axpy"
				:depends-on ("maker" "copy"))
			 (:file "scal"
				:depends-on ("copy" "maker"))
			 (:file "realimag"
				:depends-on ("copy"))
			 (:file "trans"
				:depends-on ("scal" "copy"))
			 (:file "sum"
				:depends-on ("dot" "copy"))
			 (:file "gemv"
				:depends-on ("copy"))
			 (:file "ger"
				:depends-on ("copy"))
			 (:file "gemm"
				:depends-on ("copy"))
			 (:file "trsm")))
   (:module "matlisp-lapack"
	    :pathname "lapack"
	    :depends-on ("matlisp-base" "matlisp-classes" "matlisp-blas")
	    :components ((:file "lu")
			 (:file "chol")
			 (:file "eig")
			 (:file "least-squares")
			 #+nil(:file "qr")
			 (:file "schur")
			 (:file "svd")
			 (:file "syl" :depends-on ("schur"))))
   (:module "matlisp-special"
	    :pathname "special"
	    :depends-on ("matlisp-base" "matlisp-classes" "matlisp-blas")
	    :components ((:file "random")
			 (:file "map")
			 (:file "norm")
			 (:file "seq")))
   (:module "matlisp-sugar"
	    :pathname "sugar"
	    :depends-on ("matlisp-base" "matlisp-classes" "matlisp-blas")
	    :components ((:file "arithmetic")
			 (:file "oneseye")))
   (:module "matlisp-reader"
	    :pathname "reader"
	    :components ((:file "infix")
			 (:file "loadsave")))
   (:module "matlisp-graph"
	    :pathname "graph"
	    :depends-on ("matlisp-base" "matlisp-classes" "matlisp-blas" #+nil"matlisp-lapack")
	    :components ((:file "fibonacci")))))

;; (defclass f2cl-cl-source-file (asdf:cl-source-file)
;;   ())

;; (defmethod asdf:source-file-type ((f f2cl-cl-source-file) (m asdf:module))
;;   "l")

;; (asdf:defsystem matlisp-f2cl-macros
;;     :pathname #.(translate-logical-pathname "matlisp:srcdir;lib-src;")
;;     :depends-on ("matlisp-packages")
;;     :default-component-class f2cl-cl-source-file
;;     :components
;;     ((:file "macros")))

;; (asdf:defsystem matlisp
;;     :pathname #.(translate-logical-pathname "matlisp:srcdir;")
;;     :depends-on ("lazy-loader"
;;		 "matlisp-packages"
;;		 "matlisp-utilities"
;;		 "fortran-names"
;;		 "matlisp-f2cl-macros")
;;       :components
;;       ((:module "foreign-interface"
;;	:pathname "src/"
;;	:components ((:file "ffi-cffi")
;;		     (:file "ffi-cffi-interpreter-specific")
;;		     ))
;;        (:module "foreign-functions"
;;	:pathname "src/"
;;	:depends-on ("foreign-interface")
;;	:components ((:file "blas")
;;		     (:file "lapack")
;;		     (:file "dfftpack")
;;		     #+nil (:file "ranlib")))
;;        (:module "matlisp-essentials"
;;	:pathname "src/"
;;	:depends-on ("foreign-interface"
;;		     "foreign-functions")
;;	:components ((:file "conditions")
;;		     (:file "standard-matrix")
;;		     (:file "real-matrix"
;;			    :depends-on ("standard-matrix"))
;;		     (:file "complex-matrix"
;;			    :depends-on ("standard-matrix"))
;;		     ;; (:file "ref"
;;		     ;;		    :depends-on ("matrix"))
;;		     (:file "copy"
;;			    :depends-on ("standard-matrix"))
;;		     (:file "print"
;;			    :depends-on ("standard-matrix"))))

;;        (:module "matlisp-blas-wrappers"
;;	:pathname "src/"
;;	:depends-on ("foreign-interface"
;;		     "foreign-functions"
;;		     "matlisp-essentials")
;;	:components ((:file "axpy")
;;		     (:file "scal")
;;		     (:file "swap")
;;		     (:file "gemv")
;;		     (:file "gemm")))

;;        (:module "matlisp-lapack-wrappers"
;;	:pathname "src/"
;;	:depends-on ("foreign-interface"
;;		     "foreign-functions"
;;		     "matlisp-essentials")
;;	:components ((:file "gels")
;;		     (:file "gesv")
;;		     (:file "geev")
;;		     (:file "getrf")
;;		     (:file "getrs")
;;		     (:file "potrf")
;;		     (:file "potrs")))

;;        (:module "matlisp-functions"
;;         :pathname "src/"
;;	:depends-on ("foreign-interface"
;;		     "foreign-functions"
;;		     "matlisp-essentials"
;;		     "matlisp-blas-wrappers"
;;		     "matlisp-lapack-wrappers")
;;	:components ((:file "compat")
;;		     (:file "help")
;;		     (:file "special")
;;		     (:file "reader")
;;		     (:file "trans")
;;		     (:file "realimag")
;;		     (:file "submat")
;;		     (:file "reshape")
;;		     (:file "join")
;;		     (:file "svd")
;;		     (:file "sum")
;;		     (:file "norm")
;;		     (:file "dot")
;;		     (:file "trace")
;;		     (:file "seq")
;;		     (:file "vec")
;;		     (:file "map")
;;		     (:file "mplus")
;;		     (:file "mminus")
;;		     (:file "mtimes")
;;		     (:file "mdivide")
;;		     (:file "msqrt")
;;		     (:file "fft")
;;		     (:file "geqr")))
;;        (:module "special-functions"
;;		:pathname "src/"
;;		:depends-on ("matlisp-functions")
;;		:components
;;		((:file "specfun")))))

;; Add-on packages
;; (asdf:defsystem matlisp-quadpack
;;   :pathname #.(translate-logical-pathname "matlisp:srcdir;")
;;   :depends-on ("matlisp-f2cl-macros")
;;   :components
;;   ((:module "quadpack-interface"
;;	    :pathname "src/"
;;	    :components
;;	    ((:file "quadpack")))
;;    (:module "lib-src"
;;	    :components
;;	    ((:module "quadpack"
;;		      :components
;;		      (
;;		       ;; Support
;;		       (:file "dqwgtf")
;;		       (:file "dqcheb")
;;		       (:file "dqk15w")
;;		       (:file "dqwgts")
;;		       (:file "dqwgtc")
;;		       (:file "dgtsl")
;;		       (:file "xerror")

;;		       ;; Core integration routines
;;		       (:file "dqk15")
;;		       (:file "dqk31")
;;		       (:file "dqk41")
;;		       (:file "dqk51")
;;		       (:file "dqk61")
;;		       (:file "dqk21")
;;		       (:file "dqk15i")
;;		       (:file "dqelg")
;;		       (:file "dqpsrt")
;;		       (:file "dqc25s"
;;			      :depends-on ("dqcheb" "dqk15w"))
;;		       (:file "dqmomo")
;;		       (:file "dqc25c"
;;			      :depends-on ("dqcheb"
;;					   "dqk15w"))
;;		       (:file "dqc25f"
;;			      :depends-on ("dgtsl"
;;					   "dqcheb"
;;					   "dqk15w"
;;					   "dqwgtf"))
;;		       ;; Basic integrators
;;		       (:file "dqage"
;;			      :depends-on ("dqk15"
;;					   "dqk31"
;;					   "dqk41"
;;					   "dqk51"
;;					   "dqk61"
;;					   "dqk21"
;;					   "dqpsrt"))
;;		       (:file "dqagie"
;;			      :depends-on ("dqelg"
;;					   "dqk15i"
;;					   "dqpsrt"))
;;		       (:file "dqagpe"
;;			      :depends-on ("dqelg"
;;					   "dqpsrt"
;;					   "dqk21"
;;					   ))
;;		       (:file "dqagse"
;;			      :depends-on ("dqk21"
;;					   "dqelg"
;;					   "dqpsrt"))
;;		       (:file "dqawfe"
;;			      :depends-on ("dqagie"
;;					   "dqawoe"
;;					   "dqelg"))
;;		       (:file "dqawoe"
;;			      :depends-on ("dqc25f"
;;					   "dqpsrt"
;;					   "dqelg"))
;;		       (:file "dqawse"
;;			      :depends-on ("dqc25s"
;;					   "dqmomo"
;;					   "dqpsrt"))
;;		       (:file "dqawce"
;;			      :depends-on ("dqc25c"
;;					   "dqpsrt"))
;;		       ;; Simplified interface routines
;;		       (:file "dqng"
;;			      :depends-on ("xerror"))
;;		       (:file "dqag"
;;			      :depends-on ("dqage"
;;					   "xerror"))
;;		       (:file "dqags"
;;			      :depends-on ("dqagse"
;;					   "xerror"))
;;		       (:file "dqagi"
;;			      :depends-on ("dqagie"
;;					   "xerror"))
;;		       (:file "dqawf"
;;			      :depends-on ("dqawfe"
;;					   "xerror"))
;;		       (:file "dqawo"
;;			      :depends-on ("dqawoe"
;;					   "xerror"))
;;		       (:file "dqaws"
;;			      :depends-on ("dqawse"
;;					   "xerror"))
;;		       (:file "dqawc"
;;			      :depends-on ("dqawce"
;;					   "xerror"))))))))

;; (asdf:defsystem matlisp-minpack
;;   :pathname #.(translate-logical-pathname "matlisp:srcdir;")
;;   :depends-on ("matlisp-f2cl-macros")
;;   :components
;;   ((:module "lib-src"
;;	    :components
;;	    ((:module "minpack"
;;		      :components
;;		      ((:file "dpmpar")
;;		       (:file "enorm")
;;		       (:file "fdjac2")
;;		       (:file "qrsolv")
;;		       (:file "lmpar")
;;		       (:file "qrfac")
;;		       (:file "lmdif")
;;		       (:file "lmdif1")
;;		       (:file "lmder")
;;		       (:file "lmder1")
;;		       (:file "dogleg")
;;		       (:file "qform")
;;		       (:file "r1mpyq")
;;		       (:file "r1updt")
;;		       (:file "hybrj" :depends-on ("dogleg" "qform" "r1mpyq" "r1updt"))
;;		       (:file "hybrj1" :depends-on ("hybrj"))
;;		       ))))))

;; (asdf:defsystem matlisp-odepack
;;   :pathname #.(translate-logical-pathname "matlisp:srcdir;")
;;   :depends-on ("matlisp-f2cl-macros")
;;   :components
;;   ((:module "src"
;;     :components
;;	    ((:file "dlsode")))))

;; (asdf:defsystem matlisp-colnew
;;   :pathname #.(translate-logical-pathname "matlisp:srcdir;")
;;   :components
;;   ((:module "src"
;;     :components
;;     ((:file "colnew")
;;      (:file "colnew-demo1" :depends-on ("colnew"))
;;      (:file "colnew-demo2" :depends-on ("colnew"))))))

;; (defmethod perform ((op asdf:test-op) (c (eql (asdf:find-system :matlisp))))
;;   (oos 'asdf:test-op 'matlisp-tests))

;; (asdf:defsystem matlisp-tests
;;   :depends-on (matlisp)
;;   :in-order-to ((compile-op (load-op :rt))
;;		(test-op (load-op :rt :matlisp)))
;;   :components
;;   ((:module "tests"
;;	    :components
;;	    ((:file "blas")))))

;; (defmethod perform ((op test-op) (c (eql (asdf:find-system :matlisp-tests))))
;;   (or (funcall (intern "DO-TESTS" (find-package "RT")))
;;       (error "TEST-OP failed for MATLISP-TESTS")))
