import 'package:Prism/logger/logger.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// BlocObserver that logs all BLoC/Cubit lifecycle events via the app logger.
/// Register once at startup: `Bloc.observer = BlocDebugObserver();`
class BlocDebugObserver extends BlocObserver {
  const BlocDebugObserver();

  static const String _tag = 'BLoC';

  @override
  void onCreate(BlocBase<dynamic> bloc) {
    super.onCreate(bloc);
    logger.d('Created ${bloc.runtimeType}', tag: _tag);
  }

  @override
  void onEvent(Bloc<dynamic, dynamic> bloc, Object? event) {
    super.onEvent(bloc, event);
    logger.d(
      '${bloc.runtimeType} ← ${event.runtimeType}',
      tag: _tag,
      fields: <String, Object?>{'bloc': bloc.runtimeType.toString(), 'event': event.toString()},
    );
  }

  @override
  void onTransition(Bloc<dynamic, dynamic> bloc, Transition<dynamic, dynamic> transition) {
    super.onTransition(bloc, transition);
    logger.d(
      '${bloc.runtimeType} state: ${transition.nextState.runtimeType}',
      tag: _tag,
      fields: <String, Object?>{
        'bloc': bloc.runtimeType.toString(),
        'event': transition.event.runtimeType.toString(),
        'from': transition.currentState.runtimeType.toString(),
        'to': transition.nextState.runtimeType.toString(),
      },
    );
  }

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    logger.d(
      '${bloc.runtimeType} changed: ${change.nextState.runtimeType}',
      tag: _tag,
      fields: <String, Object?>{
        'bloc': bloc.runtimeType.toString(),
        'from': change.currentState.runtimeType.toString(),
        'to': change.nextState.runtimeType.toString(),
      },
    );
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    logger.e(
      '${bloc.runtimeType} error',
      tag: _tag,
      error: error,
      stackTrace: stackTrace,
      fields: <String, Object?>{'bloc': bloc.runtimeType.toString()},
    );
  }

  @override
  void onClose(BlocBase<dynamic> bloc) {
    super.onClose(bloc);
    logger.d('Closed ${bloc.runtimeType}', tag: _tag);
  }
}
