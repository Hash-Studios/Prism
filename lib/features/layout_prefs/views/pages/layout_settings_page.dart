import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/layout_prefs/data/layout_prefs_store.dart';
import 'package:Prism/features/layout_prefs/domain/entities/layout_prefs.dart';
import 'package:Prism/features/layout_prefs/views/nav_tab_view.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Settings > Layout: the order and visibility of the bottom bar tabs, and the size of every wallpaper grid.
@RoutePage()
class LayoutSettingsPage extends StatelessWidget {
  const LayoutSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final LayoutPrefsStore layout = getIt<LayoutPrefsStore>();
    return PrismPage(
      title: context.l10n.layoutTitle,
      body: ValueListenableBuilder<LayoutPrefs>(
        valueListenable: layout,
        builder: (context, prefs, _) => ListView(
          padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xs, PrismSpace.page, PrismSpace.xxxl),
          children: <Widget>[
            _Section(
              title: context.l10n.layoutTabsHeader,
              footnote: context.l10n.layoutTabsFootnote,
              child: _TabList(prefs: prefs, store: layout),
            ),
            _Section(
              title: context.l10n.layoutGridHeader,
              footnote: context.l10n.layoutGridFootnote,
              child: PrismSegmented<WallGridDensity>(
                values: WallGridDensity.values,
                selected: prefs.density,
                labelOf: (density) => density.label(context),
                iconOf: (density) => switch (density) {
                  WallGridDensity.compact => Icons.apps_rounded,
                  WallGridDensity.comfortable => Icons.grid_view_rounded,
                  WallGridDensity.large => Icons.crop_portrait_rounded,
                },
                onChanged: (density) {
                  if (density == prefs.density) return;
                  PrismHaptics.selection();
                  layout.update(prefs.copyWith(density: density));
                  analytics.track(
                    LayoutDensityChangedEvent(density: density, source: LayoutChangeSourceValue.settings),
                  );
                },
              ),
            ),
            const SizedBox(height: PrismSpace.xl),
            Align(
              child: PrismButton(
                label: context.l10n.layoutReset,
                icon: Icons.restart_alt_rounded,
                variant: PrismButtonVariant.ghost,
                onPressed: prefs.isDefaultLayout
                    ? null
                    : () {
                        PrismHaptics.selection();
                        layout.update(prefs.resetLayout());
                        analytics.track(const LayoutResetEvent());
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension WallGridDensityLabel on WallGridDensity {
  String label(BuildContext context) => switch (this) {
    WallGridDensity.compact => context.l10n.layoutDensityCompact,
    WallGridDensity.comfortable => context.l10n.layoutDensityComfortable,
    WallGridDensity.large => context.l10n.layoutDensityLarge,
  };
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, required this.footnote});

  final String title;
  final Widget child;
  final String footnote;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      PrismSectionHeader(
        title: title,
        small: true,
        padding: const EdgeInsetsDirectional.fromSTEB(PrismSpace.xs, PrismSpace.xl, 0, PrismSpace.xs),
      ),
      child,
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(PrismSpace.xs, PrismSpace.xs, PrismSpace.xs, 0),
        child: Text(footnote, style: PrismTextStyles.caption(context)),
      ),
    ],
  );
}

/// The tabs in bar order. Drag a handle, or use the screen reader's "Move up" and "Move down" actions, to reorder.
class _TabList extends StatelessWidget {
  const _TabList({required this.prefs, required this.store});

  final LayoutPrefs prefs;
  final LayoutPrefsStore store;

  void _move(int from, int to) {
    final LayoutPrefs next = prefs.withTabMoved(from, to);
    if (next == prefs) return;
    PrismHaptics.selection();
    store.update(next);
    analytics.track(LayoutTabsReorderedEvent(tab: prefs.tabOrder[from].analyticsValue, toPosition: to));
  }

  void _setVisible(NavTab tab, bool visible) {
    final LayoutPrefs next = prefs.withTabVisible(tab, visible: visible);
    if (next == prefs) return;
    store.update(next);
    analytics.track(LayoutTabVisibilityChangedEvent(tab: tab.analyticsValue, visible: visible));
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final List<NavTab> order = prefs.tabOrder;
    return PrismCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(PrismRadius.lg - 1),
        child: ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: order.length,
          onReorderItem: _move,
          proxyDecorator: (child, index, animation) => Material(
            color: cs.surfaceContainerHigh,
            elevation: 6,
            borderRadius: BorderRadius.circular(PrismRadius.md),
            child: child,
          ),
          itemBuilder: (context, index) {
            final NavTab tab = order[index];
            return _TabRow(
              key: ValueKey<NavTab>(tab),
              tab: tab,
              index: index,
              prefs: prefs,
              onMoveUp: index == 0 ? null : () => _move(index, index - 1),
              onMoveDown: index == order.length - 1 ? null : () => _move(index, index + 1),
              onVisibleChanged: (visible) => _setVisible(tab, visible),
            );
          },
        ),
      ),
    );
  }
}

class _TabRow extends StatelessWidget {
  const _TabRow({
    super.key,
    required this.tab,
    required this.index,
    required this.prefs,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onVisibleChanged,
  });

  final NavTab tab;
  final int index;
  final LayoutPrefs prefs;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final ValueChanged<bool> onVisibleChanged;

  @override
  Widget build(BuildContext context) {
    final String label = tab.label(context);
    final bool visible = !prefs.hiddenTabs.contains(tab);
    final bool canToggle = !visible || prefs.canHide(tab);
    return Semantics(
      customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
        if (onMoveUp != null) CustomSemanticsAction(label: context.l10n.layoutMoveUp): onMoveUp!,
        if (onMoveDown != null) CustomSemanticsAction(label: context.l10n.layoutMoveDown): onMoveDown!,
      },
      child: Material(
        type: MaterialType.transparency,
        child: PrismRow(
          icon: tab.icon,
          title: label,
          subtitle: switch (tab) {
            NavTab.home => context.l10n.layoutTabAlwaysShown,
            _ when !visible => context.l10n.layoutTabUnderMore,
            _ => null,
          },
          padding: const EdgeInsetsDirectional.only(start: PrismSpace.md, top: PrismSpace.xs, bottom: PrismSpace.xs),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Semantics(
                label: context.l10n.layoutShowTab(label),
                child: Switch(
                  value: visible,
                  onChanged: canToggle
                      ? (value) {
                          PrismHaptics.selection();
                          onVisibleChanged(value);
                        }
                      : null,
                ),
              ),
              ReorderableDragStartListener(
                index: index,
                child: Tooltip(
                  message: context.l10n.layoutReorderTab(label),
                  child: const SizedBox(width: 48, height: 48, child: Icon(Icons.drag_handle_rounded)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
