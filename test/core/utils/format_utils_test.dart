import 'package:Prism/core/utils/format_utils.dart';
import 'package:Prism/core/utils/theme_utils.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatMegabytes uses localized labels and numeric formatting', () {
    expect(formatMegabytes(2450000, AppLocalizationsEn()), '2.45 MB');
  });

  test('rgbHex drops alpha and pads', () {
    expect(const Color(0xFFE57697).rgbHex, 'e57697');
    expect(const Color(0x80000A0B).rgbHex, '000a0b');
  });
}
