import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/favourite_setups/domain/entities/favourite_setup_entity.dart';
import 'package:Prism/features/favourite_setups/presentation/bloc/favourite_setups_bloc.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LegacyFavouriteSetupSnapshot {
  const LegacyFavouriteSetupSnapshot(this._payload);

  final Map<String, dynamic> _payload;

  Map<String, dynamic> data() => _payload;

  dynamic operator [](String key) => _payload[key];
}

class LegacyFavouriteSetupsProvider {
  LegacyFavouriteSetupsProvider(BuildContext context, {required bool listen})
      : _bloc = listen ? context.watch<FavouriteSetupsBloc>() : context.read<FavouriteSetupsBloc>();

  final FavouriteSetupsBloc _bloc;

  List<LegacyFavouriteSetupSnapshot>? get liked {
    final state = _bloc.state;
    if (state.status == LoadStatus.initial) {
      return null;
    }
    return state.items.map((item) => LegacyFavouriteSetupSnapshot(item.payload)).toList(growable: false);
  }

  Future<List<LegacyFavouriteSetupSnapshot>?> getDataBase() async {
    await _ensureLoaded();
    return liked;
  }

  Future<void> favCheck(String id, Map? setup) async {
    final resolvedId = id;
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
      FavouriteSetupsEvent.toggleRequested(
        setup: FavouriteSetupEntity(
          id: resolvedId,
          payload: _buildPayload(id: resolvedId, setup: setup),
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
    _bloc.add(const FavouriteSetupsEvent.clearRequested());
    await completion;
    return _bloc.state.actionStatus == ActionStatus.success;
  }

  Future<void> _ensureLoaded() async {
    final userId = globals.prismUser.id;
    if (userId.isEmpty) {
      return;
    }

    if (_bloc.state.userId != userId || _bloc.state.status == LoadStatus.initial) {
      _bloc.add(FavouriteSetupsEvent.started(userId: userId));
    } else {
      _bloc.add(const FavouriteSetupsEvent.refreshRequested());
    }

    await _bloc.stream.firstWhere((state) => state.status != LoadStatus.loading);
  }

  Map<String, dynamic> _buildPayload({required String id, required Map? setup}) {
    final existing = _existingPayload(id);
    if (setup == null) {
      return existing ?? <String, dynamic>{'id': id, 'created_at': DateTime.now().toUtc()};
    }

    return <String, dynamic>{
      'by': setup['by'].toString(),
      'icon': setup['icon'].toString(),
      'icon_url': setup['icon_url'].toString(),
      'created_at': DateTime.now().toUtc(),
      'desc': setup['desc'].toString(),
      'email': setup['email'].toString(),
      'id': setup['id'].toString(),
      'image': setup['image'].toString(),
      'name': setup['name'].toString(),
      'userPhoto': setup['userPhoto'].toString(),
      'wall_id': setup['wall_id'].toString(),
      'wallpaper_provider': setup['wallpaper_provider'].toString(),
      'wallpaper_thumb': setup['wallpaper_thumb'].toString(),
      'wallpaper_url': setup['wallpaper_url'],
      'widget': setup['widget'].toString(),
      'widget2': setup['widget2'].toString(),
      'widget_url': setup['widget_url'].toString(),
      'widget_url2': setup['widget_url2'].toString(),
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

extension FavouriteSetupsLegacyBridgeX on BuildContext {
  LegacyFavouriteSetupsProvider favouriteSetupsLegacyProvider({bool listen = true}) {
    return LegacyFavouriteSetupsProvider(this, listen: listen);
  }
}
