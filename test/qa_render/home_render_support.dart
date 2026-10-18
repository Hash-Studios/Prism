import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:auto_route/auto_route.dart';
// ignore: depend_on_referenced_packages
import 'package:file/local.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

const bool homeRender = bool.fromEnvironment('QA_RENDER') || int.fromEnvironment('QA_RENDER') == 1;

String get _photoDir => Platform.environment['QA_PHOTOS'] ?? '/tmp/prism-qa/home-photos';
String get renderDir => Platform.environment['QA_OUT'] ?? '/tmp/prism-qa/home-renders';

/// Url the fake cache resolves to the local photo [name], for example `w07.jpg`.
String photoUrl(String name) => 'https://qa.prism.test/photo/$name';

List<String> get portraitPhotos => <String>[for (int i = 1; i <= 24; i++) 'w${i.toString().padLeft(2, '0')}.jpg'];

/// Answers every image url with a real photo from the photo folder. A url ending in a photo file name gets that photo;
/// any other url gets one picked by its hash, so a screen with unplanned urls still shows pictures.
class QaPhotoCache extends Fake implements BaseCacheManager {
  QaPhotoCache._();

  static HttpOverrides? _previousHttp;
  static Directory? _appDir;

  /// Besides [PrismImageCache], a few widgets (the avatar, the interest tiles) use the package's default cache manager.
  /// That one writes to the app directories and downloads over HTTP, so those two are faked too.
  static void install() {
    PrismImageCache.testOverride = QaPhotoCache._();
    _appDir ??= Directory.systemTemp.createTempSync('qa_render_app_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async => _appDir!.path,
    );
    _previousHttp = HttpOverrides.current;
    HttpOverrides.global = _PhotoHttpOverrides();
  }

  static void uninstall() {
    PrismImageCache.testOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    HttpOverrides.global = _previousHttp;
  }

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) {
    final String name = Uri.tryParse(url)?.pathSegments.lastOrNull ?? '';
    final List<String> portraits = portraitPhotos;
    final String file = File('$_photoDir/$name').existsSync() && name.endsWith('.jpg')
        ? name
        : portraits[url.hashCode.abs() % portraits.length];
    return Stream<FileResponse>.value(
      FileInfo(
        const LocalFileSystem().file('$_photoDir/$file'),
        FileSource.Cache,
        DateTime.now().add(const Duration(days: 1)),
        url,
      ),
    );
  }
}

List<int> _photoBytes(Uri url) {
  final String name = url.pathSegments.lastOrNull ?? '';
  final File file = File('$_photoDir/$name');
  return (file.existsSync() && name.endsWith('.jpg') ? file : File('$_photoDir/w01.jpg')).readAsBytesSync();
}

class _PhotoHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _PhotoHttpClient();
}

