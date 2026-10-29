import 'package:Prism/core/wallpaper/wall_ai_source.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:Prism/features/wall_remix/domain/wall_remix.dart';
import 'package:flutter_test/flutter_test.dart';

import '../wall_remix_fixture.dart';

WallViewer _viewer({
  bool isPremium = false,
  List<String> premiumCollections = const <String>['space'],
  Set<String> blocked = const <String>{},
}) => WallViewer(isPremium: isPremium, premiumCollections: premiumCollections, blockedCreatorUids: blocked);

void main() {
  group('AiRemixSeed.of', () {
    test('returns a seed for an approved user AI wall with a prompt and doc id', () {
      final seed = AiRemixSeed.of(remixWall(), viewer: _viewer(), aiEnabled: true);

      expect(seed, isNotNull);
      expect(seed!.wallDocId, 'doc-1');
      expect(seed.prompt, 'a koi pond at dawn');
      expect(seed.title, 'Koi');
      expect(seed.creatorName, 'Asha');
      expect(seed.sourceType, RemixSourceType.user);
      expect(seed.style, AiStylePreset.anime);
      expect(seed.model, 'z-image-turbo');
    });

    test('returns a studio seed with no style for a Studio wall', () {
      final seed = AiRemixSeed.of(remixWall(isStudio: true), viewer: _viewer(), aiEnabled: true);

      expect(seed, isNotNull);
      expect(seed!.sourceType, RemixSourceType.studio);
      expect(seed.style, isNull);
    });

    test('returns null when AI is off', () {
      expect(AiRemixSeed.of(remixWall(), viewer: _viewer(), aiEnabled: false), isNull);
    });

    test('returns null for a wall without an AI source', () {
      expect(AiRemixSeed.of(remixWall(isAi: false), viewer: _viewer(), aiEnabled: true), isNull);
    });

    test('returns null when review is false or unknown', () {
      expect(AiRemixSeed.of(remixWall(review: false), viewer: _viewer(), aiEnabled: true), isNull);
      expect(AiRemixSeed.of(remixWall(review: null), viewer: _viewer(), aiEnabled: true), isNull);
    });

    test('returns null for a premium collection wall for a non-premium viewer only', () {
      final wall = remixWall(collections: const <String>['space']);

      expect(AiRemixSeed.of(wall, viewer: _viewer(), aiEnabled: true), isNull);
      expect(AiRemixSeed.of(wall, viewer: _viewer(isPremium: true), aiEnabled: true), isNotNull);
    });

    test('returns null for a streak-exclusive wall', () {
      expect(AiRemixSeed.of(remixWall(isStreakExclusive: true), viewer: _viewer(), aiEnabled: true), isNull);
    });

    test('returns null when the creator is blocked', () {
      expect(
        AiRemixSeed.of(remixWall(), viewer: _viewer(blocked: const <String>{'uid-asha'}), aiEnabled: true),
        isNull,
      );
    });

    test('returns null when the wall has no Firestore doc id', () {
      expect(AiRemixSeed.of(remixWall(docId: null), viewer: _viewer(), aiEnabled: true), isNull);
    });
  });

  group('visibleRemixes', () {
    test('drops the original owner by email, case-insensitively, and keeps order', () {
      final original = remixWall(id: 'orig', docId: 'doc-orig', authorEmail: 'Owner@Example.com', authorUid: 'uid-o');
      final remixes = [
        remixWall(id: 'r1', docId: 'd1', authorName: 'Ben', authorEmail: 'ben@example.com', authorUid: 'uid-b'),
        remixWall(id: 'r2', docId: 'd2', authorName: 'Owner', authorEmail: 'owner@example.com', authorUid: 'uid-o'),
        remixWall(id: 'r3', docId: 'd3', authorName: 'Chloe', authorEmail: 'chloe@example.com', authorUid: 'uid-c'),
      ];

      final visible = visibleRemixes(remixes, original: original, viewer: _viewer());

      expect(visible.map((w) => w.id), ['r1', 'r3']);
    });

    test('drops gated, withdrawn, premium-gated and blocked-creator remixes', () {
      final original = remixWall(id: 'orig', docId: 'doc-orig');
      final remixes = [
        remixWall(id: 'withdrawn', docId: 'd1', authorUid: 'uid-1', review: false),
        remixWall(id: 'streak', docId: 'd2', authorUid: 'uid-2', isStreakExclusive: true),
        remixWall(id: 'premium', docId: 'd3', authorUid: 'uid-3', collections: const <String>['space']),
        remixWall(id: 'blocked', docId: 'd4', authorUid: 'uid-blocked'),
        remixWall(id: 'ok', docId: 'd5', authorUid: 'uid-ok'),
      ];

      final visible = visibleRemixes(
        remixes,
        original: original,
        viewer: _viewer(blocked: const <String>{'uid-blocked'}),
      );

      expect(visible.map((w) => w.id), ['ok']);
    });

    test('keeps premium-gated remixes for a premium viewer', () {
      final original = remixWall(id: 'orig', docId: 'doc-orig');
      final remixes = [
        remixWall(id: 'premium', docId: 'd3', authorUid: 'uid-3', collections: const <String>['space']),
      ];

      final visible = visibleRemixes(remixes, original: original, viewer: _viewer(isPremium: true));

      expect(visible.map((w) => w.id), ['premium']);
    });
  });

  group('WallAiSource.parse', () {
    test('returns a source for an AI wall with a prompt', () {
      final source = WallAiSource.parse(isAiGenerated: true, prompt: '  a koi pond  ');

      expect(source, isNotNull);
      expect(source!.prompt, 'a koi pond');
      expect(source.isStudio, isFalse);
    });

    test('returns null when isAiGenerated is false', () {
      expect(WallAiSource.parse(isAiGenerated: false, prompt: 'a koi pond'), isNull);
    });

    test('returns null when the prompt is empty', () {
      expect(WallAiSource.parse(isAiGenerated: true, prompt: '   '), isNull);
    });

    test('marks a studio origin as Studio', () {
      final source = WallAiSource.parse(isAiGenerated: true, prompt: 'a koi pond', origin: 'studio');

      expect(source!.isStudio, isTrue);
    });
  });
}
