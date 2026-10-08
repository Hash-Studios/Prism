import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/network/connectivity_service.dart';
import 'package:flutter/material.dart';

/// A small "Offline" chip. It shows nothing while the device is online.
class OfflineChip extends StatefulWidget {
  const OfflineChip({super.key, this.connectivity});

  /// Replaces the registered [ConnectivityService], for tests.
  final ConnectivityService? connectivity;

  @override
  State<OfflineChip> createState() => _OfflineChipState();
}

class _OfflineChipState extends State<OfflineChip> {
  StreamSubscription<bool>? _subscription;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    final ConnectivityService service = widget.connectivity ?? getIt<ConnectivityService>();
    _subscription = service.onConnectionChange.listen((bool online) {
      if (mounted) setState(() => _offline = !online);
    });
    unawaited(
      service.hasConnection().then((bool online) {
        if (mounted && online == _offline) setState(() => _offline = !online);
      }),
    );
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_offline) return const SizedBox.shrink();
    final ThemeData theme = Theme.of(context);
    return Semantics(
      label: 'Offline',
      child: Chip(
        avatar: Icon(Icons.cloud_off_rounded, size: 16, color: theme.colorScheme.secondary),
        label: Text('Offline', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.secondary)),
        visualDensity: VisualDensity.compact,
        backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.12),
        side: BorderSide.none,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
