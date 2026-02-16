.PHONY: setup ensure-fvm get update-flutter format fmt format-check analyze

DART_FORMAT_LINE_LENGTH ?= 120
DART_FORMAT_PATHS ?= lib test

setup: ensure-fvm
	@echo "Installing Flutter SDK from .fvmrc..."
	@fvm install
	@echo "Linking project SDK..."
	@fvm use --force
	@fvm flutter --version
	@fvm flutter pub get
	@echo "Setup complete. Use 'fvm flutter <command>' for project commands."

get: ensure-fvm
	@fvm flutter pub get

format: ensure-fvm
	@fvm dart format --line-length $(DART_FORMAT_LINE_LENGTH) $(DART_FORMAT_PATHS)

fmt: format

format-check: ensure-fvm
	@fvm dart format --line-length $(DART_FORMAT_LINE_LENGTH) --set-exit-if-changed -o none $(DART_FORMAT_PATHS)

analyze: ensure-fvm
	@fvm flutter analyze

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
