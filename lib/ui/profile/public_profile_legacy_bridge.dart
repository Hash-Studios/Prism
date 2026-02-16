import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/public_profile/presentation/bloc/public_profile_bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LegacyPublicProfileSnapshot {
  const LegacyPublicProfileSnapshot(this._payload);

  final Map<String, dynamic> _payload;

  Map<String, dynamic> data() => _payload;

  dynamic operator [](String key) => _payload[key];
}

class LegacyUserProfileProvider {
  LegacyUserProfileProvider(BuildContext context, {required bool listen})
      : _bloc = listen ? context.watch<PublicProfileBloc>() : context.read<PublicProfileBloc>();

  final PublicProfileBloc _bloc;

  List<LegacyPublicProfileSnapshot>? get userProfileWalls {
    final state = _bloc.state;
    if (state.status == LoadStatus.initial) {
      return null;
    }
    return state.walls.map((item) => LegacyPublicProfileSnapshot(item.payload)).toList(growable: false);
  }

  List<LegacyPublicProfileSnapshot>? get userProfileSetups {
    final state = _bloc.state;
    if (state.status == LoadStatus.initial) {
      return null;
    }
    return state.setups.map((item) => LegacyPublicProfileSnapshot(item.payload)).toList(growable: false);
  }

  Future<void> getuserProfileWalls(String? email) {
    return _loadForEmail(email);
  }

  Future<void> seeMoreUserProfileWalls(String? email) async {
    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail.isEmpty) {
      return;
    }
    await _ensureLoadedEmail(normalizedEmail);

    if (_bloc.state.isFetchingMoreWalls || !_bloc.state.hasMoreWalls) {
      return;
    }
    final completion = _bloc.stream.firstWhere((state) => !state.isFetchingMoreWalls);
    _bloc.add(const PublicProfileEvent.fetchMoreWallsRequested());
    await completion;
  }

  Future<void> getUserProfileSetups(String? email) {
    return _loadForEmail(email);
  }

  Future<void> seeMoreUserProfileSetups(String? email) async {
    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail.isEmpty) {
      return;
    }
    await _ensureLoadedEmail(normalizedEmail);

    if (_bloc.state.isFetchingMoreSetups || !_bloc.state.hasMoreSetups) {
      return;
    }
    final completion = _bloc.stream.firstWhere((state) => !state.isFetchingMoreSetups);
    _bloc.add(const PublicProfileEvent.fetchMoreSetupsRequested());
    await completion;
  }

  Future<void> _loadForEmail(String? email) async {
    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail.isEmpty) {
      return;
    }
    _bloc.add(PublicProfileEvent.started(email: normalizedEmail));
    await _bloc.stream.firstWhere((state) => state.status != LoadStatus.loading);
  }

  Future<void> _ensureLoadedEmail(String email) async {
    if (_bloc.state.email == email && _bloc.state.status != LoadStatus.initial) {
      return;
    }
    await _loadForEmail(email);
  }

  String _normalizeEmail(String? email) => email?.trim() ?? '';
}

extension PublicProfileLegacyBridgeX on BuildContext {
  LegacyUserProfileProvider publicProfileLegacyProvider({bool listen = true}) {
    return LegacyUserProfileProvider(this, listen: listen);
  }
}
