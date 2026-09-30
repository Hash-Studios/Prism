import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:flutter/material.dart';

/// Top of the settings page. Signed-in users see who they are and open their profile; guests see a sign-in prompt.
class SettingsAccountCard extends StatelessWidget {
  const SettingsAccountCard({super.key, required this.onOpenProfile, required this.onSignIn});

  final VoidCallback onOpenProfile;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    if (!app_state.prismUser.loggedIn) {
      return PrismCard(
        child: Row(
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: cs.onSurface.withValues(alpha: 0.08), shape: BoxShape.circle),
              child: Icon(Icons.person_rounded, color: cs.onSurface.withValues(alpha: 0.6)),
            ),
            const SizedBox(width: PrismSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Sign in to Prism', style: PrismTextStyles.cardTitle(context)),
                  const SizedBox(height: 2),
                  Text('Sync your data across devices', style: PrismTextStyles.caption(context)),
                ],
              ),
            ),
            const SizedBox(width: PrismSpace.sm),
            PrismButton(label: 'Sign in', size: PrismButtonSize.compact, onPressed: onSignIn),
          ],
        ),
      );
    }
    final String name = app_state.prismUser.name;
    return PrismCard(
      semanticLabel: 'Open your profile',
      onTap: onOpenProfile,
      child: Row(
        children: <Widget>[
          PrismAvatar(url: app_state.prismUser.profilePhoto, name: name, size: 52),
          const SizedBox(width: PrismSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PrismTextStyles.cardTitle(context),
                      ),
                    ),
                    if (app_state.prismUser.premium) ...<Widget>[
                      const SizedBox(width: PrismSpace.xs),
                      const PrismTag(label: 'Pro', tone: PrismTone.accent),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  app_state.prismUser.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PrismTextStyles.caption(context),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 22, color: cs.onSurface.withValues(alpha: 0.35)),
        ],
      ),
    );
  }
}
