import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// The header of every page: an optional back button, a large title and trailing actions.
class PrismHeader extends StatelessWidget {
  const PrismHeader({
    super.key,
    required this.title,
    this.showBack = true,
    this.onBack,
    this.actions = const <Widget>[],
    this.titleWidget,
  });

  final String title;
  final bool showBack;

  /// Defaults to popping the current route.
  final VoidCallback? onBack;
  final List<Widget> actions;

  /// Replaces the title text, for example a search field. [title] stays the screen reader label.
  final Widget? titleWidget;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        showBack ? PrismSpace.xs : PrismSpace.page,
        PrismSpace.xs,
        PrismSpace.sm,
        PrismSpace.xs,
      ),
      child: SizedBox(
        height: 48,
        child: Row(
          children: <Widget>[
            if (showBack) ...<Widget>[
              PrismIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Back',
                onPressed: onBack ?? () => context.router.maybePop(),
              ),
              const SizedBox(width: PrismSpace.xxs),
            ],
            Expanded(
              child:
                  titleWidget ??
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: showBack
                          ? PrismTextStyles.screenTitle(context).copyWith(fontSize: 22)
                          : PrismTextStyles.screenTitle(context),
                    ),
                  ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

/// A page with the shared [PrismHeader] pinned above [body]. A hairline appears under the header once the body
/// scrolls, so content never runs into the title without a boundary.
class PrismPage extends StatefulWidget {
  const PrismPage({
    super.key,
    required this.title,
    required this.body,
    this.showBack = true,
    this.onBack,
    this.actions = const <Widget>[],
    this.titleWidget,
    this.headerBottom,
    this.bottomBar,
    this.resizeToAvoidBottomInset = true,
  });

  final String title;
  final Widget body;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final Widget? titleWidget;

  /// Pinned under the header, for example a tab bar or a filter row.
  final Widget? headerBottom;

  /// Pinned at the bottom, for example the page's main action.
  final Widget? bottomBar;
  final bool resizeToAvoidBottomInset;

  @override
  State<PrismPage> createState() => _PrismPageState();
}

class _PrismPageState extends State<PrismPage> {
  bool _scrolled = false;

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical || n.depth != 0) return false;
    final bool scrolled = n.metrics.pixels > 2;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
      bottomNavigationBar: widget.bottomBar == null
          ? null
          // The keyboard inset keeps the action above the keyboard.
          : Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
              child: SafeArea(
                minimum: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xs, PrismSpace.page, PrismSpace.md),
                child: widget.bottomBar!,
              ),
            ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            PrismHeader(
              title: widget.title,
              showBack: widget.showBack,
              onBack: widget.onBack,
              actions: widget.actions,
              titleWidget: widget.titleWidget,
            ),
            if (widget.headerBottom != null) widget.headerBottom!,
            AnimatedOpacity(
              opacity: _scrolled ? 1 : 0,
              duration: context.motion(PrismDurations.fast),
              child: Divider(height: 1, color: cs.onSurface.withValues(alpha: 0.08)),
            ),
            Expanded(
              child: NotificationListener<ScrollNotification>(onNotification: _onScroll, child: widget.body),
            ),
          ],
        ),
      ),
    );
  }
}
