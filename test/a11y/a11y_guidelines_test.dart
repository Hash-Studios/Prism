import 'package:Prism/core/widgets/prism/prism_chip.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/a11y_guidelines.dart';

void main() {
  testWidgets('guideline helper renders and validates Android 48 dp and iOS 44 pt targets', (tester) async {
    final Map<TargetPlatform, double> renderedTargets = <TargetPlatform, double>{};

    await expectA11yGuidelines(
      tester,
      () => Scaffold(
        body: Center(
          child: Builder(
            builder: (BuildContext context) {
              final TargetPlatform platform = Theme.of(context).platform;
              renderedTargets[platform] = prismTapTarget(context);
              return PrismChip(label: 'Selected', selected: true, compact: true, onTap: () {});
            },
          ),
        ),
      ),
    );

    expect(renderedTargets, <TargetPlatform, double>{TargetPlatform.android: 48, TargetPlatform.iOS: 44});
  });
}
