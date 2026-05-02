#!/usr/bin/env python3

import pathlib
import re
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent
PUBSPEC = ROOT / "pubspec.yaml"
APP_CONSTANTS = ROOT / "lib/core/constants/app_constants.dart"


def parse_pubspec() -> tuple[str, str]:
    text = PUBSPEC.read_text(encoding="utf-8")
    match = re.search(r"^version:\s*([0-9]+(?:\.[0-9]+){2})\+([0-9]+)\s*$", text, re.MULTILINE)
    if not match:
        raise ValueError("Could not parse pubspec.yaml version")
    return match.group(1), match.group(2)


def parse_app_constants() -> tuple[str, str]:
    text = APP_CONSTANTS.read_text(encoding="utf-8")
    version_match = re.search(r"const String currentAppVersion = '([^']+)';", text)
    build_match = re.search(r"const String currentAppVersionCode = '([^']+)';", text)
    if not version_match or not build_match:
        raise ValueError("Could not parse app version constants")
    return version_match.group(1), build_match.group(1)


def main() -> int:
    try:
        pub_version, pub_build = parse_pubspec()
        app_version, app_build = parse_app_constants()
    except Exception as exc:
        print(f"verify_version_sync.py failed: {exc}", file=sys.stderr)
        return 1

    if (pub_version, pub_build) == (app_version, app_build):
        print(f"Version sync OK: {pub_version}+{pub_build}")
        return 0

    print(
        "Version mismatch detected:\n"
        f"- pubspec.yaml: {pub_version}+{pub_build}\n"
        f"- app_constants: {app_version}+{app_build}\n"
        "Run: python3 tool/sync_app_version.py",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
