#!/usr/bin/env python3
"""Check Indonesian app and native localization contracts without third-party dependencies."""

from __future__ import annotations

import json
import re
import sys
import xml.etree.ElementTree as ET
from collections import Counter
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
EN_ARB = ROOT / 'lib/l10n/app_en.arb'
ID_ARB = ROOT / 'lib/l10n/app_id.arb'
ANDROID_EN = ROOT / 'android/app/src/main/res/values/strings.xml'
ANDROID_ID = ROOT / 'android/app/src/main/res/values-in/strings.xml'
IOS_EN = ROOT / 'ios/Runner/en.lproj/InfoPlist.strings'
IOS_ID = ROOT / 'ios/Runner/id.lproj/InfoPlist.strings'
IOS_CATALOG = ROOT / 'ios/Runner/Localizable.xcstrings'
XCODE_PROJECT = ROOT / 'ios/Runner.xcodeproj/project.pbxproj'
FONT_DIR = ROOT / 'assets/fonts'

ARGUMENT_NAME = re.compile(r'^[A-Za-z_][A-Za-z0-9_]*$')
ICU_TYPES = {'plural', 'selectordinal', 'select', 'number', 'date', 'time'}
ANDROID_FORMAT = re.compile(r'%(?:(\d+)\$)?([-+#0 ,(<]*)?(\d+)?(?:\.(\d+))?([tT])?([a-zA-Z%])')
IOS_FORMAT = re.compile(r'%(?:(\d+)\$)?([-+#0 ]*)(\d+)?(?:\.(\d+))?(ll|l|hh|h|z|t|j)?([@a-zA-ZdiuoxXfFeEgGcCsSp])')


def printf_contract(value: str, platform: str) -> Counter[tuple[Any, ...]]:
    """Compare native format arguments by effective argument and conversion type."""
    implicit_index = 0
    previous_index: int | None = None
    tokens: list[tuple[Any, ...]] = []
    index = 0
    while index < len(value):
        if value[index] != '%':
            index += 1
            continue
        if value.startswith('%%', index):
            index += 2
            continue
        match = (ANDROID_FORMAT if platform == 'android' else IOS_FORMAT).match(value, index)
        if match is None:
            if platform == 'ios' and re.match(r'%(?:\d+\$)?[-+#0 ]*(?:\*|\.(?:\*|\d*\*))', value[index:]):
                raise CheckFailure('unsupported dynamic width or precision in iOS format string')
            index += 1
            continue
        if platform == 'android':
            position, flags, width, precision, date_prefix, conversion = match.groups()
            if conversion == '%':
                index = match.end()
                continue
            if conversion == 'n':
                index = match.end()
                continue
            if '<' in (flags or ''):
                if previous_index is None:
                    raise CheckFailure('Android relative format conversion has no prior argument')
                argument_index = previous_index
            else:
                if position:
                    argument_index = int(position)
                else:
                    implicit_index += 1
                    argument_index = implicit_index
                previous_index = argument_index
            conversion_type = (date_prefix or '') + conversion
            index = match.end()
            tokens.append((argument_index, conversion_type))
            continue
        position, flags, width, precision, length, conversion = match.groups()
        if conversion == '%':
            index = match.end()
            continue
        if position is None:
            implicit_index += 1
            argument_index = implicit_index
        else:
            argument_index = int(position)
        tokens.append((argument_index, conversion, length or '', flags, width or '', precision or ''))
        index = match.end()
    return Counter(tokens)


class CheckFailure(Exception):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise CheckFailure(message)


def unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        require(key not in result, f'duplicate JSON key {key!r}')
        result[key] = value
    return result


def read_json(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding='utf-8'), object_pairs_hook=unique_object)
    except (OSError, json.JSONDecodeError) as error:
        raise CheckFailure(f'{path.relative_to(ROOT)}: {error}') from error
    require(isinstance(data, dict), f'{path.relative_to(ROOT)} must contain an object')
    return data


