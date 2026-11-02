import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/features/auto_rotate/domain/entities/auto_rotate_config.dart';
import 'package:Prism/features/auto_rotate/domain/repositories/auto_rotate_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'auto_rotate_event.j.dart';
part 'auto_rotate_state.j.dart';
part 'auto_rotate_bloc.j.freezed.dart';

@injectable
class AutoRotateBloc extends Bloc<AutoRotateEvent, AutoRotateState> {
  AutoRotateBloc(this._repository) : super(AutoRotateState.initial()) {
    on<AutoRotateEvent>(
      (event, emit) => event.map<Future<void>>(
        started: (event) => _onStarted(event, emit),
        entitlementChanged: (event) => _onEntitlementChanged(event, emit),
        favouritesChanged: (event) => _onFavouritesChanged(event, emit),
        favouritesSettled: (event) => _onFavouritesSettled(emit),
        toggled: (event) => _onToggled(event, emit),
        intervalChanged: (event) => _onConfigChanged(state.config.copyWith(intervalMinutes: event.minutes), emit),
        targetChanged: (event) => _onConfigChanged(state.config.copyWith(target: event.target), emit),
        shuffleChanged: (event) => _onConfigChanged(state.config.copyWith(shuffle: event.shuffle), emit),
        sourceChanged: (event) => _onSourceChanged(event, emit),
        categoryChanged: (event) => _onCategoryChanged(event, emit),
        folderChosen: (event) => _onFolderChosen(event, emit),
        folderChanged: (event) => _onFolderChanged(event, emit),
        folderSettled: (event) => _onFolderSettled(emit),
        folderStopAcknowledged: (event) async => emit(state.copyWith(folderStop: null)),
        chargingOnlyChanged: (event) => _onConfigChanged(state.config.copyWith(chargingOnly: event.chargingOnly), emit),
        rotateNowPressed: (event) => _onRotateNow(event, emit),
        statusRefreshed: (event) => _onStatusRefreshed(emit),
        batteryTipDismissed: (event) async => emit(state.copyWith(showBatteryTip: false)),
        proLapseAcknowledged: (event) async => emit(state.copyWith(proLapsed: false)),
      ),
      transformer: (events, mapper) => events.asyncExpand(mapper),
    );
  }

  /// The native rotation worker caps its playlist at 100 sources.
  static const int _maxSources = 100;
  static const int _maxStatusPolls = 40;
  static const int minWallpapers = 2;

  /// How often opening the app checks the rotating folder again.
  static const Duration _folderRecheck = Duration(minutes: 15);

  @visibleForTesting
  Duration favouritesDebounce = const Duration(seconds: 2);
  @visibleForTesting
  Duration statusPollInterval = const Duration(seconds: 3);
  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  final AutoRotateRepository _repository;
  List<String> _favouriteUrls = const <String>[];
  List<String> _downloadUrls = const <String>[];
  List<String> _remoteUrls = const <String>[];
  bool _remoteFailed = false;
  bool _folderMissing = false;
  DateTime? _folderCheckedAt;
  String? _folderCheckedId;
  bool _favouritesCapped = false;
  bool _downloadsCapped = false;
  List<String>? _appliedUrls;
  AutoRotateConfig? _failedSourceConfig;
  bool _entitlementKnown = false;
  bool _favouritesKnown = false;
  String? _userId;
  Timer? _favouritesTimer;
  Timer? _folderTimer;
  Timer? _pollTimer;
  Timer? _passTimer;
  int _pollsLeft = _maxStatusPolls;
  String? _requestedUserId;
  int _sessionGeneration = 0;

  Set<WallpaperTarget> _supportedTargets = const <WallpaperTarget>{
    WallpaperTarget.home,
    WallpaperTarget.lock,
    WallpaperTarget.both,
  };

  bool _isRemote(AutoRotateSource source) =>
      source == AutoRotateSource.category ||
      source == AutoRotateSource.wallOfTheDay ||
      source == AutoRotateSource.history ||
      source == AutoRotateSource.folder;

