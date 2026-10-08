// ignore_for_file: depend_on_referenced_packages

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/purchases/upload_quota.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/navigation/views/widgets/upload_bottom_panel.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';

class _Picker extends ImagePickerPlatform {
  _Picker(this.paths);

  final List<String> paths;
  int? multiLimit;
  int singleCalls = 0;

  @override
  Future<List<XFile>> getMultiImageWithOptions({
    MultiImagePickerOptions options = const MultiImagePickerOptions(),
  }) async {
    multiLimit = options.limit;
    return paths.map(XFile.new).toList();
  }

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    singleCalls++;
    return XFile(paths.first);
  }
}

class _PanelRouter extends AppRouter {
  _PanelRouter(this.onEdit);

  final void Function(EditWallRouteArgs args) onEdit;

  @override
  List<AutoRoute> get routes => <AutoRoute>[
    AutoRoute(
      path: '/',
      page: PageInfo(
        'PanelHost',
        builder: (_) => Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => context.router.push<Object?>(const _PanelRoute()),
              child: const Text('Open panel'),
            ),
          ),
        ),
      ),
    ),
    AutoRoute(
      path: '/panel',
      page: PageInfo(_PanelRoute.name, builder: (_) => const Scaffold(body: UploadBottomPanel())),
    ),
    AutoRoute(
      path: '/edit-wall',
      page: PageInfo(
        EditWallRoute.name,
        builder: (data) {
          onEdit(data.argsAs<EditWallRouteArgs>());
          return const Scaffold(body: Text('edit-stub'));
        },
      ),
    ),
  ];
}

class _PanelRoute extends PageRouteInfo<void> {
  const _PanelRoute() : super(name);

  static const String name = 'PanelRoute';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ImagePickerPlatform previousPicker;
  late SettingsLocalDataSource settings;

  setUp(() async {
    previousPicker = ImagePickerPlatform.instance;
    await getIt.reset();
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    AnalyticsRuntime.instance = FakeAppAnalytics();
    app_state.prismUser = app_constants.createGuestPrismUser();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      (_) async => true,
    );
  });

  tearDown(() async {
    ImagePickerPlatform.instance = previousPicker;
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('PonnamKarthik/fluttertoast'),
      null,
    );
    await getIt.reset();
  });

  Future<List<EditWallRouteArgs>> pickWith(WidgetTester tester, _Picker picker) async {
    ImagePickerPlatform.instance = picker;
    final opened = <EditWallRouteArgs>[];
    final router = _PanelRouter(opened.add);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router.config()));
    await router.navigatePath('/');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open panel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wallpapers'));
    await tester.pumpAndSettle();
    return opened;
  }

  testWidgets('a free user can pick as many images as the week has slots left', (tester) async {
    await settings.set('uploadsWeekStart', _thisWeekStart());
    await settings.set('uploadsThisWeek', 1);
    final picker = _Picker(<String>['/tmp/a.png', '/tmp/b.png']);

    final opened = await pickWith(tester, picker);

    expect(UploadQuota.remainingFreeUploadsThisWeek(), 2);
    expect(picker.multiLimit, 2);
    expect(opened.single.image.path, '/tmp/a.png');
    expect(opened.single.batch!.total, 2);
    expect(find.text('edit-stub'), findsOneWidget);
  });

  testWidgets('one image starts the normal single upload with no batch', (tester) async {
    final picker = _Picker(<String>['/tmp/a.png']);

    final opened = await pickWith(tester, picker);

    expect(opened.single.batch, isNull);
  });

  testWidgets('a Prism Pro user can pick ten and extra images are dropped', (tester) async {
    app_state.prismUser.premium = true;
    final picker = _Picker(<String>[for (var i = 0; i < 12; i++) '/tmp/$i.png']);

    final opened = await pickWith(tester, picker);

    expect(picker.multiLimit, 10);
    expect(opened.single.batch!.total, 10);
  });
}

String _thisWeekStart() {
  final now = DateTime.now();
  return DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: now.weekday - DateTime.monday)).toIso8601String();
}
