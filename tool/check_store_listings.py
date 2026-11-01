#!/usr/bin/env python3
"""Check the store listing files in metadata/ against the App Store and Google Play limits.

Usage: python3 tool/check_store_listings.py [metadata_dir]
"""

import json
import re
import sys
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
LEFTOVER = re.compile(r'\{[^}]*\}|\bTODO\b|\bTBD\b|\bXXX\b|[Ll]orem ipsum')
SEPARATORS = re.compile(r'[\s,&:;.!?()"/·•|™®\-]+')


def words(text):
    return [w for w in SEPARATORS.split(text.lower()) if w]


def stem(word):
    return word[:-1] if len(word) > 3 and word.endswith('s') else word


def check_text(path, field, text, errors):
    limit = LIMITS.get(field)
    if limit is not None and len(text) > limit:
        errors.append(f'{path}: {field} is {len(text)} characters, limit {limit}')
    if LEFTOVER.search(text):
        errors.append(f'{path}: {field} has a placeholder: {LEFTOVER.search(text).group(0)!r}')
    brands = COMPETITORS.intersection(words(text))
    if brands:
        errors.append(f'{path}: {field} names a competitor: {", ".join(sorted(brands))}')


def check_keywords(path, keywords, name, subtitle, errors):
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


def check_app_store(app_store, errors):
    version_dir = latest_version_dir(app_store)
    if version_dir is None:
        errors.append(f'{app_store}: no version directory')
        return 0
    infos = {p.stem: p for p in (app_store / 'app-info').glob('*.json')}
    versions = {p.stem: p for p in version_dir.glob('*.json')}
    for locale in sorted(infos.keys() ^ versions.keys()):
        errors.append(f'{app_store}: locale {locale} needs both app-info and version/{version_dir.name} files')
    for locale in sorted(infos.keys() & versions.keys()):
        info = json.loads(infos[locale].read_text(encoding='utf-8'))
        version = json.loads(versions[locale].read_text(encoding='utf-8'))
        for path, data in ((infos[locale], info), (versions[locale], version)):
            for field, text in data.items():
                if field in LIMITS:
                    check_text(path, field, text, errors)
        check_keywords(versions[locale], version.get('keywords', ''), info.get('name', ''),
                       info.get('subtitle', ''), errors)
    return len(infos.keys() & versions.keys())


def check_play(play, errors):
    locales = sorted(p for p in play.glob('*') if p.is_dir())
    for locale in locales:
        for field in PLAY_FILES:
            path = locale / f'{field}.txt'
            if not path.is_file():
                errors.append(f'{path}: missing')
                continue
            text = path.read_text(encoding='utf-8')
            check_text(path, field, text.rstrip('\n'), errors)
    return len(locales)


def check_captions(captions, errors):
    files = sorted(captions.glob('*.json'))
    for path in files:
        for store, shots in json.loads(path.read_text(encoding='utf-8')).items():
            for shot in shots:
                for field in ('headline', 'subline'):
                    check_text(f'{path} {store}/{shot["file"]}', field, shot.get(field, ''), errors)
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
