.PHONY: setup setup-dev ensure-fvm get doppler-check doppler-login secrets-print update-flutter format fmt format-check analyze analytics-gen analytics-guard analytics-check firestore-guard no-dynamic-guard no-shape-parse-guard env-guard system-ui-guard secrets-guard version-sync version-guard file-gen pigeon-gen run build build-aab size-android sentry-size-upload attach ios-setup build-ios build-ipa ci test find-unused find-unused-html find-unused-ci gradle-reset
DART_FORMAT_LINE_LENGTH ?= 120
DART_FORMAT_PATHS ?= lib test
DEVICE ?=
RUN_ARGS ?=
BUILD_ARGS ?=
IOS_BUILD_ARGS ?=
APP_SIZE_TARGET_PLATFORM ?= android-arm64
RIVE_SKIP_SETUP ?= false
FIREBASE_RUN_ARG ?= $(shell [ -f android/app/google-services.json ] && echo "" || echo "--dart-define=SKIP_FIREBASE_INIT=true")
DOPPLER_PROJECT ?= prism
DOPPLER_CONFIG ?= dev
DOPPLER_REQUIRED ?= true
DOPPLER_ARGS = --project $(DOPPLER_PROJECT) --config $(DOPPLER_CONFIG)
ENV_DART_DEFINES ?= $(shell DOPPLER_PROJECT=$(DOPPLER_PROJECT) DOPPLER_CONFIG=$(DOPPLER_CONFIG) ./tool/dart_defines_from_doppler.sh)
SENTRY_SIZE_AAB ?= build/app/outputs/bundle/release/app-release.aab
SENTRY_ENV ?=
SENTRY_RELEASE ?=
SENTRY_DIST ?=
SENTRY_ENABLED ?=
SENTRY_UPLOAD ?= true
SENTRY_DOPPLER_CONFIG ?= prd
SENTRY_DART_DEFINES = $(strip \
	$(if $(SENTRY_ENV),--dart-define=SENTRY_ENV=$(SENTRY_ENV),) \
	$(if $(SENTRY_RELEASE),--dart-define=SENTRY_RELEASE=$(SENTRY_RELEASE),) \
	$(if $(SENTRY_DIST),--dart-define=SENTRY_DIST=$(SENTRY_DIST),) \
	$(if $(SENTRY_ENABLED),--dart-define=SENTRY_ENABLED=$(SENTRY_ENABLED),))
ANDROID_JAVA_HOME ?= $(shell /usr/libexec/java_home -v 17 2>/dev/null)
ifeq ($(OS),Windows_NT)
  GRADLE_USER_HOME_DIR ?= $(HOME)/.gradle-prism
else
  GRADLE_USER_HOME_DIR ?= $(CURDIR)/.gradle-local
endif
GRADLE_USER_HOME_DIR_POSIX := $(subst \,/,$(GRADLE_USER_HOME_DIR))
GRADLE_COMMON_OPTS ?= -Dorg.gradle.vfs.watch=false
RIVE_SETUP_ENV := $(if $(filter true,$(RIVE_SKIP_SETUP)),env "ORG_GRADLE_PROJECT_rive.native.skipSetup=true",)

# Ensure POSIX shell recipes work when running make from PowerShell/cmd on Windows.
ifeq ($(OS),Windows_NT)
  ifneq ($(wildcard C:/Progra~1/Git/bin/bash.exe),)
    SHELL := C:/Progra~1/Git/bin/bash.exe
  else ifneq ($(wildcard C:/Program Files/Git/bin/bash.exe),)
    SHELL := C:/Program Files/Git/bin/bash.exe
  else ifneq ($(wildcard C:/msys64/usr/bin/bash.exe),)
    SHELL := C:/msys64/usr/bin/bash.exe
  else
    SHELL := bash
  endif
  MAKESHELL := $(SHELL)
  .SHELLFLAGS := -lc
  GRADLE_COMMON_OPTS += -Dorg.gradle.daemon=false
endif

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
	@echo "Setup complete. For full local setup with secrets, run: make setup-dev"

setup-dev: ensure-fvm doppler-check
	@$(MAKE) get
	@if [ "$$(uname -s)" = "Darwin" ]; then $(MAKE) ios-setup; fi
	@echo "Developer setup complete. Next step: make run"

get: ensure-fvm
	@$(FLUTTER) pub get

doppler-check:
	@DOPPLER_PROJECT=$(DOPPLER_PROJECT) DOPPLER_CONFIG=$(DOPPLER_CONFIG) DOPPLER_REQUIRED=$(DOPPLER_REQUIRED) ./tool/doppler_check.sh

