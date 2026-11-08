import 'dart:async';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/folders/biz/smart_folder_builder_cubit.dart';
import 'package:Prism/features/folders/domain/entities/smart_rule.dart';
import 'package:Prism/features/folders/domain/repositories/smart_folders_repository.dart';
import 'package:Prism/features/public_profile/domain/entities/user_summary_entity.dart';
import 'package:flutter_test/flutter_test.dart';

const SmartRule _blue = SmartRule(SmartRuleKind.colour, 'blue');
const SmartRule _teal = SmartRule(SmartRuleKind.colour, 'teal');

class _FakeSmartRepo implements SmartFoldersRepository {
  /// The count of the next preview that is not gated.
  int count = 3;
  bool failPreview = false;

  /// One entry per preview call, with the rules it got.
  final List<List<SmartRule>> previewCalls = <List<SmartRule>>[];

  /// Preview calls that wait on a completer, keyed by their 1-based call number.
  final Map<int, Completer<Result<SmartPreview>>> gates = <int, Completer<Result<SmartPreview>>>{};

  @override
  Future<Result<SmartPreview>> preview(List<SmartRule> rules) {
    previewCalls.add(List<SmartRule>.of(rules));
    final Completer<Result<SmartPreview>>? gate = gates[previewCalls.length];
    if (gate != null) return gate.future;
    if (failPreview) return Future.value(Result.error<SmartPreview>(const NetworkFailure('offline')));
    return Future.value(
      Result.success<SmartPreview>(SmartPreview(count: count, more: false, walls: const <SmartPreviewWall>[])),
    );
  }

  @override
  Future<Result<({String folderId, int count})>> create({required String name, required List<SmartRule> rules}) async =>
      Result.success<({String folderId, int count})>((folderId: 'new', count: count));

  @override
  Future<Result<int>> updateRules(String folderId, List<SmartRule> rules) async => Result.success<int>(count);
}

Future<void> _flush() => Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
  late _FakeSmartRepo repo;

  setUp(() => repo = _FakeSmartRepo());

  SmartFolderBuilderCubit build({List<SmartRule> initial = const <SmartRule>[], Duration debounce = Duration.zero}) {
    final SmartFolderBuilderCubit cubit = SmartFolderBuilderCubit(
      repo,
      initialRules: initial,
      debounce: debounce,
      loadCreators: () async => const <UserSummaryEntity>[],
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test('toggle adds the rule, sends exactly that list to the repository, and goes loading then ready', () async {
    final SmartFolderBuilderCubit cubit = build();
    final List<SmartPreviewStatus> statuses = <SmartPreviewStatus>[];
    final StreamSubscription<SmartFolderBuilderState> sub = cubit.stream.listen((s) => statuses.add(s.previewStatus));
    addTearDown(sub.cancel);

    expect(cubit.toggle(_blue), isTrue);
    expect(cubit.state.rules, <SmartRule>[_blue]);
    expect(cubit.state.previewStatus, SmartPreviewStatus.loading);

    await _flush();

    expect(repo.previewCalls, <List<SmartRule>>[
      <SmartRule>[_blue],
    ]);
    expect(statuses, containsAllInOrder(<SmartPreviewStatus>[SmartPreviewStatus.loading, SmartPreviewStatus.ready]));
    expect(cubit.state.previewStatus, SmartPreviewStatus.ready);
    expect(cubit.state.preview?.count, 3);
  });

  test('a fourth kind is refused with kindLimit and leaves the rules unchanged', () {
    final SmartFolderBuilderCubit cubit = build();
    cubit.toggle(_blue);
    cubit.toggle(const SmartRule(SmartRuleKind.category, 'Nature'));
    cubit.toggle(const SmartRule(SmartRuleKind.followed));
    final List<SmartRule> before = cubit.state.rules;

    expect(cubit.toggle(const SmartRule(SmartRuleKind.desktop)), isFalse);

    expect(cubit.state.rules, before);
    expect(cubit.state.blocked, SmartRuleBlock.kindLimit);
  });

  test('a seventh value of one kind is refused with valueLimit', () {
    final SmartFolderBuilderCubit cubit = build();
    for (final String id in <String>['red', 'orange', 'yellow', 'green', 'teal', 'blue']) {
      expect(cubit.toggle(SmartRule(SmartRuleKind.colour, id)), isTrue);
    }
    final List<SmartRule> before = cubit.state.rules;

    expect(cubit.toggle(const SmartRule(SmartRuleKind.colour, 'purple')), isFalse);

    expect(cubit.state.rules, before);
    expect(cubit.state.blocked, SmartRuleBlock.valueLimit);
  });

  test('a stale preview response is ignored and the newer preview stays on screen', () async {
    repo.gates[1] = Completer<Result<SmartPreview>>();
    final SmartFolderBuilderCubit cubit = build(initial: const <SmartRule>[_blue]);
    await _flush();
    expect(repo.previewCalls, hasLength(1));

    repo.count = 7;
    expect(cubit.toggle(_teal), isTrue);
    await _flush();
    expect(cubit.state.preview?.count, 7);

    repo.gates[1]!.complete(
      Result.success<SmartPreview>(const SmartPreview(count: 1, more: false, walls: <SmartPreviewWall>[])),
    );
    await _flush();

    expect(cubit.state.preview?.count, 7);
    expect(cubit.state.previewStatus, SmartPreviewStatus.ready);
  });

  test('removing the last rule sets noRules and cancels the pending preview', () async {
    final SmartFolderBuilderCubit cubit = build();
    cubit.toggle(_blue);

    expect(cubit.toggle(_blue), isTrue);
    await _flush();

    expect(cubit.state.rules, isEmpty);
    expect(cubit.state.previewStatus, SmartPreviewStatus.noRules);
    expect(repo.previewCalls, isEmpty);
  });

  test('initialRules loads a preview at once, without the debounce', () async {
    final SmartFolderBuilderCubit cubit = build(
      initial: const <SmartRule>[_blue],
      debounce: const Duration(seconds: 5),
    );
    expect(cubit.state.previewStatus, SmartPreviewStatus.loading);

    await _flush();

    expect(repo.previewCalls, hasLength(1));
    expect(cubit.state.previewStatus, SmartPreviewStatus.ready);
    expect(cubit.state.preview?.count, 3);
  });
}