  List<String> _activeUrls(AutoRotateConfig config) => switch (config.source) {
    AutoRotateSource.favourites => _favouriteUrls,
    AutoRotateSource.downloads => _downloadUrls,
    AutoRotateSource.category ||
    AutoRotateSource.wallOfTheDay ||
    AutoRotateSource.history ||
    AutoRotateSource.folder => _remoteUrls,
  };

  /// True when the list for the chosen source could not be loaded. A rotation that already runs keeps its own list.
  bool _remoteUnavailable(AutoRotateConfig config) => _isRemote(config.source) && _remoteFailed;

  bool _isCapped(AutoRotateSource source) =>
      source == AutoRotateSource.downloads ? _downloadsCapped : _favouritesCapped;

  void _setFavourites(List<String> urls) {
    final Set<String> seen = <String>{};
    final List<String> valid = urls.where(_isValidHttpsUrl).where(seen.add).toList(growable: false);
    _favouritesCapped = valid.length > _maxSources;
    _favouriteUrls = valid.take(_maxSources).toList(growable: false);
  }

  Future<void> _refreshDownloads() async {
    final Set<String> seen = <String>{};
    final List<String> paths = (await _repository.listDownloads())
        .where((path) => path.isNotEmpty)
        .where(seen.add)
        .toList(growable: false);
    _downloadsCapped = paths.length > _maxSources;
    _downloadUrls = paths.take(_maxSources).toList(growable: false);
  }

  /// Loads the list of a category, Wall of the Day or history source. Keeps the old list and returns false on failure.
  Future<bool> _refreshRemote(AutoRotateConfig config) async {
    final int sessionGeneration = _sessionGeneration;
    List<String>? urls;
    try {
      urls = config.source == AutoRotateSource.folder
          ? await _loadFolder(config)
          : await _repository.loadRemoteUrls(config.source, category: config.categoryName);
    } catch (_) {
      urls = null;
    }
    if (sessionGeneration != _sessionGeneration) return false;
    if (urls == null) return false;
    final Set<String> seen = <String>{};
    _remoteUrls = urls.where(_isRepositorySource).where(seen.add).take(_maxSources).toList(growable: false);
    return true;
  }

  Future<List<String>?> _loadFolder(AutoRotateConfig config) async {
    final String? folderId = config.folderId;
    final String? userId = _userId;
    if (folderId == null || userId == null || userId.isEmpty) return null;
    final int sessionGeneration = _sessionGeneration;
    _folderCheckedAt = clock();
    _folderCheckedId = folderId;
    final loaded = await _repository.loadFolderUrls(folderId, userId: userId);
    if (sessionGeneration != _sessionGeneration || userId != _requestedUserId) return null;
    if (loaded == null) return null;
    _folderMissing = !loaded.found;
    return loaded.urls;
  }

  bool _folderDue(AutoRotateConfig config) =>
      config.source == AutoRotateSource.folder &&
      (_folderCheckedAt == null ||
          _folderCheckedId != config.folderId ||
          clock().difference(_folderCheckedAt!) >= _folderRecheck);

  /// The reason to show when a folder rotation stops because the folder has too few walls.
  AutoRotateStopReason? get _folderTooFew =>
      state.config.source == AutoRotateSource.folder &&
          state.isPro &&
          !state.config.passExpired(clock()) &&
          !_remoteFailed &&
          _remoteUrls.length < minWallpapers
      ? AutoRotateStopReason.folderEmpty
      : null;

  /// A folder that is gone stops its rotation and falls back to favourites. The other settings stay. True when the
  /// folder was gone.
  Future<bool> _dropMissingFolder(Emitter<AutoRotateState> emit) async {
    if (state.config.source != AutoRotateSource.folder || !_folderMissing) return false;
    _folderMissing = false;
    if (state.config.enabled || state.status.isRunning) {
      await _disable(emit, folderStop: AutoRotateStopReason.folderDeleted);
    }
    final AutoRotateConfig next = state.config.copyWith(
      enabled: false,
      source: AutoRotateSource.favourites,
      folderId: () => null,
      folderName: '',
    );
    _remoteUrls = const <String>[];
    await _repository.saveConfig(next, ownerId: _userId);
    emit(_snapshot(next));
    return true;
  }

