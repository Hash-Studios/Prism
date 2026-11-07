import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('download button uses shared typography instead of raw text styles', () {
    final source = File('lib/features/ads/views/widgets/download_button.dart').readAsStringSync();
    expect(RegExp(r'\bTextStyle\s*\(').hasMatch(source), isFalse);
  });
}
