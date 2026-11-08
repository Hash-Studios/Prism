import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/color/prism_palette.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/data/categories/category_definition.dart';
import 'package:Prism/features/folders/biz/bloc/folders_bloc.j.dart';
import 'package:Prism/features/folders/biz/smart_folder_builder_cubit.dart';
import 'package:Prism/features/folders/data/smart_folder_creators.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/domain/entities/smart_rule.dart';
import 'package:Prism/features/folders/domain/repositories/smart_folders_repository.dart';
import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:Prism/features/moods/views/mood_copy.dart';
import 'package:Prism/features/public_profile/domain/entities/user_summary_entity.dart';
import 'package:Prism/features/public_profile/domain/repositories/public_profile_repository.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const int smartMaxFolders = 20;

String smartKindLabel(SmartRuleKind kind, AppLocalizations l10n) => switch (kind) {
  SmartRuleKind.mood => l10n.foldersSmartKindMood,
  SmartRuleKind.colour => l10n.foldersSmartKindColour,
  SmartRuleKind.category => l10n.foldersSmartKindCategory,
  SmartRuleKind.followed => l10n.foldersSmartKindFollowed,
  SmartRuleKind.creator => l10n.foldersSmartKindCreator,
  SmartRuleKind.desktop => l10n.foldersSmartKindDesktop,
  SmartRuleKind.editorsChoice => l10n.editorsChoiceTitle,
};

String smartCreatorName(UserSummaryEntity user) => user.username.isNotEmpty ? '@${user.username}' : user.name;

String smartValueLabel(
  SmartRule rule,
  AppLocalizations l10n, {
  Map<String, String> creatorNames = const <String, String>{},
}) => switch (rule.kind) {
  SmartRuleKind.mood => WallMood.parse(rule.value)?.title(l10n) ?? rule.value,
  SmartRuleKind.colour => prismPaletteColorDisplayName(
    prismPalette.firstWhere((colour) => colour.id == rule.value, orElse: () => prismPalette.first),
    l10n,
  ),
  SmartRuleKind.category => categoryDisplayName(rule.value, l10n),
  SmartRuleKind.creator => creatorNames[rule.value] ?? l10n.foldersSmartKindCreator,
  _ => smartKindLabel(rule.kind, l10n),
};

/// One line for each rule kind: "Colour: Blue, Teal", or the label alone for an on or off rule.
List<String> smartRuleSummary(
  List<SmartRule> rules,
  AppLocalizations l10n, {
  Map<String, String> creatorNames = const <String, String>{},
}) => <String>[
  for (final MapEntry<SmartRuleKind, List<String>> group in smartRulesByKind(rules).entries)
    if (group.key.hasValue)
      l10n.foldersSmartRuleSummary(
        smartKindLabel(group.key, l10n),
        group.value
            .map((value) => smartValueLabel(SmartRule(group.key, value), l10n, creatorNames: creatorNames))
            .join(', '),
      )
    else
      smartKindLabel(group.key, l10n),
];

List<String> smartRuleKindsForAnalytics(List<SmartRule> rules) => <String>[
  for (final SmartRuleKind kind in smartRulesByKind(rules).keys) kind.wire,
];

String _refusalMessage(Object? failure, AppLocalizations l10n) {
  if (failure is! SmartFolderFailure) return l10n.foldersSmartSaveFailed;
  return switch (failure.refusal) {
    SmartFolderRefusal.limit when failure.message == 'limit' => l10n.foldersSmartLimitRefused(smartMaxFolders),
    SmartFolderRefusal.limit => l10n.foldersSmartTooManyChanges,
    _ => l10n.foldersSmartSaveFailed,
  };
}

typedef _SheetResult = ({String folderId, int count});

