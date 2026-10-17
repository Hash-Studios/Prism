import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class DropsPage extends StatelessWidget {
  const DropsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PrismPage(
      title: 'Drops',
      body: GlintState(kind: GlintStateKind.empty, title: 'No Drop this week yet'),
    );
  }
}
