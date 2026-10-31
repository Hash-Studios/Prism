import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/auto_rotate/domain/entities/auto_rotate_config.dart';
import 'package:Prism/features/folders/biz/bloc/folders_bloc.j.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/views/folders_access.dart';
import 'package:Prism/features/folders/views/widgets/folder_cover.dart';
import 'package:Prism/features/folders/views/widgets/folder_picker_sheet.dart';
import 'package:Prism/features/ios_shortcuts/data/ios_shortcuts_support.dart';
import 'package:Prism/features/ios_shortcuts/data/shortcuts_folders_store.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

/// The manual build steps, shown when Remote Config has no shared shortcut link.
List<String> shortcutsManualSteps(AppLocalizations l10n) => <String>[
  l10n.shortcutsManualNew,
  l10n.shortcutsManualGet,
  l10n.shortcutsManualSet,
  l10n.shortcutsManualName(iosShortcutName),
];

List<String> shortcutsAutomationSteps(AppLocalizations l10n) => <String>[
  l10n.shortcutsAutomationOpen,
  l10n.shortcutsAutomationTime,
  l10n.shortcutsAutomationRun,
  l10n.shortcutsAutomationPick(iosShortcutName),
];

List<(String, String)> shortcutsGuideSources(AppLocalizations l10n) => <(String, String)>[
  (l10n.shortcutsSourceRotation, l10n.shortcutsSourceRotationDescription),
  (l10n.shortcutsSourceFolder, l10n.shortcutsSourceFolderDescription),
  (l10n.wallpaperShortcutsSourceFavourite, l10n.shortcutsSourceFavouriteDescription),
  (l10n.wallpaperShortcutsSourceWotd, l10n.wallpaperShortcutsSourceWotdDescription),
];

/// How to get a new wallpaper every day on iPhone: a shared or hand-built shortcut, a daily automation, a test run.
@RoutePage()
class IosShortcutsGuideScreen extends StatefulWidget {
  const IosShortcutsGuideScreen({super.key, this.source = 'settings'});

  /// Where the guide was opened from, for analytics: settings, folder_menu, auto_rotate or deep_link.
  final String source;

  @override
  State<IosShortcutsGuideScreen> createState() => _IosShortcutsGuideScreenState();
}

class _IosShortcutsGuideScreenState extends State<IosShortcutsGuideScreen> {
  final Uri? _link = iosShortcutLink();
  String? _rotationId;
  bool _rotationLoaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(ensureFoldersLoaded(context));
    unawaited(_loadRotation());
  }

  Future<void> _loadRotation() async {
    final String? id = await ShortcutsFoldersStore.rotationFolderId();
    if (!mounted) return;
    setState(() {
      _rotationId = id;
      _rotationLoaded = true;
    });
    unawaited(
      analytics.track(
        IosShortcutsGuideOpenedEvent(
          source: widget.source,
          hasShortcutLink: _link != null,
          hasRotationFolder: id != null,
        ),
      ),
    );
  }

  Future<void> _open(Uri uri, String kind) async {
    PrismHaptics.selection();
    final String error = context.l10n.wallpaperShortcutsOpenError;
    bool opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (error, stackTrace) {
      logger.w('Could not open Shortcuts', error: error, stackTrace: stackTrace);
    }
    unawaited(analytics.track(IosShortcutLinkOpenedEvent(kind: kind, opened: opened)));
    if (!opened) toasts.error(error);
  }

  Future<void> _change() async {
    final String ownerId = app_state.prismUser.id;
    final FolderEntity? picked = await pickFolder(context, _rotationId);
    if (picked == null || !mounted || app_state.prismUser.id != ownerId) return;
    await ShortcutsFoldersStore.setRotationFolder(picked.id);
    unawaited(
      analytics.track(IosRotationFolderSetEvent(source: 'guide', itemCountBucket: folderCountBucket(picked.itemCount))),
    );
    if (mounted) setState(() => _rotationId = picked.id);
  }

  Future<void> _stop() async {
    PrismHaptics.selection();
    await ShortcutsFoldersStore.setRotationFolder(null);
    if (mounted) setState(() => _rotationId = null);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Uri? link = _link;
    return PrismPage(
      title: l10n.wallpaperShortcutsTitle,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xs, PrismSpace.page, PrismSpace.xxl),
        children: <Widget>[
          Text(l10n.shortcutsGuideHeadline, style: PrismTextStyles.sectionTitle(context)),
          const SizedBox(height: PrismSpace.xs),
          Text(l10n.shortcutsGuideBody, style: PrismTextStyles.body(context)),
          PrismSectionHeader(title: l10n.shortcutsSourceRotation),
          _RotationCard(
            folderId: _rotationId,
            loaded: _rotationLoaded,
            onChange: () => unawaited(_change()),
            onStop: () => unawaited(_stop()),
          ),
          const SizedBox(height: PrismSpace.xl),
          _Step(
            number: 1,
            title: l10n.shortcutsStepAddTitle,
            body: link == null ? l10n.shortcutsStepAddManualBody : l10n.shortcutsStepAddBody,
            lines: link == null ? shortcutsManualSteps(l10n) : const <String>[],
            action: link == null
                ? PrismButton(
                    label: l10n.wallpaperShortcutsOpenAction,
                    icon: Icons.open_in_new_rounded,
                    variant: PrismButtonVariant.tonal,
                    onPressed: () => unawaited(_open(Uri.parse('shortcuts://'), 'app')),
                  )
                : PrismButton(
                    label: l10n.shortcutsStepAddAction,
                    icon: Icons.add_rounded,
                    expand: true,
                    onPressed: () => unawaited(_open(link, 'icloud')),
                  ),
          ),
          _Step(
            number: 2,
            title: l10n.shortcutsStepAutomationTitle,
            lines: shortcutsAutomationSteps(l10n),
            note: '${l10n.shortcutsAutomationNoTab(iosShortcutName)}\n${l10n.shortcutsAutomationIos16}',
          ),
          _Step(
            number: 3,
            title: l10n.shortcutsStepTestTitle,
            body: l10n.shortcutsStepTestBody(iosShortcutName),
            action: PrismButton(
              label: l10n.shortcutsStepTestAction,
              icon: Icons.play_arrow_rounded,
              variant: PrismButtonVariant.tonal,
              onPressed: () => unawaited(_open(iosRunShortcutUri(), 'run')),
            ),
          ),
          PrismSectionHeader(title: l10n.wallpaperShortcutsChoosePrismData),
          PrismGroup(
            children: <Widget>[
              for (final (String name, String detail) in shortcutsGuideSources(l10n))
                PrismRow(icon: Icons.photo_outlined, title: name, subtitle: detail, showChevron: false),
            ],
          ),
        ],
      ),
    );
  }
}

