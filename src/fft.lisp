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
;;; Originally written by Tunc Simsek, Univ. of California, Berkeley
;;; May 5th, 2000
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; $Id: fft.lisp,v 1.5 2000/07/11 02:11:56 simsek Exp $
;;;
;;; $Log: fft.lisp,v $
;;; Revision 1.5  2000/07/11 02:11:56  simsek
;;; o Added support for Allegro CL
;;;
;;; Revision 1.4  2000/05/12 14:13:37  rtoy
;;; o Change the interface to fft and ifft:  We don't need the wsave
;;;   argument anymore because fft and ifft compute them (and cache them
;;;   in a hash table) as needed.
;;; o Don't export ffti; the user doesn't need access to this anymore.
;;;
;;; Revision 1.3  2000/05/08 17:19:18  rtoy
;;; Changes to the STANDARD-MATRIX class:
;;; o The slots N, M, and NXM have changed names.
;;; o The accessors of these slots have changed:
;;;      NROWS, NCOLS, NUMBER-OF-ELEMENTS
;;;   The old names aren't available anymore.
;;; o The initargs of these slots have changed:
;;;      :nrows, :ncols, :nels
;;;
;;; Revision 1.2  2000/05/05 22:04:13  simsek
;;; o Changed one typo: fftb to ifft
;;;
;;; Revision 1.1  2000/05/05 21:35:54  simsek
;;; o Initial revision
;;;
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(in-package "MATLISP")

(use-package "DFFTPACK")
(use-package "BLAS")
(use-package "LAPACK")
(use-package "FORTRAN-FFI-ACCESSORS")

