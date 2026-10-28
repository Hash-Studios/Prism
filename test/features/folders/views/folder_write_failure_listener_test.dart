import 'dart:async';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/folders/biz/bloc/folders_bloc.j.dart';
import 'package:Prism/features/folders/views/widgets/folder_write_failure_listener.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _FoldersBloc extends MockBloc<FoldersEvent, FoldersState> implements FoldersBloc {}

void main() {
  testWidgets('a late queued-write rejection shows one error even after the picker is gone', (tester) async {
    final bloc = _FoldersBloc();
    final states = StreamController<FoldersState>.broadcast(sync: true);
    final initial = FoldersState.initial().copyWith(status: LoadStatus.success, userId: 'u1');
    whenListen(bloc, states.stream, initialState: initial);
    final messages = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      (call) async {
        if (call.method == 'showToast') messages.add((call.arguments as Map)['msg'] as String);
        return true;
      },
    );
    addTearDown(() async {
      await states.close();
      await bloc.close();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('PonnamKarthik/fluttertoast'),
        null,
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<FoldersBloc>.value(
          value: bloc,
          child: FolderWriteFailureListener(child: const Scaffold()),
        ),
      ),
    );
    const failure = ServerFailure('permission-denied');
    states.add(initial.copyWith(failure: failure));
    await tester.pump();
    expect(messages, isEmpty);

    final rejected = initial.copyWith(queuedWriteFailure: failure);
    states.add(rejected);
    await tester.pump();
    states.add(rejected.copyWith(completedOperationId: 2));
    await tester.pump();

    expect(messages, <String>['Could not save to folders. Try again.']);
    await tester.pump(const Duration(seconds: 2));
  });
}
