;;; -*- Mode: lisp; Syntax: ansi-common-lisp; Package: :matlisp; Base: 10 -*-
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
;;;
;;; $Id: ref.lisp,v 1.1 2000/04/14 00:11:12 simsek Exp $
;;;
;;; $Log: ref.lisp,v $
;;; Revision 1.1  2000/04/14 00:11:12  simsek
;;; o This file is adapted from obsolete files 'matrix-float.lisp'
;;;   'matrix-complex.lisp' and 'matrix-extra.lisp'
;;; o Initial revision.
;;;
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Implementation of MATRIX-REF, the primary
;;; accessor for an element of a matrix.

(in-package "MATLISP")

(export '(matrix-ref))


(defgeneric matrix-ref (matrix row &optional cols)
  (:documentation "
  Syntax
  ======
  (MATRIX-REF matrix rows [cols])

  Purpose
  =======
  Return the element(s) of the matrix MAT, specified by the ROWS and COLS.
  If ROWS and/or COLS are matrices or sequences then the submatrix indexed
  by them will be returned.

  The indices are 0-based."))

(defgeneric (setf matrix-ref) (value matrix rows &optional cols))

(defgeneric matrix-ref-1 (matrix rows &optional cols)
  (:documentation "Same as matrix-ref, except that the indices are 1-based."))

(defgeneric (setf matrix-ref-1) (value matrix rows &optional cols))

;;; Extract a 1-D slice from the matrix.  
;;; We treat the matrix as if it were a 1-D array.
(defun get-real-matrix-slice-1d (mat idx)
  (let* ((n (n mat))
	 (m (m mat))
	 (k (nxm idx))
	 (idx-store (store idx))
	 (mat-store (store mat))
	 (store (make-array k :element-type 'real-matrix-element-type)))
    (declare (optimize (speed 3) (safety 0))
	     (type fixnum n m k)
	     (type (real-matrix-store-type (*)) idx-store mat-store store))
    
    (if (and (> n 1)
	     (> m 1))
	(error "underspecified index"))
    
    (dotimes (i k)
      (declare (type fixnum i))
      (let* ((val (aref idx-store i))
	     (idx (floor val)))
	(declare (type real-matrix-element-type val)
		 (type fixnum idx))
	(setf (aref store i) (aref mat-store idx))))
    
    (make-instance 'real-matrix 
      :n (if (> n 1)
	     k
	   1)
      :m (if (> m 1)
	     k
	   1)
      :store store)))

(defun get-real-matrix-slice-1d-seq (mat idx)
  (let* ((n (n mat))
	 (m (m mat))
	 (k (length idx))
	 (mat-store (store mat))
	 (store (make-array k :element-type 'real-matrix-element-type)))
    (declare (optimize (speed 3) (safety 0))
	     (type fixnum n m k)
	     (type (real-matrix-store-type (*)) mat-store store))
    
    (if (and (> n 1)
	     (> m 1))
	(error "underspecified index"))
    
    (let ((i -1))
      (declare (type fixnum i))
      (dolist (idx idx)
	(declare (type fixnum idx))
	(setf (aref store (incf i)) (aref mat-store idx))))
    
    (make-instance 'real-matrix
      :n (if (> n 1)
	     k
	   1)
      :m (if (> m 1)
	     k
	   1)
      :store store)))

;;; Extrace a 2-D slice from the matrix.  The row and column indices
;;; are given.
(defun get-real-matrix-slice-2d (mat row-idx col-idx)
  (let* ((l (n mat))
	 (n (nxm row-idx))
	 (m (nxm col-idx))
	 (slice (make-real-matrix-dim n m))
	 (row-idx-store (store row-idx))
	 (col-idx-store (store col-idx))
	 (mat-store (store mat))
	 (store (store slice)))
    (declare (type fixnum l n m)
	     (type (real-matrix-store-type (*)) 
		   row-idx-store
		   col-idx-store
		   mat-store
		   store))
    
    (dotimes (i n)
      (declare (type fixnum i))
      (dotimes (j m)
	(declare (type fixnum j))
	(let* ((i-val (aref row-idx-store i))
	       (j-val (aref col-idx-store j))
	       (i-idx (floor i-val))
	       (j-idx (floor j-val))) 
	  (declare (type fixnum i-idx j-idx)
		   (type real-matrix-element-type i-val j-val))
	  (setf (aref store (fortran-matrix-indexing i j n))
	    (aref mat-store (fortran-matrix-indexing i-idx j-idx l))))))
    
    slice))
	 

(defun get-real-matrix-slice-2d-seq (mat row-idx col-idx)
  (let* ((l (n mat))
	 (n (length row-idx))
	 (m (length col-idx))
	 (slice (make-real-matrix-dim n m))
	 (mat-store (store mat))
	 (store (store slice)))
    
    (declare (type fixnum l n m)
	     (type (real-matrix-store-type (*))
		   mat-store
		   store))
    
    (let ((i -1))
      (declare (type fixnum i))
      (dolist (i-idx row-idx)
	(incf i)
	(let ((j -1))
	  (declare (type fixnum j))
	  (dolist (j-idx col-idx)
	    (setf (aref store (fortran-matrix-indexing i (incf j) n))
	      (aref mat-store (fortran-matrix-indexing i-idx j-idx l)))))))
    
    slice))

(defun %matrix-every (fn mat)
  (let* ((n (n mat))
	 (m (m mat))
	 (store (store mat)))
    (declare (optimize (speed 3) (safety 0))
	     (type fixnum n m)
	     (type (real-matrix-store-type (*)) store))
    
    (dotimes (i n)
      (declare (type fixnum i))
      (dotimes (j m)
	(declare (type fixnum j))
	(let* ((val (aref store (fortran-matrix-indexing i j n)))
	       (idx (floor val)))
	  (declare (type real-matrix-element-type val)
		   (type fixnum idx))
	  (unless (funcall fn idx)
	    (return-from %matrix-every nil)))))
     t))

(defmethod matrix-ref ((matrix real-matrix) i &optional (j 0 j-p))
  (let* ((n (n matrix))
	 (m (m matrix))
	 (store (store matrix)))
    (declare (type fixnum n m)
	     (type (real-matrix-store-type (*)) store))
    
    (labels ((consistent-i (i)
	       (and (integerp i)
		    (>= i 0)
		    (< i n)))
	     (consistent-j (j)
	       (and (integerp j)
		    (>= j 0)
		    (< j m))))
      (if j-p
	  (typecase i
	    (fixnum (if (consistent-i i)
			(typecase j
			  (fixnum (if (consistent-j j)
				      (aref store (fortran-matrix-indexing i j n))
				    (error "out of bounds indexing")))
			  (list (if (every #'consistent-j j)
				    (get-real-matrix-slice-2d-seq matrix (list i) j)
				  (error "out of bounds indexing")))
			  (real-matrix (if (%matrix-every #'consistent-j j)
					   (get-real-matrix-slice-2d matrix (make-real-matrix (list i)) j)
					 (error "out of bounds indexing")))
			  (t (error "don't know how to access elements ~a of matrix" (list i j))))
		      (error "out of bounds indexing")))
	    (list (if (every #'consistent-i i)
		      (typecase j
			(fixnum (if (consistent-j j)
				    (get-real-matrix-slice-2d-seq matrix i (list j))
				  (error "out of bounds indexing")))
			(list (if (every #'consistent-j j)
				  (get-real-matrix-slice-2d-seq matrix i j)
				(error "out of bounds indexing")))
			(real-matrix (if (%matrix-every #'consistent-j j)
					 (get-real-matrix-slice-2d matrix (make-real-matrix i) j)
				       (error "out of bounds indexing")))
			(t (error "don't know how to access elements ~a of matrix" (list i j))))
		    (error "out of bounds indexing")))
	    (real-matrix (if (%matrix-every #'consistent-i i)
			     (typecase j
			       (fixnum (if (consistent-j j)
					   (get-real-matrix-slice-2d matrix i (make-real-matrix (list j)))
					 (error "out of bounds indexing")))
			       (list (if (every #'consistent-j j)
					 (get-real-matrix-slice-2d matrix i (make-real-matrix j))
				       (error "out of bounds indexing")))
			       (real-matrix (if (%matrix-every #'consistent-j j)
						(get-real-matrix-slice-2d matrix i j)
					      (error "out of bounds indexing")))
			       (t (error "don't know how to access elements ~a of matrix" (list i j))))
			   (error "out of bounds indexing")))
	    (t (error "don't know how to access elements ~a of matrix" (list i j))))
	(typecase i
	  (fixnum (if  
			  (and (>= i 0) (< i (nxm matrix)))
		      (aref store (fortran-matrix-indexing i 0 n))
		    (error "out of bounds indexing")))
	  (list (if (every #'(lambda (i)
			       
				   (and (>= i 0) (< i (nxm matrix)))) i)
		    (get-real-matrix-slice-1d-seq matrix i)
		  (error "out of bounds indexing")))
	  (real-matrix (if (%matrix-every #'(lambda (i)
					      
						  (and (>= i 0) (< i (nxm matrix)))) i)
			   (get-real-matrix-slice-1d matrix i)
			 (error "out of bounds indexing")))
	  (t (error "don't know how to access element ~a of matrix" i)))))))

;;; Extract a 1-D slice from the matrix.  
;;; We treat the matrix as if it were a 1-D array.
(defun set-real-matrix-slice-1d (new mat idx)
  (let* ((n (n mat))
	 (m (m mat))
	 (k (nxm idx))
	 (idx-store (store idx))
	 (new-store (store new))
	 (mat-store (store mat)))
    
    (declare (optimize (speed 3) (safety 0))
	     (type fixnum n m k)
	     (type (real-matrix-store-type (*)) idx-store new-store mat-store))
    
    (if (and (> n 1)
	     (> m 1))
	(error "underspecified index"))
    
    (dotimes (i k)
      (declare (type fixnum i))
      (let* ((val (aref idx-store i))
	     (idx (floor val)))
	(declare (type real-matrix-element-type val)
		 (type fixnum idx))
	(setf (aref mat-store idx)
	  (aref new-store i))))
    
    mat))

(defun set-real-matrix-slice-1d-seq (new mat idx)
  (let* ((n (n mat))
	 (m (m mat))
	 (new-store (store new))
	 (mat-store (store mat)))
    (declare (optimize (speed 3) (safety 0))
	     (type fixnum n m)
	     (type (real-matrix-store-type (*)) new-store mat-store))
    
    (if (and (> n 1)
	     (> m 1))
	(error "underspecified index"))
    
    (let ((i -1))
      (declare (type fixnum i))
      (dolist (idx idx)
	(declare (type fixnum idx))
	(setf (aref mat-store idx) (aref new-store (incf i)))))
    
    mat))

(defun set-real-matrix-slice-2d (new mat row-idx col-idx)
  (let* ((l (n mat))
	 (n (nxm row-idx))
	 (m (nxm col-idx))
	 (row-idx-store (store row-idx))
	 (col-idx-store (store col-idx))
	 (new-store (store new))
	 (mat-store (store mat)))
    (declare (type fixnum l n m)
	     (type (real-matrix-store-type (*)) 
		   row-idx-store
		   col-idx-store
		   new-store
		   mat-store))
    
    (dotimes (i n)
      (declare (type fixnum i))
      (dotimes (j m)
	(declare (type fixnum j))
	(let* ((i-val (aref row-idx-store i))
	       (j-val (aref col-idx-store j))
	       (i-idx (floor i-val))
	       (j-idx (floor j-val)))
	  (setf (aref mat-store (fortran-matrix-indexing i-idx j-idx l))
	    (aref new-store (fortran-matrix-indexing i j n))))))
    
    mat))

(defun set-real-matrix-slice-2d-seq (new mat row-idx col-idx)
  (let* ((l (n mat))
	 (n (length row-idx))
	 (new-store (store new))
	 (mat-store (store mat)))
    
    (declare (type fixnum l n)
	     (type (real-matrix-store-type (*))
		   new-store
		   mat-store))
    
    (let ((i -1))
      (declare (type fixnum i))
      (dolist (i-idx row-idx)
	(incf i)
	(let ((j -1))
	  (declare (type fixnum j))
	  (dolist (j-idx col-idx)
	    (setf (aref mat-store (fortran-matrix-indexing i-idx j-idx l))
	      (aref new-store (fortran-matrix-indexing i (incf j) n)))))))
    
    mat))
  
;;; Extract a 1-D slice from the matrix.  
;;; We treat the matrix as if it were a 1-D array.
(defun set-real-from-scalar-matrix-slice-1d (new mat idx)
  (let* ((n (n mat))
	 (m (m mat))
	 (k (nxm idx))
	 (idx-store (store idx))
	 (mat-store (store mat)))
    
    (declare (optimize (speed 3) (safety 0))
	     (type fixnum n m k)
	     (type (real-matrix-store-type (*)) idx-store mat-store))
    
    (if (and (> n 1)
	     (> m 1))
	(error "underspecified index"))
    
    (dotimes (i k)
      (declare (type fixnum i))
      (let* ((val (aref idx-store i))
	     (idx (floor val)))
	(declare (type real-matrix-element-type val)
		 (type fixnum idx))
	(setf (aref mat-store idx) new)))
    
    mat))

(defun set-real-from-scalar-matrix-slice-1d-seq (new mat idx)
  (let* ((n (n mat))
	 (m (m mat))
	 (mat-store (store mat)))
    (declare (optimize (speed 3) (safety 0))
	     (type fixnum n m)
	     (type (real-matrix-store-type (*)) mat-store))
    
    (if (and (> n 1)
	     (> m 1))
	(error "underspecified index"))
    
    (let ((i -1))
      (declare (type fixnum i))
      (dolist (idx idx)
	(declare (type fixnum idx))
	(setf (aref mat-store idx) new)))
    
    mat))

(defun set-real-from-scalar-matrix-slice-2d (new mat row-idx col-idx)
  (let* ((l (n mat))
	 (n (nxm row-idx))
	 (m (nxm col-idx))
	 (row-idx-store (store row-idx))
	 (col-idx-store (store col-idx))
	 (mat-store (store mat)))
    (declare (type fixnum l n m)
	     (type (real-matrix-store-type (*)) 
		   row-idx-store
		   col-idx-store
		   mat-store))
    
    (dotimes (i n)
      (declare (type fixnum i))
      (dotimes (j m)
	(declare (type fixnum j))
	(let* ((i-val (aref row-idx-store i))
	       (j-val (aref col-idx-store j))
	       (i-idx (floor i-val))
	       (j-idx (floor j-val)))
	  (declare (type real-matrix-element-type)
		   (type fixnum i-idx j-idx))
	  (setf (aref mat-store (fortran-matrix-indexing i-idx j-idx l)) new))))
    
    mat))

(defun set-real-from-scalar-matrix-slice-2d-seq (new mat row-idx col-idx)
  (let* ((l (n mat))
	 (mat-store (store mat)))
    
    (declare (type fixnum l)
	     (type (real-matrix-store-type (*))
		   mat-store))
    
    (let ((i -1))
      (declare (type fixnum i))
      (dolist (i-idx row-idx)
        (declare (type fixnum i-idx))
	(incf i)
	(let ((j -1))
	  (declare (type fixnum j))
	  (dolist (j-idx col-idx)
	    (declare (type fixnum j-idx))	  
	    (setf (aref mat-store (fortran-matrix-indexing i-idx j-idx l)) new)))))
    
    mat))
  

(defmethod (setf matrix-ref) ((new real-matrix) (matrix real-matrix) i &optional (j nil j-p))
  (let* ((n (n matrix))
	 (m (m matrix))
	 (store (store matrix))
	 (new-n (n new))
	 (new-m (m new))
	 (new-store (store new)))
    
    (declare (type fixnum n m new-n new-m)
	     (type (real-matrix-store-type (*)) store new-store))
    
  
    (let ((p (if (integerp i)
		 1
	       (if (listp i)
		   (length i)
		 (nxm i)))))
      (if (> p new-n)
	  (error "cannot do matrix assignment, too many indices")))

    (let ((q (if (or j-p (integerp j))
		 1
	       (if (listp j)
		   (length j)
		 (nxm j)))))
      (if (> q new-m)
	  (error "cannot do matrix assignment, too many indices")))

    
    (labels ((consistent-i (i)
	       (and (integerp i)
		    (>= i 0)
		    (< i n)))
	     (consistent-j (j)
	       (and (integerp j)
		    (>= j 0)
		    (< j m))))
      (if j-p
	  (typecase i
	    (fixnum (if (consistent-i i)
			(typecase j
			  (fixnum (if (consistent-j j)
				      (setf (aref store (fortran-matrix-indexing i j n))
					(aref new-store 0))
				    (error "out of bounds indexing")))
			  (list (if (every #'consistent-j j)
				    (set-real-matrix-slice-2d-seq new matrix (list i) j)
				  (error "out of bounds indexing")))
			  (real-matrix (if (%matrix-every #'consistent-j j)
					   (set-real-matrix-slice-2d new matrix (make-real-matrix (list i)) j)
					 (error "out of bounds indexing")))
			  (t (error "don't know how to access elements ~a of matrix" (list i j))))
		      (error "out of bounds indexing")))
	    (list (if (every #'consistent-i i)
		      (typecase j
			(fixnum (if (consistent-j j)
				    (set-real-matrix-slice-2d-seq new matrix i (list j))
				  (error "out of bounds indexing")))
			(list (if (every #'consistent-j j)
				  (set-real-matrix-slice-2d-seq new matrix i j)
				(error "out of bounds indexing")))
			(real-matrix (if (%matrix-every #'consistent-j j)
					 (set-real-matrix-slice-2d new matrix (make-real-matrix i) j)
				       (error "out of bounds indexing")))
			(t (error "don't know how to access elements ~a of matrix" (list i j))))
		    (error "out of bounds indexing")))
	    (real-matrix (if (%matrix-every #'consistent-i i)
			     (typecase j
			       (fixnum (if (consistent-j j)
					   (set-real-matrix-slice-2d new matrix i (make-real-matrix (list j)))
					 (error "out of bounds indexing")))
			       (list (if (every #'consistent-j j)
					 (set-real-matrix-slice-2d new matrix i (make-real-matrix j))
				       (error "out of bounds indexing")))
			       (real-matrix (if (%matrix-every #'consistent-j j)
						(set-real-matrix-slice-2d new matrix i j)
					      (error "out of bounds indexing")))
			       (t (error "don't know how to access elements ~a of matrix" (list i j))))
			   (error "out of bounds indexing")))
	    (t (error "don't know how to access elements ~a of matrix" (list i j))))
	(typecase i
	  (fixnum (if 
			  (and (>= i 0) (< i (nxm matrix)))
		      (setf (aref store (fortran-matrix-indexing i 0 n))
			(aref new-store 0))
		    (error "out of bounds indexing")))
	  (list (if (every #'(lambda (i)
			       
				   (and (>= i 0) (< i (nxm matrix)))) i)
		    (set-real-matrix-slice-1d-seq new matrix i)
		  (error "out of bounds indexing")))
	  (real-matrix (if (%matrix-every #'(lambda (i)
					      
						  (and (>= i 0) (< i (nxm matrix)))) i)
			   (set-real-matrix-slice-1d new matrix i)
			 (error "out of bounds indexing")))
	  (t (error "don't know how to access element ~a of matrix" i)))))))


(defmethod (setf matrix-ref) ((new real) (matrix real-matrix) i &optional (j nil j-p))
  (if j-p
      (setf (matrix-ref matrix i j) (coerce new 'real-matrix-element-type))
    (setf (matrix-ref matrix i) (coerce new 'real-matrix-element-type))))

;; Tunc: how do I write real-matrix-element-type here instead of double-float
(defmethod (setf matrix-ref) ((new double-float) (matrix real-matrix) i &optional (j nil j-p))
  (let* ((n (n matrix))
	 (m (m matrix))
	 (store (store matrix)))
    
    (declare (type fixnum n m)
	     (type (real-matrix-store-type (*)) store))
    
    (labels ((consistent-i (i)
	       (and (integerp i)
		    (>= i 0)
		    (< i n)))
	     (consistent-j (j)
	       (and (integerp j)
		    (>= j 0)
		    (< j m))))
      (if j-p
	  (typecase i
	    (fixnum (if (consistent-i i)
			(typecase j
			  (fixnum (if (consistent-j j)
				      (setf (aref store (fortran-matrix-indexing i j n)) new)
				    (error "out of bounds indexing")))
			  (list (if (every #'consistent-j j)
				    (set-real-from-scalar-matrix-slice-2d-seq new matrix (list i) j)
				  (error "out of bounds indexing")))
			  (real-matrix (if (%matrix-every #'consistent-j j)
					   (set-real-from-scalar-matrix-slice-2d new matrix (make-real-matrix (list i)) j)
					 (error "out of bounds indexing")))
			  (t (error "don't know how to access elements ~a of matrix" (list i j))))
		      (error "out of bounds indexing")))
	    (list (if (every #'consistent-i i)
		      (typecase j
			(fixnum (if (consistent-j j)
				    (set-real-from-scalar-matrix-slice-2d-seq new matrix i (list j))
				  (error "out of bounds indexing")))
			(list (if (every #'consistent-j j)
				  (set-real-from-scalar-matrix-slice-2d-seq new matrix i j)
				(error "out of bounds indexing")))
			(real-matrix (if (%matrix-every #'consistent-j j)
					 (set-real-from-scalar-matrix-slice-2d new matrix (make-real-matrix i) j)
				       (error "out of bounds indexing")))
			(t (error "don't know how to access elements ~a of matrix" (list i j))))
		    (error "out of bounds indexing")))
	    (real-matrix (if (%matrix-every #'consistent-i i)
			     (typecase j
			       (fixnum (if (consistent-j j)
					   (set-real-from-scalar-matrix-slice-2d new matrix i (make-real-matrix (list j)))
					 (error "out of bounds indexing")))
			       (list (if (every #'consistent-j j)
					 (set-real-from-scalar-matrix-slice-2d new matrix i (make-real-matrix j))
				       (error "out of bounds indexing")))
			       (real-matrix (if (%matrix-every #'consistent-j j)
						(set-real-from-scalar-matrix-slice-2d new matrix i j)
					      (error "out of bounds indexing")))
			       (t (error "don't know how to access elements ~a of matrix" (list i j))))
			   (error "out of bounds indexing")))
	    (t (error "don't know how to access elements ~a of matrix" (list i j))))
	(typecase i
	  (fixnum (if 
			  (and (>= i 0) (< i (nxm matrix)))
		      (setf (aref store (fortran-matrix-indexing i 0 n)) new)
		    (error "out of bounds indexing")))
	  (list (if (every #'(lambda (i)
			       
				   (and (>= i 0) (< i (nxm matrix)))) i)
		    (set-real-from-scalar-matrix-slice-1d-seq new matrix i)
		  (error "out of bounds indexing")))
	  (real-matrix (if (%matrix-every #'(lambda (i)
					      
						  (and (>= i 0) (< i (nxm matrix)))) i)
			   (set-real-from-scalar-matrix-slice-1d new matrix i)
			 (error "out of bounds indexing")))
	  (t (error "don't know how to access element ~a of matrix" i)))))))


;;;


;;; Extract a 1-D slice from the matrix.  
;;; We treat the matrix as if it were a 1-D array.
(defun get-complex-matrix-slice-1d (mat idx)
  (let* ((n (n mat))
	 (m (m mat))
	 (k (nxm idx))
	 (idx-store (store idx))
	 (mat-store (store mat))
	 (store (make-array (* 2 k) :element-type 'complex-matrix-element-type)))
    (declare (optimize (speed 3) (safety 0))
	     (type fixnum n m k)
	     (type (real-matrix-store-type (*)) idx-store)
	     (type (complex-matrix-store-type (*))  mat-store store))
    
    (if (and (> n 1)
	     (> m 1))
	(error "underspecified index"))
    
    (dotimes (i k)
      (declare (type fixnum i))
      (let* ((val (aref idx-store i))
	     (idx (floor val))
	     (realpart (aref mat-store (* 2 idx)))
	     (imagpart (aref mat-store (1+ (* 2 idx)))))
	
	(declare (type complex-matrix-element-type imagpart realpart)
		 (type real-matrix-element-type val)
		 (type fixnum idx))
	(setf (aref store (* 2 i)) realpart)
	(setf (aref store (1+ (* 2 i))) imagpart)))
    
    (make-instance 'complex-matrix 
      :n (if (> n 1)
	     k
	   1)
      :m (if (> m 1)
	     k
	   1)
      :store store)))

(defun get-complex-matrix-slice-1d-seq (mat idx)
  (let* ((n (n mat))
	 (m (m mat))
	 (k (length idx))
	 (mat-store (store mat))
	 (store (make-array (* 2 k) :element-type 'complex-matrix-element-type)))
    (declare (optimize (speed 3) (safety 0))
	     (type fixnum n m k)
	     (type (complex-matrix-store-type (*)) mat-store store))
    
    (if (and (> n 1)
	     (> m 1))
	(error "underspecified index"))
    
    (let ((i -1))
      (declare (type fixnum i))
      (dolist (idx idx)
	(declare (type fixnum idx))
	(let* ((realpart (aref mat-store (* 2 idx)))
	       (imagpart (aref mat-store (1+ (* 2 idx)))))
	  
	  (declare 
		   (type complex-matrix-element-type realpart imagpart))
	  (setf (aref store (* 2 (incf i))) realpart)
	  (setf (aref store (1+ (* 2 i))) imagpart))))
    
    (make-instance 'complex-matrix
      :n (if (> n 1)
	     k
	   1)
      :m (if (> m 1)
	     k
	   1)
      :store store)))

;;; Extrace a 2-D slice from the matrix.  The row and column indices
;;; are given.
(defun get-complex-matrix-slice-2d (mat row-idx col-idx)
  (let* ((l (n mat))
	 (n (nxm row-idx))
	 (m (nxm col-idx))
	 (slice (make-complex-matrix-dim n m))
	 (row-idx-store (store row-idx))
	 (col-idx-store (store col-idx))
	 (mat-store (store mat))
	 (store (store slice)))
    (declare (type fixnum l n m)
	     (type (real-matrix-store-type (*))
		   row-idx-store
		   col-idx-store)
	     (type (complex-matrix-store-type (*)) 
		   mat-store
		   store))
    
    (dotimes (i n)
      (declare (type fixnum i))
      (dotimes (j m)
	(declare (type fixnum j))
	(let* ((i-val (aref row-idx-store i))
	       (j-val (aref col-idx-store j))
	       (i-idx (floor i-val))
	       (j-idx (floor j-val))
	       (realpart (aref mat-store (fortran-complex-matrix-indexing i-idx j-idx l)))
	       (imagpart (aref mat-store (1+ (fortran-complex-matrix-indexing i-idx j-idx l))))
	       (s-idx  (fortran-complex-matrix-indexing i j n)))
	  (declare (type real-matrix-element-type i-val j-val)
		   (type fixnum i-idx j-idx)
		   (type complex-matrix-element-type realpart imagpart))
	  (setf (aref store s-idx) realpart)
	  (setf (aref store (1+ s-idx)) imagpart))))
        
    slice))
	 

(defun get-complex-matrix-slice-2d-seq (mat row-idx col-idx)
  (let* ((l (n mat))
	 (n (length row-idx))
	 (m (length col-idx))
	 (slice (make-complex-matrix-dim n m))
	 (mat-store (store mat))
	 (store (store slice)))
    
    (declare (type fixnum l n m)
	     (type (complex-matrix-store-type (*))
		   mat-store
		   store))
    
    (let ((i -1))
      (declare (type fixnum i))
      (dolist (i-idx row-idx)
        (declare (type fixnum i-idx))
	(incf i)
	(let ((j -1))
	  (declare (type fixnum j))
	  (dolist (j-idx col-idx)
	    (let* ((realpart (aref mat-store (fortran-complex-matrix-indexing i-idx j-idx l)))
		   (imagpart (aref mat-store (1+ (fortran-complex-matrix-indexing i-idx j-idx l))))
		   (s-idx (fortran-complex-matrix-indexing i (incf j) n)))
	      (declare (type fixnum j-idx)
		       (type complex-matrix-element-type realpart imagpart))
	      (setf (aref store s-idx) realpart)
	      (setf (aref store (1+ s-idx)) imagpart))))))
        
    slice))

(defmethod matrix-ref ((matrix complex-matrix) i &optional (j 0 j-p))
  (let* ((n (n matrix))
	 (m (m matrix))
	 (store (store matrix)))
    (declare (type fixnum n m)
	     (type (complex-matrix-store-type (*)) store))
    
    (labels ((consistent-i (i)
	       (and (integerp i)
		    (>= i 0)
		    (< i n)))
	     (consistent-j (j)
	       (and (integerp j)
		    (>= j 0)
		    (< j m))))
      (if j-p
	  (typecase i
	    (fixnum (if (consistent-i i)
			(typecase j
			  (fixnum (if (consistent-j j)
				      (complex (aref store (fortran-complex-matrix-indexing i j n))
					       (aref store (1+ (fortran-complex-matrix-indexing i j n))))
				    (error "out of bounds indexing")))
			  (list (if (every #'consistent-j j)
				    (get-complex-matrix-slice-2d-seq matrix (list i) j)
				  (error "out of bounds indexing")))
			  (real-matrix (if (%matrix-every #'consistent-j j)
					   (get-complex-matrix-slice-2d matrix (make-real-matrix (list i)) j)
					 (error "out of bounds indexing")))
			  (t (error "don't know how to access elements ~a of matrix" (list i j))))
		      (error "out of bounds indexing")))
	    (list (if (every #'consistent-i i)
		      (typecase j
			(fixnum (if (consistent-j j)
				    (get-complex-matrix-slice-2d-seq matrix i (list j))
				  (error "out of bounds indexing")))
			(list (if (every #'consistent-j j)
				  (get-complex-matrix-slice-2d-seq matrix i j)
				(error "out of bounds indexing")))
			(real-matrix (if (%matrix-every #'consistent-j j)
					 (get-complex-matrix-slice-2d matrix (make-real-matrix i) j)
				       (error "out of bounds indexing")))
			(t (error "don't know how to access elements ~a of matrix" (list i j))))
		    (error "out of bounds indexing")))
	    (real-matrix (if (%matrix-every #'consistent-i i)
			     (typecase j
			       (fixnum (if (consistent-j j)
					   (get-complex-matrix-slice-2d matrix i (make-real-matrix (list j)))
					 (error "out of bounds indexing")))
			       (list (if (every #'consistent-j j)
					 (get-complex-matrix-slice-2d matrix i (make-real-matrix j))
				       (error "out of bounds indexing")))
			       (real-matrix (if (%matrix-every #'consistent-j j)
						(get-complex-matrix-slice-2d matrix i j)
					      (error "out of bounds indexing")))
			       (t (error "don't know how to access elements ~a of matrix" (list i j))))
			   (error "out of bounds indexing")))
	    (t (error "don't know how to access elements ~a of matrix" (list i j))))
	(typecase i
	  (fixnum (if 
			  (and (>= i 0) (< i (nxm matrix)))
		      (complex (aref store (fortran-complex-matrix-indexing i 0 n))
			       (aref store (1+ (fortran-complex-matrix-indexing i 0 n))))
		    (error "out of bounds indexing")))
	  (list (if (every #'(lambda (i)
			       
				   (and (>= i 0) (< i (nxm matrix)))) i)
		    (get-complex-matrix-slice-1d-seq matrix i)
		  (error "out of bounds indexing")))
	  (real-matrix (if (%matrix-every #'(lambda (i)
					      
						  (and (>= i 0) (< i (nxm matrix)))) i)
			   (get-complex-matrix-slice-1d matrix i)
			 (error "out of bounds indexing")))
	  (t (error "don't know how to access element ~a of matrix" i)))))))


;;; Extract a 1-D slice from the matrix.  
;;; We treat the matrix as if it were a 1-D array.
(defun set-complex-from-complex-matrix-slice-1d (new mat idx)
  (let* ((n (n mat))
	 (m (m mat))
	 (k (nxm idx))
	 (idx-store (store idx))
	 (new-store (store new))
	 (mat-store (store mat)))
    
    (declare (optimize (speed 3) (safety 0))
	     (type fixnum n m k)
	     (type (real-matrix-store-type (*)) idx-store)
	     (type (complex-matrix-store-type (*)) new-store mat-store))
    
    (if (and (> n 1)
	     (> m 1))
	(error "underspecified index"))
    
    (dotimes (i k)
      (declare (type fixnum i))
      (let* ((val (aref idx-store i))
	     (idx (floor val))
	     (realpart (aref new-store (* 2 i)))
	     (imagpart (aref new-store (1+ (* 2 i)))))
	(declare (type real-matrix-element-type val)
		 (type fixnum idx)
		 (type complex-matrix-element-type realpart imagpart))
	(setf (aref mat-store (* 2 idx)) realpart)
	(setf (aref mat-store (1+ (* 2 idx))) imagpart)))
   
    mat))

(defun set-complex-from-complex-matrix-slice-1d-seq (new mat idx)
  (let* ((n (n mat))
	 (m (m mat))
	 (k (length idx))
	 (new-store (store new))
	 (mat-store (store mat)))
    (declare (optimize (speed 3) (safety 0))
	     (type fixnum n m k)
	     (type (complex-matrix-store-type (*)) new-store mat-store))
    
    (if (and (> n 1)
	     (> m 1))
	(error "underspecified index"))
    
    (let ((i -1))
      (declare (type fixnum i))
      (dolist (idx idx)
	(declare (type fixnum idx))
	(let ((realpart (aref new-store (* 2 (incf i))))
	      (imagpart (aref new-store (1+ (* 2 i)))))
	  (declare (type complex-matrix-element-type realpart imagpart))
	  (setf (aref mat-store (* 2 idx)) realpart)
	  (setf (aref mat-store (1+ (* 2 idx))) imagpart))))

    mat))

(defun set-complex-from-complex-matrix-slice-2d (new mat row-idx col-idx)
  (let* ((l (n mat))
	 (n (nxm row-idx))
	 (m (nxm col-idx))
	 (row-idx-store (store row-idx))
	 (col-idx-store (store col-idx))
	 (new-store (store new))
	 (mat-store (store mat)))
    (declare (type fixnum l n m)
	     (type (real-matrix-store-type (*))
		   row-idx-store
		   col-idx-store)
	     (type (complex-matrix-store-type (*)) 
		   new-store
		   mat-store))
    
    (dotimes (i n)
      (declare (type fixnum i))
      (dotimes (j m)
	(declare (type fixnum j))
	(let* ((i-val (aref row-idx-store i))
	       (j-val (aref col-idx-store j))
	       (i-idx (floor i-val))
	       (j-idx (floor j-val))
	       (realpart (aref new-store (fortran-complex-matrix-indexing i j n)))
	       (imagpart (aref new-store (1+ (fortran-complex-matrix-indexing i j n)))))
	  (declare (type complex-matrix-element-type realpart imagpart))
	  
	  (setf (aref mat-store (fortran-complex-matrix-indexing i-idx j-idx l)) realpart)
	  (setf (aref mat-store (1+ (fortran-complex-matrix-indexing i-idx j-idx l))) imagpart))))

    mat))

(defun set-complex-from-complex-matrix-slice-2d-seq (new mat row-idx col-idx)
  (let* ((l (n mat))
	 (n (length row-idx))
	 (m (length col-idx))
	 (new-store (store new))
	 (mat-store (store mat)))
    
    (declare (type fixnum l n m)
	     (type (complex-matrix-store-type (*))
		   new-store
		   mat-store))
    
    (let ((i -1))
      (declare (type fixnum i))
      (dolist (i-idx row-idx)
	(incf i)
	(let ((j -1))
	  (declare (type fixnum j))
	  (dolist (j-idx col-idx)
		  (let ((realpart (aref new-store (fortran-complex-matrix-indexing i (incf j) n)))
			(imagpart (aref new-store (1+ (fortran-complex-matrix-indexing i j n)))))
		    (declare (type complex-matrix-element-type realpart imagpart))
		    
		    (setf (aref mat-store (fortran-complex-matrix-indexing i-idx j-idx l)) realpart)
		    (setf (aref mat-store (1+ (fortran-complex-matrix-indexing i-idx j-idx l))) imagpart))))))

    mat))

;;; Extract a 1-D slice from the matrix.  
;;; We treat the matrix as if it were a 1-D array.
(defun set-complex-from-real-matrix-slice-1d (new mat idx)
  (let* ((n (n mat))
	 (m (m mat))
	 (k (nxm idx))
	 (idx-store (store idx))
	 (new-store (store new))
	 (mat-store (store mat)))
    
    (declare (optimize (speed 3) (safety 0))
	     (type fixnum n m k)
	     (type (real-matrix-store-type (*)) idx-store new-store)
	     (type (complex-matrix-store-type (*)) mat-store))
    
    (if (and (> n 1)
	     (> m 1))
	(error "underspecified index"))
    
    (dotimes (i k)
      (declare (type fixnum i))
      (let* ((val (aref idx-store i))
	     (idx (floor val))
	     (realpart (aref new-store i))
	     (imagpart 0.0d0))
	(declare (type real-matrix-element-type val)
		 (type fixnum idx)
		 (type complex-matrix-element-type realpart imagpart))
	(setf (aref mat-store (* 2 idx)) realpart)
	(setf (aref mat-store (1+ (* 2 idx))) imagpart)))
   
    mat))

(defun set-complex-from-real-matrix-slice-1d-seq (new mat idx)
  (let* ((n (n mat))
	 (m (m mat))
	 (k (length idx))
	 (new-store (store new))
	 (mat-store (store mat)))
    (declare (optimize (speed 3) (safety 0))
	     (type fixnum n m k)
	     (type (real-matrix-store-type (*)) new-store)
	     (type (complex-matrix-store-type (*)) mat-store))
    
    (if (and (> n 1)
	     (> m 1))
	(error "underspecified index"))
    
    (let ((i -1))
      (declare (type fixnum i))
      (dolist (idx idx)
	(declare (type fixnum idx))
	(let ((realpart (aref new-store (incf i)))
	      (imagpart 0.0d0))
	  (declare (type complex-matrix-element-type realpart imagpart))
	  (setf (aref mat-store (* 2 idx)) realpart)
	  (setf (aref mat-store (1+ (* 2 idx))) imagpart))))

    mat))

(defun set-complex-from-real-matrix-slice-2d (new mat row-idx col-idx)
  (let* ((l (n mat))
	 (n (nxm row-idx))
	 (m (nxm col-idx))
	 (row-idx-store (store row-idx))
	 (col-idx-store (store col-idx))
	 (new-store (store new))
	 (mat-store (store mat)))
    (declare (type fixnum l n m)
	     (type (real-matrix-store-type (*))
		   new-store
		   row-idx-store
		   col-idx-store)
	     (type (complex-matrix-store-type (*)) 
		   mat-store))
    
    (dotimes (i n)
      (declare (type fixnum i))
      (dotimes (j m)
	(declare (type fixnum j))
	(let* ((i-val (aref row-idx-store i))
	       (j-val (aref col-idx-store j))
	       (i-idx (floor i-val))
	       (j-idx (floor j-val))
	       (realpart (aref new-store (fortran-matrix-indexing i j n)))
	       (imagpart 0.0d0))
	  (declare (type complex-matrix-element-type realpart imagpart))
	  
	  (setf (aref mat-store (fortran-complex-matrix-indexing i-idx j-idx l)) realpart)
	  (setf (aref mat-store (1+ (fortran-complex-matrix-indexing i-idx j-idx l))) imagpart))))

    mat))

(defun set-complex-from-real-matrix-slice-2d-seq (new mat row-idx col-idx)
  (let* ((l (n mat))
	 (n (length row-idx))
	 (m (length col-idx))
	 (new-store (store new))
	 (mat-store (store mat)))
    
    (declare (type fixnum l n m)
	     (type (real-matrix-store-type (*))
		   new-store)
	     (type (complex-matrix-store-type (*))
		   mat-store))
    
    (let ((i -1))
      (declare (type fixnum i))
      (dolist (i-idx row-idx)
	(incf i)
	(let ((j -1))
	  (declare (type fixnum j))
	  (dolist (j-idx col-idx)
		  (let ((realpart (aref new-store (fortran-matrix-indexing i (incf j) n)))
			(imagpart 0.0d0))
		    (declare (type complex-matrix-element-type realpart imagpart))
		    
		    (setf (aref mat-store (fortran-complex-matrix-indexing i-idx j-idx l)) realpart)
		    (setf (aref mat-store (1+ (fortran-complex-matrix-indexing i-idx j-idx l))) imagpart))))))

    mat))

;;; Extract a 1-D slice from the matrix.  
;;; We treat the matrix as if it were a 1-D array.
(defun set-complex-from-scalar-matrix-slice-1d (new mat idx)
  (let* ((n (n mat))
	 (m (m mat))
	 (k (nxm idx))
	 (idx-store (store idx))
	 (mat-store (store mat)))
    
    (declare (optimize (speed 3) (safety 0))
	     (type fixnum n m k)
	     (type (real-matrix-store-type (*)) idx-store)
	     (type (complex-matrix-store-type (*)) mat-store))
    
    (if (and (> n 1)
	     (> m 1))
	(error "underspecified index"))
    
    (dotimes (i k)
      (declare (type fixnum i))
      (let* ((val (aref idx-store i))
	     (idx (floor val))
	     (realpart (realpart new))
	     (imagpart (imagpart new)))
	(declare (type real-matrix-element-type val)
		 (type fixnum idx)
		 (type complex-matrix-element-type realpart imagpart))
	(setf (aref mat-store (* 2 idx)) realpart)
	(setf (aref mat-store (1+ (* 2 idx))) imagpart)))
   
    mat))

(defun set-complex-from-scalar-matrix-slice-1d-seq (new mat idx)
  (let* ((n (n mat))
	 (m (m mat))
	 (k (length idx))
	 (mat-store (store mat)))
    (declare (optimize (speed 3) (safety 0))
	     (type fixnum n m k)
	     (type (complex-matrix-store-type (*)) mat-store))
    
    (if (and (> n 1)
	     (> m 1))
	(error "underspecified index"))
    
    (let ((i -1))
      (declare (type fixnum i))
      (dolist (idx idx)
	(declare (type fixnum idx))
	(let ((realpart (realpart new))
	      (imagpart (imagpart new)))
	  (declare (type complex-matrix-element-type realpart imagpart))
	  (setf (aref mat-store (* 2 idx)) realpart)
	  (setf (aref mat-store (1+ (* 2 idx))) imagpart))))

    mat))

(defun set-complex-from-scalar-matrix-slice-2d (new mat row-idx col-idx)
  (let* ((l (n mat))
	 (n (nxm row-idx))
	 (m (nxm col-idx))
	 (row-idx-store (store row-idx))
	 (col-idx-store (store col-idx))
	 (mat-store (store mat)))
    (declare (type fixnum l n m)
	     (type (real-matrix-store-type (*))
		   row-idx-store
		   col-idx-store)
	     (type (complex-matrix-store-type (*)) 
		   mat-store))
    
    (dotimes (i n)
      (declare (type fixnum i))
      (dotimes (j m)
	(declare (type fixnum j))
	(let* ((i-val (aref row-idx-store i))
	       (j-val (aref col-idx-store j))
	       (i-idx (floor i-val))
	       (j-idx (floor j-val))
	       (realpart (realpart new))
	       (imagpart (imagpart new)))
	  (declare (type complex-matrix-element-type realpart imagpart))
	  
	  (setf (aref mat-store (fortran-complex-matrix-indexing i-idx j-idx l)) realpart)
	  (setf (aref mat-store (1+ (fortran-complex-matrix-indexing i-idx j-idx l))) imagpart))))

    mat))

(defun set-complex-from-scalar-matrix-slice-2d-seq (new mat row-idx col-idx)
  (let* ((l (n mat))
	 (n (length row-idx))
	 (m (length col-idx))
	 (mat-store (store mat)))
    
    (declare (type fixnum l n m)
	     (type (complex-matrix-store-type (*))
		   mat-store))
    
    (let ((i -1))
      (declare (type fixnum i))
      (dolist (i-idx row-idx)
	(incf i)
	(let ((j -1))
	  (declare (type fixnum j))
	  (dolist (j-idx col-idx)
		  (let ((realpart (realpart new))
			(imagpart (imagpart new)))
		    (declare (type complex-matrix-element-type realpart imagpart))
		    
		    (setf (aref mat-store (fortran-complex-matrix-indexing i-idx j-idx l)) realpart)
		    (setf (aref mat-store (1+ (fortran-complex-matrix-indexing i-idx j-idx l))) imagpart))))))

    mat))

(defmethod (setf matrix-ref) ((new complex-matrix) (matrix complex-matrix) i &optional (j nil j-p))
  (let* ((n (n matrix))
	 (m (m matrix))
	 (store (store matrix))
	 (new-n (n new))
	 (new-m (m new))
	 (new-store (store new)))
    
    (declare (type fixnum n m new-n new-m)
	     (type (complex-matrix-store-type (*)) store new-store))
    
  
    (let ((p (if (integerp i)
		 1
	       (if (listp i)
		   (length i)
		 (nxm i)))))
      (if (> p new-n)
	  (error "cannot do matrix assignment, too many indices")))

    (let ((q (if (or j-p (integerp j))
		 1
	       (if (listp j)
		   (length j)
		 (nxm j)))))
      (if (> q new-m)
	  (error "cannot do matrix assignment, too many indices")))

    
    (labels ((consistent-i (i)
	       (and (integerp i)
		    (>= i 0)
		    (< i n)))
	     (consistent-j (j)
	       (and (integerp j)
		    (>= j 0)
		    (< j m))))
      (if j-p
	  (typecase i
	    (fixnum (if (consistent-i i)
			(typecase j
			  (fixnum (if (consistent-j j)
				      (let ((realpart (aref new-store 0))
					    (imagpart (aref new-store 1)))
					(setf (aref store (fortran-complex-matrix-indexing i j n)) realpart)
					(setf (aref store (1+ (fortran-complex-matrix-indexing i j n))) imagpart)
					(complex realpart imagpart))
				    (error "out of bounds indexing")))
			  (list (if (every #'consistent-j j)
				    (set-complex-from-complex-matrix-slice-2d-seq new matrix (list i) j)
				  (error "out of bounds indexing")))
			  (real-matrix (if (%matrix-every #'consistent-j j)
					   (set-complex-from-complex-matrix-slice-2d new matrix (make-real-matrix (list i)) j)
					 (error "out of bounds indexing")))
			  (t (error "don't know how to access elements ~a of matrix" (list i j))))
		      (error "out of bounds indexing")))
	    (list (if (every #'consistent-i i)
		      (typecase j
			(fixnum (if (consistent-j j)
				    (set-complex-from-complex-matrix-slice-2d-seq new matrix i (list j))
				  (error "out of bounds indexing")))
			(list (if (every #'consistent-j j)
				  (set-complex-from-complex-matrix-slice-2d-seq new matrix i j)
				(error "out of bounds indexing")))
			(real-matrix (if (%matrix-every #'consistent-j j)
					 (set-complex-from-complex-matrix-slice-2d new matrix (make-real-matrix i) j)
				       (error "out of bounds indexing")))
			(t (error "don't know how to access elements ~a of matrix" (list i j))))
		    (error "out of bounds indexing")))
	    (real-matrix (if (%matrix-every #'consistent-i i)
			     (typecase j
			       (fixnum (if (consistent-j j)
					   (set-complex-from-complex-matrix-slice-2d new matrix i (make-real-matrix (list j)))
					 (error "out of bounds indexing")))
			       (list (if (every #'consistent-j j)
					 (set-complex-from-complex-matrix-slice-2d new matrix i (make-real-matrix j))
				       (error "out of bounds indexing")))
			       (real-matrix (if (%matrix-every #'consistent-j j)
						(set-complex-from-complex-matrix-slice-2d new matrix i j)
					      (error "out of bounds indexing")))
			       (t (error "don't know how to access elements ~a of matrix" (list i j))))
			   (error "out of bounds indexing")))
	    (t (error "don't know how to access elements ~a of matrix" (list i j))))
	(typecase i
	  (fixnum (if 
			  (and (>= i 0) (< i (nxm matrix)))
		      (let ((realpart (aref new-store 0))
			    (imagpart (aref new-store 1)))
			(setf (aref store (fortran-complex-matrix-indexing i 0 n)) realpart)
			(setf (aref store (1+ (fortran-complex-matrix-indexing i 0 n))) imagpart)
			(complex realpart imagpart))
		    (error "out of bounds indexing")))
	  (list (if (every #'(lambda (i)
			       
				   (and (>= i 0) (< i (nxm matrix)))) i)
		    (set-complex-from-complex-matrix-slice-1d-seq new matrix i)
		  (error "out of bounds indexing")))
	  (real-matrix (if (%matrix-every #'(lambda (i)
					      
						  (and (>= i 0) (< i (nxm matrix)))) i)
			   (set-complex-from-complex-matrix-slice-1d new matrix i)
			 (error "out of bounds indexing")))
	  (t (error "don't know how to access element ~a of matrix" i)))))))

(defmethod (setf matrix-ref) ((new real-matrix) (matrix complex-matrix) i &optional (j nil j-p))
  (let* ((n (n matrix))
	 (m (m matrix))
	 (store (store matrix))
	 (new-n (n new))
	 (new-m (m new))
	 (new-store (store new)))
    
    (declare (type fixnum n m new-n new-m)
	     (type (real-matrix-store-type (*)) new-store)
	     (type (complex-matrix-store-type (*)) store))
    
  
    (let ((p (if (integerp i)
		 1
	       (if (listp i)
		   (length i)
		 (nxm i)))))
      (if (> p new-n)
	  (error "cannot do matrix assignment, too many indices")))

    (let ((q (if (or j-p (integerp j))
		 1
	       (if (listp j)
		   (length j)
		 (nxm j)))))
      (if (> q new-m)
	  (error "cannot do matrix assignment, too many indices")))

    
    (labels ((consistent-i (i)
	       (and (integerp i)
		    (>= i 0)
		    (< i n)))
	     (consistent-j (j)
	       (and (integerp j)
		    (>= j 0)
		    (< j m))))
      (if j-p
	  (typecase i
	    (fixnum (if (consistent-i i)
			(typecase j
			  (fixnum (if (consistent-j j)
				      (let ((realpart (aref new-store 0))
					    (imagpart 0.0d0))
					(setf (aref store (fortran-complex-matrix-indexing i j n)) realpart)
					(setf (aref store (1+ (fortran-complex-matrix-indexing i j n))) imagpart)
					(complex realpart imagpart))
				    (error "out of bounds indexing")))
			  (list (if (every #'consistent-j j)
				    (set-complex-from-real-matrix-slice-2d-seq new matrix (list i) j)
				  (error "out of bounds indexing")))
			  (real-matrix (if (%matrix-every #'consistent-j j)
					   (set-complex-from-real-matrix-slice-2d new matrix (make-real-matrix (list i)) j)
					 (error "out of bounds indexing")))
			  (t (error "don't know how to access elements ~a of matrix" (list i j))))
		      (error "out of bounds indexing")))
	    (list (if (every #'consistent-i i)
		      (typecase j
			(fixnum (if (consistent-j j)
				    (set-complex-from-real-matrix-slice-2d-seq new matrix i (list j))
				  (error "out of bounds indexing")))
			(list (if (every #'consistent-j j)
				  (set-complex-from-real-matrix-slice-2d-seq new matrix i j)
				(error "out of bounds indexing")))
			(real-matrix (if (%matrix-every #'consistent-j j)
					 (set-complex-from-real-matrix-slice-2d new matrix (make-real-matrix i) j)
				       (error "out of bounds indexing")))
			(t (error "don't know how to access elements ~a of matrix" (list i j))))
		    (error "out of bounds indexing")))
	    (real-matrix (if (%matrix-every #'consistent-i i)
			     (typecase j
			       (fixnum (if (consistent-j j)
					   (set-complex-from-real-matrix-slice-2d new matrix i (make-real-matrix (list j)))
					 (error "out of bounds indexing")))
			       (list (if (every #'consistent-j j)
					 (set-complex-from-real-matrix-slice-2d new matrix i (make-real-matrix j))
				       (error "out of bounds indexing")))
			       (real-matrix (if (%matrix-every #'consistent-j j)
						(set-complex-from-real-matrix-slice-2d new matrix i j)
					      (error "out of bounds indexing")))
			       (t (error "don't know how to access elements ~a of matrix" (list i j))))
			   (error "out of bounds indexing")))
	    (t (error "don't know how to access elements ~a of matrix" (list i j))))
	(typecase i
	  (fixnum (if 
			  (and (>= i 0) (< i (nxm matrix)))
		      (let ((realpart (aref new-store 0))
			    (imagpart 0.0d0))
			(setf (aref store (fortran-complex-matrix-indexing i 0 n)) realpart)
			(setf (aref store (1+ (fortran-complex-matrix-indexing i 0 n))) imagpart)
			(complex realpart imagpart))
		    (error "out of bounds indexing")))
	  (list (if (every #'(lambda (i)
			       
				   (and (>= i 0) (< i (nxm matrix)))) i)
		    (set-complex-from-real-matrix-slice-1d-seq new matrix i)
		  (error "out of bounds indexing")))
	  (real-matrix (if (%matrix-every #'(lambda (i)
					      
						  (and (>= i 0) (< i (nxm matrix)))) i)
			   (set-complex-from-real-matrix-slice-1d new matrix i)
			 (error "out of bounds indexing")))
	  (t (error "don't know how to access element ~a of matrix" i)))))))


(defmethod (setf matrix-ref) ((new number) (matrix complex-matrix) i &optional (j nil j-p))
  (if j-p
      (setf (matrix-ref matrix i j) (complex-coerce new))
    (setf (matrix-ref matrix i) (complex-coerce new))))
  
(defmethod (setf matrix-ref) ((new kernel::complex-double-float) (matrix complex-matrix) i &optional (j nil j-p))
  (let* ((n (n matrix))
	 (m (m matrix))
	 (store (store matrix)))

    
    (declare (type fixnum n m)
	     (type (complex-matrix-store-type (*)) store))
    
    
    (labels ((consistent-i (i)
	       (and (integerp i)
		    (>= i 0)
		    (< i n)))
	     (consistent-j (j)
	       (and (integerp j)
		    (>= j 0)
		    (< j m))))
      (if j-p
	  (typecase i
	    (fixnum (if (consistent-i i)
			(typecase j
			  (fixnum (if (consistent-j j)
				      (let ((realpart (realpart new))
					    (imagpart (imagpart new)))
					(setf (aref store (fortran-complex-matrix-indexing i j n)) realpart)
					(setf (aref store (1+ (fortran-complex-matrix-indexing i j n))) imagpart)
					new)
				    (error "out of bounds indexing")))
			  (list (if (every #'consistent-j j)
				    (set-complex-from-scalar-matrix-slice-2d-seq new matrix (list i) j)
				  (error "out of bounds indexing")))
			  (real-matrix (if (%matrix-every #'consistent-j j)
					   (set-complex-from-scalar-matrix-slice-2d new matrix (make-real-matrix (list i)) j)
					 (error "out of bounds indexing")))
			  (t (error "don't know how to access elements ~a of matrix" (list i j))))
		      (error "out of bounds indexing")))
	    (list (if (every #'consistent-i i)
		      (typecase j
			(fixnum (if (consistent-j j)
				    (set-complex-from-scalar-matrix-slice-2d-seq new matrix i (list j))
				  (error "out of bounds indexing")))
			(list (if (every #'consistent-j j)
				  (set-complex-from-scalar-matrix-slice-2d-seq new matrix i j)
				(error "out of bounds indexing")))
			(real-matrix (if (%matrix-every #'consistent-j j)
					 (set-complex-from-scalar-matrix-slice-2d new matrix (make-real-matrix i) j)
				       (error "out of bounds indexing")))
			(t (error "don't know how to access elements ~a of matrix" (list i j))))
		    (error "out of bounds indexing")))
	    (real-matrix (if (%matrix-every #'consistent-i i)
			     (typecase j
			       (fixnum (if (consistent-j j)
					   (set-complex-from-scalar-matrix-slice-2d new matrix i (make-real-matrix (list j)))
					 (error "out of bounds indexing")))
			       (list (if (every #'consistent-j j)
					 (set-complex-from-scalar-matrix-slice-2d new matrix i (make-real-matrix j))
				       (error "out of bounds indexing")))
			       (real-matrix (if (%matrix-every #'consistent-j j)
						(set-complex-from-scalar-matrix-slice-2d new matrix i j)
					      (error "out of bounds indexing")))
			       (t (error "don't know how to access elements ~a of matrix" (list i j))))
			   (error "out of bounds indexing")))
	    (t (error "don't know how to access elements ~a of matrix" (list i j))))
	(typecase i
	  (fixnum (if 
			  (and (>= i 0) (< i (nxm matrix)))
		      (let ((realpart (realpart new))
			    (imagpart (imagpart new)))
			(setf (aref store (fortran-complex-matrix-indexing i 0 n)) realpart)
			(setf (aref store (1+ (fortran-complex-matrix-indexing i 0 n))) imagpart)
			new)
		    (error "out of bounds indexing")))
	  (list (if (every #'(lambda (i)
			       
				   (and (>= i 0) (< i (nxm matrix)))) i)
		    (set-complex-from-scalar-matrix-slice-1d-seq new matrix i)
		  (error "out of bounds indexing")))
	  (real-matrix (if (%matrix-every #'(lambda (i)
					      
						  (and (>= i 0) (< i (nxm matrix)))) i)
			   (set-complex-from-scalar-matrix-slice-1d new matrix i)
			 (error "out of bounds indexing")))
	  (t (error "don't know how to access element ~a of matrix" i)))))))


(defmethod matrix-ref ((matrix t) row &optional col)
  (declare (ignore row col))
  (error "argument must be a matrix"))

(defmethod (setf matrix-ref) (new (matrix t) row &optional col)
  (declare (ignore row col))
  (error "argument must be a matrix"))

(defmethod (setf matrix-ref) ((new t) (matrix real-matrix) row &optional col)
  (declare (ignore row col))
  (error "argument must be a matrix or a number"))

(defmethod (setf matrix-ref) ((new t) (matrix complex-matrix) row &optional col)
  (declare (ignore row col))
  (error "argument must be a matrix or a number"))

(defmethod matrix-ref ((matrix standard-matrix) row &optional (col 0 col-p))
  (with-slots (store n m) matrix
      (if col-p
	  (if (and (integerp row)
		   (integerp col)
		   (>= row 0)
		   (>= col 0)
		   (< row n)
		   (< col m))
	      (aref store (fortran-matrix-indexing row col n))
	    (error "don't know how to access on indices ~a" (list row col)))
	(if (and (integerp row)
		 (>= row 0)
		 (< row (max n m)))
	    (aref store row)
	  (error "don't know how to access on index ~a" row)))))

(defmethod (setf matrix-ref) (new (matrix standard-matrix) row &optional (col 0 col-p))
  (with-slots (store n m) matrix
      (if col-p
	  (if (and (integerp row)
		   (integerp col)
		   (>= row 0)
		   (>= col 0)
		   (< row n)
		   (< col m))
	      (setf (aref store (fortran-matrix-indexing row col n)) new)
	    (error "don't know how to access on indices ~a" (list row col)))
	(if (and (integerp row)
		 (>= row 0)
		 (< row (max n m)))
	    (setf (aref store row) new)
	  (error "don't know how to access on index ~a" row)))))
	 
(defun %fixup-to-1-indexing (item)
  (typecase item
     (integer (1- item))
     (list (mapcar #'1- item))
     (real-matrix 
      (let ((n (n item))
	    (m (m item))
	    (store (store item)))
	(declare (type fixnum n m)
		 (type (real-matrix-store-type (*)) store))
	(dotimes (i n)
	   (declare (type fixnum i))
	   (dotimes (j m)
	      (declare (type fixnum j))
	      (let ((index (fortran-matrix-indexing i j n)))
		(setf (aref store index) (- (aref store index) 1.0d0)))))
	item))
     (t (error "cannot handle index ~a to matrix" item))))

(defmethod matrix-ref-1 (matrix rows &optional (cols 0 c-p))
  (if c-p
      (matrix-ref matrix (%fixup-to-1-indexing rows) (%fixup-to-1-indexing cols))
    (matrix-ref matrix (%fixup-to-1-indexing rows))))

(defmethod (setf matrix-ref-1) (new matrix rows &optional (cols 0 c-p))
  (if c-p
      (setf (matrix-ref matrix (%fixup-to-1-indexing rows) (%fixup-to-1-indexing cols)) new)
    (setf (matrix-ref matrix (%fixup-to-1-indexing rows)) new)))




