import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/auth/require_signed_in_action.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/localized_relative_time.dart';
import 'package:Prism/core/widgets/content_report/content_report_sheet.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/favourite_walls/biz/favourite_counts_cubit.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/features/user_blocks/user_block_actions.dart';
import 'package:Prism/features/wall_comments/biz/wall_comments_cubit.dart';
import 'package:Prism/features/wall_comments/data/wall_comments_repository.dart';
import 'package:Prism/features/wall_comments/domain/wall_comment.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The wall a comments sheet belongs to. [wallId] is the Firestore doc id, [statsId] the logical id whose stats doc
/// holds the count, and [creatorUid] the wall's creator (empty for legacy walls).
typedef CommentsWall = ({String wallId, String statsId, String creatorUid});

/// Opens the comments of one wall. Guests and signed-out users can read; the composer asks them to sign in.
Future<void> showWallCommentsSheet(BuildContext context, CommentsWall wall, {WallCommentsCubit? cubit}) {
  unawaited(analytics.track(const CommentsSheetOpenedEvent()));
  PrismHaptics.tap();
  return showPrismSheet<void>(
    context,
    // Full height only: at the medium stop the keyboard leaves the list no room above the composer.
    detents: const <PrismSheetDetent>[PrismSheetDetent.large],
    dismissKeyboardOnDrag: true,
    builder: (_) => BlocProvider<WallCommentsCubit>(
      create: (_) => (cubit ?? _cubitFor(wall))..load(),
      child: WallCommentsSheet(wall: wall),
    ),
  );
}

CommentViewer? _viewer() {
  final user = app_state.prismUser;
  if (!user.loggedIn || user.id.trim().isEmpty) return null;
  return (uid: user.id.trim(), name: user.name.trim().isEmpty ? user.username : user.name, photo: user.profilePhoto);
}

WallCommentsCubit _cubitFor(CommentsWall wall) {
  final UserBlockRepository blocks = getIt<UserBlockRepository>();
  return WallCommentsCubit(
    wallId: wall.wallId,
    repository: getIt<WallCommentsRepository>(),
    viewer: _viewer(),
    blockedCreators: blocks.watchBlockedCreators(),
    initialBlocked: blocks.blockedCreators,
  );
}

String commentRefusalMessage(CommentRefusal refusal, AppLocalizations l10n) => switch (refusal) {
  CommentRefusal.disabled => l10n.commentErrorDisabled,
  CommentRefusal.guest => l10n.commentErrorGuest,
  CommentRefusal.tooNew => l10n.commentErrorTooNew,
  CommentRefusal.wallUnavailable => l10n.commentErrorWallUnavailable,
  CommentRefusal.empty => l10n.commentErrorEmpty,
  CommentRefusal.tooLong => l10n.commentErrorTooLong,
  CommentRefusal.hiddenCharacters => l10n.commentErrorHiddenCharacters,
  CommentRefusal.blockedWord => l10n.commentErrorBlockedWord,
  CommentRefusal.blocked => l10n.commentErrorBlocked,
  CommentRefusal.tooFast => l10n.commentErrorTooFast,
  CommentRefusal.dailyLimit => l10n.commentErrorDailyLimit,
  CommentRefusal.failed => l10n.commentPostFailed,
};

class WallCommentsSheet extends StatelessWidget {
  const WallCommentsSheet({super.key, required this.wall});

  final CommentsWall wall;

  @override
  Widget build(BuildContext context) {
    return PrismSheetBody(
      title: context.l10n.commentsTitle,
      childScrolls: true,
      actions: <Widget>[CommentComposer(wall: wall)],
      child: BlocBuilder<WallCommentsCubit, WallCommentsState>(
        builder: (BuildContext context, WallCommentsState state) {
          final List<WallComment> shown = state.shown;
          return switch (state.status) {
            CommentsStatus.loading => PrismSkeleton.rows(rows: 6),
            CommentsStatus.failed => Center(
              child: SingleChildScrollView(
                child: GlintState(
                  glintSize: 64,
                  padding: const EdgeInsets.all(PrismSpace.md),
                  kind: GlintStateKind.error,
                  title: context.l10n.commentsLoadFailed,
                  actionLabel: context.l10n.commentsRetry,
                  onAction: context.read<WallCommentsCubit>().load,
                ),
              ),
            ),
            CommentsStatus.ready when shown.isEmpty => Center(
              child: SingleChildScrollView(
                child: GlintState(
                  glintSize: 64,
                  padding: const EdgeInsets.all(PrismSpace.md),
                  kind: GlintStateKind.empty,
                  title: context.l10n.commentsEmptyTitle,
                  body: context.l10n.commentsEmptyBody,
                  actionLabel: state.hasMore ? context.l10n.commentsRetry : null,
                  onAction: state.hasMore ? context.read<WallCommentsCubit>().loadMore : null,
                ),
              ),
            ),
            CommentsStatus.ready => _CommentList(wall: wall, state: state, shown: shown),
          };
        },
      ),
    );
  }
}

