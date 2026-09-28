import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:Prism/main.dart' as main;
import 'package:flutter/material.dart';

/// Centered "sign in required" placeholder for screens that need an
/// authenticated user even on iOS, where browsing without an account is
/// otherwise allowed (Guideline 5.1.1(v)). Some reads/writes still require
/// Firebase auth per firestore.rules (e.g. coin callables, usersV2 reads).
class SignInPrompt extends StatelessWidget {
  const SignInPrompt({required this.feature, super.key});

  /// Human-readable feature name, e.g. "streaks", "profiles", "search".
  final String feature;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 40, color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              'Sign in to use $feature',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => googleSignInPopUp(context, () => main.RestartWidget.restartApp(context)),
              child: const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}
