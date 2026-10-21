#!/usr/bin/env python3
"""Inventory handwritten Dart coverage without treating unloaded code as covered.

Run the complete coverage workflow with ``bash tool/flutter_coverage.sh``; pass
an optional output directory and minimum percentage as its first and second
arguments. The script runs the full suite first, then a separate import-only
probe and reports using that probe only to inventory loaded lines. Its
initialization hits do not count toward the suite's coverage numerator.
"""

import argparse
import json
from pathlib import Path
import re
import sys
import subprocess


def generated(path, root):
    name = path.as_posix()
    return (name.endswith(('.g.dart', '.freezed.dart', '.gr.dart'))
            or path.name == 'injection.config.dart'
            or '/l10n/generated/' in '/' + name
            or path.relative_to(root).as_posix() == 'lib/firebase_options.dart')


def inventory(root):
    return sorted(p.relative_to(root).as_posix() for p in (root / 'lib').rglob('*.dart')
                  if not generated(p, root))


def records(lcov, root):
    result = {}
    current = None
    for line in lcov.read_text().splitlines():
        if line.startswith('SF:'):
            name = line[3:]
            if name.startswith('package:'):
                package = re.search(r'^name:\s*(\w+)', (root / 'pubspec.yaml').read_text(), re.M)
                prefix = 'package:' + package.group(1) + '/' if package else ''
                if prefix and name.startswith(prefix):
                    name = 'lib/' + name[len(prefix):]
            path = Path(name)
            if path.is_absolute():
                try:
                    name = path.relative_to(root).as_posix()
                except ValueError:
                    current = None
                    continue
            current = result.setdefault(name, {})
        elif line.startswith('DA:') and current is not None:
            number, hits, *_ = line[3:].split(',')
            number, hits = int(number), int(hits)
            if number < 1 or hits < 0:
                raise ValueError('LCOV line numbers and hits must be nonnegative (line >= 1)')
            current[number] = current.get(number, 0) + hits
        elif line == 'end_of_record':
            current = None
    return result


def report(root, lcov, minimum, declaration_only=(), inventory_lcov=()):
    sources = inventory(root)
    excluded = sorted(p.relative_to(root).as_posix() for p in (root / 'lib').rglob('*.dart')
                      if generated(p, root))
    data = {}
    for coverage in lcov if isinstance(lcov, list) else [lcov]:
        for name, lines in records(coverage, root).items():
            target = data.setdefault(name, {})
            for line, hits in lines.items():
                target[line] = target.get(line, 0) + hits
    for coverage in inventory_lcov:
        for name, lines in records(coverage, root).items():
            target = data.setdefault(name, {})
            for line in lines:
                target.setdefault(line, 0)
    missing = [name for name in sources if not data.get(name) and name not in declaration_only]
    ignored = [name for name in sources if 'coverage:ignore' in (root / name).read_text()]
    areas = {}
    for name in sources:
        parts = name.split('/')
        area = '/'.join(parts[:3] if parts[1] == 'features' else parts[:2])
        counts = areas.setdefault(area, {'hit': 0, 'found': 0})
        lines = data.get(name, {})
        counts['hit'] += sum(hits > 0 for hits in lines.values())
        counts['found'] += len(lines)
    hit = sum(a['hit'] for a in areas.values())
    found = sum(a['found'] for a in areas.values())
    percent = 100 * hit / found if found else None
    complete = not missing and not ignored and bool(found)
    passed = complete and percent >= minimum
    return {'complete': complete, 'passed': passed, 'minimum_percent': minimum,
            'handwritten_files': len(sources), 'missing_records': missing,
            'generated_files_excluded': excluded,
            'generated_exclusion_reason': 'Dart generator suffixes (.g/.freezed/.gr), injectable config, '
                                          'Flutter localization output, and root lib/firebase_options.dart '
                                          '(generated Firebase configuration).',
            'verified_declaration_only': sorted(declaration_only),
            'handwritten_coverage_ignore_directives': ignored,
            'observed_hit': hit, 'observed_found': found,
            'observed_percent': percent, 'areas': areas,
            'note': 'Observed percent is not a whole-source coverage claim when records are missing. '
                    'Use --verify-declarations to prove missing declaration-only files contain no executable source. '
                    'Executable lines come only from VM LCOV DA records.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--root', type=Path, default=Path.cwd())
    commands = parser.add_subparsers(dest='command', required=True)
    imports = commands.add_parser('imports')
    imports.add_argument('output', type=Path)
    reports = commands.add_parser('report')
    reports.add_argument('lcov', type=Path, nargs='+')
    reports.add_argument('--minimum', type=float, default=90)
    reports.add_argument('--inventory', type=Path, action='append', default=[],
                         help='Add executable lines from import-only LCOV without counting incidental hits')
    reports.add_argument('--verify-declarations', action='store_true',
                         help='Use the project Dart analyzer to prove missing files have no executable declarations')
    args = parser.parse_args()
    root = args.root.resolve()
    if args.command == 'imports':
        output = args.output.resolve()
        if output.exists():
            parser.error('Refusing to overwrite an existing file: ' + str(output))
        if output.parent != root / 'test' or not output.name.endswith('_test.dart'):
            parser.error('Output must be a new test/*_test.dart directly under the project root')
        package = re.search(r'^name:\s*(\w+)', (root / 'pubspec.yaml').read_text(), re.M).group(1)
        lines = ['// Generated coverage inventory. Delete after collecting coverage.',
                 "import 'package:flutter_test/flutter_test.dart';"]
        for name in inventory(root):
            # Part libraries load through their owning library, not a direct import.
            if not re.search(r'^\s*part\s+of\s', (root / name).read_text(), re.M):
                lines.append("import 'package:" + package + '/' + name[4:] + "';")
        lines.append("void main() { test('load coverage inventory', () {}); }")
        output.write_text('\n'.join(lines) + '\n')
        print(output)
        return 0
    if not 0 <= args.minimum <= 100:
        parser.error('--minimum must be between 0 and 100')
    declarations = []
    if args.verify_declarations:
        observed = {name for path in args.lcov + args.inventory
                    for name, lines in records(path, root).items() if lines}
        missing = [name for name in inventory(root) if name not in observed]
        if missing:
            process = subprocess.run(['fvm', 'dart', str(root / 'tool/test_coverage_declarations.dart'),
                                      *missing], cwd=root, check=True, capture_output=True, text=True)
            declarations = json.loads(process.stdout)
    result = report(root, args.lcov, args.minimum, declarations, args.inventory)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    sys.exit(main())
