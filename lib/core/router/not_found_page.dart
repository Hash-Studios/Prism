import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: PrismSpace.pageInsets,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Glint(mood: GlintMood.surprised, size: 120),
                  const SizedBox(height: PrismSpace.lg),
                  Text(
                    'This page does not exist',
                    textAlign: TextAlign.center,
                    style: PrismTextStyles.sectionTitle(context),
                  ),
                  const SizedBox(height: PrismSpace.xs),
                  Text(
                    'The link you opened is invalid or no longer available.',
                    textAlign: TextAlign.center,
                    style: PrismTextStyles.body(context),
                  ),
                  const SizedBox(height: PrismSpace.xl),
                  PrismButton(
                    label: 'Go home',
                    variant: PrismButtonVariant.tonal,
                    onPressed: () {
                      context.router.replaceAll(<PageRouteInfo>[const DashboardRoute()]);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
