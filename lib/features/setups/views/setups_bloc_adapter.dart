import 'package:Prism/core/firestore/dtos/setup_doc_dto.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/setups/biz/bloc/setups_bloc.j.dart';
import 'package:Prism/features/setups/domain/entities/setup_entity.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SetupsAdapter {
  SetupsAdapter(BuildContext context, {required bool listen})
    : _bloc = listen ? context.watch<SetupsBloc>() : context.read<SetupsBloc>();

  final SetupsBloc _bloc;

  List<SetupEntity>? get setups {
    final state = _bloc.state;
    if (state.status == LoadStatus.initial) {
      return null;
    }
    return state.items;
  }

  Future<void> getSetups() async {
    _bloc.add(const SetupsEvent.started());
    await _bloc.stream.firstWhere((state) => state.status != LoadStatus.loading);
  }

  Future<void> seeMoreSetups() async {
    if (_bloc.state.isFetchingMore || !_bloc.state.hasMore) {
      return;
    }

    final completion = _bloc.stream.firstWhere((state) => !state.isFetchingMore);
    _bloc.add(const SetupsEvent.fetchMoreRequested());
    await completion;
  }
}

extension SetupsBlocAdapterX on BuildContext {
  SetupsAdapter setupsAdapter({bool listen = true}) {
    return SetupsAdapter(this, listen: listen);
  }
}

SetupEntity? setup;

Future<SetupEntity?> getSetupFromName(String? name) async {
  try {
    final List<(SetupDocDto, String)> value = await firestoreClient.query<(SetupDocDto, String)>(
      FirestoreQuerySpec(
        collection: FirebaseCollections.setups,
        sourceTag: 'setups.lookup.byName',
        filters: <FirestoreFilter>[FirestoreFilter(field: 'name', op: FirestoreFilterOp.isEqualTo, value: name)],
        limit: 1,
      ),
      (data, docId) => (SetupDocDto.fromJson(data), docId),
    );
    if (value.isEmpty) {
      return null;
    }
    final SetupDocDto item = value.first.$1;
    final String docId = value.first.$2;
    setup = SetupEntity(
      id: item.id,
      by: item.by,
      icon: item.icon,
      iconUrl: item.iconUrl,
      createdAt: item.createdAt,
      desc: item.desc,
      email: item.email,
      image: item.image,
      name: item.name,
      userPhoto: item.userPhoto,
      wallId: item.wallId,
      source: WallpaperSourceX.fromWire(item.wallpaperProvider),
      wallpaperThumb: item.wallpaperThumb,
      wallpaperUrl: item.wallpaperUrl,
      widget: item.widget,
      widget2: item.widget2,
      widgetUrl: item.widgetUrl,
      widgetUrl2: item.widgetUrl2,
      link: item.link,
      review: item.review,
      resolution: item.resolution,
      size: item.size,
      firestoreDocumentId: docId,
    );
    return setup;
  } catch (error) {
    logger.d('data done with error');
    logger.d(error.toString());
    setup = null;
    return null;
  }
}
