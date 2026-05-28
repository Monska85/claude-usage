BINARY_NAME   := claude-usage
EXT_UUID      := claude-usage@claude-code-usage
EXT_DIR       := $(HOME)/.local/share/gnome-shell/extensions/$(EXT_UUID)
INSTALL_DIR   := $(HOME)/.local/bin

.PHONY: build install install-binary install-extension uninstall uninstall-binary uninstall-extension reload-extension test-extension clean

## Build the Go binary
build:
	go build -o $(BINARY_NAME) ./cmd/claude-usage/

## Install everything
install: build install-binary install-extension

## Install the Go binary to ~/.local/bin
install-binary: build
	mkdir -p $(INSTALL_DIR)
	cp $(BINARY_NAME) $(INSTALL_DIR)/$(BINARY_NAME)
	@echo "Installed $(BINARY_NAME) to $(INSTALL_DIR)"
	@echo "Make sure $(INSTALL_DIR) is in your PATH"

## Install the GNOME Shell extension
install-extension:
	mkdir -p $(EXT_DIR)
	cp gnome-shell-extension/extension.js $(EXT_DIR)/
	cp gnome-shell-extension/metadata.json $(EXT_DIR)/
	cp gnome-shell-extension/sparkle.svg $(EXT_DIR)/
	@echo "Extension installed to $(EXT_DIR)"
	@echo "Enable with: gnome-extensions enable $(EXT_UUID)"

## Reload extension (disable + enable)
reload-extension:
	gnome-extensions disable $(EXT_UUID) 2>/dev/null || true
	sleep 1
	gnome-extensions enable $(EXT_UUID)

## Run a nested GNOME Shell on Wayland for testing (requires mutter-devkit)
test-extension: install-extension
	dbus-run-session gnome-shell --devkit --wayland

## Uninstall everything
uninstall: uninstall-binary uninstall-extension

## Remove the binary
uninstall-binary:
	rm -f $(INSTALL_DIR)/$(BINARY_NAME)
	@echo "Removed $(BINARY_NAME) from $(INSTALL_DIR)"

## Remove the GNOME Shell extension
uninstall-extension:
	gnome-extensions disable $(EXT_UUID) 2>/dev/null || true
	rm -rf $(EXT_DIR)
	@echo "Removed extension $(EXT_UUID)"

## Remove build artifacts
clean:
	rm -f $(BINARY_NAME)
