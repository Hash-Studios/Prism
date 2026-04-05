import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/personalized_interests_catalog.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/onboarding_v2/src/domain/usecases/save_interests_usecase.dart';
import 'package:Prism/features/onboarding_v2/src/utils/onboarding_v2_config.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';

/// Opens the same "Your feed" interests / mix sheet used from the home tab logo.
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
  final String currentMix = settingsLocal.get<String>(personalizedFeedMixLocalKey, defaultValue: 'balanced');

  if (!context.mounted) {
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => PersonalizedFeedSettingsSheet(
      catalog: catalog,
      initialInterests: selected,
      initialFeedMix: currentMix,
      onSave: (List<String> interests, String feedMix) async {
        final bool persisted = await _persistInterests(settingsLocal, interests);
        if (!persisted) {
          return;
        }
        await settingsLocal.set(personalizedFeedMixLocalKey, feedMix);
        onPreferencesSaved?.call();
      },
    ),
  );
}

Future<bool> _persistInterests(SettingsLocalDataSource settingsLocal, List<String> interests) async {
  await settingsLocal.set('onboarding_v2_interests', interests.join(','));
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
  final String initialFeedMix;
  final Future<void> Function(List<String> interests, String feedMix) onSave;

  @override
  State<PersonalizedFeedSettingsSheet> createState() => _PersonalizedFeedSettingsSheetState();
}

class _PersonalizedFeedSettingsSheetState extends State<PersonalizedFeedSettingsSheet> {
  late Set<String> _selectedInterests;
  late String _feedMix;
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
      _feedMix = 'balanced';
    });
  }

  Future<void> _save() async {
    if (!_canSave) {
      return;
    }
    setState(() => _saving = true);
    await widget.onSave(_selectedInterests.toList(growable: false), _feedMix);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;
    final int count = _selectedInterests.length;
    final bool belowMin = count < OnboardingV2Config.minInterests;
    final double keyboardPadding = MediaQuery.viewInsetsOf(context).bottom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: 12),
        const _DragHandle(),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text('Your feed', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('$count selected', style: tt.bodySmall?.copyWith(color: belowMin ? cs.error : cs.onSurfaceVariant)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 4),
          child: Text('Interests', style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final PersonalizedInterest entry in widget.catalog)
                  FilterChip(
                    label: Text(entry.name),
                    selected: _selectedInterests.contains(entry.name),
                    avatar: CircleAvatar(backgroundImage: CachedNetworkImageProvider(entry.imageUrl)),
                    onSelected: (bool selected) {
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
          padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 4),
          child: Text('Feed mix', style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16),
          child: _FeedMixSelector(value: _feedMix, onChanged: (String v) => setState(() => _feedMix = v)),
        ),
        const Divider(height: 1, indent: 20, endIndent: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: <Widget>[
              TextButton(onPressed: _saving ? null : _resetToDefaults, child: const Text('Reset to defaults')),
              const Spacer(),
              FilledButton(
                onPressed: _canSave ? _save : null,
                child: _saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save'),
              ),
            ],
          ),
        ),
        SizedBox(height: keyboardPadding + 8),
      ],
    );
  }
}

class _FeedMixSelector extends StatelessWidget {
  const _FeedMixSelector({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return SegmentedButton<String>(
      segments: const <ButtonSegment<String>>[
        ButtonSegment<String>(value: 'balanced', label: Text('Balanced')),
        ButtonSegment<String>(value: 'creators', label: Text('Creators')),
        ButtonSegment<String>(value: 'discovery', label: Text('Discovery')),
      ],
      selected: <String>{value},
      onSelectionChanged: (Set<String> s) {
        if (s.isNotEmpty) {
          onChanged(s.first);
        }
      },
      expandedInsets: EdgeInsets.zero,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => states.contains(WidgetState.selected) ? cs.primary : null,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => states.contains(WidgetState.selected) ? cs.onPrimary : cs.onSurface,
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: 4,
        width: 32,
        decoration: BoxDecoration(color: Theme.of(context).hintColor, borderRadius: BorderRadius.circular(99)),
      ),
    );
  }
}
