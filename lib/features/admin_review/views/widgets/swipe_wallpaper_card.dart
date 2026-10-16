import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

/// One wallpaper in the swipe stack. The wallpaper fills the card; the title, category and creator sit on a scrim.
class SwipeWallpaperCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String category;
  final String authorName;
  final String authorPhoto;
  final String? uploadedAgo;
  final bool isTopCard;

  /// Space around the card. The stamp overlay uses the same margin so the two line up.
  static const EdgeInsets margin = EdgeInsets.symmetric(horizontal: PrismSpace.md, vertical: PrismSpace.xs);

  const SwipeWallpaperCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.category,
    required this.authorName,
    required this.authorPhoto,
    this.uploadedAgo,
    this.isTopCard = true,
  });

  factory SwipeWallpaperCard.fromDocument(FirestoreDocument wall, {bool isTopCard = true}) {
    final DateTime? uploadedAt = wall.createdAt;
    return SwipeWallpaperCard(
      imageUrl: wall.wallpaperThumb.isNotEmpty ? wall.wallpaperThumb : wall.wallpaperUrl,
      title: wall.data()['title']?.toString() ?? '',
      category: wall.data()['category']?.toString() ?? 'General',
      authorName: wall.by,
      authorPhoto: wall.userPhoto,
      uploadedAgo: uploadedAt == null ? null : timeago.format(uploadedAt.toLocal()),
      isTopCard: isTopCard,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextStyle onImage = PrismTextStyles.caption(context).copyWith(color: Colors.white);

    return Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(PrismRadius.lg),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => const PrismSkeleton(child: PrismBone(height: double.infinity, radius: 0)),
              errorWidget: (context, url, error) => ColoredBox(
                color: cs.surfaceContainerHighest,
                child: Icon(Icons.broken_image_outlined, color: cs.onSurface.withValues(alpha: 0.5), size: 48),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.72)],
                  stops: const [0.55, 1.0],
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(PrismSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (category.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: PrismSpace.sm, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(PrismRadius.pill),
                        ),
                        child: Text(category, style: onImage.copyWith(fontWeight: FontWeight.w700)),
                      ),
                    const SizedBox(height: PrismSpace.xs),
                    Text(
                      title.isNotEmpty ? title : 'Untitled',
                      style: PrismTextStyles.sheetHeadline(context).copyWith(color: Colors.white),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: PrismSpace.sm),
                    Row(
                      children: [
                        PrismAvatar(url: authorPhoto, name: authorName, size: 32),
                        const SizedBox(width: PrismSpace.xs),
                        Expanded(
                          child: Text(
                            authorName.isNotEmpty ? authorName : 'Anonymous',
                            style: PrismTextStyles.rowTitle(context).copyWith(color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (uploadedAgo != null && uploadedAgo!.isNotEmpty) ...<Widget>[
                      const SizedBox(height: PrismSpace.xxs),
                      Text(uploadedAgo!, style: onImage.copyWith(color: Colors.white.withValues(alpha: 0.8))),
                    ],
                  ],
                ),
              ),
            ),
            if (!isTopCard) ColoredBox(color: Colors.black.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }
}
