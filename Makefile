.PHONY: setup ensure-fvm get update-flutter format fmt format-check analyze firestore-guard env-guard file-gen pigeon-gen run build attach ios-setup build-ios ci test update-goldens verify-goldens install-hooks

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

# CI support: when CI=true, use plain flutter/dart instead of fvm-prefixed
ifeq ($(CI),true)
  FLUTTER := flutter
  DART := dart
  ANALYZE_FLAGS := --no-fatal-infos
else
  FLUTTER := fvm flutter
  DART := fvm dart
  ANALYZE_FLAGS :=
endif

setup: ensure-fvm
	@echo "Installing Flutter SDK from .fvmrc..."
	@fvm install
	@echo "Linking project SDK..."
	@fvm use --force
	@$(FLUTTER) --version
	@$(FLUTTER) pub get
	@if [ "$$(uname -s)" = "Darwin" ]; then $(MAKE) ios-setup; fi
	@$(MAKE) install-hooks
	@echo "Setup complete. Use 'fvm flutter <command>' for project commands."

get: ensure-fvm
	@$(FLUTTER) pub get

format: ensure-fvm
	@$(DART) format --line-length $(DART_FORMAT_LINE_LENGTH) $(DART_FORMAT_PATHS)

fmt: format

format-check: ensure-fvm
	@$(DART) format --line-length $(DART_FORMAT_LINE_LENGTH) --set-exit-if-changed -o none $(DART_FORMAT_PATHS)

analyze: ensure-fvm env-guard
	@$(FLUTTER) analyze --no-pub $(ANALYZE_FLAGS)

firestore-guard:
	@./tool/firestore_guard.sh

env-guard:
	@./tool/env_define_guard.sh

file-gen: ensure-fvm
	@$(DART) run build_runner build --delete-conflicting-outputs
	make format

pigeon-gen: ensure-fvm
	@./tool/generate_pigeon.sh

run: ensure-fvm
	@if [ -n "$(ANDROID_JAVA_HOME)" ]; then \
		export JAVA_HOME="$(ANDROID_JAVA_HOME)"; \
		export PATH="$$JAVA_HOME/bin:$$PATH"; \
		$(FLUTTER) config --jdk-dir "$$JAVA_HOME" >/dev/null; \
	fi; \
	export GRADLE_USER_HOME="$(GRADLE_USER_HOME_DIR)"; \
	mkdir -p "$(GRADLE_USER_HOME_DIR)"; \
	if [ -n "$(DEVICE)" ]; then \
		$(FLUTTER) run -d "$(DEVICE)" $(FIREBASE_RUN_ARG) $(ENV_DART_DEFINES) $(SENTRY_DART_DEFINES) $(RUN_ARGS); \
	else \
		$(FLUTTER) run $(FIREBASE_RUN_ARG) $(ENV_DART_DEFINES) $(SENTRY_DART_DEFINES) $(RUN_ARGS); \
	fi

build: ensure-fvm
	@if [ -n "$(ANDROID_JAVA_HOME)" ]; then \
		export JAVA_HOME="$(ANDROID_JAVA_HOME)"; \
		export PATH="$$JAVA_HOME/bin:$$PATH"; \
		$(FLUTTER) config --jdk-dir "$$JAVA_HOME" >/dev/null; \
	fi; \
	export GRADLE_USER_HOME="$(GRADLE_USER_HOME_DIR)"; \
	mkdir -p "$(GRADLE_USER_HOME_DIR)"; \
	$(FLUTTER) build apk $(FIREBASE_RUN_ARG) $(ENV_DART_DEFINES) $(SENTRY_DART_DEFINES) $(BUILD_ARGS)

attach: ensure-fvm
	@if [ -n "$(DEVICE)" ]; then \
		$(FLUTTER) attach -d "$(DEVICE)"; \
	else \
		$(FLUTTER) attach; \
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
	@$(FLUTTER) precache --ios
	@cd ios && export LANG=en_US.UTF-8 && export LC_ALL=en_US.UTF-8 && pod deintegrate && pod install --repo-update
	@echo "iOS pods setup complete."

build-ios: ensure-fvm
	@$(FLUTTER) build ios $(ENV_DART_DEFINES) $(IOS_BUILD_ARGS)

ifeq ($(CI),true)
ensure-fvm:
	@true
else
ensure-fvm:
	@command -v fvm >/dev/null 2>&1 || { \
		echo "fvm is not installed."; \
		echo "Install it first (example): dart pub global activate fvm"; \
		exit 1; \
	}
endif

update-flutter: ensure-fvm
	@if [ -z "$(VERSION)" ]; then \
		echo "Usage: make update-flutter VERSION=3.42.0"; \
		exit 1; \
	fi
	@fvm use "$(VERSION)" --force
	@fvm install "$(VERSION)"
	@$(FLUTTER) --version
	@$(FLUTTER) pub get
	@echo "Pinned Flutter version updated to $(VERSION). Commit .fvmrc."

ci: get format-check env-guard analyze

test: ensure-fvm
	@if ls test/*_test.dart >/dev/null 2>&1 || find test -name '*_test.dart' -print -quit | grep -q .; then \
		$(FLUTTER) test $$(find test -name '*_test.dart' -not -path 'test/core/arsenal/*' | tr '\n' ' '); \
	else \
		echo "No test files found, skipping."; \
	fi

update-goldens: ensure-fvm  ## Regenerate goldens only for changed Arsenal components
	@./tool/update_goldens.sh

verify-goldens: ensure-fvm  ## Fail if goldens don't match current renders
	@$(FLUTTER) test test/core/arsenal/

install-hooks:  ## Install git hooks (run once after cloning)
	@cp tool/pre_commit_goldens.sh .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
	@echo "Git pre-commit hook installed."
