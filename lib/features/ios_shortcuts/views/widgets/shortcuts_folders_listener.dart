import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/folders/biz/bloc/folders_bloc.j.dart';
import 'package:Prism/features/folders/domain/repositories/folders_repository.dart';
import 'package:Prism/features/ios_shortcuts/data/shortcuts_folders_store.dart';
import 'package:Prism/features/session/session.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// On iOS, keeps the folders snapshot that the Shortcuts intent reads in step with the signed-in user's folders.
/// The app loads folders on every sign-in and app open, so that load writes the snapshot too. Coming back to the app
/// syncs again, which reads only folders that changed or failed last time.
class ShortcutsFoldersListener extends StatefulWidget {
  const ShortcutsFoldersListener({required this.child, this.repository, super.key});

  /// Folder edits come in bursts, such as saving a wall to three folders. One sync covers the burst.
  static const Duration editDebounce = Duration(seconds: 2);

  final Widget child;

  /// Reads each changed folder's items. Defaults to the app's [FoldersRepository].
  final FoldersRepository? repository;

  @override
  State<ShortcutsFoldersListener> createState() => _ShortcutsFoldersListenerState();
}

class _ShortcutsFoldersListenerState extends State<ShortcutsFoldersListener> with WidgetsBindingObserver {
  late bool _wasLoggedIn;
  late String _lastUserId;
  late LoadStatus _foldersStatus;
  Timer? _debounce;
  StreamSubscription<void>? _rotationFolderChanges;

  bool get _enabled => defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    final SessionState sessionState = context.read<SessionBloc>().state;
    _wasLoggedIn = sessionState.session.loggedIn;
    _lastUserId = sessionState.session.userId;
    _foldersStatus = context.read<FoldersBloc>().state.status;
    WidgetsBinding.instance.addObserver(this);
    if (_enabled) {
      _rotationFolderChanges = ShortcutsFoldersStore.rotationFolderChanges.listen((_) => _sync());
    }
    if (_enabled && _isResolvedGuest(sessionState)) _run(ShortcutsFoldersStore.clear);
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _rotationFolderChanges?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _sync();
  }

  void _onFoldersChanged(FoldersState current) {
    _debounce?.cancel();
    final bool edit = _foldersStatus == LoadStatus.success && current.status == LoadStatus.success;
    _foldersStatus = current.status;
    if (!edit) return _sync();
    _debounce = Timer(ShortcutsFoldersListener.editDebounce, _sync);
  }

  void _sync({SessionState? stateOverride}) {
    _debounce?.cancel();
    if (!_enabled || !mounted) return;
    final session = (stateOverride ?? context.read<SessionBloc>().state).session;
    final FoldersState folders = context.read<FoldersBloc>().state;
    final String userId = session.userId;
    if (!session.loggedIn ||
        userId.isEmpty ||
        !app_state.prismUser.loggedIn ||
        app_state.prismUser.id.trim() != userId.trim() ||
        folders.userId != userId ||
        folders.status != LoadStatus.success) {
      return;
    }
    final FoldersRepository repository = widget.repository ?? getIt<FoldersRepository>();
    _run(() => ShortcutsFoldersStore.syncFrom(repository, ownerId: userId, folders: folders.folders));
  }

  bool _isResolvedGuest(SessionState state) => state.status == LoadStatus.success && !state.session.loggedIn;

  void _run(Future<void> Function() write) {
    write().catchError((Object error, StackTrace stackTrace) {
      logger.w('Could not update Shortcuts folders', error: error, stackTrace: stackTrace);
    });
  }

  void _onSessionChanged(SessionState current) {
    final bool loggedOut = _wasLoggedIn && !current.session.loggedIn;
    final bool switchedAccount = _wasLoggedIn && current.session.loggedIn && _lastUserId != current.session.userId;
    _wasLoggedIn = current.session.loggedIn;
    _lastUserId = current.session.userId;
    if (!_enabled) return;
    if (loggedOut || switchedAccount || _isResolvedGuest(current)) {
      _run(ShortcutsFoldersStore.clear);
      if (!loggedOut && current.session.loggedIn) _sync(stateOverride: current);
    } else {
      _sync(stateOverride: current);
    }
  }

  @override
  Widget build(BuildContext context) => MultiBlocListener(
    listeners: [
      BlocListener<SessionBloc, SessionState>(
        listenWhen: (previous, current) =>
            previous.status != current.status ||
            previous.session.userId != current.session.userId ||
            previous.session.loggedIn != current.session.loggedIn,
        listener: (_, state) => _onSessionChanged(state),
      ),
      BlocListener<FoldersBloc, FoldersState>(
        listenWhen: (previous, current) =>
            previous.status != current.status ||
            previous.userId != current.userId ||
            !identical(previous.folders, current.folders),
        listener: (_, state) => _onFoldersChanged(state),
      ),
    ],
    child: widget.child,
  );
}
