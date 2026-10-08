import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/router/notification_route_mapper.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/admin_review/data/admin_moderation_repository.dart';
import 'package:Prism/features/admin_review/views/widgets/full_screen_image_view.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:timeago/timeago.dart' as timeago;

@RoutePage()
class AdminReviewScreen extends StatefulWidget {
  const AdminReviewScreen({super.key, this.repository});

  final AdminModerationRepository? repository;

  @override
  State<AdminReviewScreen> createState() => _AdminReviewScreenState();
}

class _AdminReviewScreenState extends State<AdminReviewScreen> with SingleTickerProviderStateMixin {
  late TabController _controller;
  late final AdminModerationRepository _repository;
  late Stream<List<FirestoreDocument>> _pendingWallsStream;
  late Stream<List<FirestoreDocument>> _openReportsStream;
  late Stream<(int, int)> _pendingCountsStream;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? getIt<AdminModerationRepository>();
    _controller = TabController(length: 3, vsync: this);
    _subscribeStreams();
  }

  void _subscribeStreams() {
    _pendingWallsStream = _repository.watchPendingWalls();
    _openReportsStream = _repository.watchOpenContentReports();
    _pendingCountsStream = Rx.combineLatest2<int, int, (int, int)>(
      _repository.watchPendingWalls().map((List<FirestoreDocument> list) => list.length),
      _repository.watchOpenContentReports().map((List<FirestoreDocument> list) => list.length),
      (int a, int b) => (a, b),
    );
  }

  void _retryStreams() {
    PrismHaptics.tap();
    setState(_subscribeStreams);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<(int, int)>(
      stream: _pendingCountsStream,
      builder: (BuildContext context, AsyncSnapshot<(int, int)> countSnapshot) {
        final counts = countSnapshot.hasError || countSnapshot.connectionState == ConnectionState.waiting
            ? null
            : countSnapshot.data;
        final String wallsCount = counts?.$1.toString() ?? '—';
        final String reportsCount = counts?.$2.toString() ?? '—';
        return Scaffold(
          appBar: AppBar(
            title: const Text('Admin Moderation'),
            actions: [
              IconButton(
                icon: const Icon(Icons.swipe),
                tooltip: 'Swipe Review Mode',
                onPressed: () {
                  context.router.push(const SwipeReviewRoute());
                },
              ),
            ],
            bottom: TabBar(
              controller: _controller,
              tabs: <Tab>[
                Tab(text: 'Walls ($wallsCount)'),
                Tab(text: 'Reports ($reportsCount)'),
                const Tab(text: 'Notifications'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _controller,
            children: <Widget>[_buildWallTab(), _buildReportsTab(), const _NotificationSenderTab()],
          ),
        );
      },
    );
  }

  Widget _buildWallTab() {
    return _buildPendingTab(
      stream: _pendingWallsStream,
      keyPrefix: 'wall',
      emptyLabel: 'No pending wallpapers',
      errorLabel: 'Could not load pending wallpapers.',
      itemBuilder: (BuildContext context, FirestoreDocument wall) {
        final String previewUrl = wall.wallpaperThumb;
        return _moderationCard(
          context,
          doc: wall,
          previewUrl: previewUrl,
          fullUrl: wall.wallpaperUrl.isNotEmpty ? wall.wallpaperUrl : previewUrl,
          approve: () async {
            await _repository.approveWall(wall);
            toasts.success('Wallpaper approved');
          },
          reject: (String reason) async {
            await _repository.rejectWall(wall, reason: reason);
            toasts.success('Wallpaper rejected');
          },
        );
      },
    );
  }

  Widget _buildPendingTab({
    required Stream<List<FirestoreDocument>> stream,
    required String keyPrefix,
    required String emptyLabel,
    required String errorLabel,
    required Widget Function(BuildContext context, FirestoreDocument doc) itemBuilder,
  }) {
    return StreamBuilder<List<FirestoreDocument>>(
      stream: stream,
      builder: (BuildContext context, AsyncSnapshot<List<FirestoreDocument>> snapshot) {
        if (snapshot.hasError) {
          return _buildStreamError(errorLabel);
        }
        if (!snapshot.hasData) {
          return const Center(child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)));
        }
        final List<FirestoreDocument> docs = snapshot.data!;
        if (docs.isEmpty) {
          return Center(child: Text(emptyLabel));
        }
        return ListView.builder(
          itemCount: docs.length,
          findChildIndexCallback: (Key key) {
            final int index = docs.indexWhere(
              (FirestoreDocument doc) => '$keyPrefix-${doc.id}' == (key as ValueKey<String>).value,
            );
            return index < 0 ? null : index;
          },
          itemBuilder: (BuildContext context, int index) => KeyedSubtree(
            key: ValueKey<String>('$keyPrefix-${docs[index].id}'),
            child: itemBuilder(context, docs[index]),
          ),
        );
      },
    );
  }

  Widget _moderationCard(
    BuildContext context, {
    required FirestoreDocument doc,
    required String previewUrl,
    required String fullUrl,
    required Future<void> Function() approve,
    required Future<void> Function(String reason) reject,
  }) {
    final DateTime? createdAt = doc.createdAt;
    return _ModerationCard(
      previewUrl: previewUrl,
      fullUrl: fullUrl,
      metadataLines: <Widget>[
        Text('ID: ${doc.id}'),
        Text('By: ${doc.by.isNotEmpty ? doc.by : '-'}'),
        Text('Email: ${doc.email.isNotEmpty ? doc.email : '-'}'),
        Text(
          createdAt != null ? 'Uploaded ${timeago.format(createdAt.toLocal())}' : 'Uploaded —',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
      onApprove: approve,
      onReject: () => _confirmReject(context, onSubmit: reject),
    );
  }

  Widget _buildReportsTab() {
    return StreamBuilder<List<FirestoreDocument>>(
      stream: _openReportsStream,
      builder: (BuildContext context, AsyncSnapshot<List<FirestoreDocument>> snapshot) {
        if (snapshot.hasError) {
          return _buildStreamError('Could not load open reports.');
        }
        if (!snapshot.hasData) {
          return const Center(child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)));
        }
        final List<FirestoreDocument> reports = snapshot.data!;
        if (reports.isEmpty) {
          return const Center(child: Text('No open reports'));
        }
        return ListView.builder(
          itemCount: reports.length,
          itemBuilder: (BuildContext context, int index) {
            final FirestoreDocument r = reports[index];
            final Map<String, dynamic> m = r.data();
            final String ct = m['contentType']?.toString() ?? '';
            final String tid = m['targetFirestoreDocId']?.toString() ?? '';
            final String reason = m['reason']?.toString() ?? '';
            final String uid = m['reporterUid']?.toString() ?? '';
            final DateTime? created = r.createdAt;
            final String timeStr = created != null ? timeago.format(created) : '';
            if (ct == 'wall' && tid.isNotEmpty) {
              return _WallContentReportCard(
                key: ValueKey<String>('report-${r.id}'),
                report: r,
                targetDocId: tid,
                contentTypeLabel: ct,
                reason: reason,
                reporterUid: uid,
                timeStr: timeStr,
                repository: _repository,
                onConfirmRemoveWithReason: ({required Future<void> Function(String reason) onSubmit}) => _confirmReject(
                  context,
                  dialogTitle: 'Remove wallpaper',
                  confirmButtonLabel: 'Remove',
                  onSubmit: onSubmit,
                ),
              );
            }
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                title: Text('$ct — $reason'),
                subtitle: Text('Target: $tid\nReporter: $uid\n$timeStr'),
                isThreeLine: true,
                trailing: TextButton(
                  onPressed: () async {
                    PrismHaptics.tap();
                    try {
                      await _repository.markContentReportReviewed(r.id);
                      toasts.success('Marked reviewed');
                    } catch (e, st) {
                      logger.e('mark report failed', tag: 'AdminReview', error: e, stackTrace: st);
                      toasts.error('Failed');
                    }
                  },
                  child: const Text('Done'),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStreamError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.cloud_off_outlined, color: Theme.of(context).colorScheme.error, size: 36),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _retryStreams,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmReject(
    BuildContext context, {
    required Future<void> Function(String reason) onSubmit,
    String dialogTitle = 'Reject Item',
    String confirmButtonLabel = 'Reject',
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _RejectReasonDialog(title: dialogTitle, confirmButtonLabel: confirmButtonLabel, onSubmit: onSubmit),
    );
  }
}

class _RejectReasonDialog extends StatefulWidget {
  const _RejectReasonDialog({required this.title, required this.confirmButtonLabel, required this.onSubmit});

  final String title;
  final String confirmButtonLabel;
  final Future<void> Function(String reason) onSubmit;

  @override
  State<_RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<_RejectReasonDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    final String reason = _controller.text.trim();
    if (reason.isEmpty) {
      setState(() => _errorMessage = 'Enter a reason before rejecting this item.');
      return;
    }
    PrismHaptics.tap();
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await widget.onSubmit(reason);
      if (mounted) Navigator.of(context).pop();
    } catch (error, stackTrace) {
      logger.e('Admin reject failed', tag: 'AdminReview', error: error, stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Could not save this decision. Your reason is still here. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving,
      child: AlertDialog(
        scrollable: true,
        title: Text(widget.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _controller,
              enabled: !_isSaving,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Explain what needs to change',
                helperText: 'The creator will see this feedback.',
              ),
              onChanged: (_) {
                if (_errorMessage != null) {
                  setState(() => _errorMessage = null);
                }
              },
            ),
            if (_errorMessage != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
        actions: <Widget>[
          TextButton(onPressed: _isSaving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: _isSaving ? null : _submit,
            child: AnimatedSwitcher(
              duration: context.motion(PrismDurations.fast),
              child: _isSaving
                  ? const SizedBox.square(
                      key: ValueKey('loading'),
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.confirmButtonLabel, key: const ValueKey('label')),
            ),
          ),
        ],
      ),
    );
  }
}

class _WallContentReportCard extends StatefulWidget {
  const _WallContentReportCard({
    super.key,
    required this.report,
    required this.targetDocId,
    required this.contentTypeLabel,
    required this.reason,
    required this.reporterUid,
    required this.timeStr,
    required this.repository,
    required this.onConfirmRemoveWithReason,
  });

  final FirestoreDocument report;
  final String targetDocId;
  final String contentTypeLabel;
  final String reason;
  final String reporterUid;
  final String timeStr;
  final AdminModerationRepository repository;
  final Future<void> Function({required Future<void> Function(String reason) onSubmit}) onConfirmRemoveWithReason;

  @override
  State<_WallContentReportCard> createState() => _WallContentReportCardState();
}

class _WallContentReportCardState extends State<_WallContentReportCard> {
  late final Future<Map<String, dynamic>?> _wallFuture;

  @override
  void initState() {
    super.initState();
    _wallFuture = firestoreClient.getById<Map<String, dynamic>>(
      FirebaseCollections.walls,
      widget.targetDocId,
      (Map<String, dynamic> data, String _) => data,
      sourceTag: 'admin_review.report_wall_preview',
    );
  }

  Future<void> _openWallpaperDetail(BuildContext context) async {
    final PageRouteInfo? route = await const NotificationRouteMapper().fromRoute(
      route: 'wall',
      wallId: widget.targetDocId,
      profileIdentifier: '',
      sourceTag: 'admin.content_report',
      fallbackToInbox: false,
    );
    if (!context.mounted) {
      return;
    }
    if (route != null) {
      await context.router.push(route);
    } else {
      toasts.error('Wallpaper not found');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                FutureBuilder<Map<String, dynamic>?>(
                  future: _wallFuture,
                  builder: (BuildContext context, AsyncSnapshot<Map<String, dynamic>?> snap) {
                    final String thumb = snap.data?['wallpaper_thumb']?.toString() ?? '';
                    final Widget preview = thumb.isEmpty
                        ? Container(
                            width: 88,
                            height: 120,
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.image_not_supported_outlined),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: thumb,
                              width: 88,
                              height: 120,
                              fit: BoxFit.cover,
                              placeholder: (BuildContext context, String url) => const SizedBox(
                                width: 88,
                                height: 120,
                                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              ),
                              errorWidget: (BuildContext context, String url, Object error) =>
                                  const SizedBox(width: 88, height: 120, child: Icon(Icons.broken_image_outlined)),
                            ),
                          );
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _openWallpaperDetail(context),
                        borderRadius: BorderRadius.circular(8),
                        child: preview,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${widget.contentTypeLabel} — ${widget.reason}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Target: ${widget.targetDocId}\nReporter: ${widget.reporterUid}\n${widget.timeStr}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      TextButton(onPressed: () => _openWallpaperDetail(context), child: const Text('Open detail')),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      PrismHaptics.tap();
                      try {
                        await widget.repository.markContentReportReviewed(widget.report.id, resolution: 'dismissed');
                        if (context.mounted) {
                          toasts.success('Marked as valid');
                        }
                      } catch (e, st) {
                        logger.e('mark report dismissed failed', tag: 'AdminReview', error: e, stackTrace: st);
                        if (context.mounted) {
                          toasts.error('Failed');
                        }
                      }
                    },
                    child: const Text('Mark as valid'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      PrismHaptics.tap();
                      widget.onConfirmRemoveWithReason(
                        onSubmit: (String reason) async {
                          final bool removed = await widget.repository.rejectWallByFirestoreDocumentId(
                            widget.targetDocId,
                            reason: reason,
                          );
                          await widget.repository.markContentReportReviewed(
                            widget.report.id,
                            resolution: 'content_removed',
                          );
                          if (context.mounted) {
                            if (removed) {
                              toasts.success('Wallpaper removed');
                            } else {
                              toasts.success('Wallpaper was already gone; report closed');
                            }
                          }
                        },
                      );
                    },
                    child: const Text('Remove wallpaper'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModerationCard extends StatefulWidget {
  const _ModerationCard({
    required this.previewUrl,
    required this.fullUrl,
    required this.metadataLines,
    required this.onApprove,
    required this.onReject,
  });

  final String previewUrl;
  final String fullUrl;
  final List<Widget> metadataLines;
  final Future<void> Function() onApprove;
  final Future<void> Function() onReject;

  @override
  State<_ModerationCard> createState() => _ModerationCardState();
}

class _ModerationCardState extends State<_ModerationCard> {
  bool _isApproving = false;
  bool _isApproved = false;
  String? _approvalError;

  Future<void> _approve() async {
    if (_isApproving || _isApproved) return;
    PrismHaptics.tap();
    setState(() {
      _isApproving = true;
      _approvalError = null;
    });
    try {
      await widget.onApprove();
      if (mounted) setState(() => _isApproved = true);
    } catch (error, stackTrace) {
      logger.e('Admin approval failed', tag: 'AdminReview', error: error, stackTrace: stackTrace);
      if (mounted) {
        setState(() => _approvalError = 'Approval failed. Check your connection, then try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isApproving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final VoidCallback? openFull = widget.fullUrl.isEmpty
        ? null
        : () => FullScreenImageView.show(context, widget.fullUrl);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _PortraitPreview(imageUrl: widget.previewUrl, onTap: openFull),
            const SizedBox(height: 8),
            ...widget.metadataLines,
            const SizedBox(height: 8),
            if (_approvalError != null) ...<Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_approvalError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                  TextButton(onPressed: _isApproving ? null : _approve, child: const Text('Retry')),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: <Widget>[
                Expanded(
                  child: TextButton.icon(
                    onPressed: openFull,
                    icon: const Icon(Icons.open_in_full),
                    label: const Text('View Full'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _isApproving || _isApproved ? null : _approve,
                    child: AnimatedSwitcher(
                      duration: context.motion(PrismDurations.fast),
                      child: _isApproving
                          ? const SizedBox.square(
                              key: ValueKey('loading'),
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isApproved ? 'Approved' : 'Approve', key: const ValueKey('label')),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isApproving || _isApproved
                        ? null
                        : () {
                            PrismHaptics.tap();
                            widget.onReject();
                          },
                    child: const Text('Reject'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PortraitPreview extends StatelessWidget {
  const _PortraitPreview({required this.imageUrl, required this.onTap});

  final String imageUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: GestureDetector(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (BuildContext context, String _) =>
                    const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                errorWidget: (BuildContext context, String _, Object _) =>
                    const Center(child: Icon(Icons.broken_image)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationSenderTab extends StatefulWidget {
  const _NotificationSenderTab();

  @override
  State<_NotificationSenderTab> createState() => _NotificationSenderTabState();
}

class _NotificationSenderTabState extends State<_NotificationSenderTab> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _targetEmailController = TextEditingController();

  _Audience _audience = _Audience.all;
  String _route = 'announcement';
  bool _isSending = false;

  static const List<_Option> _routeOptions = <_Option>[
    (value: 'announcement', label: 'Announcement (inbox)'),
    (value: 'wall_of_the_day', label: 'Wall of the Day'),
    (value: 'follower', label: 'Followers screen'),
    (value: 'wall', label: 'Wall / upload'),
  ];

  bool get _isCustomTarget => _audience == _Audience.custom;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _imageUrlController.dispose();
    _targetEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const _SectionHeader(title: 'Compose notification', icon: Icons.notifications_outlined),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              maxLength: 65,
              validator: (String? v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bodyController,
              decoration: const InputDecoration(
                labelText: 'Body *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.text_snippet_outlined),
              ),
              minLines: 2,
              maxLines: 4,
              maxLength: 200,
              validator: (String? v) => (v == null || v.trim().isEmpty) ? 'Body is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _imageUrlController,
              decoration: const InputDecoration(
                labelText: 'Image URL (optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.image_outlined),
                hintText: 'https://...',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 20),
            const _SectionHeader(title: 'Audience', icon: Icons.group_outlined),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _Audience.values.map((_Audience opt) {
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[Icon(opt.icon, size: 16), const SizedBox(width: 4), Text(opt.label)],
                  ),
                  selected: opt == _audience,
                  onSelected: (_) {
                    PrismHaptics.selection();
                    setState(() => _audience = opt);
                  },
                );
              }).toList(),
            ),
            if (_isCustomTarget) ...<Widget>[
              const SizedBox(height: 12),
              TextFormField(
                controller: _targetEmailController,
                decoration: const InputDecoration(
                  labelText: 'User email *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.alternate_email),
                  hintText: 'user@example.com',
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (String? v) {
                  if (!_isCustomTarget) return null;
                  if (v == null || v.trim().isEmpty) return 'Email is required';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
            ],
            const SizedBox(height: 20),
            const _SectionHeader(title: 'Deep-link destination', icon: Icons.link),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _route,
              decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.route)),
              items: _routeOptions.map((_Option opt) {
                return DropdownMenuItem<String>(value: opt.value, child: Text(opt.label));
              }).toList(),
              onChanged: (String? v) {
                if (v != null) {
                  PrismHaptics.selection();
                  setState(() => _route = v);
                }
              },
            ),
            const SizedBox(height: 28),
            ListenableBuilder(
              listenable: Listenable.merge(<TextEditingController>[
                _titleController,
                _bodyController,
                _imageUrlController,
              ]),
              builder: (BuildContext context, _) => _NotificationPreviewCard(
                title: _titleController.text,
                body: _bodyController.text,
                imageUrl: _imageUrlController.text,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isSending ? null : _send,
              icon: AnimatedSwitcher(
                duration: context.motion(PrismDurations.fast),
                child: _isSending
                    ? const SizedBox.square(
                        key: ValueKey('loading'),
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send, key: ValueKey('icon')),
              ),
              label: Text(_isSending ? 'Sending…' : 'Send notification'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    PrismHaptics.tap();

    final String title = _titleController.text.trim();
    final String body = _bodyController.text.trim();
    final String imageUrl = _imageUrlController.text.trim();
    final String modifier = _isCustomTarget ? _targetEmailController.text.trim() : _audience.value;

    setState(() => _isSending = true);
    try {
      await firestoreClient.addDoc(FirebaseCollections.notificationRequests, <String, dynamic>{
        'title': title,
        'body': body,
        'modifier': modifier,
        'route': _route,
        if (imageUrl.isNotEmpty) 'imageUrl': imageUrl,
        'requestedBy': app_state.prismUser.email,
        'requestedAt': DateTime.now().millisecondsSinceEpoch,
      }, sourceTag: 'admin.send_notification');
      if (mounted) {
        toasts.success('Notification queued — Cloud Function will send it shortly');
        _titleController.clear();
        _bodyController.clear();
        _imageUrlController.clear();
        _targetEmailController.clear();
        setState(() => _audience = _Audience.all);
      }
    } catch (e, st) {
      logger.e('Admin notification send failed', tag: 'AdminNotif', error: e, stackTrace: st);
      if (mounted) toasts.error('Failed to queue notification');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}

enum _Audience {
  all('all', 'All users', Icons.people),
  premium('premium', 'Premium users', Icons.star),
  free('free', 'Free users', Icons.person_outline),
  custom('custom', 'Specific user (email)', Icons.email_outlined);

  const _Audience(this.value, this.label, this.icon);

  final String value;
  final String label;
  final IconData icon;
}

typedef _Option = ({String value, String label});

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: colors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: textTheme.titleSmall?.copyWith(color: colors.primary, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _NotificationPreviewCard extends StatelessWidget {
  const _NotificationPreviewCard({required this.title, required this.body, required this.imageUrl});

  final String title;
  final String body;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (title.isEmpty && body.isEmpty) return const SizedBox.shrink();

    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.phone_iphone, size: 14, color: colors.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 4),
              Text(
                'PREVIEW',
                style: TextStyle(fontSize: 10, letterSpacing: 1.2, color: colors.onSurface.withValues(alpha: 0.5)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.notifications, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (title.isNotEmpty)
                      Text(
                        title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (body.isNotEmpty)
                      Text(
                        body,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (imageUrl.isNotEmpty) ...<Widget>[
                const SizedBox(width: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
