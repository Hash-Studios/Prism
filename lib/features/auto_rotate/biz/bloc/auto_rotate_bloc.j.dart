import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/usecase/usecase.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/data/categories/categories.dart';
import 'package:Prism/data/categories/category_definition.dart';
import 'package:Prism/data/collections/provider/collectionsWithoutProvider.dart';
import 'package:Prism/features/auto_rotate/domain/entities/auto_rotate_config_entity.dart';
import 'package:Prism/features/auto_rotate/domain/usecases/auto_rotate_usecases.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;
import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'auto_rotate_event.j.dart';
part 'auto_rotate_state.j.dart';
part 'auto_rotate_bloc.j.freezed.dart';

@injectable
class AutoRotateBloc extends Bloc<AutoRotateEvent, AutoRotateState> {
  AutoRotateBloc(
    this._loadConfigUseCase,
    this._saveConfigUseCase,
    this._startAutoRotateUseCase,
    this._stopAutoRotateUseCase,
    this._getStatusUseCase,
  ) : super(AutoRotateState.initial()) {
    on<_Started>(_onStarted);
    on<_SourceTypeChanged>(_onSourceTypeChanged);
    on<_TargetChanged>(_onTargetChanged);
    on<_IntervalChanged>(_onIntervalChanged);
    on<_ChargingTriggerToggled>(_onChargingTriggerToggled);
    on<_OrderChanged>(_onOrderChanged);
    on<_StartRequested>(_onStartRequested);
    on<_StopRequested>(_onStopRequested);
    on<_StatusRefreshRequested>(_onStatusRefreshRequested);
    on<_RotateNowRequested>(_onRotateNowRequested);
  }

  final LoadAutoRotateConfigUseCase _loadConfigUseCase;
  final SaveAutoRotateConfigUseCase _saveConfigUseCase;
  final StartAutoRotateUseCase _startAutoRotateUseCase;
  final StopAutoRotateUseCase _stopAutoRotateUseCase;
  final GetAutoRotateStatusUseCase _getStatusUseCase;

  Future<void> _onStarted(_Started event, Emitter<AutoRotateState> emit) async {
    emit(state.copyWith(status: LoadStatus.loading, failure: null));

    // Load saved config
    final configResult = await _loadConfigUseCase(const NoParams());
    final config = configResult.fold(onSuccess: (c) => c, onFailure: (_) => AutoRotateConfigEntity.defaults);

    // Load available collections
    final collectionList = await getCollections();
    final availableCollections = (collectionList ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map((c) => c['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toList();

    // Check current rotation status
    final statusResult = await _getStatusUseCase(const NoParams());
    final isRunning = statusResult.fold(onSuccess: (v) => v, onFailure: (_) => false);

    emit(
      state.copyWith(
        status: LoadStatus.success,
        config: config,
        isRunning: isRunning,
        availableCollections: availableCollections,
        availableCategories: categoryDefinitions,
        failure: null,
      ),
    );
  }

  Future<void> _onSourceTypeChanged(_SourceTypeChanged event, Emitter<AutoRotateState> emit) async {
    final updated = state.config.copyWith(
      sourceType: event.sourceType,
      collectionName: event.sourceType == AutoRotateSourceType.collection ? event.name : null,
      categoryName: event.sourceType == AutoRotateSourceType.category ? event.name : null,
    );
    emit(state.copyWith(config: updated));
    await _saveConfigUseCase(updated);
  }

  Future<void> _onTargetChanged(_TargetChanged event, Emitter<AutoRotateState> emit) async {
    final updated = state.config.copyWith(target: event.target);
    emit(state.copyWith(config: updated));
    await _saveConfigUseCase(updated);
  }

  Future<void> _onIntervalChanged(_IntervalChanged event, Emitter<AutoRotateState> emit) async {
    final updated = state.config.copyWith(intervalMinutes: event.minutes);
    emit(state.copyWith(config: updated));
    await _saveConfigUseCase(updated);
  }

  Future<void> _onChargingTriggerToggled(_ChargingTriggerToggled event, Emitter<AutoRotateState> emit) async {
    final updated = state.config.copyWith(chargingTrigger: !state.config.chargingTrigger);
    emit(state.copyWith(config: updated));
    await _saveConfigUseCase(updated);
  }

  Future<void> _onOrderChanged(_OrderChanged event, Emitter<AutoRotateState> emit) async {
    final updated = state.config.copyWith(order: event.order);
    emit(state.copyWith(config: updated));
    await _saveConfigUseCase(updated);
  }

  Future<void> _onStartRequested(_StartRequested event, Emitter<AutoRotateState> emit) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, failure: null));
    final result = await _startAutoRotateUseCase(state.config);
    result.fold(
      onSuccess: (_) => emit(state.copyWith(actionStatus: ActionStatus.success, isRunning: true, failure: null)),
      onFailure: (failure) => emit(state.copyWith(actionStatus: ActionStatus.failure, failure: failure)),
    );
  }

  Future<void> _onStopRequested(_StopRequested event, Emitter<AutoRotateState> emit) async {
    emit(state.copyWith(actionStatus: ActionStatus.inProgress, failure: null));
    final result = await _stopAutoRotateUseCase(const NoParams());
    result.fold(
      onSuccess: (_) => emit(state.copyWith(actionStatus: ActionStatus.success, isRunning: false, failure: null)),
      onFailure: (failure) => emit(state.copyWith(actionStatus: ActionStatus.failure, failure: failure)),
    );
  }

  Future<void> _onStatusRefreshRequested(_StatusRefreshRequested event, Emitter<AutoRotateState> emit) async {
    final result = await _getStatusUseCase(const NoParams());
    result.fold(
      onSuccess: (isRunning) => emit(state.copyWith(isRunning: isRunning)),
      onFailure: (_) {},
    );
  }

  Future<void> _onRotateNowRequested(_RotateNowRequested event, Emitter<AutoRotateState> emit) async {
    try {
      await aw.AsyncWallpaper.rotateWallpaperNow();
    } catch (_) {}
  }
}
