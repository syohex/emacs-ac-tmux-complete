;;; ac-tmux-complete.el --- auto complete with content of tmux panes

;; Copyright (C) 2014 by Syohei YOSHIDA

;; Author: Syohei YOSHIDA <syohex@gmail.com>
;; URL: https://github.com/syohex/emacs-ac-tmux-complete
;; Version: 0.01
;; Package-Requires: ((auto-complete "1.4") (cl-lib "0.5"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;;; Code:

(require 'cl-lib)
(require 'auto-complete)

(defsubst ac-tmux-complete--in-tmux-p ()
  (or (getenv "TMUX") (getenv "TMUX_PANE")))

(defun ac-tmux-complete--collect-panes ()
  (with-temp-buffer
    (unless (zerop (call-process "tmux" nil t nil "list-panes" "-F" "#P"))
      (error "Faild: 'tmux list-panes -F #P"))
    (goto-char (point-min))
    (let (panes)
      (while (not (eobp))
        (push (buffer-substring-no-properties
               (line-beginning-position) (line-end-position)) panes)
        (forward-line 1))
      (reverse panes))))

(defun ac-tmux-complete--trim (str)
  (let ((left-trimed (if (string-match "\\`[ \t\n\r]+" str)
                         (replace-match "" t t str)
                       str)))
    (if (string-match "[ \t\n\r]+\\'" left-trimed)
        (replace-match "" t t left-trimed)
      left-trimed)))

(defun ac-tmux-complete--split-line (line)
  (unless (string-match-p "\\`\\s-*\\'" line)
    (mapcar 'ac-tmux-complete--trim (append (split-string line)
                                            (split-string line "[^a-zA-Z0-9_]+")))))

(defun ac-tmux-complete--remove-space-candidates (candidates)
  (cl-remove-if (lambda (c) (string-match-p "\\`\\s-*\\'" c)) candidates))

(defun ac-tmux-complete--parse-capture-output ()
  (goto-char (point-min))
  (let ((candidates nil))
    (while (not (eobp))
      (let* ((line (buffer-substring-no-properties
                    (line-beginning-position) (line-end-position)))
             (words (ac-tmux-complete--split-line line)))
        (when words
          (setq candidates (append words candidates)))
        (forward-line 1)))
    candidates))

(defun ac-tmux-complete--capture-pane (pane-id)
  (with-temp-buffer
    (unless (zerop (call-process "tmux" nil t nil
                                 "capture-pane" "-J" "-p" "-t" pane-id))
      (error "Failed: 'tmux capture-pane -J -p -t %s'" pane-id))
    (let* ((candidates (ac-tmux-complete--parse-capture-output))
           (sorted (sort candidates 'string<)))
      (cl-delete-duplicates sorted :test 'equal)
      (ac-tmux-complete--remove-space-candidates sorted))))

(defun ac-tmux-complete--collect-candidates (panes)
  (cl-loop for pane in panes
           appending (ac-tmux-complete--capture-pane pane)))

(defun ac-tmux-complete--filter-candidates (prefix candidates)
  (cl-loop with regexp = (format "\\`%s." prefix)
           for candidate in candidates
           when (string-match-p regexp candidate)
           collect candidate))

(defun ac-tmux-complete--candidates ()
  (unless (ac-tmux-complete--in-tmux-p)
    (error "Not running inside tmux!!"))
  (let* ((panes (ac-tmux-complete--collect-panes))
         (candidates (ac-tmux-complete--collect-candidates panes))
         (filtered (ac-tmux-complete--filter-candidates ac-prefix candidates)))
    filtered))

;;;###autoload
(defun ac-tmux-complete-ac-setup ()
  "Add `ac-source-tmux-complete' to `ac-sources' and enable `auto-complete' mode"
  (interactive)
  (add-to-list 'ac-sources 'ac-source-tmux-complete)
  (unless auto-complete-mode
    (auto-complete-mode +1)))

(ac-define-source tmux-complete
  `((candidates . ac-tmux-complete--candidates)
    (requires . 0)
    (symbol . "s")))

(provide 'ac-tmux-complete)

;;; ac-tmux-complete.el ends here
