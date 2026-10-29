import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:Prism/features/moods/views/mood_copy.dart';
import 'package:Prism/features/wall_requests/domain/entities/wall_request.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// The copy for a failed request action. The page toast and the sheet both use it.
String wallRequestErrorText(BuildContext context, WallRequestError error) {
  final AppLocalizations l10n = context.l10n;
  return switch (error) {
    WallRequestError.textRejected => l10n.wallRequestErrorText,
    WallRequestError.dailyLimit => l10n.wallRequestErrorLimit,
    WallRequestError.ownRequest => l10n.wallRequestErrorOwn,
    WallRequestError.closed => l10n.wallRequestErrorClosed,
    WallRequestError.missing => l10n.wallRequestErrorGone,
    WallRequestError.signedOut => l10n.wallRequestSignIn,
    WallRequestError.accountTooNew => l10n.wallRequestErrorAccountAge,
    WallRequestError.unknown => l10n.wallRequestErrorGeneric,
  };
}

/// A tag as the user reads it. Mood ids show the mood title. Category names show as they are.
String wallRequestTagLabel(BuildContext context, String tag) {
  final WallMood? mood = WallMood.parse(tag);
  return mood == null ? tag : mood.title(context.l10n);
}

/// How long ago a request was made, in words.
String wallRequestAge(BuildContext context, DateTime createdAt, {DateTime? now}) {
  final AppLocalizations l10n = context.l10n;
  final Duration age = (now ?? DateTime.now()).difference(createdAt);
  if (age < const Duration(minutes: 1)) return l10n.wallRequestAgeNow;
  if (age < const Duration(hours: 1)) return l10n.wallRequestAgeMinutes(age.inMinutes);
  if (age < const Duration(days: 1)) return l10n.wallRequestAgeHours(age.inHours);
  if (age < const Duration(days: 14)) return l10n.wallRequestAgeDays(age.inDays);
  return l10n.wallRequestAgeWeeks(age.inDays ~/ 7);
}

/// One request in a list: the text, its tags, a meta line and the vote on the trailing side. A filled request shows
/// its wall as a thumbnail on the leading side.
class WallRequestRow extends StatelessWidget {
  const WallRequestRow({
    super.key,
    required this.request,
    required this.onVote,
    this.onOpenWall,
    this.onReport,
    this.onToggleHidden,
    this.isAdmin = false,
  });

  final WallRequest request;

  /// Null disables the vote button.
  final VoidCallback? onVote;
  final VoidCallback? onOpenWall;
  final VoidCallback? onReport;
  final VoidCallback? onToggleHidden;

  /// Admins see hidden requests and get the hide and show actions.
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme cs = Theme.of(context).colorScheme;
    final WallRequest r = request;
    final Color soft = cs.onSurface.withValues(alpha: 0.6);
    final List<String> meta = <String>[
      l10n.wallRequestVotes(r.voteCount),
      wallRequestAge(context, r.createdAt),
      if (!r.mine)
        if (r.requesterName.isEmpty) l10n.wallRequestSomeone else r.requesterName,
    ];
    final List<PopupMenuEntry<VoidCallback>> menu = <PopupMenuEntry<VoidCallback>>[
      if (onReport != null) PopupMenuItem<VoidCallback>(value: onReport, child: Text(l10n.wallRequestReport)),
      if (isAdmin && onToggleHidden != null)
        PopupMenuItem<VoidCallback>(
          value: onToggleHidden,
          child: Text(r.hidden ? l10n.wallRequestUnhide : l10n.wallRequestHide),
        ),
    ];
    return PrismCard(
      padding: const EdgeInsets.all(PrismSpace.md),
      child: Row(
        children: <Widget>[
          if (r.isFilled) ...<Widget>[
            _Thumb(url: r.filledWallThumb, onTap: onOpenWall),
            const SizedBox(width: PrismSpace.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(r.text, maxLines: 3, overflow: TextOverflow.ellipsis, style: PrismTextStyles.rowTitle(context)),
                if (r.tags.isNotEmpty || r.hidden) ...<Widget>[
                  const SizedBox(height: PrismSpace.xs),
                  Wrap(
                    spacing: PrismSpace.xs,
                    runSpacing: PrismSpace.xs,
                    children: <Widget>[
                      if (r.hidden) _Tag(label: l10n.wallRequestHiddenLabel, color: cs.error),
                      for (final String tag in r.tags) _Tag(label: wallRequestTagLabel(context, tag)),
                    ],
                  ),
                ],
                const SizedBox(height: PrismSpace.xxs),
                Text(meta.join(' · '), style: PrismTextStyles.caption(context).copyWith(fontSize: 13, color: soft)),
                if (r.filledBy == WallRequestFiller.studio) ...<Widget>[
                  const SizedBox(height: PrismSpace.xxs),
                  Text(l10n.wallRequestFilledByStudio, style: PrismTextStyles.caption(context).copyWith(color: soft)),
                ],
              ],
            ),
          ),
          if (r.canVote && !r.isFilled)
            _VoteButton(voted: r.voted, count: r.voteCount, onPressed: onVote)
          else if (r.mine)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: PrismSpace.xs),
              child: Text(l10n.wallRequestMine, style: PrismTextStyles.caption(context).copyWith(color: soft)),
            ),
          if (menu.isNotEmpty)
            PopupMenuButton<VoidCallback>(
              tooltip: l10n.wallRequestMoreActions,
              icon: Icon(Icons.more_vert_rounded, color: soft),
              padding: const EdgeInsets.all(12),
              onSelected: (VoidCallback action) => action(),
              itemBuilder: (_) => menu,
            ),
        ],
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({required this.voted, required this.count, required this.onPressed});

  final bool voted;
  final int count;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String label = voted ? l10n.wallRequestRemoveUpvote : l10n.wallRequestUpvote;
    final Color fg = voted ? cs.onPrimary : cs.onSurface;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      toggled: voted,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(PrismRadius.pill),
            onTap: onPressed,
            child: AnimatedContainer(
              duration: context.motion(PrismDurations.fast),
              curve: PrismCurves.enter,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: PrismSpace.sm),
              decoration: BoxDecoration(
                color: voted ? cs.primary : cs.onSurface.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(PrismRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(Icons.arrow_upward_rounded, size: 18, color: fg),
                  const SizedBox(width: PrismSpace.xxs),
                  Text('$count', style: PrismTextStyles.rowTitle(context).copyWith(fontSize: 14, color: fg)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url, required this.onTap});

  final String url;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Widget placeholder = ColoredBox(
      color: cs.onSurface.withValues(alpha: 0.08),
      child: Icon(Icons.image_outlined, color: cs.onSurface.withValues(alpha: 0.38)),
    );
    final Widget image = url.isEmpty
        ? placeholder
        : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder);
    return Semantics(
      container: true,
      button: true,
      label: context.l10n.wallRequestOpenWall,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(PrismRadius.sm),
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(PrismRadius.sm),
            child: SizedBox.square(dimension: 56, child: image),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color fg = color ?? cs.onSurface.withValues(alpha: 0.8);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(PrismRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PrismSpace.xs, vertical: 3),
        child: Text(label, style: PrismTextStyles.caption(context).copyWith(fontSize: 12, color: fg)),
      ),
    );
  }
}