  Future<void> _refreshSource(AutoRotateConfig config) async {
    if (config.source == AutoRotateSource.downloads) await _refreshDownloads();
    if (_isRemote(config.source)) {
      final int sessionGeneration = _sessionGeneration;
      final bool loaded = await _refreshRemote(config);
      if (sessionGeneration == _sessionGeneration) _remoteFailed = !loaded;
    }
  }

  Future<void> _loadSupportedTargets() async {
    try {
      _supportedTargets = await _repository.supportedTargets();
    } catch (_) {
      // Keep the default: every target.
    }
  }

  Future<void> _loadApplied() async {
    _appliedUrls = await _repository.loadAppliedSources();
  }

  bool _isValidHttpsUrl(String value) {
    if (value.trim() != value) return false;
    final Uri? uri = Uri.tryParse(value);
    return uri != null &&
        uri.isAbsolute &&
        uri.scheme.toLowerCase() == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty;
  }

  bool _isRepositorySource(String value) {
    if (_isValidHttpsUrl(value)) return true;
    if (value.trim() != value) return false;
    final uri = Uri.tryParse(value);
    return uri != null &&
        ((uri.scheme.isEmpty && value.startsWith('/')) ||
            (uri.scheme == 'file' && uri.host.isEmpty && uri.path.startsWith('/')));
  }

  bool _sameUrls(List<String> previous, List<String> next) => const ListEquality<String>().equals(previous, next);

  bool get _canRotate =>
      state.isPro && !state.config.passExpired(clock()) && _activeUrls(state.config).length >= minWallpapers;

  @override
  void add(AutoRotateEvent event) {
    event.maybeMap(
      entitlementChanged: (event) {
        if (_requestedUserId != event.userId) {
          _requestedUserId = event.userId;
          _sessionGeneration++;
          // A pending folder read may have stamped the prior account's check time before it
          // became stale. Invalidate that timestamp immediately, including A -> B -> A.
          _folderCheckedAt = null;
          _folderCheckedId = null;
        }
      },
      orElse: () {},
    );
    super.add(event);
  }

  /// The entitlement and pass end to act on. A pass the app already stored still counts while the live passes are
  /// unknown, for example before they load at launch, but never for another account.
  (bool, DateTime?) _entitlement(
    bool isPro,
    DateTime? passUntil,
    AutoRotateConfig stored, {
    required bool trustStored,
  }) {
    final DateTime? until = isPro ? passUntil : (trustStored ? stored.passUntil : null);
    final bool entitled = isPro ? until == null || until.isAfter(clock()) : until?.isAfter(clock()) ?? false;
    return (entitled, entitled ? until : null);
  }

  /// Stores the pass end with the config and turns the rotation off the moment the pass ends.
  Future<AutoRotateConfig> _applyPass(AutoRotateConfig config, DateTime? passUntil, {String? ownerId}) async {
    _passTimer?.cancel();
    _passTimer = null;
    if (passUntil != null) {
      final String passOwnerId = ownerId ?? _userId ?? '';
      _passTimer = Timer(passUntil.difference(clock()), () {
        _passTimer = null;
        if (!isClosed && _userId == passOwnerId && _requestedUserId == passOwnerId) {
          add(AutoRotateEvent.entitlementChanged(isPro: false, userId: passOwnerId));
        }
      });
    }
    if (config.passUntil == passUntil) return config;
    final AutoRotateConfig next = config.copyWith(passUntil: () => passUntil);
    await _repository.saveConfig(next, ownerId: ownerId);
    return next;
  }

  Future<bool> _urlsMatchApplied(AutoRotateConfig config) async =>
      _sameUrls(_appliedUrls ?? const <String>[], await _repository.resolveSources(_activeUrls(config)));

  bool _rotationChanged(AutoRotateConfig previous, AutoRotateConfig next) =>
      previous.intervalMinutes != next.intervalMinutes ||
      previous.target != next.target ||
      previous.shuffle != next.shuffle ||
      previous.source != next.source ||
      previous.categoryName != next.categoryName ||
      previous.folderId != next.folderId ||
      previous.chargingOnly != next.chargingOnly;

