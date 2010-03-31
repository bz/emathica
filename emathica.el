;; emathica.el 
;; A Mathematica mode for GNU Emacs
;; http://github.com/bz/emathica

;; Copyright (C) 2010  Burkhard Zimmermann.

;; Font-lock support: derived from mma.el,
;; Copyright (C) 1999 - 2003 Tim Wichmannn,
;; http://www.itwm.fraunhofer.de/as/asemployees/wichmann/mma.html

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 2 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;; Mathematica is a registered trademark of Wolfram Research, Inc.

;; Author:     Burkhard Zimmermann <B.Zimmermann@risc.uni-linz.ac.at>
;; Maintainer: Burkhard Zimmermann <B.Zimmermann@risc.uni-linz.ac.at>
;; Site:       http://github.com/bz
;; Credits:    font-lock support is derived from Tim Wichmann's Emacs Mathematica mode mma.el.

;; Purpose:
;; --------
;;
;; emathica.el provides a fast edit-run-debug cycle for Mathematica programming under GNU Emacs.
;;
;;

;; Use:
;; ----
;;
;; emathica.el provides two Emacs major modes and a fast way to switch between them:
;;
;;
;;                        F2 (emathica-comint-load)
;;
;; foo.m                  ------------------------->      Mathematica buffer
;; emathica-m-mode                                        emathica-comint-mode
;;                        <-------------------------
;;
;;                        F2 (emathica-comint-find-error)
;;
;;
;; When editing foo.m in emathica-m-mode, [F2] (emathica-comint-load)
;; loads foo.m into a Mathematica kernel running as a subprocess of Emacs.
;; It starts this process unless it is already running,
;; and gives focus to the Mathematica interaction buffer.

;; Conversely, in emathica-comint-mode, [F2] (emathica-comint-find-error)
;; gives focus to the buffer for editing foo.m
;; If Mathematica found a syntax error, the cursor is on the error line.
;;

;; Installation under Linux
;; ------------------------

;; 0. Download and save emathica.el.
;;    http://github.com/bz/emathica

;; 1. Make sure that you can start Mathematica.
;;
;;    $ which math
;;    /usr/local/bin/math
;;
;;    $ /usr/local/bin/math
;;    Mathematica 7.0 for Linux x86 (64-bit)
;;    Copyright 1988-2008 Wolfram Research, Inc.
;;
;;    In[1]:= Quit[];

;; 2. Add the following to your ~/.emacs file:

