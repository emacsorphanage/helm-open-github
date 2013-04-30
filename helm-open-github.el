;;; helm-open-github.el --- Utilities of Opening Github Page

;; Copyright (C) 2013 by Syohei YOSHIDA

;; Author: Syohei YOSHIDA <syohex@gmail.com>
;; URL: https://github.com/syohex/emacs-open-github
;; Version: 0.02
;; Package-Requires: ((helm "1.0") (gh "1.0"))

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

;; Open github URL utilities. This package is inspired by URL below.
;;   - http://shibayu36.hatenablog.com/entry/2013/01/18/211428

;;; Code:

(eval-when-compile
  (require 'cl))

(require 'helm)
(require 'gh-issues)

(defgroup helm-open-github nil
  "Utilities of opeg "
  :prefix "helm-open-github-"
  :group 'http)

(defcustom helm-open-github-commit-limit 100
  "Limit of commit id collected"
  :type 'integer
  :group 'helm-open-github)

(defcustom helm-open-github-issues-api
  (gh-issues-api "api" :sync t :cache nil :num-retries 1)
  "Github API instance. This is-a `gh-issues'"
  :group 'helm-open-github)

(defun helm-open-github--collect-commit-id ()
  (let ((cmd (format "git --no-pager log -n %d --pretty=oneline --abbrev-commit"
                     helm-open-github-commit-limit)))
    (with-current-buffer (helm-candidate-buffer 'global)
      (let ((ret (call-process-shell-command cmd nil t)))
        (unless (zerop ret)
          (error "Failed: git log(retval=%d)" ret))))))

(defun helm-open-github--command-one-line (cmd)
  (with-temp-buffer
    (let ((ret (call-process-shell-command cmd nil t)))
      (when (zerop ret)
        (goto-char (point-min))
        (buffer-substring-no-properties
         (line-beginning-position) (line-end-position))))))

(defun helm-open-github--full-commit-id (abbrev-id)
  (let ((cmd (concat "git rev-parse " abbrev-id)))
    (or (helm-open-github--command-one-line cmd)
        (error "Failed: %s" cmd))))

(defun helm-open-github--root-directory ()
  (let ((root (helm-open-github--command-one-line "git rev-parse --show-toplevel")))
    (if (not root)
        (error "Error: here is not Git repository")
      (file-name-as-directory root))))

(defun helm-open-github--host ()
  (or (helm-open-github--command-one-line "git config --get hub.host")
      "github.com"))

(defun helm-open-github--remote-url ()
  (let ((cmd "git config --get remote.origin.url"))
    (or (helm-open-github--command-one-line cmd)
        (error "Failed: %s" cmd))))

(defun helm-open-github--extract-user-host (remote-url)
  (if (string-match "[:/]\\([^/]+\\)/\\([^/]+?\\)\\.git\\'" remote-url)
      (values (match-string 1 remote-url) (match-string 2 remote-url))
    (error "Failed: match %s" remote-url)))

(defun helm-open-github--commit-url (host remote-url commit-id)
  (multiple-value-bind (user repo) (helm-open-github--extract-user-host remote-url)
    (format "https://%s/%s/%s/commit/%s"
            host user repo commit-id)))

(defun helm-open-github--from-commit-open-url-common (commit-id)
  (let* ((host (helm-open-github--host))
         (remote-url (helm-open-github--remote-url)))
    (browse-url
     (helm-open-github--commit-url host remote-url commit-id))))

(defun helm-open-github--from-commit-open-url (line)
  (let* ((commit-line (split-string line " "))
         (commit-id (helm-open-github--full-commit-id (car commit-line))))
    (helm-open-github--from-commit-open-url-common commit-id)))

(defun helm-open-github--from-commit-open-url-with-input (unused)
  (let ((commit-id (read-string "Input Commit ID: ")))
    (helm-open-github--from-commit-open-url-common
     (helm-open-github--full-commit-id commit-id))))

(defun helm-open-github--show-commit-id-common (commit-id)
  (with-current-buffer (get-buffer-create "*open-github-issues*")
    (let* ((cmd (format "git show --stat -p %s" commit-id))
           (ret (call-process-shell-command cmd nil t)))
      (unless (zerop ret)
        (error "Error: %s" cmd))
      (goto-char (point-min))
      (pop-to-buffer (current-buffer)))))

(defun helm-open-github--show-commit-id (line)
  (let* ((commit-line (split-string line " "))
         (commit-id (helm-open-github--full-commit-id (car commit-line))))
    (helm-open-github--show-commit-id-common commit-id)))

(defun helm-open-github--show-commit-id-with-input (unused)
  (let ((commit-id (read-string "Input Commit ID: ")))
    (helm-open-github--show-commit-id-common
     (helm-open-github--full-commit-id commit-id))))

(defvar helm-open-github--from-commit-source
  '((name . "Open Github From Commit")
    (init . helm-open-github--collect-commit-id)
    (candidates-in-buffer)
    (action . (("Open Commit Page" . helm-open-github--from-commit-open-url)
               ("Show Detail" . helm-open-github--show-commit-id)))))

(defvar helm-open-github--from-commit-direct-input-source
  '((name . "Open Github From Commit Direct Input")
    (candidates . ("Input Commit ID"))
    (action . (("Open Commit Page" . helm-open-github--from-commit-open-url-with-input)
               ("Show Detail" . helm-open-github--show-commit-id-with-input)))))

;;;###autoload
(defun helm-open-github-from-commit ()
  (interactive)
  (helm :sources '(helm-open-github--from-commit-source
                   helm-open-github--from-commit-direct-input-source)
        :buffer "*open github*"))

(defun helm-open-github--collect-files ()
  (let ((root (helm-open-github--root-directory)))
    (with-current-buffer (helm-candidate-buffer 'global)
      (let* ((default-directory root)
             (cmd "git ls-files")
             (ret (call-process-shell-command cmd nil t)))
        (unless (zerop ret)
          (error "Failed: %s(%s)" cmd default-directory))))))

(defun helm-open-github--branch ()
  (let* ((cmd "git symbolic-ref HEAD")
         (branch (helm-open-github--command-one-line cmd)))
    (if (not branch)
        (error "Failed: %s" cmd)
      (replace-regexp-in-string "\\`refs/heads/" "" branch))))

(defun helm-open-github--file-url (host remote-url branch file marker)
  (multiple-value-bind (user repo) (helm-open-github--extract-user-host remote-url)
    (format "https://%s/%s/%s/blob/%s/%s%s"
            host user repo branch file marker)))

(defun helm-open-github--highlight-marker (start end)
  (cond ((and start end)
         (format "#L%s..L%s" start end))
        (start
         (format "#L%s" start))
        (t "")))

(defun helm-open-github--from-file-action (file &optional start end)
  (let ((host (helm-open-github--host))
        (remote-url (helm-open-github--remote-url))
        (branch (helm-open-github--branch))
        (marker (helm-open-github--highlight-marker start end)))
    (browse-url
     (helm-open-github--file-url host remote-url branch file marker))))

(defun helm-open-github--from-file-highlight-region-action (file)
  (let ((start-line (read-number "Start Line: "))
        (end-line (read-number "End Line: ")))
    (helm-open-github--from-file-action file start-line end-line)))

(defun helm-open-github--from-file-highlight-line-action (file)
  (let ((start-line (read-number "Start Line: ")))
    (helm-open-github--from-file-action file start-line)))

(defvar helm-open-github--from-file-source
  '((name . "Open Github From File")
    (init . helm-open-github--collect-files)
    (candidates-in-buffer)
    (action . (("Open File" .
                (lambda (file) (helm-open-github--from-file-action file)))
               ("Open File and Highlight Line"
                . helm-open-github--from-file-highlight-line-action)
               ("Open File and Highlight Region"
                . helm-open-github--from-file-highlight-region-action)))))

(defun helm-open-github--from-file-direct (file start end)
  (let* ((root (helm-open-github--root-directory))
         (repo-path (file-relative-name file root))
         (start-line (line-number-at-pos start))
         (end-line (line-number-at-pos end)))
    (helm-open-github--from-file-action repo-path start-line end-line)))

;;;###autoload
(defun helm-open-github-from-file ()
  (interactive)
  (if mark-active
      (helm-open-github--from-file-direct (buffer-file-name) (region-beginning) (region-end))
    (helm :sources '(helm-open-github--from-file-source)
          :buffer "*open github*")))

(defun helm-open-github--collect-issues ()
  (let ((host (helm-open-github--host))
        (remote-url (helm-open-github--remote-url)))
    (multiple-value-bind (user repo) (helm-open-github--extract-user-host remote-url)
      (let ((issues (gh-issues-issue-list helm-open-github-issues-api user repo)))
        (if (null issues)
            (error "This repository has no issues!!")
          (sort (oref issues data)
                (lambda (a b) (< (oref a number) (oref b number)))))))))

(defun helm-open-github--convert-issue-api-url (url)
  (replace-regexp-in-string
   "api\\." ""
   (replace-regexp-in-string "/repos" "" url)))

(defun helm-open-github--from-issues-real-to-display (issue)
  (with-slots (number title state) issue
    (format "#%-4d [%s] %s" number state title)))

(defvar helm-open-github--from-issues-source
  '((name . "Open Github From Issues")
    (candidates . helm-open-github--collect-issues)
    (volatile)
    (real-to-display . helm-open-github--from-issues-real-to-display)
    (action . (lambda (issue)
                (browse-url
                 (helm-open-github--convert-issue-api-url (oref issue url)))))))

(defun helm-open-github--construct-issue-url (host remote-url issue-id)
  (multiple-value-bind (user repo) (helm-open-github--extract-user-host remote-url)
    (format "https://%s/%s/%s/issues/%s"
            host user repo issue-id)))

(defun helm-open-github--from-issues-direct (host)
  (let ((remote-url (helm-open-github--remote-url))
        (issue-id (read-number "Issue ID: ")))
    (browse-url
     (helm-open-github--construct-issue-url host remote-url issue-id))))

;;;###autoload
(defun helm-open-github-from-issues ()
  (interactive)
  (let ((host (helm-open-github--host)))
    (if (not (string= host "github.com"))
        (helm-open-github--from-issues-direct host)
      (helm :sources '(helm-open-github--from-issues-source)
            :buffer  "*open github*"))))

(provide 'helm-open-github)

;;; helm-open-github.el ends here
