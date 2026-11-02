import 'dart:io';

import 'package:Prism/core/analytics/events/events.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('the five Duo events use exact typed payloads without prompt text', () {
    const events = <AnalyticsEvent>[
      DuoPreviewOpenedEvent(contentId: 'wall', source: 'ai', presetId: 'prism-right-v1'),
      DuoFoldToggledEvent(contentId: 'wall', unfolded: true),
      DuoAiGeneratedEvent(generationId: 'generation', qualityTier: 'quality'),
      DuoShareCardMadeEvent(contentId: 'wall'),
      DuoRowOpenedEvent(source: 'row'),
    ];
    expect(events.map((event) => event.eventName), <String>[
      'duo_preview_opened',
      'duo_fold_toggled',
      'duo_ai_generated',
      'duo_share_card_made',
      'duo_row_opened',
    ]);
    expect(events.map((event) => event.toWireParameters()).toList(), <Map<String, Object?>>[
      <String, Object?>{'content_id': 'wall', 'source': 'ai', 'preset_id': 'prism-right-v1'},
      <String, Object?>{'content_id': 'wall', 'unfolded': 1},
      <String, Object?>{'generation_id': 'generation', 'quality_tier': 'quality'},
      <String, Object?>{'content_id': 'wall'},
      <String, Object?>{'source': 'row'},
    ]);
    expect(ShareFormatValue.duoReveal.wireValue, 'duo_reveal');
    final schema = loadYaml(File('lib/core/analytics/schema/analytics_events.yaml').readAsStringSync()) as YamlMap;
    final duo = (schema['events'] as YamlList).cast<YamlMap>().where(
      (event) => (event['id'] as String).startsWith('duo_'),
    );
    expect(duo.map((event) => event['id']), events.map((event) => event.eventName));
  });
}
