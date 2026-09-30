import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

enum _Audience {
  all('all', 'All users', Icons.people_rounded),
  premium('premium', 'Premium users', Icons.star_rounded),
  free('free', 'Free users', Icons.person_rounded),
  custom('custom', 'Specific user (email)', Icons.alternate_email_rounded);

  const _Audience(this.value, this.label, this.icon);

  final String value;
  final String label;
  final IconData icon;
}

typedef _Option = ({String value, String label});

/// The Notifications tab: compose a push notification, pick who gets it, and queue it for the Cloud Function.
class NotificationSenderTab extends StatefulWidget {
  const NotificationSenderTab({super.key});

  @override
  State<NotificationSenderTab> createState() => _NotificationSenderTabState();
}

class _NotificationSenderTabState extends State<NotificationSenderTab> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _targetEmailController = TextEditingController();

  _Audience _audience = _Audience.all;
  String _route = 'announcement';
  bool _isSending = false;
  String? _titleError;
  String? _bodyError;
  String? _emailError;

  static const List<_Option> _routeOptions = <_Option>[
    (value: 'announcement', label: 'Announcement (inbox)'),
    (value: 'wall_of_the_day', label: 'Wall of the Day'),
    (value: 'follower', label: 'Followers screen'),
    (value: 'wall', label: 'Wall or upload'),
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

  bool _validate() {
    final String email = _targetEmailController.text.trim();
    setState(() {
      _titleError = _titleController.text.trim().isEmpty ? 'Title is required' : null;
      _bodyError = _bodyController.text.trim().isEmpty ? 'Body is required' : null;
      _emailError = !_isCustomTarget
          ? null
          : email.isEmpty
          ? 'Email is required'
          : !email.contains('@')
          ? 'Enter a valid email'
          : null;
    });
    return _titleError == null && _bodyError == null && _emailError == null;
  }

  Future<void> _send() async {
    if (_isSending || !_validate()) return;
    if (!_isCustomTarget) {
      final bool ok = await showPrismConfirm(
        context,
        title: 'Send to ${_audience.label.toLowerCase()}?',
        message: 'This notification goes out to everyone in this group. You cannot take it back.',
        confirmLabel: 'Send notification',
      );
      if (!ok || !mounted) return;
    }

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
        toasts.success('Notification queued. The Cloud Function will send it shortly.');
        _titleController.clear();
        _bodyController.clear();
        _imageUrlController.clear();
        _targetEmailController.clear();
        setState(() => _audience = _Audience.all);
      }
    } catch (e, st) {
      logger.e('Admin notification send failed', tag: 'AdminNotif', error: e, stackTrace: st);
      if (mounted) toasts.error('Could not queue the notification. Try again.');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xs, PrismSpace.page, PrismSpace.xxl),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PrismCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                PrismTextField(
                  controller: _titleController,
                  label: 'Title',
                  maxLength: 65,
                  error: _titleError,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() => _titleError = null),
                ),
                const SizedBox(height: PrismSpace.sm),
                PrismTextField(
                  controller: _bodyController,
                  label: 'Body',
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 200,
                  error: _bodyError,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() => _bodyError = null),
                ),
                const SizedBox(height: PrismSpace.sm),
                PrismTextField(
                  controller: _imageUrlController,
                  label: 'Image URL (optional)',
                  hint: 'https://',
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                ),
              ],
            ),
          ),
          const PrismSectionHeader(title: 'Audience', small: true, padding: _sectionPadding),
          Wrap(
            spacing: PrismSpace.xs,
            runSpacing: PrismSpace.xs,
            children: <Widget>[
              for (final _Audience opt in _Audience.values)
                PrismChip(
                  label: opt.label,
                  icon: opt.icon,
                  selected: opt == _audience,
                  onTap: () => setState(() {
                    _audience = opt;
                    _emailError = null;
                  }),
                ),
            ],
          ),
          if (_isCustomTarget) ...<Widget>[
            const SizedBox(height: PrismSpace.sm),
            PrismTextField(
              controller: _targetEmailController,
              label: 'User email',
              hint: 'user@example.com',
              error: _emailError,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              onChanged: (_) => setState(() => _emailError = null),
            ),
          ],
          const PrismSectionHeader(title: 'Opens', small: true, padding: _sectionPadding),
          Wrap(
            spacing: PrismSpace.xs,
            runSpacing: PrismSpace.xs,
            children: <Widget>[
              for (final _Option opt in _routeOptions)
                PrismChip(
                  label: opt.label,
                  selected: opt.value == _route,
                  onTap: () => setState(() => _route = opt.value),
                ),
            ],
          ),
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
          const SizedBox(height: PrismSpace.xl),
          PrismButton(
            label: 'Send notification',
            icon: Icons.send_rounded,
            expand: true,
            loading: _isSending,
            onPressed: _send,
          ),
        ],
      ),
    );
  }

  static const EdgeInsets _sectionPadding = EdgeInsets.only(
    top: PrismSpace.xl,
    bottom: PrismSpace.xs,
    left: PrismSpace.xxs,
  );
}

class _NotificationPreviewCard extends StatelessWidget {
  const _NotificationPreviewCard({required this.title, required this.body, required this.imageUrl});

  final String title;
  final String body;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (title.isEmpty && body.isEmpty) return const SizedBox.shrink();

    final ColorScheme cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const PrismSectionHeader(title: 'Preview', small: true, padding: _NotificationSenderTabState._sectionPadding),
        PrismCard(
          padding: const EdgeInsets.all(PrismSpace.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(PrismRadius.xs)),
                child: Icon(Icons.notifications_rounded, color: cs.onPrimary, size: 20),
              ),
              const SizedBox(width: PrismSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (title.isNotEmpty)
                      Text(
                        title,
                        style: PrismTextStyles.rowTitle(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (body.isNotEmpty)
                      Text(body, style: PrismTextStyles.body(context), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (imageUrl.isNotEmpty) ...<Widget>[
                const SizedBox(width: PrismSpace.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(PrismRadius.xs),
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
        ),
      ],
    );
  }
}
