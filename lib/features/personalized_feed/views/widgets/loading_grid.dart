import 'dart:math' as math;

import 'package:flutter/material.dart';

class PersonalizedLoadingGrid extends StatelessWidget {
  const PersonalizedLoadingGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(5, 20, 5, 4),
      itemCount: 20,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: MediaQuery.of(context).orientation == Orientation.portrait ? 300 : 250,
        childAspectRatio: 0.6625,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final shimmer = (index % 4) / 8;
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.35 + shimmer, end: 0.55 + shimmer),
          duration: Duration(milliseconds: 850 + (index % 5) * 70),
          curve: Curves.easeInOut,
          builder: (context, value, _) {
            final alpha = math.min(0.7, math.max(0.2, value));
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary.withValues(alpha: alpha),
                borderRadius: BorderRadius.circular(20),
              ),
            );
          },
        );
      },
    );
  }
}