  AutoRotateState _snapshot(AutoRotateConfig config, {AutoRotateStatus? status, bool? isPro, bool? loaded}) =>
      state.copyWith(
        loaded: loaded ?? state.loaded,
        isPro: isPro ?? state.isPro,
        config: config,
        status: status ?? state.status,
        favouriteCount: _favouriteUrls.length,
        downloadCount: _downloadUrls.length,
        remoteCount: _remoteUrls.length,
        loadingSource: false,
        sourceLoadFailed: _failedSourceConfig != null || _remoteUnavailable(config),
        supportedTargets: _supportedTargets,
        sourcesCapped: _isCapped(config.source),
      );

  Future<AutoRotateStatus> _status() async {
    try {
      return await _repository.status();
    } on PlatformException catch (error) {
      return AutoRotateStatus(lastError: error.message ?? error.code);
    }
  }

  @override
  void onChange(Change<AutoRotateState> change) {
    super.onChange(change);
    if (change.currentState.status != change.nextState.status) _schedulePoll(change.nextState.status);
  }

  void _schedulePoll(AutoRotateStatus status) {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (isClosed || !status.isRunning || status.totalCount <= 0 || status.cachedCount >= status.totalCount) return;
    if (_pollsLeft <= 0) return;
    _pollsLeft--;
    _pollTimer = Timer(statusPollInterval, () {
      _pollTimer = null;
      if (!isClosed) add(const AutoRotateEvent.statusRefreshed());
    });
  }

  @override
  Future<void> close() {
    _favouritesTimer?.cancel();
    _folderTimer?.cancel();
    _pollTimer?.cancel();
    _passTimer?.cancel();
    return super.close();
  }

  Future<void> _onStarted(_Started event, Emitter<AutoRotateState> emit) async {
    if (_userId != null && _userId != _requestedUserId) return;
    final int sessionGeneration = _sessionGeneration;
    final String? ownerId = _userId ?? _requestedUserId;
    final AutoRotateConfig stored = await _repository.loadConfig(ownerId: ownerId);
    if (sessionGeneration != _sessionGeneration) return;
    final (bool entitled, DateTime? passUntil) = _entitlementKnown
        ? _entitlement(state.isPro, stored.passUntil, stored, trustStored: false)
        : _entitlement(event.isPro, event.passUntil, stored, trustStored: ownerId != null && ownerId.isNotEmpty);
    final bool isPro = entitled;
    if (_entitlementKnown && !isPro) {
      _favouriteUrls = const <String>[];
      _favouritesCapped = false;
    } else {
      _setFavourites(event.favouriteUrls);
    }
    _favouritesKnown = true;
    final AutoRotateConfig config = await _applyPass(stored, passUntil, ownerId: ownerId);
    if (sessionGeneration != _sessionGeneration) return;
    await _loadSupportedTargets();
    // Opening the screen always reloads the list. Only the automatic checks on resume wait for the recheck window.
    if (isPro || config.source == AutoRotateSource.downloads) await _refreshSource(config);
    if (sessionGeneration != _sessionGeneration) return;
    await _loadApplied();
    final AutoRotateStatus status = await _status();
    if (sessionGeneration != _sessionGeneration) return;
    _pollsLeft = _maxStatusPolls;
    emit(_snapshot(config, status: status, isPro: isPro, loaded: true));

    if (!isPro) {
      if (config.enabled || status.isRunning || status.lastError != null) await _disable(emit);
      return;
    }
    if (await _dropMissingFolder(emit)) return;
    if (!config.enabled) {
      if (status.isRunning || status.lastError != null) await _disable(emit);
      return;
    }
    if (_remoteUnavailable(config) && status.isRunning && status.lastError == null) return;
    if (!_canRotate) {
      await _disable(emit, folderStop: _folderTooFew);
    } else if (!status.isRunning && status.lastError != null) {
      await _disable(emit);
    } else if (!status.isRunning || !await _urlsMatchApplied(config)) {
      await _start(config, emit);
    }
  }

