#!/usr/bin/env python3
"""Check German localization parity across Flutter and native resources."""
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


# Exact English/German matches that are valid as written. Keep entries keyed by
# message ID: a general same-English exception would hide untranslated copy.
UNCHANGED_ENGLISH_ALLOWLIST = {
    # Product, platform, and service names.
    'appTitle': 'Prism',
    'accountAppName': 'Prism Wallpapers',
    'wallpaperLiveStyleDepth': '3D',
    'accountPrismPro': 'Prism Pro',
    'accountProBadge': 'Pro',
    'premiumPageTitle': 'Prism Premium',
    'wallpaperHomeAppName': 'Prism',
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
    'accountSocialGithub': 'GITHUB',
    'accountSocialInstagram': 'INSTAGRAM',
    'accountSocialTelegram': 'TELEGRAM',
    'accountSocialTwitter': 'TWITTER',
    'coreContributorGithub': 'GitHub',
    'coreContributorTwitter': 'Twitter',
    'coreContributorWebsite': 'Website',
    'economyDropWatermarkLabel': 'PRISM DROP',

    # Standard German loanwords, labels, and technical terms.
    'accountAdmin': 'Admin',
    'accountFeedback': 'FEEDBACK',
    'accountLink': 'Link',
    'accountShop': 'Shop',
    'accountTop': 'Top',
    'accountVersionLabel': 'Version {version}',
    'adminDrop': 'Drop',
    'adminEmailExample': 'user@example.com',
    'adminWallId': 'ID',
    'coreBio': 'Bio',
    'coreCategoryAnime': 'Anime',
    'coreCategoryComic': 'Comic',
    'coreCategoryCyberpunk': 'Cyberpunk',
    'coreCategoryFantasy': 'Fantasy',
    'coreCategoryGaming': 'Gaming',
    'coreCategoryIllustration': 'Illustration',
    'coreCategoryKawaii': 'Kawaii',
    'coreCategoryNeon': 'Neon',
    'coreCategoryVintage': 'Vintage',
    'coreCoinBoost': 'Boost',
    'coreCoinCoins': 'Coins',
    'coreCoinQuest': 'Quest',
    'coreCoinShop': 'Shop',
    'coreColorOrange': 'Orange',
    'coreColorPink': 'Pink',
    'coreName': 'Name',
    'corePairPickerDownloads': 'Downloads',
    'coreReportDetailsOptional': 'Details (optional)',
    'coreThemeAmoled': 'AMOLED',
    'coreThemeOlive': 'Olive',
    'coreThemeRose': 'Rose',
    'debugCoins': 'Coins',
    'debugHardware': 'Hardware',
    'debugLevel': 'Level',
    'debugName': 'Name',
    'debugRemoteConfig': 'Remote Config',
    'debugTitle': 'Debug',
    'debugVersion': 'Version',
    'economyAiStyleAnime': 'Anime',
    'economyAiStyleCyberpunk': 'Cyberpunk',
    'economyAiStylePixelArt': 'Pixel Art',
    'economyAiStyleSynthwave': 'Synthwave',
    'economyAiStyleUkiyoE': 'Ukiyo-e',
    'economyBadgeCreator': 'Creator',
    'economyBoost': 'Boost',
    'economyDownloads': 'Downloads',
    'economyDropTitle': 'Drop',
    'economyDrops': 'Drops',
    'economyLeaderboardGlobal': 'Global',
    'economyPro': 'Pro',
    'economyRankBronze': 'Bronze',
    'economyRankGold': 'Gold',
    'economyRankPrism': 'Prism',
    'economyShopAurora': 'Aurora',
    'economyShopGold': 'Gold',
    'economyShopMono': 'Mono',
    'economyShopNoir': 'Noir',
    'economyShopPrism': 'Prism',
    'economyShopRing': 'Ring',
    'economyShopRose': 'Rose',
    'economyShopTitle': 'Shop',
    'economyXpUnit': 'XP',
    'notifChannelDownloads': 'Downloads',
    'notifChannelDraw': 'Prism Draw',
    'notifChannelModeration': 'Moderation',
    'onboardingPro': 'Pro',
    'wallpaperAutoRotateSourceDownloads': 'Downloads',
    'wallpaperAutoRotateStatusLabel': 'Status',
    'wallpaperDownloadSortName': 'Name',
    'wallpaperDownloadsTitle': 'Downloads',
    'wallpaperLive': 'Live',
    'wallpaperLiveModeVideo': 'Video',
    'wallpaperLiveStyleAurora': 'Aurora',
    'wallpaperLiveStylePlasma': 'Plasma',
    'wallpaperOffline': 'Offline',
    'wallpaperPositionTitle': 'Position',
    'wallpaperPremium': 'Premium',
    'wallpaperFilterOriginal': 'Original',
    'wallpaperLibraryDownloads': 'Downloads',
    'wallpaperUploadTags': 'Tags',

    # Values composed only of named runtime placeholders and/or symbols.
    'accountProfilePersonSemantics': '{name}, @{username}',
    'accountResolution1080': '1080p',
    'accountResolution1440': '1440p',
    'accountResolution4k': '4K',
    'accountStorageSizeBytes': '{size} B',
    'accountStorageSizeGigabytes': '{size} GB',
    'accountStorageSizeKilobytes': '{size} KB',
    'accountStorageSizeMegabytes': '{size} MB',
    'adminFactLabel': '{label}: {value}',
    'adminReviewProgress': '{current}/{total}',
    'coreCoinBalanceChange': '{balance}, {change}',
    'coreFileSizeMegabytes': '{size} MB',
    'coreWallpaperSavedWithTip': '{saved} {tip}',
    'debugBackendName': 'Backend: {backend}',
    'economyBadgeSemantics': '{name}, {status}. {description}',
    'economyChestBoosterSemantics': '{title}. {caption}',
    'economyCollectionItemSemantics': '{category}, {status}. {caption}',
    'economyCreatorMilestoneProgress': '{label}: {current} / {target}',
    'economyCreatorWeekRange': '{start} – {end} UTC',
    'economyDownloadCost': '{label} · {cost}',
    'economyAiPromptSceneOnly': '{scene}, {suffix}',
    'economyOddsTierSemantics': '{tier}, {odds}',
    'economyRankRewardMilestone': '{rank} · {xp} XP\n{reward}',
    'economyShopItemSemantics': '{name}, {status}',
    'economySpendItemSemantics': '{label}, {price}',
    'economyXp': '{count} XP',
    'economyXpAwarded': '+{xp} XP',
    'notifGroupCountAction': '{count} {label} · {action}',
    'notifGroupSemantics': '{title}. {summary}. {expandedState}. {unreadStatus} {action}',
    'notifPushWotdAudienceBody': '{wallTitle}',
    'notifSemanticsRow': '{message}. {time}. {readStatus}',
    'wallpaperAutoRotateNounCategory': '{category}',
    'wallpaperUploadDetailsOptional': 'Details (optional)',
}


