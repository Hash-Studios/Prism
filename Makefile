.PHONY: setup ensure-fvm update-flutter

setup: ensure-fvm
	@echo "Installing Flutter SDK from .fvmrc..."
	@fvm install
	@echo "Linking project SDK..."
	@fvm use --force
	@fvm flutter --version
	@fvm flutter pub get
	@echo "Setup complete. Use 'fvm flutter <command>' for project commands."

ensure-fvm:
	@command -v fvm >/dev/null 2>&1 || { \
		echo "fvm is not installed."; \
		echo "Install it first (example): dart pub global activate fvm"; \
		exit 1; \
	}

update-flutter: ensure-fvm
	@if [ -z "$(VERSION)" ]; then \
		echo "Usage: make update-flutter VERSION=3.42.0"; \
		exit 1; \
	fi
	@fvm use "$(VERSION)" --force
	@fvm install "$(VERSION)"
	@fvm flutter --version
	@fvm flutter pub get
	@echo "Pinned Flutter version updated to $(VERSION). Commit .fvmrc."
