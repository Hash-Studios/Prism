import 'package:Prism/core/widgets/pulse_placeholder.dart';
import 'package:flutter/material.dart';

class LoadingCards extends StatelessWidget {
  const LoadingCards({super.key, this.childAspectRatio = 0.6625});

  final double childAspectRatio;

  @override
  Widget build(BuildContext context) {
    return PulsePlaceholder(
      builder: (context, _) => GridView.builder(
        primary: false,
        padding: const EdgeInsets.fromLTRB(5, 4, 5, 4),
        itemCount: 24,
        shrinkWrap: true,
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: MediaQuery.of(context).orientation == Orientation.portrait ? 300 : 250,
          childAspectRatio: childAspectRatio,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemBuilder: (context, index) => PulseFill(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
