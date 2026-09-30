import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/personalized_interests_catalog.dart';
import 'package:Prism/core/personalization/taste_profile.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/navigation/views/widgets/tune_feed_tiles.dart';
import 'package:Prism/features/onboarding_v2/src/common/onboarding_v2_keys.dart';
import 'package:Prism/features/onboarding_v2/src/domain/usecases/save_interests_usecase.dart';
import 'package:Prism/features/onboarding_v2/src/utils/onboarding_v2_config.dart';
import 'package:Prism/features/personalized_feed/domain/entities/feed_mix.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final ValueNotifier<int> personalizedFeedSettingsRevision = ValueNotifier<int>(0);

Future<void> openPersonalizedFeedSettingsBottomSheet(BuildContext context) async {
  final SettingsLocalDataSource settingsLocal = getIt<SettingsLocalDataSource>();
  final List<PersonalizedInterest> catalog = await PersonalizedInterestsCatalog.load(
    remoteConfig: FirebaseRemoteConfig.instance,
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
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => AnimatedPadding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
      duration: sheetContext.motion(PrismDurations.base),
      child: MediaQuery.removeViewInsets(
        context: sheetContext,
        removeBottom: true,
        child: PersonalizedFeedSettingsSheet(
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
      ),
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
  });

  final List<PersonalizedInterest> catalog;
  final Set<String> initialInterests;
  final FeedMix initialFeedMix;
  final Future<bool> Function(List<String> interests, FeedMix feedMix) onSave;

  /// Defaults to the app-wide store.
  final TasteSignalStore? tasteSignals;

  @override
  State<PersonalizedFeedSettingsSheet> createState() => _PersonalizedFeedSettingsSheetState();
}

class _PersonalizedFeedSettingsSheetState extends State<PersonalizedFeedSettingsSheet> {
  late final TasteSignalStore _tasteSignals = widget.tasteSignals ?? getIt<TasteSignalStore>();
  late TasteProfile _learned;
  late Set<String> _selectedInterests;
  late FeedMix _feedMix;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedInterests = {...widget.initialInterests};
    _feedMix = widget.initialFeedMix;
    _learned = TasteProfile.build(
      interests: const <String>[],
      following: const <String>[],
      signals: _tasteSignals.read(),
      now: DateTime.now(),
    );
  }

  bool get _canSave => !_saving && _selectedInterests.length >= OnboardingV2Config.minInterests;

  void _toggleInterest(String name) {
    HapticFeedback.selectionClick();
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
      toasts.error('Could not clear history. Try again.');
      return;
    }
    if (!mounted) return;
    personalizedFeedSettingsRevision.value += 1;
    setState(() => _learned = TasteProfile.empty);
    toasts.success('Learning history cleared');
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
    toasts.error('Could not save feed settings. Try again.');
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: PrismBottomSheet.maxHeightFactor,
      child: PrismSheetBody(
        title: 'Tune your feed',
        message: 'Prism learns from what you open, save and set.',
        scrollable: true,
        actions: <Widget>[
          Row(
            children: <Widget>[
              PrismButton(
                label: 'Reset',
                variant: PrismButtonVariant.ghost,
                onPressed: _saving ? null : _resetToDefaults,
              ),
              const SizedBox(width: PrismSpace.sm),
              Expanded(
                child: PrismButton(label: 'Save', expand: true, loading: _saving, onPressed: _canSave ? _save : null),
              ),
            ],
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AnimatedSwitcher(
              duration: context.motion(PrismDurations.fast),
              child: KeyedSubtree(key: ValueKey<bool>(_learned.topTerms(1).isEmpty), child: _buildLearned(context)),
            ),
            const SizedBox(height: PrismSpace.xl),
            ..._buildStartingPoints(context),
            const SizedBox(height: PrismSpace.xl),
            ..._buildDiscovery(context),
          ],
        ),
      ),
    );
  }

  Widget _buildLearned(BuildContext context) {
    final List<String> terms = _learned.topTerms(PrismBottomSheet.learnedTermCount);
    if (terms.isEmpty) {
      return Text('Open, save and set walls to teach your feed.', style: PrismTextStyles.body(context));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionLabel(
          title: 'Learned from you',
          trailing: PrismButton(
            label: 'Clear',
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
        title: 'Starting points',
        trailing: AnimatedDefaultTextStyle(
          duration: context.motion(PrismDurations.fast),
          style: label.copyWith(color: belowMin ? cs.error : cs.onSurfaceVariant),
          child: Text('$count picked'),
        ),
      ),
      AnimatedSwitcher(
        duration: context.motion(PrismDurations.fast),
        child: belowMin
            ? Padding(
                key: const ValueKey<bool>(true),
                padding: const EdgeInsets.only(bottom: PrismSpace.xs),
                child: Text(
                  'Pick at least ${OnboardingV2Config.minInterests}',
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
      const _SectionLabel(title: 'Discovery'),
      PrismSegmented<FeedMix>(
        values: FeedMix.values,
        selected: _feedMix,
        labelOf: (FeedMix mix) => mix.label,
        onChanged: (FeedMix mix) => setState(() => _feedMix = mix),
      ),
      const SizedBox(height: PrismSpace.sm),
      AnimatedSwitcher(
        duration: context.motion(PrismDurations.fast),
        child: SizedBox(
          key: ValueKey<FeedMix>(_feedMix),
          width: double.infinity,
          child: Text(switch (_feedMix) {
            FeedMix.familiar => 'Mostly what you already love.',
            FeedMix.balanced => 'Your taste, with a few surprises.',
            FeedMix.adventurous => 'More walls from outside your taste.',
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
