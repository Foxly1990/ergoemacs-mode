;;; ergoemacs-map.el --- Ergoemacs map interface -*- lexical-binding: t -*-

;; Copyright © 2013-2015  Free Software Foundation, Inc.

;; Filename: ergoemacs-map.el
;; Description:
;; Author: Matthew L. Fidler
;; Maintainer: 
;; Created: Sat Sep 28 20:10:56 2013 (-0500)
;; Version: 
;; Last-Updated: 
;;           By: 
;;     Update #: 0
;; URL: 
;; Doc URL: 
;; Keywords: 
;; Compatibility: 
;; 
;; Features that might be required by this library:
;;
;;   None
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 
;;; Commentary: 
;; 
;;
;; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 
;;; Change Log:
;; 
;; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.
;; 
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;; 
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 
;;; Code:

(eval-when-compile
  (require 'ergoemacs-macros)
  (require 'cl))

(defvar ergoemacs-keyboard-layout)
(defvar cl-struct-ergoemacs-component-struct-tags)
(defvar ergoemacs-keymap)
(defvar ergoemacs-keyboard-layout)
(defvar ergoemacs-menu-keymap)
(defvar ergoemacs-theme)
(defvar ergoemacs-map-properties--plist-hash)
(defvar ergoemacs-dir)
(defvar ergoemacs-mode)

(declare-function ergoemacs-setcdr "ergoemacs-lib")

(declare-function ergoemacs-component-struct--lookup-hash "ergoemacs-component")
(declare-function ergoemacs-component-struct--minor-mode-map-alist "ergoemacs-component")
(declare-function ergoemacs-component-struct--translated-list "ergoemacs-component")
(declare-function ergoemacs-component-struct--get "ergoemacs-component")
(declare-function ergoemacs-component-struct--lookup-list "ergoemacs-component")

(declare-function ergoemacs-theme-components "ergoemacs-theme-engine")
(declare-function ergoemacs-theme--menu "ergoemacs-theme-engine")

(declare-function ergoemacs-mapkeymap "ergoemacs-mapkeymap")

(declare-function ergoemacs-map-properties--composed-list "ergoemacs-map-properties")
(declare-function ergoemacs-map-properties--composed-p "ergoemacs-map-properties")
(declare-function ergoemacs-map-properties--empty-p "ergoemacs-map-properties")
(declare-function ergoemacs-map-properties--get-or-generate-map-key "ergoemacs-map-properties")
(declare-function ergoemacs-map-properties--key-struct "ergoemacs-map-properties")
(declare-function ergoemacs-map-properties--keymap-value "ergoemacs-map-properties")
(declare-function ergoemacs-map-properties--keys "ergoemacs-map-properties")
(declare-function ergoemacs-map-properties--label "ergoemacs-map-properties")
(declare-function ergoemacs-map-properties--lookup "ergoemacs-map-properties")
(declare-function ergoemacs-map-properties--map-fixed-plist "ergoemacs-map-properties")
(declare-function ergoemacs-map-properties--new-command "ergoemacs-map-properties")
(declare-function ergoemacs-map-properties--original "ergoemacs-map-properties")
(declare-function ergoemacs-map-properties--put "ergoemacs-map-properties")
(declare-function ergoemacs-map-properties--user "ergoemacs-map-properties")
(declare-function ergoemacs-map-properties--user-original "ergoemacs-map-properties")
(declare-function ergoemacs-map-properties--installed-p "ergoemacs-map-properties")
(declare-function ergoemacs-map-properties--original-user "ergoemacs-map-properties")

(declare-function ergoemacs-translate--escape-to-meta "ergoemacs-translate")

(declare-function ergoemacs-key-description "ergoemacs-key-description")


(defvar ergoemacs-map--hash (make-hash-table :test 'equal)
  "Hash of calculated maps")

(defvar ergoemacs-map--alist (make-hash-table))
(defun ergoemacs-map--alist (alist &optional symbol)
  "Apply maps for ALIST."
  (let (type old-len)
    (if (and symbol (setq old-len (gethash symbol ergoemacs-map--alist))
             (= (length alist) old-len)) alist
      (when symbol
        (puthash symbol (length alist) ergoemacs-map--alist))
      (mapcar
       (lambda(elt)
         (cond
          ;; ((not (ergoemacs-sv (car elt)))
          ;;  ;; not enabled, ignore any changes to this map...?
          ;;  elt)
          ((eq (car elt) 'ergoemacs-mode) elt)
          
          ((and (not (setq type (ergoemacs (cdr elt) :installed-p))) ergoemacs-mode)
           ;; Install `ergoemacs-mode' into the keymap
           (cons (car elt) (ergoemacs (cdr elt))))
          ((not type)
           ;; Install `ergoemacs-mode' user protection into the keymap.
           (cons (car elt) (ergoemacs (cdr elt) :original-user)))
          ((eq :cond-map type)
           ;; Don't change conditional maps.  Change in alists...?
           elt)
          ((and ergoemacs-mode (eq :protected-p type))
           ;; Change protection into full ergoemacs-mode installation
           (cons (car elt) (ergoemacs (ergoemacs (cdr elt) :original)))
           )
          ((eq :protected-p type)
           ;; `ergoemacs-mode' already protected this map
           elt)
          ((and ergoemacs-mode type)
           ;; `ergoemacs-mode' already installed
           elt)
          ((and (not ergoemacs-mode) type)
           ;; Change full `ergoemacs-mode' installation to user
           ;; installation
           (cons (car elt) (ergoemacs (ergoemacs (cdr elt) :original-user))))))
       alist))))

(defvar ergoemacs-map--alists (make-hash-table))
(defun ergoemacs-map--alists (alists &optional symbol)
  "Apply maps for ALISTS"
  (let (old-len)
    ;; Only modify if the list has changed length.
    (unless (and symbol (setq old-len (gethash symbol ergoemacs-map--alists))
                 (= (length alists) old-len))
      (when symbol
        (puthash symbol (length alists) ergoemacs-map--alists))
      (mapcar
       (lambda(elt)
         (cond
          ((consp elt)
           (ergoemacs-map--alist (list elt)))
          (t
           (set elt (ergoemacs-map--alist (symbol-value elt) elt))
           elt)))
       alists))))

(defun ergoemacs-map--emulation-mode-map-alists ()
  "Modify the `emulation-mode-map-alists'."
  (setq emulation-mode-map-alists (ergoemacs-map--alists emulation-mode-map-alists 'emulation-mode-map-alists))
  ;; FIXME: put translations and read key at the top.
  )

(defun ergoemacs-map--minor-mode-overriding-map-alist ()
  "Modify `minor-mode-overriding-map-alist'"
  (setq minor-mode-overriding-map-alist (ergoemacs-map--alist minor-mode-overriding-map-alist 'minor-mode-overriding-map-alist)))

(defun ergoemacs-map--minor-mode-map-alist (&optional ini)
  "Modify `minor-mode-map-alist'"
  (let (ret)
    (when (and ini (not ergoemacs-mode))
      (let (new-lst)
        (dolist (elt minor-mode-map-alist)
          (unless (or (eq (car elt) 'ergoemacs-mode)
                      (eq 'cond-map (car (ergoemacs (cdr elt) :map-key))))
            (push elt new-lst)))
        (setq minor-mode-map-alist (reverse new-lst))))
    
    (setq ret (ergoemacs-map--alist minor-mode-map-alist 'minor-mode-map-alist))

    (when (and ini ergoemacs-mode ret (not (ignore-errors (eq 'cond-map (car (ergoemacs (cdr (last ret)) :map-key))))))
      (setq ret (append ret (ergoemacs-component-struct--minor-mode-map-alist))))
    (setq minor-mode-map-alist ret)
    ret))

(defun ergoemacs-map--base-lookup-key (map-list)
  "Lookup Base key for MAP-LIST"
  (let ((map map-list)
        lookup-key)
    (catch 'all-struct
      (dolist (cur-map map)
        (if (ergoemacs-component-struct-p cur-map)
            (push (intern (format "%s%s"
                                  (ergoemacs-component-struct-name cur-map)
                                  (or (and (ergoemacs-component-struct-version cur-map)
                                           (concat "::" (ergoemacs-component-struct-version cur-map)))
                                      ""))) lookup-key)
          (throw 'all-struct
                 (setq lookup-key nil))))
      (setq lookup-key (reverse lookup-key))
      (push (or (and (stringp ergoemacs-keyboard-layout) (intern ergoemacs-keyboard-layout)) ergoemacs-keyboard-layout)
            lookup-key)
      t)
    lookup-key))

(defun ergoemacs-map--md5 (&optional map-list)
  "Get the MD5 for MAP-LIST.
MAP-LIST is the list of theme components if not pre-specified."
  (md5 (format "%s" (ergoemacs-map--base-lookup-key (ergoemacs-component-struct--lookup-hash (or map-list (ergoemacs-theme-components)))))))

(defvar ergoemacs-map-- (make-hash-table :test 'equal))
(defun ergoemacs-map-- (&optional lookup-keymap layout map recursive)
  "Get map looking up changed keys in LOOKUP-MAP based on LAYOUT.

MAP can be a `ergoemacs-component-struct', or a string/symbol
of a calculated or uncalcuated component in
`ergoemacs-component-hash'

MAP can also be a list of `ergoemacs-component-struct' values
or string/symbols that are in `ergoemacs-component-hash'

If missing, MAP represents the current theme compenents, from `ergoemacs-theme-components'

LAYOUT represents the layout that is used.

RECURSIVE is an internal argument to make sure that infinite
loops do not occur.

LOOKUP-KEYMAP represents what should be calculated/looked up.

If LOOKUP-KEYMAP is a keymap, lookup the ergoemacs-mode modifications to that keymap.

If LOOKUP-KEYMAP 
"
  (let* ((cur-layout (or layout ergoemacs-keyboard-layout))
         lookup-key
         (map (ergoemacs-component-struct--lookup-hash (or map (ergoemacs-theme-components))))
         unbind-list
         parent
         composed-list
         (read-map (make-sparse-keymap))
         tmp-key
         tmp
         ret)
    (cond
     ((consp (ergoemacs lookup-keymap :map-key)) ;; Ignore already installed.
      lookup-keymap)
     ((ergoemacs-component-struct-p map)
      (let ((ret (cond
                  ((and (not lookup-keymap)
                        (string= cur-layout (ergoemacs-component-struct-layout map)))
                   (ergoemacs-component-struct-map map))
                  ((and (not lookup-keymap)
                        (setq ret (gethash
                                   (list nil (intern cur-layout))
                                   (ergoemacs-component-struct-calculated-layouts map))))
                   ret)
                  ((not lookup-keymap)
                   ;; Overall layout hasn't been calculated.
                   (ergoemacs-component-struct--get map cur-layout nil))
                  (t
                   (error "Cant calculate/lookup keymap.")))))
        (ergoemacs-mapkeymap
         (lambda(key item _prefix)
           (unless (eq item 'ergoemacs-prefix)
             (puthash key item ergoemacs-map--)))
         ret)
        ret))
     ((and (consp map) ;; Don't do anything with blank keymaps.
           lookup-keymap
           (or (equal lookup-keymap (make-sparse-keymap))
               (equal lookup-keymap (make-keymap))))
      lookup-keymap)
     ((and (consp map)
           (setq lookup-key (ergoemacs-map--base-lookup-key map))
           (not lookup-keymap)
           (setq lookup-key (append (list (ergoemacs (ergoemacs :global-map) :key-struct)) lookup-key))
           (setq ret (gethash lookup-key ergoemacs-map--hash)))
      ret)
     ((and (consp map) lookup-key lookup-keymap
           (setq lookup-key (append (list (ergoemacs lookup-keymap :key-struct)) lookup-key))
           (setq ret (gethash lookup-key ergoemacs-map--hash)))
      ret)
     ((and (consp map) lookup-key
           (progn
             (dolist (cur-map map)
               (setq unbind-list (append unbind-list
                                         (ergoemacs-component-struct--translated-list
                                          cur-map (ergoemacs-component-struct-unbind cur-map)))))
             t)
           )
      (cond
       ((not lookup-keymap)
        ;; The `undefined-key' layer
        (setq tmp (make-sparse-keymap))
        (dolist (cur-map map)
          (dolist (undefined-key
                   (ergoemacs-component-struct--translated-list cur-map (ergoemacs-component-struct-undefined cur-map)))
            (unless (member undefined-key ret)
              (define-key tmp undefined-key 'ergoemacs-map-undefined))))
        (ergoemacs tmp :label (list (ergoemacs (ergoemacs :global-map) :key-struct) 'ergoemacs-undefined (intern ergoemacs-keyboard-layout)))
        
        (push tmp composed-list)
        
        ;; Each ergoemacs theme component
        (dolist (cur-map (reverse map))
          (setq tmp (ergoemacs-map-- lookup-keymap layout cur-map t))
          (unless (ergoemacs tmp :empty-p)
            (push tmp composed-list)))

        ;; The real `global-map'
        (setq parent (copy-keymap (ergoemacs :global-map)))

        ;; The keys that will be unbound
        (setq ret (make-sparse-keymap))
        (dolist (key unbind-list)
          (when (not lookup-keymap)
            (remhash key ergoemacs-map--))
          (define-key ret key nil))
        (ergoemacs ret :label (list (ergoemacs (ergoemacs :global-map) :key-struct) 'ergoemacs-unbound (intern ergoemacs-keyboard-layout)))

        
        (set-keymap-parent ret (make-composed-keymap composed-list parent))
        
        ;; Get the protecting user keys
        (setq tmp (ergoemacs parent :user))
        (when tmp
          (setq ret (make-composed-keymap tmp ret)))
        
        ;; Define the read-key map
        (dolist (cur-map map)
          (dolist (read-key
                   (ergoemacs-component-struct--translated-list cur-map (ergoemacs-component-struct-read-list cur-map)))
            (define-key read-map read-key 'ergoemacs-read-key-default)))
        (ergoemacs read-map :label (list (ergoemacs (ergoemacs :global-map) :key-struct) 'ergoemacs-read (intern ergoemacs-keyboard-layout))))
       
       ;; Now create the keymap for a specified `lookup-keymap'
       (lookup-keymap
        (setq lookup-keymap (ergoemacs lookup-keymap :original))
        (setq ret (make-sparse-keymap))
        (maphash
         (lambda(key item)
           (cond
            ;; Mode specific keys are translated to `ergoemacs-mode'
            ;; equivalent key binding
            ((setq tmp (ergoemacs lookup-keymap :new-command item))
             (define-key ret key tmp)
             (setq tmp-key (ergoemacs-translate--escape-to-meta key))
             (when tmp-key
               ;; Define the higher character as well.
               (define-key ret tmp-key tmp)))
            ;; Accept default for other keys
            ((and (setq tmp (lookup-key lookup-keymap [t])) 
                  (not (integerp tmp)))
             ;; No need to define these keys
             ;; (define-key ret key item)
             ;; (when (setq tmp-key (ergoemacs-translate--escape-to-meta key))
             ;;   ;; Define the higher character meta as well...
             ;;   (define-key ret tmp-key item))
             )
            ;; Keys where `ergoemacs-mode' dominates...
            ((and (setq tmp (lookup-key lookup-keymap key t))
                  (not (integerp tmp)))
             (define-key ret key item)
             (when (setq tmp-key (ergoemacs-translate--escape-to-meta key))
               ;; Define the higher character meta as well...
               (define-key ret tmp-key item)))
            ((and (setq tmp-key (ergoemacs-translate--escape-to-meta key))
                  (setq tmp (lookup-key lookup-keymap tmp-key t))
                  (not (integerp tmp)))
             ;; Define both
             (define-key ret tmp-key item)
             (define-key ret key item))))
         ergoemacs-map--)
        
        (setq tmp (ergoemacs global-map :keys))

        ;; Define ergoemacs-mode remapping lookups.
        (ergoemacs-mapkeymap
         (lambda(key item _prefix)
           (unless (eq item 'ergoemacs-prefix)
             (when (member key tmp)
               (define-key ret (vector 'ergoemacs-remap (gethash key (ergoemacs global-map :lookup)))
                 item))))
         lookup-keymap)
        
        (ergoemacs ret :label (list (ergoemacs lookup-keymap :key-struct) 'ergoemacs-mode (intern ergoemacs-keyboard-layout)))
        
        (setq tmp (ergoemacs-component-struct--lookup-list lookup-keymap))
        
        (setq composed-list (or (and tmp (append tmp (list ret))) (list ret))
              ret nil
              parent (and (not recursive) lookup-keymap))

        ;; The keys that will be unbound
        (setq ret (make-sparse-keymap))
        (dolist (key unbind-list)
          (when (not lookup-keymap)
            (remhash key ergoemacs-map--))
          (define-key ret key nil))
        (ergoemacs ret :label (list (ergoemacs lookup-keymap :key-struct) 'ergoemacs-unbound (intern ergoemacs-keyboard-layout)))
        
        (set-keymap-parent ret (make-composed-keymap composed-list parent))

        ;; Get the protecting user keys
        (setq tmp (ergoemacs parent :user))
        (when tmp
          (setq ret (make-composed-keymap tmp ret)))

        
        ;; Define the read-key map
        (dolist (cur-map map)
          (dolist (read-key
                   (ergoemacs-component-struct--translated-list cur-map (ergoemacs-component-struct-read-list cur-map)))
            (define-key read-map read-key 'ergoemacs-read-key-default)))
        
        (ergoemacs read-map :label (list (ergoemacs lookup-keymap :key-struct) 'ergoemacs-read (intern ergoemacs-keyboard-layout)))
        ))
      
      ;; (when lookup-key
      ;;   (puthash lookup-key ret ergoemacs-map--hash)
      ;;   (puthash (cons 'read-map lookup-key) read-map ergoemacs-map--hash))
      ret)
     ((and (not composed-list) parent)
      (unwind-protect
          (progn
            (set-keymap-parent lookup-keymap nil)
            (setq ret (ergoemacs-map-- lookup-keymap layout map t)))
        (set-keymap-parent lookup-keymap parent))
      (setq parent (ergoemacs-map-- parent layout map t))
      (set-keymap-parent ret parent)
      ret)
     (composed-list
      (make-composed-keymap
       (mapcar
        (lambda(x)
          (ergoemacs-map-- x layout map t))
        composed-list)
       (ergoemacs-map-- parent layout map t)))
     (t
      (error "Component map isn't a proper argument")))))

(defvar ergoemacs-map--modify-active-last-overriding-terminal-local-map nil)
(defvar ergoemacs-map--modify-active-last-overriding-local-map nil)
(defvar ergoemacs-map--modify-active-last-char-map nil)
(defvar ergoemacs-map--modify-active-last-local-map nil)
(defun ergoemacs-map--modify-active (&optional ini)
  "Modifies Active maps."
  (let ((char-map (get-char-property (point) 'keymap))
        (local-map (get-text-property (point) 'local-map)))

    ;; Restore `overriding-terminal-local-map' if needed
    (when (and ergoemacs-mode (eq ergoemacs-command-loop-type :full) (not overriding-terminal-local-map))
      (setq overriding-terminal-local-map ergoemacs-command-loop--overriding-terminal-local-map
            ergoemacs-command-loop--displaced-overriding-terminal-local-map nil))
    
    (when (and ergoemacs-mode overriding-terminal-local-map)
      (cond
       ((and (eq ergoemacs-command-loop-type :full) ;; Correct `overriding-terminal-local-map'
             (eq overriding-terminal-local-map ergoemacs-command-loop--overriding-terminal-local-map)))
       ((and (eq ergoemacs-command-loop-type :full))
        ;; Different `overriding-terminal-local-map'; modify and displace.
        (if (ergoemacs overriding-terminal-local-map :installed-p)
            (setq ergoemacs-command-loop--displaced-overriding-terminal-local-map overriding-terminal-local-map
                  overriding-terminal-local-map ergoemacs-command-loop--overriding-terminal-local-map)
          (setq ergoemacs-command-loop--displaced-overriding-terminal-local-map (ergoemacs overriding-terminal-local-map)
                overriding-terminal-local-map ergoemacs-command-loop--overriding-terminal-local-map)))
       
       ((and (not (eq overriding-terminal-local-map ergoemacs-map--modify-active-last-overriding-terminal-local-map))
             (not (ergoemacs overriding-terminal-local-map :installed-p)))
        ;; Modify `overriding-terminal-local-map'
        (setq overriding-terminal-local-map (ergoemacs overriding-terminal-local-map)))))
    
    (when (and overriding-local-map
               (not (eq overriding-local-map ergoemacs-map--modify-active-last-overriding-local-map))
               (not (ergoemacs overriding-local-map :installed-p)))
      (setq overriding-local-map (ergoemacs overriding-local-map)))

    (when (and char-map
               (not (eq char-map ergoemacs-map--modify-active-last-char-map))
               (not (ergoemacs char-map :installed-p)))
      (setf char-map (ergoemacs char-map)))

    (when (and local-map
               (not (eq local-map ergoemacs-map--modify-active-last-local-map))
               (not (ergoemacs local-map :installed-p)))
      (setf local-map (ergoemacs local-map)))

    
    (setq ergoemacs-map--modify-active-last-overriding-terminal-local-map overriding-terminal-local-map
          ergoemacs-map--modify-active-last-overriding-local-map overriding-local-map
          ergoemacs-map--modify-active-last-char-map char-map
          ergoemacs-map--modify-active-last-local-map local-map)
    (ergoemacs-map--emulation-mode-map-alists)
    (ergoemacs-map--minor-mode-map-alist ini)
    (ergoemacs-map--minor-mode-overriding-map-alist)))

(defun ergoemacs-map--install ()
  (interactive)
  (ergoemacs-mode-line)
  (define-key ergoemacs-menu-keymap [menu-bar ergoemacs-mode]
    `("ErgoEmacs" . ,(ergoemacs-theme--menu (ergoemacs :current-theme))))

  (let ((x (assq 'ergoemacs-mode minor-mode-map-alist)))
    (while x
      (setq minor-mode-map-alist (delq x minor-mode-map-alist))
      ;; Multiple menus sometimes happen because of multiple 
      ;; ergoemacs-mode variables in minor-mode-map-alist
      (setq x (assq 'ergoemacs-mode minor-mode-map-alist)))
    (push (cons 'ergoemacs-mode ergoemacs-menu-keymap) minor-mode-map-alist))
  
  (message "Global")
  (setq ergoemacs-map-- (make-hash-table :test 'equal)
        ergoemacs-keymap (ergoemacs)
        ergoemacs-map--alist (make-hash-table)
        ergoemacs-map--alists (make-hash-table))
  (use-global-map ergoemacs-keymap)
  (ergoemacs-map--modify-active t)
  (add-hook 'post-command-hook #'ergoemacs-map--modify-active))

(add-hook 'ergoemacs-mode-startup-hook #'ergoemacs-map--install)

(defvar ergoemacs-mode)
(defun ergoemacs-map--remove ()
  "Remove `ergoemacs-mode'"
  (interactive)
  ;; Not needed; Global map isn't modified...
  (let (ergoemacs-mode)
    (use-global-map global-map)
    (setq ergoemacs-map--alist (make-hash-table)
          ergoemacs-map--alists (make-hash-table))
    (ergoemacs-map--modify-active t)))

(defun ergoemacs-map-undefined ()
  "Lets the user know that this key is undefined in `ergoemacs-mode'."
  (interactive)
  (let ((key (ergoemacs-key-description (this-single-command-keys)))
        (old-key (lookup-key (ergoemacs :global-map) (this-single-command-keys))))
    (cond
     ((and old-key (not (integerp old-key)))
      (message "%s is disabled! Use %s for %s instead." key (ergoemacs-key-description (where-is-internal old-key ergoemacs-keymap t)) old-key))
     (t
      (message "%s is disabled!" key)))))

(add-hook 'ergoemacs-mode-shutdown-hook 'ergoemacs-map--remove)

(autoload 'ergoemacs (expand-file-name "ergoemacs-macros.el" ergoemacs-dir) nil t)
(provide 'ergoemacs)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; ergoemacs-map.el ends here
;; Local Variables:
;; coding: utf-8-emacs
;; End:
