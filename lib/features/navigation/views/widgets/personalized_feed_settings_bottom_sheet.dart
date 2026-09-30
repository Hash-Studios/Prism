import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/personalized_interests_catalog.dart';
import 'package:Prism/core/personalization/taste_profile.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_sheet_chrome.dart';
import 'package:Prism/features/onboarding_v2/src/common/onboarding_v2_keys.dart';
import 'package:Prism/features/onboarding_v2/src/domain/usecases/save_interests_usecase.dart';
import 'package:Prism/features/onboarding_v2/src/utils/onboarding_v2_config.dart';
import 'package:Prism/features/personalized_feed/domain/entities/feed_mix.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const Duration _kTileMotion = Duration(milliseconds: 150);
const Duration _kSectionMotion = Duration(milliseconds: 200);
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
      duration: const Duration(milliseconds: 200),
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
  final GlobalKey<ScaffoldMessengerState> _messengerKey = GlobalKey<ScaffoldMessengerState>();
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
      _messengerKey.currentState?.showSnackBar(const SnackBar(content: Text('Could not clear history. Try again.')));
      return;
    }
    if (!mounted) return;
    personalizedFeedSettingsRevision.value += 1;
    setState(() => _learned = TasteProfile.empty);
    _messengerKey.currentState?.showSnackBar(const SnackBar(content: Text('Learning history cleared')));
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
    _messengerKey.currentState?.showSnackBar(const SnackBar(content: Text('Could not save feed settings. Try again.')));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final TextStyle muted = (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(color: cs.onSurfaceVariant);

    return FractionallySizedBox(
      heightFactor: PrismBottomSheet.maxHeightFactor,
      child: ScaffoldMessenger(
        key: _messengerKey,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          bottomNavigationBar: _ActionBar(
            saving: _saving,
            onReset: _saving ? null : _resetToDefaults,
            onSave: _canSave ? _save : null,
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: PrismBottomSheet.topGap),
              const AiSheetDragHandle(),
              const SizedBox(height: PrismBottomSheet.headerGap),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: PrismBottomSheet.horizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Tune your feed', style: PrismTextStyles.sheetTitle(context)),
                    const SizedBox(height: PrismBottomSheet.sectionLabelBottomGap),
                    Text('Prism learns from what you open, save and set.', style: muted),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: PrismBottomSheet.horizontalPadding,
                    vertical: PrismBottomSheet.sectionGap,
                  ),
                  children: <Widget>[
                    AnimatedSize(
                      duration: _kSectionMotion,
                      curve: Curves.easeOut,
                      alignment: AlignmentDirectional.topStart,
                      child: _buildLearned(context, muted),
                    ),
                    const SizedBox(height: PrismBottomSheet.sectionGap),
                    ..._buildStartingPoints(context),
                    const SizedBox(height: PrismBottomSheet.sectionGap),
                    ..._buildDiscovery(context, muted),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLearned(BuildContext context, TextStyle muted) {
    final List<String> terms = _learned.topTerms(PrismBottomSheet.learnedTermCount);
    if (terms.isEmpty) {
      return SizedBox(
        width: double.infinity,
        child: Text('Open, save and set walls to teach your feed.', style: muted),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text('Learned from you', style: PrismTextStyles.sheetSectionLabel(context))),
            TextButton(
              onPressed: _clearLearned,
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              child: const Text('Clear'),
            ),
          ],
        ),
        const SizedBox(height: PrismBottomSheet.sectionLabelBottomGap),
        Wrap(
          spacing: PrismBottomSheet.chipSpacing,
          runSpacing: PrismBottomSheet.chipRunSpacing,
          children: <Widget>[
            for (final String term in terms) _LearnedPill(term: term, strength: _learned.strengthOf(term)),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildStartingPoints(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final int count = _selectedInterests.length;
    final bool belowMin = count < OnboardingV2Config.minInterests;
    final TextStyle label = PrismTextStyles.sheetSectionLabel(context);
    return <Widget>[
      Row(
        children: <Widget>[
          Expanded(child: Text('Starting points', style: label)),
          AnimatedDefaultTextStyle(
            duration: _kSectionMotion,
            style: label.copyWith(color: belowMin ? cs.error : cs.onSurfaceVariant),
            child: Text('$count picked'),
          ),
        ],
      ),
      AnimatedSize(
        duration: _kSectionMotion,
        curve: Curves.easeOut,
        alignment: AlignmentDirectional.topStart,
        child: belowMin
            ? Padding(
                padding: const EdgeInsets.only(top: PrismBottomSheet.sectionLabelBottomGap),
                child: Text(
                  'Pick at least ${OnboardingV2Config.minInterests}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.error),
                ),
              )
            : const SizedBox(width: double.infinity),
      ),
      const SizedBox(height: PrismBottomSheet.sectionContentGap),
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
            _InterestTile(
              interest: interest,
              selected: _selectedInterests.contains(interest.name),
              onTap: () => _toggleInterest(interest.name),
            ),
        ],
      ),
    ];
  }

  List<Widget> _buildDiscovery(BuildContext context, TextStyle muted) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return <Widget>[
      Text('Discovery', style: PrismTextStyles.sheetSectionLabel(context)),
      const SizedBox(height: PrismBottomSheet.sectionContentGap),
      SegmentedButton<FeedMix>(
        segments: <ButtonSegment<FeedMix>>[
          for (final FeedMix mix in FeedMix.values)
            ButtonSegment<FeedMix>(
              value: mix,
              label: Text(mix.label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
        ],
        selected: <FeedMix>{_feedMix},
        showSelectedIcon: false,
        expandedInsets: EdgeInsets.zero,
        onSelectionChanged: (Set<FeedMix> value) => setState(() => _feedMix = value.first),
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: cs.primary,
          selectedForegroundColor: cs.onPrimary,
          foregroundColor: cs.onSurface,
          padding: const EdgeInsets.symmetric(horizontal: PrismBottomSheet.chipSpacing),
        ),
      ),
      const SizedBox(height: PrismBottomSheet.sectionLabelBottomGap * 2),
      AnimatedSwitcher(
        duration: _kSectionMotion,
        child: SizedBox(
          key: ValueKey<FeedMix>(_feedMix),
          width: double.infinity,
          child: Text(switch (_feedMix) {
            FeedMix.familiar => 'Mostly what you already love.',
            FeedMix.balanced => 'Your taste, with a few surprises.',
            FeedMix.adventurous => 'More walls from outside your taste.',
          }, style: muted),
        ),
      ),
    ];
  }
}

class _LearnedPill extends StatelessWidget {
  const _LearnedPill({required this.term, required this.strength});

  final String term;
  final double strength;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final String label = '${term[0].toUpperCase()}${term.substring(1)}';
    const BorderRadius barRadius = BorderRadius.all(Radius.circular(PrismBottomSheet.dragHandleRadius));
    return Semantics(
      label: 'Learned: $label, ${(strength * 100).round()} percent',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: barRadius),
        child: Padding(
          padding: PrismBottomSheet.learnedPillPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: PrismBottomSheet.sectionLabelBottomGap),
              Container(
                width: PrismBottomSheet.learnedBarWidth,
                height: PrismBottomSheet.learnedBarHeight,
                alignment: AlignmentDirectional.centerStart,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: PrismBottomSheet.learnedBarTrackAlpha),
                  borderRadius: barRadius,
                ),
                child: FractionallySizedBox(
                  widthFactor: strength,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: cs.primary, borderRadius: barRadius),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InterestTile extends StatelessWidget {
  const _InterestTile({required this.interest, required this.selected, required this.onTap});

  final PersonalizedInterest interest;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    const BorderRadius radius = BorderRadius.all(Radius.circular(PrismBottomSheet.interestTileRadius));
    return Semantics(
      button: true,
      selected: selected,
      label: 'Interest: ${interest.name}, ${selected ? 'selected' : 'not selected'}',
      onTap: onTap,
      excludeSemantics: true,
      child: AnimatedScale(
        scale: selected ? PrismBottomSheet.interestTileSelectedScale : 1,
        duration: _kTileMotion,
        curve: Curves.easeOut,
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) => CachedNetworkImage(
                  imageUrl: interest.imageUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context)).round(),
                  fadeInDuration: _kTileMotion,
                  placeholder: (_, _) => ColoredBox(color: cs.surfaceContainerHighest),
                  errorWidget: (_, _, _) => ColoredBox(color: cs.surfaceContainerHighest),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const <double>[0.4, 1],
                    colors: <Color>[
                      cs.scrim.withValues(alpha: 0),
                      cs.scrim.withValues(alpha: PrismBottomSheet.interestTileScrimAlpha),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: PrismBottomSheet.interestTileLabelInset,
                right: PrismBottomSheet.interestTileLabelInset,
                bottom: PrismBottomSheet.interestTileLabelInset,
                child: Text(
                  interest.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: PrismColors.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              AnimatedContainer(
                duration: _kTileMotion,
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: selected ? cs.primary : cs.primary.withValues(alpha: 0),
                    width: PrismBottomSheet.interestTileSelectedBorderWidth,
                  ),
                ),
              ),
              PositionedDirectional(
                top: PrismBottomSheet.interestTileLabelInset,
                end: PrismBottomSheet.interestTileLabelInset,
                child: AnimatedScale(
                  scale: selected ? 1 : 0,
                  duration: _kTileMotion,
                  curve: Curves.easeOut,
                  child: Container(
                    width: PrismBottomSheet.interestCheckBadgeSize,
                    height: PrismBottomSheet.interestCheckBadgeSize,
                    decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                    child: Icon(Icons.check_rounded, size: PrismBottomSheet.interestCheckIconSize, color: cs.onPrimary),
                  ),
                ),
              ),
              Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: onTap),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.saving, required this.onReset, required this.onSave});

  final bool saving;
  final VoidCallback? onReset;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PrismBottomSheet.horizontalPadding,
            vertical: PrismBottomSheet.actionsVerticalPadding,
          ),
          child: Row(
            children: <Widget>[
              TextButton(onPressed: onReset, child: const Text('Reset')),
              const SizedBox(width: PrismBottomSheet.sectionContentGap),
              Expanded(
                child: FilledButton(
                  onPressed: onSave,
                  child: saving
                      ? const SizedBox(
                          width: PrismBottomSheet.savingIndicatorSize,
                          height: PrismBottomSheet.savingIndicatorSize,
                          child: CircularProgressIndicator(strokeWidth: PrismBottomSheet.savingIndicatorStrokeWidth),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
