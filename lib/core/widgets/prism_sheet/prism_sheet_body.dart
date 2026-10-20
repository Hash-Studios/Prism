import 'dart:math' as math;

import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/widgets/glint/glint.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/core/widgets/prism_sheet/prism_sheet_route.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

/// A text action in the header's trailing slot, opposite the close button. Use it for an action that does not commit
/// the sheet ("Clear", "Reset", "Skip"). The committing action goes in [PrismSheetBody.actions].
@immutable
class PrismSheetAction {
  const PrismSheetAction({required this.label, required this.onTap});

  final String label;

  /// Null disables the action.
  final VoidCallback? onTap;
}

/// The inside of every sheet opened with [showPrismSheet].
///
/// The header holds the drag handle, a close button on the left, the [title] in the centre and an optional
/// [trailingAction] on the right. The body holds an optional Glint, the [message] and the [child]. The [actions] stay
/// pinned to the bottom while the body scrolls.
class PrismSheetBody extends StatelessWidget {
  const PrismSheetBody({
    super.key,
    this.title,
    this.message,
    this.mood,
    this.child,
    this.actions = const <Widget>[],
    this.trailingAction,
    this.centered = false,
    this.childScrolls = false,
    this.showHandle = true,
    this.showCloseButton = true,
  });

  /// The sheet title. On a sheet with a [mood] it shows as a headline under Glint instead of in the header.
  final String? title;
  final String? message;

  /// Shows Glint above the title in this mood. Use it for moments, not for plain pickers.
  final GlintMood? mood;
  final Widget? child;

  /// Stacked full-width and pinned to the bottom, main action first.
  final List<Widget> actions;
  final PrismSheetAction? trailingAction;

  /// Centres the Glint, the headline and the message.
  final bool centered;

  /// Set when [child] is its own scroll view (a long list or grid). The body then gives it the space that is left
  /// instead of wrapping it in a scroll view, and does not pad it.
  final bool childScrolls;

  /// Hide the drag handle on a sheet that cannot be dragged away.
  final bool showHandle;

  /// Hide the close button on a sheet the user must answer.
  final bool showCloseButton;

  /// Below this much height (screen minus keyboard) the actions stop being pinned.
  static const double _minRoomToPinActions = 400;

  @override
  Widget build(BuildContext context) {
    final bool moment = mood != null;
    final CrossAxisAlignment align = centered ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final TextAlign textAlign = centered ? TextAlign.center : TextAlign.start;
    final List<Widget> head = <Widget>[
      if (moment) ...<Widget>[Glint(mood: mood!, size: 88), const SizedBox(height: PrismSpace.sm)],
      if (moment && title != null)
        Semantics(
          header: true,
          child: Text(title!, textAlign: textAlign, style: PrismTextStyles.sheetHeadline(context)),
        ),
      if (message != null) ...<Widget>[
        if (moment && title != null) const SizedBox(height: 6),
        Text(message!, textAlign: textAlign, style: PrismTextStyles.body(context).copyWith(height: 1.4)),
      ],
    ];
    final bool hasHead = head.isNotEmpty;
    // In a short window with the keyboard up, pinned actions would leave no room for the body. There they scroll
    // with it instead.
    final double room = MediaQuery.sizeOf(context).height - MediaQuery.viewInsetsOf(context).bottom;
    final bool pinActions = childScrolls || room >= _minRoomToPinActions;
    final Widget? actionStack = actions.isEmpty
        ? null
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int i = 0; i < actions.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(height: PrismSpace.xs),
                actions[i],
              ],
            ],
          );
    final Widget body = childScrolls
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (hasHead)
                Padding(
                  padding: PrismBottomSheet.bodyPadding.copyWith(bottom: PrismSpace.md),
                  child: Column(crossAxisAlignment: align, children: head),
                ),
              Expanded(child: child ?? const SizedBox.shrink()),
            ],
          )
        : SingleChildScrollView(
            padding: PrismBottomSheet.bodyPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (hasHead) Column(crossAxisAlignment: align, children: head),
                if (child != null) ...<Widget>[if (hasHead) const SizedBox(height: PrismSpace.md), child!],
                if (!pinActions && actionStack != null) ...<Widget>[const SizedBox(height: PrismSpace.lg), actionStack],
              ],
            ),
          );
    return SheetContentScaffold(
      backgroundColor: Colors.transparent,
      // The sheet already sits above the keyboard, so the bar must not move up again.
      bottomBarVisibility: const BottomBarVisibility.always(ignoreBottomInset: true),
      topBar: _PrismSheetHeader(
        title: moment ? null : title,
        trailingAction: trailingAction,
        showHandle: showHandle,
        showCloseButton: showCloseButton,
      ),
      bottomBar: !pinActions || actionStack == null
          ? null
          : Material(
              type: MaterialType.transparency,
              child: Padding(padding: PrismBottomSheet.actionsPadding, child: actionStack),
            ),
      body: Material(type: MaterialType.transparency, child: body),
    );
  }
}

