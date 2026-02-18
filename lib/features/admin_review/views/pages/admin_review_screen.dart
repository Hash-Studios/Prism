import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/features/admin_review/data/admin_review_repository.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

@RoutePage()
class AdminReviewScreen extends StatefulWidget {
  const AdminReviewScreen({super.key});

  @override
  State<AdminReviewScreen> createState() => _AdminReviewScreenState();
}

class _AdminReviewScreenState extends State<AdminReviewScreen> with SingleTickerProviderStateMixin {
  late TabController _controller;
  final AdminReviewRepository _repository = const AdminReviewRepository();

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!globals.isAdminUser()) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Moderation')),
        body: const Center(child: Text('You are not authorized to access this page.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Moderation'),
        bottom: TabBar(
          controller: _controller,
          tabs: const <Tab>[
            Tab(text: 'Wallpapers'),
            Tab(text: 'Setups'),
          ],
        ),
      ),
      body: TabBarView(controller: _controller, children: <Widget>[_buildWallTab(), _buildSetupTab()]),
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
    final Map<String, dynamic> data = wall.data();
    final String previewUrl = data['wallpaper_thumb']?.toString() ?? '';
    final String fullUrl = (data['wallpaper_url']?.toString() ?? '').isNotEmpty
        ? data['wallpaper_url'].toString()
        : previewUrl;
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
            Text('ID: ${data['id'] ?? wall.id}'),
            Text('By: ${data['by'] ?? '-'}'),
            Text('Email: ${data['email'] ?? '-'}'),
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
    final Map<String, dynamic> data = setup.data();
    final String fullUrl = data['image']?.toString() ?? '';
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
            Text('ID: ${data['id'] ?? setup.id}'),
            Text('By: ${data['by'] ?? '-'}'),
            Text('Email: ${data['email'] ?? '-'}'),
            Text('Name: ${data['name'] ?? '-'}'),
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
                errorWidget: (BuildContext context, String _, Object __) =>
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
            errorWidget: (BuildContext context, String _, Object __) =>
                const Center(child: Icon(Icons.broken_image, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}
