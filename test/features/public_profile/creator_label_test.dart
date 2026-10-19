import 'package:Prism/features/public_profile/domain/creator_label.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final String fallback = AppLocalizationsEn().accountCreatorFallback;

  test('uses the name first, then the username', () {
    expect(creatorLabel(name: 'Ana', username: 'ana_w', fallback: fallback), 'Ana');
    expect(creatorLabel(name: '  ', username: 'ana_w', fallback: fallback), 'ana_w');
  });

  test('never returns an email address', () {
    expect(creatorLabel(name: 'ana@example.com', username: 'ana_w', fallback: fallback), 'ana_w');
    expect(creatorLabel(name: 'ana@example.com', username: 'a@b.co', fallback: fallback), fallback);
  });

  test('falls back to Prism creator when nothing is set', () {
    expect(creatorLabel(name: '', username: '', fallback: fallback), fallback);
  });
}
