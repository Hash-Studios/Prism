#!/usr/bin/env python3
"""Sync lib/core/constants/app_constants.dart to the pubspec.yaml version.

With --check, change nothing and exit 1 when they differ.
"""

import pathlib
import re
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent
PUBSPEC = ROOT / "pubspec.yaml"
APP_CONSTANTS = ROOT / "lib/core/constants/app_constants.dart"


def read_pubspec_version() -> tuple[str, str]:
    text = PUBSPEC.read_text(encoding="utf-8")
    match = re.search(r"^version:\s*([0-9]+(?:\.[0-9]+){2})\+([0-9]+)\s*$", text, re.MULTILINE)
    if not match:
        raise ValueError("Unable to parse version from pubspec.yaml")
    return match.group(1), match.group(2)


def read_app_constants() -> tuple[str, str]:
    text = APP_CONSTANTS.read_text(encoding="utf-8")
    version_match = re.search(r"const String currentAppVersion = '([^']+)';", text)
    build_match = re.search(r"const String currentAppVersionCode = '([^']+)';", text)
    if not version_match or not build_match:
        raise ValueError("Unable to parse app version constants")
    return version_match.group(1), build_match.group(1)


def sync_constants(version: str, build: str) -> bool:
    text = APP_CONSTANTS.read_text(encoding="utf-8")
    updated = re.sub(
        r"const String currentAppVersion = '[^']+';",
        f"const String currentAppVersion = '{version}';",
        text,
    )
    updated = re.sub(
        r"const String currentAppVersionCode = '[^']+';",
        f"const String currentAppVersionCode = '{build}';",
        updated,
    )
    if updated == text:
        return False
    APP_CONSTANTS.write_text(updated, encoding="utf-8")
    return True


def main() -> int:
    check = "--check" in sys.argv[1:]
    try:
        version, build = read_pubspec_version()
        if check:
            app_version, app_build = read_app_constants()
            if (version, build) == (app_version, app_build):
                print(f"Version sync OK: {version}+{build}")
                return 0
            print(
                "Version mismatch detected:\n"
                f"- pubspec.yaml: {version}+{build}\n"
                f"- app_constants: {app_version}+{app_build}\n"
                "Run: python3 tool/sync_app_version.py",
                file=sys.stderr,
            )
            return 1
        if sync_constants(version, build):
            print(f"Synced app version constants to {version}+{build}")
        else:
            print(f"App version constants already synced at {version}+{build}")
        return 0
    except Exception as exc:
        print(f"sync_app_version.py failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