doppler-login:
	@DOPPLER_PROJECT=$(DOPPLER_PROJECT) DOPPLER_CONFIG=$(DOPPLER_CONFIG) ./tool/doppler_setup_local.sh

secrets-print: doppler-check
	@doppler secrets download --no-file --format env $(DOPPLER_ARGS) | sed -E 's/=.*/=***MASKED***/'

format: ensure-fvm
	@$(DART) format --line-length $(DART_FORMAT_LINE_LENGTH) $(DART_FORMAT_PATHS)

fmt: format

format-check: ensure-fvm
	@$(DART) format --line-length $(DART_FORMAT_LINE_LENGTH) --set-exit-if-changed -o none $(DART_FORMAT_PATHS)

analyze: ensure-fvm env-guard
	@$(FLUTTER) analyze --no-pub $(ANALYZE_FLAGS)

analytics-gen: ensure-fvm
	@$(DART) run tool/generate_analytics_schema.dart
	@$(DART) format --line-length $(DART_FORMAT_LINE_LENGTH) lib/core/analytics/events/generated/analytics_events.g.dart

analytics-guard:
	@./tool/analytics_raw_usage_guard.sh

analytics-check: ensure-fvm analytics-guard
	@$(DART) run tool/generate_analytics_schema.dart
	@$(DART) format --line-length $(DART_FORMAT_LINE_LENGTH) lib/core/analytics/events/generated/analytics_events.g.dart
	@git diff --exit-code -- lib/core/analytics/events/generated/analytics_events.g.dart

firestore-guard:
	@./tool/firestore_guard.sh

no-dynamic-guard:
	@./tool/no_dynamic_guard.sh

no-shape-parse-guard:
	@./tool/no_shape_parse_guard.sh

env-guard:
	@./tool/env_define_guard.sh
	@bash ./tool/system_ui_guard.sh

system-ui-guard:
	@bash ./tool/system_ui_guard.sh

secrets-guard:
	@./tool/doppler_guard.sh

version-sync:
	@python3 tool/sync_app_version.py

version-guard:
	@python3 tool/verify_version_sync.py

file-gen: ensure-fvm
	@$(DART) run build_runner build --delete-conflicting-outputs
	make format

pigeon-gen: ensure-fvm
	@./tool/generate_pigeon.sh

run: ensure-fvm doppler-check
	@if [ -n "$(ANDROID_JAVA_HOME)" ]; then \
		export JAVA_HOME="$(ANDROID_JAVA_HOME)"; \
		export PATH="$$JAVA_HOME/bin:$$PATH"; \
		$(FLUTTER) config --jdk-dir "$$JAVA_HOME" >/dev/null; \
	fi; \
	export GRADLE_OPTS="$$GRADLE_OPTS $(GRADLE_COMMON_OPTS)"; \
	export GRADLE_USER_HOME="$(GRADLE_USER_HOME_DIR_POSIX)"; \
	mkdir -p "$(GRADLE_USER_HOME_DIR_POSIX)"; \
	if [ -n "$(DEVICE)" ]; then \
		$(RIVE_SETUP_ENV) $(FLUTTER) run -d "$(DEVICE)" $(FIREBASE_RUN_ARG) $(ENV_DART_DEFINES) $(SENTRY_DART_DEFINES) $(RUN_ARGS); \
	else \
		$(RIVE_SETUP_ENV) $(FLUTTER) run $(FIREBASE_RUN_ARG) $(ENV_DART_DEFINES) $(SENTRY_DART_DEFINES) $(RUN_ARGS); \
	fi

build: ensure-fvm doppler-check
	@if [ -n "$(ANDROID_JAVA_HOME)" ]; then \
		export JAVA_HOME="$(ANDROID_JAVA_HOME)"; \
		export PATH="$$JAVA_HOME/bin:$$PATH"; \
		$(FLUTTER) config --jdk-dir "$$JAVA_HOME" >/dev/null; \
	fi; \
	export GRADLE_OPTS="$$GRADLE_OPTS $(GRADLE_COMMON_OPTS)"; \
	export GRADLE_USER_HOME="$(GRADLE_USER_HOME_DIR_POSIX)"; \
	mkdir -p "$(GRADLE_USER_HOME_DIR_POSIX)"; \
	$(RIVE_SETUP_ENV) build apk --obfuscate --split-debug-info=build/app/outputs/symbols $(FIREBASE_RUN_ARG) $(ENV_DART_DEFINES) $(SENTRY_DART_DEFINES) $(BUILD_ARGS)

