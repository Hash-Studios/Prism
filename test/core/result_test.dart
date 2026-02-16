import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Result', () {
    test('success stores data and folds to success branch', () {
      final result = Result.success<int>(42);

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.data, 42);

      final folded = result.fold(
        onSuccess: (value) => value + 1,
        onFailure: (_) => 0,
      );

      expect(folded, 43);
    });

    test('error stores failure and folds to failure branch', () {
      final result = Result.error<int>(const ValidationFailure('bad input'));

      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.failure, isA<ValidationFailure>());

      final folded = result.fold(
        onSuccess: (_) => 0,
        onFailure: (failure) => failure.message,
      );

      expect(folded, 'bad input');
    });
  });
}
