import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String _hex(Color? c) => c == null ? 'null' : c.toARGB32().toRadixString(16).padLeft(8, '0');

String _style(TextStyle? s) =>
    s == null ? 'null' : '${s.fontFamily}/${s.fontSize}/${s.fontWeight?.value}/${_hex(s.color)}';

String describeTheme(ThemeData t) {
  final tt = t.textTheme;
  return [
    t.brightness.name,
    'canvas=${_hex(t.canvasColor)}',
    'primary=${_hex(t.primaryColor)}',
    'focus=${_hex(t.focusColor)}',
    'hint=${_hex(t.hintColor)}',
    'scheme=${_hex(t.colorScheme.primary)}/${_hex(t.colorScheme.secondary)}/${_hex(t.colorScheme.error)}',
    'overlay=${t.appBarTheme.systemOverlayStyle?.statusBarIconBrightness?.name}',
    'labelLarge=${_style(tt.labelLarge)}',
    'headlineSmall=${_style(tt.headlineSmall)}',
    'headlineMedium=${_style(tt.headlineMedium)}',
    'displaySmall=${_style(tt.displaySmall)}',
    'displayMedium=${_style(tt.displayMedium)}',
    'displayLarge=${_style(tt.displayLarge)}',
    'titleMedium=${_style(tt.titleMedium)}',
    'titleLarge=${_style(tt.titleLarge)}',
    'bodyMedium=${_style(tt.bodyMedium)}',
    'bodyLarge=${_style(tt.bodyLarge)}',
    'bodySmall=${_style(tt.bodySmall)}',
  ].join(' ');
}

