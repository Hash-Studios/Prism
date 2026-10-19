import unittest
from collections import Counter

from tool.check_indonesian_l10n import CheckFailure, printf_contract


class IosStringsTests(unittest.TestCase):
    def test_equals_and_comment_markers_in_values_are_not_structure(self):
        self.assertEqual(
            ios_strings_from_text('/* "ignored" = "pair"; */\n"key" = "https://x/y?a=b // ok";'),
            {'key': 'https://x/y?a=b // ok'},
        )

    def test_rejects_trailing_junk_and_unterminated_comment(self):
        for text in ('"key" = "value"; junk', '/* never closed', '"key" = "unterminated'):
            with self.subTest(text=text), self.assertRaises(CheckFailure):
                ios_strings_from_text(text)

    def test_comment_only_entry_does_not_count(self):
        self.assertEqual(ios_strings_from_text('/* "key" = "value"; */'), {})

    def test_rejects_duplicate_entries(self):
        with self.assertRaises(CheckFailure):
            ios_strings_from_text('"key" = "one"; "key" = "two";')

    def test_escaped_quotes_and_backslashes_stay_inside_values(self):
        self.assertEqual(
            ios_strings_from_text(r'"key\"part" = "a quoted: \\\" and slash: \\\\";'),
            {r'key\"part': r'a quoted: \\\" and slash: \\\\'},
        )


def ios_strings_from_text(text):
    from tool.check_indonesian_l10n import parse_ios_strings
    return parse_ios_strings(text)


class PrintfContractTests(unittest.TestCase):
    def test_platform_contracts_preserve_argument_order_and_repetition(self):
        self.assertNotEqual(printf_contract('%s %d', 'android'), printf_contract('%d %s', 'android'))
        self.assertNotEqual(printf_contract('%s %d', 'android'), printf_contract('%d %d', 'android'))
        self.assertNotEqual(printf_contract('%s %s', 'android'), printf_contract('%s', 'android'))

    def test_explicit_reordering_and_escaped_percent(self):
        self.assertEqual(printf_contract('%1$s %2$d', 'android'), printf_contract('%2$d %1$s', 'android'))
        self.assertEqual(printf_contract('%%', 'android'), printf_contract('', 'android'))
        self.assertEqual(printf_contract('https://x/y', 'android'), printf_contract('', 'android'))

    def test_android_explicit_and_implicit_indexes_are_independent(self):
        self.assertEqual(
            printf_contract('%2$s %s', 'android'),
            printf_contract('%2$s %1$s', 'android'),
        )
        self.assertNotEqual(
            printf_contract('%2$s', 'android'),
            printf_contract('%2$s %s', 'android'),
        )

    def test_ios_length_modifiers_are_distinct(self):
        self.assertNotEqual(printf_contract('%lld', 'ios'), printf_contract('%d', 'ios'))

    def test_explicit_arguments_reorder_but_usage_and_types_must_match(self):
        self.assertNotEqual(printf_contract('%1$s', 'ios'), printf_contract('%1$s %s', 'ios'))
        self.assertNotEqual(printf_contract('%s %d', 'ios'), printf_contract('%d %s', 'ios'))
        self.assertEqual(printf_contract('%1$s %2$d', 'ios'), printf_contract('%2$d %1$s', 'ios'))

    def test_android_date_and_relative_argument_contracts(self):
        self.assertNotEqual(printf_contract('%1$tF', 'android'), printf_contract('%1$F', 'android'))
        contract = printf_contract('%1$s %<s', 'android')
        self.assertEqual(contract, Counter({(1, 's'): 2}))
        self.assertNotEqual(printf_contract('%1$s %<s', 'android'), printf_contract('%1$s %<d', 'android'))

    def test_non_consuming_formats_do_not_add_arguments(self):
        self.assertEqual(printf_contract('%% %n', 'android'), printf_contract('', 'android'))
        self.assertEqual(printf_contract('%% https://x/y', 'ios'), printf_contract('', 'ios'))

    def test_ios_dynamic_width_is_rejected(self):
        for value in ('%*s', '%.*s', '%1$*2$s', '%10.*s', '%1$10.*s', '%010.*s'):
            with self.subTest(value=value), self.assertRaises(CheckFailure):
                printf_contract(value, 'ios')

    def test_ios_constant_precision_with_width_is_supported(self):
        self.assertEqual(printf_contract('%10.2f', 'ios'), Counter({(1, 'f', '', '', '10', '2'): 1}))


if __name__ == '__main__':
    unittest.main()
