(in-package #:matlisp-ffi)

;;Adapted from cl-blapack.
(defun %f77.tokenize (line)
  (declare (type string line))
  (split-seq #'(lambda (c)
		 (cond
		   ((member c '(#\Space #\,)) t)
		   ((member c '(#\( #\))) :keep)))
	     line))

(defun %f77.splitlines (line)
  "
Split lines of a Fortran 77 file, whilst removing comments, and taking care of
line continuations.
"  
  (declare (type string line))
  (split-seq (let ((newline-state 0)
		   (comment-state nil))
	       #'(lambda (c)
		   (cond
		     ((member c '(#\Newline)) (setf newline-state 0
						    comment-state nil)
		      :delete)
		     (newline-state
		      (incf newline-state)
		      (cond
			((and (= newline-state 1) (member c '(#\* #\C #\c)))
			 (setf comment-state t
			       newline-state nil)
			 :delete)
			((< newline-state 6)
			 (if (char= c #\Space) :delete
			     (progn (setf newline-state nil)
				    :right)))
			((= newline-state 6)
			 (progn (setf newline-state nil)
				(if (member c '(#\Space #\0)) t :delete)))))
		     (comment-state :delete))))
	     line))
;;
(defparameter *%f77.typemap* 
  '((("character") :char)
    (("character*") :string)
    (("character*1") :string)
    (("character*6") :string)
    (("integer") :integer)
    (("real") :single-float)
    (("double" "precision") :double-float)
    (("complex") :complex-single-float)
    (("double" "complex") :complex-double-float)
    (("complex*16") :complex-double-float)
    (("external") (* :void))
    (("dimension") nil)
    (("none") :void)))
;;
(defun %f77.type (line)
  (when-let (type (find line *%f77.typemap* :test #'(lambda (x y) (every #'string= x (car y)))))
    (list (cadr type) (nthcdr (length (car type)) line))))

(defun parse-fortran-file (fname)
  (let ((lines (mapcar #'%f77.tokenize (%f77.splitlines (string-downcase (file->string fname))))))
    (labels ((pointerp (pos line)
	       (let ((lst (nthcdr (1+ pos) line)))
		 (when (and (consp lst) (every #'(lambda (x y) (if (eql y t) t (string= x y))) lst '("(" t ")")))
		   (cadr lst))))
	     (parse-procedure (line)
	       (let* ((func-name (if (string= (car line) "subroutine")
				     (cadr line)
				     (elt line (1+ (position "function" line :test #'string=)))))
		      (output-type (if (string= (car line) "subroutine")
				       '("none")
				       (subseq line 0 (position "function" line :test #'string=))))
		      (arguments (mapcar #'(lambda (x) (list x nil nil)) (subseq line (1+ (position "(" line :test #'string=)) (position ")" line :test #'string=)))))
		 (do ((cline '("") (cond
				     ((null lines) (error "Cannot find END statement."))
				     ((string= (caar lines) "end") (pop lines) nil)
				     (t (pop lines)))))
		     ((null cline))
		   (when (member cline *%f77.typemap* :test #'(lambda (x y) (every #'string= x (car y))))
		     (let ((type (%f77.type cline)))
		       (if (car type)
			   (mapcar #'(lambda (x) (when (and (not (second x)) (find (car x) (cadr type) :test #'string=))
						   (setf (second x) (car type)
							 (third x) (pointerp (position (car x) (cadr type) :test #'string=) (cadr type)))))
				   arguments)
			   (mapcar #'(lambda (x) (when (and (not (third x)) (find (car x) (cadr type) :test #'string=))
						   (setf (third x) (pointerp (position (car x) (cadr type) :test #'string=) (cadr type)))))
				   arguments)))))
		 (list (intern (string-upcase func-name)) (car (%f77.type output-type)) (mapcar #'(lambda (x) (list (intern (string-upcase (car x)))
														   (if (null (third x))
														       (second x)
														       (list '* (second x)))))
											       arguments)))))
      (do ((line '("") (pop lines))
	   (defns nil))
	  ((null line) defns)
	(when (or (member "function" line :test #'string=)
		  (member "subroutine" line :test #'string=))
	  (push (parse-procedure line) defns))))))

