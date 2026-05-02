import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_frame.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// F3 unique content: AI wallpaper generation step.
/// Background, headline, progress, CTA button, and helper text are owned by
/// the shell overlay. This page owns the prompt chip, preview area, and skip.
class F3AiGeneratePage extends StatelessWidget {
  const F3AiGeneratePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingV2Bloc, OnboardingV2State>(
      buildWhen: (prev, curr) => prev.aiData != curr.aiData,
      builder: (context, state) {
        final aiData = state.aiData;

        return OnboardingFrame(
          builder: (context, sx, sy) {
            // Preview fills from below the chip to just above the CTA.
            const previewBottom = OnboardingLayout.ctaY - 12;
            const previewHeight = previewBottom - OnboardingLayout.aiPreviewY;

            return Stack(
              fit: StackFit.expand,
              children: [
                // ── Prompt chip — sits below the two-line headline ──
                Positioned(
                  top: OnboardingLayout.aiChipY * sy,
                  left: OnboardingLayout.aiChipX * sx,
                  right: OnboardingLayout.aiChipX * sx,
                  child: _PromptChip(prompt: aiData.prompt, style: aiData.stylePreset.label),
                ),

                // ── Preview area (loading / result / failure) ──
                Positioned(
                  top: OnboardingLayout.aiPreviewY * sy,
                  left: OnboardingLayout.aiPreviewX * sx,
                  right: OnboardingLayout.aiPreviewX * sx,
                  height: previewHeight * sy,
                  child: _PreviewArea(aiData: aiData),
                ),

                // ── Skip link (top-right, same position as F4 skip) ──
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: OnboardingLayout.skipY * sy,
                      right: (OnboardingLayout.designWidth - OnboardingLayout.skipX - 32) * sx,
                    ),
                    child: GestureDetector(
                      onTap: () =>
                          context.read<OnboardingV2Bloc>().add(const OnboardingV2Event.aiGenerationStepContinued()),
                      child: Text(
                        'skip',
                        style: OnboardingTypography.skip.copyWith(color: OnboardingColors.textPrimary),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _PromptChip extends StatelessWidget {
  const _PromptChip({required this.prompt, required this.style});

  final String prompt;
  final String style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              style,
              style: const TextStyle(
                fontFamily: OnboardingTypography.sans,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              prompt,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: OnboardingTypography.sans,
                fontSize: 13,
                color: Colors.black.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewArea extends StatelessWidget {
  const _PreviewArea({required this.aiData});

  final OnboardingAiData aiData;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: switch (aiData.status) {
        AiGenerateStatus.idle => const _IdlePlaceholder(key: ValueKey('idle')),
        AiGenerateStatus.loading => const _LoadingView(key: ValueKey('loading')),
        AiGenerateStatus.success => _ResultImage(
          key: const ValueKey('success'),
          imageUrl: aiData.thumbnailUrl ?? aiData.imageUrl ?? '',
        ),
        AiGenerateStatus.failure => const _FailureView(key: ValueKey('failure')),
      },
    );
  }
}

class _IdlePlaceholder extends StatelessWidget {
  const _IdlePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_rounded, color: Colors.black.withValues(alpha: 0.35), size: 40),
            const SizedBox(height: 12),
            Text(
              'tap generate to create\nyour unique wallpaper',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: OnboardingTypography.sans,
                fontSize: 14,
                color: Colors.black.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.black.withValues(alpha: 0.6), strokeWidth: 2.5),
            const SizedBox(height: 16),
            Text(
              'crafting your wallpaper…',
              style: TextStyle(
                fontFamily: OnboardingTypography.sans,
                fontSize: 14,
                color: Colors.black.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultImage extends StatelessWidget {
  const _ResultImage({super.key, required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        fadeInDuration: const Duration(milliseconds: 300),
        errorWidget: (_, _, _) => const _FailureView(),
      ),
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.refresh_rounded, color: Colors.black.withValues(alpha: 0.45), size: 36),
            const SizedBox(height: 12),
            Text(
              'something went wrong.\ntap generate to try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: OnboardingTypography.sans,
                fontSize: 14,
                color: Colors.black.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