/// Opens the rule builder. With [folder], it edits that smart folder's rules. Without it, it creates a smart folder and
/// opens it.
Future<void> showSmartFolderSheet(
  BuildContext context, {
  FolderEntity? folder,
  SmartFoldersRepository? repository,
  Future<List<UserSummaryEntity>> Function()? loadCreators,
}) async {
  final String uid = app_state.prismUser.id;
  if (uid.isEmpty) return;
  final FoldersBloc bloc = context.read<FoldersBloc>();
  final StackRouter router = context.router;
  final AppLocalizations l10n = context.l10n;
  final List<SmartRule> initial = folder?.smartRules ?? const <SmartRule>[];
  final SmartFolderBuilderCubit cubit = SmartFolderBuilderCubit(
    repository ?? getIt<SmartFoldersRepository>(),
    initialRules: initial,
    loadCreators:
        loadCreators ??
        () => loadSmartFolderCreators(getIt<PublicProfileRepository>(), uid, <String>[
          for (final SmartRule rule in initial)
            if (rule.kind == SmartRuleKind.creator) rule.value,
        ]),
  );
  final _SheetResult? result = await showPrismSheet<_SheetResult>(
    context,
    dismissKeyboardOnDrag: true,
    builder: (sheetContext) => BlocProvider<SmartFolderBuilderCubit>.value(
      value: cubit,
      child: SmartFolderSheet(folder: folder),
    ),
  );
  await cubit.close();
  if (result == null || app_state.prismUser.id != uid || bloc.state.userId != uid) return;
  await bloc.run((id) => FoldersEvent.started(userId: uid, operationId: id));
  if (folder == null) {
    toasts.success(l10n.foldersSmartCreated(result.count));
    unawaited(router.push(FolderRoute(folderId: result.folderId)));
  } else {
    toasts.success(l10n.foldersSmartRulesSaved(result.count));
    await bloc.run((id) => FoldersEvent.folderOpened(folderId: folder.id, operationId: id));
  }
}

/// The sheet body. Build it inside [showSmartFolderSheet], under a [SmartFolderBuilderCubit].
class SmartFolderSheet extends StatefulWidget {
  const SmartFolderSheet({super.key, this.folder});

  final FolderEntity? folder;

  @override
  State<SmartFolderSheet> createState() => _SmartFolderSheetState();
}

class _SmartFolderSheetState extends State<SmartFolderSheet> {
  final TextEditingController _name = TextEditingController();
  final String _ownerId = app_state.prismUser.id;

  bool get _creating => widget.folder == null;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool _canSave(SmartFolderBuilderState state) {
    if (_ownerId.isEmpty || app_state.prismUser.id != _ownerId || state.rules.isEmpty || state.saving) return false;
    if (_creating) return normalizeFolderName(_name.text) != null;
    final List<SmartRule> before = sortSmartRules(widget.folder!.smartRules ?? const <SmartRule>[]);
    return before.length != state.rules.length || before.indexed.any((entry) => state.rules[entry.$1] != entry.$2);
  }

  Future<void> _save() async {
    if (_ownerId.isEmpty || app_state.prismUser.id != _ownerId) return;
    final SmartFolderBuilderCubit cubit = context.read<SmartFolderBuilderCubit>();
    final AppLocalizations l10n = context.l10n;
    final NavigatorState navigator = Navigator.of(context);
    final List<SmartRule> rules = cubit.state.rules;
    if (_creating) {
      final Result<({String folderId, int count})> result = await cubit.create(normalizeFolderName(_name.text)!);
      final ({String folderId, int count})? created = result.data;
      if (created == null) {
        toasts.error(_refusalMessage(result.failure, l10n));
        return;
      }
      unawaited(
        analytics.track(
          SmartFolderCreatedEvent(
            ruleKinds: smartRuleKindsForAnalytics(rules),
            ruleCount: rules.length,
            matchCount: created.count,
          ),
        ),
      );
      if (mounted) navigator.pop<_SheetResult>(created);
      return;
    }
    final String folderId = widget.folder!.id;
    final Result<int> result = await cubit.saveRules(folderId);
    final int? count = result.data;
    if (count == null) {
      toasts.error(_refusalMessage(result.failure, l10n));
      return;
    }
    unawaited(
      analytics.track(
        SmartFolderRulesEditedEvent(
          ruleKinds: smartRuleKindsForAnalytics(rules),
          ruleCount: rules.length,
          matchCount: count,
        ),
      ),
    );
    if (mounted) navigator.pop<_SheetResult>((folderId: folderId, count: count));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return BlocBuilder<SmartFolderBuilderCubit, SmartFolderBuilderState>(
      builder: (context, state) => PrismSheetBody(
        title: _creating ? l10n.foldersSmartNew : l10n.foldersSmartEditRules,
        childScrolls: true,
        actions: <Widget>[
          PrismButton(
            key: const ValueKey<String>('smart-folder-save'),
            label: _creating ? l10n.foldersSmartCreate : l10n.foldersSmartSaveRules,
            expand: true,
            loading: state.saving,
            onPressed: _canSave(state) ? () => unawaited(_save()) : null,
          ),
        ],
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(PrismSpace.page, 0, PrismSpace.page, PrismSpace.md),
          children: <Widget>[
            if (_creating) ...<Widget>[
              Text(l10n.foldersSmartIntro, style: PrismTextStyles.body(context)),
              const SizedBox(height: PrismSpace.lg),
              PrismTextField(
                key: const ValueKey<String>('smart-folder-name'),
                controller: _name,
                label: l10n.foldersNameHint,
                hint: l10n.foldersNameHint,
              ),
              const SizedBox(height: PrismSpace.xl),
            ],
            SmartRuleBuilder(state: state),
            const SizedBox(height: PrismSpace.xl),
            SmartPreviewSection(state: state),
          ],
        ),
      ),
    );
  }
}