(export '(fft ifft))

(defgeneric fft (x &optional n)
  (:documentation
  "
  Syntax
  ======
  (FFT x [n])

  Purpose
  =======
  Computes the N point discrete Fourier transform (DFT) of X:
   
     For k = 0,...,N-1:            
                                2 pi n
               \\---       -j k ------
                \\                N
    DFT(k) =    /    x(i) e
               /---
            i=0,..,N-1
 
     where the inverse DFT (see IFFT) is:

     For i = 0,...,N-1:            
                                  2 pi k
               \\---         -j i ------
                \\                  N
      X(i) =    /    DFT(k) e
               /---
            k=0,..,N-1
 
  If X is a vector, it is truncated at the end if it has more 
  than N elements and it is padded with zeros at the end if
  it has less than N elements.

  If X is a matrix, the FFT of each column of X is taken.

  The optional argument defaults to length of X when X is 
  a vector and to the number of rows of X when it is a matrix.

  See IFFT, FFTI
  "))

(defgeneric ifft (x &optional n)
  (:documentation
  "
  Syntax
  ======
  (IFFT x [n])

  Purpose
  =======
  Computes the N point inverse discrete Fourier transform (DFT) of X:
   
     For i = 0,...,N-1:            
                                        2 pi k
                     \\---          j i ------
                 1    \\                  N
      IDFT(i) = ---    /      X(k) e
                 N    /---
                   k=0,..,N-1

     where the DFT (see FFT) is:

     For k = 0,...,N-1:            
                                 2 pi n
               \\---         j k ------
                \\                 N
      X(k) =    /  IDFT(i) e
               /---
            i=0,..,N-1

  If X is a vector, it is truncated at the end if it has more 
  than N elements and it is padded with zeros at the end if
  it has less than N elements.

  If X is a matrix, the IFFT of each column of X is taken.

  The optional argument defaults to length of X when X is 
  a vector and to the number of rows of X when it is a matrix.

  See FFT, FFTI
  "))

(defun ffti (n)
  "
  Syntax
  ======
  (FFTI n)

  Purpose
  =======
  Initializes the vector WSAVE which is used in FFT and IFFT.
  The prime factorization of N and a tabulation of the
  trigonometric functions are computed and returned in WSAVE.

  The optional argument WSAVE, if provided, must be a REAL-MATRIX
  with length > 4*N+15.  The same WSAVE may be used in FFT and IFFT
  if the arg N given to FFT and IFFT are the same.
"
  (declare (type (and fixnum (integer 1 *)) n))

  (let ((result (make-array (+ (* 4 n) 15) :element-type 'double-float)))
    (zffti n result)
    result))

;; Create the hash table used to keep track of all of the tables we
;; need for fft and ifft.
(eval-when (load eval compile)
(let ((wsave-hash-table (make-hash-table)))
  (defun lookup-wsave-entry (n)
    "Find the wsave entry for an FFT size of N"
    (let ((entry (gethash n wsave-hash-table)))
      (or entry
	  (setf (gethash n wsave-hash-table) (ffti n)))))
  ;; Just in case we want to start over
  (defun clear-wsave-entries ()
    (clrhash wsave-hash-table))
  ;; Just in case we want to take a peek at what's in the table.
  (defun dump-wsave-entries ()
    (maphash #'(lambda (key val)
		 (format t "Key = ~D, Val = ~A~%" key val))
	     wsave-hash-table))))

#+:cmu  
(defmethod fft ((x standard-matrix) &optional n)
  (let* ((n (or n (if (row-or-col-vector-p x)
		      (max (nrows x) (ncols x))
		    (nrows x))))
	 (wsave (lookup-wsave-entry n))
	 (result (cond ((row-vector-p x) 
			(make-complex-matrix-dim 1 n))
		       ((col-vector-p x)
			(make-complex-matrix-dim n 1))
		       (t (make-complex-matrix-dim n (ncols x))))))
    (if (row-or-col-vector-p x)
	(progn
	  (copy! x result)
	  (zfftf n (store result) wsave))

      (dotimes (j (ncols x))
	(declare (type fixnum j))
	 (dotimes (i (nrows x))
	   (declare (type fixnum i))
	   (setf (matrix-ref result i j) (matrix-ref x i j)))
	 (with-vector-data-addresses ((addr-result (store result))
				      (addr-wsave wsave))
	    (incf-sap :complex-double-float addr-result (* j n))
	    (dfftpack::fortran-zfftf n addr-result addr-wsave))))

      result))


#+:allegro
(defmethod fft ((x standard-matrix) &optional n)
  (let* ((n (or n (if (row-or-col-vector-p x)
		      (max (nrows x) (ncols x))
		    (nrows x))))
	 (wsave (lookup-wsave-entry n))
	 (tmp (make-complex-matrix-dim n 1))
	 (result (cond ((row-vector-p x) 
			(make-complex-matrix-dim 1 n))
		       ((col-vector-p x)
			(make-complex-matrix-dim n 1))
		       (t (make-complex-matrix-dim n (ncols x))))))

    (if (row-or-col-vector-p x)
	(progn
	  (copy! x result)
	  (zfftf n (store result) wsave))

      (dotimes (j (ncols x))
	(declare (type fixnum j))
	 (dotimes (i (nrows x))
	   (declare (type fixnum i))
	   (setf (matrix-ref tmp i) (matrix-ref x i j)))

	 (zfftf n (store tmp) wsave)

	 (dotimes (i (nrows x))
	   (declare (type fixnum i))
	   (setf (matrix-ref result i j) (matrix-ref tmp i)))

	 ))

      result))


#+:cmu
(defmethod ifft ((x standard-matrix) &optional n)
  (let* ((n (or n (if (row-or-col-vector-p x)
		      (max (nrows x) (ncols x))
		      (nrows x))))
	 (wsave (lookup-wsave-entry n))
	 (result (cond ((row-vector-p x) 
			(make-complex-matrix-dim 1 n))
		       ((col-vector-p x)
			(make-complex-matrix-dim n 1))
		       (t (make-complex-matrix-dim n (ncols x))))))

    (if (row-or-col-vector-p x)
	(progn
	  (copy! x result)
	  (zfftb n (store result) wsave))

	(let ((scale-factor (/ (float n 1d0))))
	  (dotimes (j (ncols x))
	    (declare (type fixnum j))
	    (dotimes (i (nrows x))
	      (declare (type fixnum i))
	      (setf (matrix-ref result i j) (matrix-ref x i j)))
	    (with-vector-data-addresses ((addr-result (store result))
					 (addr-wsave wsave))
	      (incf-sap :complex-double-float addr-result (* j n))
	      (dfftpack::fortran-zfftb n addr-result addr-wsave))
	    ;; Scale the result
	    (dotimes (i (nrows x))
	      (declare (type fixnum i))
	      (setf (matrix-ref result i j) (* scale-factor (matrix-ref x i j)))))))

    result))


#+:allegro
(defmethod ifft ((x standard-matrix) &optional n)
  (let* ((n (or n (if (row-or-col-vector-p x)
		      (max (nrows x) (ncols x))
		    (nrows x))))
	 (wsave (lookup-wsave-entry n))
	 (tmp (make-complex-matrix-dim n 1))
	 (result (cond ((row-vector-p x) 
			(make-complex-matrix-dim 1 n))
		       ((col-vector-p x)
			(make-complex-matrix-dim n 1))
		       (t (make-complex-matrix-dim n (ncols x))))))

    (if (row-or-col-vector-p x)
	(progn
	  (copy! x result)
	  (zfftb n (store result) wsave))

      (dotimes (j (ncols x))
	(declare (type fixnum j))

	 (dotimes (i (nrows x))
	   (declare (type fixnum i))
	   (setf (matrix-ref tmp i) (matrix-ref x i j)))

	 (zfftb n (store tmp) wsave)

	 (dotimes (i (nrows x))
	   (declare (type fixnum i))
	   (setf (matrix-ref result i j) (matrix-ref tmp i)))

	 ))

      result))
