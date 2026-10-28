import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/personalized_interests_catalog.dart';
import 'package:Prism/core/personalization/taste_profile.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/startup/firebase_init.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/navigation/views/widgets/tune_feed_tiles.dart';
import 'package:Prism/features/onboarding_v2/src/common/onboarding_v2_keys.dart';
import 'package:Prism/features/onboarding_v2/src/domain/usecases/save_interests_usecase.dart';
import 'package:Prism/features/onboarding_v2/src/utils/onboarding_v2_config.dart';
import 'package:Prism/features/personalized_feed/domain/entities/feed_mix.dart';
import 'package:Prism/features/taste_quiz/taste_quiz.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';

final ValueNotifier<int> personalizedFeedSettingsRevision = ValueNotifier<int>(0);

Future<void> openPersonalizedFeedSettingsBottomSheet(BuildContext context) async {
  final SettingsLocalDataSource settingsLocal = getIt<SettingsLocalDataSource>();
  final List<PersonalizedInterest> catalog = await PersonalizedInterestsCatalog.load(
    remoteConfig: FirebaseInit.remoteConfigIfInitialized,
    settingsLocal: settingsLocal,
  );
  if (catalog.isEmpty || !context.mounted) {
    return;
  }

  Set<String> selected = PersonalizedInterestsCatalog.selectedFromLocal(settingsLocal).toSet();
  if (selected.isEmpty) {
    selected = PersonalizedInterestsCatalog.defaultSelection(catalog).toSet();
  }
  final FeedMix currentMix = FeedMix.parse(settingsLocal.get<String>(personalizedFeedMixLocalKey, defaultValue: ''));

  await showPrismSheet<void>(
    context,
    detents: const <PrismSheetDetent>[PrismSheetDetent.large],
    builder: (sheetContext) => PersonalizedFeedSettingsSheet(
      catalog: catalog,
      initialInterests: selected,
      initialFeedMix: currentMix,
      onSave: (List<String> interests, FeedMix feedMix) async {
        final bool persisted = await _persistInterests(settingsLocal, interests);
        if (!persisted) {
          return false;
        }
        await settingsLocal.set(personalizedFeedMixLocalKey, feedMix.name);
        return true;
      },
    ),
  );
}

Future<bool> _persistInterests(SettingsLocalDataSource settingsLocal, List<String> interests) async {
  if (!app_state.prismUser.loggedIn) {
    await settingsLocal.set(OnboardingV2Keys.selectedInterests, interests.join(','));
    return true;
  }
  final SaveInterestsUseCase saveInterests = getIt<SaveInterestsUseCase>();
  final Result<void> saveResult = await saveInterests(SaveInterestsParams(interests: interests));
  return saveResult.isSuccess;
}

class PersonalizedFeedSettingsSheet extends StatefulWidget {
  const PersonalizedFeedSettingsSheet({
    super.key,
    required this.catalog,
    required this.initialInterests,
    required this.initialFeedMix,
    required this.onSave,
    this.tasteSignals,
    this.tasteQuiz,
    this.openRetake = openTasteQuizRetake,
  });

  final List<PersonalizedInterest> catalog;
  final Set<String> initialInterests;
  final FeedMix initialFeedMix;
  final Future<bool> Function(List<String> interests, FeedMix feedMix) onSave;

  /// Defaults to the app-wide store.
  final TasteSignalStore? tasteSignals;

  /// Defaults to the app-wide repository.
  final TasteQuizRepository? tasteQuiz;

  /// Shows the quiz over the sheet and waits for it to close.
  final Future<bool?> Function(BuildContext context, {required TasteQuizPlan plan, required List<String> interests})
  openRetake;

  @override
  State<PersonalizedFeedSettingsSheet> createState() => _PersonalizedFeedSettingsSheetState();
}

class _PersonalizedFeedSettingsSheetState extends State<PersonalizedFeedSettingsSheet> {
  late final TasteSignalStore _tasteSignals = widget.tasteSignals ?? getIt<TasteSignalStore>();
  late final TasteQuizRepository _tasteQuiz = widget.tasteQuiz ?? getIt<TasteQuizRepository>();
  late TasteProfile _learned;
  late Set<String> _selectedInterests;
  late FeedMix _feedMix;
  bool _saving = false;
  bool _loadingQuiz = false;