/// The rule chips. A kind with values is a labelled wrap of chips. The on or off kinds share one "Only" group.
class SmartRuleBuilder extends StatelessWidget {
  const SmartRuleBuilder({super.key, required this.state});

  final SmartFolderBuilderState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SmartFolderBuilderCubit cubit = context.read<SmartFolderBuilderCubit>();
    final bool ios = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final Map<String, String> names = <String, String>{
      for (final UserSummaryEntity user in state.creators ?? const <UserSummaryEntity>[])
        user.id: smartCreatorName(user),
    };

    Widget chip(SmartRule rule, {Widget? leading, IconData? icon}) => PrismChip(
      key: ValueKey<String>('smart-rule-${rule.kind.wire}-${rule.value}'),
      label: smartValueLabel(rule, l10n, creatorNames: names),
      leading: leading,
      icon: icon,
      selected: state.rules.contains(rule),
      onTap: () {
        PrismHaptics.selection();
        cubit.toggle(rule);
      },
    );

    final List<UserSummaryEntity>? creators = state.creators;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(header: true, child: Text(l10n.foldersSmartRulesTitle, style: PrismTextStyles.sectionTitle(context))),
        const SizedBox(height: PrismSpace.xxs),
        Text(l10n.foldersSmartRulesHint, style: PrismTextStyles.caption(context)),
        _BlockedNote(blocked: state.blocked),
        _RuleGroup(
          title: l10n.foldersSmartKindMood,
          chips: <Widget>[
            for (final WallMood mood in WallMood.values)
              if (ios || mood.iosMajor == null) chip(SmartRule(SmartRuleKind.mood, mood.id)),
          ],
        ),
        _RuleGroup(
          title: l10n.foldersSmartKindColour,
          chips: <Widget>[
            for (final PrismPaletteColor colour in prismPalette)
              chip(SmartRule(SmartRuleKind.colour, colour.id), leading: _ColourDot(colour: colour.color)),
          ],
        ),
        _RuleGroup(
          title: l10n.foldersSmartKindCategory,
          chips: <Widget>[for (final String name in smartCategoryNames) chip(SmartRule(SmartRuleKind.category, name))],
        ),
        _RuleGroup(
          title: l10n.foldersSmartKindCreator,
          empty: creators != null && creators.isEmpty && !state.rules.any((rule) => rule.kind == SmartRuleKind.creator)
              ? l10n.foldersSmartNoCreators
              : null,
          chips: <Widget>[
            if (creators == null) const PrismSkeleton(child: PrismBone(width: 160, height: 36, radius: 18)),
            for (final UserSummaryEntity user in creators ?? const <UserSummaryEntity>[])
              chip(
                SmartRule(SmartRuleKind.creator, user.id),
                leading: PrismAvatar(url: user.profilePhoto, name: user.name, size: 20),
              ),
            for (final SmartRule rule in state.rules)
              if (rule.kind == SmartRuleKind.creator && !names.containsKey(rule.value)) chip(rule),
          ],
        ),
        _RuleGroup(
          title: l10n.foldersSmartKindOnly,
          chips: <Widget>[
            chip(const SmartRule(SmartRuleKind.followed), icon: Icons.people_alt_rounded),
            chip(const SmartRule(SmartRuleKind.desktop), icon: Icons.desktop_windows_rounded),
            chip(const SmartRule(SmartRuleKind.editorsChoice), icon: Icons.workspace_premium_rounded),
          ],
        ),
      ],
    );
  }
}

class _BlockedNote extends StatelessWidget {
  const _BlockedNote({required this.blocked});

