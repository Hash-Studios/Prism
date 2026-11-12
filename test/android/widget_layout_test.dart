import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

const Set<String> _remoteViewsClasses = <String>{
  'AdapterViewFlipper',
  'AnalogClock',
  'Button',
  'Chronometer',
  'FrameLayout',
  'GridLayout',
  'GridView',
  'ImageButton',
  'ImageView',
  'LinearLayout',
  'ListView',
  'ProgressBar',
  'RelativeLayout',
  'StackView',
  'TextClock',
  'TextView',
  'ViewFlipper',
  'CheckBox',
  'RadioButton',
  'RadioGroup',
  'Switch',
};

Map<String, String> _colors(String path) => <String, String>{
  for (final RegExpMatch match in RegExp(
    '<color name="([^"]+)">([^<]+)</color>',
  ).allMatches(File('android/app/src/main/res/$path').readAsStringSync()))
    match.group(1)!: match.group(2)!,
};

double _contrast(String foreground, String background) {
  double luminance(String color) {
    final String hex = color.substring(color.length - 6);
    final List<double> channels =
        <double>[
              for (final int offset in <int>[0, 2, 4]) int.parse(hex.substring(offset, offset + 2), radix: 16) / 255,
            ]
            .map(
              (double channel) =>
                  channel <= 0.04045 ? channel / 12.92 : math.pow((channel + 0.055) / 1.055, 2.4).toDouble(),
            )
            .toList();
    return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2];
  }

  final double a = luminance(foreground);
  final double b = luminance(background);
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

double _whiteOnBlackOverlayContrast() {
  return _contrast('#FFFFFF', '#191919');
}

void main() {
  final List<File> layouts =
      Directory('android/app/src/main/res/layout')
          .listSync()
          .whereType<File>()
          .where((File f) => RegExp(r'(wotd|streak)_widget[^/]*\.xml$').hasMatch(f.path))
          .toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));

  test('the widget layouts exist', () {
    expect(
      layouts.map((File f) => f.uri.pathSegments.last),
      containsAll(<String>[
        'wotd_widget.xml',
        'wotd_widget_preview.xml',
        'streak_widget_compact.xml',
        'streak_widget_large.xml',
        'streak_widget_preview.xml',
        'streak_widget_signed_out.xml',
      ]),
    );
  });

  test('the Wall of the Day label keeps contrast over arbitrary wallpaper imagery', () {
    final String layout = File('android/app/src/main/res/layout/wotd_widget.xml').readAsStringSync();
    expect(layout, contains('android:background="@drawable/wotd_widget_label_bg"'));
    final String labelBackground = File(
      'android/app/src/main/res/drawable/wotd_widget_label_bg.xml',
    ).readAsStringSync();
    expect(labelBackground, contains('#E6000000'));
    expect(_whiteOnBlackOverlayContrast(), greaterThanOrEqualTo(4.5));
  });

  test('widget static palettes meet contrast targets and Android 12 tones preserve them', () {
    final Map<String, String> light = _colors('values/colors.xml');
    final Map<String, String> dark = _colors('values-night/colors.xml');
    for (final Map<String, String> palette in <Map<String, String>>[light, dark]) {
      expect(
        _contrast(palette['prism_widget_on_surface']!, palette['prism_widget_surface']!),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(palette['prism_widget_on_surface_variant']!, palette['prism_widget_surface']!),
        greaterThanOrEqualTo(4.5),
      );
      expect(_contrast(palette['prism_widget_accent']!, palette['prism_widget_surface']!), greaterThanOrEqualTo(3));
      expect(_contrast(palette['prism_widget_track']!, palette['prism_widget_surface']!), greaterThanOrEqualTo(3));
      expect(
        _contrast(palette['prism_widget_on_accent_container']!, palette['prism_widget_accent_container']!),
        greaterThanOrEqualTo(4.5),
      );
    }
    final Map<String, String> dynamicLight = _colors('values-v31/colors.xml');
    final Map<String, String> dynamicDark = _colors('values-night-v31/colors.xml');
    expect(dynamicLight['prism_widget_track'], '@android:color/system_neutral2_700');
    expect(dynamicDark['prism_widget_track'], '@android:color/system_neutral2_600');
    expect(dynamicLight['prism_widget_accent'], '@android:color/system_accent1_600');
    expect(dynamicDark['prism_widget_accent'], '@android:color/system_accent1_200');
    expect(dynamicLight['prism_widget_on_surface'], '@android:color/system_neutral1_900');
    expect(dynamicDark['prism_widget_on_surface'], '@android:color/system_neutral1_50');
    expect(dynamicLight['prism_widget_on_accent_container'], '@android:color/system_accent1_900');
    expect(dynamicDark['prism_widget_on_accent_container'], '@android:color/system_accent1_100');
  });

  for (final File layout in layouts) {
    test('${layout.uri.pathSegments.last} uses only classes that RemoteViews can inflate', () {
      final Iterable<String> elements = RegExp(r'<([A-Za-z][\w.]*)')
          .allMatches(layout.readAsStringSync().replaceAll(RegExp(r'<!--.*?-->', dotAll: true), ''))
          .map((m) => m.group(1)!);
      final List<String> unsupported = elements.where((String e) => !_remoteViewsClasses.contains(e)).toList();
      expect(unsupported, isEmpty, reason: 'RemoteViews cannot inflate: $unsupported');
    });
  }
}