const _expected = <String, String>{
  'kLightTheme':
      'light canvas=00000000 primary=ffffffff focus=ffffffff hint=ffededed '
      'scheme=ffe57697/ff090909/ffc62828 overlay=dark labelLarge=Proxima Nova/16.0/800/ffffffff '
      'headlineSmall=Proxima Nova/16.0/null/ffffffff headlineMedium=Proxima Nova/16.0/500/ff2f2f2f '
      'displaySmall=Proxima Nova/20.0/500/ff000000 displayMedium=Proxima Nova/24.0/500/ff000000 '
      'displayLarge=Proxima Nova/50.0/600/ff2f2f2f titleMedium=Roboto/20.0/900/ffededed titleLarge=Proxima '
      'Nova/13.0/null/d9ffffff bodyMedium=Proxima Nova/14.0/500/bfffffff bodyLarge=Proxima '
      'Nova/24.0/500/ffffffff bodySmall=Roboto/16.0/400/ff2f2f2f',
  'kLightTheme2':
      'light canvas=00000000 primary=fff7f1e3 focus=ffffffff hint=fff1e6d0 '
      'scheme=ffc19439/ff1e1709/ffc62828 overlay=dark labelLarge=Proxima Nova/16.0/800/ffffffff '
      'headlineSmall=Proxima Nova/16.0/null/ffffffff headlineMedium=Proxima Nova/16.0/500/ff2f2f2f '
      'displaySmall=Proxima Nova/20.0/500/ff000000 displayMedium=Proxima Nova/24.0/500/ff000000 '
      'displayLarge=Proxima Nova/50.0/600/ff2f2f2f titleMedium=Roboto/20.0/900/ffededed titleLarge=Proxima '
      'Nova/13.0/null/d9ffffff bodyMedium=Proxima Nova/14.0/500/bfffffff bodyLarge=Proxima '
      'Nova/24.0/500/ffffffff bodySmall=Roboto/16.0/400/ff2f2f2f',
  'kLightTheme3':
      'light canvas=00000000 primary=ffc5a79f focus=ffffffff hint=ffbe9c93 '
      'scheme=ffa7796d/ff19110f/ffc62828 overlay=dark labelLarge=Proxima Nova/16.0/800/ffffffff '
      'headlineSmall=Proxima Nova/16.0/null/ffffffff headlineMedium=Proxima Nova/16.0/500/ff2f2f2f '
      'displaySmall=Proxima Nova/20.0/500/ff000000 displayMedium=Proxima Nova/24.0/500/ff000000 '
      'displayLarge=Proxima Nova/50.0/600/ff2f2f2f titleMedium=Roboto/20.0/900/ffededed titleLarge=Proxima '
      'Nova/13.0/null/d9ffffff bodyMedium=Proxima Nova/14.0/500/bfffffff bodyLarge=Proxima '
      'Nova/24.0/500/ffffffff bodySmall=Roboto/16.0/400/ff2f2f2f',
  'kLightTheme4':
      'light canvas=00000000 primary=ff8399be focus=ffffffff hint=ff788caf '
      'scheme=ff596f95/ff0b0d12/ffc62828 overlay=dark labelLarge=Proxima Nova/16.0/800/ffffffff '
      'headlineSmall=Proxima Nova/16.0/null/ffffffff headlineMedium=Proxima Nova/16.0/500/ff2f2f2f '
      'displaySmall=Proxima Nova/20.0/500/ff000000 displayMedium=Proxima Nova/24.0/500/ff000000 '
      'displayLarge=Proxima Nova/50.0/600/ff2f2f2f titleMedium=Roboto/20.0/900/ffededed titleLarge=Proxima '
      'Nova/13.0/null/d9ffffff bodyMedium=Proxima Nova/14.0/500/bfffffff bodyLarge=Proxima '
      'Nova/24.0/500/ffffffff bodySmall=Roboto/16.0/400/ff2f2f2f',
  'kDarkTheme':
      'dark canvas=00000000 primary=ff000000 focus=ff000000 hint=ff2f2f2f scheme=ffe57697/fff0f0f0/ffff6b6b '
      'overlay=light labelLarge=Proxima Nova/16.0/800/ff000000 headlineSmall=Proxima '
      'Nova/16.0/null/fff0f0f0 headlineMedium=Proxima Nova/16.0/500/fff0f0f0 displaySmall=Proxima '
      'Nova/20.0/500/ffffffff displayMedium=Proxima Nova/24.0/500/ffffffff displayLarge=Proxima '
      'Nova/50.0/600/fff0f0f0 titleMedium=Roboto/20.0/900/ff2f2f2f titleLarge=Proxima '
      'Nova/14.0/null/d9f0f0f0 bodyMedium=Proxima Nova/14.0/500/d9f0f0f0 bodyLarge=Proxima '
      'Nova/22.0/500/fff0f0f0 bodySmall=Roboto/16.0/400/fff0f0f0',
  'kDarkTheme2':
      'dark canvas=00000000 primary=ff000000 focus=ff000000 hint=ff000000 scheme=ffffffff/ffffffff/ffff6b6b '
      'overlay=light labelLarge=Proxima Nova/16.0/800/ff000000 headlineSmall=Proxima '
      'Nova/16.0/null/ffffffff headlineMedium=Proxima Nova/16.0/500/ffffffff displaySmall=Proxima '
      'Nova/20.0/500/ffffffff displayMedium=Proxima Nova/24.0/500/ffffffff displayLarge=Proxima '
      'Nova/50.0/600/ffffffff titleMedium=Roboto/20.0/900/ff000000 titleLarge=Proxima '
      'Nova/14.0/null/d9ffffff bodyMedium=Proxima Nova/14.0/500/d9ffffff bodyLarge=Proxima '
      'Nova/22.0/500/ffffffff bodySmall=Roboto/16.0/400/ffffffff',
  'kDarkTheme3':
      'dark canvas=00000000 primary=ff202113 focus=ff000000 hint=ff35371f scheme=ff767b45/ffe3e4d0/ffff6b6b '
      'overlay=light labelLarge=Proxima Nova/16.0/800/ff000000 headlineSmall=Proxima '
      'Nova/16.0/null/fff0f0f0 headlineMedium=Proxima Nova/16.0/500/fff0f0f0 displaySmall=Proxima '
      'Nova/20.0/500/ffffffff displayMedium=Proxima Nova/24.0/500/ffffffff displayLarge=Proxima '
      'Nova/50.0/600/fff0f0f0 titleMedium=Roboto/20.0/900/ff2f2f2f titleLarge=Proxima '
      'Nova/14.0/null/d9f0f0f0 bodyMedium=Proxima Nova/14.0/500/d9f0f0f0 bodyLarge=Proxima '
      'Nova/22.0/500/fff0f0f0 bodySmall=Roboto/16.0/400/fff0f0f0',
  'kDarkTheme4':
      'dark canvas=00000000 primary=ff041b29 focus=ff000000 hint=ff152836 scheme=ff427da8/ffb0cce0/ffff6b6b '
      'overlay=light labelLarge=Proxima Nova/16.0/800/ff000000 headlineSmall=Proxima '
      'Nova/16.0/null/fff0f0f0 headlineMedium=Proxima Nova/16.0/500/fff0f0f0 displaySmall=Proxima '
      'Nova/20.0/500/ffffffff displayMedium=Proxima Nova/24.0/500/ffffffff displayLarge=Proxima '
      'Nova/50.0/600/fff0f0f0 titleMedium=Roboto/20.0/900/ff2f2f2f titleLarge=Proxima '
      'Nova/14.0/null/d9f0f0f0 bodyMedium=Proxima Nova/14.0/500/d9f0f0f0 bodyLarge=Proxima '
      'Nova/22.0/500/fff0f0f0 bodySmall=Roboto/16.0/400/fff0f0f0',
  'kDarkTheme5':
      'dark canvas=00000000 primary=ff12210e focus=ff000000 hint=ff1d2b1a scheme=ff4c7044/ffd9e6d6/ffff6b6b '
      'overlay=light labelLarge=Proxima Nova/16.0/800/ff000000 headlineSmall=Proxima '
      'Nova/16.0/null/fff0f0f0 headlineMedium=Proxima Nova/16.0/500/fff0f0f0 displaySmall=Proxima '
      'Nova/20.0/500/ffffffff displayMedium=Proxima Nova/24.0/500/ffffffff displayLarge=Proxima '
      'Nova/50.0/600/fff0f0f0 titleMedium=Roboto/20.0/900/ff2f2f2f titleLarge=Proxima '
      'Nova/14.0/null/d9f0f0f0 bodyMedium=Proxima Nova/14.0/500/d9f0f0f0 bodyLarge=Proxima '
      'Nova/22.0/500/fff0f0f0 bodySmall=Roboto/16.0/400/fff0f0f0',
  'kDarkTheme6':
      'dark canvas=00000000 primary=ff290d02 focus=ff000000 hint=ff361b12 scheme=ff703826/ffdfb0a0/ffff6b6b '
      'overlay=light labelLarge=Proxima Nova/16.0/800/ff000000 headlineSmall=Proxima '
      'Nova/16.0/null/fff0f0f0 headlineMedium=Proxima Nova/16.0/500/fff0f0f0 displaySmall=Proxima '
      'Nova/20.0/500/ffffffff displayMedium=Proxima Nova/24.0/500/ffffffff displayLarge=Proxima '
      'Nova/50.0/600/fff0f0f0 titleMedium=Roboto/20.0/900/ff2f2f2f titleLarge=Proxima '
      'Nova/14.0/null/d9f0f0f0 bodyMedium=Proxima Nova/14.0/500/d9f0f0f0 bodyLarge=Proxima '
      'Nova/22.0/500/fff0f0f0 bodySmall=Roboto/16.0/400/fff0f0f0',
  'kDarkTheme7':
      'dark canvas=00000000 primary=ff142431 focus=ff000000 hint=ff193543 scheme=ff2d6079/ffa9cddf/ffff6b6b '
      'overlay=light labelLarge=Proxima Nova/16.0/800/ff000000 headlineSmall=Proxima '
      'Nova/16.0/null/fff0f0f0 headlineMedium=Proxima Nova/16.0/500/fff0f0f0 displaySmall=Proxima '
      'Nova/20.0/500/ffffffff displayMedium=Proxima Nova/24.0/500/ffffffff displayLarge=Proxima '
      'Nova/50.0/600/fff0f0f0 titleMedium=Roboto/20.0/900/ff2f2f2f titleLarge=Proxima '
      'Nova/14.0/null/d9f0f0f0 bodyMedium=Proxima Nova/14.0/500/d9f0f0f0 bodyLarge=Proxima '
      'Nova/22.0/500/fff0f0f0 bodySmall=Roboto/16.0/400/fff0f0f0',
  'kDarkTheme8':
      'dark canvas=00000000 primary=ff393d46 focus=ff000000 hint=ff33363f scheme=ff686e80/ffeeeff2/ffff6b6b '
      'overlay=light labelLarge=Proxima Nova/16.0/800/ff000000 headlineSmall=Proxima '
      'Nova/16.0/null/fff0f0f0 headlineMedium=Proxima Nova/16.0/500/fff0f0f0 displaySmall=Proxima '
      'Nova/20.0/500/ffffffff displayMedium=Proxima Nova/24.0/500/ffffffff displayLarge=Proxima '
      'Nova/50.0/600/fff0f0f0 titleMedium=Roboto/20.0/900/ff2f2f2f titleLarge=Proxima '
      'Nova/14.0/null/d9f0f0f0 bodyMedium=Proxima Nova/14.0/500/d9f0f0f0 bodyLarge=Proxima '
      'Nova/22.0/500/fff0f0f0 bodySmall=Roboto/16.0/400/fff0f0f0',
};

void main() {
  test('theme getters keep the values they had before the builder refactor', () {
    final themes = <String, ThemeData>{
      'kLightTheme': kLightTheme,
      'kLightTheme2': kLightTheme2,
      'kLightTheme3': kLightTheme3,
      'kLightTheme4': kLightTheme4,
      'kDarkTheme': kDarkTheme,
      'kDarkTheme2': kDarkTheme2,
      'kDarkTheme3': kDarkTheme3,
      'kDarkTheme4': kDarkTheme4,
      'kDarkTheme5': kDarkTheme5,
      'kDarkTheme6': kDarkTheme6,
      'kDarkTheme7': kDarkTheme7,
      'kDarkTheme8': kDarkTheme8,
    };
    expect(themes.keys, _expected.keys);
    themes.forEach((name, theme) => expect(describeTheme(theme), _expected[name], reason: name));
  });
}