  final SmartRuleBlock? blocked;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String? text = switch (blocked) {
      SmartRuleBlock.kindLimit => l10n.foldersSmartKindLimit(smartMaxKinds),
      SmartRuleBlock.valueLimit => l10n.foldersSmartValueLimit(smartMaxValuesPerKind),
      null => null,
    };
    return AnimatedSwitcher(
      duration: context.motion(PrismDurations.fast),
      switchInCurve: PrismCurves.enter,
      switchOutCurve: PrismCurves.exitReverse,
      child: text == null
          ? const SizedBox(key: ValueKey<String>('smart-blocked-none'), width: double.infinity)
          : Padding(
              key: ValueKey<String>('smart-blocked-$text'),
              padding: const EdgeInsets.only(top: PrismSpace.xs),
              child: Semantics(
                liveRegion: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(Icons.info_outline_rounded, size: 16, color: cs.onSurface),
                    const SizedBox(width: PrismSpace.xs),
                    Expanded(
                      child: Text(text, style: PrismTextStyles.caption(context).copyWith(color: cs.onSurface)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _RuleGroup extends StatelessWidget {
  const _RuleGroup({required this.title, required this.chips, this.empty});

  final String title;
  final List<Widget> chips;
  final String? empty;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: PrismSpace.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(header: true, child: Text(title, style: PrismTextStyles.rowTitle(context))),
        const SizedBox(height: PrismSpace.xs),
        if (empty case final String text)
          Text(text, style: PrismTextStyles.caption(context))
        else
          Wrap(spacing: PrismSpace.xs, runSpacing: PrismSpace.xs, children: chips),
      ],
    ),
  );
}

class _ColourDot extends StatelessWidget {
  const _ColourDot({required this.colour});

  final Color colour;

  @override
  Widget build(BuildContext context) => Container(
    width: 14,
    height: 14,
    decoration: BoxDecoration(
      color: colour,
      shape: BoxShape.circle,
      border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.16)),
    ),
  );
}

/// The count and the first matches. It keeps the last grid while a new preview loads.
class SmartPreviewSection extends StatelessWidget {
  const SmartPreviewSection({super.key, required this.state});

  final SmartFolderBuilderState state;

  static const int _columns = 4;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SmartPreview? preview = state.preview;
    final SmartPreviewStatus status = state.previewStatus;
    final bool loading = status == SmartPreviewStatus.loading;
    final String? count = preview == null || (status != SmartPreviewStatus.ready && !loading)
        ? null
        : preview.more
        ? l10n.foldersSmartMatchesMore(preview.count)
        : l10n.foldersSmartMatches(preview.count);
    final Widget body;
    if (status == SmartPreviewStatus.noRules) {
      body = Text(
        l10n.foldersSmartPickRule,
        key: const ValueKey<String>('smart-preview-pick'),
        style: PrismTextStyles.caption(context),
      );
    } else if (status == SmartPreviewStatus.failure) {
      body = Column(
        key: const ValueKey<String>('smart-preview-error'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.foldersSmartPreviewError, style: PrismTextStyles.caption(context)),
          const SizedBox(height: PrismSpace.xs),
          PrismButton(
            label: l10n.wallpaperTryAgain,
            variant: PrismButtonVariant.tonal,
            onPressed: context.read<SmartFolderBuilderCubit>().retryPreview,
          ),
        ],
      );
    } else if (preview == null) {
      body = const _PreviewSkeleton(columns: _columns);
    } else if (preview.count == 0) {
      body = Text(
        l10n.foldersSmartNoMatchesHint,
        key: const ValueKey<String>('smart-preview-empty'),
        style: PrismTextStyles.body(context),
      );
    } else {
      body = AnimatedOpacity(
        key: const ValueKey<String>('smart-preview-grid'),
        opacity: loading ? 0.5 : 1,
        duration: context.motion(PrismDurations.fast),
        child: ExcludeSemantics(
          child: GridView.count(
            crossAxisCount: _columns,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: PrismSpace.xs,
            crossAxisSpacing: PrismSpace.xs,
            childAspectRatio: 9 / 16,
            children: <Widget>[for (final SmartPreviewWall wall in preview.walls) PrismWallTile(url: wall.thumb)],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: PrismSpace.sm,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(l10n.foldersSmartPreviewTitle, style: PrismTextStyles.sectionTitle(context)),
            ),
            if (count != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  count,
                  key: const ValueKey<String>('smart-preview-count'),
                  style: PrismTextStyles.rowTitle(context),
                ),
              ),
          ],
        ),
        const SizedBox(height: PrismSpace.sm),
        AnimatedSwitcher(
          duration: context.motion(PrismDurations.fast),
          switchInCurve: PrismCurves.enter,
          switchOutCurve: PrismCurves.exitReverse,
          child: body,
        ),
      ],
    );
  }
}

class _PreviewSkeleton extends StatelessWidget {
  const _PreviewSkeleton({required this.columns});

  final int columns;

  @override
  Widget build(BuildContext context) => PrismSkeleton(
    key: const ValueKey<String>('smart-preview-loading'),
    child: GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: PrismSpace.xs,
      crossAxisSpacing: PrismSpace.xs,
      childAspectRatio: 9 / 16,
      children: <Widget>[for (int i = 0; i < columns; i++) const PrismBone(height: double.infinity, radius: 12)],
    ),
  );
}