def matching_brace(message: str, start: int) -> int:
    """Return the closing brace for an ICU argument, honoring ICU apostrophe quoting."""
    depth = 0
    quoted = False
    index = start
    while index < len(message):
        char = message[index]
        if char == "'":
            if index + 1 < len(message) and message[index + 1] == "'":
                index += 2
                continue
            if quoted:
                quoted = False
            elif index + 1 < len(message) and message[index + 1] in '{}#':
                quoted = True
            index += 1
            continue
        if not quoted:
            if char == '{':
                depth += 1
            elif char == '}':
                depth -= 1
                if depth == 0:
                    return index
        index += 1
    raise CheckFailure(f'unclosed ICU argument in {message!r}')


def split_icu_fields(argument: str) -> list[str]:
    fields: list[str] = []
    start = 0
    depth = 0
    quoted = False
    index = 0
    while index < len(argument):
        char = argument[index]
        if char == "'":
            if index + 1 < len(argument) and argument[index + 1] == "'":
                index += 2
                continue
            if quoted:
                quoted = False
            elif index + 1 < len(argument) and argument[index + 1] in '{}#':
                quoted = True
        elif not quoted:
            if char == '{':
                depth += 1
            elif char == '}':
                depth -= 1
            elif char == ',' and depth == 0:
                fields.append(argument[start:index].strip())
                start = index + 1
        index += 1
    fields.append(argument[start:].strip())
    return fields


def selector_contract(body: str, message: str) -> tuple[set[str], list[str]]:
    selectors: set[str] = set()
    branches: list[str] = []
    index = 0
    while index < len(body):
        while index < len(body) and body[index].isspace():
            index += 1
        if index == len(body):
            break
        selector_start = index
        while index < len(body) and not body[index].isspace() and body[index] != '{':
            index += 1
        selector = body[selector_start:index]
        while index < len(body) and body[index].isspace():
            index += 1
        require(bool(selector) and index < len(body) and body[index] == '{',
                f'invalid ICU selector list in {message!r}')
        selectors.add(selector)
        end = matching_brace(body, index)
        branches.append(body[index + 1:end])
        index = end + 1
    return selectors, branches


def message_contract(message: str) -> tuple[set[str], set[tuple[str, str]], dict[tuple[str, str], set[str]]]:
    arguments: set[str] = set()
    formats: set[tuple[str, str]] = set()
    selectors: dict[tuple[str, str], set[str]] = {}

    def scan(text: str) -> None:
        index = 0
        quoted = False
        while index < len(text):
            char = text[index]
            if char == "'":
                if index + 1 < len(text) and text[index + 1] == "'":
                    index += 2
                    continue
                if quoted:
                    quoted = False
                elif index + 1 < len(text) and text[index + 1] in '{}#':
                    quoted = True
                index += 1
                continue
            if char == '{' and not quoted:
                end = matching_brace(text, index)
                inner = text[index + 1:end]
                fields = split_icu_fields(inner)
                name = fields[0]
                require(bool(ARGUMENT_NAME.fullmatch(name)), f'invalid ICU argument {name!r} in {message!r}')
                arguments.add(name)
                if len(fields) >= 2 and fields[1] in ICU_TYPES:
                    kind = fields[1]
                    formats.add((name, kind))
                    if kind in {'plural', 'selectordinal', 'select'}:
                        options, branches = selector_contract(','.join(fields[2:]), message)
                        require('other' in options, f'ICU {kind} argument {name!r} has no other branch')
                        selectors[(name, kind)] = options
                        for branch in branches:
                            scan(branch)
                index = end + 1
                continue
            index += 1

    scan(message)
    return arguments, formats, selectors


def self_test_icu_parser() -> None:
    plural = message_contract('{count, plural, one{{name} photo} other{{name} photos}}')
    require(plural == (
        {'count', 'name'},
        {('count', 'plural')},
        {('count', 'plural'): {'one', 'other'}},
    ), 'ICU parser self-test failed for plural branches and nested interpolation')
    selected = message_contract('{gender, select, female{She has {count}} other{They have {count}}}')
    require(selected == (
        {'gender', 'count'},
        {('gender', 'select')},
        {('gender', 'select'): {'female', 'other'}},
    ), 'ICU parser self-test failed for select branches and nested interpolation')
    quoted = message_contract("Literal '{notAPlaceholder}' and {size, number}")
    require(quoted == ({'size'}, {('size', 'number')}, {}), 'ICU parser self-test failed for quoted braces')


