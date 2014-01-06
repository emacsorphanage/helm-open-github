# helm-open-github.el
*helm-open-github.el* is utilities for opening github url.
This is inspired by URL below.

* http://shibayu36.hatenablog.com/entry/2013/01/18/211428

## screenshot

![open-github-from-commit](image/helm-open-github-from-commit.png)


## Dependency

* Emacs 23.4 or higher
* [helm](https://github.com/emacs-helm/helm)
* [gh](https://github.com/sigma/gh.el)


## Basic Usage

### `helm-open-github-from-commit`

Open commit page from **Commit ID**

### `helm-open-github-from-file`

Open file page from **File Name**

### `helm-open-github-from-issues`

Open issue page from **Issue ID**

### `helm-open-github-from-pull-requests`

Open pull request page from **Pull Request ID**


## Customize

### `helm-open-github-commit-limit`

Issue number shown by `helm-open-github-from-commit`.(Default is 100)


## Sample Configuration

```elisp
(require 'helm-open-github)
(global-set-key (kbd "C-c o f") 'helm-open-github-from-file)
(global-set-key (kbd "C-c o c") 'helm-open-github-from-commit)
(global-set-key (kbd "C-c o i") 'helm-open-github-from-issues)
(global-set-key (kbd "C-c p p") 'helm-open-github-from-pull-requests)
```
