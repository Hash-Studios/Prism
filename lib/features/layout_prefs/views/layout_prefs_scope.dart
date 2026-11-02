import 'package:Prism/features/layout_prefs/domain/entities/layout_prefs.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The part of [LayoutPrefs] a widget reads, so a feed tab change does not rebuild every wallpaper grid.
enum LayoutAspect { tabs, density }

/// Puts [prefs] in the tree. Widgets read it with [LayoutPrefsScope.of] and rebuild only when their aspect changes.
/// Without a scope (in a test) they read the defaults.
class LayoutPrefsScope extends StatelessWidget {
  const LayoutPrefsScope({super.key, required this.prefs, required this.child});

  final ValueListenable<LayoutPrefs> prefs;
  final Widget child;

  static LayoutPrefs of(BuildContext context, LayoutAspect aspect) =>
      InheritedModel.inheritFrom<_LayoutPrefsModel>(context, aspect: aspect)?.prefs ?? const LayoutPrefs();

  static WallGridDensity densityOf(BuildContext context) => of(context, LayoutAspect.density).density;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<LayoutPrefs>(
    valueListenable: prefs,
    builder: (context, value, child) => _LayoutPrefsModel(prefs: value, child: child!),
    child: child,
  );
}

class _LayoutPrefsModel extends InheritedModel<LayoutAspect> {
  const _LayoutPrefsModel({required this.prefs, required super.child});

  final LayoutPrefs prefs;

  @override
  bool updateShouldNotify(_LayoutPrefsModel oldWidget) => oldWidget.prefs != prefs;

  @override
  bool updateShouldNotifyDependent(_LayoutPrefsModel oldWidget, Set<LayoutAspect> dependencies) =>
      (dependencies.contains(LayoutAspect.density) && oldWidget.prefs.density != prefs.density) ||
      (dependencies.contains(LayoutAspect.tabs) &&
          (!listEquals(oldWidget.prefs.tabOrder, prefs.tabOrder) ||
              !setEquals(oldWidget.prefs.hiddenTabs, prefs.hiddenTabs)));
}