  Future<void> _onEntitlementChanged(_EntitlementChanged event, Emitter<AutoRotateState> emit) async {
    final int sessionGeneration = _sessionGeneration;
    if (event.userId != _requestedUserId) return;
    final bool accountChanged = _entitlementKnown && _userId != event.userId;
    _entitlementKnown = true;
    _userId = event.userId;
    if (accountChanged) {
      _folderCheckedAt = null;
      _folderCheckedId = null;
      _failedSourceConfig = null;
      _remoteUrls = const <String>[];
      _remoteFailed = false;
      _folderMissing = false;
    }
    if (accountChanged || !event.isPro) {
      _favouriteUrls = const <String>[];
      _favouritesCapped = false;
      _favouritesKnown = false;
    }
    final AutoRotateConfig stored = await _repository.loadConfig(ownerId: event.userId);
    if (sessionGeneration != _sessionGeneration) return;
    final (bool isPro, DateTime? passUntil) = _entitlement(
      event.isPro,
      event.passUntil,
      stored,
      trustStored: !accountChanged && event.userId.isNotEmpty,
    );
    final AutoRotateConfig config = await _applyPass(stored, passUntil, ownerId: event.userId);
    if (sessionGeneration != _sessionGeneration) return;
    if (config.source == AutoRotateSource.downloads) await _refreshDownloads();
    await _loadApplied();
    final AutoRotateStatus status = await _status();
    if (isPro &&
        config.enabled &&
        !accountChanged &&
        ((!status.isRunning && _isRemote(config.source) && config.source != AutoRotateSource.folder) ||
            _folderDue(config))) {
      final bool loaded = await _refreshRemote(config);
      if (sessionGeneration != _sessionGeneration) return;
      _remoteFailed = !loaded;
    }
    if (sessionGeneration != _sessionGeneration) return;
    emit(_snapshot(config, status: status, isPro: isPro, loaded: true));
    final bool somethingToStop = config.enabled || status.isRunning || status.lastError != null;
    if (!isPro || accountChanged) {
      if (somethingToStop) await _disable(emit);
      if (!isPro && !accountChanged && event.userId.isNotEmpty && (config.enabled || status.isRunning)) {
        emit(state.copyWith(proLapsed: true));
      }
    } else if (await _dropMissingFolder(emit)) {
      return;
    } else if (!config.enabled && somethingToStop) {
      await _disable(emit);
    } else if (!status.isRunning && status.lastError != null) {
      await _disable(emit);
    } else if (config.source == AutoRotateSource.folder) {
      if (!config.enabled || _remoteUnavailable(config)) return;
      if (!_canRotate) {
        await _disable(emit, folderStop: _folderTooFew);
      } else if (!status.isRunning || !await _urlsMatchApplied(config)) {
        await _start(config, emit);
      }
    } else if (_favouritesKnown && config.enabled && _canRotate && status.lastError == null && !status.isRunning) {
      await _start(config, emit);
    }
  }

  Future<void> _onFavouritesChanged(_FavouritesChanged event, Emitter<AutoRotateState> emit) async {
    if (_userId != _requestedUserId) return;
    final List<String> previousUrls = _favouriteUrls;
    final bool wasKnown = _favouritesKnown;
    _setFavourites(event.favouriteUrls);
    _favouritesKnown = true;
    emit(_snapshot(state.config));
    if (!state.loaded) return;
    if (!wasKnown) {
      await _onFavouritesSettled(emit);
      return;
    }
    if (_sameUrls(previousUrls, _favouriteUrls) && state.status.isRunning && _canRotate) return;
    _favouritesTimer?.cancel();
    _favouritesTimer = Timer(favouritesDebounce, () {
      if (!isClosed) add(const AutoRotateEvent.favouritesSettled());
    });
  }

