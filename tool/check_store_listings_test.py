"""Fixtures for tool/check_store_listings.py. No network."""

import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest

from tool import check_store_listings

INFO = {'name': 'Prism: AI & 4K Wallpapers', 'subtitle': 'Widgets and lock screen'}
VERSION = {'description': 'Todo en un lugar.', 'keywords': 'amoled,backgrounds,anime', 'promotionalText': 'New.',
           'whatsNew': 'Folders.'}
PLAY = {'title': 'Prism: AI & 4K Wallpapers', 'short_description': 'Walls.', 'full_description': 'Walls.'}


def run(info=None, version=None, play=None, captions=None, omit=()):
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        (root / 'app-store/app-info').mkdir(parents=True)
        (root / 'app-store/version/3.18.0').mkdir(parents=True)
        (root / 'app-store/version/3.8.0').mkdir(parents=True)
        info_data = {**INFO, **(info or {})}
        version_data = {**VERSION, **(version or {})}
        for section, field in omit:
            {'info': info_data, 'version': version_data}[section].pop(field)
        (root / 'app-store/app-info/en-US.json').write_text(json.dumps(info_data))
        (root / 'app-store/version/3.18.0/en-US.json').write_text(json.dumps(version_data))
        (root / 'app-store/version/3.8.0/en-US.json').write_text(json.dumps({'keywords': 'wallpaper,' * 30}))
        (root / 'play/en-US').mkdir(parents=True)
        for field, text in {**PLAY, **(play or {})}.items():
            (root / f'play/en-US/{field}.txt').write_text(text + '\n')
        (root / 'screenshot-captions').mkdir()
        (root / 'screenshot-captions/en-US.json').write_text(
            json.dumps({'play': [{'file': 'play-1', 'headline': 'Find your vibe', 'subline': 'Walls.'}],
                        **(captions or {})}))
        err = io.StringIO()
        with contextlib.redirect_stderr(err), contextlib.redirect_stdout(io.StringIO()):
            code = check_store_listings.main(['check', str(root)])
        return code, err.getvalue()


