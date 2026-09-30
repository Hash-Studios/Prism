import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/format_utils.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

/// One label over a value in the expanded detail panel.
class DetailFact {
  const DetailFact({required this.label, this.value, this.loading = false, this.onTap});

  final String label;
  final String? value;

  /// Shows a skeleton in place of [value].
  final bool loading;

  /// Makes the value a link.
  final VoidCallback? onTap;
}

/// The name shown at the top of the detail panel.
String detailTitle(FeedItemEntity entity) => entity.id.toUpperCase();

/// The creator's name for "by ...", or null when the source has none.
String? detailAuthor(FeedItemEntity entity) {
  final String? name = entity.when(
    prism: (_, w) {
      final String author = w.core.authorName?.trim() ?? '';
      return author.isNotEmpty ? author : w.core.authorEmail?.trim();
    },
    wallhaven: (_, w) => w.core.authorName?.trim(),
    pexels: (_, w) => w.photographer?.trim(),
  );
  return name == null || name.isEmpty ? null : name;
}

String _formatDate(DateTime date) {
  final DateTime local = date.toLocal();
  final DateTime now = DateTime.now();
  if (now.difference(local).inDays < 7) return timeago.format(local);
  return DateFormat(local.year == now.year ? 'd MMM' : 'd MMM y').format(local);
}

/// Facts for the expanded panel, in reading order. Only facts the source has are returned.
List<DetailFact> detailFacts(BuildContext context, FeedItemEntity entity, WallpaperDetailLoaded state) {
  Future<void> open(Uri? uri) async {
    if (uri == null) return;
    final bool ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) toasts.success('Could not open profile');
  }

  return entity.when(
    prism: (_, w) {
      final String email = w.core.authorEmail?.trim() ?? '';
      final String name = w.core.authorName?.trim() ?? '';
      final String profile = email.isNotEmpty ? email : name;
      final String? author = detailAuthor(entity);
      final List<String>? collections = w.collections;
      return <DetailFact>[
        if (author != null)
          DetailFact(
            label: 'Author',
            value: author,
            onTap: profile.isEmpty ? null : () => context.router.push(ProfileRoute(profileIdentifier: profile)),
          ),
        if (state.views != null || state.viewsLoading)
          DetailFact(label: 'Views', value: state.views, loading: state.views == null),
        if (w.core.sizeBytes != null) DetailFact(label: 'Size', value: formatMegabytes(w.core.sizeBytes!)),
        if (w.core.resolution != null) DetailFact(label: 'Resolution', value: w.core.resolution),
        if (w.core.category != null) DetailFact(label: 'Category', value: w.core.category),
        if (collections != null && collections.isNotEmpty)
          DetailFact(label: 'Collections', value: collections.take(2).join(', ')),
        if (w.core.createdAt != null) DetailFact(label: 'Added', value: _formatDate(w.core.createdAt!)),
        const DetailFact(label: 'Source', value: 'Prism'),
      ];
    },
    wallhaven: (_, w) {
      final String? author = detailAuthor(entity);
      final int? bytes = w.sizeBytes ?? w.core.sizeBytes;
      return <DetailFact>[
        if (author != null)
          DetailFact(
            label: 'Author',
            value: author,
            onTap: () => open(Uri.https('wallhaven.cc', '/user/${Uri.encodeComponent(author)}')),
          ),
        if (w.views != null) DetailFact(label: 'Views', value: '${w.views}'),
        if (w.core.favourites != null) DetailFact(label: 'Favourites', value: '${w.core.favourites}'),
        if (bytes != null) DetailFact(label: 'Size', value: formatMegabytes(bytes)),
        if (w.core.resolution != null) DetailFact(label: 'Resolution', value: w.core.resolution),
        if (w.core.category != null) DetailFact(label: 'Category', value: w.core.category),
        const DetailFact(label: 'Source', value: 'Wallhaven'),
      ];
    },
    pexels: (_, w) {
      final String? author = detailAuthor(entity);
      final String link = w.photographerUrl?.trim() ?? '';
      return <DetailFact>[
        if (author != null)
          DetailFact(label: 'Photographer', value: author, onTap: link.isEmpty ? null : () => open(Uri.tryParse(link))),
        if (w.core.width != null && w.core.height != null)
          DetailFact(label: 'Resolution', value: '${w.core.width}x${w.core.height}'),
        const DetailFact(label: 'Source', value: 'Pexels'),
      ];
    },
  );
}

/// [facts] in two columns, each a caption over its value.
class DetailFactsGrid extends StatelessWidget {
  const DetailFactsGrid({super.key, required this.facts});

  final List<DetailFact> facts;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double cell = (constraints.maxWidth - PrismSpace.md) / 2;
        return Wrap(
          spacing: PrismSpace.md,
          runSpacing: PrismSpace.sm,
          children: <Widget>[
            for (final DetailFact fact in facts)
              SizedBox(
                width: cell,
                child: Semantics(
                  link: fact.onTap != null,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: fact.onTap,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: fact.onTap == null ? 0 : 44),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(fact.label, style: PrismTextStyles.caption(context)),
                          const SizedBox(height: 2),
                          if (fact.loading)
                            const PrismSkeleton(child: PrismBone(width: 40, height: 15))
                          else
                            Text(
                              fact.value ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: PrismTextStyles.rowTitle(
                                context,
                              ).copyWith(decoration: fact.onTap == null ? null : TextDecoration.underline),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