/// The handle and the header row. It sizes to its content, so a long translated title can take two lines.
class _PrismSheetHeader extends StatelessWidget {
  const _PrismSheetHeader({
    required this.title,
    required this.trailingAction,
    required this.showHandle,
    required this.showCloseButton,
  });

  final String? title;
  final PrismSheetAction? trailingAction;
  final bool showHandle;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context) {
    final bool hasRow = title != null || showCloseButton || trailingAction != null;
    if (!showHandle && !hasRow) return const SizedBox(height: PrismSpace.md);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Widget? close = showCloseButton
        ? PrismIconButton(
            icon: Icons.close_rounded,
            tooltip: context.l10n.actionClose,
            filled: true,
            size: PrismBottomSheet.closeButtonSize,
            iconSize: 20,
            onPressed: () {
              PrismHaptics.tap();
              Navigator.of(context).maybePop();
            },
          )
        : null;
    final Widget? action = trailingAction == null ? null : _TrailingAction(action: trailingAction!);
    // Both sides take the width of the wider one, so the title stays centred on the row.
    final double slot = math.max(
      PrismBottomSheet.headerSlotWidth,
      trailingAction == null ? 0 : _TrailingAction.width(context, trailingAction!.label),
    );
    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: Container(
              width: PrismBottomSheet.dragHandleWidth,
              height: PrismBottomSheet.dragHandleHeight,
              decoration: showHandle
                  ? BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(PrismBottomSheet.dragHandleRadius),
                    )
                  : null,
            ),
          ),
          if (hasRow)
            Padding(
              padding: PrismBottomSheet.headerPadding,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: PrismBottomSheet.headerRowHeight),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: slot,
                      child: Align(alignment: Alignment.centerLeft, child: close),
                    ),
                    const SizedBox(width: PrismSpace.xs),
                    Expanded(
                      child: title == null
                          ? const SizedBox.shrink()
                          : Semantics(
                              header: true,
                              child: Text(
                                title!,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: PrismTextStyles.cardTitle(context),
                              ),
                            ),
                    ),
                    const SizedBox(width: PrismSpace.xs),
                    ConstrainedBox(
                      constraints: BoxConstraints(minWidth: slot),
                      child: Align(alignment: Alignment.centerRight, widthFactor: 1, child: action),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrailingAction extends StatelessWidget {
  const _TrailingAction({required this.action});

  final PrismSheetAction action;

  static const EdgeInsets _padding = EdgeInsets.only(left: PrismSpace.xs, right: PrismSpace.xxs);

  /// The width this action takes in the header for [label].
  static double width(BuildContext context, String label) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: label, style: PrismTextStyles.button),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final double width = painter.width.ceilToDouble() + _padding.horizontal;
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool enabled = action.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: action.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: action.onTap,
        // Align with a width factor: an aligned Container would fill the toolbar and push the title off centre.
        child: SizedBox(
          height: PrismBottomSheet.headerRowHeight,
          child: Align(
            alignment: Alignment.centerRight,
            widthFactor: 1,
            child: Padding(
              padding: _padding,
              child: Text(
                action.label,
                maxLines: 1,
                style: PrismTextStyles.button.copyWith(
                  color: enabled ? cs.primary : cs.onSurface.withValues(alpha: 0.38),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks the user to confirm an action in a sheet. Resolves true only when they tap [confirmLabel].
///
/// [confirmLabel] names the action ("Delete wallpaper", "Sign out"), never "Yes" or "OK".
Future<bool> showPrismConfirm(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String? message,
  String? cancelLabel,
  bool destructive = false,
  GlintMood? mood,
}) async {
  final String resolvedCancelLabel = cancelLabel ?? context.l10n.coreCancel;
  final bool? ok = await showPrismSheet<bool>(
    context,
    detents: const <PrismSheetDetent>[PrismSheetDetent.fit],
    builder: (sheetContext) => PrismSheetBody(
      title: title,
      message: message,
      mood: mood,
      centered: mood != null,
      actions: <Widget>[
        PrismButton(
          label: confirmLabel,
          expand: true,
          variant: destructive ? PrismButtonVariant.danger : PrismButtonVariant.primary,
          onPressed: () => Navigator.of(sheetContext).pop(true),
        ),
        PrismButton(
          label: resolvedCancelLabel,
          expand: true,
          variant: PrismButtonVariant.ghost,
          onPressed: () => Navigator.of(sheetContext).pop(false),
        ),
      ],
    ),
  );
  return ok ?? false;
}
