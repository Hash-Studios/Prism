import 'package:Prism/core/di/injection.dart';
import 'package:Prism/features/in_app_notifications/biz/bloc/in_app_notifications_bloc.j.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class InAppNotificationsBuilder {
  const InAppNotificationsBuilder._();

  static Widget withBloc({required Widget child, InAppNotificationsBloc? bloc}) {
    return BlocProvider<InAppNotificationsBloc>(create: (_) => bloc ?? getIt<InAppNotificationsBloc>(), child: child);
  }
}