class CheckStoreListingsTest(unittest.TestCase):
    def test_valid_listing_passes_and_only_the_latest_version_is_checked(self):
        self.assertEqual(run(), (0, ''))

    def test_over_limit_fields_fail(self):
        code, err = run(info={'subtitle': 'x' * 31}, play={'short_description': 'y' * 81})
        self.assertEqual(code, 1)
        self.assertIn('subtitle is 31 characters, limit 30', err)
        self.assertIn('short_description is 81 characters, limit 80', err)

    def test_keyword_repeating_a_name_word_or_another_keyword_fails(self):
        code, err = run(version={'keywords': 'wallpaper,anime,anime girl'})
        self.assertEqual(code, 1)
        self.assertIn("keyword word 'wallpaper' repeats a word already in the name or subtitle", err)
        self.assertIn("keyword word 'anime' repeats a word already in the keywords", err)

    def test_devanagari_words_stay_whole(self):
        self.assertEqual(run(info={'subtitle': 'लॉक स्क्रीन विजेट'}, version={'keywords': 'स्क्रीनशॉट,लॉकर'}), (0, ''))
        self.assertIn("'स्क्रीन' repeats", run(info={'subtitle': 'लॉक स्क्रीन'}, version={'keywords': 'स्क्रीन'})[1])

    def test_devanagari_nukta_spellings_are_canonically_equivalent(self):
        # U+0958 (क़) and U+0915 U+093C (क़) are the same written letter.
        self.assertIn("'क़' repeats", run(info={'subtitle': 'क़'}, version={'keywords': 'क़'})[1])

    def test_competitor_names_are_detected_next_to_unicode_punctuation(self):
        variants = ("Zedge's", 'Walli’s', '“Zedge”', '[Wallcraft]', 'Zedge—wallpaper')
        for variant in variants:
            with self.subTest(variant=variant):
                self.assertIn('names a competitor', run(play={'full_description': variant})[1])

    def test_keyword_repetition_is_detected_inside_quotes(self):
        code, err = run(info={'subtitle': '“amoled”'}, version={'keywords': 'amoled'})
        self.assertEqual(code, 1)
        self.assertIn("keyword word 'amoled' repeats a word already in the name or subtitle", err)

    def test_every_text_limit_accepts_exact_and_rejects_over_limit(self):
        field_inputs = {
            'name': ('info', 'name', 30),
            'subtitle': ('info', 'subtitle', 30),
            'keywords': ('version', 'keywords', 100),
            'promotionalText': ('version', 'promotionalText', 170),
            'description': ('version', 'description', 4000),
            'whatsNew': ('version', 'whatsNew', 4000),
            'title': ('play', 'title', 30),
            'short_description': ('play', 'short_description', 80),
            'full_description': ('play', 'full_description', 4000),
        }
        for field, (section, key, limit) in field_inputs.items():
            with self.subTest(field=field, length='exact'):
                kwargs = {section: {key: 'x' * limit}}
                self.assertEqual(run(**kwargs), (0, ''))
            with self.subTest(field=field, length='over'):
                kwargs = {section: {key: 'x' * (limit + 1)}}
                code, err = run(**kwargs)
                self.assertEqual(code, 1)
                self.assertIn(f'{field} is {limit + 1} characters, limit {limit}', err)
        for field, limit in (('headline', 30), ('subline', 60)):
            for length in (limit, limit + 1):
                with self.subTest(field=field, length=length):
                    caption = {'file': 'iphone-1', 'headline': 'Short', 'subline': 'Short'}
                    caption[field] = 'x' * length
                    code, err = run(captions={'app-store': [caption]})
                    if length == limit:
                        self.assertEqual((code, err), (0, ''))
                    else:
                        self.assertEqual(code, 1)
                        self.assertIn(f'{field} is {limit + 1} characters, limit {limit}', err)

    def test_plural_singular_keyword_stem_matches_and_spanish_todo_is_not_a_placeholder(self):
        code, err = run(info={'subtitle': 'Fondos todo el día'}, version={'keywords': 'fondo'})
        self.assertEqual(code, 1)
        self.assertIn("keyword word 'fondo' repeats", err)
        self.assertNotIn('placeholder', err)

    def test_reviewed_german_and_portuguese_plurals_repeat_singular_keywords(self):
        self.assertIn('keyword word \'hintergründe\' repeats',
                      run(info={'subtitle': 'Hintergrund'}, version={'keywords': 'hintergründe'})[1])
        self.assertIn('keyword word \'papéis\' repeats',
                      run(info={'name': 'Papel de parede'}, version={'keywords': 'papéis'})[1])

    def test_distinct_hindi_terms_and_spanish_todo_are_not_false_positives(self):
        self.assertEqual(run(info={'subtitle': 'लॉक स्क्रीन विजेट'},
                             version={'keywords': 'स्क्रीनशॉट,लॉकर'}), (0, ''))
        self.assertEqual(run(info={'subtitle': 'Todo el día'}, version={'keywords': 'fondos,amoled'}), (0, ''))

    def test_spaces_around_commas_fail(self):
        self.assertIn('spaces around commas', run(version={'keywords': 'amoled, anime'})[1])

    def test_competitor_names_and_placeholders_fail(self):
        code, err = run(version={'keywords': 'amoled,zedge'}, play={'full_description': 'Get {count} walls'},
                        captions={'app-store': [{'file': 'iphone-1', 'headline': 'Better than Walli'}]})
        self.assertEqual(code, 1)
        self.assertIn('keywords names a competitor: zedge', err)
        self.assertIn("full_description has a placeholder: '{count}'", err)
        self.assertIn('headline names a competitor: walli', err)

    def test_policy_checks_cover_unlimited_app_store_text_fields(self):
        code, err = run(version={'supportUrl': 'https://zedge.example/{locale}'})
        self.assertEqual(code, 1)
        self.assertIn('supportUrl names a competitor: zedge', err)
        self.assertIn("supportUrl has a placeholder: '{locale}'", err)

    def test_long_caption_fails(self):
        code, err = run(captions={'app-store': [{'file': 'iphone-1', 'headline': 'h' * 31, 'subline': 's'}]})
        self.assertEqual(code, 1)
        self.assertIn('headline is 31 characters, limit 30', err)

    def test_required_fields_cannot_be_missing_or_empty(self):
        code, err = run(info={'name': ''}, version={'whatsNew': ''}, play={'short_description': ''})
        self.assertEqual(code, 1)
        self.assertIn('name is empty', err)
        self.assertIn('whatsNew is empty', err)
        self.assertIn('short_description is empty', err)

        code, err = run(omit=(('info', 'name'), ('version', 'description'), ('version', 'keywords'),
                              ('version', 'whatsNew')))
        self.assertEqual(code, 1)
        for field in ('name', 'description', 'keywords', 'whatsNew'):
            self.assertIn(f'missing required field {field}', err)

        code, err = run(info={'subtitle': None})
        self.assertEqual(code, 1)
        self.assertIn('subtitle must be a non-empty string', err)

    def test_optional_app_store_subtitle_and_promotional_text_may_be_omitted(self):
        self.assertEqual(run(omit=(('info', 'subtitle'), ('version', 'promotionalText'))), (0, ''))
        self.assertEqual(run(info={'subtitle': ''}, version={'promotionalText': ''}), (0, ''))

        code, err = run(info={'subtitle': ' ' * 31}, version={'promotionalText': ' ' * 171})
        self.assertEqual(code, 1)
        self.assertIn('subtitle is 31 characters, limit 30', err)
        self.assertIn('promotionalText is 171 characters, limit 170', err)

    def test_malformed_json_and_missing_caption_fields_fail_cleanly(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'app-store/app-info').mkdir(parents=True)
            (root / 'app-store/version/3.18.0').mkdir(parents=True)
            (root / 'app-store/app-info/en-US.json').write_text('{not json')
            (root / 'app-store/version/3.18.0/en-US.json').write_text(json.dumps(VERSION))
            (root / 'play/en-US').mkdir(parents=True)
            for field, text in PLAY.items():
                (root / f'play/en-US/{field}.txt').write_text(text)
            (root / 'screenshot-captions').mkdir()
            (root / 'screenshot-captions/en-US.json').write_text(json.dumps({'play': [{'file': 'play-1'}]}))
            err = io.StringIO()
            with contextlib.redirect_stderr(err), contextlib.redirect_stdout(io.StringIO()):
                code = check_store_listings.main(['check', str(root)])
            self.assertEqual(code, 1)
            self.assertIn('invalid JSON', err.getvalue())
            self.assertIn('headline must be a non-empty string', err.getvalue())

    def test_empty_store_roots_fail_instead_of_reporting_zero_locales(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for path in ('app-store/app-info', 'app-store/version/3.18.0', 'play', 'screenshot-captions'):
                (root / path).mkdir(parents=True)
            err = io.StringIO()
            with contextlib.redirect_stderr(err), contextlib.redirect_stdout(io.StringIO()):
                code = check_store_listings.main(['check', str(root)])
            self.assertEqual(code, 1)
            self.assertIn('no App Store locale files', err.getvalue())
            self.assertIn('no Play locales', err.getvalue())
            self.assertIn('no screenshot caption files', err.getvalue())

    def test_caption_files_with_empty_store_lists_fail(self):
        code, err = run(captions={'play': [], 'app-store': []})
        self.assertEqual(code, 1)
        self.assertIn('play captions must not be empty', err)
        self.assertIn('app-store captions must not be empty', err)


if __name__ == '__main__':
    unittest.main()
