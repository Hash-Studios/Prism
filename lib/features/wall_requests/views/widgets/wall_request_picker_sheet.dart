import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/wall_requests/domain/entities/wall_request.dart';
import 'package:Prism/features/wall_requests/domain/repositories/wall_requests_repository.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/material.dart';

/// Lets a creator pick the open request an upload fills. Returns null when the user closed the sheet.
Future<WallRequest?> showWallRequestPicker(BuildContext context) {
  return showPrismSheet<WallRequest>(
    context,
    dismissKeyboardOnDrag: true,
    detents: const <PrismSheetDetent>[PrismSheetDetent.medium, PrismSheetDetent.large],
    builder: (_) => WallRequestPickerBody(repository: getIt<WallRequestsRepository>()),
  );
}

/// The picker's content. It lists the Top and New requests once each, and pops with the one the user taps.
class WallRequestPickerBody extends StatefulWidget {
  const WallRequestPickerBody({super.key, required this.repository});

  final WallRequestsRepository repository;

  @override
  State<WallRequestPickerBody> createState() => _WallRequestPickerBodyState();
}

class _WallRequestPickerBodyState extends State<WallRequestPickerBody> {
  final TextEditingController _search = TextEditingController();
  List<WallRequest> _requests = const <WallRequest>[];
  bool _loading = true;
  bool _failed = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final List<List<WallRequest>> lists = await Future.wait(<Future<List<WallRequest>>>[
        widget.repository.list(WallRequestTab.top),
        widget.repository.list(WallRequestTab.newest),
      ]);
      final Set<String> seen = <String>{};
      final List<WallRequest> merged = <WallRequest>[
        for (final WallRequest request in lists.expand((List<WallRequest> list) => list))
          if (seen.add(request.id)) request,
      ];
      if (!mounted) return;
      setState(() {
        _requests = merged;
        _loading = false;
        _failed = false;
      });
    } catch (error, stackTrace) {
      logger.w('[WallRequestPicker] load failed', error: error, stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return PrismSheetBody(
      title: l10n.requestPickerTitle,
      childScrolls: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: PrismSpace.page),
            child: PrismTextField(
              controller: _search,
              hint: l10n.requestPickerSearch,
              prefixIcon: Icons.search_rounded,
              textInputAction: TextInputAction.search,
              onChanged: (String value) => setState(() => _query = value.trim().toLowerCase()),
            ),
          ),
          const SizedBox(height: PrismSpace.sm),
          Expanded(child: _results(context)),
        ],
      ),
    );
  }

  Widget _results(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    if (_loading) return PrismSkeleton.cards(count: 4, height: 64);
    if (_failed) {
      return GlintState(
        kind: GlintStateKind.error,
        title: l10n.wallRequestsLoadFailed,
        actionLabel: l10n.wallRequestsRetry,
        onAction: () {
          setState(() => _loading = true);
          unawaited(_load());
        },
      );
    }
    final List<WallRequest> shown = _requests
        .where((WallRequest request) => request.text.toLowerCase().contains(_query))
        .toList(growable: false);
    if (shown.isEmpty) return GlintState(kind: GlintStateKind.empty, title: l10n.requestPickerEmpty);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(PrismSpace.page, 0, PrismSpace.page, PrismSpace.md),
      itemCount: shown.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (BuildContext context, int index) {
        final WallRequest request = shown[index];
        return PrismRow(
          title: request.text,
          subtitle: l10n.wallRequestVotes(request.voteCount),
          onTap: () => Navigator.of(context).pop(request),
        );
      },
    );
  }
}
