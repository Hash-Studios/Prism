import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class F3FirstWallpaperPage extends StatelessWidget {
  const F3FirstWallpaperPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingV2Bloc, OnboardingV2State>(
      buildWhen: (prev, curr) => prev.wallpaperData != curr.wallpaperData,
      builder: (context, state) {
        final wallpaper = state.wallpaperData.wallpaper;
        final status = state.wallpaperData.status;
        final isLoading = status == FirstWallpaperStatus.loading;
        final isSuccess = status == FirstWallpaperStatus.success;

        return Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (wallpaper != null)
                CachedNetworkImage(
                  imageUrl: wallpaper.fullUrl.isNotEmpty ? wallpaper.fullUrl : wallpaper.thumbnailUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const ColoredBox(color: Color(0xFF1A1A1A)),
                  errorWidget: (_, __, ___) => const ColoredBox(color: Color(0xFF1A1A1A)),
                )
              else
                const ColoredBox(color: Color(0xFF1A1A1A)),
              if (wallpaper == null) const Center(child: CircularProgressIndicator(color: Colors.white)),
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x80000000), Colors.transparent, Colors.transparent, Color(0xCC000000)],
                    stops: [0.0, 0.25, 0.45, 1.0],
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => context.read<OnboardingV2Bloc>().add(const OnboardingV2Event.stepBack()),
                            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(20)),
                            child: const Text(
                              'Step 4 of 4',
                              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => context.read<OnboardingV2Bloc>().add(
                              const OnboardingV2Event.firstWallpaperStepContinued(),
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.black26,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: const StadiumBorder(),
                            ),
                            child: const Text(
                              'Skip',
                              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ready to set?',
                            style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          if (wallpaper != null && wallpaper.sourceCategory.isNotEmpty)
                            Text(
                              'Based on your interest in ${wallpaper.sourceCategory}.',
                              style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
                            )
                          else
                            const Text(
                              "Here's a pick just for you.",
                              style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
                            ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: isLoading || isSuccess || wallpaper == null
                                  ? null
                                  : () => context.read<OnboardingV2Bloc>().add(
                                      const OnboardingV2Event.firstWallpaperActionRequested(),
                                    ),
                              icon: isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                    )
                                  : Icon(isSuccess ? Icons.check_circle_outline_rounded : Icons.wallpaper_rounded),
                              label: Text(_actionLabel(isLoading: isLoading, isSuccess: isSuccess)),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: const StadiumBorder(),
                                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          if (isSuccess) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: () => context.read<OnboardingV2Bloc>().add(
                                  const OnboardingV2Event.firstWallpaperStepContinued(),
                                ),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: const StadiumBorder(),
                                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                                  foregroundColor: Colors.white,
                                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                                child: const Text('Continue'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _actionLabel({required bool isLoading, required bool isSuccess}) {
    if (isLoading) {
      return defaultTargetPlatform == TargetPlatform.android ? 'Setting Wallpaper...' : 'Saving to Photos...';
    }
    if (isSuccess) {
      return defaultTargetPlatform == TargetPlatform.android ? 'Wallpaper Set!' : 'Saved to Photos!';
    }
    return defaultTargetPlatform == TargetPlatform.android ? 'Set as Wallpaper' : 'Download to Photos';
  }
}