  Future<void> _onFavouritesSettled(Emitter<AutoRotateState> emit) async {
    if (_userId != _requestedUserId) return;
    if (!state.loaded) return;
    final int sessionGeneration = _sessionGeneration;
    if (_remoteUnavailable(state.config) && state.status.isRunning && state.status.lastError == null) return;
    if (state.status.isRunning && _canRotate && await _urlsMatchApplied(state.config)) return;
    if (sessionGeneration != _sessionGeneration) return;
    if (!_canRotate && (state.config.enabled || state.status.isRunning || state.status.lastError != null)) {
      await _disable(emit, folderStop: _folderTooFew);
      return;
    }
    if (!state.status.isRunning && state.status.lastError != null) {
      await _disable(emit);
      return;
    }
    if (state.config.enabled && _canRotate && state.isPro) {
      await _start(state.config, emit);
    } else if (state.config.enabled || state.status.isRunning || state.status.lastError != null) {
      await _disable(emit);
    }
  }

  Future<void> _onToggled(_Toggled event, Emitter<AutoRotateState> emit) async {
    if (event.enabled && _userId != _requestedUserId) return;
    if (event.enabled) {
      final AutoRotateConfig? failedSource = _failedSourceConfig;
      if (failedSource != null) {
        await _switchSource(failedSource.copyWith(enabled: true), emit);
        return;
      }
      if (state.isPro && _isRemote(state.config.source) && (_remoteFailed || _remoteUrls.isEmpty)) {
        _remoteFailed = !await _refreshRemote(state.config);
        emit(_snapshot(state.config));
      }
      if (!_canRotate || (state.config.enabled && state.status.isRunning)) return;
      await _start(state.config.copyWith(enabled: true), emit, userInitiated: true);
    } else {
      _failedSourceConfig = null;
      if (!state.config.enabled && !state.status.isRunning && state.status.lastError == null) return;
      await _disable(emit);
    }
  }

  Future<void> _onSourceChanged(_SourceChanged event, Emitter<AutoRotateState> emit) async {
    if (event.source == state.config.source) {
      _failedSourceConfig = null;
      return;
    }
    await _switchSource(state.config.copyWith(source: event.source), emit);
  }

  Future<void> _onCategoryChanged(_CategoryChanged event, Emitter<AutoRotateState> emit) async {
    final AutoRotateConfig next = state.config.copyWith(
      source: AutoRotateSource.category,
      categoryName: event.category,
    );
    if (next == state.config) {
      _failedSourceConfig = null;
      return;
    }
    await _switchSource(next, emit);
  }

  Future<void> _onFolderChosen(_FolderChosen event, Emitter<AutoRotateState> emit) async {
    final AutoRotateConfig next = state.config.copyWith(
      enabled: state.config.enabled || event.enable,
      source: AutoRotateSource.folder,
      folderId: () => event.folderId,
      folderName: event.name,
    );
    if (next == state.config) {
      _failedSourceConfig = null;
      return;
    }
    await _switchSource(next, emit);
    if (state.config.source == AutoRotateSource.folder && state.config.folderId == event.folderId) {
      analytics.track(AutoRotateFolderSetEvent(itemCountBucket: folderCountBucket(_remoteUrls.length)));
    }
  }

  Future<void> _onFolderChanged(_FolderChanged event, Emitter<AutoRotateState> emit) async {
    if (_userId != _requestedUserId) return;
    final int sessionGeneration = _sessionGeneration;
    final AutoRotateConfig config = state.config;
    if (!state.loaded || config.source != AutoRotateSource.folder || config.folderId != event.folderId) return;
    final String? name = event.name;
    if (name != null && name.isNotEmpty && name != config.folderName) {
      final AutoRotateConfig renamed = config.copyWith(folderName: name);
      await _repository.saveConfig(renamed, ownerId: _userId);
      if (sessionGeneration != _sessionGeneration) return;
      emit(_snapshot(renamed));
    }
    _folderTimer?.cancel();
    _folderTimer = Timer(favouritesDebounce, () {
      _folderTimer = null;
      if (!isClosed && sessionGeneration == _sessionGeneration) add(const AutoRotateEvent.folderSettled());
    });
  }

