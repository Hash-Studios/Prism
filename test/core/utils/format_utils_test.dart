import 'package:Prism/core/utils/format_utils.dart';
import 'package:Prism/core/utils/theme_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatCompactCount', () {
    expect(formatCompactCount(999), '999');
    expect(formatCompactCount(1234), '1.2K');
    expect(formatCompactCount(12345), '12K');
    expect(formatCompactCount(1234567), '1.2M');
  });

  test('formatMegabytes', () => expect(formatMegabytes(2450000), '2.45 MB'));

  test('rgbHex drops alpha and pads', () {
    expect(const Color(0xFFE57697).rgbHex, 'e57697');
    expect(const Color(0x80000A0B).rgbHex, '000a0b');
  });
}
