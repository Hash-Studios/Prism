import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

class SwipeWallpaperCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String category;
  final String authorName;
  final String authorPhoto;
  final String? uploadedAgo;
  final bool isTopCard;

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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => ColoredBox(
                color: colorScheme.surfaceContainerHighest,
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              errorWidget: (context, url, error) => ColoredBox(
                color: colorScheme.errorContainer,
                child: Icon(Icons.broken_image, color: colorScheme.onErrorContainer, size: 48),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: 0.8),
                  ],
                  stops: const [0.5, 0.7, 1.0],
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (category.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          category,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      title.isNotEmpty ? title : 'Untitled',
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: authorPhoto.isNotEmpty ? CachedNetworkImageProvider(authorPhoto) : null,
                          child: authorPhoto.isEmpty ? const Icon(Icons.person, size: 16) : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            authorName.isNotEmpty ? authorName : 'Anonymous',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (uploadedAgo != null && uploadedAgo!.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(uploadedAgo!, style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ),
            if (!isTopCard)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