  /// Loads the folder again and applies the new list only when it differs from the one the platform runs.
  Future<void> _onFolderSettled(Emitter<AutoRotateState> emit) async {
    if (_userId != _requestedUserId) return;
    final int sessionGeneration = _sessionGeneration;
    final AutoRotateConfig config = state.config;
    if (!state.loaded || !state.isPro || config.source != AutoRotateSource.folder) return;
    if (!await _refreshRemote(config)) return;
    if (sessionGeneration != _sessionGeneration) return;
    _remoteFailed = false;
    emit(_snapshot(config));
    if (await _dropMissingFolder(emit) || !config.enabled) return;
    if (!_canRotate) {
      await _disable(emit, folderStop: _folderTooFew);
    } else if (!state.status.isRunning || !await _urlsMatchApplied(config)) {
      await _start(config, emit);
    }
  }

  /// Loads the list for [next] first. When it cannot be loaded the old source and its rotation stay as they are.
  Future<void> _switchSource(AutoRotateConfig next, Emitter<AutoRotateState> emit) async {
    if (_userId != _requestedUserId) return;
    final int sessionGeneration = _sessionGeneration;
    final List<String> previousRemoteUrls = _remoteUrls;
    final bool previousRemoteFailed = _remoteFailed;
    final bool previousFolderMissing = _folderMissing;
    final DateTime? previousFolderCheckedAt = _folderCheckedAt;
    final String? previousFolderCheckedId = _folderCheckedId;
    if (next.source == AutoRotateSource.downloads) await _refreshDownloads();
    if (_isRemote(next.source)) {
      emit(state.copyWith(loadingSource: true, sourceLoadFailed: false));
      final bool loaded = await _refreshRemote(next) && !(next.source == AutoRotateSource.folder && _folderMissing);
      if (sessionGeneration != _sessionGeneration) return;
      if (!loaded) {
        _failedSourceConfig = next;
        _remoteUrls = previousRemoteUrls;
        _remoteFailed = previousRemoteFailed;
        _folderMissing = previousFolderMissing;
        _folderCheckedAt = previousFolderCheckedAt;
        _folderCheckedId = previousFolderCheckedId;
        emit(state.copyWith(loadingSource: false, sourceLoadFailed: true));
        return;
      }
      _remoteFailed = false;
    }
    _failedSourceConfig = null;
    await _onConfigChanged(next, emit);
  }

  Future<void> _onConfigChanged(AutoRotateConfig next, Emitter<AutoRotateState> emit) async {
    if (_userId != _requestedUserId) return;
    if (next == state.config) return;
    final int sessionGeneration = _sessionGeneration;
    final AutoRotateConfig previous = state.config;
    await _repository.saveConfig(next, ownerId: _userId);
    if (sessionGeneration != _sessionGeneration) return;
    _failedSourceConfig = null;
    emit(_snapshot(next));
    if (!next.enabled) return;
    if (!_canRotate) {
      await _disable(emit);
    } else if (!state.status.isRunning || _rotationChanged(previous, next)) {
      await _start(next, emit);
    }
  }

  Future<void> _onRotateNow(_RotateNowPressed event, Emitter<AutoRotateState> emit) async {
    if (!state.config.enabled) return;
    bool rotated = false;
    try {
      rotated = await _repository.rotateNow();
    } on PlatformException {
      rotated = false;
    }
    analytics.track(AutoRotateRunResultEvent(result: rotated ? BinaryResultValue.success : BinaryResultValue.failure));
    final AutoRotateStatus status = await _status();
    if (status.isRunning) {
      emit(
        state.copyWith(
          status: AutoRotateStatus(
            isRunning: true,
            nextRunEpochMs: status.nextRunEpochMs,
            lastError: rotated ? status.lastError : status.lastError ?? 'Could not rotate wallpaper now.',
            cachedCount: status.cachedCount,
            totalCount: status.totalCount,
          ),
        ),
      );
      return;
    }
    await _disable(emit);
  }

  Future<void> _onStatusRefreshed(Emitter<AutoRotateState> emit) async {
    final AutoRotateStatus status = await _status();
    if (!state.status.isRunning || !status.isRunning) return;
    if (status == state.status) {
      _schedulePoll(status);
    } else {
      emit(state.copyWith(status: status));
    }
  }