def placeholder_metadata(entry: dict[str, Any], key: str) -> dict[str, Any]:
    metadata = entry.get(f'@{key}', {})
    require(isinstance(metadata, dict), f'@{key} metadata must be an object')
    placeholders = metadata.get('placeholders', {})
    require(isinstance(placeholders, dict), f'@{key}.placeholders must be an object')
    return placeholders


def placeholder_contract(descriptor: Any, key: str, name: str) -> dict[str, Any]:
    require(isinstance(descriptor, dict), f'@{key}.placeholders.{name} must be an object')
    # Examples and descriptions are translator-facing text, not generated API contracts.
    return {field: value for field, value in descriptor.items() if field not in {'example', 'description'}}


def check_arb() -> tuple[str, list[str]]:
    english = read_json(EN_ARB)
    indonesian = read_json(ID_ARB)
    require(english.get('@@locale') == 'en', 'app_en.arb must declare @@locale "en"')
    require(indonesian.get('@@locale') in {'id', 'id_ID'}, 'app_id.arb must declare Indonesian locale')
    source_keys = {key for key, value in english.items() if not key.startswith('@') and key != '@@locale'}
    target_keys = {key for key, value in indonesian.items() if not key.startswith('@') and key != '@@locale'}
    missing = sorted(source_keys - target_keys)
    extra = sorted(target_keys - source_keys)
    require(not missing and not extra,
            f'ARB key mismatch: {len(missing)} missing {missing[:8]}, {len(extra)} extra {extra[:8]}')

    for key in sorted(source_keys):
        source, target = english[key], indonesian[key]
        require(isinstance(source, str) and isinstance(target, str), f'{key} values must be strings')
        source_args, source_formats, source_selectors = message_contract(source)
        target_args, target_formats, target_selectors = message_contract(target)
        require(source_args == target_args, f'{key} ICU arguments differ: {sorted(source_args)} != {sorted(target_args)}')
        require(source_formats == target_formats,
                f'{key} ICU format contracts differ: {sorted(source_formats)} != {sorted(target_formats)}')
        for selector_key, selectors in source_selectors.items():
            translated = target_selectors.get(selector_key, set())
            kind = selector_key[1]
            if kind == 'select':
                require(selectors == translated,
                        f'{key} ICU select branches differ for {selector_key[0]}: {sorted(selectors)} != {sorted(translated)}')
        source_meta = placeholder_metadata(english, key)
        target_meta = placeholder_metadata(indonesian, key)
        require(set(source_meta) == set(target_meta),
                f'{key} placeholder metadata differs: {sorted(source_meta)} != {sorted(target_meta)}')
        for name in source_meta:
            source_contract = placeholder_contract(source_meta[name], key, name)
            target_contract = placeholder_contract(target_meta[name], key, name)
            require(source_contract == target_contract,
                    f'{key}.{name} placeholder contract differs: {source_contract} != {target_contract}')
        if source_args:
            require(set(source_meta) == source_args,
                    f'{key} metadata placeholders {sorted(source_meta)} do not describe ICU arguments {sorted(source_args)}')
    return str(indonesian['@@locale']), [indonesian[key] for key in sorted(source_keys)]


def android_strings(path: Path) -> dict[str, str]:
    try:
        root = ET.parse(path).getroot()
    except (OSError, ET.ParseError) as error:
        raise CheckFailure(f'{path.relative_to(ROOT)}: {error}') from error
    result: dict[str, str] = {}
    for item in root.findall('string'):
        key = item.get('name')
        require(bool(key), f'{path.relative_to(ROOT)} contains a string without a name')
        require(key not in result, f'{path.relative_to(ROOT)} repeats string key {key!r}')
        result[key] = ''.join(item.itertext())
    return result




