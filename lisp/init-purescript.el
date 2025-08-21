;;; init-purescript.el --- Support the PureScript language -*- lexical-binding: t -*-
;;; Commentary:
;;; Code:

(when (maybe-require-package 'purescript-mode)
  ;; Basic editing
  (add-hook 'purescript-mode-hook 'turn-on-purescript-indentation)

  ;; Auto-sort imports on save
  (add-hook 'purescript-mode-hook
            (lambda ()
              (add-hook 'before-save-hook 'purescript-sort-imports nil t)))

  ;; Prettify symbols
  (defun purescript-prettify-symbols ()
    "Add PureScript-specific prettify symbols."
    (setq-local prettify-symbols-alist
                '(("forall" . ?∀)
                  ("->"     . ?→)
                  ("=>"     . ?⇒)
                  ("<-"     . ?←)
                  ("<="     . ?≤)
                  (">="     . ?≥)
                  ("/="     . ?≠))))

  (add-hook 'purescript-mode-hook #'purescript-prettify-symbols)
  (add-hook 'purescript-mode-hook #'prettify-symbols-mode)


  ;; Keybinding tweak
  (with-eval-after-load 'purescript-mode
    (define-key purescript-mode-map (kbd "C-o") 'open-line))

  ;; Set default-directory to spago project root
  (defun purescript-set-project-root ()
    "Set `default-directory` to the root of the current Spago project."
    (let ((root (locate-dominating-file default-directory "spago.yaml")))
      (when root
        (setq-local default-directory root))))

  (add-hook 'purescript-mode-hook #'purescript-set-project-root)

  ;; Formatter: purs-tidy
  (when (maybe-require-package 'reformatter)
    (reformatter-define purs-tidy
      :program "purs-tidy"
      :lighter " tidy"))

  ;; Ensure local node_modules/.bin is on PATH
  (defun add-node-modules-bin-to-buffer-path ()
    "Add local node_modules/.bin to `exec-path` and PATH for this buffer."
    (let ((bin-dir (expand-file-name "node_modules/.bin/" (locate-dominating-file default-directory "package.json"))))
      (when (and bin-dir (file-directory-p bin-dir))
        ;; Make exec-path buffer-local and prepend
        (setq-local exec-path (cons bin-dir exec-path))
        ;; Update PATH for subprocesses
        (setenv "PATH" (concat bin-dir path-separator (getenv "PATH"))))))

  ;; Add it to purescript-mode buffers
  (add-hook 'purescript-mode-hook #'add-node-modules-bin-to-buffer-path)

  ;; LSP support
  (defun purescript-lsp-setup ()
    "Set up buffer-local PATH/exec-path for PureScript and start LSP."
    (let ((bin-dir (expand-file-name "node_modules/.bin/"
                                     (locate-dominating-file default-directory "package.json"))))
      (when (and bin-dir (file-directory-p bin-dir))
        (setq-local exec-path (cons bin-dir exec-path))
        (setenv "PATH" (concat bin-dir path-separator (getenv "PATH")))))
    (lsp))  ;; now start LSP

  (when (maybe-require-package 'lsp-mode)
    (add-hook 'purescript-mode-hook #'purescript-lsp-setup))

  ;; Inline errors
  (when (maybe-require-package 'flycheck)
    (add-hook 'purescript-mode-hook 'flycheck-mode))

  ;; Default build command
  (add-hook 'purescript-mode-hook
            (lambda ()
              (setq-local compile-command "npx spago build")))

  ;; Support for Spago auto-build and run
  (defun purescript-spago-build-buffer ()
    "Return the comint buffer for spago builds, creating it if necessary."
    (let* ((buffer-name "*Spago Build*"))
      (unless (comint-check-proc buffer-name)
        ;; Start a new comint process running bash
        (make-comint-in-buffer "Spago Build" buffer-name "bash"))
      (get-buffer buffer-name)))

  (defun purescript-spago-execute (cmd)
    "Run `npx spago build` in the persistent comint buffer in a split."
    (let ((default-directory (locate-dominating-file default-directory "spago.yaml"))
          (buf (purescript-spago-build-buffer)))
      (when default-directory
        ;; Open buffer in vertically split right side
        (display-buffer
         buf
         '((display-buffer-in-side-window)
           (side . right)
           (window-width . 0.5)
           (inhibit-same-window . t)))
        ;; Send the build command
        (comint-send-string (get-buffer-process buf) cmd))))

  (defun purescript-spago-build ()
    (interactive)
    (purescript-spago-execute "npx spago build\n"))

  (defun purescript-spago-run ()
    (interactive)
    (purescript-spago-execute "npx spago run\n"))

  (defvar-local purescript-auto-reload t
    "If non-nil, automatically reload modules in the REPL on save.")

  (defun purescript-toggle-auto-reload ()
    "Toggle auto-reloading in the REPL on save."
    (interactive)
    (setq purescript-auto-reload (not purescript-auto-reload))
    (message "Purescript auto-reload %s"
             (if purescript-auto-reload "enabled" "disabled")))

  (defun purescript-maybe-auto-build ()
    (when purescript-auto-reload
      (purescript-spago-build)))

  (defun purescript-auto-build-on-save ()
    "Add buffer-local after-save hook to build PureScript project."
    (add-hook 'after-save-hook #'purescript-maybe-auto-build nil t))

  (add-hook 'purescript-mode-hook #'purescript-auto-build-on-save)

  ;; Keybindings
  (with-eval-after-load 'purescript-mode
    (define-key purescript-mode-map (kbd "C-c r") 'purescript-spago-run)
    (define-key purescript-mode-map (kbd "C-c b") 'purescript-toggle-auto-reload)))

(provide 'init-purescript)
;;; init-purescript.el ends here
