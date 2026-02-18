.PHONY: setup ensure-fvm get update-flutter format fmt format-check analyze firestore-guard file-gen pigeon-gen run build attach ios-setup build-ios

DART_FORMAT_LINE_LENGTH ?= 120
DART_FORMAT_PATHS ?= lib test
DEVICE ?=
RUN_ARGS ?=
BUILD_ARGS ?=
IOS_BUILD_ARGS ?=
FIREBASE_RUN_ARG ?= $(shell [ -f android/app/google-services.json ] && echo "" || echo "--dart-define=SKIP_FIREBASE_INIT=true")
ENV_DART_DEFINES ?= $(shell ./tool/dart_defines_from_env.sh)
SENTRY_ENV ?=
SENTRY_RELEASE ?=
SENTRY_DIST ?=
SENTRY_ENABLED ?=
SENTRY_DART_DEFINES = $(strip \
	$(if $(SENTRY_ENV),--dart-define=SENTRY_ENV=$(SENTRY_ENV),) \
	$(if $(SENTRY_RELEASE),--dart-define=SENTRY_RELEASE=$(SENTRY_RELEASE),) \
	$(if $(SENTRY_DIST),--dart-define=SENTRY_DIST=$(SENTRY_DIST),) \
	$(if $(SENTRY_ENABLED),--dart-define=SENTRY_ENABLED=$(SENTRY_ENABLED),))
ANDROID_JAVA_HOME ?= $(shell /usr/libexec/java_home -v 17 2>/dev/null)
GRADLE_USER_HOME_DIR ?= $(CURDIR)/.gradle-local

setup: ensure-fvm
	@echo "Installing Flutter SDK from .fvmrc..."
	@fvm install
	@echo "Linking project SDK..."
	@fvm use --force
	@fvm flutter --version
	@fvm flutter pub get
	@if [ "$$(uname -s)" = "Darwin" ]; then $(MAKE) ios-setup; fi
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

firestore-guard:
	@./tool/firestore_guard.sh

file-gen: ensure-fvm
	@fvm dart run build_runner build --delete-conflicting-outputs

pigeon-gen: ensure-fvm
	@./tool/generate_pigeon.sh

run: ensure-fvm
	@if [ -n "$(ANDROID_JAVA_HOME)" ]; then \
		export JAVA_HOME="$(ANDROID_JAVA_HOME)"; \
		export PATH="$$JAVA_HOME/bin:$$PATH"; \
		fvm flutter config --jdk-dir "$$JAVA_HOME" >/dev/null; \
	fi; \
	export GRADLE_USER_HOME="$(GRADLE_USER_HOME_DIR)"; \
	mkdir -p "$(GRADLE_USER_HOME_DIR)"; \
	if [ -n "$(DEVICE)" ]; then \
		fvm flutter run -d "$(DEVICE)" $(FIREBASE_RUN_ARG) $(ENV_DART_DEFINES) $(SENTRY_DART_DEFINES) $(RUN_ARGS); \
	else \
		fvm flutter run $(FIREBASE_RUN_ARG) $(ENV_DART_DEFINES) $(SENTRY_DART_DEFINES) $(RUN_ARGS); \
	fi

build: ensure-fvm
	@if [ -n "$(ANDROID_JAVA_HOME)" ]; then \
		export JAVA_HOME="$(ANDROID_JAVA_HOME)"; \
		export PATH="$$JAVA_HOME/bin:$$PATH"; \
		fvm flutter config --jdk-dir "$$JAVA_HOME" >/dev/null; \
	fi; \
	export GRADLE_USER_HOME="$(GRADLE_USER_HOME_DIR)"; \
	mkdir -p "$(GRADLE_USER_HOME_DIR)"; \
	fvm flutter build apk $(FIREBASE_RUN_ARG) $(ENV_DART_DEFINES) $(SENTRY_DART_DEFINES) $(BUILD_ARGS)

attach: ensure-fvm
	@if [ -n "$(DEVICE)" ]; then \
		fvm flutter attach -d "$(DEVICE)"; \
	else \
		fvm flutter attach; \
	fi

ios-setup: ensure-fvm
	@if [ "$$(uname -s)" != "Darwin" ]; then \
		echo "Skipping iOS setup (requires macOS)."; \
		exit 0; \
	fi
	@command -v pod >/dev/null 2>&1 || { \
		echo "CocoaPods is not installed. Install it first (example): sudo gem install cocoapods"; \
		exit 1; \
	}
	@fvm flutter precache --ios
	@cd ios && export LANG=en_US.UTF-8 && export LC_ALL=en_US.UTF-8 && pod deintegrate && pod install --repo-update
	@echo "iOS pods setup complete."

build-ios: ensure-fvm
	@fvm flutter build ios $(ENV_DART_DEFINES) $(IOS_BUILD_ARGS)

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
