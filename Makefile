.DEFAULT_GOAL = install
SHELL = /bin/bash

FLAVOR = $(shell echo $$XDG_CURRENT_DESKTOP)
PACMAN_FLAGS = --noconfirm
ICONS_DIR = /usr/share/icons
ICONS = window-close window-minimize window-maximize
IS_WAYLAND = $(shell if [[ "$$XDG_SESSION_TYPE" == "wayland" ]]; then echo true; else echo false; fi)
USER = $(shell cat /etc/passwd | grep $$(whoami) | awk -F : '{print $$5}')
LIGHT_GREEN = \e[92m
LIGHT_YELLOW = \e[93m
NOCOLOR = \e[0m

# default font
font = https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/SourceCodePro.zip
font-name = $(shell v=$(font); echo $${v##*/} | awk -F \. '{print $$1}')
wayland = true
nvidia=true
nvidia-prerequisite = $(if $(shell if [[ $(nvidia) == true ]]; then echo true; else echo ""; fi), install-nvidia)
slack-app = $(if $(shell if [[ $(wayland) == true ]]; then echo true; else echo ""; fi),slack-desktop-wayland,slack-desktop)
clipboard-util = $(if $(shell if [[ $(wayland) == true ]]; then echo true; else echo ""; fi),wl-clipboard,xclip)

gnome-applist = okular konsole ibus-libpinyin dconf-editor \
	breeze-icons kvantum qt5ct qt6ct qadwaitadecorations-qt6 \
	gnome-browser-connector gparted appimagelauncher-bin

kde-applist = partitionmanager fcitx5 fcitx5-breeze ksshaskpass plasma-systemmonitor fcitx5-chinese-addons \
	fcitx5-configtool plasma-browser-integration xdg-desktop-portal xdg-desktop-portal-kde kwalletmanager

flavor-apps = $(shell if [[ "$(FLAVOR)" == "GNOME" ]]; then echo $(gnome-applist); elif [[ "$(FLAVOR)" == "KDE" ]]; then echo $(kde-applist); fi)
applist = $(flavor-apps) neovim alacritty spotify $(slack-app) keepassxc telegram-desktop zsh \
		eza zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search \
		fzf fd git-delta npm fnm jdk21-openjdk $(clipboard-util) ripgrep go pika-backup \
		libreoffice-fresh maven yarn visual-studio-code-bin \
		intellij-idea-community-edition clang gimp git tig jq ufw

define app_installed =
$(shell cmd=$$(command -v $(1)); if test -x $${cmd:-""}; then echo true; else echo false; fi)
endef

# install system packages
install-system-packages: install-rust-toolchain
	@echo -e "$(LIGHT_GREEN)Install system packages$(NOCOLOR)"
	paru $(PACMAN_FLAGS) -S $(applist)
	sudo ufw enable

# install paru and alias it as yay if yay is not intalled
install-paru:
	@echo -e "$(LIGHT_GREEN)Install paru$(NOCOLOR)"
	sudo pacman $(PACMAN_FLAGS) -S paru
	$(shell if ! test -l /usr/bin/yay; then sudo ln -s /usr/bin/paru /usr/bin/yay; fi)

# install and configure rust
install-rust-toolchain: install-paru
	@echo -e "$(LIGHT_GREEN)Install rust toolchain$(NOCOLOR)"
	paru -S $(PACMAN_FLAGS) rustup
	rustup install stable nightly

# install nvidia and configure nvidia with wayland and suspend
install-nvidia: install-paru
	@echo -e "$(LIGHT_GREEN)Install and configure nvidia for wayland$(NOCOLOR)"
	paru -S $(PACMAN_FLAGS) nvidia-inst
	nvidia-inst
	sudo systemctl enable nvidia-resume.service nvidia-suspend.service nvidia-hibernate.service
	echo -e "options nvidia NVreg_PreserveVideoMemoryAllocations=1\noptions nvidia NVreg_TemporaryFilePath=/tmp" | sudo tee -a /lib/modprobe.d/system.conf
	sudo dracut --force
	sudo ln -s /dev/null /etc/udev/rules.d/61-gdm.rules

setup-terminal: install-system-packages
	@echo -e "$(LIGHT_GREEN)Setup terminal$(NOCOLOR)"
	curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | sh
	curl -sS https://starship.rs/install.sh | sh
	cp ./config/starship.toml ~/.config/starship.toml

# extended flavor specific configuration
configure:
	@echo -e "$(LIGHT_GREEN)Configure $(FLAVOR) specific settings$(NOCOLOR)"
	@if test -f $(FLAVOR).Makefile; then $(MAKE) -f $(FLAVOR).Makefile $@; else echo -e "$(LIGHT_YELLOW)No $(FLAVOR).Makefile found$(NOCOLOR)"; fi

# set time locale to en_GB
set-time-locale: 
	@echo -e "$(LIGHT_GREEN)Set time locale to match up rest of the system, using en_GB$(NOCOLOR)"
	localectl set-locale "LC_TIME=en_GB.UTF-8"

# enable bluetooth
setup-bluetooth: 
	@echo -e "$(LIGHT_GREEN)Enable bluetooth$(NOCOLOR)"
	sudo systemctl enable bluetooth.service
	sudo systemctl start bluetooth.service

setup-nerd-font:
	@echo -e "$(LIGHT_GREEN)Setup nerd font, change the font with parameter: font=... e.g. font=$(font)$(NOCOLOR)"
	curl -o ~/Downloads/$(font-name).zip -sSL $(font)
	unzip -d ~/Downloads/$(font-name) ~/Downloads/$(font-name).zip
	sudo cp -r ~/Downloads/$(font-name) /usr/share/fonts
	sudo fc-cache -f -v
	rm -r ~/Downloads/$(font-name)*

ifeq ($(wayland),true)
configure-spotify: install-system-packages
	@echo -e "$(LIGHT_GREEN)Configure spotify support wayland$(NOCOLOR)"
	sudo sed -i 's/Exec=.*/Exec=spotify --enable-features=UseOzonePlatform --ozone-platform=wayland --enable-features=WaylandWindowDecorations --uri=%U/' /usr/share/applications/spotify.desktop
else
configure-spotify:
	@echo -e "$(LIGHT_GREEN)Wayland set to false, skipping configure spotify$(NOCOLOR)"
endif

install: setup-bluetooth set-time-locale $(nvidia-prerequisite) setup-terminal configure \
	setup-nerd-font configure-spotify
	@echo -e "$(LIGHT_GREEN)Done!, Reboot recommended to take configuration changes effect$(NOCOLOR)"

email=

setup-git-configs:
	@echo -e "$(LIGHT_GREEN)Setup git configs$(NOCOLOR)"
	mkdir -p ~/.config/git/
	cp ./config/gitconfig ~/.config/git/config
	sed -i "s/{user}/$(USER)/" ~/.config/git/config
ifdef email
	sed -i "s/{email}/$(email)/" ~/.config/git/config
else
	@echo -n "Enter email for git config: "; read email; sed -i "s/{email}/$$email/" ~/.config/git/config
endif

ssh=true
host=

ifeq ($(ssh),true)
copy-ssh-configs:
	@echo -e "$(LIGHT_GREEN)Setup ssh configs$(NOCOLOR)"
	mkdir -p ~/.ssh
ifdef host
	scp $(host):~/sshconfig.zip ~/Downloads/
else
	@echo -n "Enter ssh host: "; read host; scp $$host:~/sshconfig.zip ~/Downloads/
endif
	unzip -d ~/Downloads/sshconfig/ ~/Downloads/sshconfig.zip
	cp ~/Downloads/sshconfig/* ~/.ssh/
	rm -r ~/Downloads/sshconfig*
else
copy-ssh-configs:
	@echo -e "$(LIGHT_GREEN)Skipping ssh setup$(NOCOLOR)"
endif

setup-code-configs:
	@echo -e "$(LIGHT_GREEN)Setup vscode configs$(NOCOLOR)"
	mkdir -p ~/.config/Code/User/
	cp ./config/code/keybindings.json ~/.config/Code/User/keybindings.json
	cp ./config/code/settings.json ~/.config/Code/User/settings.json

setup-idea-configs:
	@echo -e "$(LIGHT_GREEN)Setup intellij configs$(NOCOLOR)"
	cp ./config/.ideavimrc ~/.ideavimrc
	idea_dir=$$(ls -t ~/.config/JetBrains/ | xargs | awk '{print $$1}'); \
		mkdir -p ~/.config/JetBrains/$$idea_dir/keymaps/; \
		cp ./config/'GNOME copy.xml' ~/.config/JetBrains/$$idea_dir/keymaps/'GNOME copy.xml'

setup-alacritty:
	@echo -e "$(LIGHT_GREEN)Setup alacritty$(NOCOLOR)"
	mkdir -p ~/.config/alacritty/
	cp ./config/alacritty.toml ~/.config/alacritty/alacritty.toml
	mkdir -p ~/.config/alacritty/themes && git clone https://github.com/alacritty/alacritty-theme ~/.config/alacritty/themes

setup-zshrc:
	@echo -e "$(LIGHT_GREEN)Setup zshrc$(NOCOLOR)"
	chsh -s $$(which zsh)
	cp ./config/.zshrc ~/.zshrc

setup-neovim:
	@echo -e "$(LIGHT_GREEN)Setup neovim$(NOCOLOR)"
	git clone $(shell if [[ $(ssh) == true ]]; then echo git@github.com:juhaku/nvim.git; else echo https://github.com/juhaku/nvim; fi) ~/.config/nvim
	mkdir -p ~/.local/share/nvim/jdtls-libs/
	mkdir -p ~/.local/share/nvim/jdtls/
	cd ~/.local/share/nvim/jdtls-libs && git clone https://github.com/microsoft/java-debug && cd java-debug &&\
		./mvnw clean install
	cd ~/.local/share/nvim/jdtls-libs && git clone https://github.com/microsoft/vscode-java-test && cd vscode-java-test &&\
		npm install && npm run build-plugin
	curl -sSL -o ~/.local/share/nvim/jdtls-libs/lombok.jar https://projectlombok.org/downloads/lombok.jar

install-watchmux:
	@echo -e "$(LIGHT_GREEN)Install watchmux$(NOCOLOR)"
	cargo install --git https://github.com/juhaku/watchmux

dev-setup: setup-git-configs copy-ssh-configs setup-code-configs setup-idea-configs setup-alacritty setup-zshrc \
	install-watchmux setup-neovim
	@echo -e "$(LIGHT_GREEN)Done, Happy coding  !$(NOCOLOR)"

