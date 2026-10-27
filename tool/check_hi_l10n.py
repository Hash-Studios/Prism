#!/usr/bin/env python3
"""Check Hindi app and native localization contracts using only the stdlib."""

import json
import plistlib
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

# Reviewed messages that are intentionally identical in English and Hindi.
# Keep values exact so a generic English UI message cannot be added by mistake.
UNCHANGED_ENGLISH = {
    'accountLinkTypeBehance': 'Behance',
    'accountLinkTypeBioLink': 'bio.link',
    'accountLinkTypeBuyMeACoffee': 'Buy Me a Coffee',
    'accountLinkTypeDeviantArt': 'DeviantArt',
    'accountLinkTypeDribbble': 'Dribbble',
    'accountLinkTypeGithub': 'GitHub',
    'accountLinkTypeGitlab': 'GitLab',
    'accountLinkTypeInstagram': 'Instagram',
    'accountLinkTypeLinkedin': 'LinkedIn',
    'accountLinkTypeLinktree': 'Linktree',
    'accountLinkTypeMedium': 'Medium',
    'accountLinkTypePatreon': 'Patreon',
    'accountLinkTypePaypal': 'PayPal',
    'accountLinkTypeReddit': 'Reddit',
    'accountLinkTypeSpotify': 'Spotify',
    'accountLinkTypeTelegram': 'Telegram',
    'accountLinkTypeTrello': 'Trello',
    'accountLinkTypeTwitch': 'Twitch',
    'accountLinkTypeTwitter': 'Twitter',
    'accountLinkTypeUnsplash': 'Unsplash',
    'accountLinkTypeYoutube': 'YouTube',
    'accountPrismPro': 'Prism Pro',
    'accountProBadge': 'Pro',
    'accountProfilePersonSemantics': '{name}, @{username}',
    'accountResolution1080': '1080p',
    'accountResolution1440': '1440p',
    'accountResolution4k': '4K',
    'accountSocialGithub': 'GITHUB',
    'accountSocialInstagram': 'INSTAGRAM',
    'accountSocialTelegram': 'TELEGRAM',
    'accountSocialTwitter': 'TWITTER',
    'accountStorageSizeBytes': '{size} B',
    'accountStorageSizeGigabytes': '{size} GB',
    'accountStorageSizeKilobytes': '{size} KB',
    'accountStorageSizeMegabytes': '{size} MB',
    'adminEmailExample': 'user@example.com',
    'adminFactLabel': '{label}: {value}',
    'adminReviewProgress': '{current}/{total}',
    'adminWallId': 'ID',
    'appTitle': 'Prism',
    'coreCoinBalanceChange': '{balance}, {change}',
    'coreContributorGithub': 'GitHub',
    'coreContributorTwitter': 'Twitter',
    'coreFileSizeMegabytes': '{size} MB',
    'coreThemeAmoled': 'AMOLED',
    'coreWallpaperSavedWithTip': '{saved} {tip}',
    'economyAiPromptSceneOnly': '{scene}, {suffix}',
    'economyCreatorMilestoneProgress': '{label}: {current} / {target}',
    'economyCreatorWeekRange': '{start} – {end} UTC',
    'economyDownloadCost': '{label} · {cost}',
    'economyDrawTitle': 'Prism Draw',
    'economyDropBrandTitle': 'THE DROP',
    'economyDropHeader': 'THE DROP · {week}',
    'economyDropTitle': 'Drop',
    'economyDropWatermarkLabel': 'PRISM DROP',
    'economyDrops': 'Drops',
    'economyOddsTierSemantics': '{tier}, {odds}',
    'economyPro': 'Pro',
    'economyRankPrism': 'Prism',
    'economyRankRewardMilestone': '{rank} · {xp} XP\n{reward}',
    'economyShopItemSemantics': '{name}, {status}',
    'economyShopPrism': 'Prism',
    'economySpendItemSemantics': '{label}, {price}',
    'economyStreakProReward': '+{coins} x{multiplier} Pro',
    'economyXp': '{count} XP',
    'economyXpAwarded': '+{xp} XP',
    'economyXpUnit': 'XP',
    'notifGroupCountAction': '{count} {label} · {action}',
    'notifPushWotdAudienceBody': '{wallTitle}',
    'onboardingPro': 'Pro',
    'premiumPageTitle': 'Prism Premium',
    'wallpaperAutoRotateNounCategory': '{category}',
    'wallpaperHomeAppName': 'Prism',
    'wallpaperPremium': 'Premium',
    'wallpaperProviderWallhaven': 'Wallhaven',
    'wallpaperSpatialPreviewLabel': '3D',
}

