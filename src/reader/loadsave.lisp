(in-package #:matlisp)

#+(not :sbcl)
(defun file->string (path)
  "Sucks up an entire file from PATH into a freshly-allocated string,
returning two values: the string and the number of bytes read."
  (declare (optimize (safety 0) (speed 3)))
  (with-open-file (s path :external-format :iso8859-1)
    (let* ((len (file-length s))
	   (data (make-array len :element-type 'standard-char)))
      (values data (read-sequence data s)))))

#+sbcl
(defun file->string (path)
"Sucks up an entire file from PATH into a freshly-allocated string,
returning two values: the string and the number of bytes read."
  (let* ((fsize (with-open-file (s path)
		  (file-length s)))
	 (data (make-array fsize :element-type 'standard-char))
	 (fd (sb-posix:open path 0)))
    (unwind-protect (sb-posix:read fd (sb-sys:vector-sap data) fsize)
      (sb-posix:close fd))
    (values data fsize)))
;;
(definline split-seq (test seq &optional (filter-empty? t))
  "Split a string, wherever the given character occurs."
  (loop :for i :from (1- (length seq)) :downto -1
     :with prev := (length seq)
     :with split-list := nil
     :with split-count := 0
     :do (when (or (< i 0) (funcall test (aref seq i)))
	   (let ((str (subseq seq (1+ i) prev)))
	     (when (or (< (1+ i) prev) (not filter-empty?))
	       (incf split-count)
	       (push str split-list))
	     (setf prev i)))
     :finally (return (values split-list split-count))))
;;
(defun splitlines (string)
  "Split the given string wherever the Carriage-return occurs."
  (split-seq #'(lambda (x) (or (char= x #\Newline) (char= x #\Return))) string))

;;
(defun loadtxt (fname &key (delimiters '(#\Space #\Tab #\,)) (newlines '(#\Newline #\;)))
  (let* ((f-string (file->string fname)))
    (multiple-value-bind (lns nrows) (split-seq #'(lambda (x) (member x newlines)) f-string)
      (unless (null lns)
	(let* ((ncols (second (multiple-value-list (split-seq #'(lambda (x) (member x delimiters)) (car lns)))))
	       (ret (zeros (list nrows ncols) 'real-tensor)))
	  (loop :for line :in lns
	     :for i := 0 :then (1+ i)
	     :do (loop :for num :in (split-seq #'(lambda (x) (member x delimiters)) line)
		    :for j := 0 :then (1+ j)
		    :do (setf (ref ret i j) (t/coerce (t/field-type real-tensor) (read-from-string num)))))
	  ret)))))

(defun savetxt (fname mat &key (delimiter #\Tab) (newline #\Newline))
  (with-open-file (out fname :direction :output :if-exists :overwrite :if-does-not-exist :create)
    (let ((ncols (ncols mat)))
      (loop :for i :from 0 :below (nrows mat)
	 :do (loop :for j :from 0 :below ncols
		:do (format out "~a~a" (ref mat i j) (if (= j (1- ncols)) newline delimiter)))))
    nil))