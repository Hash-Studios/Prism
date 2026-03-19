#!/usr/bin/env python3

import pathlib
import re
import sys


ROOT = pathlib.Path(__file__).resolve().parent.parent
CHANGELOG = ROOT / "CHANGELOG.md"


def normalize_message(raw: str) -> str:
    lines = raw.splitlines()
    if not lines:
        return ""
    first_line = lines[0].strip()
    first_line = re.sub(r"\s+", " ", first_line)
    return first_line


def should_skip(message: str) -> bool:
    lowered = message.lower()
    return "[skip changelog]" in lowered or lowered.startswith("chore(changelog):")


def ensure_unreleased_section(lines: list[str]) -> list[str]:
    has_unreleased = any(line.strip() == "### Unreleased" for line in lines)
    if has_unreleased:
        return lines

    insert_at = 0
    for idx, line in enumerate(lines):
        if line.strip() == "## Changelog":
            insert_at = idx + 1
            break

    block = ["", "### Unreleased", ""]
    return lines[:insert_at] + block + lines[insert_at:]


def insert_bullet(lines: list[str], bullet: str, sha_short: str) -> tuple[list[str], bool]:
    sha_token = f"`{sha_short}`"
    if any(sha_token in line for line in lines):
        return lines, False

    unreleased_idx = next((i for i, line in enumerate(lines) if line.strip() == "### Unreleased"), None)
    if unreleased_idx is None:
        return lines, False

    insert_at = unreleased_idx + 1
    while insert_at < len(lines) and lines[insert_at].startswith("- "):
        insert_at += 1
    if insert_at < len(lines) and lines[insert_at].strip() != "":
        lines.insert(insert_at, "")

    lines.insert(unreleased_idx + 1, bullet)
    return lines, True


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: update_changelog.py <commit_message> <commit_sha>", file=sys.stderr)
        return 2

    message = normalize_message(sys.argv[1])
    sha = sys.argv[2].strip()
    sha_short = sha[:7] if sha else "unknown"

    if not message or should_skip(message):
        print("Skipping changelog update for this commit message")
        return 0

    text = CHANGELOG.read_text(encoding="utf-8")
    lines = text.splitlines()

    lines = ensure_unreleased_section(lines)
    bullet = f"- {message} (`{sha_short}`)"
    lines, inserted = insert_bullet(lines, bullet, sha_short)

    if not inserted:
        print("No changelog update needed")
        return 0

    updated_text = "\n".join(lines).rstrip() + "\n"
    CHANGELOG.write_text(updated_text, encoding="utf-8")
    print(f"Added changelog entry: {bullet}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
