import 'package:Prism/core/wallpaper/prism_preview.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PrismWallpaper wall(String thumb, {WallpaperSource source = WallpaperSource.prism, String id = 'CANONICAL'}) =>
      PrismWallpaper(
        core: WallpaperCore(id: id, source: source, fullUrl: '', thumbnailUrl: thumb),
        firestoreDocumentId: 'firestore-document',
      );

  test('Prism previews use HTTPS thumbnails without treating the endpoint as original authority', () {
    const owned = 'https://staging.example.test/ownedThumbnail/CANONICAL';
    expect(hasPrismPreview(wall(owned)), isTrue);
    expect(hasPrismPreview(wall('')), isFalse);
    expect(hasPrismPreview(wall('https://example.com/thumb.jpg')), isTrue);
    expect(hasPrismPreview(wall('http://example.com/thumb.jpg')), isFalse);
    expect(hasPrismPreview(wall('https:///thumb.jpg')), isFalse);
    expect(hasPrismPreview(wall(owned, id: '')), isFalse);
    expect(hasPrismPreview(wall(owned, source: WallpaperSource.wallhaven)), isFalse);
    expect(wall(owned).fullUrl, isEmpty);
  });
}