def read_json(path):
    def unique_object(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f'{path.name}: duplicate key {key}')
            result[key] = value
        return result

    return json.loads(path.read_text(encoding='utf-8'), object_pairs_hook=unique_object)


def arb_placeholders(value, declared):
    # Only metadata-declared names count. ICU selector values and words in
    # branch bodies also use braces, so parsing them as arguments is unsafe.
    return sorted(name for name in declared if re.search(r'\{' + re.escape(name) + r'(?:\s*,|\})', value))


def format_placeholders(value):
    return sorted(set(re.findall(r'(%\d+\$[s@d])', value)))


def check():
    root = Path(__file__).resolve().parent.parent
    errors = []

    en_path = root / 'lib/l10n/app_en.arb'
    de_path = root / 'lib/l10n/app_de.arb'
    en_arb = read_json(en_path)
    de_arb = read_json(de_path)
    en_keys = {key for key in en_arb if not key.startswith('@')}
    de_keys = {key for key in de_arb if not key.startswith('@')}
    if de_arb.get('@@locale') != 'de':
        errors.append('ARB: @@locale must be de')
    if en_keys != de_keys:
        errors.append(f'ARB keys: missing={sorted(en_keys - de_keys)}, extra={sorted(de_keys - en_keys)}')
    en_metadata = {key for key in en_arb if key.startswith('@') and key != '@@locale'}
    de_metadata = {key for key in de_arb if key.startswith('@') and key != '@@locale'}
    if en_metadata != de_metadata:
        errors.append(
            f'ARB metadata: missing={sorted(en_metadata - de_metadata)}, '
            f'extra={sorted(de_metadata - en_metadata)}'
        )
    for key in sorted(en_keys & de_keys):
        en_value, de_value = en_arb[key], de_arb[key]
        expected_names = set(en_arb.get(f'@{key}', {}).get('placeholders', {}))
        actual_names = set(de_arb.get(f'@{key}', {}).get('placeholders', {}))
        if expected_names != actual_names:
            errors.append(f'ARB {key}: placeholder metadata differs: {sorted(expected_names)} vs {sorted(actual_names)}')
        for locale, message, names in (
            ('en', en_value, expected_names), ('de', de_value, expected_names)
        ):
            used_names = set(arb_placeholders(message, names))
            if used_names != names:
                errors.append(f'ARB {key} ({locale}): declared placeholders not used: {sorted(names - used_names)}')
        if en_arb.get(f'@{key}') != de_arb.get(f'@{key}'):
            errors.append(f'ARB {key}: metadata differs from English')
        if en_value == de_value and UNCHANGED_ENGLISH_ALLOWLIST.get(key) != en_value:
            errors.append(f'ARB {key}: meaningful English text is unchanged')

    android_en = root / 'android/app/src/main/res/values/strings.xml'
    android_de = root / 'android/app/src/main/res/values-de/strings.xml'
    en_android = {item.attrib['name']: item.text or '' for item in ET.parse(android_en).getroot()}
    de_android = {item.attrib['name']: item.text or '' for item in ET.parse(android_de).getroot()}
    if set(en_android) != set(de_android):
        errors.append(
            f'Android keys: missing={sorted(set(en_android) - set(de_android))}, '
            f'extra={sorted(set(de_android) - set(en_android))}'
        )
    for key in sorted(set(en_android) & set(de_android)):
        if format_placeholders(en_android[key]) != format_placeholders(de_android[key]):
            errors.append(f'Android {key}: positional placeholders differ')
        if en_android[key] == de_android[key] and key not in {
            'app_name', 'wotd_widget_label', 'notif_push_wotd_for_audience_body', 'notif_push_follow_digest_body'
        }:
            errors.append(f'Android {key}: meaningful English text is unchanged')

    xcstrings_document = read_json(root / 'ios/Runner/Localizable.xcstrings')
    xcstrings = xcstrings_document['strings']
    ios_errors = []
    if xcstrings_document.get('sourceLanguage') != 'en':
        ios_errors.append('source language must be en')
    for key, entry in sorted(xcstrings.items()):
        localizations = entry.get('localizations', {})
        english = localizations.get('en', {}).get('stringUnit', {}).get('value')
        german = localizations.get('de', {}).get('stringUnit', {}).get('value')
        if english is None:
            ios_errors.append(f'{key}: missing English source')
        if german is None:
            ios_errors.append(f'{key}: missing German localization')
            continue
        if english is not None and format_placeholders(english) != format_placeholders(german):
            ios_errors.append(f'{key}: positional placeholders differ')
        if english == german and key not in ('notif_push_wotd_for_audience_body', 'notif_push_follow_digest_body'):
            ios_errors.append(f'{key}: meaningful English text is unchanged')
    errors.extend(f'iOS {error}' for error in ios_errors)

    info_dir = root / 'ios/Runner'
    def parse_strings(path):
        return dict(re.findall(r'^\s*"([^"]+)"\s*=\s*"((?:[^"\\]|\\.)*)";',
                               path.read_text(encoding='utf-8'), re.MULTILINE))

    en_info = parse_strings(info_dir / 'en.lproj/InfoPlist.strings')
    de_info = parse_strings(info_dir / 'de.lproj/InfoPlist.strings')
    if set(en_info) != set(de_info) or len(en_info) != 3:
        errors.append(f'InfoPlist keys: expected exact three-key parity, en={sorted(en_info)}, de={sorted(de_info)}')

    project = (root / 'ios/Runner.xcodeproj/project.pbxproj').read_text(encoding='utf-8')
    if not re.search(r'knownRegions\s*=\s*\([^)]*\bde\b', project, re.DOTALL):
        errors.append('Xcode project: de is not registered in knownRegions')
    if 'de.lproj/InfoPlist.strings' not in project:
        errors.append('Xcode project: German InfoPlist.strings is not referenced')

    if errors:
        print('\n'.join(errors), file=sys.stderr)
        return 1
    print(f'German localization passed: {len(en_keys)} ARB messages, {len(en_android)} Android strings, {len(xcstrings)} iOS strings.')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(check())
    except (KeyError, OSError, ValueError, ET.ParseError) as error:
        print(error, file=sys.stderr)
        sys.exit(1)
