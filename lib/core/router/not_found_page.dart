import 'package:Prism/core/router/app_router.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('Page not found', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 12),
                Text(
                  'The link you opened is invalid or no longer available.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    context.router.replaceAll(<PageRouteInfo>[const DashboardRoute()]);
                  },
                  child: const Text('Go Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
