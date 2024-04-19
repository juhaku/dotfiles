.DEFAULT_GOAL = install
SHELL = /bin/bash

FLAVOR = $(shell echo $$XDG_CURRENT_DESKTOP)
PACMAN_FLAGS = --noconfirm
ICONS_DIR = /usr/share/icons
ICONS = window-close window-minimize window-maximize
IS_WAYLAND = $(shell if [[ "$$XDG_SESSION_TYPE" == "wayland" ]]; then echo true; else echo false; fi)
USER = $(shell cat /etc/passwd | grep $$(whoami) | awk -F : '{print $$5}')

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
	fcitx5-configtool plasma-browser-integration

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
	@echo "Install system packages"
	paru $(PACMAN_FLAGS) -S $(applist)
	xdg-mime default org.gnome.Nautilus.desktop inode/directory

# install paru and alias it as yay if yay is not intalled
install-paru:
	@echo "Install paru"
	sudo pacman $(PACMAN_FLAGS) -S paru
	$(shell if ! test -l /usr/bin/yay; then sudo ln -s /usr/bin/paru /usr/bin/yay; fi)

# install and configure rust
install-rust-toolchain: install-paru
	@echo "Install rust toolchain"
	paru -S $(PACMAN_FLAGS) rustup
	rustup install stable nightly

# install nvidia and configure nvidia with wayland and suspend
install-nvidia: install-paru
	@echo "Install and configure nvidia for wayland"
	paru -S $(PACMAN_FLAGS) nvidia-inst
	nvidia-inst
	sudo systemctl enable nvidia-resume.service nvidia-suspend.service nvidia-hibernate.service
	echo -e "options nvidia NVreg_PreserveVideoMemoryAllocations=1\noptions nvidia NVreg_TemporaryFilePath=/tmp" | sudo tee -a /lib/modprobe.d/system.conf
	sudo dracut --force
	sudo ln -s /dev/null /etc/udev/rules.d/61-gdm.rules

setup-terminal:
	@echo "Setup terminal"
	curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh
	curl -sS https://starship.rs/install.sh | sh
	cp ./config/starship.toml ~/.config/starship.toml

# setup ssh agent
setup-ssh:
	@echo "Setup ssh agent"
	systemctl enable --user gcr-ssh-agent.socket
	systemctl start --user gcr-ssh-agent.socket
	echo 'export SSH_AUTH_SOCK=$$XDG_RUNTIME_DIR/gcr/ssh' | tee .zprofile

# set time locale to en_GB
set-time-locale: 
	@echo "Set time locale to match up rest of the system, using en_GB"
	localectl set-locale "LC_TIME=en_GB.UTF-8"

# enable bluetooth
setup-bluetooth: 
	@echo "Enable bluetooth"
	sudo systemctl enable bluetooth.service
	sudo systemctl start bluetooth.service

# set global environment variables
set-environment: install-system-packages
	@echo "Set qt environment"
	echo "QT_QPA_PLATFORMTHEME=qt6ct" | sudo tee -a /etc/environment
	echo "QT_WAYLAND_DECORATION=adwaita" | sudo tee -a /etc/environment
	@echo "Set ibus environment"
	sudo echo -e "GTK_IM_MODULE=ibus\nQT_IM_MODULE=ibus\nXMODIFIERS=@im=ibus" | sudo tee -a /etc/environment
	@echo "Change editor to neovim"
	sudo sed -i 's/EDITOR=.*/EDITOR=nvim/' /etc/environment

# create breeze-dark-adwaita flavor ionc theme
create-breeze-adwaita-icons: install-system-packages
	@echo "Create breeze-dark-adwaita flavor icon theme"
	sudo cp -r $(ICONS_DIR)/breeze-dark $(ICONS_DIR)/breeze-dark-adwaita
	$(foreach icon, $(ICONS), find $(ICONS_DIR)/breeze-dark-adwaita/ -name "*$(icon)*" -exec sudo rm {} \;; ) 
	sudo mkdir -p $(ICONS_DIR)/breeze-dark-adwaita/symbolic/ui/
	$(foreach icon, $(ICONS), find $(ICONS_DIR)/Adwaita/ -name "*$(icon)-symbolic.svg" -exec sudo cp {} $(ICONS_DIR)/breeze-dark-adwaita/symbolic/ui/$(icon)-symbolic.svg \;; )
	sudo sed -i 's/Name=.*/Name=Breeze Dark Adwaita/g' $(ICONS_DIR)/breeze-dark-adwaita/index.theme
	sudo sed -i 's/Comment=.*/Comment=Breeze Dark Adwaita by Juha/g' $(ICONS_DIR)/breeze-dark-adwaita/index.theme

