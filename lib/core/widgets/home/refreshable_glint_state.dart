import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:flutter/material.dart';

/// A [GlintState] inside an always-scrollable list, so pull-to-refresh still works on an empty or failed feed.
class RefreshableGlintState extends StatelessWidget {
  const RefreshableGlintState({
    super.key,
    required this.kind,
    required this.title,
    required this.onRefresh,
    this.body,
    this.actionLabel,
    this.onAction,
  });

  final GlintStateKind kind;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[
            SizedBox(
              height: constraints.maxHeight,
              child: GlintState(kind: kind, title: title, body: body, actionLabel: actionLabel, onAction: onAction),
            ),
          ],
        ),
      ),
    );
  }
}
