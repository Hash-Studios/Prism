#!/usr/bin/env python3
"""Check the store listing files in metadata/ against the App Store and Google Play limits.

Usage: python3 tool/check_store_listings.py [metadata_dir]
"""

import json
import re
import sys
import unicodedata
from pathlib import Path

LIMITS = {
    'name': 30,
    'subtitle': 30,
    'keywords': 100,
    'promotionalText': 170,
    'description': 4000,
    'whatsNew': 4000,
    'title': 30,
    'short_description': 80,
    'full_description': 4000,
    # Prism's own rule, so a caption stays readable on a phone screenshot.
    'headline': 30,
    'subline': 60,
}
PLAY_FILES = ('title', 'short_description', 'full_description')
COMPETITORS = {
    'abstruct', 'backdrops', 'everpix', 'iscreen', 'minipaper', 'muzei', 'myscreen', 'tapet', 'themify',
    'unsplash', 'vellum', 'walldrobe', 'wallcandy', 'wallcraft', 'walley', 'walli', 'wallaroo', 'wallpics',
    'wallspark', 'wallspy', 'walltanic', 'wlppr', 'zedge',
}
STEM_EQUIVALENTS = {'hintergründe': 'hintergrund', 'papéis': 'papel'}
LEFTOVER = re.compile(r'\{[^}]*\}|\bTODO\b|\bTBD\b|\bXXX\b|[Ll]orem ipsum')


def words(text):
    normalized = unicodedata.normalize('NFC', text).lower()
    result = []
    current = []
    for character in normalized:
        if unicodedata.category(character)[0] in {'L', 'N', 'M'}:
            current.append(character)
        elif current:
            result.append(''.join(current))
            current = []
    if current:
        result.append(''.join(current))
    return result


def stem(word):
    if word in STEM_EQUIVALENTS:
        return STEM_EQUIVALENTS[word]
    return word[:-1] if len(word) > 3 and word.endswith('s') else word


def check_text(path, field, text, errors, allow_empty=False):
    if not isinstance(text, str):
        errors.append(f'{path}: {field} must be a non-empty string')
        return
    limit = LIMITS.get(field)
    if limit is not None and len(text) > limit:
        errors.append(f'{path}: {field} is {len(text)} characters, limit {limit}')
    if not text.strip():
        if not allow_empty:
            errors.append(f'{path}: {field} is empty')
        return
    if LEFTOVER.search(text):
        errors.append(f'{path}: {field} has a placeholder: {LEFTOVER.search(text).group(0)!r}')
    brands = COMPETITORS.intersection(words(text))
    if brands:
        errors.append(f'{path}: {field} names a competitor: {", ".join(sorted(brands))}')


def check_keywords(path, keywords, name, subtitle, errors):
    if not isinstance(keywords, str) or not isinstance(name, str) or not isinstance(subtitle, str):
        return
    if keywords != keywords.strip() or re.search(r'\s,|,\s', keywords):
        errors.append(f'{path}: keywords have spaces around commas, which waste characters')
    seen = {stem(w): 'name or subtitle' for w in words(f'{name} {subtitle}')}
    for term in keywords.split(','):
        if not term.strip():
            errors.append(f'{path}: keywords have an empty term')
        for word in words(term):
            if stem(word) in seen:
                errors.append(f'{path}: keyword word {word!r} repeats a word already in the {seen[stem(word)]}')
            seen.setdefault(stem(word), 'keywords')


def latest_version_dir(app_store):
    versions = [p for p in (app_store / 'version').glob('*') if p.is_dir()]
    return max(versions, key=lambda p: [int(n) for n in re.findall(r'\d+', p.name)], default=None)


def read_json(path, errors):
    try:
        data = json.loads(path.read_text(encoding='utf-8'))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        errors.append(f'{path}: invalid JSON: {exc}')
        return None
    if not isinstance(data, dict):
        errors.append(f'{path}: JSON root must be an object')
        return None
    return data


def check_required_fields(path, data, fields, errors):
    for field in fields:
        if field not in data:
            errors.append(f'{path}: missing required field {field}')


def check_app_store(app_store, errors):
    version_dir = latest_version_dir(app_store)
    if version_dir is None:
        errors.append(f'{app_store}: no version directory')
        return 0
    infos = {p.stem: p for p in (app_store / 'app-info').glob('*.json')}
    versions = {p.stem: p for p in version_dir.glob('*.json')}
    if not infos:
        errors.append(f'{app_store}: no App Store locale files')
    if not versions:
        errors.append(f'{version_dir}: no version locale files')
    for locale in sorted(infos.keys() ^ versions.keys()):
        errors.append(f'{app_store}: locale {locale} needs both app-info and version/{version_dir.name} files')
    for locale in sorted(infos.keys() & versions.keys()):
        info = read_json(infos[locale], errors)
        version = read_json(versions[locale], errors)
        if info is None or version is None:
            continue
        check_required_fields(infos[locale], info, ('name',), errors)
        check_required_fields(versions[locale], version,
                              ('description', 'keywords', 'whatsNew'), errors)
        for path, data in ((infos[locale], info), (versions[locale], version)):
            for field, text in data.items():
                optional_field = field in {'subtitle', 'promotionalText'}
                check_text(path, field, text, errors, allow_empty=optional_field or field not in LIMITS)
        check_keywords(versions[locale], version.get('keywords', ''), info.get('name', ''),
                       info.get('subtitle', ''), errors)
    return len(infos.keys() & versions.keys())


def check_play(play, errors):
    locales = sorted(p for p in play.glob('*') if p.is_dir())
    if not locales:
        errors.append(f'{play}: no Play locales')
    for locale in locales:
        for field in PLAY_FILES:
            path = locale / f'{field}.txt'
            if not path.is_file():
                errors.append(f'{path}: missing')
                continue
            try:
                text = path.read_text(encoding='utf-8')
            except (OSError, UnicodeError) as exc:
                errors.append(f'{path}: could not read text: {exc}')
                continue
            check_text(path, field, text.rstrip('\n'), errors)
    return len(locales)


def check_captions(captions, errors):
    files = sorted(captions.glob('*.json'))
    if not files:
        errors.append(f'{captions}: no screenshot caption files')
    for path in files:
        data = read_json(path, errors)
        if data is None:
            continue
        if not data:
            errors.append(f'{path}: no caption stores')
        for store, shots in data.items():
            if not isinstance(shots, list):
                errors.append(f'{path}: {store} captions must be a list')
                continue
            if not shots:
                errors.append(f'{path}: {store} captions must not be empty')
                continue
            for shot in shots:
                if not isinstance(shot, dict):
                    errors.append(f'{path}: {store} caption entries must be objects')
                    continue
                shot_file = shot.get('file')
                if not isinstance(shot_file, str) or not shot_file.strip():
                    errors.append(f'{path}: {store} caption is missing a file name')
                for field in ('headline', 'subline'):
                    check_text(f'{path} {store}/{shot_file or "?"}', field, shot.get(field), errors)
    return len(files)


def main(argv):
    root = Path(argv[1] if len(argv) > 1 else Path(__file__).resolve().parents[1] / 'metadata')
    errors = []
    counts = (
        check_app_store(root / 'app-store', errors),
        check_play(root / 'play', errors),
        check_captions(root / 'screenshot-captions', errors),
    )
    for error in errors:
        print(f'FAIL: {error}', file=sys.stderr)
    if errors:
        return 1
    print('Store listings OK: {} App Store locales, {} Play locales, {} caption files.'.format(*counts))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
