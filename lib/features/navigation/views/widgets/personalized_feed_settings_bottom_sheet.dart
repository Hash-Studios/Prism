import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/personalized_interests_catalog.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_sheet_chrome.dart';
import 'package:Prism/features/onboarding_v2/src/common/onboarding_v2_keys.dart';
import 'package:Prism/features/onboarding_v2/src/domain/usecases/save_interests_usecase.dart';
import 'package:Prism/features/onboarding_v2/src/utils/onboarding_v2_config.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';

enum FeedMix {
  balanced('Balanced'),
  creators('Creators'),
  discovery('Discovery');

  const FeedMix(this.label);

  final String label;

  static FeedMix fromName(String name) =>
      FeedMix.values.firstWhere((FeedMix mix) => mix.name == name, orElse: () => FeedMix.balanced);
}

Future<void> openPersonalizedFeedSettingsBottomSheet(BuildContext context, {VoidCallback? onPreferencesSaved}) async {
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
  final FeedMix currentMix = FeedMix.fromName(
    settingsLocal.get<String>(personalizedFeedMixLocalKey, defaultValue: FeedMix.balanced.name),
  );

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => PersonalizedFeedSettingsSheet(
      catalog: catalog,
      initialInterests: selected,
      initialFeedMix: currentMix,
      onSave: (List<String> interests, FeedMix feedMix) async {
        final bool persisted = await _persistInterests(settingsLocal, interests);
        if (!persisted) {
          return false;
        }
        await settingsLocal.set(personalizedFeedMixLocalKey, feedMix.name);
        onPreferencesSaved?.call();
        return true;
      },
    ),
  );
}

Future<bool> _persistInterests(SettingsLocalDataSource settingsLocal, List<String> interests) async {
  await settingsLocal.set(OnboardingV2Keys.selectedInterests, interests.join(','));
  if (!app_state.prismUser.loggedIn) {
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
  });

  final List<PersonalizedInterest> catalog;
  final Set<String> initialInterests;
  final FeedMix initialFeedMix;
  final Future<bool> Function(List<String> interests, FeedMix feedMix) onSave;

  @override
  State<PersonalizedFeedSettingsSheet> createState() => _PersonalizedFeedSettingsSheetState();
}

