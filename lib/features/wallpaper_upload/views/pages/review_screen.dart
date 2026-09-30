import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/navigation/views/widgets/upload_bottom_panel.dart';
import 'package:Prism/features/wallpaper_upload/views/widgets/wall_tile.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

export 'package:Prism/features/wallpaper_upload/views/widgets/wall_tile.dart' show WallTile;

@RoutePage()
class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PrismPage(title: 'Your uploads', onBack: () => Navigator.maybePop(context), body: const _WallReview());
  }
}

class _WallReview extends StatefulWidget {
  const _WallReview();

  @override
  State<_WallReview> createState() => _WallReviewState();
}

class _WallReviewState extends State<_WallReview> {
  late Stream<List<FirestoreDocument>> _rejected = _watchRejected();
  late Stream<List<FirestoreDocument>> _pending = _watchPending();

  Stream<List<FirestoreDocument>> _watchRejected() => firestoreClient.watchQuery<FirestoreDocument>(
    FirestoreQuerySpec(
      collection: FirebaseCollections.rejectedWalls,
      sourceTag: 'review.rejectedWalls',
      filters: <FirestoreFilter>[
        FirestoreFilter(field: 'email', op: FirestoreFilterOp.isEqualTo, value: app_state.prismUser.email),
      ],
      orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'createdAt', descending: true)],
      isStream: true,
    ),
    (data, docId) => FirestoreDocument(docId, data),
  );

  Stream<List<FirestoreDocument>> _watchPending() => firestoreClient.watchQuery<FirestoreDocument>(
    FirestoreQuerySpec(
      collection: FirebaseCollections.walls,
      sourceTag: 'review.pendingWalls',
      filters: <FirestoreFilter>[
        FirestoreFilter(field: 'email', op: FirestoreFilterOp.isEqualTo, value: app_state.prismUser.email),
        const FirestoreFilter(field: 'review', op: FirestoreFilterOp.isEqualTo, value: false),
      ],
      orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'createdAt', descending: true)],
      isStream: true,
    ),
    (data, docId) => FirestoreDocument(docId, data),
  );

  void _retry() => setState(() {
    _rejected = _watchRejected();
    _pending = _watchPending();
  });

  void _openUploadSheet() {
    showPrismSheet<void>(context: context, isScrollControlled: true, builder: (_) => const UploadBottomPanel());
  }

  static bool _resolved(AsyncSnapshot<List<FirestoreDocument>> s) => s.hasData || s.hasError;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FirestoreDocument>>(
      stream: _pending,
      builder: (context, pending) => StreamBuilder<List<FirestoreDocument>>(
        stream: _rejected,
        builder: (context, rejected) {
          if (!_resolved(pending) && !_resolved(rejected)) return PrismSkeleton.cards(height: 152);
          if (pending.hasError && rejected.hasError) {
            return GlintState(
              kind: GlintStateKind.error,
              title: "Couldn't load your uploads",
              body: 'Check your connection, then try again.',
              actionLabel: 'Try again',
              onAction: _retry,
            );
          }
          final List<FirestoreDocument> pendingDocs = pending.data ?? const <FirestoreDocument>[];
          final List<FirestoreDocument> rejectedDocs = rejected.data ?? const <FirestoreDocument>[];
          if (pending.hasData && rejected.hasData && pendingDocs.isEmpty && rejectedDocs.isEmpty) {
            return GlintState(
              kind: GlintStateKind.empty,
              title: 'Nothing here yet',
              body: 'Wallpapers you upload show their review status here.',
              actionLabel: 'Upload a wallpaper',
              onAction: _openUploadSheet,
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(PrismSpace.page, 0, PrismSpace.page, PrismSpace.xxl),
            children: <Widget>[
              ..._section(
                title: 'In review',
                snapshot: pending,
                docs: pendingDocs,
                rejected: false,
                error: "Couldn't load your submissions.",
                first: true,
              ),
              ..._section(
                title: 'Rejected',
                snapshot: rejected,
                docs: rejectedDocs,
                rejected: true,
                error: "Couldn't load your rejected submissions.",
                first: pendingDocs.isEmpty && !pending.hasError,
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _section({
    required String title,
    required AsyncSnapshot<List<FirestoreDocument>> snapshot,
    required List<FirestoreDocument> docs,
    required bool rejected,
    required String error,
    required bool first,
  }) {
    if (snapshot.hasData && docs.isEmpty) return const <Widget>[];
    return <Widget>[
      PrismSectionHeader(
        title: title,
        small: true,
        padding: EdgeInsets.only(top: first ? PrismSpace.xs : PrismSpace.xl, bottom: PrismSpace.sm),
      ),
      if (snapshot.hasError)
        Row(
          children: <Widget>[
            Expanded(child: Text(error, style: PrismTextStyles.body(context))),
            PrismButton(
              label: 'Try again',
              variant: PrismButtonVariant.ghost,
              size: PrismButtonSize.compact,
              onPressed: _retry,
            ),
          ],
        ),
      if (!snapshot.hasData && !snapshot.hasError)
        const PrismSkeleton(child: PrismBone(height: 152, radius: PrismRadius.lg)),
      for (final FirestoreDocument doc in docs)
        Padding(
          padding: const EdgeInsets.only(bottom: PrismSpace.sm),
          child: WallTile(doc, rejected: rejected),
        ),
    ];
  }
}
