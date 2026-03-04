import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class OnboardingWallpaperActionButton extends StatelessWidget {
  const OnboardingWallpaperActionButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingV2Bloc, OnboardingV2State>(
      buildWhen: (prev, curr) => prev.wallpaperData.status != curr.wallpaperData.status,
      builder: (context, state) {
        final status = state.wallpaperData.status;
        final isLoading = status == FirstWallpaperStatus.loading;
        final isSuccess = status == FirstWallpaperStatus.success;

        final label = defaultTargetPlatform == TargetPlatform.android
            ? (isSuccess ? 'Wallpaper Set!' : 'Set as Wallpaper')
            : (isSuccess ? 'Saved to Photos!' : 'Save to Photos');

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: isLoading || isSuccess
                ? null
                : () => context.read<OnboardingV2Bloc>().add(const OnboardingV2Event.firstWallpaperActionRequested()),
            icon: isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5))
                : Icon(isSuccess ? Icons.check_circle_outline : Icons.wallpaper_rounded),
            label: Text(label),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        );
      },
    );
  }
}