  @override
  void initState() {
    super.initState();
    _selectedInterests = {...widget.initialInterests};
    _feedMix = widget.initialFeedMix;
    _learned = _readLearned();
  }

  TasteProfile _readLearned() => TasteProfile.build(
    interests: const <String>[],
    following: const <String>[],
    signals: _tasteSignals.read(),
    now: DateTime.now(),
  );

  /// Runs the quiz over the sheet. The picks add to what the feed already learned.
  Future<void> _retakeQuiz() async {
    if (_loadingQuiz) return;
    unawaited(analytics.track(const TasteQuizRetakeOpenedEvent()));
    setState(() => _loadingQuiz = true);
    final List<String> interests = _selectedInterests.toList(growable: false);
    final TasteQuizPlan? plan = await _tasteQuiz.loadPlan(interests);
    if (!mounted) return;
    setState(() => _loadingQuiz = false);
    if (plan == null) {
      toasts.error(context.l10n.tasteQuizRetakeFailed);
      return;
    }
    final bool? completed = await widget.openRetake(context, plan: plan, interests: interests);
    if (!mounted || completed == null) return;
    personalizedFeedSettingsRevision.value += 1;
    setState(() => _learned = _readLearned());
  }

  bool get _canSave => !_saving && _selectedInterests.length >= OnboardingV2Config.minInterests;

  void _toggleInterest(String name) {
    PrismHaptics.selection();
    setState(() {
      if (!_selectedInterests.remove(name)) {
        _selectedInterests.add(name);
      }
    });
  }

  void _resetToDefaults() {
    setState(() {
      _selectedInterests = PersonalizedInterestsCatalog.defaultSelection(widget.catalog).toSet();
      _feedMix = FeedMix.balanced;
    });
  }

  Future<void> _clearLearned() async {
    try {
      await _tasteSignals.clear();
    } catch (_) {
      if (!mounted) return;
      toasts.error(context.l10n.wallpaperFeedClearHistoryError);
      return;
    }
    if (!mounted) return;
    personalizedFeedSettingsRevision.value += 1;
    setState(() => _learned = TasteProfile.empty);
    toasts.success(context.l10n.wallpaperFeedLearningHistoryCleared);
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    try {
      final bool saved = await widget.onSave(_selectedInterests.toList(growable: false), _feedMix);
      if (!mounted) return;
      if (saved) {
        personalizedFeedSettingsRevision.value += 1;
        Navigator.of(context).pop();
        return;
      }
    } catch (_) {
      if (!mounted) return;
    }
    setState(() => _saving = false);
    toasts.error(context.l10n.wallpaperFeedSaveError);
  }

  @override
  Widget build(BuildContext context) {
    return PrismSheetBody(
      title: context.l10n.wallpaperFeedTuneTitle,
      message: context.l10n.wallpaperFeedTuneDescription,
      trailingAction: PrismSheetAction(label: context.l10n.wallpaperReset, onTap: _saving ? null : _resetToDefaults),
      actions: <Widget>[
        PrismButton(
          label: context.l10n.wallpaperSave,
          expand: true,
          loading: _saving,
          onPressed: _canSave ? _save : null,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AnimatedSwitcher(
            duration: context.motion(PrismDurations.fast),
            child: KeyedSubtree(key: ValueKey<bool>(_learned.topTerms(1).isEmpty), child: _buildLearned(context)),
          ),
          const SizedBox(height: PrismSpace.md),
          PrismButton(
            label: context.l10n.tasteQuizRetake,
            variant: PrismButtonVariant.tonal,
            icon: Icons.compare_rounded,
            expand: true,
            loading: _loadingQuiz,
            onPressed: _saving ? null : _retakeQuiz,
          ),
          const SizedBox(height: PrismSpace.xl),
          ..._buildStartingPoints(context),
          const SizedBox(height: PrismSpace.xl),
          ..._buildDiscovery(context),
        ],
      ),
    );
  }