class _RotationCard extends StatelessWidget {
  const _RotationCard({required this.folderId, required this.loaded, required this.onChange, required this.onStop});

  final String? folderId;
  final bool loaded;
  final VoidCallback onChange;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final FoldersState state = context.watch<FoldersBloc>().state;
    final FolderEntity? folder = folderId == null ? null : state.folder(folderId!);
    final bool waiting = !loaded || (folderId != null && folder == null && state.status != LoadStatus.success);
    final Widget child = waiting
        ? const PrismSkeleton(child: PrismBone(height: 116, radius: PrismRadius.lg))
        : PrismCard(
            key: ValueKey<String?>(folder?.id),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    if (folder == null)
                      Icon(Icons.folder_outlined, size: 32, color: Theme.of(context).colorScheme.onSurfaceVariant)
                    else
                      FolderCover(covers: folder.covers, size: 48),
                    const SizedBox(width: PrismSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(folder?.name ?? l10n.shortcutsRotationNone, style: PrismTextStyles.cardTitle(context)),
                          const SizedBox(height: PrismSpace.xxs),
                          Text(
                            folder == null ? l10n.shortcutsRotationNoneBody : l10n.foldersItemCount(folder.itemCount),
                            style: PrismTextStyles.caption(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: PrismSpace.sm),
                Row(
                  children: <Widget>[
                    PrismButton(
                      label: folder == null ? l10n.shortcutsRotationPick : l10n.shortcutsRotationChange,
                      variant: PrismButtonVariant.tonal,
                      size: PrismButtonSize.compact,
                      onPressed: onChange,
                    ),
                    if (folder != null) ...<Widget>[
                      const SizedBox(width: PrismSpace.xs),
                      PrismButton(
                        label: l10n.shortcutsRotationStop,
                        variant: PrismButtonVariant.ghost,
                        size: PrismButtonSize.compact,
                        onPressed: onStop,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
    return AnimatedSwitcher(duration: context.motion(PrismDurations.fast), child: child);
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    this.body,
    this.lines = const <String>[],
    this.note,
    this.action,
  });

  final int number;
  final String title;
  final String? body;
  final List<String> lines;
  final String? note;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: PrismSpace.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExcludeSemantics(
            child: CircleAvatar(
              radius: 14,
              backgroundColor: cs.primary.withValues(alpha: 0.14),
              child: Text(
                '$number',
                style: PrismTextStyles.caption(context).copyWith(color: cs.primary, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: PrismSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Semantics(
                  header: true,
                  label: context.l10n.shortcutsStepLabel(number, title),
                  excludeSemantics: true,
                  child: Text(title, style: PrismTextStyles.cardTitle(context)),
                ),
                if (body case final String text) ...<Widget>[
                  const SizedBox(height: PrismSpace.xxs),
                  Text(text, style: PrismTextStyles.body(context)),
                ],
                for (final String line in lines)
                  Padding(
                    padding: const EdgeInsets.only(top: PrismSpace.xs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(color: cs.onSurfaceVariant, shape: BoxShape.circle),
                          ),
                        ),
                        const SizedBox(width: PrismSpace.xs),
                        Expanded(
                          child: Text(
                            line,
                            style: PrismTextStyles.rowTitle(context).copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (note case final String text) ...<Widget>[
                  const SizedBox(height: PrismSpace.xs),
                  Text(text, style: PrismTextStyles.caption(context)),
                ],
                if (action case final Widget button) ...<Widget>[const SizedBox(height: PrismSpace.sm), button],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