class _CommentList extends StatelessWidget {
  const _CommentList({required this.wall, required this.state, required this.shown});

  final CommentsWall wall;
  final WallCommentsState state;
  final List<WallComment> shown;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification n) {
          if (n.metrics.extentAfter < 400) unawaited(context.read<WallCommentsCubit>().loadMore());
          return false;
        },
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(PrismSpace.page, 0, PrismSpace.page, PrismSpace.md),
          itemCount: shown.length + (state.hasMore ? 1 : 0),
          itemBuilder: (BuildContext context, int i) => i == shown.length
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: PrismSpace.md),
                  child: Center(
                    child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                )
              : CommentRow(key: ValueKey<String>(shown[i].id), comment: shown[i], wall: wall),
        ),
      ),
    );
  }
}

/// One comment: avatar, name (opens the profile), a Creator label, the time and the text. Long press for options.
class CommentRow extends StatelessWidget {
  const CommentRow({super.key, required this.comment, required this.wall});

  final WallComment comment;
  final CommentsWall wall;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String name = comment.authorName.trim().isEmpty ? l10n.commentAuthorFallback : comment.authorName.trim();
    final bool byCreator = comment.authorUid.isNotEmpty && comment.authorUid == wall.creatorUid;
    final String time = localizedRelativeTime(l10n, comment.createdAt, locale: Localizations.localeOf(context));
    final VoidCallback? openProfile = comment.authorUid.isEmpty || comment.pending
        ? null
        : () {
            final StackRouter router = context.router;
            Navigator.of(context).pop();
            unawaited(router.push(ProfileRoute(profileIdentifier: comment.authorUid)));
          };
    final Widget row = Semantics(
      container: true,
      onLongPressHint: comment.pending ? null : l10n.commentOptionsHint,
      onLongPress: comment.pending ? null : () => showCommentMenu(context, comment, wall),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: comment.pending ? null : () => showCommentMenu(context, comment, wall),
        child: AnimatedOpacity(
          opacity: comment.pending ? 0.55 : 1,
          duration: context.motion(PrismDurations.fast),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: PrismSpace.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Semantics(
                  button: openProfile != null,
                  label: name,
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: openProfile,
                    child: PrismAvatar(url: comment.authorPhoto, name: name, size: 36),
                  ),
                ),
                const SizedBox(width: PrismSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        spacing: PrismSpace.xs,
                        runSpacing: PrismSpace.xxs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Semantics(
                            button: openProfile != null,
                            child: GestureDetector(
                              onTap: openProfile,
                              child: Text(name, style: PrismTextStyles.rowTitle(context)),
                            ),
                          ),
                          if (byCreator) PrismTag(label: l10n.commentCreatorLabel, tone: PrismTone.accent),
                          Text(time, style: PrismTextStyles.caption(context)),
                        ],
                      ),
                      const SizedBox(height: PrismSpace.xxs),
                      Text(
                        comment.text,
                        style: PrismTextStyles.body(context).copyWith(color: cs.onSurface, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!comment.pending) return row;
    // Only the viewer's own new comment arrives with motion. Rows that load with the list do not animate in.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: context.motion(PrismDurations.base),
      curve: PrismCurves.enter,
      builder: (_, double t, Widget? child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 8 * (1 - t)), child: child),
      ),
      child: row,
    );
  }
}

