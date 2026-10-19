import 'package:Prism/data/categories/category_definition.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog aliases use localized category labels while unknown names stay intact', () {
    final AppLocalizations l10n = AppLocalizationsEn();

    expect(categoryDisplayName('Gradients', l10n), l10n.coreCategoryGradient);
    expect(categoryDisplayName('3D Renders', l10n), l10n.coreCategoryRender3d);
    expect(categoryDisplayName('Remote custom interest', l10n), 'Remote custom interest');
  });
}
