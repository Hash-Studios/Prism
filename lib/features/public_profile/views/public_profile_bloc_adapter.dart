import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PublicProfileSnapshot {
  const PublicProfileSnapshot(this._payload);

  final Map<String, dynamic> _payload;

  Map<String, dynamic> data() => _payload;

  dynamic operator [](String key) => _payload[key];
}

class PublicProfileAdapter {
  PublicProfileAdapter(BuildContext context, {required bool listen})
      : _bloc = listen ? context.watch<PublicProfileBloc>() : context.read<PublicProfileBloc>();

  final PublicProfileBloc _bloc;

  List<PublicProfileSnapshot>? get userProfileWalls {
    final state = _bloc.state;
    if (state.status == LoadStatus.initial) {
      return null;
    }
    return state.walls.map((item) => PublicProfileSnapshot(item.payload)).toList(growable: false);
  }

  List<PublicProfileSnapshot>? get userProfileSetups {
    final state = _bloc.state;
    if (state.status == LoadStatus.initial) {
      return null;
    }
    return state.setups.map((item) => PublicProfileSnapshot(item.payload)).toList(growable: false);
  }

  bool get hasMoreWalls => _bloc.state.hasMoreWalls;

  bool get hasMoreSetups => _bloc.state.hasMoreSetups;

  Future<void> getuserProfileWalls(String? email) {
    return _ensureLoadedEmail(_normalizeEmail(email));
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
    return _ensureLoadedEmail(_normalizeEmail(email));
  }

  Future<void> refreshProfile(String? email) async {
    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail.isEmpty) {
      return;
    }
    if (_bloc.state.email != normalizedEmail || _bloc.state.status == LoadStatus.initial) {
      await _loadForEmail(normalizedEmail, force: true);
      return;
    }
    if (_bloc.state.status == LoadStatus.loading) {
      await _bloc.stream.firstWhere((state) => state.status != LoadStatus.loading);
      return;
    }
    _bloc.add(const PublicProfileEvent.refreshRequested());
    await _bloc.stream.firstWhere((state) => state.status != LoadStatus.loading);
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

  Future<void> _ensureLoadedEmail(String email) async {
    if (email.isEmpty) {
      return;
    }
    await _loadForEmail(email);
  }

  Future<void> _loadForEmail(String email, {bool force = false}) async {
    if (email.isEmpty) {
      return;
    }
    final state = _bloc.state;
    final bool sameEmail = state.email == email;
    if (!force && sameEmail) {
      if (state.status == LoadStatus.loading) {
        await _bloc.stream.firstWhere((value) => value.status != LoadStatus.loading);
        return;
      }
      if (state.status != LoadStatus.initial) {
        return;
      }
    }
    _bloc.add(PublicProfileEvent.started(email: email));
    await _bloc.stream.firstWhere((value) => value.status != LoadStatus.loading);
  }

  String _normalizeEmail(String? email) => email?.trim() ?? '';
}

extension PublicProfileBlocAdapterX on BuildContext {
  PublicProfileAdapter publicProfileAdapter({bool listen = true}) {
    return PublicProfileAdapter(this, listen: listen);
  }
}
