import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:flutter/material.dart';

/// "See more" at the end of a paged grid.
class SeeMoreButton extends StatelessWidget {
  const SeeMoreButton({super.key, required this.seeMoreLoader, required this.func});

  final bool seeMoreLoader;
  final VoidCallback func;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: PrismButton(
        label: 'See more',
        onPressed: func,
        loading: seeMoreLoader,
        variant: PrismButtonVariant.tonal,
        size: PrismButtonSize.compact,
      ),
    );
  }
}
