import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class DropDetailPage extends StatelessWidget {
  const DropDetailPage({super.key, @PathParam('weekKey') required this.weekKey});

  final String weekKey;

  @override
  Widget build(BuildContext context) {
    return const PrismPage(
      title: 'Drop',
      body: GlintState(kind: GlintStateKind.empty, title: 'This Drop is not live'),
    );
  }
}
