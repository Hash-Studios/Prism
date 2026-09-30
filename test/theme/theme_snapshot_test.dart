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
      'light canvas=00000000 primary=ffffffff focus=1f000000 hint=99000000 '
      'scheme=ffe57697/ff090909/ffc62828 overlay=dark labelLarge=Proxima Nova/15.0/600/ff090909 '
      'headlineSmall=Proxima Nova/20.0/700/ff090909 headlineMedium=Proxima Nova/24.0/700/ff090909 '
      'displaySmall=Fraunces/28.0/700/ff090909 displayMedium=Fraunces/34.0/700/ff090909 '
      'displayLarge=Fraunces/40.0/700/ff090909 titleMedium=Proxima Nova/16.0/700/ff090909 '
      'titleLarge=Proxima Nova/20.0/700/ff090909 bodyMedium=Proxima Nova/14.0/500/ff090909 '
      'bodyLarge=Proxima Nova/16.0/500/ff090909 bodySmall=Proxima Nova/12.0/500/ff5d5d5d',
  'kLightTheme2':
      'light canvas=00000000 primary=fff7f1e3 focus=1f000000 hint=99000000 '
      'scheme=ffc19439/ff1e1709/ffc62828 overlay=dark labelLarge=Proxima Nova/15.0/600/ff1e1709 '
      'headlineSmall=Proxima Nova/20.0/700/ff1e1709 headlineMedium=Proxima Nova/24.0/700/ff1e1709 '
      'displaySmall=Fraunces/28.0/700/ff1e1709 displayMedium=Fraunces/34.0/700/ff1e1709 '
      'displayLarge=Fraunces/40.0/700/ff1e1709 titleMedium=Proxima Nova/16.0/700/ff1e1709 '
      'titleLarge=Proxima Nova/20.0/700/ff1e1709 bodyMedium=Proxima Nova/14.0/500/ff1e1709 '
      'bodyLarge=Proxima Nova/16.0/500/ff1e1709 bodySmall=Proxima Nova/12.0/500/ff686153',
  'kLightTheme3':
      'light canvas=00000000 primary=ffc5a79f focus=1f000000 hint=99000000 '
      'scheme=ffa7796d/ff19110f/ffc62828 overlay=dark labelLarge=Proxima Nova/15.0/600/ff19110f '
      'headlineSmall=Proxima Nova/20.0/700/ff19110f headlineMedium=Proxima Nova/24.0/700/ff19110f '
      'displaySmall=Fraunces/28.0/700/ff19110f displayMedium=Fraunces/34.0/700/ff19110f '
      'displayLarge=Fraunces/40.0/700/ff19110f titleMedium=Proxima Nova/16.0/700/ff19110f '
      'titleLarge=Proxima Nova/20.0/700/ff19110f bodyMedium=Proxima Nova/14.0/500/ff19110f '
      'bodyLarge=Proxima Nova/16.0/500/ff19110f bodySmall=Proxima Nova/12.0/500/ff4d3e3a',
  'kLightTheme4':
      'light canvas=00000000 primary=ff8399be focus=1f000000 hint=99000000 '
      'scheme=ff596f95/ff0b0d12/ffc62828 overlay=dark labelLarge=Proxima Nova/15.0/600/ff0b0d12 '
      'headlineSmall=Proxima Nova/20.0/700/ff0b0d12 headlineMedium=Proxima Nova/24.0/700/ff0b0d12 '
      'displaySmall=Fraunces/28.0/700/ff0b0d12 displayMedium=Fraunces/34.0/700/ff0b0d12 '
      'displayLarge=Fraunces/40.0/700/ff0b0d12 titleMedium=Proxima Nova/16.0/700/ff0b0d12 '
      'titleLarge=Proxima Nova/20.0/700/ff0b0d12 bodyMedium=Proxima Nova/14.0/500/ff0b0d12 '
      'bodyLarge=Proxima Nova/16.0/500/ff0b0d12 bodySmall=Proxima Nova/12.0/500/ff252c38',
  'kDarkTheme':
      'dark canvas=00000000 primary=ff000000 focus=1fffffff hint=99ffffff scheme=ffe57697/fff0f0f0/ffff6b6b '
      'overlay=light labelLarge=Proxima Nova/15.0/600/fff0f0f0 headlineSmall=Proxima Nova/20.0/700/fff0f0f0 '
      'headlineMedium=Proxima Nova/24.0/700/fff0f0f0 displaySmall=Fraunces/28.0/700/fff0f0f0 '
      'displayMedium=Fraunces/34.0/700/fff0f0f0 displayLarge=Fraunces/40.0/700/fff0f0f0 titleMedium=Proxima '
      'Nova/16.0/700/fff0f0f0 titleLarge=Proxima Nova/20.0/700/fff0f0f0 bodyMedium=Proxima '
      'Nova/14.0/500/fff0f0f0 bodyLarge=Proxima Nova/16.0/500/fff0f0f0 bodySmall=Proxima '
      'Nova/12.0/500/ff9e9e9e',
  'kDarkTheme2':
      'dark canvas=00000000 primary=ff000000 focus=1fffffff hint=99ffffff scheme=ffffffff/ffffffff/ffff6b6b '
      'overlay=light labelLarge=Proxima Nova/15.0/600/ffffffff headlineSmall=Proxima Nova/20.0/700/ffffffff '
      'headlineMedium=Proxima Nova/24.0/700/ffffffff displaySmall=Fraunces/28.0/700/ffffffff '
      'displayMedium=Fraunces/34.0/700/ffffffff displayLarge=Fraunces/40.0/700/ffffffff titleMedium=Proxima '
      'Nova/16.0/700/ffffffff titleLarge=Proxima Nova/20.0/700/ffffffff bodyMedium=Proxima '
      'Nova/14.0/500/ffffffff bodyLarge=Proxima Nova/16.0/500/ffffffff bodySmall=Proxima '
      'Nova/12.0/500/ffa8a8a8',
  'kDarkTheme3':
      'dark canvas=00000000 primary=ff202113 focus=1fffffff hint=99ffffff scheme=ff767b45/ffe3e4d0/ffff6b6b '
      'overlay=light labelLarge=Proxima Nova/15.0/600/ffe3e4d0 headlineSmall=Proxima Nova/20.0/700/ffe3e4d0 '
      'headlineMedium=Proxima Nova/24.0/700/ffe3e4d0 displaySmall=Fraunces/28.0/700/ffe3e4d0 '
      'displayMedium=Fraunces/34.0/700/ffe3e4d0 displayLarge=Fraunces/40.0/700/ffe3e4d0 titleMedium=Proxima '
      'Nova/16.0/700/ffe3e4d0 titleLarge=Proxima Nova/20.0/700/ffe3e4d0 bodyMedium=Proxima '
      'Nova/14.0/500/ffe3e4d0 bodyLarge=Proxima Nova/16.0/500/ffe3e4d0 bodySmall=Proxima '
      'Nova/12.0/500/ffa1a290',
  'kDarkTheme4':
      'dark canvas=00000000 primary=ff041b29 focus=1fffffff hint=99ffffff scheme=ff427da8/ffb0cce0/ffff6b6b '
      'overlay=light labelLarge=Proxima Nova/15.0/600/ffb0cce0 headlineSmall=Proxima Nova/20.0/700/ffb0cce0 '
      'headlineMedium=Proxima Nova/24.0/700/ffb0cce0 displaySmall=Fraunces/28.0/700/ffb0cce0 '
      'displayMedium=Fraunces/34.0/700/ffb0cce0 displayLarge=Fraunces/40.0/700/ffb0cce0 titleMedium=Proxima '
      'Nova/16.0/700/ffb0cce0 titleLarge=Proxima Nova/20.0/700/ffb0cce0 bodyMedium=Proxima '
      'Nova/14.0/500/ffb0cce0 bodyLarge=Proxima Nova/16.0/500/ffb0cce0 bodySmall=Proxima '
      'Nova/12.0/500/ff7690a2',
  'kDarkTheme5':
      'dark canvas=00000000 primary=ff12210e focus=1fffffff hint=99ffffff scheme=ff4c7044/ffd9e6d6/ffff6b6b '
      'overlay=light labelLarge=Proxima Nova/15.0/600/ffd9e6d6 headlineSmall=Proxima Nova/20.0/700/ffd9e6d6 '
      'headlineMedium=Proxima Nova/24.0/700/ffd9e6d6 displaySmall=Fraunces/28.0/700/ffd9e6d6 '
      'displayMedium=Fraunces/34.0/700/ffd9e6d6 displayLarge=Fraunces/40.0/700/ffd9e6d6 titleMedium=Proxima '
      'Nova/16.0/700/ffd9e6d6 titleLarge=Proxima Nova/20.0/700/ffd9e6d6 bodyMedium=Proxima '
      'Nova/14.0/500/ffd9e6d6 bodyLarge=Proxima Nova/16.0/500/ffd9e6d6 bodySmall=Proxima '
      'Nova/12.0/500/ff95a392',
  'kDarkTheme6':
      'dark canvas=00000000 primary=ff290d02 focus=1fffffff hint=99ffffff scheme=ff703826/ffdfb0a0/ffff6b6b '
      'overlay=light labelLarge=Proxima Nova/15.0/600/ffdfb0a0 headlineSmall=Proxima Nova/20.0/700/ffdfb0a0 '
      'headlineMedium=Proxima Nova/24.0/700/ffdfb0a0 displaySmall=Fraunces/28.0/700/ffdfb0a0 '
      'displayMedium=Fraunces/34.0/700/ffdfb0a0 displayLarge=Fraunces/40.0/700/ffdfb0a0 titleMedium=Proxima '
      'Nova/16.0/700/ffdfb0a0 titleLarge=Proxima Nova/20.0/700/ffdfb0a0 bodyMedium=Proxima '
      'Nova/14.0/500/ffdfb0a0 bodyLarge=Proxima Nova/16.0/500/ffdfb0a0 bodySmall=Proxima '
      'Nova/12.0/500/ffa1796a',
  'kDarkTheme7':
      'dark canvas=00000000 primary=ff142431 focus=1fffffff hint=99ffffff scheme=ff2d6079/ffa9cddf/ffff6b6b '
      'overlay=light labelLarge=Proxima Nova/15.0/600/ffa9cddf headlineSmall=Proxima Nova/20.0/700/ffa9cddf '
      'headlineMedium=Proxima Nova/24.0/700/ffa9cddf displaySmall=Fraunces/28.0/700/ffa9cddf '
      'displayMedium=Fraunces/34.0/700/ffa9cddf displayLarge=Fraunces/40.0/700/ffa9cddf titleMedium=Proxima '
      'Nova/16.0/700/ffa9cddf titleLarge=Proxima Nova/20.0/700/ffa9cddf bodyMedium=Proxima '
      'Nova/14.0/500/ffa9cddf bodyLarge=Proxima Nova/16.0/500/ffa9cddf bodySmall=Proxima '
      'Nova/12.0/500/ff7694a4',
  'kDarkTheme8':
      'dark canvas=00000000 primary=ff393d46 focus=1fffffff hint=99ffffff scheme=ff686e80/ffeeeff2/ffff6b6b '
      'overlay=light labelLarge=Proxima Nova/15.0/600/ffeeeff2 headlineSmall=Proxima Nova/20.0/700/ffeeeff2 '
      'headlineMedium=Proxima Nova/24.0/700/ffeeeff2 displaySmall=Fraunces/28.0/700/ffeeeff2 '
      'displayMedium=Fraunces/34.0/700/ffeeeff2 displayLarge=Fraunces/40.0/700/ffeeeff2 titleMedium=Proxima '
      'Nova/16.0/700/ffeeeff2 titleLarge=Proxima Nova/20.0/700/ffeeeff2 bodyMedium=Proxima '
      'Nova/14.0/500/ffeeeff2 bodyLarge=Proxima Nova/16.0/500/ffeeeff2 bodySmall=Proxima '
      'Nova/12.0/500/ffb0b2b8',
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
