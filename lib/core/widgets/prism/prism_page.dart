import 'dart:math' as math;

import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/core/widgets/prism/prism_max_width.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

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
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: <Widget>[
            if (showBack) ...<Widget>[
              PrismIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: context.l10n.coreBack,
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
                      maxLines: 2,
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
    this.maxContentWidth = PrismLayout.readableWidth,
  });

  final String title;
  final Widget body;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final Widget? titleWidget;

  /// Pinned under the header, for example a tab bar or a filter row.
  final Widget? headerBottom;

  /// Pinned at the bottom, for example the page's main action. A hairline shows on top while content scrolls under it.
  final Widget? bottomBar;
  final bool resizeToAvoidBottomInset;

  /// On a tablet the header, body and bottom bar sit in a centred column this wide. Pass [double.infinity] for a page
  /// whose body is a wallpaper grid, so the grid can use the whole screen.
  final double maxContentWidth;

  @override
  State<PrismPage> createState() => _PrismPageState();
}

class _PrismPageState extends State<PrismPage> {
  bool _scrolled = false;

  /// The body has more content below the fold, under the bottom bar.
  bool _moreBelow = false;
  TabController? _tabController;
  List<bool> _tabScroll = <bool>[];
  List<bool> _tabMore = <bool>[];

  void _setTabController(TabController? controller, int length) {
    if (identical(controller, _tabController) && _tabScroll.length == length) return;
    _tabController?.removeListener(_onTabChanged);
    _tabController = controller;
    _tabScroll = List<bool>.filled(length, false);
    _tabMore = List<bool>.filled(length, false);
    controller?.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    final int index = _tabController!.index;
    final bool scrolled = index < _tabScroll.length && _tabScroll[index];
    final bool more = index < _tabMore.length && _tabMore[index];
    if (scrolled != _scrolled || more != _moreBelow) {
      setState(() {
        _scrolled = scrolled;
        _moreBelow = more;
      });
    }
  }

  bool _onTabScroll(int index, ScrollMetrics metrics) {
    if (metrics.axis != Axis.vertical) return false;
    final bool scrolled = metrics.pixels > 2;
    final bool more = metrics.extentAfter > 2;
    _tabScroll[index] = scrolled;
    _tabMore[index] = more;
    if (_tabController?.index == index) _setScrollState(scrolled, more);
    return false;
  }

  bool _onScroll(ScrollMetrics metrics) {
    if (metrics.axis != Axis.vertical) return false;
    final bool scrolled = metrics.pixels > 2;
    final bool more = metrics.extentAfter > 2;
    _setScrollState(scrolled, more);
    return false;
  }

  /// Scroll metrics notifications also arrive during layout, where setState is not allowed. Then the change waits for
  /// the end of the frame.
  void _setScrollState(bool scrolled, bool more) {
    if (scrolled == _scrolled && more == _moreBelow) return;
    void apply() {
      if (!mounted || (scrolled == _scrolled && more == _moreBelow)) return;
      setState(() {
        _scrolled = scrolled;
        _moreBelow = more;
      });
    }

    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => apply());
    } else {
      apply();
    }
  }

  Widget _buildBody() {
    final Widget body = widget.body;
    if (body is TabBarView) {
      final TabController? controller = body.controller ?? DefaultTabController.maybeOf(context);
      _setTabController(controller, body.children.length);
      final int activeIndex = controller?.index ?? 0;
      _scrolled = activeIndex < _tabScroll.length && _tabScroll[activeIndex];
      _moreBelow = activeIndex < _tabMore.length && _tabMore[activeIndex];
      return TabBarView(
        key: body.key,
        controller: body.controller,
        physics: body.physics,
        dragStartBehavior: body.dragStartBehavior,
        viewportFraction: body.viewportFraction,
        clipBehavior: body.clipBehavior,
        children: <Widget>[
          for (int index = 0; index < body.children.length; index++)
            NotificationListener<ScrollMetricsNotification>(
              onNotification: (n) => _onTabScroll(index, n.metrics),
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) => _onTabScroll(index, n.metrics),
                child: body.children[index],
              ),
            ),
        ],
      );
    }
    _setTabController(null, 0);
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => _onScroll(n.metrics),
      child: NotificationListener<ScrollNotification>(onNotification: (n) => _onScroll(n.metrics), child: body),
    );
  }

  @override
  void dispose() {
    _tabController?.removeListener(_onTabChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Widget body = _buildBody();
    return Scaffold(
      backgroundColor: cs.surface,
      resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
      bottomNavigationBar: widget.bottomBar == null
          ? null
          : Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
              // A hairline on top separates the pinned action from content that scrolls under it. With nothing under
              // it, the action sits on the page with no line.
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: _moreBelow ? cs.onSurface.withValues(alpha: 0.08) : Colors.transparent),
                  ),
                ),
                child: SafeArea(
                  minimum: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xs, PrismSpace.page, PrismSpace.md),
                  child: PrismMaxWidth(maxWidth: widget.maxContentWidth, child: widget.bottomBar!),
                ),
              ),
            ),
      body: SafeArea(
        bottom: false,
        child: PrismMaxWidth(
          maxWidth: widget.maxContentWidth,
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
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}

/// The body of a short task page. [child] sits at the optical centre of the space (a little above the middle) when it
/// fits, and scrolls when it does not.
///
/// Give the page's main action as [action], not as [PrismPage.bottomBar]. When [child] and [action] fit together, the
/// action sits [PrismSpace.xl] below [child] and the two are centred as one group, so no empty band separates a short
/// message from its action. When they do not fit, [child] scrolls and [action] pins at the bottom, clear of the home
/// indicator.
class PrismCenteredScroll extends StatefulWidget {
  const PrismCenteredScroll({
    super.key,
    required this.child,
    this.action,
    this.padding = const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.md, PrismSpace.page, PrismSpace.xl),
    this.physics,
  });

  final Widget child;
  final Widget? action;
  final EdgeInsets padding;

  /// For example [AlwaysScrollableScrollPhysics] under a [RefreshIndicator].
  final ScrollPhysics? physics;

  @override
  State<PrismCenteredScroll> createState() => _PrismCenteredScrollState();
}

