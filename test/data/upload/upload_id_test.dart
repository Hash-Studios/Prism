import 'dart:math';

import 'package:Prism/data/upload/upload_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new wall ids are ten characters long', () {
    expect(uploadIdLength, 10);
  });

  test('an id has the requested length, capitals and digits only, and exactly one digit', () {
    final Random random = Random(7);
    for (int i = 0; i < 200; i++) {
      final String id = randomUploadId(uploadIdLength, random: random);
      expect(id, hasLength(10));
      expect(id, matches(RegExp(r'^[A-Z0-9]+$')));
      expect(RegExp(r'\d').allMatches(id), hasLength(1));
    }
  });

  test('ids do not repeat in a large sample', () {
    final Random random = Random(11);
    final Set<String> ids = <String>{for (int i = 0; i < 5000; i++) randomUploadId(uploadIdLength, random: random)};
    expect(ids, hasLength(5000));
  });
}
