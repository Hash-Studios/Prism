import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/data/categories/category_definition.dart';
import 'package:Prism/features/auto_rotate/biz/bloc/auto_rotate_bloc.j.dart';
import 'package:Prism/features/auto_rotate/domain/entities/auto_rotate_config_entity.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

@RoutePage()
class AutoRotateScreen extends StatelessWidget {
  const AutoRotateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<AutoRotateBloc>()..add(const AutoRotateEvent.started()),
      child: const _AutoRotateView(),
    );
  }
}

class _AutoRotateView extends StatelessWidget {
  const _AutoRotateView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto Rotate'),
        centerTitle: false,
      ),
      body: BlocBuilder<AutoRotateBloc, AutoRotateState>(
        builder: (context, state) {
          if (state.status == LoadStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          return _AutoRotateBody(state: state);
        },
      ),
    );
  }
}

class _AutoRotateBody extends StatelessWidget {
  const _AutoRotateBody({required this.state});

  final AutoRotateState state;

  Color _accentColor(BuildContext context) {
    final c = Theme.of(context).colorScheme.error;
    return c == Colors.black ? Colors.grey : c;
  }

  TextStyle _titleStyle(BuildContext context) => TextStyle(
        color: Theme.of(context).colorScheme.secondary,
        fontWeight: FontWeight.w500,
        fontFamily: 'Proxima Nova',
      );

