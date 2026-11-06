"""Partition test files before Flutter compiles them, not tests within every file."""

import argparse
import os
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--total-shards', type=int, required=True)
    parser.add_argument('--shard-index', type=int, required=True)
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if args.total_shards <= 0 or not 0 <= args.shard_index < args.total_shards:
        parser.error('Require total-shards > 0 and 0 <= shard-index < total-shards.')
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command:
        parser.error('Pass the Flutter test command after --.')
    files = sorted(str(path) for path in Path('test').rglob('*_test.dart') if path.is_file())
    selected = files[args.shard_index::args.total_shards]
    if not selected:
        parser.error('The shard has no test files; check the working directory and shard count.')
    print(f'Flutter shard {args.shard_index}/{args.total_shards}: {len(selected)}/{len(files)} files', flush=True)
    os.execvp(command[0], command + selected)


if __name__ == '__main__':
    main()
