import 'package:Prism/core/utils/status.dart';
import 'package:Prism/data/pexels/model/wallpaperp.dart';
import 'package:Prism/data/wallhaven/model/wallpaper.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FavouriteWallSnapshot {
  const FavouriteWallSnapshot(this._payload);

  final Map<String, dynamic> _payload;

  Map<String, dynamic> data() => _payload;

  dynamic operator [](String key) => _payload[key];
}

class FavouriteWallsAdapter {
  FavouriteWallsAdapter(BuildContext context, {required bool listen})
      : _bloc = listen ? context.watch<FavouriteWallsBloc>() : context.read<FavouriteWallsBloc>();

  final FavouriteWallsBloc _bloc;

  List<FavouriteWallSnapshot>? get liked {
    final state = _bloc.state;
    if (state.status == LoadStatus.initial) {
      return null;
    }
    return state.items.map((item) => FavouriteWallSnapshot(item.payload)).toList(growable: false);
  }

  Future<List<FavouriteWallSnapshot>?> getDataBase({bool forceRefresh = false}) async {
    await _ensureLoaded(forceRefresh: forceRefresh);
    return liked;
  }

  Future<void> favCheck(
    String? id,
    String provider,
    WallPaper? wallhaven,
    WallPaperP? pexels,
    Map? prism,
  ) async {
    final resolvedId = id?.toString() ?? '';
    if (resolvedId.isEmpty) {
      return;
    }

    final userId = globals.prismUser.id;
    if (userId.isEmpty) {
      return;
    }

    await _ensureLoaded();

    final completion = _bloc.stream.firstWhere((state) => state.actionStatus != ActionStatus.inProgress);
    _bloc.add(
      FavouriteWallsEvent.toggleRequested(
        wall: FavouriteWallEntity(
          id: resolvedId,
          provider: provider,
          payload: _buildPayload(
            id: resolvedId,
            provider: provider,
            wallhaven: wallhaven,
            pexels: pexels,
            prism: prism,
          ),
        ),
      ),
    );
    await completion;
  }

  Future<bool> deleteData() async {
    final userId = globals.prismUser.id;
    if (userId.isEmpty) {
      return false;
    }

    await _ensureLoaded();
    final completion = _bloc.stream.firstWhere((state) => state.actionStatus != ActionStatus.inProgress);
    _bloc.add(const FavouriteWallsEvent.clearRequested());
    await completion;
    return _bloc.state.actionStatus == ActionStatus.success;
  }

  Future<void> _ensureLoaded({bool forceRefresh = false}) async {
    final userId = globals.prismUser.id;
    if (userId.isEmpty) {
      return;
    }

    if (_bloc.state.userId != userId || _bloc.state.status == LoadStatus.initial) {
      _bloc.add(FavouriteWallsEvent.started(userId: userId));
    } else if (forceRefresh || _bloc.state.status == LoadStatus.failure) {
      _bloc.add(const FavouriteWallsEvent.refreshRequested());
    } else {
      return;
    }

    await _bloc.stream.firstWhere((state) => state.status != LoadStatus.loading);
  }

  Map<String, dynamic> _buildPayload({
    required String id,
    required String provider,
    required WallPaper? wallhaven,
    required WallPaperP? pexels,
    required Map? prism,
  }) {
    if (provider == 'WallHaven' && wallhaven != null) {
      return <String, dynamic>{
        'id': wallhaven.id.toString(),
        'url': wallhaven.path.toString(),
        'thumb': wallhaven.thumbs?['original'].toString() ?? '',
        'category': wallhaven.category.toString(),
        'provider': 'WallHaven',
        'views': wallhaven.views.toString(),
        'resolution': wallhaven.resolution.toString(),
        'fav': wallhaven.favourites.toString(),
        'size': wallhaven.file_size.toString(),
        'photographer': '',
        'createdAt': DateTime.now().toUtc(),
      };
    }

    if (provider == 'Pexels' && pexels != null) {
      return <String, dynamic>{
        'id': pexels.id.toString(),
        'url': pexels.src?['original'].toString() ?? '',
        'thumb': pexels.src?['medium'].toString() ?? '',
        'category': '',
        'provider': 'Pexels',
        'views': '',
        'resolution': '${pexels.width}x${pexels.height}',
        'fav': '',
        'size': '',
        'photographer': pexels.photographer.toString(),
        'createdAt': DateTime.now().toUtc(),
      };
    }

    if (provider == 'Prism' && prism != null) {
      return <String, dynamic>{
        'id': prism['id'].toString(),
        'url': prism['wallpaper_url'].toString(),
        'thumb': prism['wallpaper_thumb'].toString(),
        'category': prism['desc'].toString(),
        'provider': 'Prism',
        'views': '',
        'resolution': prism['resolution'].toString(),
        'fav': '',
        'size': prism['size'].toString(),
        'photographer': prism['by'].toString(),
        'createdAt': DateTime.now().toUtc(),
      };
    }

    final existing = _existingPayload(id);
    if (existing != null) {
      return existing;
    }

    return <String, dynamic>{
      'id': id,
      'provider': provider,
      'createdAt': DateTime.now().toUtc(),
    };
  }

  Map<String, dynamic>? _existingPayload(String id) {
    for (final item in _bloc.state.items) {
      if (item.id == id) {
        return item.payload;
      }
    }
    return null;
  }
}

extension FavouriteWallsBlocAdapterX on BuildContext {
  FavouriteWallsAdapter favouriteWallsAdapter({bool listen = true}) {
    return FavouriteWallsAdapter(this, listen: listen);
  }
}