class _PrismCenteredScrollState extends State<PrismCenteredScroll> {
  /// Natural heights of the child and the action. They do not depend on where the action sits, so the choice between
  /// the centred group and the pinned action is stable.
  double? _childHeight;
  double? _actionHeight;

  void _setChildHeight(double height) {
    if (mounted && height != _childHeight) setState(() => _childHeight = height);
  }

  void _setActionHeight(double height) {
    if (mounted && height != _actionHeight) setState(() => _actionHeight = height);
  }

  Widget _scroll(BoxConstraints constraints, EdgeInsets padding, Widget content) => SingleChildScrollView(
    physics: widget.physics,
    padding: padding,
    child: ConstrainedBox(
      constraints: BoxConstraints(minHeight: math.max(0, constraints.maxHeight - padding.vertical)),
      child: Align(alignment: const Alignment(0, -0.12), child: content),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final Widget? action = widget.action;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (action == null) return _scroll(constraints, widget.padding, widget.child);
        final EdgeInsets padding = widget.padding.copyWith(
          bottom: widget.padding.bottom + MediaQuery.paddingOf(context).bottom,
        );
        final Widget child = _HeightReporter(onHeight: _setChildHeight, child: widget.child);
        final Widget reported = _HeightReporter(onHeight: _setActionHeight, child: action);
        // Until both heights are known, assume the group fits.
        final bool fits =
            _childHeight == null ||
            _actionHeight == null ||
            padding.vertical + _childHeight! + PrismSpace.xl + _actionHeight! <= constraints.maxHeight;
        if (fits) {
          return _scroll(
            constraints,
            padding,
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(child: child),
                const SizedBox(height: PrismSpace.xl),
                reported,
              ],
            ),
          );
        }
        return Column(
          children: <Widget>[
            Expanded(
              child: LayoutBuilder(
                builder: (context, inner) => _scroll(inner, widget.padding.copyWith(bottom: PrismSpace.md), child),
              ),
            ),
            SafeArea(
              top: false,
              minimum: EdgeInsets.fromLTRB(widget.padding.left, PrismSpace.xs, widget.padding.right, PrismSpace.md),
              child: reported,
            ),
          ],
        );
      },
    );
  }
}

/// Reports the height of [child] after each layout that changes it.
class _HeightReporter extends SingleChildRenderObjectWidget {
  const _HeightReporter({required this.onHeight, required super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHeightReporter(onHeight);

  @override
  void updateRenderObject(BuildContext context, _RenderHeightReporter renderObject) => renderObject.onHeight = onHeight;
}

class _RenderHeightReporter extends RenderProxyBox {
  _RenderHeightReporter(this.onHeight);

  ValueChanged<double> onHeight;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final double height = size.height;
    if (height == _reported) return;
    _reported = height;
    SchedulerBinding.instance.addPostFrameCallback((_) => onHeight(height));
  }
}