class _PhotoHttpClient extends Fake implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => _PhotoRequest(url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _PhotoRequest extends Fake implements HttpClientRequest {
  _PhotoRequest(this._url);

  final Uri _url;

  @override
  HttpHeaders get headers => _PhotoRequestHeaders();

  @override
  Future<dynamic> addStream(Stream<List<int>> stream) => stream.drain<void>();

  @override
  Future<HttpClientResponse> close() async => _PhotoResponse(_photoBytes(_url));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _PhotoRequestHeaders extends Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _PhotoResponse extends Stream<List<int>> implements HttpClientResponse {
  _PhotoResponse(this._bytes);

  final List<int> _bytes;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(_bytes).listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  int get statusCode => 200;

  @override
  int get contentLength => _bytes.length;

  @override
  String get reasonPhrase => 'OK';

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const <RedirectInfo>[];

  @override
  bool get persistentConnection => false;

  @override
  HttpHeaders get headers => _PhotoResponseHeaders();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _PhotoResponseHeaders extends Fake implements HttpHeaders {
  @override
  void forEach(void Function(String name, List<String> values) action) {
    action('content-type', <String>['image/jpeg']);
    action('cache-control', <String>['max-age=86400']);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Loads the families declared in pubspec.yaml with the weights the manifest gives them, because the app maps weights
/// to files in pubspec (for example w700 to Proxima Nova Extrabold) while the engine reads the weight from the file.
Future<void> loadAppFonts() async {
  final Map<String, Object?> manifestEntry = <String, Object?>{};
  final List<Object?> manifest = json.decode(await rootBundle.loadString('FontManifest.json')) as List<Object?>;
  for (final Object? entry in manifest) {
    final Map<String, Object?> family = (entry! as Map<Object?, Object?>).cast<String, Object?>();
    manifestEntry[family['family']! as String] = family['fonts'];
  }
  for (final MapEntry<String, Object?> family in manifestEntry.entries) {
    final FontLoader loader = FontLoader(family.key);
    for (final Object? font in family.value! as List<Object?>) {
      final Map<String, Object?> spec = (font! as Map<Object?, Object?>).cast<String, Object?>();
      final ByteData data = await rootBundle.load(Uri.decodeFull(spec['asset']! as String));
      final int? weight = spec['weight'] as int?;
      loader.addFont(Future<ByteData>.value(weight == null ? data : _withWeight(data, weight)));
    }
    await loader.load();
  }
  final Directory? fonts = _sdkFontDir();
  if (fonts == null) return;
  final FontLoader roboto = FontLoader('Roboto');
  for (final String weight in <String>['Regular', 'Medium', 'Bold']) {
    final File file = File('${fonts.path}/Roboto-$weight.ttf');
    if (file.existsSync()) {
      roboto.addFont(Future<ByteData>.value(ByteData.sublistView(file.readAsBytesSync())));
    }
  }
  await roboto.load();
  final File icons = File('${fonts.path}/MaterialIcons-Regular.otf');
  if (icons.existsSync() && !manifestEntry.containsKey('MaterialIcons')) {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future<ByteData>.value(ByteData.sublistView(icons.readAsBytesSync())))).load();
  }
}

Directory? _sdkFontDir() {
  final List<String> roots = <String>[
    ?Platform.environment['FLUTTER_ROOT'],
    '${Platform.environment['HOME']}/fvm/versions/3.47.5',
  ];
  Directory walk = File(Platform.resolvedExecutable).parent;
  while (walk.parent.path != walk.path) {
    roots.add(walk.path);
    walk = walk.parent;
  }
  for (final String root in roots) {
    final Directory dir = Directory('$root/bin/cache/artifacts/material_fonts');
    if (dir.existsSync()) return dir;
  }
  return null;
}

/// Rewrites usWeightClass in the OS/2 table, which is where Skia reads the weight of a loaded font.
ByteData _withWeight(ByteData data, int weight) {
  final Uint8List bytes = Uint8List.fromList(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  final ByteData view = ByteData.sublistView(bytes);
  if (bytes.length < 12) return data;
  final int tables = view.getUint16(4);
  for (int i = 0; i < tables; i++) {
    final int record = 12 + 16 * i;
    if (record + 16 > bytes.length) break;
    final String tag = String.fromCharCodes(bytes.sublist(record, record + 4));
    if (tag == 'OS/2') {
      view.setUint16(view.getUint32(record + 8) + 4, weight);
      break;
    }
  }
  return ByteData.sublistView(bytes);
}

class MockStackRouter extends Mock implements StackRouter {}

/// An iPhone 15 sized view: 390x844 logical px at 3x, with the status bar and home indicator insets.
class HomeShot {
  HomeShot(this.tester);

  final WidgetTester tester;
  final GlobalKey boundary = GlobalKey();

  static const double statusBar = 47;
  static const double homeIndicator = 34;

  void configureView() {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: statusBar * 3, bottom: homeIndicator * 3);
    tester.view.viewPadding = const FakeViewPadding(top: statusBar * 3, bottom: homeIndicator * 3);
    addTearDown(() {
      tester.view.reset();
      tester.view.resetPadding();
      tester.view.resetViewPadding();
    });
  }

  /// Wraps [home] in the capture boundary plus a fake status bar and home indicator drawn above the app.
  Widget frame(Widget home, {required Brightness brightness}) => Directionality(
    textDirection: TextDirection.ltr,
    child: RepaintBoundary(
      key: boundary,
      child: Stack(
        children: <Widget>[
          Positioned.fill(child: home),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: statusBar,
            child: IgnorePointer(child: _StatusIcons(dark: brightness == Brightness.dark)),
          ),
          const Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: SizedBox(
                  width: 134,
                  height: 5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFFFFFFFF),
                      borderRadius: BorderRadius.all(Radius.circular(3)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  /// Bounded pumps: Glint, shimmer and the carousel timer animate forever, so `pumpAndSettle` would time out.
  /// Image files decode on real IO, which fake time never advances.
  Future<void> settle({int frames = 8, int frameMs = 250}) async {
    for (int i = 0; i < frames; i++) {
      await tester.pump(Duration(milliseconds: frameMs));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
    }
  }

  /// Drags in small steps with frames between, like a finger, so scroll-direction logic sees real deltas.
  Future<void> scrollBy(double dy, {Offset from = const Offset(195, 480), int steps = 18}) async {
    final TestGesture gesture = await tester.startGesture(from);
    final double step = dy / steps;
    for (int i = 0; i < steps; i++) {
      await gesture.moveBy(Offset(0, step));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await settle(frames: 4, frameMs: 150);
  }

  Future<File> save(String name) async {
    final RenderRepaintBoundary render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final File file = File('$renderDir/$name.png');
    await tester.runAsync(() async {
      final ui.Image image = await render.toImage(pixelRatio: 3);
      final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    return file;
  }
}

class _StatusIcons extends StatelessWidget {
  const _StatusIcons({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final Color ink = dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 14, 28, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '9:41',
            style: TextStyle(
              color: ink,
              fontFamily: 'Roboto',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.none,
            ),
          ),
          const Spacer(),
          Icon(Icons.signal_cellular_alt_rounded, color: ink, size: 16),
          const SizedBox(width: 4),
          Icon(Icons.wifi_rounded, color: ink, size: 16),
          const SizedBox(width: 4),
          Icon(Icons.battery_full_rounded, color: ink, size: 18),
        ],
      ),
    );
  }
}