def check_android() -> None:
    english = android_strings(ANDROID_EN)
    indonesian = android_strings(ANDROID_ID)
    require(english.keys() == indonesian.keys(),
            f'Android string keys differ: missing {sorted(english.keys() - indonesian.keys())}, '
            f'extra {sorted(indonesian.keys() - english.keys())}')
    for key in english:
        source = printf_contract(english[key], 'android')
        target = printf_contract(indonesian[key], 'android')
        require(source == target,
                f'Android {key} positional placeholders differ: {sorted(source.elements())} != {sorted(target.elements())}')


IOS_ENTRY = re.compile(r'\s*"((?:\\.|[^"\\])*)"\s*=\s*"((?:\\.|[^"\\])*)"\s*;', re.DOTALL)


def parse_ios_strings(content: str) -> dict[str, str]:
    """Parse quoted key/value entries while removing comments outside strings."""
    visible: list[str] = []
    index = 0
    in_string = False
    while index < len(content):
        if in_string:
            char = content[index]
            visible.append(char)
            if char == '\\' and index + 1 < len(content):
                index += 1
                visible.append(content[index])
            elif char == '"':
                in_string = False
            index += 1
            continue
        if content[index] == '"':
            in_string = True
            visible.append(content[index])
            index += 1
        elif content.startswith('//', index):
            end = content.find('\n', index)
            index = len(content) if end == -1 else end
        elif content.startswith('/*', index):
            end = content.find('*/', index + 2)
            require(end != -1, 'unterminated iOS strings comment')
            visible.extend('\n' for char in content[index:end + 2] if char == '\n')
            index = end + 2
        else:
            visible.append(content[index])
            index += 1
    require(not in_string, 'unterminated quoted value in iOS strings file')
    residue = ''.join(visible)
    result: dict[str, str] = {}
    while residue.strip():
        match = IOS_ENTRY.match(residue)
        require(match is not None, 'iOS strings file has malformed entry or trailing junk')
        key, value = match.groups()
        require(key not in result, f'duplicate permission key {key!r}')
        result[key] = value
        residue = residue[match.end():]
    return result


def ios_strings(path: Path) -> dict[str, str]:
    try:
        content = path.read_text(encoding='utf-8')
    except OSError as error:
        raise CheckFailure(f'{path.relative_to(ROOT)}: {error}') from error
    try:
        return parse_ios_strings(content)
    except CheckFailure as error:
        raise CheckFailure(f'{path.relative_to(ROOT)}: {error}') from error


