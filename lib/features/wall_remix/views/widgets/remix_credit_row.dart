import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/wall_remix/biz/remix_credit_cubit.dart';
import 'package:Prism/features/wall_remix/domain/wall_remix.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A line under the detail panel that names the wall a remix started from. It shows nothing while it loads, when the
/// original is missing or withheld from this viewer, or when the lookup fails.
class RemixCreditRow extends StatefulWidget {
  const RemixCreditRow({required this.remixOfDocId, this.viewer, this.cubit, super.key});

  final String remixOfDocId;
  final WallViewer? viewer;
  final RemixCreditCubit? cubit;

  @override
  State<RemixCreditRow> createState() => _RemixCreditRowState();
}

class _RemixCreditRowState extends State<RemixCreditRow> {
  late final RemixCreditCubit _cubit;
  late final bool _ownsCubit;

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? getIt<RemixCreditCubit>();
    _load();
  }

  @override
  void didUpdateWidget(covariant RemixCreditRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.remixOfDocId != widget.remixOfDocId || !_sameViewer(oldWidget.viewer, widget.viewer)) {
      _load();
    }
  }

  void _load() => unawaited(_cubit.load(widget.remixOfDocId, viewer: widget.viewer));

  @override
  void dispose() {
    if (_ownsCubit) unawaited(_cubit.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RemixCreditCubit, RemixCreditState>(
      bloc: _cubit,
      builder: (context, state) {
        switch (state) {
          case RemixCreditShown(:final original):
            return _credit(context, original);
          case RemixCreditLoading():
          case RemixCreditHidden():
            return const SizedBox.shrink();
        }
      },
    );
  }

  Widget _credit(BuildContext context, PrismWallpaper original) {
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
        first.blockedCreators == second.blockedCreators);
