# dotfiles

Make sure you have `make` installed on your system. If not install it with `sudo pacman -S make`.

## install miminum packages for system

Install miminum packages for system. This expects that configs and data is restoreable by other means. Thus 
some app configs will not be installed with this command.

Change the default nerd font with argument `font=https://host/to/the/font.zip`.

Don't install nvidia with argument `nvidia=false`.

Target x11 with argument `wayland=false`.
```make
make install
```
Or just simply `make` as the `install` is the default goal.

## setup dev environment

Following command will setup full dev environment with configuring various tools needed for development work.

Skip ssh setup with argument `ssh=false`.
Define `host=...` arugment to copy ssh configs from for `dev-setup` command in order to configure ssh.

Define custom terminal for tmux with `terminal=...` if not defined, the current terminal will be used from `$TERM` env variable.

```make
make dev-setup
```

### manual install plugins

For neovim see the `README.md` of [nvim](https://github.com/juhaku/nvim) to see the plugins you should manually install via `mason`.
* Idea plugins: IdeaVim, Lombok optional: Flutter, Android
* Vscode plugins: Docker, Go, Prettier, Vim, Bash Ide, CodeLLB, crates, Flutter, Error Lens, ESLint, 
  Even Better TOML, rust-analyzer, GitLens, Kubernetes
