import 'package:Prism/core/wallpaper/wall_ai_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';

/// An approved Prism wall. Image URLs stay empty so widget tests never load the network.
PrismWallpaper remixWall({
  String id = 'wall-1',
  String? docId = 'doc-1',
  String? title = 'Koi',
  String? authorName = 'Asha',
  String? authorEmail,
  String? authorUid = 'uid-asha',
  bool? review = true,
  bool isAi = true,
  bool isStudio = false,
  String? stylePreset = 'anime',
  List<String>? collections,
  bool isStreakExclusive = false,
  String? remixOf,
  int remixCount = 0,
}) {
  return PrismWallpaper(
    core: WallpaperCore(
      id: id,
      source: WallpaperSource.prism,
      fullUrl: '',
      thumbnailUrl: '',
      authorName: authorName,
      authorEmail: authorEmail,
      authorUid: authorUid,
    ),
    title: title,
    review: review,
    collections: collections,
    isStreakExclusive: isStreakExclusive,
    firestoreDocumentId: docId,
    aiSource: isAi
        ? WallAiSource(
            prompt: 'a koi pond at dawn',
            stylePreset: isStudio ? null : stylePreset,
            model: 'z-image-turbo',
            isStudio: isStudio,
          )
        : null,
    remixOf: remixOf,
    remixCount: remixCount,
  );
}