  Future<void> _stopStaleStart() async {
    try {
      await _repository.stop();
    } on PlatformException {
      // The queued entitlement event will retry the stop for the current account.
    }
    _appliedUrls = const <String>[];
  }

  Future<void> _start(AutoRotateConfig config, Emitter<AutoRotateState> emit, {bool userInitiated = false}) async {
    if (_userId != _requestedUserId) return;
    final int sessionGeneration = _sessionGeneration;
    final bool wasRunning = state.status.isRunning;
    final List<String> sourceUrls = _activeUrls(config);
    _pollsLeft = _maxStatusPolls;
    emit(state.copyWith(starting: true, startFailed: false));
    try {
      final List<String> urls = await _repository.resolveSources(sourceUrls);
      if (sessionGeneration != _sessionGeneration) return;
      if (urls.length < minWallpapers) {
        await _disable(emit, startFailed: true);
        return;
      }
      if (!await _repository.start(config, urls)) {
        await _disable(emit, startFailed: true);
        return;
      }
      if (sessionGeneration != _sessionGeneration) {
        await _stopStaleStart();
        return;
      }
      final AutoRotateStatus status = await _status();
      if (sessionGeneration != _sessionGeneration) {
        await _stopStaleStart();
        return;
      }
      if (!status.isRunning) {
        await _disable(emit, startFailed: true);
        return;
      }
      await _repository.saveConfig(config, ownerId: _userId);
      if (sessionGeneration != _sessionGeneration) {
        await _stopStaleStart();
        return;
      }
      try {
        _appliedUrls = await _repository.loadAppliedSources() ?? urls;
      } catch (_) {
        _appliedUrls = urls;
      }
      if (sessionGeneration != _sessionGeneration) {
        await _stopStaleStart();
        return;
      }
      final bool showTip = userInitiated && !wasRunning && await _repository.consumeBatteryTip();
      emit(
        state.copyWith(
          config: config,
          status: status,
          startFailed: false,
          starting: false,
          showBatteryTip: state.showBatteryTip || showTip,
        ),
      );
      if (!wasRunning && status.isRunning && status.lastError == null) {
        analytics.track(
          AutoRotateEnabledEvent(
            intervalMinutes: config.intervalMinutes,
            target: config.target,
            shuffle: config.shuffle,
            wallpaperCount: urls.length,
            source: config.source.name,
            category: config.source == AutoRotateSource.category ? config.categoryName : null,
          ),
        );
      }
    } on PlatformException {
      await _disable(emit, startFailed: true);
    } finally {
      if (state.starting) emit(state.copyWith(starting: false));
    }
  }

  Future<void> _disable(
    Emitter<AutoRotateState> emit, {
    bool startFailed = false,
    AutoRotateStopReason? folderStop,
  }) async {
    final bool wasRunning = state.status.isRunning;
    bool stopped = false;
    try {
      stopped = await _repository.stop();
    } on PlatformException {
      stopped = false;
    }
    if (stopped) _appliedUrls = const <String>[];
    final AutoRotateConfig next = state.config.copyWith(enabled: false);
    await _repository.saveConfig(next, ownerId: _userId);
    final AutoRotateStatus latestStatus = await _status();
    final AutoRotateStatus status = stopped
        ? const AutoRotateStatus()
        : AutoRotateStatus(
            isRunning: state.status.isRunning || latestStatus.isRunning,
            nextRunEpochMs: latestStatus.isRunning ? latestStatus.nextRunEpochMs : state.status.nextRunEpochMs,
            lastError: latestStatus.lastError ?? 'Failed to stop wallpaper rotation.',
          );
    emit(
      state.copyWith(
        config: next,
        status: status,
        startFailed: startFailed,
        starting: false,
        folderStop: folderStop == null ? state.folderStop : (reason: folderStop, folderName: next.folderName),
      ),
    );
    if (wasRunning && stopped) {
      analytics.track(const AutoRotateDisabledEvent());
    }
    if (folderStop != null) analytics.track(AutoRotateStoppedEvent(reason: folderStop.name));
  }
}
