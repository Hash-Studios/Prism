import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/analytics_enums.dart';
import 'package:Prism/core/analytics/events/generated/analytics_events.g.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/wall_requests/biz/wall_request_sheet_cubit.dart';
import 'package:Prism/features/wall_requests/domain/entities/wall_request.dart';
import 'package:Prism/features/wall_requests/views/widgets/wall_request_row.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Opens the request sheet. Returns the request made or upvoted, or null when the user closed the sheet.
Future<WallRequest?> showWallRequestSheet(
  BuildContext context, {
  required WallRequestSourceValue source,
  String initialText = '',
}) {
  unawaited(analytics.track(WallRequestSheetOpenedEvent(source: source)));
  return showPrismSheet<WallRequest>(
    context,
    // Search and Home have their own navigators under the floating nav bar; the root one puts the sheet above it.
    useRootNavigator: true,
    dismissKeyboardOnDrag: true,
    builder: (_) => BlocProvider<WallRequestSheetCubit>(
      create: (_) => getIt<WallRequestSheetCubit>(),
      child: WallRequestSheetBody(source: source, initialText: initialText),
    ),
  );
}

/// The inside of the request sheet. It needs a [WallRequestSheetCubit] above it. It pops with the request when the
/// cubit reaches done.
class WallRequestSheetBody extends StatefulWidget {
  const WallRequestSheetBody({super.key, required this.source, this.initialText = ''});

  final WallRequestSourceValue source;
  final String initialText;

  @override
  State<WallRequestSheetBody> createState() => _WallRequestSheetBodyState();
}

class _WallRequestSheetBodyState extends State<WallRequestSheetBody> {
  late final TextEditingController _text = TextEditingController(text: widget.initialText);
  final List<String> _tags = <String>[];

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _canSubmit => _text.text.trim().length >= wallRequestMinLength;

  void _submit(WallRequestSheetCubit cubit, {bool force = false}) {
    unawaited(cubit.submit(text: _text.text.trim(), tags: List<String>.of(_tags), source: widget.source, force: force));
  }

  void _toggleTag(String tag) {
    setState(() {
      if (!_tags.remove(tag)) _tags.add(tag);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!app_state.prismUser.loggedIn) return _signedOut(context);
    return BlocListener<WallRequestSheetCubit, WallRequestSheetState>(
      listener: (BuildContext context, WallRequestSheetState state) {
        if (state is! WallRequestSheetDone) return;
        final AppLocalizations l10n = context.l10n;
        showGlintToast(context);
        toasts.success(state.upvoted ? l10n.wallRequestUpvoted : l10n.wallRequestCreated);
        Navigator.of(context).pop(state.request);
      },
      child: BlocBuilder<WallRequestSheetCubit, WallRequestSheetState>(
        builder: (BuildContext context, WallRequestSheetState state) {
          final bool duplicate = state is WallRequestSheetDuplicate;
          return AnimatedSwitcher(
            duration: context.motion(PrismDurations.base),
            switchInCurve: PrismCurves.enter,
            switchOutCurve: PrismCurves.exit,
            transitionBuilder: (Widget child, Animation<double> animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: Tween<double>(begin: 0.95, end: 1).animate(animation), child: child),
            ),
            child: KeyedSubtree(
              key: ValueKey<bool>(duplicate),
              child: switch (state) {
                WallRequestSheetDuplicate(
                  :final WallRequest request,
                  :final bool exact,
                  :final WallRequestError? error,
                ) =>
                  _duplicate(context, request, exact: exact, error: error),
                WallRequestSheetEditing(:final WallRequestError? error) => _form(context, error: error, busy: false),
                WallRequestSheetBusy() || WallRequestSheetDone() => _form(context, error: null, busy: true),
              },
            ),
          );
        },
      ),
    );
  }

  Widget _signedOut(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return PrismSheetBody(
      title: l10n.wallRequestSheetTitle,
      message: l10n.wallRequestSignIn,
      actions: <Widget>[
        PrismButton(
          label: l10n.coreSignInPromptAction,
          expand: true,
          onPressed: () => unawaited(
            googleSignInPopUp(context, () {
              if (mounted) setState(() {});
            }),
          ),
        ),
      ],
    );
  }

  Widget _form(BuildContext context, {required WallRequestError? error, required bool busy}) {
    final AppLocalizations l10n = context.l10n;
    final bool full = _tags.length >= wallRequestMaxTags;
    final List<String> tags = <String>[...wallRequestCategoryTags, ...wallRequestMoodTags];
    return PrismSheetBody(
      title: l10n.wallRequestSheetTitle,
      actions: <Widget>[
        PrismButton(
          label: l10n.wallRequestSheetSubmit,
          expand: true,
          loading: busy,
          onPressed: busy || !_canSubmit ? null : () => _submit(context.read<WallRequestSheetCubit>()),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PrismTextField(
            controller: _text,
            hint: l10n.wallRequestSheetHint,
            maxLength: wallRequestMaxLength,
            autofocus: true,
            enabled: !busy,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            error: error == null ? null : wallRequestErrorText(context, error),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: PrismSpace.lg),
          Text(
            l10n.wallRequestSheetTags,
            style: PrismTextStyles.caption(context).copyWith(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: PrismSpace.xs),
          Wrap(
            spacing: PrismSpace.xs,
            runSpacing: PrismSpace.xs,
            children: <Widget>[
              for (final String tag in tags)
                _TagChip(
                  label: wallRequestTagLabel(context, tag),
                  selected: _tags.contains(tag),
                  enabled: !busy && (_tags.contains(tag) || !full),
                  onTap: () => _toggleTag(tag),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _duplicate(
    BuildContext context,
    WallRequest request, {
    required bool exact,
    required WallRequestError? error,
  }) {
    final AppLocalizations l10n = context.l10n;
    final WallRequestSheetCubit cubit = context.read<WallRequestSheetCubit>();
    final bool canUpvote = request.canVote && !request.voted;
    final String title = request.mine
        ? l10n.wallRequestDuplicateMine
        : request.voted
        ? l10n.wallRequestDuplicateVoted
        : l10n.wallRequestDuplicateTitle;
    final bool showBody = !request.mine && !request.voted;
    final ColorScheme cs = Theme.of(context).colorScheme;
    return PrismSheetBody(
      title: title,
      message: showBody ? l10n.wallRequestDuplicateBody : null,
      actions: <Widget>[
        if (canUpvote)
          PrismButton(
            label: l10n.wallRequestUpvoteInstead,
            expand: true,
            onPressed: () => unawaited(cubit.upvoteInstead()),
          ),
        if (!exact && !request.mine)
          PrismButton(
            label: l10n.wallRequestCreateAnyway,
            expand: true,
            variant: PrismButtonVariant.tonal,
            onPressed: () => _submit(cubit, force: true),
          ),
        PrismButton(
          label: l10n.wallRequestEditText,
          expand: true,
          variant: PrismButtonVariant.ghost,
          onPressed: cubit.edit,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PrismCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(request.text, style: PrismTextStyles.cardTitle(context)),
                const SizedBox(height: PrismSpace.xxs),
                Text(
                  l10n.wallRequestVotes(request.voteCount),
                  style: PrismTextStyles.caption(context).copyWith(color: cs.onSurface.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
          if (error != null) ...<Widget>[
            const SizedBox(height: PrismSpace.sm),
            Text(wallRequestErrorText(context, error), style: PrismTextStyles.body(context).copyWith(color: cs.error)),
          ],
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, required this.selected, required this.enabled, required this.onTap});

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.38,
      child: PrismChip(label: label, selected: selected, onTap: enabled ? onTap : null),
    );
  }
}
