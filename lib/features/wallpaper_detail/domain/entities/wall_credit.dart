import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';

/// Where a wall comes from. Creator and Studio walls were uploaded to Prism, so only they are Prism exclusive.
enum WallProvenance {
  creator,
  studio,
  wallhaven,
  pexels;

  bool get isPrismExclusive => this == creator || this == studio;
}

/// Who made a wall, and where the credit opens: a Prism profile or a page on the source site.
final class WallCredit {
  const WallCredit({required this.provenance, this.name, this.photoUrl, this.profileUid, this.externalUrl});

  /// The Prism Studio profile. Studio walls credit Hash Studios and open this profile.
  static const String studioProfileUid = 'prism-studio';

  factory WallCredit.of(FeedItemEntity entity) => entity.when(
    prism: (_, wall) => _prism(wall),
    wallhaven: (_, wall) {
      final String? name = _text(wall.core.authorName);
      return WallCredit(
        provenance: WallProvenance.wallhaven,
        name: name,
        externalUrl: name == null ? null : Uri.https('wallhaven.cc', '/user/${Uri.encodeComponent(name)}'),
      );
    },
    pexels: (_, wall) => WallCredit(
      provenance: WallProvenance.pexels,
      name: _text(wall.photographer),
      externalUrl: _webUrl(wall.photographerUrl),
    ),
  );

  static WallCredit _prism(PrismWallpaper wall) {
    if (wall.byStudio) {
      return WallCredit(
        provenance: WallProvenance.studio,
        photoUrl: _text(wall.core.authorPhoto),
        profileUid: studioProfileUid,
      );
    }
    return WallCredit(
      provenance: WallProvenance.creator,
      name: _text(wall.core.authorName),
      photoUrl: _text(wall.core.authorPhoto),
      profileUid: _text(wall.core.authorUid),
    );
  }

  final WallProvenance provenance;

  /// Null for Studio walls, which always read "By Hash Studios", and when the source gave no name.
  final String? name;
  final String? photoUrl;

  /// The Prism profile the credit opens. Null for Wallhaven and Pexels walls.
  final String? profileUid;

  /// The source page the credit opens. Null for Prism walls.
  final Uri? externalUrl;

  static String? _text(String? value) {
    final String trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  static Uri? _webUrl(String? value) {
    final Uri? uri = Uri.tryParse(value?.trim() ?? '');
    return uri != null && (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty ? uri : null;
  }
}