  Widget _buildLearned(BuildContext context) {
    final List<String> terms = _learned.topTerms(PrismBottomSheet.learnedTermCount);
    if (terms.isEmpty) {
      return Text(context.l10n.wallpaperFeedLearningEmpty, style: PrismTextStyles.body(context));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionLabel(
          title: context.l10n.wallpaperFeedLearnedFromYou,
          trailing: PrismButton(
            label: context.l10n.wallpaperClear,
            variant: PrismButtonVariant.ghost,
            size: PrismButtonSize.compact,
            onPressed: _clearLearned,
          ),
        ),
        Wrap(
          spacing: PrismBottomSheet.chipSpacing,
          runSpacing: PrismBottomSheet.chipRunSpacing,
          children: <Widget>[
            for (final String term in terms) LearnedPill(term: term, strength: _learned.strengthOf(term)),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildStartingPoints(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final int count = _selectedInterests.length;
    final bool belowMin = count < OnboardingV2Config.minInterests;
    final TextStyle label = _SectionLabel.style(context);
    return <Widget>[
      _SectionLabel(
        title: context.l10n.wallpaperFeedStartingPoints,
        trailing: AnimatedDefaultTextStyle(
          duration: context.motion(PrismDurations.fast),
          style: label.copyWith(color: belowMin ? cs.error : cs.onSurfaceVariant),
          child: Text(context.l10n.wallpaperFeedPickedCount(count)),
        ),
      ),
      AnimatedSwitcher(
        duration: context.motion(PrismDurations.fast),
        child: belowMin
            ? Padding(
                key: const ValueKey<bool>(true),
                padding: const EdgeInsets.only(bottom: PrismSpace.xs),
                child: Text(
                  context.l10n.wallpaperFeedPickAtLeast(OnboardingV2Config.minInterests),
                  style: PrismTextStyles.caption(context).copyWith(color: cs.error),
                ),
              )
            : const SizedBox(key: ValueKey<bool>(false), width: double.infinity),
      ),
      GridView.count(
        crossAxisCount: PrismBottomSheet.interestGridColumns,
        mainAxisSpacing: PrismBottomSheet.interestTileSpacing,
        crossAxisSpacing: PrismBottomSheet.interestTileSpacing,
        childAspectRatio: PrismBottomSheet.interestTileAspectRatio,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: <Widget>[
          for (final PersonalizedInterest interest in widget.catalog)
            InterestTile(
              interest: interest,
              selected: _selectedInterests.contains(interest.name),
              onTap: () => _toggleInterest(interest.name),
            ),
        ],
      ),
    ];
  }

  List<Widget> _buildDiscovery(BuildContext context) {
    return <Widget>[
      _SectionLabel(title: context.l10n.wallpaperFeedDiscovery),
      PrismSegmented<FeedMix>(
        values: FeedMix.values,
        selected: _feedMix,
        labelOf: (FeedMix mix) => switch (mix) {
          FeedMix.familiar => context.l10n.wallpaperFeedMixFamiliar,
          FeedMix.balanced => context.l10n.wallpaperFeedMixBalanced,
          FeedMix.adventurous => context.l10n.wallpaperFeedMixAdventurous,
        },
        onChanged: (FeedMix mix) => setState(() => _feedMix = mix),
      ),
      const SizedBox(height: PrismSpace.sm),
      AnimatedSwitcher(
        duration: context.motion(PrismDurations.fast),
        child: SizedBox(
          key: ValueKey<FeedMix>(_feedMix),
          width: double.infinity,
          child: Text(switch (_feedMix) {
            FeedMix.familiar => context.l10n.wallpaperFeedMixFamiliarDescription,
            FeedMix.balanced => context.l10n.wallpaperFeedMixBalancedDescription,
            FeedMix.adventurous => context.l10n.wallpaperFeedMixAdventurousDescription,
          }, style: PrismTextStyles.body(context)),
        ),
      ),
    ];
  }
}

/// A quiet label above a group in the sheet, with an optional widget at the end.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  static TextStyle style(BuildContext context) =>
      PrismTextStyles.caption(context).copyWith(fontSize: 13, fontWeight: FontWeight.w600);

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 40),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Semantics(header: true, child: Text(title, style: style(context))),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
