import 'package:Prism/core/router/deep_link_action_entity.dart';
import 'package:Prism/core/router/deep_link_parser.dart';
import 'package:Prism/core/router/deep_link_route_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final uri in ['https://prismwalls.com/challenges/2026-10-26', 'prism://challenges/2026-10-26']) {
    test('accepts $uri', () {
      final action = const DeepLinkParser().parse(Uri.parse(uri));
      expect(action, isA<PageLinkIntent>());
      final match = DeepLinkRouteCatalog.match(Uri.parse((action as PageLinkIntent).path));
      expect(match!.target, DeepLinkPageTarget.weeklyChallenge);
      expect(match.pathParams['challengeId'], '2026-10-26');
    });
  }
  for (final id in ['2026-10-27', '2026-02-30', 'bad', '2026-10-26/extra', '2026-10-26?admin=true']) {
    test('rejects malformed or non-Monday challenge $id', () {
      expect(const DeepLinkParser().parse(Uri.parse('prism://challenges/$id')), isA<UnknownIntent>());
    });
  }
}
