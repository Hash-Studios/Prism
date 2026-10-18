import 'dart:io';

import 'package:Prism/core/analytics/events/generated/analytics_events.g.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('every schema enum exactly matches Dart wire values', () {
    final YamlMap schema =
        loadYaml(File('lib/core/analytics/schema/analytics_events.yaml').readAsStringSync()) as YamlMap;
    final Map<String, List<String>> actual = analyticsEnumWireValues();
    final List<String> drifted = <String>[];
    for (final YamlMap spec in (schema['enums'] as YamlList).cast<YamlMap>()) {
      if (!unorderedEquals(
        (spec['values'] as YamlList).cast<String>(),
      ).matches(actual[spec['name']], <Object?, Object?>{})) {
        drifted.add('${spec['name']}: schema=${spec['values']}, Dart=${actual[spec['name']]}');
      }
    }
    expect(drifted, isEmpty, reason: drifted.join('\n'));
    expect(actual.length, (schema['enums'] as YamlList).length);
  });
}
