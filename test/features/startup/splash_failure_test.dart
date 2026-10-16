import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/startup/biz/bloc/startup_bloc.j.dart';
import 'package:Prism/features/startup/views/pages/splash_widget.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/in_memory_local_store.dart';

class _MockStartupBloc extends MockBloc<StartupEvent, StartupState> implements StartupBloc {}

void main() {
  late _MockStartupBloc bloc;

  setUp(() {
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
    bloc = _MockStartupBloc();
  });

  tearDown(getIt.reset);

  Future<void> pumpSplash(WidgetTester tester, LoadStatus status) {
    when(() => bloc.state).thenReturn(StartupState.initial().copyWith(status: status));
    return tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<StartupBloc>.value(value: bloc, child: const SplashWidget()),
      ),
    );
  }

  testWidgets('a failed bootstrap shows a try again button that starts bootstrap again', (tester) async {
    await pumpSplash(tester, LoadStatus.failure);

    expect(find.text("Prism could not start"), findsOneWidget);
    await tester.tap(find.text('Try again'));

    verify(() => bloc.add(StartupEvent.started(currentVersion: app_state.currentAppVersion))).called(1);
  });

  testWidgets('a loading bootstrap shows no try again button', (tester) async {
    await pumpSplash(tester, LoadStatus.loading);

    expect(find.text('Try again'), findsNothing);
  });
}
