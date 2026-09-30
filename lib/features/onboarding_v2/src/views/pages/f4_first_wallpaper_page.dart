import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_frame.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Step 4: a first wallpaper, previewed on a phone-shaped card, to set or save.
class F4FirstWallpaperPage extends StatelessWidget {
  const F4FirstWallpaperPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingV2Bloc, OnboardingV2State>(
      buildWhen: (prev, curr) => prev.wallpaperData != curr.wallpaperData,
      builder: (context, state) {
        final OnboardingWallpaperData data = state.wallpaperData;
        final OnboardingV2Bloc bloc = context.read<OnboardingV2Bloc>();
        final wallpaper = data.wallpaper;
        final bool android = defaultTargetPlatform == TargetPlatform.android;
        final String category = wallpaper?.sourceCategory ?? '';
        void later() => bloc.add(const OnboardingV2Event.firstWallpaperStepContinued());
        return OnboardingFrame(
          title: 'Make it yours',
          body: category.isEmpty ? 'Picked just for you.' : 'Picked for your interest in $category.',
          primaryLabel: wallpaper == null
              ? 'Continue'
              : android
              ? 'Set as wallpaper'
              : 'Save to Photos',
          primaryLoading: data.status == FirstWallpaperStatus.loading,
          onPrimary: wallpaper == null
              ? later
              : () => bloc.add(const OnboardingV2Event.firstWallpaperActionRequested()),
          secondary: wallpaper == null
              ? null
              : PrismButton(label: 'Later', variant: PrismButtonVariant.ghost, expand: true, onPressed: later),
          child: Padding(
            padding: PrismSpace.pageInsets,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const PrismTag(
                  label: 'Pro is free for you',
                  tone: PrismTone.accent,
                  icon: Icons.workspace_premium_rounded,
                ),
                const SizedBox(height: PrismSpace.sm),
                Expanded(
                  child: _Preview(fullUrl: wallpaper?.fullUrl, thumbnailUrl: wallpaper?.thumbnailUrl),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.fullUrl, required this.thumbnailUrl});

  final String? fullUrl;
  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Size screen = MediaQuery.sizeOf(context);
    final Widget asset = Image.asset(OnboardingAssets.wallpaperPrimary, fit: BoxFit.cover);
    final String? full = fullUrl;
    final String? thumb = thumbnailUrl;
    return Center(
      child: AspectRatio(
        aspectRatio: screen.width / screen.height,
        child: Container(
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PrismRadius.lg),
            border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(PrismRadius.lg),
            child: full == null || full.isEmpty
                ? asset
                : CachedNetworkImage(
                    imageUrl: full,
                    fit: BoxFit.cover,
                    fadeInDuration: context.motion(PrismDurations.base),
                    placeholder: (_, _) => thumb == null || thumb.isEmpty
                        ? ColoredBox(color: cs.surfaceContainerHigh)
                        : CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover),
                    errorWidget: (_, _, _) => asset,
                  ),
          ),
        ),
      ),
    );
  }
}
