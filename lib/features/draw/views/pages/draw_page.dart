import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class DrawPage extends StatelessWidget {
  const DrawPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PrismPage(
      title: 'Prism Draw',
      body: GlintState(kind: GlintStateKind.empty, title: 'The draw is closed'),
    );
  }
}
