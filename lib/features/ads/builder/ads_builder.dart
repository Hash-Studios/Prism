import 'package:Prism/core/di/injection.dart';
import 'package:Prism/features/ads/biz/bloc/ads_bloc.j.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AdsBuilder {
  const AdsBuilder._();

  static Widget withBloc({required Widget child, AdsBloc? bloc}) {
    return BlocProvider<AdsBloc>(
      create: (_) => bloc ?? getIt<AdsBloc>(),
      child: child,
    );
  }
}
