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


def run(info=None, version=None, play=None, captions=None):
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        (root / 'app-store/app-info').mkdir(parents=True)
        (root / 'app-store/version/3.18.0').mkdir(parents=True)
        (root / 'app-store/version/3.8.0').mkdir(parents=True)
        (root / 'app-store/app-info/en-US.json').write_text(json.dumps({**INFO, **(info or {})}))
        (root / 'app-store/version/3.18.0/en-US.json').write_text(json.dumps({**VERSION, **(version or {})}))
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

    def test_spaces_around_commas_fail(self):
        self.assertIn('spaces around commas', run(version={'keywords': 'amoled, anime'})[1])

    def test_competitor_names_and_placeholders_fail(self):
        code, err = run(version={'keywords': 'amoled,zedge'}, play={'full_description': 'Get {count} walls'},
                        captions={'app-store': [{'file': 'iphone-1', 'headline': 'Better than Walli'}]})
        self.assertEqual(code, 1)
        self.assertIn('keywords names a competitor: zedge', err)
        self.assertIn("full_description has a placeholder: '{count}'", err)
        self.assertIn('headline names a competitor: walli', err)

    def test_long_caption_fails(self):
        code, err = run(captions={'app-store': [{'file': 'iphone-1', 'headline': 'h' * 31, 'subline': 's'}]})
        self.assertEqual(code, 1)
        self.assertIn('headline is 31 characters, limit 30', err)


if __name__ == '__main__':
    unittest.main()
