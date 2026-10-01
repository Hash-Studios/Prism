import 'dart:async';

import 'package:Prism/core/platform/quick_tile_config_service.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/wall_of_the_day/biz/bloc/wotd_bloc.j.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WotdQuickTileListener extends BlocListener<WotdBloc, WotdState> {
  const WotdQuickTileListener({super.key, super.child}) : super(listenWhen: _listenWhen, listener: _cacheUrl);

  static bool _listenWhen(WotdState previous, WotdState current) =>
      current.status == LoadStatus.success &&
      (previous.status != LoadStatus.success || previous.entity?.url != current.entity?.url);

  static void _cacheUrl(BuildContext context, WotdState state) {
    unawaited(QuickTileConfigService.pushWotdUrl(state.entity?.url ?? ''));
  }
}
