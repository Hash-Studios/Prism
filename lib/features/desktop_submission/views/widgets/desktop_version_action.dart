import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/desktop_submission/data/desktop_submission_repository.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

enum DesktopMenuState { add, replace, inReview }

/// Pending wins: while a desktop version waits for review, the button stays disabled whatever the wall has.
DesktopMenuState desktopMenuState({required bool hasDesktop, required bool pending}) {
  if (pending) return DesktopMenuState.inReview;
  return hasDesktop ? DesktopMenuState.replace : DesktopMenuState.add;
}

/// The creator's entry point on their own approved wall: add, replace, or see that a version is in review.
class DesktopVersionAction extends StatefulWidget {
  const DesktopVersionAction({
    required this.wallDocId,
    required this.uid,
    required this.hasDesktop,
    required this.onOpen,
    this.repository,
    super.key,
  });

  final String wallDocId;
  final String uid;
  final bool hasDesktop;

  /// [replace] is true when the wall already has a desktop version.
  final void Function(bool replace) onOpen;

  /// Defaults to the app's repository. Tests pass a fake.
  final DesktopSubmissionRepository? repository;

  @override
  State<DesktopVersionAction> createState() => _DesktopVersionActionState();
}

class _DesktopVersionActionState extends State<DesktopVersionAction> {
  late Stream<bool> _pending;

  @override
  void initState() {
    super.initState();
    _pending = _watch();
  }

  @override
  void didUpdateWidget(DesktopVersionAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wallDocId != widget.wallDocId ||
        oldWidget.uid != widget.uid ||
        oldWidget.repository != widget.repository) {
      _pending = _watch();
    }
  }

  Stream<bool> _watch() {
    // Pages built without the repository registered (some detail page tests) show the entry as not pending.
    final DesktopSubmissionRepository? repository =
        widget.repository ??
        (getIt.isRegistered<DesktopSubmissionRepository>() ? getIt<DesktopSubmissionRepository>() : null);
    return repository?.watchPendingForWall(wallDocId: widget.wallDocId, uid: widget.uid) ?? Stream<bool>.value(false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return StreamBuilder<bool>(
      stream: _pending,
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
        // A failed watch counts as "not pending": the creator can still open the upload screen.
        final bool pending = !snapshot.hasError && (snapshot.data ?? false);
        final DesktopMenuState state = desktopMenuState(hasDesktop: widget.hasDesktop, pending: pending);
        final bool inReview = state == DesktopMenuState.inReview;
        final String label = switch (state) {
          DesktopMenuState.add => l10n.desktopUploadAdd,
          DesktopMenuState.replace => l10n.desktopUploadReplace,
          DesktopMenuState.inReview => l10n.desktopUploadInReview,
        };
        return PrismButton(
          label: label,
          icon: inReview ? Icons.hourglass_top_rounded : Icons.desktop_windows_outlined,
          variant: PrismButtonVariant.tonal,
          onPressed: inReview ? null : () => widget.onOpen(state == DesktopMenuState.replace),
        );
      },
    );
  }
}