def check_ios() -> tuple[int, int]:
    english = ios_strings(IOS_EN)
    indonesian = ios_strings(IOS_ID)
    require(english.keys() == indonesian.keys(),
            f'iOS permission keys differ: missing {sorted(english.keys() - indonesian.keys())}, '
            f'extra {sorted(indonesian.keys() - english.keys())}')
    catalog = read_json(IOS_CATALOG)
    require(catalog.get('sourceLanguage') == 'en', 'iOS Localizable.xcstrings must use English source strings')
    catalog_strings = catalog.get('strings')
    require(isinstance(catalog_strings, dict), 'iOS Localizable.xcstrings must contain a strings object')
    for key, entry in catalog_strings.items():
        require(isinstance(entry, dict), f'iOS string {key!r} must be an object')
        localizations = entry.get('localizations', {})
        require(isinstance(localizations, dict), f'iOS string {key!r} localizations must be an object')
        english_locale = localizations.get('en', {})
        id_locale = localizations.get('id', {})
        require(isinstance(english_locale, dict) and isinstance(id_locale, dict),
                f'iOS string {key!r} localization entries must be objects')
        english_unit = english_locale.get('stringUnit', {})
        id_unit = id_locale.get('stringUnit', {})
        require(isinstance(english_unit, dict) and isinstance(id_unit, dict),
                f'iOS string {key!r} string units must be objects')
        require(english_unit.get('state') == 'translated' and isinstance(english_unit.get('value'), str),
                f'iOS string {key!r} lacks a translated English source')
        require(id_unit.get('state') == 'translated' and isinstance(id_unit.get('value'), str),
                f'iOS string {key!r} lacks a translated Indonesian value')
        source_arguments = printf_contract(english_unit['value'], 'ios')
        translated_arguments = printf_contract(id_unit['value'], 'ios')
        require(source_arguments == translated_arguments,
                f'iOS string {key!r} printf placeholders differ: '
                f'{sorted(source_arguments.elements())} != {sorted(translated_arguments.elements())}')
    project = XCODE_PROJECT.read_text(encoding='utf-8')
    require('id.lproj/InfoPlist.strings' in project, 'Xcode project does not reference id.lproj/InfoPlist.strings')
    variant_group = re.search(
        r'/\* InfoPlist\.strings \*/\s*=\s*\{\s*isa = PBXVariantGroup;\s*children = \((.*?)\);',
        project,
        re.DOTALL,
    )
    require(variant_group is not None and re.search(r'/\* id \*/', variant_group.group(1)),
            'Xcode InfoPlist.strings variant group does not register the Indonesian file')
    known_regions = re.search(r'knownRegions\s*=\s*\(([^)]*)\)', project, re.DOTALL)
    require(known_regions is not None and re.search(r'(?m)^\s*id\s*,', known_regions.group(1)),
            'Xcode project knownRegions does not include id')
    require('Localizable.xcstrings in Resources' in project and 'Localizable.xcstrings' in project,
            'Xcode project does not register Localizable.xcstrings as an app resource')
    return len(english), len(catalog_strings)


def check_fonts(translations: list[str]) -> str:
    text_glyphs = {char for message in translations for char in message if char.isalpha()}
    try:
        from fontTools.ttLib import TTFont  # type: ignore[import-not-found]
    except ImportError:
        return f'SKIP: fontTools is unavailable; {len(text_glyphs)} Indonesian alphabetic glyphs were not inspected.'
    fonts = sorted(path for path in FONT_DIR.rglob('*') if path.suffix.lower() in {'.ttf', '.otf'})
    families = {
        'Proxima Nova': [path for path in fonts if path.name.startswith(('Proxima Nova', 'ProximaNova'))],
        'Satoshi': [path for path in fonts if path.name.startswith('Satoshi')],
        'Fraunces': [path for path in fonts if path.name.startswith('Fraunces')],
    }
    require(all(families.values()), 'one or more primary text font families are missing from assets/fonts')
    results: list[str] = []
    for family, paths in families.items():
        supported: set[str] = set()
        for path in paths:
            try:
                font = TTFont(path, lazy=True)
                for table in font['cmap'].tables:
                    supported.update(chr(codepoint) for codepoint in table.cmap if codepoint <= 0x10FFFF)
                font.close()
            except Exception as error:  # fontTools raises several format-specific exceptions
                raise CheckFailure(f'cannot inspect {path.relative_to(ROOT)}: {error}') from error
        missing = sorted(text_glyphs - supported)
        require(not missing, f"{family} lacks Indonesian alphabetic glyphs: {''.join(missing)}")
        results.append(f'{family}: {len(text_glyphs)} glyphs covered')
    return f'PASS: primary text fonts cover all Indonesian alphabetic glyphs ({"; ".join(results)}).'


def main() -> int:
    try:
        self_test_icu_parser()
        locale, translations = check_arb()
        check_android()
        permission_count, native_string_count = check_ios()
        font_status = check_fonts(translations)
    except CheckFailure as error:
        print(f'FAIL: {error}', file=sys.stderr)
        return 1
    print(f'PASS: ARB locale {locale}, exact key set, ICU and placeholder contracts.')
    print('PASS: Android key parity and positional placeholders.')
    print(
        f'PASS: {permission_count} iOS permissions, {native_string_count} native strings and printf contracts, '
        'Xcode localization registration.'
    )
    print(font_status)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
