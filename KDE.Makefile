include Makefile

# setup ssh agent
setup-ssh:
	@echo -e "$(LIGHT_GREEN)Setup ssh agent$(NOCOLOR)"
	echo 'export SSH_AUTH_SOCK=$$XDG_RUNTIME_DIR/ssh-agent.socket' | tee ~/.zprofile
	mkdir -p ~/.config/environment.d/
	cp ./config/ssh_askpass.conf ~/.config/environment.d/ssh_askpass.conf

# set global environment variables
set-environment: install-system-packages
	@echo -e "$(LIGHT_GREEN)Set qt environment$(NOCOLOR)"
	echo "QT_QPA_PLATFORMTHEME=qt6ct" | sudo tee -a /etc/environment
	echo "QT_WAYLAND_DECORATION=adwaita" | sudo tee -a /etc/environment
	@echo -e "$(LIGHT_GREEN)Set fcitx5 environment$(NOCOLOR)"
ifeq ($(wayland),true)
	sudo echo -e "XMODIFIERS=@im=fcitx" | sudo tee -a /etc/environment
else
	sudo echo -e "GTK_IM_MODULE=fcitx\nQT_IM_MODULE=fcitx\nXMODIFIERS=@im=fcitx" | sudo tee -a /etc/environment
endif
	@echo -e "$(LIGHT_GREEN)Change editor to neovim$(NOCOLOR)"
	sudo sed -i 's/EDITOR=.*/EDITOR=nvim/' /etc/environment

# KDE specific configuration
configure: set-environment setup-ssh
	@echo -e "$(LIGHT_GREEN)Done configuring $(FLAVOR)$(NOCOLOR)"
