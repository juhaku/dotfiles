include Makefile

# setup ssh agent
setup-ssh:
	@echo -e "$(LIGHT_GREEN)Setup ssh agent$(NOCOLOR)"
	systemctl enable --user gcr-ssh-agent.socket
	systemctl start --user gcr-ssh-agent.socket
	echo 'export SSH_AUTH_SOCK=$$XDG_RUNTIME_DIR/gcr/ssh' | tee ~/.zprofile

# set global environment variables
set-environment: install-system-packages
	@echo -e "$(LIGHT_GREEN)Set qt environment$(NOCOLOR)"
	#echo "QT_QPA_PLATFORMTHEME=qt6ct" | sudo tee -a /etc/environment
	#echo "QT_WAYLAND_DECORATION=adwaita" | sudo tee -a /etc/environment
	@echo -e "$(LIGHT_GREEN)Set ibus environment$(NOCOLOR)"
	sudo echo -e "GTK_IM_MODULE=ibus\nQT_IM_MODULE=ibus\nXMODIFIERS=@im=ibus" | sudo tee -a /etc/environment
	@echo -e "$(LIGHT_GREEN)Change editor to neovim$(NOCOLOR)"
	sudo sed -i 's/EDITOR=.*/EDITOR=nvim/' /etc/environment

# create breeze-dark-adwaita flavor icon theme
create-breeze-adwaita-icons: install-system-packages
	@echo -e "$(LIGHT_GREEN)Create breeze-dark-adwaita flavor icon theme$(NOCOLOR)"
	sudo cp -r $(ICONS_DIR)/breeze-dark $(ICONS_DIR)/breeze-dark-adwaita
	$(foreach icon, $(ICONS), find $(ICONS_DIR)/breeze-dark-adwaita/ -name "*$(icon)*" -exec sudo rm {} \;; ) 
	sudo mkdir -p $(ICONS_DIR)/breeze-dark-adwaita/symbolic/ui/
	$(foreach icon, $(ICONS), find $(ICONS_DIR)/Adwaita/ -name "*$(icon)-symbolic.svg" -exec sudo cp {} $(ICONS_DIR)/breeze-dark-adwaita/symbolic/ui/$(icon)-symbolic.svg \;; )
	sudo sed -i 's/Name=.*/Name=Breeze Dark Adwaita/g' $(ICONS_DIR)/breeze-dark-adwaita/index.theme
	sudo sed -i 's/Comment=.*/Comment=Breeze Dark Adwaita by Juha/g' $(ICONS_DIR)/breeze-dark-adwaita/index.theme

setup-kvantum:
	@echo -e "$(LIGHT_GREEN)Setup kvantum configs$(NOCOLOR)"
	mkdir -p ~/.config/qt6ct/
	mkdir -p ~/.config/Kvantum/
	cp ./config/qt6ct.conf ~/.config/qt6ct/qt6ct.conf
	cp ./config/kvantum.kvconfig ~/.config/Kvantum/kvantum.kvconfig

# Gnome specific configuration
configure: set-environment setup-ssh
	xdg-mime default org.gnome.Nautilus.desktop inode/directory
	@echo -e "$(LIGHT_GREEN)Done configuring $(FLAVOR)$(NOCOLOR)"

