import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PrismPage(
      title: context.l10n.coreThisPageDoesNotExist,
      body: GlintState(
        kind: GlintStateKind.empty,
        glintSize: 120,
        title: context.l10n.coreInvalidLinkBody,
        actionLabel: context.l10n.coreGoHome,
        onAction: () {
          context.router.replaceAll(<PageRouteInfo>[const DashboardRoute()]);
        },
      ),
    );
  }
}
