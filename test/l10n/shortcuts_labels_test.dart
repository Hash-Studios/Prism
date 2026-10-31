import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the manual shortcut step names the action and source the way iOS shows them in each language', () {
    final Map<String, dynamic> strings =
        (jsonDecode(File('ios/Runner/Localizable.xcstrings').readAsStringSync()) as Map<String, dynamic>)['strings']
            as Map<String, dynamic>;
    String ios(String key, String locale) =>
        ((((strings[key] as Map<String, dynamic>)['localizations'] as Map<String, dynamic>)[locale]
                    as Map<String, dynamic>)['stringUnit']
                as Map<String, dynamic>)['value']
            as String;
    const Map<String, String> arbToIos = <String, String>{
      'en': 'en',
      'de': 'de',
      'es': 'es',
      'hi': 'hi',
      'id': 'id',
      'pt': 'pt-BR',
      'pt_BR': 'pt-BR',
    };
    for (final MapEntry<String, String>(key: String arb, value: String locale) in arbToIos.entries) {
      final Map<String, dynamic> catalog =
          jsonDecode(File('lib/l10n/app_$arb.arb').readAsStringSync()) as Map<String, dynamic>;
      final String step = catalog['shortcutsManualGet'] as String;
      for (final String key in <String>['Get Prism Wallpaper', 'Source', 'Rotation folder']) {
        expect(step, contains(ios(key, locale)), reason: '$arb shortcutsManualGet must use the iOS "$key" label');
      }
    }
  });
}
