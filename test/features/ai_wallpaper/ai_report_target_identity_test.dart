import 'package:Prism/features/ai_wallpaper/domain/entities/ai_generation_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AI report target Firestore identity', () {
    test('history document identity wins over a different record id', () {
      final AiGenerationRecord record = AiGenerationRecord.fromJson(<String, Object?>{
        'id': 'api-generation-id',
        'userId': 'user-1',
        'format': 'duo-reveal',
        'prompt': 'folded prompt',
      }, fallbackId: 'actual-firestore-document-id');

      expect(record.id, 'api-generation-id');
      expect(record.isDuoReveal, isTrue);
      expect(record.reportTargetFirestoreDocId, 'actual-firestore-document-id');
    });

    test('locally cached record retains its Firestore report target', () {
      final AiGenerationRecord original = AiGenerationRecord.fromJson(<String, Object?>{
        'id': 'api-generation-id',
        'firestoreDocId': 'actual-document-id',
      });

      final AiGenerationRecord restored = AiGenerationRecord.fromJson(original.toJson());

      expect(restored.reportTargetFirestoreDocId, 'actual-document-id');
      expect(restored.copyWith(challengeId: 'challenge-1').reportTargetFirestoreDocId, 'actual-document-id');
    });

    test('new generations default report target to their id', () {
      final AiGenerationRecord record = AiGenerationRecord.fromJson(<String, Object?>{'id': 'new-generation'});

      expect(record.reportTargetFirestoreDocId, 'new-generation');
    });
  });
}
