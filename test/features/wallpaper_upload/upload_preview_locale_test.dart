import 'package:Prism/features/wallpaper_upload/views/widgets/upload_preview_row.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatFileSize', () {
    test('uses the selected locale decimal separator and keeps the original precision', () {
      expect(formatFileSize('0.25MB', 'es'), '0,25 MB');
      expect(formatFileSize('12.5KB', 'en'), '12.5 KB');
      expect(formatFileSize('2MB', 'es'), '2 MB');
    });

    test('leaves unknown or malformed sizes unchanged', () {
      expect(formatFileSize('1.20TB', 'es'), '1.20TB');
      expect(formatFileSize('unknown', 'es'), 'unknown');
      expect(formatFileSize('1.2.3MB', 'es'), '1.2.3MB');
    });
  });
}