/// Report, Block and Delete, each only where it applies to the viewer.
Future<void> showCommentMenu(BuildContext context, WallComment comment, CommentsWall wall) async {
  final AppLocalizations l10n = context.l10n;
  final WallCommentsCubit cubit = context.read<WallCommentsCubit>();
  final String me = app_state.prismUser.loggedIn ? app_state.prismUser.id.trim() : '';
  final CommentRoleValue? role = me.isEmpty
      ? null
      : comment.authorUid == me
      ? CommentRoleValue.author
      : wall.creatorUid.isNotEmpty && wall.creatorUid == me
      ? CommentRoleValue.creator
      : app_state.isAdminUser()
      ? CommentRoleValue.admin
      : null;
  final bool mine = me.isNotEmpty && comment.authorUid == me;
  final String name = comment.authorName.trim().isEmpty ? l10n.commentAuthorFallback : comment.authorName.trim();
  PrismHaptics.tap();
  final String? choice = await showPrismSheet<String>(
    context,
    detents: const <PrismSheetDetent>[PrismSheetDetent.fit],
    builder: (BuildContext sheet) => PrismSheetBody(
      child: PrismGroup(
        children: <Widget>[
          if (!mine)
            PrismRow(
              icon: Icons.flag_outlined,
              title: l10n.commentReport,
              showChevron: false,
              onTap: () => Navigator.of(sheet).pop('report'),
            ),
          if (!mine && me.isNotEmpty && comment.authorUid.isNotEmpty)
            PrismRow(
              icon: Icons.person_off_outlined,
              title: l10n.commentBlockUser(name),
              showChevron: false,
              onTap: () => Navigator.of(sheet).pop('block'),
            ),
          if (role != null)
            PrismRow(
              icon: Icons.delete_outline_rounded,
              title: l10n.commentDelete,
              destructive: true,
              showChevron: false,
              onTap: () => Navigator.of(sheet).pop('delete'),
            ),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  switch (choice) {
    case 'report':
      unawaited(analytics.track(const CommentReportedEvent()));
      await showContentReportSheet(
        context,
        contentType: 'comment',
        targetFirestoreDocId: '${wall.wallId}:${comment.id}',
        subtitle: comment.text,
        onBlockCreator: me.isEmpty || comment.authorUid.isEmpty
            ? null
            : () =>
                  unawaited(confirmAndBlockUser(context: context, targetUserId: comment.authorUid, displayName: name)),
      );
    case 'block':
      await confirmAndBlockUser(context: context, targetUserId: comment.authorUid, displayName: name);
    case 'delete' when role != null:
      final bool ok = await showPrismConfirm(
        context,
        title: l10n.commentDeleteConfirmTitle,
        message: l10n.commentDeleteConfirmBody,
        confirmLabel: l10n.commentDelete,
        destructive: true,
      );
      if (!ok || !context.mounted) return;
      if (await cubit.delete(comment)) {
        unawaited(analytics.track(CommentDeletedEvent(role: role)));
        getIt<FavouriteCountsCubit>().request(wall.statsId, force: true);
        toasts.success(l10n.commentDeleted);
      } else {
        toasts.error(l10n.commentDeleteFailed);
      }
  }
}

/// The text field and Send, or "Sign in to comment" for a guest. A refusal shows under the field and keeps the text.
class CommentComposer extends StatefulWidget {
  const CommentComposer({super.key, required this.wall});

  final CommentsWall wall;

  @override
  State<CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends State<CommentComposer> {
  static const int _counterFrom = 50;
  final TextEditingController _text = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final WallCommentsCubit cubit = context.read<WallCommentsCubit>();
    final AppLocalizations l10n = context.l10n;
    final String text = _text.text;
    cubit.updateViewer(_viewer());
    PrismHaptics.tap();
    _text.clear();
    setState(() => _error = null);
    final CommentRefusal? refusal = await cubit.send(text);
    if (!mounted) return;
    if (refusal == null) {
      unawaited(analytics.track(const CommentPostedEvent()));
      getIt<FavouriteCountsCubit>().request(widget.wall.statsId, force: true);
      return;
    }
    unawaited(analytics.track(CommentRefusedEvent(reason: refusal.wire.isEmpty ? 'failed' : refusal.wire)));
    if (_text.text.isEmpty) _text.text = text;
    setState(() => _error = commentRefusalMessage(refusal, l10n));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    if (!app_state.prismUser.loggedIn) {
      return PrismButton(
        label: l10n.commentSignInToComment,
        variant: PrismButtonVariant.tonal,
        expand: true,
        onPressed: () async {
          if (await requireSignedInAction(context) && context.mounted) {
            context.read<WallCommentsCubit>().updateViewer(_viewer());
            setState(() {});
          }
        },
      );
    }
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool sending = context.select((WallCommentsCubit c) => c.state.sending);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _text,
      builder: (BuildContext context, TextEditingValue value, _) {
        final int length = value.text.trim().characters.length;
        final int left = kCommentMaxLength - length;
        final bool canSend = !sending && length > 0 && left >= 0;
        final String? counter = left < 0
            ? l10n.commentCharactersOver(-left)
            : left <= _counterFrom
            ? l10n.commentCharactersLeft(left)
            : null;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _text,
                    minLines: 1,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    style: PrismTextStyles.body(context).copyWith(color: cs.onSurface),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    decoration: InputDecoration(
                      hintText: l10n.commentComposerHint,
                      filled: true,
                      fillColor: cs.onSurface.withValues(alpha: 0.06),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: PrismSpace.md, vertical: PrismSpace.sm),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(PrismRadius.lg),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: PrismSpace.xs),
                PrismIconButton(
                  icon: Icons.arrow_upward_rounded,
                  tooltip: l10n.commentSend,
                  filled: true,
                  color: canSend ? cs.primary : null,
                  onPressed: canSend ? _send : null,
                ),
              ],
            ),
            if (_error != null || counter != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(PrismSpace.md, PrismSpace.xxs, PrismSpace.md, 0),
                child: Semantics(
                  liveRegion: _error != null,
                  child: Text(
                    _error ?? counter!,
                    style: PrismTextStyles.caption(
                      context,
                    ).copyWith(color: _error != null || left < 0 ? cs.error : null),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
