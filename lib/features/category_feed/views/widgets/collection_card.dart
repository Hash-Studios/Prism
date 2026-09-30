import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/views/widgets/premium_tile_badge.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

enum CollectionCardKind { collection, category }

/// What one card on the collections tab shows.
class CollectionCardData {
  const CollectionCardData({required this.kind, required this.name, required this.thumbUrl, required this.isPremium});

  final CollectionCardKind kind;
  final String name;
  final String thumbUrl;
  final bool isPremium;

  String get title {
    final String trimmed = name.trim();
    if (trimmed.isNotEmpty) return trimmed;
    return kind == CollectionCardKind.category ? 'Category' : 'Collection';
  }

  String get semanticLabel {
    final String trimmed = name.trim();
    if (kind == CollectionCardKind.category) return trimmed.isEmpty ? 'Category' : 'Category, $trimmed';
    if (trimmed.isEmpty) return isPremium ? 'Premium collection' : 'Collection';
    return isPremium ? 'Premium collection, $trimmed' : 'Collection, $trimmed';
  }
}

const double _cardAspect = 0.72;
const double _cardGap = 12;

/// Cards up to about 260 points wide: two columns on a phone, more on a tablet.
SliverGridDelegate collectionsGridDelegate(BuildContext context) {
  final int columns = (MediaQuery.sizeOf(context).width / 260).ceil().clamp(2, 6);
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: columns,
    mainAxisSpacing: _cardGap,
    crossAxisSpacing: _cardGap,
    childAspectRatio: _cardAspect,
  );
}

const EdgeInsets collectionsGridPadding = EdgeInsets.symmetric(horizontal: PrismWallGrid.margin);

/// A collection or category: cover image, a scrim, the name at the bottom left and a lock for premium ones.
class CollectionCard extends StatelessWidget {
  const CollectionCard({super.key, required this.data, required this.onTap});

  final CollectionCardData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final BorderRadius radius = BorderRadius.circular(PrismRadius.md);
    final String url = data.thumbUrl.trim();
    return PressScale(
      scale: 0.98,
      child: Semantics(
        button: true,
        label: data.semanticLabel,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                ColoredBox(color: cs.surfaceContainerHighest),
                if (url.isNotEmpty) _Cover(url: url),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: const Alignment(0, 0.1),
                      end: Alignment.bottomCenter,
                      colors: <Color>[Colors.transparent, Colors.black.withValues(alpha: 0.72)],
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
                  ),
                ),
                Positioned(
                  left: PrismSpace.md,
                  right: PrismSpace.md,
                  bottom: PrismSpace.md,
                  child: Text(
                    data.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: PrismTextStyles.cardTitle(context).copyWith(color: Colors.white),
                  ),
                ),
                if (data.isPremium)
                  const Positioned(top: PrismSpace.sm, right: PrismSpace.sm, child: PremiumTileBadge()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The cover decodes near its on-screen height, to keep memory and GPU upload cost down.
class _Cover extends StatelessWidget {
  const _Cover({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) => Image(
        image: ResizeImage(
          CachedNetworkImageProvider(url),
          height: (constraints.maxHeight * dpr).round().clamp(1, 4096),
        ),
        fit: BoxFit.cover,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) => wasSynchronouslyLoaded
            ? child
            : AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: context.motion(PrismDurations.fast),
                curve: PrismCurves.enter,
                child: child,
              ),
      ),
    );
  }
}

/// Card-shaped placeholders for the collections tab while it loads.
class CollectionsSkeleton extends StatelessWidget {
  const CollectionsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return PrismSkeleton(
      child: GridView.builder(
        primary: false,
        physics: const NeverScrollableScrollPhysics(),
        padding: collectionsGridPadding,
        gridDelegate: collectionsGridDelegate(context),
        itemCount: 8,
        itemBuilder: (context, index) => const PrismBone(radius: PrismRadius.md),
      ),
    );
  }
}