UNTRANSLATED_UI_TOKENS = (
    'Rewards', 'Downloads', 'Shop', 'Settings', 'Share', 'Done', 'Automation',
    'Unrestricted', 'Silver', 'Apps', 'Battery',
)


def require(condition, message):
    if not condition:
        raise ValueError(message)


def load_json(path):
    return json.loads(path.read_text(encoding='utf-8'), object_pairs_hook=unique_object)


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, f'duplicate key: {key}')
        result[key] = value
    return result


def message_keys(catalog):
    return {key for key in catalog if not key.startswith('@')}


def icu_contract(message):
    variables = set()
    selectors = []

    def parse_text(text):
        index = 0
        while index < len(text):
            if text[index] != '{':
                require(text[index] != '}', f'unmatched closing brace in ICU message: {message!r}')
                index += 1
                continue
            selector = re.match(r'\{\s*([A-Za-z_]\w*)\s*,\s*(plural|select|selectordinal)\s*,', text[index:])
            if selector is not None:
                variable, kind = selector.groups()
                variables.add(variable)
                index += selector.end()
                choices = []
                while index < len(text) and text[index] != '}':
                    branch = re.match(r'\s*(=\d+|[A-Za-z_]\w*)\s*\{', text[index:])
                    require(branch is not None,
                            f'invalid ICU {kind} choice for {variable!r} in message: {message!r}')
                    choices.append(branch.group(1))
                    index += branch.end()
                    start = index
                    depth = 1
                    while index < len(text) and depth:
                        if text[index] == '{':
                            depth += 1
                        elif text[index] == '}':
                            depth -= 1
                        index += 1
                    require(depth == 0, f'unclosed ICU choice for {variable!r} in message: {message!r}')
                    parse_text(text[start:index - 1])
                require(index < len(text), f'unclosed ICU {kind} selector for {variable!r}: {message!r}')
                require(choices and 'other' in choices,
                        f'ICU {kind} selector for {variable!r} needs an other choice: {message!r}')
                selectors.append((variable, kind, tuple(sorted(choices))))
                index += 1
                continue
            placeholder = re.match(r'\{\s*([A-Za-z_]\w*)\s*\}', text[index:])
            if placeholder is not None:
                variables.add(placeholder.group(1))
                index += placeholder.end()
                continue
            raise ValueError(f'invalid ICU placeholder or selector in message: {message!r}')

    parse_text(message)
    return variables, tuple(sorted(selectors))


def check_arb(root):
    en_path = root / 'lib/l10n/app_en.arb'
    hi_path = root / 'lib/l10n/app_hi.arb'
    en = load_json(en_path)
    hi = load_json(hi_path)
    require(hi.get('@@locale') == 'hi', 'app_hi.arb: @@locale must be "hi"')
    require(message_keys(en) == message_keys(hi),
            f'app_hi.arb keys differ: missing={sorted(message_keys(en) - message_keys(hi))}, '
            f'extra={sorted(message_keys(hi) - message_keys(en))}')
    untranslated = re.compile(r'\b(?:' + '|'.join(UNTRANSLATED_UI_TOKENS) + r')\b')
    placeholders = re.compile(r'\{\s*([A-Za-z_]\w*)\s*\}')
    paths = re.compile(r'(?<![A-Za-z0-9])(?:[A-Za-z0-9_.-]+/)+[A-Za-z0-9_.-]+')
    for key in sorted(message_keys(en)):
        require(isinstance(hi[key], str) and hi[key].strip(), f'app_hi.arb: {key} must be a non-empty string')
        placeholder_names = en.get(f'@{key}', {}).get('placeholders', {})
        visible_text = paths.sub('', placeholders.sub(
            lambda match: '' if match.group(1) in placeholder_names else match.group(0), hi[key]))
        match = untranslated.search(visible_text)
        require(match is None,
                f'app_hi.arb: {key} contains untranslated English UI text {match.group(0)!r}' if match else '')
        if hi[key] == en[key]:
            require(UNCHANGED_ENGLISH.get(key) == en[key],
                    f'app_hi.arb: {key} is unchanged English without an exact reviewed allowlist entry')
        require(icu_contract(en[key]) == icu_contract(hi[key]),
                f'app_hi.arb: {key} changes ICU variables or selectors: '
                f'{icu_contract(en[key])} != {icu_contract(hi[key])}')
        metadata_key = f'@{key}'
        require(hi.get(metadata_key) == en.get(metadata_key),
                f'app_hi.arb: {metadata_key} metadata must match English exactly')
    require({key for key in hi if key.startswith('@') and not key.startswith('@@')} ==
            {f'@{key}' for key in message_keys(en) if f'@{key}' in en},
            'app_hi.arb metadata keys differ from English')
    print(f'ARB passed: {len(message_keys(en))} Hindi messages match English metadata and ICU contracts.')


