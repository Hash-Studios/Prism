import 'dart:io';
import 'dart:typed_data';

import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:flutter/services.dart';

class BundledWallpapers {
  BundledWallpapers._();

  static const List<({String id, String title, String category, String assetPath})> _starters =
      <({String id, String title, String category, String assetPath})>[
        (
          id: 'starter-sunset',
          title: 'Quiet Horizon',
          category: 'Nature',
          assetPath: 'assets/images/onboarding_bg_primary.jpg',
        ),
        (id: 'starter-prism', title: 'Prism Glow', category: 'Abstract', assetPath: 'assets/images/wallpaper.jpg'),
      ];

  static const Set<String> _starterIds = <String>{'starter-sunset', 'starter-prism'};

  static Future<List<FeedItemEntity>> load({AssetBundle? bundle, Directory? directory}) async {
    final AssetBundle assets = bundle ?? rootBundle;
    final Directory targetDirectory = directory ?? Directory('${Directory.systemTemp.path}/prism-bundled-wallpapers');
    await targetDirectory.create(recursive: true);

    final List<FeedItemEntity> items = <FeedItemEntity>[];
    for (final starter in _starters) {
      final ByteData data = await assets.load(starter.assetPath);
      final Uint8List bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final File file = File('${targetDirectory.path}/${starter.id}.jpg');
      if (!await file.exists() || await file.length() != bytes.length) {
        await file.writeAsBytes(bytes, flush: true);
      }
      final String localPath = file.path;
      items.add(
        PrismFeedItem(
          id: starter.id,
          wallpaper: PrismWallpaper(
            core: WallpaperCore(
              id: starter.id,
              source: WallpaperSource.prism,
              fullUrl: localPath,
              thumbnailUrl: localPath,
              authorName: 'Prism',
              category: starter.category,
            ),
            title: starter.title,
            tags: <String>['starter', 'offline', starter.category.toLowerCase()],
          ),
        ),
      );
    }
    return items;
  }

  static bool isStarter(FeedItemEntity item) => _starterIds.contains(item.id) && item.source == WallpaperSource.prism;

  static bool isStarterIdentity(String id, WallpaperSource source) =>
      _starterIds.contains(id) && source == WallpaperSource.prism;

  /// Resolves only a catalogued starter. Never interpret an arbitrary feed URL as a local path.
  static Future<File?> localFileForStarter(String id, WallpaperSource source) async {
    if (!isStarterIdentity(id, source)) return null;
    final items = await load();
    final item = items.where((candidate) => candidate.id == id && isStarter(candidate)).firstOrNull;
    if (item == null) return null;
    final file = File(item.fullUrl);
    return await file.exists() ? file : null;
  }
}
