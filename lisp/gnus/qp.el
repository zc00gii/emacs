;;; qp.el --- Quoted-Printable functions

;; Copyright (C) 1998, 1999, 2000 Free Software Foundation, Inc.

;; Author: Lars Magne Ingebrigtsen <larsi@gnus.org>
;; Keywords: mail, extensions

;; This file is part of GNU Emacs.

;; GNU Emacs is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:

;; Functions for encoding and decoding quoted-printable text as
;; defined in RFC 2045.

;;; Code:

(defun quoted-printable-decode-region (from to &optional charset)
  "Decode quoted-printable in the region between FROM and TO, per RFC 2045.
If CHARSET is non-nil, decode bytes into characters with that charset."
  (interactive "r")
  (save-excursion
    (save-restriction
      (let ((nonascii-insert-offset nonascii-insert-offset)
	    ;; RFC 2045:  An "=" followed by two hexadecimal digits,
	    ;; one or both of which are lowercase letters in "abcdef",
	    ;; is formally illegal. A robust implementation might
	    ;; choose to recognize them as the corresponding uppercase
	    ;; letters.
	    (case-fold-search t))
	(if charset
	    (setq nonascii-insert-offset (- (make-char charset) 128)))
	(narrow-to-region from to)
	(goto-char from)
	(while (and (skip-chars-forward "^=" to)
		    (not (eobp)))
	  (cond ((eq (char-after (1+ (point))) ?\n)
		 (delete-char 2))
		((looking-at "=[0-9A-F][0-9A-F]")
		 (let ((byte (string-to-int (buffer-substring (1+ (point))
							      (+ 3 (point)))
					    16)))
		   (if (and charset (fboundp 'unibyte-char-to-multibyte))
		       (insert (unibyte-char-to-multibyte byte))
		     (insert byte))
		   (delete-region (point) (+ 3 (point)))
		   (unless (eq byte ?=)
		     (backward-char))))
		((eq (char-after (1+ (point))) ?=)
		 (forward-char)
		 (delete-char 1))
		(t
		 (message "Malformed MIME quoted-printable message")
		 (forward-char))))))))

(defun quoted-printable-decode-string (string &optional charset)
  "Decode the quoted-printable encoded STRING and return the result.
If CHARSET is non-nil, decode the region with charset."
  (with-temp-buffer
    (insert string)
    (quoted-printable-decode-region (point-min) (point-max) charset)
    (buffer-string)))

(defun quoted-printable-encode-region (from to &optional fold class)
  "Quoted-printable encode the region between FROM and TO per RFC 2045.

If FOLD, fold long lines at 76 characters (as required by the RFC).
If CLASS is non-nil, translate the characters matched by that class in
the form expected by `skip-chars-forward'.

If `mm-use-ultra-safe-encoding' is set, fold lines unconditionally and
encode lines starting with \"From\"."
  (interactive "r")
  ;; Fixme: what should this do in XEmacs/Mule?
  (if (fboundp 'find-charset-region)	; else XEmacs, non-Mule
      (if (delq 'unknown		; Emacs 20 unibyte
		(delq 'eight-bit-graphic ; Emacs 21
		      (delq 'eight-bit-control
			    (delq 'ascii (find-charset-region from to)))))
	  (error "Multibyte character in QP encoding region")))
  (unless class
    (setq class "^\000-\007\013\015-\037\200-\377="))
  (if (fboundp 'string-as-multibyte)
      (setq class (string-as-multibyte class)))
  (save-excursion
    (save-restriction
      (narrow-to-region from to)
      ;; Encode all the non-ascii and control characters.
      (goto-char (point-min))
      (while (and (skip-chars-forward class)
		  (not (eobp)))
	(insert
	 (prog1
	     (format "=%02x" (upcase (char-after)))
	   (delete-char 1))))
      ;; Encode white space at the end of lines.
      (goto-char (point-min))
      (while (re-search-forward "[ \t]+$" nil t)
	(goto-char (match-beginning 0))
	(while (not (eolp))
	  (insert
	   (prog1
	       (format "=%02x" (upcase (char-after)))
	     (delete-char 1)))))
      (let ((mm-use-ultra-safe-encoding
	     (and (boundp 'mm-use-ultra-safe-encoding)
		  mm-use-ultra-safe-encoding)))
	(when (or fold mm-use-ultra-safe-encoding)
	  ;; Fold long lines.
	  (let ((tab-width 1))		; HTAB is one character.
	    (goto-char (point-min))
	    (while (not (eobp))
	      ;; In ultra-safe mode, encode "From " at the beginning
	      ;; of a line.
	      (when mm-use-ultra-safe-encoding
		(beginning-of-line)
		(when (looking-at "From ")
		  (replace-match "From=20" nil t)))
	      (end-of-line)
	      (while (> (current-column) 76) ; tab-width must be 1.
		(beginning-of-line)
		(forward-char 75)	; 75 chars plus an "="
		(search-backward "=" (- (point) 2) t)
		(insert "=\n")
		(end-of-line))
	      (unless (eobp)
		(forward-line)))))))))

(defun quoted-printable-encode-string (string)
  "Encode the STRING as quoted-printable and return the result."
  (with-temp-buffer
    (insert string)
    (quoted-printable-encode-region (point-min) (point-max))
    (buffer-string)))

(provide 'qp)

;;; qp.el ends here
