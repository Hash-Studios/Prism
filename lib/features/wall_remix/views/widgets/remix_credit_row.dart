import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wall_remix/data/wall_remix_repository.dart';
import 'package:Prism/features/wall_remix/domain/wall_remix.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The viewer as it is now: the signed-in user's premium state, the startup premium collections and the blocked
/// creators. Throws when the blocked creators cannot be read.
Future<WallViewer> currentWallViewer(WallRemixRepository repository) async {
  final Set<String> blockedCreatorUids = await repository.blockedCreatorUids();
  return WallViewer(
    isPremium: app_state.prismUser.premium,
    premiumCollections: app_state.premiumCollections,
    blockedCreatorUids: blockedCreatorUids,
  );
}

/// A line under the detail panel that names the wall a remix started from. It shows nothing while it loads, when the
/// original is missing or withheld from this viewer, or when the lookup fails.
class RemixCreditRow extends StatefulWidget {
  const RemixCreditRow({required this.remixOfDocId, this.repository, this.viewer, super.key});

  final String remixOfDocId;
  final WallRemixRepository? repository;
  final WallViewer? viewer;

  @override
  State<RemixCreditRow> createState() => _RemixCreditRowState();
}

class _RemixCreditRowState extends State<RemixCreditRow> {
  PrismWallpaper? _original;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant RemixCreditRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.remixOfDocId != widget.remixOfDocId ||
        oldWidget.repository != widget.repository ||
        !_sameViewer(oldWidget.viewer, widget.viewer)) {
      _original = null;
      _load();
    }
  }

  Future<void> _load() async {
    final int generation = ++_loadGeneration;
    final WallRemixRepository repository = widget.repository ?? getIt<WallRemixRepository>();
    try {
      final WallViewer viewer = widget.viewer ?? await currentWallViewer(repository);
      final PrismWallpaper? wall = await repository.fetchApprovedWall(widget.remixOfDocId);
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _original = wall != null && wall.aiSource != null && viewer.canFullyView(wall) ? wall : null);
    } catch (_) {
      if (mounted && generation == _loadGeneration) setState(() => _original = null);
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PrismWallpaper? original = _original;
    if (original == null) return const SizedBox.shrink();
    final AppLocalizations l10n = context.l10n;
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String? title = _nonBlank(original.title);
    final String? creator = _nonBlank(original.core.authorName);
    return Semantics(
      button: true,
      child: Tooltip(
        message: l10n.wallRemixOfTooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(PrismRadius.sm),
            onTap: () => context.router.push(
              WallpaperDetailRoute(
                entity: FeedItemEntity.prism(id: original.id, wallpaper: original),
              ),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: PrismImageTile(url: original.thumbnailUrl, borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.wallRemixOfLabel(title ?? l10n.wallRemixUntitled, creator ?? l10n.wallRemixUnknownCreator),
                      style: PrismTextStyles.body(context).copyWith(color: cs.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 20, color: cs.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String? _nonBlank(String? value) => value == null || value.trim().isEmpty ? null : value.trim();

bool _sameViewer(WallViewer? first, WallViewer? second) =>
    identical(first, second) ||
    (first != null &&
        second != null &&
        first.isPremium == second.isPremium &&
        listEquals(first.premiumCollections, second.premiumCollections) &&
        setEquals(first.blockedCreatorUids, second.blockedCreatorUids));
