import 'package:Prism/core/wallpaper/prism_preview.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/env/env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PrismWallpaper wall(String thumb, {WallpaperSource source = WallpaperSource.prism, String id = 'CANONICAL'}) =>
      PrismWallpaper(
        core: WallpaperCore(id: id, source: source, fullUrl: '', thumbnailUrl: thumb),
        firestoreDocumentId: 'firestore-document',
      );

  test('canonical Prism previews preserve R2, Studio and existing HTTPS thumbnails', () {
    final owned = 'https://staging.example.test/previews/${'a' * 64}.img';
    expect(hasPrismPreview(wall(owned)), isTrue);
    expect(hasPrismPreview(wall('')), isFalse);
    expect(hasPrismPreview(wall('https://example.com/thumb.jpg')), isTrue);
    expect(hasPrismPreview(wall('https://prismwalls.com/api/ai/assets/ai/studio/thumb_job-1.jpg')), isTrue);
    expect(hasPrismPreview(wall('http://example.com/thumb.jpg')), isFalse);
    expect(hasPrismPreview(wall('https:///thumb.jpg')), isFalse);
    expect(hasPrismPreview(wall(owned, id: '')), isFalse);
    expect(hasPrismPreview(wall(owned, source: WallpaperSource.wallhaven)), isFalse);
    expect(wall(owned).fullUrl, isEmpty);
  });

  test('untrusted preview inputs allow Studio thumbnails but never Studio originals', () {
    expect(isSafePrismThumbnailUrl('https://prismwalls.com/api/ai/assets/ai/studio/thumb_job-1.jpg'), isTrue);
    for (final url in <String>[
      'https://prismwalls.com/api/ai/assets/ai/studio/job-1.jpg',
      'https://prismwalls.com/api/ai/assets/ai/studio/thumb_job-1.jpg?original=1',
      'https://prismwalls.com.evil.test/api/ai/assets/ai/studio/thumb_job-1.jpg',
      'https://user@prismwalls.com/api/ai/assets/ai/studio/thumb_job-1.jpg',
    ]) {
      expect(isSafePrismThumbnailUrl(url), isFalse, reason: url);
    }
  });

  test('R2 and GitHub input allowlists use the configured endpoints only', () {
    final String base = Env.normalize(Env.r2PreviewBaseUrl);
    final String preview = '${base.replaceFirst(RegExp(r'/$'), '')}/previews/${'a' * 64}.img';
    expect(isSafePrismThumbnailUrl(preview), base.isNotEmpty);
    expect(isSafePrismThumbnailUrl('$preview?original=1'), isFalse);
    expect(isSafePrismThumbnailUrl('$preview/extra'), isFalse);
    expect(isSafePrismThumbnailUrl('https://evil.test/previews/${'a' * 64}.img'), isFalse);
    final String owner = Env.normalize(Env.ghUsername);
    final String repo = Env.normalize(Env.ghRepoWalls);
    final String github = 'https://raw.githubusercontent.com/$owner/$repo/main/thumb_wall.jpg';
    expect(isSafePrismThumbnailUrl(github), owner.isNotEmpty && repo.isNotEmpty);
    expect(isSafePrismThumbnailUrl(github.replaceFirst('thumb_wall.jpg', 'wall.jpg')), isFalse);
    expect(isSafePrismThumbnailUrl('https://raw.githubusercontent.com/attacker/repo/main/thumb_wall.jpg'), isFalse);
  });
}
