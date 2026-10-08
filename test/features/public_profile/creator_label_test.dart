import 'package:Prism/features/public_profile/domain/creator_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the name first, then the username', () {
    expect(creatorLabel(name: 'Ana', username: 'ana_w'), 'Ana');
    expect(creatorLabel(name: '  ', username: 'ana_w'), 'ana_w');
  });

  test('never returns an email address', () {
    expect(creatorLabel(name: 'ana@example.com', username: 'ana_w'), 'ana_w');
    expect(creatorLabel(name: 'ana@example.com', username: 'a@b.co'), fallbackCreatorLabel);
  });

  test('falls back to Prism creator when nothing is set', () {
    expect(creatorLabel(), 'Prism creator');
  });
}