setup-nerd-font:
	@echo "Setup nerd font, change the font with parameter: font=... e.g. font=$(font)"
	curl -o ~/Downloads/$(font-name).zip -sSL $(font)
	unzip -d ~/Downloads/$(font-name) ~/Downloads/$(font-name).zip
	sudo cp -r ~/Downloads/$(font-name) /usr/share/fonts
	sudo fc-cache -f -v
	rm -r ~/Downloads/$(font-name)*

ifeq ($(wayland),true)
configure-spotify: install-system-packages
	@echo "Configure spotify support wayland"
	sudo sed -i 's/Exec=.*/Exec=spotify --enable-features=UseOzonePlatform --ozone-platform=wayland --enable-features=WaylandWindowDecorations --uri=%U/' /usr/share/applications/spotify.desktop
else
configure-spotify:
	@echo "Wayland set to false, skipping configure spotify"
endif

install: setup-bluetooth set-time-locale $(nvidia-prerequisite) set-environment \
	create-breeze-adwaita-icons setup-terminal setup-ssh \
	setup-nerd-font configure-spotify
	@echo "Done!, Reboot recommended to take configuration changes effect"

email=

setup-git-configs:
	@echo "Setup git configs"
	mkdir -p ~/.config/git/
	cp ./config/gitconfig ~/.config/git/config
	sed -i "s/{user}/$(USER)/" ~/.config/git/config
ifdef email
	sed -i "s/{email}/$(email)/" ~/.config/git/config
else
	@echo "Enter email for git config: "; read email; sed -i "s/{email}/$$email/" ~/.config/git/config
endif

ssh=true
host=

ifeq ($(ssh),true)
copy-ssh-configs:
	@echo "Setup ssh configs"
	mkdir ~/.ssh
ifdef host
	scp $(host):~/sshconfig.zip ~/Downloads/
else
	@echo "Enter ssh host: "; read host; scp $$host:~/sshconfig.zip ~/Downloads/
endif
	cp ~/Downloads/sshconfig/* ~/.ssh/
	rm -r ~/Downloads/sshconfig*
else
copy-ssh-configs:
	@echo "Skipping ssh setup"
endif

setup-code-configs:
	@echo "Setup vscode configs"
	cp ./config/code/keybindings.json ~/.config/Code/User/keybindings.json
	cp ./config/code/settings.json ~/.config/Code/User/settings.json

setup-idea-configs:
	@echo "Setup intellij configs"
	cp ./config/.ideavimrc ~/.ideavimrc
	idea_dir=$$(ls -t ~/.config/JetBrains/ | xargs | awk '{print $$1}'); \
		mkdir -p ~/.config/JetBrains/keymaps/; \
		cp ./config/'GNOME copy.xml' ~/.config/JetBrains/$$idea_dir/keymaps/'GNOME copy.xml'

setup-alacritty:
	@echo "Setup alacritty"
	mkdir -p ~/.config/alacritty/
	cp ./config/alacritty.toml ~/.config/alacritty/alacritty.toml
	mkdir -p ~/.config/alacritty/themes && git clone https://github.com/alacritty/alacritty-theme ~/.config/alacritty/themes

setup-zshrc:
	@echo "Setup zshrc"
	chsh -s $$(which zsh)
	cp ./config/.zshrc ~/.zshrc

setup-neovim:
	@echo "Setup neovim"
	git clone git@github.com:juhaku/nvim.git ~/.config/nvim
	mkdir -p ~/.local/share/nvim/jdtls-libs
	mkdir -p ~/.local/share/nvim/jdtls
	$(shell pushd ~/.local/share/nvim/jdtls-libs && git clone https://github.com/microsoft/java-debug && cd java-debug &&\
		./mvnw clean install)
	$(shell pushd ~/.local/share/nvim/jdtls-libs && git clone https://github.com/microsoft/vscode-java-test && cd vscode-java-test &&\
		npm install && npm run build-plugin)
	$(shell curl -sSL -o ~/.local/share/nvim/jdtls-libs/lombok.jar https://projectlombok.org/downloads/lombok.jar)

dev-setup: setup-git-configs copy-ssh-configs setup-code-configs setup-idea-configs setup-alacritty setup-zshrc setup-neovim
	@echo "Done, Happy coding  !"

