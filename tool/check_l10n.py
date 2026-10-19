#!/usr/bin/env python3
"""Validate catalog keys and placeholder contracts before Flutter code generation."""
import json
from pathlib import Path
import sys


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f'Duplicate key: {key}')
        result[key] = value
    return result


def check():
    root = Path(__file__).resolve().parent.parent
    directory = root / 'lib/l10n'
    catalogs = {}
    for path in sorted(directory.glob('app_*.arb')):
        catalogs[path] = json.loads(path.read_text(), object_pairs_hook=unique_object)
    template = catalogs[directory / 'app_en.arb']
    keys = {key for key in template if not key.startswith('@')}
    for path, catalog in catalogs.items():
        locale = path.stem.removeprefix('app_')
        if catalog.get('@@locale') != locale:
            raise ValueError(f'{path.name}: @@locale must be {locale}')
        actual = {key for key in catalog if not key.startswith('@')}
        if actual != keys:
            raise ValueError(f'{path.name}: missing={sorted(keys - actual)}, extra={sorted(actual - keys)}')
        for key in keys:
            if not isinstance(catalog[key], str):
                raise ValueError(f'{path.name}: {key} must be a string')
            if ', plural,' in catalog[key] and '#' in catalog[key]:
                raise ValueError(f'{path.name}: {key} must use explicit number placeholders, not ICU #')
            expected = template.get(f'@{key}', {}).get('placeholders', {})
            translated = catalog.get(f'@{key}', {}).get('placeholders')
            if translated is not None and translated != expected:
                raise ValueError(f'{path.name}: {key} changes the template placeholder contract')
        for key in catalog:
            if key.startswith('@') and not key.startswith('@@') and key[1:] not in keys:
                raise ValueError(f'{path.name}: metadata without a message: {key}')
    print(f'Localization catalogs passed: {len(keys)} messages, {len(catalogs)} locales.')


if __name__ == '__main__':
    try:
        check()
    except (ValueError, KeyError, OSError) as error:
        print(error, file=sys.stderr)
        sys.exit(1)
