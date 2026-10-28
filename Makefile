.PHONY: setup setup-dev ensure-fvm get doppler-check doppler-login secrets-print update-flutter format fmt format-check analyze analytics-gen analytics-guard analytics-check firestore-guard rules-test no-dynamic-guard no-shape-parse-guard guard-test env-guard system-ui-guard secrets-guard version-sync version-guard file-gen pigeon-gen run build build-aab release-android release-ios patch patch-list patch-promote patch-rollback ensure-shorebird size-android sentry-size-upload attach ios-setup build-ios build-ipa ci test cloudflare-worker-check find-unused find-unused-html find-unused-ci gradle-reset functions-env functions-secrets-sync functions-deploy hooks repo-assets-check

DART_FORMAT_LINE_LENGTH ?= 120
DART_FORMAT_PATHS ?= lib test
QA_RENDER_TARGET ?= $(wildcard test/qa_render/*_render.dart)
QA_RENDER_FLAGS ?=
DEVICE ?=
RUN_ARGS ?=
BUILD_ARGS ?=
IOS_BUILD_ARGS ?=
APP_SIZE_TARGET_PLATFORM ?= android-arm64
FIREBASE_RUN_ARG ?= $(shell [ -f android/app/google-services.json ] && echo "" || echo "--dart-define=SKIP_FIREBASE_INIT=true")
DOPPLER_PROJECT ?= prism
DOPPLER_CONFIG ?= dev
DOPPLER_REQUIRED ?= true
DOPPLER_ARGS = --project $(DOPPLER_PROJECT) --config $(DOPPLER_CONFIG)
DOPPLER_FLUTTER = python3 tool/flutter_with_doppler.py
export DOPPLER_PROJECT DOPPLER_CONFIG
SENTRY_SIZE_AAB ?= build/app/outputs/bundle/release/app-release.aab
SENTRY_ENV ?=
SENTRY_RELEASE ?=
SENTRY_DIST ?=
SENTRY_ENABLED ?=
SENTRY_UPLOAD ?= true
SENTRY_DOPPLER_CONFIG ?= prd
export SENTRY_DSN SENTRY_ENV SENTRY_RELEASE SENTRY_DIST SENTRY_ENABLED
SHOREBIRD ?= shorebird
FLUTTER_PIN = $(shell python3 -c 'import json; print(json.load(open(".fvmrc"))["flutter"])')
PLATFORM ?=
RELEASE_VERSION ?=
PATCH_NUMBER ?=
TRACK ?= staging
PATCH_ARGS ?=
ALLOW_STORAGE_CHANGES ?=
ANDROID_JAVA_HOME ?= $(or $(JAVA_HOME),$(shell /usr/libexec/java_home -v 21 2>/dev/null),$(shell [ ! -d '/Applications/Android Studio.app/Contents/jbr/Contents/Home' ] || printf '%s' '/Applications/Android Studio.app/Contents/jbr/Contents/Home'))
ifeq ($(OS),Windows_NT)
  GRADLE_USER_HOME_DIR ?= $(HOME)/.gradle-prism
else
  GRADLE_USER_HOME_DIR ?= $(CURDIR)/.gradle-local
endif
GRADLE_USER_HOME_DIR_POSIX := $(subst \,/,$(GRADLE_USER_HOME_DIR))
GRADLE_COMMON_OPTS ?= -Dorg.gradle.vfs.watch=false
FIREBASE_PROJECT ?= prism-wallpapers
FIREBASE_ACCOUNT ?=
FIREBASE_ARGS = --project $(FIREBASE_PROJECT) $(if $(FIREBASE_ACCOUNT),--account $(FIREBASE_ACCOUNT),)
FUNCTIONS_DOPPLER_CONFIG ?= prd
FUNCTIONS_SECRETS ?= GH_TOKEN REVENUECAT_SECRET_KEY STUDIO_SECRET TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID FAL_API_KEY R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY
FUNCTIONS_ENV_KEYS ?= GH_USERNAME GH_REPO_WALLS GH_REPO_SETUPS R2_ACCOUNT_ID R2_PRIVATE_BUCKET R2_PREVIEW_BUCKET R2_PREVIEW_BASE_URL

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
  # flutter test defaults to half the cores; the CI runner is otherwise idle.
  TEST_FLAGS := --concurrency=$(shell getconf _NPROCESSORS_ONLN)
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
	@echo "Setup complete. For full local setup with secrets, run: make setup-dev"

hooks:
	@git config core.hooksPath .githooks
	@echo "Git hooks enabled (.githooks)."

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

.PHONY: l10n-gen l10n-check
l10n-gen: ensure-fvm
	@$(FLUTTER) gen-l10n

l10n-check: ensure-fvm
	@python3 tool/check_l10n.py
	@$(FLUTTER) gen-l10n
	@git diff --exit-code -- lib/l10n/generated
	@$(DART) run tool/l10n_audit.dart --check --summary
	@$(FLUTTER) test tool/l10n_audit_test.dart

analytics-gen: ensure-fvm
	@$(DART) run tool/generate_analytics_schema.dart
	@$(DART) format --line-length $(DART_FORMAT_LINE_LENGTH) lib/core/analytics/events/generated/analytics_events.g.dart

analytics-guard:
	@./tool/analytics_raw_usage_guard.sh

analytics-check: ensure-fvm analytics-guard
	@$(FLUTTER) test test/core/analytics/analytics_schema_contract_test.dart
	@$(DART) run tool/generate_analytics_schema.dart
	@$(DART) format --line-length $(DART_FORMAT_LINE_LENGTH) lib/core/analytics/events/generated/analytics_events.g.dart
	@git diff --exit-code -- lib/core/analytics/events/generated/analytics_events.g.dart

firestore-guard:
	@./tool/firestore_guard.sh

no-dynamic-guard:
	@./tool/no_dynamic_guard.sh

rules-test: ## Run the Firestore rules smoke test on the emulator (needs Java)
	@firebase emulators:exec --only firestore --project demo-prism "node tool/firestore_rules_smoke.mjs"

no-shape-parse-guard:
	@./tool/no_shape_parse_guard.sh

guard-test:
	@bash tool/search_guard_test.sh
	@python3 -m unittest tool.release_tools_test tool.release_workflows_test tool.ios_ci_signing_test tool.shorebird_ota_test

.PHONY: notification-contract-fixture-test
notification-contract-fixture-test: ensure-fvm
	@FLUTTER="$(FLUTTER)" python3 tool/notification_contract_fixture_test.py

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
	@python3 tool/sync_app_version.py --check

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
		$(DOPPLER_FLUTTER) -- $(FLUTTER) run -d "$(DEVICE)" $(FIREBASE_RUN_ARG) $(RUN_ARGS); \
	else \
		$(DOPPLER_FLUTTER) -- $(FLUTTER) run $(FIREBASE_RUN_ARG) $(RUN_ARGS); \
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
	$(DOPPLER_FLUTTER) --release-platform android -- $(FLUTTER) build apk --obfuscate --split-debug-info=build/app/outputs/symbols $(BUILD_ARGS)

build-aab: ensure-fvm doppler-check
	@if [ -n "$(ANDROID_JAVA_HOME)" ]; then \
		export JAVA_HOME="$(ANDROID_JAVA_HOME)"; \
		export PATH="$$JAVA_HOME/bin:$$PATH"; \
		$(FLUTTER) config --jdk-dir "$$JAVA_HOME" >/dev/null; \
	fi; \
	export GRADLE_OPTS="$$GRADLE_OPTS $(GRADLE_COMMON_OPTS)"; \
	export GRADLE_USER_HOME="$(GRADLE_USER_HOME_DIR_POSIX)"; \
	mkdir -p "$(GRADLE_USER_HOME_DIR_POSIX)"; \
	$(DOPPLER_FLUTTER) --release-platform android -- $(FLUTTER) build appbundle --release --obfuscate --split-debug-info=build/app/outputs/symbols $(BUILD_ARGS)
	@if [ "$(SENTRY_UPLOAD)" = "true" ]; then \
		DOPPLER_PROJECT=$(DOPPLER_PROJECT) SENTRY_DOPPLER_CONFIG=$(SENTRY_DOPPLER_CONFIG) DART_CMD="$(DART)" ./tool/sentry_upload.sh; \
	fi

# Shorebird store releases and over-the-air Dart patches. See docs/development/ota.md.
ensure-shorebird:
	@$(SHOREBIRD) --version >/dev/null 2>&1 || { \
		echo "Shorebird CLI $$(python3 tool/shorebird_ota.py cli-version) is not installed. See docs/development/ota.md."; \
		exit 1; \
	}

release-android: ensure-fvm ensure-shorebird doppler-check
	@if [ -n "$(ANDROID_JAVA_HOME)" ]; then \
		export JAVA_HOME="$(ANDROID_JAVA_HOME)"; \
		export PATH="$$JAVA_HOME/bin:$$PATH"; \
		$(FLUTTER) config --jdk-dir "$$JAVA_HOME" >/dev/null; \
	fi; \
	export GRADLE_OPTS="$$GRADLE_OPTS $(GRADLE_COMMON_OPTS)"; \
	export GRADLE_USER_HOME="$(GRADLE_USER_HOME_DIR_POSIX)"; \
	mkdir -p "$(GRADLE_USER_HOME_DIR_POSIX)"; \
	$(DOPPLER_FLUTTER) --release-platform android -- $(SHOREBIRD) release android --flutter-version=$(FLUTTER_PIN) --obfuscate --split-debug-info=build/app/outputs/symbols $(BUILD_ARGS)
	@if [ "$(SENTRY_UPLOAD)" = "true" ]; then \
		DOPPLER_PROJECT=$(DOPPLER_PROJECT) SENTRY_DOPPLER_CONFIG=$(SENTRY_DOPPLER_CONFIG) DART_CMD="$(DART)" ./tool/sentry_upload.sh; \
	fi
	@git push origin "refs/tags/$$(cat build/shorebird/release-tag-android)"

release-ios: ensure-fvm ensure-shorebird doppler-check
	@if [ -z "$(BUILD_NUMBER)" ]; then \
		echo "Usage: make release-ios BUILD_NUMBER=353"; \
		exit 1; \
	fi
	@$(DOPPLER_FLUTTER) --release-platform ios -- $(SHOREBIRD) release ios --flutter-version=$(FLUTTER_PIN) --build-number=$(BUILD_NUMBER) --obfuscate --split-debug-info=build/ios/outputs/symbols $(IOS_BUILD_ARGS)
	@if [ "$(SENTRY_UPLOAD)" = "true" ]; then \
		DOPPLER_PROJECT=$(DOPPLER_PROJECT) SENTRY_DOPPLER_CONFIG=$(SENTRY_DOPPLER_CONFIG) DART_CMD="$(DART)" ./tool/sentry_upload.sh; \
	fi
	@git push origin "refs/tags/$$(cat build/shorebird/release-tag-ios)"

patch: ensure-fvm ensure-shorebird doppler-check
	@if [ "$(PLATFORM)" != "android" ] && [ "$(PLATFORM)" != "ios" ] || [ -z "$(RELEASE_VERSION)" ]; then \
		echo "Usage: make patch PLATFORM=android|ios RELEASE_VERSION=3.14.0+353 [TRACK=staging]"; \
		exit 1; \
	fi
	@git fetch --quiet origin 'refs/tags/shorebird/*:refs/tags/shorebird/*'
	@if [ -n "$(ANDROID_JAVA_HOME)" ]; then \
		export JAVA_HOME="$(ANDROID_JAVA_HOME)"; \
		export PATH="$$JAVA_HOME/bin:$$PATH"; \
		$(FLUTTER) config --jdk-dir "$$JAVA_HOME" >/dev/null; \
	fi; \
	export GRADLE_OPTS="$$GRADLE_OPTS $(GRADLE_COMMON_OPTS)"; \
	export GRADLE_USER_HOME="$(GRADLE_USER_HOME_DIR_POSIX)"; \
	mkdir -p "$(GRADLE_USER_HOME_DIR_POSIX)"; \
	$(DOPPLER_FLUTTER) --release-platform $(PLATFORM) $(if $(ALLOW_STORAGE_CHANGES),--allow-storage-changes,) -- \
		$(SHOREBIRD) patch $(PLATFORM) --release-version=$(RELEASE_VERSION) --track=$(TRACK) \
		--split-debug-info=$(if $(filter ios,$(PLATFORM)),build/ios/outputs/symbols,build/app/outputs/symbols) $(PATCH_ARGS)
	@if [ "$(SENTRY_UPLOAD)" = "true" ]; then \
		DOPPLER_PROJECT=$(DOPPLER_PROJECT) SENTRY_DOPPLER_CONFIG=$(SENTRY_DOPPLER_CONFIG) DART_CMD="$(DART)" ./tool/sentry_upload.sh; \
	fi

patch-list: ensure-shorebird doppler-check
	@if [ -z "$(RELEASE_VERSION)" ]; then echo "Usage: make patch-list RELEASE_VERSION=3.14.0+353"; exit 1; fi
	@$(DOPPLER_FLUTTER) -- $(SHOREBIRD) patches list --release-version=$(RELEASE_VERSION)

patch-promote: ensure-shorebird doppler-check
	@if [ -z "$(RELEASE_VERSION)" ] || [ -z "$(PATCH_NUMBER)" ]; then \
		echo "Usage: make patch-promote RELEASE_VERSION=3.14.0+353 PATCH_NUMBER=1"; \
		exit 1; \
	fi
	@$(DOPPLER_FLUTTER) -- $(SHOREBIRD) patches promote --release-version=$(RELEASE_VERSION) --patch-number=$(PATCH_NUMBER)

patch-rollback: ensure-shorebird doppler-check
	@if [ -z "$(RELEASE_VERSION)" ] || [ -z "$(PATCH_NUMBER)" ]; then \
		echo "Usage: make patch-rollback RELEASE_VERSION=3.14.0+353 PATCH_NUMBER=1"; \
		exit 1; \
	fi
	@$(DOPPLER_FLUTTER) -- $(SHOREBIRD) patches rollback --release-version=$(RELEASE_VERSION) --patch-number=$(PATCH_NUMBER)

# Cloud Functions config comes from Doppler ($(FUNCTIONS_DOPPLER_CONFIG)). Values are piped, never printed.
functions-env:
	@set -e; out=functions/.env; : > $$out; \
	for k in $(FUNCTIONS_ENV_KEYS); do \
		v="$$(doppler secrets get $$k --plain --project $(DOPPLER_PROJECT) --config $(FUNCTIONS_DOPPLER_CONFIG))"; \
		[ -n "$$v" ] || { echo "Doppler $(FUNCTIONS_DOPPLER_CONFIG) has no value for $$k"; exit 1; }; \
		printf '%s=%s\n' "$$k" "$$v" >> $$out; \
	done; echo "Wrote $$out ($(FUNCTIONS_ENV_KEYS))"

functions-secrets-sync:
	@set -e; for k in $(FUNCTIONS_SECRETS); do \
		v="$$(doppler secrets get $$k --plain --project $(DOPPLER_PROJECT) --config $(FUNCTIONS_DOPPLER_CONFIG))"; \
		[ -n "$$v" ] || { echo "Doppler $(FUNCTIONS_DOPPLER_CONFIG) has no value for $$k"; exit 1; }; \
		out="$$(printf '%s' "$$v" | firebase functions:secrets:set $$k --data-file=- $(FIREBASE_ARGS) 2>&1)" || { echo "$$out"; exit 1; }; \
		echo "Synced $$k from Doppler $(FUNCTIONS_DOPPLER_CONFIG)"; \
	done

functions-deploy: functions-env
	@cd functions && npm run build
	@firebase deploy --only functions,firestore:indexes $(FIREBASE_ARGS)

gradle-reset:
	@echo "Stopping Gradle daemons and clearing transform cache..."
	@./android/gradlew --stop >/dev/null 2>&1 || true
	@rm -rf "$(GRADLE_USER_HOME_DIR_POSIX)/caches/8.14/transforms" "$(GRADLE_USER_HOME_DIR_POSIX)/daemon" "$(GRADLE_USER_HOME_DIR_POSIX)/workers" || true
	@echo "Gradle cache reset complete."

size-android: ensure-fvm
	@mkdir -p build/size/local
	@./tool/write_firebase_options_stub.sh
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
	@if [ ! -f ios/Runner/GoogleService-Info.plist ]; then 		cp ios/Runner/GoogleService-Info.plist.stub ios/Runner/GoogleService-Info.plist; 		echo "Installed stub ios/Runner/GoogleService-Info.plist for local builds."; 	fi
	@cd ios && export LANG=en_US.UTF-8 && export LC_ALL=en_US.UTF-8 && pod deintegrate && pod install --repo-update
	@echo "iOS pods setup complete."

build-ios: ensure-fvm doppler-check
	@$(DOPPLER_FLUTTER) --release-platform ios -- $(FLUTTER) build ios $(IOS_BUILD_ARGS)

build-ipa: ensure-fvm doppler-check
	@if [ -z "$(BUILD_NUMBER)" ]; then \
		echo "Usage: make build-ipa BUILD_NUMBER=303"; \
		exit 1; \
	fi
	@$(DOPPLER_FLUTTER) --release-platform ios -- $(FLUTTER) build ipa --release --build-number=$(BUILD_NUMBER) --obfuscate --split-debug-info=build/ios/outputs/symbols $(IOS_BUILD_ARGS)
	@if [ "$(SENTRY_UPLOAD)" = "true" ]; then \
		DOPPLER_PROJECT=$(DOPPLER_PROJECT) SENTRY_DOPPLER_CONFIG=$(SENTRY_DOPPLER_CONFIG) DART_CMD="$(DART)" ./tool/sentry_upload.sh; \
	fi

ifeq ($(CI),true)
ensure-fvm:
	@true
else
ensure-fvm:
	@fvm --version >/dev/null 2>&1 || ( \
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

repo-assets-check:
	@python3 tool/check_repo_assets.py

ci: get format-check l10n-check guard-test env-guard secrets-guard version-guard analytics-check analyze no-dynamic-guard firestore-guard no-shape-parse-guard system-ui-guard find-unused-ci cloudflare-worker-check repo-assets-check test

.PHONY: native-android-check native-ios-check ios-strip-test
native-android-check: get
	@tool/write_firebase_options_stub.sh
	@JAVA_HOME="$(ANDROID_JAVA_HOME)" $(FLUTTER) build apk --debug --dart-define=SKIP_FIREBASE_INIT=true
	@cd android && JAVA_HOME="$(ANDROID_JAVA_HOME)" ./gradlew :app:testDebugUnitTest :cloud_functions:testDebugUnitTest :app:lintDebug $(GRADLE_COMMON_OPTS)

ios-strip-test:
	@python3 ios/scripts/test_strip_embedded_frameworks.py

native-ios-check: get ios-strip-test
	@tool/write_firebase_options_stub.sh
	@test -f ios/Runner/GoogleService-Info.plist || cp ios/Runner/GoogleService-Info.plist.stub ios/Runner/GoogleService-Info.plist
	@swift test --package-path ios
	@check_dir=$$(mktemp -d); \
	xcrun swiftc -swift-version 6 -parse-as-library \
		packages/cloud_functions/ios/cloud_functions/Sources/cloud_functions/CodecUtility.swift \
		packages/cloud_functions/ios/cloud_functions/Sources/cloud_functions/FunctionsArguments.swift \
		packages/cloud_functions/native_tests/NativeSwiftCheck.swift \
		-o "$$check_dir/cloud-functions-check" && "$$check_dir/cloud-functions-check"
	@$(FLUTTER) build ios --config-only --debug --no-codesign --dart-define=SKIP_FIREBASE_INIT=true
	@xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Debug \
		-sdk iphonesimulator -destination 'generic/platform=iOS Simulator' ARCHS=arm64 ONLY_ACTIVE_ARCH=YES COMPILATION_CACHE_ENABLE_CACHING=YES \
		-derivedDataPath build/ios/native-tests build-for-testing CODE_SIGNING_ALLOWED=NO FLUTTER_BUILD_MODE=debug

test: ensure-fvm
	@if ls test/*_test.dart >/dev/null 2>&1 || find test -name '*_test.dart' -print -quit | grep -q .; then \
		$(FLUTTER) test $(TEST_FLAGS) && \
		$(FLUTTER) test $(TEST_FLAGS) --dart-define=dart.vm.product=true --dart-define=PRISM_PERF_AUTODRIVE=true test/core/debug/performance_probe_release_test.dart test/core/platform/cloud_functions_perf_test.dart; \
	else \
		echo "No test files found, skipping."; \
	fi

.PHONY: test-qa-render
test-qa-render: ensure-fvm
	@$(FLUTTER) test $(QA_RENDER_TARGET) --dart-define=QA_RENDER=true $(QA_RENDER_FLAGS)

cloudflare-worker-check:
	@sh ./tool/cloudflare-worker-check.sh

find-unused: ensure-fvm ## Find unreachable files and unused public symbols
	@$(DART) run tool/find_unused_code.dart

find-unused-html: ensure-fvm ## Find unused code + open HTML visual report
	@$(DART) run tool/find_unused_code.dart --html

find-unused-ci: ensure-fvm ## Fail if find-unused diverges from allowlist
	@report=$$(mktemp) && trap 'rm -f "$$report"' EXIT && \
		$(DART) run tool/find_unused_code.dart --json > "$$report" && \
		$(DART) run tool/validate_find_unused_allowlist.dart "$$report" tool/find_unused_allowlist.json

.PHONY: test-coverage test-functions-coverage test-coverage-tool
test-coverage: ensure-fvm
	@FLUTTER="$(FLUTTER)" DART="$(DART)" bash tool/flutter_coverage.sh

test-functions-coverage:
	@bash tool/functions_coverage.sh

test-coverage-tool: ensure-fvm
	@FLUTTER="$(FLUTTER)" DART="$(DART)" python3 -m unittest discover -s tool -p 'test_coverage*test.py'
