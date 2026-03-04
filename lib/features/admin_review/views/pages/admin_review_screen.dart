import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/admin_review/data/admin_review_repository.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:timeago/timeago.dart' as timeago;

@RoutePage()
class AdminReviewScreen extends StatefulWidget {
  const AdminReviewScreen({super.key});

  @override
  State<AdminReviewScreen> createState() => _AdminReviewScreenState();
}

class _AdminReviewScreenState extends State<AdminReviewScreen> with SingleTickerProviderStateMixin {
  late TabController _controller;
  final AdminReviewRepository _repository = const AdminReviewRepository();
  late final Stream<(int, int)> _pendingCountsStream;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 3, vsync: this);
    _pendingCountsStream = Rx.combineLatest2<int, int, (int, int)>(
      _repository.watchPendingWalls().map((List<FirestoreDocument> list) => list.length),
      _repository.watchPendingSetups().map((List<FirestoreDocument> list) => list.length),
      (int a, int b) => (a, b),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!app_state.isAdminUser()) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Moderation')),
        body: const Center(child: Text('You are not authorized to access this page.')),
      );
    }

    return StreamBuilder<(int, int)>(
      stream: _pendingCountsStream,
      initialData: (0, 0),
      builder: (BuildContext context, AsyncSnapshot<(int, int)> countSnapshot) {
        final int wallsCount = countSnapshot.data!.$1;
        final int setupsCount = countSnapshot.data!.$2;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Admin Moderation'),
            bottom: TabBar(
              controller: _controller,
              tabs: <Tab>[
                Tab(text: 'Walls ($wallsCount)'),
                Tab(text: 'Setups ($setupsCount)'),
                const Tab(text: 'Notifications'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _controller,
            children: <Widget>[_buildWallTab(), _buildSetupTab(), const _NotificationSenderTab()],
          ),
        );
      },
    );
  }

  Widget _buildWallTab() {
    return StreamBuilder<List<FirestoreDocument>>(
      stream: _repository.watchPendingWalls(),
      builder: (BuildContext context, AsyncSnapshot<List<FirestoreDocument>> snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final List<FirestoreDocument> walls = snapshot.data!;
        if (walls.isEmpty) {
          return const Center(child: Text('No pending wallpapers'));
        }
        return ListView.builder(
          itemCount: walls.length,
          itemBuilder: (BuildContext context, int index) => _WallCard(
            wall: walls[index],
            onApprove: () async {
              await _repository.approveWall(walls[index]);
              toasts.codeSend('Wallpaper approved');
            },
            onReject: () => _confirmReject(
              context,
              onSubmit: (String reason) async {
                await _repository.rejectWall(walls[index], reason: reason);
                toasts.error('Wallpaper rejected');
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildSetupTab() {
    return StreamBuilder<List<FirestoreDocument>>(
      stream: _repository.watchPendingSetups(),
      builder: (BuildContext context, AsyncSnapshot<List<FirestoreDocument>> snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final List<FirestoreDocument> setups = snapshot.data!;
        if (setups.isEmpty) {
          return const Center(child: Text('No pending setups'));
        }
        return ListView.builder(
          itemCount: setups.length,
          itemBuilder: (BuildContext context, int index) => _SetupCard(
            setup: setups[index],
            onApprove: () async {
              await _repository.approveSetup(setups[index]);
              toasts.codeSend('Setup approved');
            },
            onReject: () => _confirmReject(
              context,
              onSubmit: (String reason) async {
                await _repository.rejectSetup(setups[index], reason: reason);
                toasts.error('Setup rejected');
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmReject(BuildContext context, {required Future<void> Function(String reason) onSubmit}) async {
    final TextEditingController controller = TextEditingController(
      text: "Sorry! This item doesn't meet our expectations and failed the review.",
    );
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reject Item'),
          content: TextField(
            controller: controller,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Reason'),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final String reason = controller.text.trim();
                Navigator.of(context).pop();
                if (reason.isEmpty) {
                  toasts.error('Reason cannot be empty');
                  return;
                }
                try {
                  await onSubmit(reason);
                } catch (e, st) {
                  logger.e('Admin reject failed', tag: 'AdminReview', error: e, stackTrace: st);
                  toasts.error('Action failed');
                }
              },
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );
  }
}

class _WallCard extends StatelessWidget {
  const _WallCard({required this.wall, required this.onApprove, required this.onReject});

  final FirestoreDocument wall;
  final Future<void> Function() onApprove;
  final Future<void> Function() onReject;

  @override
  Widget build(BuildContext context) {
    final String previewUrl = wall.wallpaperThumb;
    final String fullUrl = wall.wallpaperUrl.isNotEmpty ? wall.wallpaperUrl : previewUrl;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _PortraitPreview(
              imageUrl: previewUrl,
              onTap: fullUrl.isEmpty
                  ? null
                  : () {
                      Navigator.of(
                        context,
                      ).push(MaterialPageRoute<void>(builder: (_) => _FullScreenImageView(imageUrl: fullUrl)));
                    },
            ),
            const SizedBox(height: 8),
            Text('ID: ${wall.id}'),
            Text('By: ${wall.by.isNotEmpty ? wall.by : '-'}'),
            Text('Email: ${wall.email.isNotEmpty ? wall.email : '-'}'),
            Text(
              'Added ${wall.createdAt != null ? timeago.format(_adminReviewToDateTime(wall.createdAt)) : '—'}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextButton.icon(
                    onPressed: fullUrl.isEmpty
                        ? null
                        : () {
                            Navigator.of(
                              context,
                            ).push(MaterialPageRoute<void>(builder: (_) => _FullScreenImageView(imageUrl: fullUrl)));
                          },
                    icon: const Icon(Icons.open_in_full),
                    label: const Text('View Full'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(onPressed: onApprove, child: const Text('Approve')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(onPressed: onReject, child: const Text('Reject')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({required this.setup, required this.onApprove, required this.onReject});

  final FirestoreDocument setup;
  final Future<void> Function() onApprove;
  final Future<void> Function() onReject;

  @override
  Widget build(BuildContext context) {
    final String fullUrl = setup.image;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _PortraitPreview(
              imageUrl: fullUrl,
              onTap: fullUrl.isEmpty
                  ? null
                  : () {
                      Navigator.of(
                        context,
                      ).push(MaterialPageRoute<void>(builder: (_) => _FullScreenImageView(imageUrl: fullUrl)));
                    },
            ),
            const SizedBox(height: 8),
            Text('ID: ${setup.id}'),
            Text('By: ${setup.by.isNotEmpty ? setup.by : '-'}'),
            Text('Email: ${setup.email.isNotEmpty ? setup.email : '-'}'),
            Text('Name: ${setup.name.isNotEmpty ? setup.name : '-'}'),
            Text(
              'Added ${setup.createdAt != null ? timeago.format(_adminReviewToDateTime(setup.createdAt)) : '—'}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextButton.icon(
                    onPressed: fullUrl.isEmpty
                        ? null
                        : () {
                            Navigator.of(
                              context,
                            ).push(MaterialPageRoute<void>(builder: (_) => _FullScreenImageView(imageUrl: fullUrl)));
                          },
                    icon: const Icon(Icons.open_in_full),
                    label: const Text('View Full'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(onPressed: onApprove, child: const Text('Approve')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(onPressed: onReject, child: const Text('Reject')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

DateTime _adminReviewToDateTime(dynamic value) {
  if (value == null) return DateTime.now().toUtc();
  if (value is DateTime) return value.toUtc();
  if (value is Timestamp) return value.toDate().toUtc();
  if (value is int) {
    if (value > 10000000000) return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
  }
  if (value is String) {
    try {
      return DateTime.parse(value).toUtc();
    } catch (_) {
      return DateTime.now().toUtc();
    }
  }
  return DateTime.now().toUtc();
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

class _FullScreenImageView extends StatelessWidget {
  const _FullScreenImageView({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: InteractiveViewer(
        maxScale: 5,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (BuildContext context, String _) => const Center(child: CircularProgressIndicator()),
            errorWidget: (BuildContext context, String _, Object _) =>
                const Center(child: Icon(Icons.broken_image, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification Sender
// ─────────────────────────────────────────────────────────────────────────────

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

  String _modifier = 'all';
  String _route = 'announcement';
  bool _isSending = false;

  static const List<_AudienceOption> _audienceOptions = <_AudienceOption>[
    _AudienceOption(value: 'all', label: 'All users', icon: Icons.people),
    _AudienceOption(value: 'premium', label: 'Premium users', icon: Icons.star),
    _AudienceOption(value: 'free', label: 'Free users', icon: Icons.person_outline),
    _AudienceOption(value: 'custom', label: 'Specific user (email)', icon: Icons.email_outlined),
  ];

  static const List<_RouteOption> _routeOptions = <_RouteOption>[
    _RouteOption(value: 'announcement', label: 'Announcement (inbox)'),
    _RouteOption(value: 'wall_of_the_day', label: 'Wall of the Day'),
    _RouteOption(value: 'follower', label: 'Followers screen'),
    _RouteOption(value: 'wall', label: 'Wall / upload'),
  ];

  bool get _isCustomTarget => _modifier == 'custom';

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
              children: _audienceOptions.map((_AudienceOption opt) {
                final bool selected = opt.value == _modifier || (opt.value == 'custom' && _isCustomTarget);
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[Icon(opt.icon, size: 16), const SizedBox(width: 4), Text(opt.label)],
                  ),
                  selected: selected,
                  onSelected: (_) => setState(() => _modifier = opt.value),
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
              items: _routeOptions.map((_RouteOption opt) {
                return DropdownMenuItem<String>(value: opt.value, child: Text(opt.label));
              }).toList(),
              onChanged: (String? v) {
                if (v != null) setState(() => _route = v);
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
              icon: _isSending
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send),
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

    final String title = _titleController.text.trim();
    final String body = _bodyController.text.trim();
    final String imageUrl = _imageUrlController.text.trim();
    final String modifier = _isCustomTarget ? _targetEmailController.text.trim() : _modifier;

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
        toasts.codeSend('Notification queued — Cloud Function will send it shortly');
        _titleController.clear();
        _bodyController.clear();
        _imageUrlController.clear();
        _targetEmailController.clear();
        setState(() => _modifier = 'all');
      }
    } catch (e, st) {
      logger.e('Admin notification send failed', tag: 'AdminNotif', error: e, stackTrace: st);
      if (mounted) toasts.error('Failed to queue notification');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}

class _AudienceOption {
  const _AudienceOption({required this.value, required this.label, required this.icon});

  final String value;
  final String label;
  final IconData icon;
}

class _RouteOption {
  const _RouteOption({required this.value, required this.label});

  final String value;
  final String label;
}

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

class _NotificationPreviewCard extends StatefulWidget {
  const _NotificationPreviewCard({required this.title, required this.body, required this.imageUrl});

  final String title;
  final String body;
  final String imageUrl;

  @override
  State<_NotificationPreviewCard> createState() => _NotificationPreviewCardState();
}

class _NotificationPreviewCardState extends State<_NotificationPreviewCard> {
  @override
  Widget build(BuildContext context) {
    if (widget.title.isEmpty && widget.body.isEmpty) return const SizedBox.shrink();

    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.phone_iphone, size: 14, color: colors.onSurface.withOpacity(0.5)),
              const SizedBox(width: 4),
              Text(
                'PREVIEW',
                style: TextStyle(fontSize: 10, letterSpacing: 1.2, color: colors.onSurface.withOpacity(0.5)),
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
                    if (widget.title.isNotEmpty)
                      Text(
                        widget.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (widget.body.isNotEmpty)
                      Text(
                        widget.body,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (widget.imageUrl.isNotEmpty) ...<Widget>[
                const SizedBox(width: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: widget.imageUrl,
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
