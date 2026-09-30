import 'dart:math' as math;

import 'package:Prism/core/utils/ai_target_size.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_frame.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Step 3: generate a first wallpaper from a prompt and style picked from the user's interests.
class F3AiGeneratePage extends StatefulWidget {
  const F3AiGeneratePage({super.key});

  @override
  State<F3AiGeneratePage> createState() => _F3AiGeneratePageState();
}

class _F3AiGeneratePageState extends State<F3AiGeneratePage> {
  late final TextEditingController _prompt;

  @override
  void initState() {
    super.initState();
    _prompt = TextEditingController(text: context.read<OnboardingV2Bloc>().state.aiData.prompt);
  }

  @override
  void dispose() {
    _prompt.dispose();
    super.dispose();
  }

  void _generate(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    context.read<OnboardingV2Bloc>().add(
      OnboardingV2Event.aiGenerationRequested(
        targetSize: aiTargetSize(size: media.size, devicePixelRatio: media.devicePixelRatio),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingV2Bloc, OnboardingV2State>(
      buildWhen: (prev, curr) => prev.aiData != curr.aiData,
      builder: (context, state) {
        final OnboardingAiData ai = state.aiData;
        final bool loading = ai.status == AiGenerateStatus.loading;
        return OnboardingFrame(
          title: 'Create your first wallpaper',
          body: 'Made for you by AI, based on what you picked.',
          primaryLabel: ai.status == AiGenerateStatus.failure ? 'Try again' : 'Generate',
          primaryLoading: loading,
          onPrimary: () => _generate(context),
          onSkip: () => context.read<OnboardingV2Bloc>().add(const OnboardingV2Event.aiGenerationStepContinued()),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // The prompt and style rows take about 200 points at 1x text. The preview gets the rest, never less
              // than 200, and the page scrolls when a small screen or large text leaves no room.
              final double fixed = 200 * MediaQuery.textScalerOf(context).scale(1);
              final double previewHeight = math.max(200, constraints.maxHeight - fixed);
              return SingleChildScrollView(
                padding: PrismSpace.pageInsets,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    PrismTextField(controller: _prompt, label: 'Prompt', enabled: false, minLines: 2, maxLines: 3),
                    const SizedBox(height: PrismSpace.sm),
                    _StyleTile(style: ai.stylePreset.label, swatches: ai.stylePreset.swatchColors),
                    const SizedBox(height: PrismSpace.md),
                    SizedBox(
                      height: previewHeight,
                      child: _Preview(ai: ai),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _StyleTile extends StatelessWidget {
  const _StyleTile({required this.style, required this.swatches});

  final String style;
  final List<Color> swatches;

  @override
  Widget build(BuildContext context) {
    return PrismGroup(
      children: <Widget>[
        PrismRow(
          title: style,
          subtitle: 'Style',
          leading: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PrismRadius.xs + 2),
              gradient: LinearGradient(colors: swatches.length > 1 ? swatches : <Color>[...swatches, ...swatches]),
            ),
            child: const SizedBox.square(dimension: 32),
          ),
        ),
      ],
    );
  }
}

/// The preview slot, at the shape of the phone screen. It shows a placeholder, Glint while it works, the result, or
/// a failure.
class _Preview extends StatelessWidget {
  const _Preview({required this.ai});

  final OnboardingAiData ai;

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.sizeOf(context);
    return Center(
      child: AspectRatio(
        aspectRatio: screen.width / screen.height,
        child: AnimatedSwitcher(
          duration: context.motion(PrismDurations.base),
          switchInCurve: PrismCurves.enter,
          switchOutCurve: PrismCurves.exit,
          child: switch (ai.status) {
            AiGenerateStatus.idle => const _Slot(
              key: ValueKey('idle'),
              child: _SlotMessage(icon: Icons.auto_awesome_rounded, text: 'Your wallpaper will appear here.'),
            ),
            AiGenerateStatus.loading => const _Slot(
              key: ValueKey('loading'),
              child: _SlotMessage(mood: GlintMood.curious, text: 'Crafting your wallpaper…'),
            ),
            AiGenerateStatus.success => _Result(
              key: const ValueKey('success'),
              url: ai.thumbnailUrl ?? ai.imageUrl ?? '',
            ),
            AiGenerateStatus.failure => const _Slot(
              key: ValueKey('failure'),
              child: GlintState(
                kind: GlintStateKind.error,
                title: 'Could not generate it',
                body: 'Tap Try again.',
                glintSize: 72,
                padding: EdgeInsets.all(PrismSpace.md),
              ),
            ),
          },
        ),
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(PrismRadius.lg),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
      ),
      child: Center(child: child),
    );
  }
}

class _SlotMessage extends StatelessWidget {
  const _SlotMessage({this.icon, this.mood, required this.text});

  final IconData? icon;
  final GlintMood? mood;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(PrismSpace.md),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (mood != null)
              Glint(mood: mood!, size: 88)
            else
              Icon(icon, size: 36, color: cs.onSurface.withValues(alpha: 0.5)),
            const SizedBox(height: PrismSpace.sm),
            Text(text, textAlign: TextAlign.center, style: PrismTextStyles.body(context)),
          ],
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(PrismRadius.lg),
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        fadeInDuration: context.motion(PrismDurations.base),
        errorWidget: (_, _, _) => const _Slot(
          child: GlintState(
            kind: GlintStateKind.error,
            title: 'Could not show it',
            body: 'Tap Try again.',
            glintSize: 72,
            padding: EdgeInsets.all(PrismSpace.md),
          ),
        ),
      ),
    );
  }
}
