import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/widgets/glint/glint.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// A modal bottom sheet with the app's shared shape, colour and open and close animation.
Future<T?> showPrismSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  bool isDismissible = true,
  bool enableDrag = true,
  Color? backgroundColor,
  ShapeBorder? shape,
  bool showDragHandle = false,
  bool useRootNavigator = false,
}) {
  final bool reduce = context.reduceMotion;
  return showModalBottomSheet<T>(
    context: context,
    builder: builder,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: backgroundColor,
    shape: shape,
    showDragHandle: showDragHandle,
    useRootNavigator: useRootNavigator,
    sheetAnimationStyle: AnimationStyle(
      duration: reduce ? Duration.zero : const Duration(milliseconds: 280),
      reverseDuration: reduce ? Duration.zero : const Duration(milliseconds: 180),
      curve: PrismCurves.sheet,
      reverseCurve: PrismCurves.exit,
    ),
  );
}

/// The inside of a sheet: drag handle, an optional Glint, a headline, body text, content and actions.
/// Every sheet in the app uses this so handles, margins and type match.
class PrismSheetBody extends StatelessWidget {
  const PrismSheetBody({
    super.key,
    this.title,
    this.message,
    this.mood,
    this.child,
    this.actions = const <Widget>[],
    this.centered = false,
    this.scrollable = false,
  });

  final String? title;
  final String? message;

  /// Shows Glint above the title in this mood. Use it for moments, not for plain pickers.
  final GlintMood? mood;
  final Widget? child;

  /// Stacked full-width at the bottom, main action first.
  final List<Widget> actions;

  /// Centres the Glint, title and message.
  final bool centered;

  /// Lets [child] scroll when the sheet is tall. Use with `isScrollControlled: true`.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final CrossAxisAlignment align = centered ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final TextAlign textAlign = centered ? TextAlign.center : TextAlign.start;
    final Widget handle = Center(
      child: Container(
        margin: const EdgeInsets.only(top: PrismBottomSheet.topGap, bottom: PrismSpace.md),
        width: PrismBottomSheet.dragHandleWidth,
        height: PrismBottomSheet.dragHandleHeight,
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(PrismRadius.pill),
        ),
      ),
    );
    final Widget head = Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (mood != null) ...<Widget>[Glint(mood: mood!, size: 88), const SizedBox(height: PrismSpace.sm)],
        if (title != null)
          Semantics(
            header: true,
            child: Text(title!, textAlign: textAlign, style: PrismTextStyles.sheetHeadline(context)),
          ),
        if (message != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(message!, textAlign: textAlign, style: PrismTextStyles.body(context).copyWith(height: 1.4)),
        ],
      ],
    );
    final Widget? content = child == null
        ? null
        : Padding(
            padding: EdgeInsets.only(top: title != null || message != null || mood != null ? PrismSpace.md : 0),
            child: child,
          );
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: PrismSpace.page,
          right: PrismSpace.page,
          bottom: PrismSpace.md + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            handle,
            if (scrollable)
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[head, ?content],
                  ),
                ),
              )
            else ...<Widget>[head, ?content],
            if (actions.isNotEmpty) const SizedBox(height: PrismSpace.lg),
            for (int i = 0; i < actions.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: PrismSpace.xs),
              actions[i],
            ],
          ],
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
  String cancelLabel = 'Cancel',
  bool destructive = false,
  GlintMood? mood,
}) async {
  final bool? ok = await showPrismSheet<bool>(
    context: context,
    isScrollControlled: true,
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
          label: cancelLabel,
          expand: true,
          variant: PrismButtonVariant.ghost,
          onPressed: () => Navigator.of(sheetContext).pop(false),
        ),
      ],
    ),
  );
  return ok ?? false;
}
