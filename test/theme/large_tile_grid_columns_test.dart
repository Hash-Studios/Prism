import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('largeTileGridColumns keeps phones at 2 and gives tablets more columns', () {
    expect(largeTileGridColumns(320), 2);
    expect(largeTileGridColumns(393), 2);
    expect(largeTileGridColumns(480), 2);
    expect(largeTileGridColumns(599), 2);
    expect(largeTileGridColumns(744), 3);
    expect(largeTileGridColumns(834), 4);
    expect(largeTileGridColumns(1032), 5);
    expect(largeTileGridColumns(1376), 6);
    expect(largeTileGridColumns(2000), 6);
  });
}