build-aab: ensure-fvm doppler-check
	@if [ -n "$(ANDROID_JAVA_HOME)" ]; then \
		export JAVA_HOME="$(ANDROID_JAVA_HOME)"; \
		export PATH="$$JAVA_HOME/bin:$$PATH"; \
		$(FLUTTER) config --jdk-dir "$$JAVA_HOME" >/dev/null; \
	fi; \
	export GRADLE_OPTS="$$GRADLE_OPTS $(GRADLE_COMMON_OPTS)"; \
	export GRADLE_USER_HOME="$(GRADLE_USER_HOME_DIR_POSIX)"; \
	mkdir -p "$(GRADLE_USER_HOME_DIR_POSIX)"; \
	$(RIVE_SETUP_ENV) $(FLUTTER) build appbundle --release --obfuscate --split-debug-info=build/app/outputs/symbols $(FIREBASE_RUN_ARG) $(ENV_DART_DEFINES) $(SENTRY_DART_DEFINES) $(BUILD_ARGS)
	@if [ "$(SENTRY_UPLOAD)" = "true" ]; then \
		DOPPLER_PROJECT=$(DOPPLER_PROJECT) SENTRY_DOPPLER_CONFIG=$(SENTRY_DOPPLER_CONFIG) DART_CMD="$(DART)" ./tool/sentry_upload.sh; \
	fi

gradle-reset:
	@echo "Stopping Gradle daemons and clearing transform cache..."
	@./android/gradlew --stop >/dev/null 2>&1 || true
	@rm -rf "$(GRADLE_USER_HOME_DIR_POSIX)/caches/8.14/transforms" "$(GRADLE_USER_HOME_DIR_POSIX)/daemon" "$(GRADLE_USER_HOME_DIR_POSIX)/workers" || true
	@echo "Gradle cache reset complete."

size-android: ensure-fvm
	@mkdir -p build/size/local
	@printf "import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;\n\nclass DefaultFirebaseOptions {\n  static FirebaseOptions get currentPlatform => throw UnsupportedError('Size analysis stub');\n}\n" > lib/firebase_options.dart
	@$(FLUTTER) build apk --release --target-platform=$(APP_SIZE_TARGET_PLATFORM) --obfuscate --split-debug-info=build/size/local/symbols --dart-define=SKIP_FIREBASE_INIT=true --analyze-size > build/size/local/build.log 2>&1
	@cp build/app/outputs/flutter-apk/app-release.apk build/size/local/app-release.apk
	@echo "APK + size analysis log written to build/size/local"

sentry-size-upload:
	@DOPPLER_PROJECT=$(DOPPLER_PROJECT) SENTRY_DOPPLER_CONFIG=$(SENTRY_DOPPLER_CONFIG) AAB_PATH=$(SENTRY_SIZE_AAB) ./tool/sentry_size_upload.sh

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

build-ios: ensure-fvm doppler-check
	@$(FLUTTER) build ios $(ENV_DART_DEFINES) $(IOS_BUILD_ARGS)

build-ipa: ensure-fvm doppler-check
	@if [ -z "$(BUILD_NUMBER)" ]; then \
		echo "Usage: make build-ipa BUILD_NUMBER=303"; \
		exit 1; \
	fi
	@$(FLUTTER) build ipa --release --build-number=$(BUILD_NUMBER) $(ENV_DART_DEFINES) $(IOS_BUILD_ARGS)

ifeq ($(CI),true)
ensure-fvm:
	@true
else
ensure-fvm:
	@fvm --version >NUL 2>&1 || fvm --version >/dev/null 2>&1 || ( \
		echo fvm is not installed. && \
		echo Install it first example: dart pub global activate fvm && \
		exit 1 \
	)
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

ci: get format-check env-guard secrets-guard version-guard analytics-check analyze no-dynamic-guard find-unused-ci

test: ensure-fvm
	@if ls test/*_test.dart >/dev/null 2>&1 || find test -name '*_test.dart' -print -quit | grep -q .; then \
		$(FLUTTER) test $$(find test -name '*_test.dart' -not -path 'test/core/arsenal/*' | tr '\n' ' '); \
	else \
		echo "No test files found, skipping."; \
	fi

find-unused: ensure-fvm ## Find unreachable files and unused public symbols
	@$(DART) run tool/find_unused_code.dart

find-unused-html: ensure-fvm ## Find unused code + open HTML visual report
	@$(DART) run tool/find_unused_code.dart --html

find-unused-ci: ensure-fvm ## Fail if find-unused diverges from allowlist
	@$(DART) run tool/find_unused_code.dart --json > /tmp/prism_find_unused_ci.json
	@$(DART) run tool/validate_find_unused_allowlist.dart /tmp/prism_find_unused_ci.json tool/find_unused_allowlist.json
