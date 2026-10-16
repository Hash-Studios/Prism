import 'dart:io';

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

void main() {
  final List<File> layouts =
      Directory(
          'android/app/src/main/res/layout',
        ).listSync().whereType<File>().where((File f) => RegExp(r'wotd_widget[^/]*\.xml$').hasMatch(f.path)).toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));

  test('the Wall of the Day layouts exist', () {
    expect(
      layouts.map((File f) => f.uri.pathSegments.last),
      containsAll(<String>['wotd_widget.xml', 'wotd_widget_preview.xml']),
    );
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