  Widget _sectionCard(BuildContext context, {required String title, required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Card(
        color: Theme.of(context).cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: _accentColor(context),
                  fontFamily: 'Proxima Nova',
                ),
              ),
            ),
            ...children,
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AutoRotateBloc>();
    final config = state.config;
    final isRunning = state.isRunning;
    final isLoading = state.actionStatus == ActionStatus.inProgress;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        // ── Status Banner ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: Card(
            color: isRunning
                ? Colors.green.withValues(alpha: 0.15)
                : Theme.of(context).cardColor,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isRunning ? Colors.green : Colors.transparent,
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.autorenew,
                        color: isRunning ? Colors.green : Theme.of(context).hintColor,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isRunning ? 'Auto Rotate is Running' : 'Auto Rotate is Stopped',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isRunning ? Colors.green : Theme.of(context).colorScheme.secondary,
                          fontFamily: 'Proxima Nova',
                        ),
                      ),
                    ],
                  ),
                  if (isRunning) ...[
                    const SizedBox(height: 8),
                    Text(
                      _statusSubtitle(config),
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () => bloc.add(const AutoRotateEvent.rotateNowRequested()),
                      icon: const Icon(Icons.skip_next_rounded, size: 18),
                      label: const Text('Rotate Now'),
                    ),
                  ],
                  if (state.failure != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        state.failure!.message,
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // ── Source Selection ──────────────────────────────────────────────────
        _sectionCard(
          context,
          title: 'SOURCE',
          children: [
            RadioListTile<AutoRotateSourceType>(
              activeColor: _accentColor(context),
              value: AutoRotateSourceType.favourites,
              groupValue: config.sourceType,
              title: Text('Favourites', style: _titleStyle(context)),
              subtitle: const Text('Your saved wallpapers', style: TextStyle(fontSize: 12)),
              onChanged: isRunning
                  ? null
                  : (_) => bloc.add(const AutoRotateEvent.sourceTypeChanged(
                        sourceType: AutoRotateSourceType.favourites,
                      )),
            ),
            RadioListTile<AutoRotateSourceType>(
              activeColor: _accentColor(context),
              value: AutoRotateSourceType.category,
              groupValue: config.sourceType,
              title: Text('Category', style: _titleStyle(context)),
              subtitle: const Text('Wallpapers from a category', style: TextStyle(fontSize: 12)),
              onChanged: isRunning
                  ? null
                  : (_) => bloc.add(const AutoRotateEvent.sourceTypeChanged(
                        sourceType: AutoRotateSourceType.category,
                        name: null,
                      )),
            ),
            if (config.sourceType == AutoRotateSourceType.category)
              _CategoryDropdown(
                categories: state.availableCategories.toList(),
                selectedName: config.categoryName,
                accentColor: _accentColor(context),
                enabled: !isRunning,
                onChanged: (name) => bloc.add(AutoRotateEvent.sourceTypeChanged(
                  sourceType: AutoRotateSourceType.category,
                  name: name,
                )),
              ),
            RadioListTile<AutoRotateSourceType>(
              activeColor: _accentColor(context),
              value: AutoRotateSourceType.collection,
              groupValue: config.sourceType,
              title: Text('Collection', style: _titleStyle(context)),
              subtitle: const Text('Wallpapers from a collection', style: TextStyle(fontSize: 12)),
              onChanged: isRunning
                  ? null
                  : (_) => bloc.add(const AutoRotateEvent.sourceTypeChanged(
                        sourceType: AutoRotateSourceType.collection,
                        name: null,
                      )),
            ),
            if (config.sourceType == AutoRotateSourceType.collection)
              _CollectionDropdown(
                collections: state.availableCollections,
                selectedName: config.collectionName,
                accentColor: _accentColor(context),
                enabled: !isRunning,
                onChanged: (name) => bloc.add(AutoRotateEvent.sourceTypeChanged(
                  sourceType: AutoRotateSourceType.collection,
                  name: name,
                )),
              ),
          ],
        ),

        // ── Target Screen ─────────────────────────────────────────────────────
        _sectionCard(
          context,
          title: 'SCREEN TARGET',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SegmentedButton<aw.WallpaperTarget>(
                selected: {config.target},
                onSelectionChanged: isRunning
                    ? null
                    : (selection) => bloc.add(AutoRotateEvent.targetChanged(target: selection.first)),
                segments: const [
                  ButtonSegment(value: aw.WallpaperTarget.home, label: Text('Home'), icon: Icon(Icons.home_outlined)),
                  ButtonSegment(
                      value: aw.WallpaperTarget.lock, label: Text('Lock'), icon: Icon(Icons.lock_outline)),
                  ButtonSegment(
                      value: aw.WallpaperTarget.both,
                      label: Text('Both'),
                      icon: Icon(Icons.phonelink_setup_outlined)),
                ],
              ),
            ),
          ],
        ),

        // ── Interval ─────────────────────────────────────────────────────────
        _sectionCard(
          context,
          title: 'INTERVAL',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _intervalOptions.map((opt) {
                  final isSelected = config.intervalMinutes == opt.minutes;
                  return ChoiceChip(
                    label: Text(opt.label),
                    selected: isSelected,
                    selectedColor: _accentColor(context).withValues(alpha: 0.2),
                    onSelected: isRunning ? null : (_) => bloc.add(AutoRotateEvent.intervalChanged(minutes: opt.minutes)),
                  );
                }).toList(),
              ),
            ),
          ],
        ),

        // ── Triggers ─────────────────────────────────────────────────────────
        _sectionCard(
          context,
          title: 'TRIGGERS',
          children: [
            SwitchListTile(
              activeColor: _accentColor(context),
              secondary: const Icon(Icons.bolt_outlined),
              value: config.chargingTrigger,
              title: Text('Change on Charging', style: _titleStyle(context)),
              subtitle: const Text('Rotate when device is plugged in', style: TextStyle(fontSize: 12)),
              onChanged: isRunning ? null : (_) => bloc.add(const AutoRotateEvent.chargingTriggerToggled()),
            ),
          ],
        ),

        // ── Order ─────────────────────────────────────────────────────────────
        _sectionCard(
          context,
          title: 'ORDER',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SegmentedButton<AutoRotateOrder>(
                selected: {config.order},
                onSelectionChanged: isRunning
                    ? null
                    : (selection) => bloc.add(AutoRotateEvent.orderChanged(order: selection.first)),
                segments: const [
                  ButtonSegment(
                    value: AutoRotateOrder.sequential,
                    label: Text('Sequential'),
                    icon: Icon(Icons.format_list_numbered),
                  ),
                  ButtonSegment(
                    value: AutoRotateOrder.shuffle,
                    label: Text('Shuffle'),
                    icon: Icon(Icons.shuffle),
                  ),
                ],
              ),
            ),
          ],
        ),

        // ── Action Button ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : isRunning
                    ? ElevatedButton.icon(
                        onPressed: () => bloc.add(const AutoRotateEvent.stopRequested()),
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const Text('Stop Auto Rotate'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: _canStart(config) ? () => bloc.add(const AutoRotateEvent.startRequested()) : null,
                        icon: const Icon(Icons.play_circle_outline),
                        label: const Text('Start Auto Rotate'),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
          ),
        ),
      ],
    );
  }

  bool _canStart(AutoRotateConfigEntity config) {
    if (config.sourceType == AutoRotateSourceType.category && (config.categoryName?.isEmpty ?? true)) return false;
    if (config.sourceType == AutoRotateSourceType.collection && (config.collectionName?.isEmpty ?? true)) return false;
    return true;
  }

  String _statusSubtitle(AutoRotateConfigEntity config) {
    final source = switch (config.sourceType) {
      AutoRotateSourceType.favourites => 'Favourites',
      AutoRotateSourceType.category => config.categoryName ?? 'Category',
      AutoRotateSourceType.collection => config.collectionName ?? 'Collection',
    };
    return 'Source: $source  •  Every ${_intervalLabel(config.intervalMinutes)}';
  }

  String _intervalLabel(int minutes) {
    if (minutes < 60) return '${minutes}min';
    final hours = minutes ~/ 60;
    return hours == 1 ? '1 hr' : '$hours hrs';
  }

  static const List<_IntervalOption> _intervalOptions = [
    _IntervalOption(minutes: 15, label: '15 min'),
    _IntervalOption(minutes: 30, label: '30 min'),
    _IntervalOption(minutes: 60, label: '1 hr'),
    _IntervalOption(minutes: 180, label: '3 hr'),
    _IntervalOption(minutes: 360, label: '6 hr'),
    _IntervalOption(minutes: 720, label: '12 hr'),
    _IntervalOption(minutes: 1440, label: '24 hr'),
  ];
}

class _IntervalOption {
  const _IntervalOption({required this.minutes, required this.label});

  final int minutes;
  final String label;
}

class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({
    required this.categories,
    required this.selectedName,
    required this.accentColor,
    required this.enabled,
    required this.onChanged,
  });

  final List<CategoryDefinition> categories;
  final String? selectedName;
  final Color accentColor;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: DropdownButtonFormField<String>(
        value: selectedName,
        decoration: InputDecoration(
          labelText: 'Select Category',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: accentColor),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        items: categories
            .map((c) => DropdownMenuItem(value: c.name, child: Text(c.name)))
            .toList(),
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}

class _CollectionDropdown extends StatelessWidget {
  const _CollectionDropdown({
    required this.collections,
    required this.selectedName,
    required this.accentColor,
    required this.enabled,
    required this.onChanged,
  });

  final List<String> collections;
  final String? selectedName;
  final Color accentColor;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (collections.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Text('No collections available.', style: TextStyle(fontSize: 12)),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: DropdownButtonFormField<String>(
        value: selectedName,
        decoration: InputDecoration(
          labelText: 'Select Collection',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: accentColor),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        items: collections.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}
