import 'package:Prism/core/di/injection.dart';
import 'package:Prism/features/deep_link/biz/bloc/deep_link_bloc.j.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DeepLinkBuilder {
  const DeepLinkBuilder._();

  static Widget withBloc({required Widget child, DeepLinkBloc? bloc}) {
    return BlocProvider<DeepLinkBloc>(create: (_) => bloc ?? getIt<DeepLinkBloc>(), child: child);
  }
}
