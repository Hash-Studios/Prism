import 'dart:async';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/folders/domain/entities/smart_rule.dart';
import 'package:Prism/features/folders/domain/repositories/smart_folders_repository.dart';
import 'package:Prism/features/public_profile/domain/entities/user_summary_entity.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum SmartPreviewStatus { noRules, loading, ready, failure }

/// Why the last tap did not add a rule.
enum SmartRuleBlock { kindLimit, valueLimit }

class SmartFolderBuilderState {
  const SmartFolderBuilderState({
    this.rules = const <SmartRule>[],
    this.previewStatus = SmartPreviewStatus.noRules,
    this.preview,
    this.creators,
    this.blocked,
    this.saving = false,
  });

  final List<SmartRule> rules;
  final SmartPreviewStatus previewStatus;

  /// The last preview that loaded. It stays on screen while the next one loads.
  final SmartPreview? preview;

  /// The creators the user follows, for the Creator row. Null until they load.
  final List<UserSummaryEntity>? creators;
  final SmartRuleBlock? blocked;
  final bool saving;

  SmartFolderBuilderState copyWith({
    List<SmartRule>? rules,
    SmartPreviewStatus? previewStatus,
    SmartPreview? preview,
    List<UserSummaryEntity>? creators,
    SmartRuleBlock? Function()? blocked,
    bool? saving,
  }) => SmartFolderBuilderState(
    rules: rules ?? this.rules,
    previewStatus: previewStatus ?? this.previewStatus,
    preview: preview ?? this.preview,
    creators: creators ?? this.creators,
    blocked: blocked == null ? this.blocked : blocked(),
    saving: saving ?? this.saving,
  );
}

/// The rule builder of the smart folder sheet: the rules, a debounced live preview and the save.
class SmartFolderBuilderCubit extends Cubit<SmartFolderBuilderState> {
  SmartFolderBuilderCubit(
    this._repository, {
    List<SmartRule> initialRules = const <SmartRule>[],
    Future<List<UserSummaryEntity>> Function()? loadCreators,
    this.debounce = const Duration(milliseconds: 400),
  }) : super(SmartFolderBuilderState(rules: sortSmartRules(initialRules))) {
    if (state.rules.isNotEmpty) _schedulePreview(immediately: true);
    if (loadCreators != null) {
      unawaited(
        loadCreators().then(
          (creators) => isClosed ? null : emit(state.copyWith(creators: creators)),
          onError: (Object _) => isClosed ? null : emit(state.copyWith(creators: const <UserSummaryEntity>[])),
        ),
      );
    }
  }

  final SmartFoldersRepository _repository;
  final Duration debounce;
  Timer? _timer;
  int _request = 0;

  /// Adds or removes [rule]. Returns false when the rule does not fit the limits.
  bool toggle(SmartRule rule) {
    final List<SmartRule> next = toggleSmartRule(state.rules, rule);
    if (identical(next, state.rules)) {
      final bool newKind = !smartKindsOf(state.rules).contains(rule.kind);
      emit(state.copyWith(blocked: () => newKind ? SmartRuleBlock.kindLimit : SmartRuleBlock.valueLimit));
      return false;
    }
    emit(state.copyWith(rules: next, blocked: () => null));
    _schedulePreview();
    return true;
  }

  void retryPreview() => _schedulePreview(immediately: true);

  void _schedulePreview({bool immediately = false}) {
    _timer?.cancel();
    final int request = ++_request;
    if (state.rules.isEmpty) {
      emit(state.copyWith(previewStatus: SmartPreviewStatus.noRules));
      return;
    }
    emit(state.copyWith(previewStatus: SmartPreviewStatus.loading));
    _timer = Timer(immediately ? Duration.zero : debounce, () => unawaited(_loadPreview(request)));
  }

  Future<void> _loadPreview(int request) async {
    final Result<SmartPreview> result = await _repository.preview(state.rules);
    if (isClosed || request != _request) return;
    final SmartPreview? preview = result.data;
    emit(
      preview == null
          ? state.copyWith(previewStatus: SmartPreviewStatus.failure)
          : state.copyWith(previewStatus: SmartPreviewStatus.ready, preview: preview),
    );
  }

  Future<Result<({String folderId, int count})>> create(String name) =>
      _saving(() => _repository.create(name: name, rules: state.rules));

  Future<Result<int>> saveRules(String folderId) => _saving(() => _repository.updateRules(folderId, state.rules));

  Future<Result<T>> _saving<T>(Future<Result<T>> Function() run) async {
    if (state.saving || state.rules.isEmpty) return Result.error(const ValidationFailure('Pick a rule first.'));
    emit(state.copyWith(saving: true));
    final Result<T> result = await run();
    if (!isClosed) emit(state.copyWith(saving: false));
    return result;
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