;;    ; (2a)
;;    (setq load-path (append '("~/wherever/you/saved/it") load-path))
;;    ; where you saved emathica.el
;;
;;    (autoload 'emathica-m-mode "emathica.el" "Mathematica package file mode" t)
;;    (setq auto-mode-alist (cons '("\\.m\\'" . emathica-m-mode) auto-mode-alist))
;;
;;    ; (2b)
;;    (defcustom emathica-comint-program-name "/usr/local/bin/math")
;;    ; makes sure that we can start Mathematica.

;; 3. Test your installation:
;;
;;    a. Open a file foo.m in Emacs.
;;       If it is not in emathica-m-mode, then (2a) failed.
;;
;;    b. Press F2.
;;       If Mathematica does not start up in an Emacs buffer, step (2b) failed.
;;
;;

;;;; Code:

;;(defconst emathica-m-version "March 2010"
;;  "The version of emathica.el. Please indicate it when reporting bugs.")

(defgroup emathica-m nil
  "Emacs interface for editing Mathematica *.m files."
  :group 'languages)

(defvar emathica-m-mode-syntax-table nil
  "Syntax table used in emathica-m mode.")

(if emathica-m-mode-syntax-table
    ()
  (setq emathica-m-mode-syntax-table (make-syntax-table (standard-syntax-table)))
; %, &, ... are used for punctuation, ie they may not appear in identifiers.
  (modify-syntax-entry ?% "." emathica-m-mode-syntax-table)
  (modify-syntax-entry ?& "." emathica-m-mode-syntax-table)
  (modify-syntax-entry ?+ "." emathica-m-mode-syntax-table)
  (modify-syntax-entry ?- "." emathica-m-mode-syntax-table)
  (modify-syntax-entry ?/ "." emathica-m-mode-syntax-table)
  (modify-syntax-entry ?^ "." emathica-m-mode-syntax-table)
  (modify-syntax-entry ?< "." emathica-m-mode-syntax-table)
  (modify-syntax-entry ?= "." emathica-m-mode-syntax-table)
  (modify-syntax-entry ?> "." emathica-m-mode-syntax-table)
  (modify-syntax-entry ?| "." emathica-m-mode-syntax-table)
  (modify-syntax-entry ?_ "." emathica-m-mode-syntax-table)
; ' is used for mathematica "contexts".
; following wichmann, we consider it punctuation.
  (modify-syntax-entry ?\' "." emathica-m-mode-syntax-table)
; $ is allowed in identifiers
  (modify-syntax-entry ?$ "_" emathica-m-mode-syntax-table)
; \ is an escape
  (modify-syntax-entry ?\\ "\\" emathica-m-mode-syntax-table)
; " is a string quote
; ...
; the properties of ( are:
;   (: it is an open-parenthesis character.
;   ): its matching anticharacter is ).
;   1: it is the first character of the comment delimiters "(**)",
;   n:   such comments may [n]est.
; (bug in Wichmann's mode: "n" is missing).
  (modify-syntax-entry ?( "()1n" emathica-m-mode-syntax-table)

; the properties of ) are:
;   ): it is a close-parenthesis character.
;   (: its matching anticharacter is (.
;   4: it is the fourth character of the "(**)"
;   n:   such comments may [n]est.
  (modify-syntax-entry ?) ")(4n" emathica-m-mode-syntax-table)

; * has two functions:
; 1. punctuation
; 2. characters 2 and 3 in the comment delimiters "(**)"
;   n:   such comments may [n]est.
  (modify-syntax-entry ?* ". 23n" emathica-m-mode-syntax-table)

; the properties of [ are:
;   (: it is an open-parenthesis character.
;   ]: its matching anticharacter is ].
  (modify-syntax-entry ?\[ "(]" emathica-m-mode-syntax-table)

; the properties of ] are:
;   ): it is a close-parenthesis character.
;   [: its matching anticharacter is [.
  (modify-syntax-entry ?\] ")[" emathica-m-mode-syntax-table)

; the properties of { are:
;   (: it is an open-parenthesis character.
;   }: its matching anticharacter is }.
  (modify-syntax-entry ?\{ "(}" emathica-m-mode-syntax-table)

; the properties of } are:
;   ): it is a close-parenthesis character.
;   {: its matching anticharacter is {.
  (modify-syntax-entry ?\] ")[" emathica-m-mode-syntax-table)
)

(defvar emathica-m-mode-map ()
  "Key map to use in emathica-m mode.")

(setq emathica-m-mode-map (make-sparse-keymap))
(define-key emathica-m-mode-map [f2] 'emathica-comint-load)

(define-key emathica-m-mode-map [M-right] 'emathica-indent-selection-rigidly)
(define-key emathica-m-mode-map [M-left]  'emathica-dedent-selection-rigidly)

;; currently not in use, i.e. not bound to any key.
(defun emathica-switch-to-comint ()
  ""
  (interactive)
  (pop-to-buffer "*mathematica*"))

;; currently not in use, i.e. not bound to any key.
(defun emathica-switch-to-m ()
  ""
  (interactive)
  (pop-to-buffer emathica-comint-last-buffer))

(defvar emathica-m-font-lock-keywords-1
  (list
   '("\\(^[a-zA-Z]\\w*\\)\\([ \t]*=[ \t]*Compile\\|\\[\\([ \t]*\\]\\|.*\\(_\\|:\\)\\)\\)"
     1 font-lock-function-name-face)
;; and no keywords.
   ))

(defvar emathica-m-font-lock-keywords-2
  (append
   emathica-m-font-lock-keywords-1
   '(
     ("\\(\\(-\\|:\\)>\\|//[.@]?\\|/[.@;:]\\|@@\\|#\\(#\\|[0-9]*\\)\\|&\\)" 1 font-lock-keyword-face append)
     ("([*]:[a-zA-Z-]*:[*])" 0 font-lock-keyword-face t)
;;; This pattern is just for internal use...
;;;     ("([*]\\(:FILE-ID:\\).*:[*])" 1 font-lock-keyword-face t)
     ("\\(!=\\|=\\(!=\\|==?\\)\\)" 1 font-lock-reference-face)))
   "Gaudy level highlighting for emathica-m mode.")

(defvar emathica-m-font-lock-keywords emathica-m-font-lock-keywords-1
  "Default expressions to highlight in emathica-m mode.")

(defun emathica-m-mode ()
  "emathica-Mode.
Programming mode for writing Mathematica *.m package files.
Turning on emathica-m-mode runs the hook `emathica-m-mode-hook'.
\\{emathica-m-mode-map}"
  (interactive)
  ; kill all (non-permanent) buffer-local variables.
  (kill-all-local-variables)
  (use-local-map emathica-m-mode-map)
  (setq mode-name "emathica-m")
  (setq major-mode 'emathica-m-mode)

  (set-syntax-table emathica-m-mode-syntax-table)

  ; don't split the frame unless it is already split.
  ; use C-x 2 or C-x 3 to split the frame.
  (set (make-local-variable 'pop-up-windows) nil)

  ; i don't understand the following six lines
  (set (make-local-variable 'paragraph-start) (concat "$\\|" page-delimiter))
  (set (make-local-variable 'paragraph-separate) paragraph-start)
  (set (make-local-variable 'comment-start) "(* ")
  (set (make-local-variable 'comment-end) " *)")
  (set (make-local-variable 'comment-start-skip) "(\\*+ *")
  (set (make-local-variable 'comment-column) 48)

  (setq indent-tabs-mode nil) ; use space, not tab.
  (setq tab-width 2)


  ;; how to indent:
  (make-local-variable 'indent-line-function)
  (setq indent-line-function 'indent-relative-maybe)

;  (make-local-variable 'indent-region-function)
;  (setq indent-region-function 'emathica-indent-region)

  ;; dabbrev configuration:
  ; Goal: Free the user from the burden of using the shift key in dabbrev expansions.
  ; Example: Assume that somewhere in the program text we have a line
  ;
  ;   g = Expand[f];
  ;
  ; Now, for typing
  ;
  ;   Expand
  ;
  ; in the sequel, it suffices to type
  ;
  ;   ex <Alt>+"/"
  ;
  ; or
  ;
  ;   ex <tab>
  ;
  ; where <Alt>+"/" or <tab> calls dabbrev-expand. The point to note is that dabbrev-expand
  ; changes "ex" to "Expand", i.e., the case changes.
  ;
  ; dabbrev search should be case insensitive, for convenience.
  ;(set (make-local-variable 'case-fold-search) t)
  (set (make-local-variable 'dabbrev-case-fold-search) t)
  ; case of the expansion := case of the occurrence that is used as a template.
  ; Recall that case matters in mathematica.
  (set (make-local-variable 'dabbrev-case-replace)     nil )
  (set (make-local-variable 'dabbrev-abbrev-char-regexp) "\\sw") ; allow letters and numbers.
  ;(set (make-local-variable 'dabbrev-abbrev-char-regexp) "\\sw\\|\\[") ; allow number and [
  ; trouble: "Expand[1" is misinterpreted as an identifier.
  (set (make-local-variable 'dabbrev-friend-buffer-function)
      (lambda (buffer)
         (save-excursion
           (set-buffer buffer)
           (memq major-mode '(emathica-m-mode)))))


  ;; parse-sexp-ignore-comments should be set to nil. Otherwise matching
  ;; paren highlighting does not work properly.
  (set (make-local-variable 'parse-sexp-ignore-comments) nil)
;  (set (make-local-variable 'indent-line-function) 'emathica-m-indent-line)

  (make-local-variable 'font-lock-defaults)
  (setq font-lock-defaults
	'((emathica-m-font-lock-keywords
	   emathica-m-font-lock-keywords-1
	   emathica-m-font-lock-keywords-2)
	  nil nil ((?_ . "w")) beginning-of-defun
	  (font-lock-comment-start-regexp . "^([*]\\|[ \t]([*]")))

  ;; if on Emacs, initialize imenu index creation function
  (run-hooks 'emathica-m-mode-hook)
  ;(message "(run-hooks 'emathica-m-mode-hook)")

  (show-paren-mode t)           ; show matching parentheses in color.
  ; it seems, that it doesn't work for me: I have to call it interactively.
  (setq debug-flag 1)
)

; add 'emathica-m to the global variable features.
;(provide 'emathica-m)







;; Purpose:
;;
;; To send a buffer to another buffer running Mathematica.
;;
;; Installation:
;;
;; add this to .emacs:
;;
;;    (add-hook emathica-comint-mode-hook 'turn-on-mathematica)
;;
;; Customisation:
;;       The name of the mathematica interpreter is in variable
;;          emathica-comint-program-name
;;       Arguments can be sent to the Mathematica interpreter when it is called
;;       by setting the value of the variable
;;          emathica-comint-program-args
;;
;;       If the command does not seem to respond, see the
;;          content of the `comint-prompt-regexp' variable
;;          to check that it waits for the appropriate Mathematica prompt
;;          the current value is appropriate for Mathematica 1.0 - 4.2
;;
;;    `emathica-comint-mode-hook' is invoked in the *mathematica* once it is started.
;;
;;; All functions/variables start with
;;; `(turn-(on/off)-)mathematica' or `emathica-comint-'.

(defgroup mathematica nil
  "Major mode for interacting with an inferior Mathematica session."
  :group 'mathematica
  :prefix "emathica-comint-")




; makes the current buffer a mathematica mode buffer.
; do i lose any comint defaults by this?
(defun emathica-comint-mode ()
  "Major mode for interacting with an inferior Mathematica session.

\\<emathica-comint-mode-map>
Commands:
Return at end of buffer sends line as input.
Return not at end copies rest of line to end and sends it.
\\[emathica-comint-find-error] jumps to the error line in the corresponding *.m file,
\\[comint-interrupt-subjob] interrupts Mathematica,
\\[comint-quit-subjob] sends Mathematica the QUIT signal."
  (interactive)
  (comint-mode)
  (setq major-mode 'emathica-comint-mode)
  (setq mode-name "emathica-math")

  (setq emathica-comint-mode-map (copy-keymap comint-mode-map))
  (define-key emathica-comint-mode-map [f2] 'emathica-comint-find-error)
  (define-key emathica-comint-mode-map [pause] 'comint-interrupt-subjob)
  (define-key emathica-comint-mode-map [C-pause] 'comint-quit-subjob)   ; [C-pause] = Break on typical PC keyboards.
;  (define-key emathica-comint-mode-map [C-tab] 'switch-to-emathica-m) ; not nice. in mdi applications, Ctrl-tab cycles through /all/ documents.

  (use-local-map emathica-comint-mode-map)

  ; don't split the frame unless it is already split.
  ; use C-x 2 or C-x 3 to split the frame.
  (set (make-local-variable 'pop-up-windows) nil)


  ;; dabbrev settings for Mathematica
  ;;
  ;; Search for completions also in the associated emathica-m-mode buffer.
  (set (make-local-variable 'dabbrev-friend-buffer-function)
      (lambda (buffer) (eq buffer emathica-comint-last-buffer)))

  ; Goal: Free the user from the burden of using the shift key in dabbrev expansions.
  ; Example: Assume that somewhere in the program text we have a line
  ;
  ;   g = Expand[f];
  ;
  ; Now, for typing
  ;
  ;   Expand
  ;
  ; in the sequel, it suffices to type
  ;
  ;   ex <Alt>+"/"
  ;
  ; where <Alt>+"/" calls dabbrev-expand. The point to note is that dabbrev-expand
  ; changes "ex" to "Expand", i.e., the case changes.
  ;
  (set (make-local-variable 'dabbrev-case-fold-search) t)
  (set (make-local-variable 'dabbrev-case-replace)     nil )
  (set (make-local-variable 'dabbrev-abbrev-char-regexp) "\\sw") ; allow letters and numbers.

  ; experimental: reuse emathica-m-mode syntax highlighting here.
  (set-syntax-table emathica-m-mode-syntax-table)
  (set (make-local-variable 'paragraph-start) (concat "$\\|" page-delimiter))
  (set (make-local-variable 'paragraph-separate) paragraph-start)
  (set (make-local-variable 'comment-start) "(* ")
  (set (make-local-variable 'comment-end) " *)")
  (set (make-local-variable 'comment-start-skip) "(\\*+ *")
  (set (make-local-variable 'comment-column) 48)
  (make-local-variable 'font-lock-defaults)
  (setq font-lock-defaults
	'((emathica-m-font-lock-keywords
	   emathica-m-font-lock-keywords-1
	   emathica-m-font-lock-keywords-2)
	  nil nil ((?_ . "w")) beginning-of-defun
	  (font-lock-comment-start-regexp . "^([*]\\|[ \t]([*]")))
  ; /experimental: reuse emathica-m-mode syntax highlighting here.

  ; insert images produced by Mathematica.
  ; bug: If I add this, I /sometimes/ loose scroll-to-bottom in the mathematica comint buffer.
  ;      although it is still in the hooks.
  (add-hook  'comint-output-filter-functions 'emathica-comint-insert-images)

  )

; bug: with Emacs 21, no pictures at all appear.

; to do: Choosing the image size.

; to do: Offer PostScript as an alternative to png.
;        In a Postscript image, offer keybindings for zooming.
;        how can I communicate the bounding box from Mathematica to Emacs?

; to do: 1. use overlays.
;        2. allow toggling: text <--> graphics.
;           In particular, that is useful for
;        3. toggle when the cursor enters the overlay.

(defun emathica-comint-image-text (s)
   (propertize " " 'display (read s)))

; legacy
(defun emathica-comint-insert-images (s)
   (save-excursion
      (goto-char comint-last-output-start)
      (while (re-search-forward "<image>\\(\\(.\\|\n\\)*?\\)</image>"  nil t)
         (replace-match (emathica-comint-image-text (match-string-no-properties 1)))
      )
   )
)

;; Running Mathematica in a comint buffer.

(require 'comint)

(defvar emathica-comint-process nil
  "The active Mathematica subprocess corresponding to current buffer.")

(defvar emathica-comint-process-buffer nil
  "*Buffer used for communication with Mathematica subprocess for current buffer.")

; not needed?
(defvar emathica-comint-last-loaded-file nil
  "The last file loaded into the Mathematica process.")

; !!! has to be configured by the user !!!
(defcustom emathica-comint-program-name "math"
  "*The name of the command to start the Mathematica interpreter."
  :type 'string
  :group 'mathematica)

(defcustom emathica-comint-program-args '("")
  "*A list of string args to send to the mathematica process."
  :type '(repeat string)
  :group 'mathematica)

(defun emathica-comint-load ()
  "Save the buffer. Load it into Mathematica."
  (interactive)
  (message "before.")
  (save-excursion (emathica-comint-execute-get))
                 ;(emathica-comint-execute-get)
  ; fails with: "save-excursion: Marker does not point anywhere"
  ; /even/ if I remove the save-excursion. spooky!
  (message "after.") ; not executed, because it is after the bug.
  (pop-to-buffer emathica-comint-process-buffer)
  ; (emathica-comint-wait-for-output)
  ;(goto-char (point-max)) ; pointless fix added Jan 2008. aim: Bring me to the new prompt at the end of the buffer.
)

; bad: moves the point.
(defun emathica-comint-wait-for-output ()
  "Wait until output arrives and go to the last input."
  (while (progn
           (sleep-for 0 200) ; 200 milliseconds
           (message "waiting for the prompt.")
	   (goto-char comint-last-input-end)
	   (not (re-search-forward comint-prompt-regexp nil t)))
    (accept-process-output emathica-comint-process)))

; may be called when mathematica is already running.
; may be called even several times in a row; this does not matter.
(defun emathica-comint-start-process ()
  "Start a Mathematica process and invokes `emathica-comint-mode-hook' if not nil.
Prompts for a list of args if called with an argument."
  (interactive "P")
  (message "Starting `emathica-comint-process' %s" emathica-comint-program-name)
  (setq emathica-comint-process-buffer
    (make-comint "mathematica" emathica-comint-program-name))   ; "mathematica" means: buffername becomes *mathematica*
  (setq emathica-comint-process
        (get-buffer-process emathica-comint-process-buffer))
  ;; Select Mathematica buffer temporarily
  ; was:(set-buffer emathica-comint-process-buffer)
  ; is:
  ; (set-buffer emathica-comint-process-buffer) + making it visible:
  ; This function makes buffer-or-name the current buffer and switches to it in some window,
  ; preferably not the window previously selected. The "popped-to" window becomes the selected
  ; window within its frame.

  (pop-to-buffer emathica-comint-process-buffer)

;  (delete-other-windows) ; inserted Nov 20, 2004. Not ideal.
                         ; it should only be carried out the first time,
                         ; when a process is really started.
			 ; otherwise, the window layout should be kept.

  ; reason: to make (window-width), for Mathematicas PageWidth option, work.

  ;; Set the keymap (and the modename):
  (emathica-comint-mode)
;  (setq comint-prompt-regexp  "^\? \\|^[A-Z][_a-zA-Z0-9]*> ")
  (setq comint-prompt-regexp  "^In\[[0-9]+\]:= ")
    ;; comint's history syntax conflicts with Mathematica syntax, eg. !!
;  (setq comint-input-autoexpand nil)


  (run-hooks 'emathica-comint-mode-hook)
;  (message "emathica-comint-start-process terminated.")
  )

; (save-excursion (emathica-comint-execute-get))
; Get[...];
(defun emathica-comint-execute-get ();(load-command cd)
  "Save the current buffer and load its file into the Mathematica process."
  (let (file)
    ;?
    ;(hack-local-variables);; In case they've changed
    (save-buffer)
    (setq file (buffer-file-name))

    ; remember this in order to jump back to it, eg after an error.
    ; (we cannot read off the filename from the error message, due to //Short in the message)
    (setq emathica-comint-last-file (buffer-file-name))
    (setq emathica-comint-last-buffer (current-buffer))

    ; make sure the process is there.
    ; why not simply call emathica-comint-start-process in any case?
    (emathica-comint-start-process)

;;     (if (and emathica-comint-process-buffer
;;              (eq (process-status emathica-comint-process) 'run))
;; 	  ;; Ensure the Mathematica buffer is selected.
;; 	(set-buffer emathica-comint-process-buffer)
;;         ;; Start Mathematica process.
;;         (emathica-comint-start-process))

    ;; why?:
    ;; Wait until output arrives and go to the last input.
;    (emathica-comint-wait-for-output)


;    (emathica-comint-send
;     (format "Get[\"%s\"];" (emathica-comint-quote-filename file) ))




   (emathica-comint-send
         (format "Block[{Short=Identity},Get[\"%s\"]]; SetOptions[$Output, PageWidth-> %d];" (emathica-comint-quote-filename file) (- (window-width) 1)))

    ; Remark: Only the first command of a sequence of commands gets executed.
    ; All others are ignored.

;    (emathica-comint-send "1+1")
;    (pop-to-buffer emathica-comint-process-buffer)
;    (emathica-comint-wait-for-output)

;    (emathica-comint-send "2*2")
;    (pop-to-buffer emathica-comint-process-buffer)
;    (emathica-comint-wait-for-output)

     ; Once I introduced this trick to avoid line breaking in error messages:
    ;(emathica-comint-send
    ;     (format "SetOptions[$Output, PageWidth-> Infinity]; Block[{Short=Identity},Get[\"%s\"]]; SetOptions[$Output, PageWidth-> %d];" (emathica-comint-quote-filename file) (- (window-width) 1)))
     ; But it was not worth it:
     ; trouble 1: Printout during the execution of the Get[...] becomes garbeled.
     ; trouble 2: it takes the window-width of the *.m buffer, not of the *mathematica* comint buffer.

;    (emathica-comint-wait-for-output)
  )
)


(defun emathica-comint-send (&rest string)
  "Send `emathica-comint-process' the arguments (one or more strings).
A newline is sent after the strings and they are inserted into the
current buffer after the last output."
;  (emathica-comint-wait-for-output)
  (accept-process-output emathica-comint-process 0 100)
  (goto-char (point-max))
  (apply 'insert string)
  (comint-send-input)
  (goto-char (point-max))
)



; (marker-insertion-type comint-last-input-end)
; to do, not implemented yet.
; to do: find the name of elisp's string-quoting function.
(defun emathica-comint-quote-filename (filename)
  "quote special characters in filenames."
  filename)

;(emathica-comint-quote-filename "")
;(emathica-comint-quote-filename "My Documents\\mathematica.hs")


; (emathica-comint-show-errors)
(defun emathica-comint-find-error ()
  "If there is an error, set the cursor at the
error line, otherwise show the Mathematica buffer."
  (interactive)
  (set-buffer emathica-comint-process-buffer)
  (goto-char comint-last-input-start)
  (if (re-search-forward
       ; eg: Syntax::sntx: Syntax error in or before "SetAttributes[BatchResult, HoldAllComplete[; ".
       ; eg: (line 1 of "c:/examples/test.m")
       "^\\(.*\\)(line \\([0-9]+\\) of \"\\(.*\\)\")" nil t)
      (let ( ; Unfortunately, Mathematica applies //Short to the filename.
             ; so efile is often nonsense like
             ; "c:/Documents and Settin<<42>>rki/emathica.el"
            (efile (buffer-substring (match-beginning 3)
				     (match-end 3)))
            (eline (string-to-int (buffer-substring (match-beginning 2)
				     (match-end 2))))
	    (emesg (buffer-substring (match-beginning 1)
				     (match-end 1)))
           )

        ; is this a kind of clean-up?
        ;(pop-to-buffer  emathica-comint-process-buffer)
        (goto-char (point-max))
        ;(recenter)

	(message "%s, line %d: %s" (file-name-nondirectory efile) eline emesg)
	;(message "%s" emesg)

        ; jump to the error.

        ; this is a reasonable guess, but not necessary the right file:
	(set-buffer emathica-comint-last-buffer)
	(pop-to-buffer emathica-comint-last-buffer)
        (goto-line eline)

        ; maybe that would be better in case of several files.
        ; difficulty: to resolve efile in the same way as Matheamtica does.
        ; we should call Mathematica for doing the resolving.
;         (if (file-exists-p efile)
;             (progn (find-file-other-window efile)
;                    (if eline (goto-line eline))
;                    (recenter)))


        ) ; let

; else
    (progn
     ;(pop-to-buffer  emathica-comint-process-buffer) ; show *mathematica* buffer
     (goto-char (point-max))
;     (message "There were no errors.")
     ; even if there were no errors, we switch back to the source code.
     (pop-to-buffer emathica-comint-last-buffer)
     ;(recenter 2)                        ; show only the end...
    )
))

;; ; (emathica-comint-show-emathica-buffer)
;; (defun emathica-comint-show-emathica-buffer ()
;;   "Goes to the Mathematica buffer."
;;   (interactive)
;;   (if (or (not emathica-comint-process-buffer)
;;           (not (buffer-live-p emathica-comint-process-buffer)))
;;       (emathica-comint-start-process))
;;   (pop-to-buffer  emathica-comint-process-buffer)
;;   )


(defun emathica-indent-selection-rigidly-by (n)
  (let ((start (point))
	(end   (mark) ))
    (indent-rigidly (min start end) (max start end) n) ; min and max are indeed needed here.
    ;"preserves the shape" of the affected region, moving it as a rigid unit
))

(defun emathica-indent-selection-rigidly ()
  ""
  (interactive)
  (emathica-indent-selection-rigidly-by 1))

(defun emathica-dedent-selection-rigidly ()
  ""
  (interactive)
  (emathica-indent-selection-rigidly-by -1))


