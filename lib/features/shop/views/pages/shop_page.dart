import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class ShopPage extends StatelessWidget {
  const ShopPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PrismPage(
      title: 'Shop',
      body: GlintState(kind: GlintStateKind.empty, title: 'The shop opens soon'),
    );
  }
}