def read_android(path):
    root = ET.parse(path).getroot()
    return {node.attrib['name']: (node.text or '') for node in root.findall('string')}


def check_android(root):
    en = read_android(root / 'android/app/src/main/res/values/strings.xml')
    hi = read_android(root / 'android/app/src/main/res/values-hi/strings.xml')
    require(en.keys() == hi.keys(),
            f'Android Hindi resource keys differ: missing={sorted(en.keys() - hi.keys())}, '
            f'extra={sorted(hi.keys() - en.keys())}')
    parameter_pattern = re.compile(r'%(?:\d+\$)?[sdif]')
    for key in sorted(en):
        expected = sorted(parameter_pattern.findall(en[key]))
        actual = sorted(parameter_pattern.findall(hi[key]))
        require(expected == actual, f'Android {key}: format parameters {actual} != {expected}')
    print(f'Android passed: {len(en)} resource keys and format parameters match.')


def ios_strings_keys(path):
    content = path.read_text(encoding='utf-8')
    return set(re.findall(r'^\s*"((?:[^"\\]|\\.)+)"\s*=', content, re.MULTILINE))


def check_ios(root):
    plist_path = root / 'ios/Runner/Info.plist'
    with plist_path.open('rb') as source:
        plist = plistlib.load(source)
    permissions = {key for key in plist if key.startswith('NS') and key.endswith('UsageDescription')}
    require(bool(permissions), 'Info.plist has no registered iOS usage permissions')
    for locale in ('en', 'hi'):
        path = root / f'ios/Runner/{locale}.lproj/InfoPlist.strings'
        found = ios_strings_keys(path)
        require(found == permissions,
                f'{locale}.lproj/InfoPlist.strings permission keys differ: '
                f'missing={sorted(permissions - found)}, extra={sorted(found - permissions)}')
    print(f'iOS passed: {len(permissions)} permission descriptions are registered in English and Hindi.')

    project = (root / 'ios/Runner.xcodeproj/project.pbxproj').read_text(encoding='utf-8')
    known_regions = re.search(r'knownRegions\s*=\s*\((.*?)\);', project, re.DOTALL)
    require(known_regions is not None and re.search(r'(?m)^\s*hi\s*,?\s*$', known_regions.group(1)),
            'Runner.xcodeproj knownRegions must register hi')

    catalog_path = root / 'ios/Runner/Localizable.xcstrings'
    catalog = load_json(catalog_path)
    strings = catalog.get('strings', {})
    require(bool(strings), 'Localizable.xcstrings has no native keys')
    parameter_pattern = re.compile(r'%(?:\d+\$)?[@sdif]')
    for key, entry in strings.items():
        localizations = entry.get('localizations', {})
        require('en' in localizations and 'hi' in localizations,
                f'Localizable.xcstrings: {key!r} needs English and Hindi variants')
        english = localizations['en'].get('stringUnit', {}).get('value', '')
        hindi = localizations['hi'].get('stringUnit', {}).get('value', '')
        require(bool(english.strip()) and bool(hindi.strip()),
                f'Localizable.xcstrings: {key!r} has an empty localization')
        expected = sorted(parameter_pattern.findall(english))
        actual = sorted(parameter_pattern.findall(hindi))
        require(expected == actual,
                f'Localizable.xcstrings {key!r}: parameters {actual} != {expected}')
    print(f'iOS string catalog passed: {len(strings)} keys have Hindi variants and matching parameters.')


def main():
    root = Path(__file__).resolve().parent.parent
    check_arb(root)
    check_android(root)
    check_ios(root)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, ET.ParseError, plistlib.InvalidFileException, KeyError) as error:
        print(f'Hindi localization check failed: {error}', file=sys.stderr)
        sys.exit(1)
