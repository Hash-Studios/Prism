import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PrismPage(
      title: 'Leaderboard',
      body: GlintState(kind: GlintStateKind.empty, title: 'No rankings yet'),
    );
  }
}
