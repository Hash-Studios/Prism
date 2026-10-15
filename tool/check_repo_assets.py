#!/usr/bin/env python3
"""Reject oversized tracked files and tracked mobile release artifacts."""

import os
import stat
import subprocess
import sys


MAX_FILE_BYTES = 1024 * 1024
RELEASE_SUFFIXES = (b'.apk', b'.aab', b'.ipa')


def main() -> int:
    tracked_paths = subprocess.check_output(['git', 'ls-files', '-z']).split(b'\0')
    offenders = []

    for path in tracked_paths:
        if not path:
            continue

        try:
            file_stat = os.lstat(path)
        except FileNotFoundError:
            continue

        if not stat.S_ISREG(file_stat.st_mode):
            continue

        reasons = []
        if file_stat.st_size > MAX_FILE_BYTES:
            reasons.append(f'{file_stat.st_size} bytes exceeds {MAX_FILE_BYTES} bytes')
        if path.lower().endswith(RELEASE_SUFFIXES):
            reasons.append('mobile release artifact must not be tracked')
        if reasons:
            offenders.append((path, reasons))

    if offenders:
        for path, reasons in offenders:
            print(f'FAIL: {os.fsdecode(path)!r}: {"; ".join(reasons)}', file=sys.stderr)
        print(f'Found {len(offenders)} tracked file(s) outside the repository asset policy.', file=sys.stderr)
        return 1

    print(f'Repository asset check passed. Tracked regular files are at most {MAX_FILE_BYTES} bytes.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