class _PersonalizedFeedSettingsSheetState extends State<PersonalizedFeedSettingsSheet> {
  late Set<String> _selectedInterests;
  late FeedMix _feedMix;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedInterests = {...widget.initialInterests};
    _feedMix = widget.initialFeedMix;
  }

  bool get _canSave => !_saving && _selectedInterests.length >= OnboardingV2Config.minInterests;

  void _resetToDefaults() {
    final List<String> defaults = PersonalizedInterestsCatalog.defaultSelection(widget.catalog);
    setState(() {
      _selectedInterests = defaults.toSet();
      _feedMix = FeedMix.balanced;
    });
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    final bool saved = await widget.onSave(_selectedInterests.toList(growable: false), _feedMix);
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
      toasts.error("Couldn't save your feed. Try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final int count = _selectedInterests.length;
    final bool belowMin = count < OnboardingV2Config.minInterests;
    final double keyboardPadding = MediaQuery.viewInsetsOf(context).bottom;

    // Count badge color: pink when something is selected, error when below min,
    // muted when nothing is selected yet.
    final Color countColor = belowMin
        ? cs.error
        : count > 0
        ? PrismColors.brandPink
        : cs.onSurfaceVariant;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: PrismBottomSheet.topGap),
        const AiSheetDragHandle(),
        const SizedBox(height: PrismBottomSheet.headerGap),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: PrismBottomSheet.horizontalPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text('Your feed', style: PrismTextStyles.sheetTitle(context)),
              const Spacer(),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: PrismTextStyles.sheetSectionLabel(context).copyWith(color: countColor),
                child: Text('$count selected'),
              ),
            ],
          ),
        ),
        const SizedBox(height: PrismBottomSheet.headerGap),

        Padding(
          padding: const EdgeInsets.only(
            left: PrismBottomSheet.horizontalPadding,
            right: PrismBottomSheet.horizontalPadding,
            bottom: PrismBottomSheet.sectionLabelBottomGap,
          ),
          child: Text('Interests', style: PrismTextStyles.sheetSectionLabel(context)),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: PrismBottomSheet.chipAreaPadding,
            child: Wrap(
              spacing: PrismBottomSheet.chipSpacing,
              runSpacing: PrismBottomSheet.chipRunSpacing,
              children: <Widget>[
                for (final PersonalizedInterest entry in widget.catalog)
                  _InterestChip(
                    entry: entry,
                    selected: _selectedInterests.contains(entry.name),
                    onToggle: (bool selected) {
                      setState(() {
                        if (selected) {
                          _selectedInterests.add(entry.name);
                        } else {
                          _selectedInterests.remove(entry.name);
                        }
                      });
                    },
                  ),
              ],
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.only(
            left: PrismBottomSheet.horizontalPadding,
            right: PrismBottomSheet.horizontalPadding,
            top: PrismBottomSheet.sectionTopGap,
            bottom: PrismBottomSheet.sectionLabelBottomGap,
          ),
          child: Text('Feed mix', style: PrismTextStyles.sheetSectionLabel(context)),
        ),
        Padding(
          padding: const EdgeInsets.only(
            left: PrismBottomSheet.horizontalPadding,
            right: PrismBottomSheet.horizontalPadding,
            bottom: PrismBottomSheet.sectionTopGap,
          ),
          child: _FeedMixSelector(value: _feedMix, onChanged: (FeedMix v) => setState(() => _feedMix = v)),
        ),

        const Divider(
          height: 1,
          indent: PrismBottomSheet.horizontalPadding,
          endIndent: PrismBottomSheet.horizontalPadding,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PrismBottomSheet.horizontalPadding,
            vertical: PrismBottomSheet.actionsVerticalPadding,
          ),
          child: Row(
            children: <Widget>[
              TextButton(
                onPressed: _saving ? null : _resetToDefaults,
                style: TextButton.styleFrom(foregroundColor: PrismColors.brandPink),
                child: const Text('Reset to defaults'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _canSave ? _save : null,
                style: FilledButton.styleFrom(
                  backgroundColor: PrismColors.brandPink,
                  foregroundColor: PrismColors.onPrimary,
                ),
                child: _saving
                    ? const SizedBox(
                        width: PrismBottomSheet.savingIndicatorSize,
                        height: PrismBottomSheet.savingIndicatorSize,
                        child: CircularProgressIndicator(
                          strokeWidth: PrismBottomSheet.savingIndicatorStrokeWidth,
                          color: PrismColors.onPrimary,
                        ),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        ),
        SizedBox(height: keyboardPadding + PrismBottomSheet.keyboardSafetyBuffer),
      ],
    );
  }
}

/// A single interest chip that always uses Prism brand pink for its selected
/// state, regardless of which theme is active.
class _InterestChip extends StatelessWidget {
  const _InterestChip({required this.entry, required this.selected, required this.onToggle});

  final PersonalizedInterest entry;
  final bool selected;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return FilterChip(
      label: Text(entry.name),
      selected: selected,
      // Lock selected colours to Prism brand pink so they never go cyan/blue.
      selectedColor: PrismColors.brandPink.withValues(alpha: 0.15),
      checkmarkColor: PrismColors.brandPink,
      side: BorderSide(
        color: selected ? PrismColors.brandPink : cs.outline.withValues(alpha: 0.5),
        width: selected ? 1.5 : 1.0,
      ),
      labelStyle: TextStyle(
        color: selected ? PrismColors.brandPink : cs.onSurface,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      avatar: CircleAvatar(
        backgroundColor: cs.surfaceContainerHighest,
        backgroundImage: CachedNetworkImageProvider(entry.imageUrl),
      ),
      onSelected: onToggle,
    );
  }
}

/// Feed-mix segmented button with explicit brand-pink selected state.
class _FeedMixSelector extends StatelessWidget {
  const _FeedMixSelector({required this.value, required this.onChanged});

  final FeedMix value;
  final ValueChanged<FeedMix> onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return SegmentedButton<FeedMix>(
      segments: <ButtonSegment<FeedMix>>[
        for (final FeedMix mix in FeedMix.values)
          ButtonSegment<FeedMix>(
            value: mix,
            label: Text(mix.label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
      ],
      selected: <FeedMix>{value},
      onSelectionChanged: (Set<FeedMix> s) {
        if (s.isNotEmpty) onChanged(s.first);
      },
      expandedInsets: EdgeInsets.zero,
      style: ButtonStyle(
        // Compact horizontal padding so "Discovery" never wraps on narrow screens.
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8)),
        // Brand pink replaces whatever cs.primary happens to be in the active theme.
        backgroundColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => states.contains(WidgetState.selected) ? PrismColors.brandPink : null,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => states.contains(WidgetState.selected) ? PrismColors.onPrimary : cs.onSurface,
        ),
        iconColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => states.contains(WidgetState.selected) ? PrismColors.onPrimary : cs.onSurface,
        ),
      ),
    );
  }
}
