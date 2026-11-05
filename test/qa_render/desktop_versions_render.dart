@Tags(<String>['qa_render'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/features/admin_review/views/widgets/desktop_submission_card.dart';
import 'package:Prism/features/desktop_submission/desktop_submission.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'qa_harness.dart';

String get _outDir => Platform.environment['QA_OUT'] ?? '/tmp/prism-qa/desktop-versions';

const String _wideUrl = 'https://qa.prism.local/desktop/dusk-ridge.png';
const String _phoneUrl = 'https://qa.prism.local/phone/dusk-ridge.png';

/// Real pixels for the desktop and phone thumbnails. Generated once per run, then served to every image request.
Uint8List? _wideBytes;
Uint8List? _phoneBytes;

Future<Uint8List> _gradientPng(int width, int height, ui.Color from, ui.Color to) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  final ui.Size size = ui.Size(width.toDouble(), height.toDouble());
  canvas.drawRect(
    ui.Offset.zero & size,
    ui.Paint()..shader = ui.Gradient.linear(ui.Offset.zero, ui.Offset(0, size.height), <ui.Color>[from, to]),
  );
  canvas.drawCircle(
    ui.Offset(width * 0.72, height * 0.38),
    height * 0.16,
    ui.Paint()..color = const ui.Color(0x55FFFFFF),
  );
  final ui.Image image = await recorder.endRecording().toImage(width, height);
  final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

/// Installs the image bytes and an HTTP stand-in, because the admin card loads its images with the default cache.
Future<void> _prepare(WidgetTester tester) async {
  _wideBytes ??= (await tester.runAsync(
    () => _gradientPng(2560, 1600, const ui.Color(0xFF203A6B), const ui.Color(0xFFF0A46B)),
  ))!;
  _phoneBytes ??= (await tester.runAsync(
    () => _gradientPng(270, 480, const ui.Color(0xFF6B4FA0), const ui.Color(0xFF1C1B3A)),
  ))!;

  final Directory appDir = Directory.systemTemp.createTempSync('qa_desktop_app_');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (MethodCall call) async => appDir.path,
  );
  final HttpOverrides? previous = HttpOverrides.current;
  HttpOverrides.global = _QaHttpOverrides();
  addTearDown(() {
    HttpOverrides.global = previous;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
  });
}

class _QaHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _QaHttpClient();
}

class _QaHttpClient extends Fake implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => _QaRequest(url);

  @override
  void close({bool force = false}) {}
}

class _QaRequest extends Fake implements HttpClientRequest {
  _QaRequest(this._url);

  final Uri _url;

  @override
  HttpHeaders get headers => _QaHeaders();

  @override
  Future<dynamic> addStream(Stream<List<int>> stream) => stream.drain<void>();

  @override
  Future<HttpClientResponse> close() async =>
      _QaResponse(_url.path.startsWith('/desktop') ? _wideBytes! : _phoneBytes!);
}

class _QaHeaders extends Fake implements HttpHeaders {
  @override
  void forEach(void Function(String name, List<String> values) action) {}

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _QaResponse extends Stream<List<int>> implements HttpClientResponse {
  _QaResponse(this._bytes);

  final Uint8List _bytes;

  @override
  int get statusCode => HttpStatus.ok;

  @override
  int get contentLength => _bytes.length;

  @override
  HttpHeaders get headers => _QaHeaders();

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => false;

  @override
  String get reasonPhrase => 'OK';

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(_bytes).listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Answers the upload and menu screens. Only the watch and submit calls are used by these scenes.
class _QaRepo extends Fake implements DesktopSubmissionRepository {
  _QaRepo({this.pending = false});

  final bool pending;

  @override
  Stream<bool> watchPendingForWall({required String wallDocId, required String uid}) => Stream<bool>.value(pending);
}

DesktopUploadScreen _upload({
  required bool replace,
  Future<Uint8List?> Function()? pick,
  Future<Size?> Function(Uint8List bytes)? measure,
}) => DesktopUploadScreen(
  wallDocId: 'wall_dusk_ridge',
  wallId: 'wall_dusk_ridge',
  phoneThumbUrl: _phoneUrl,
  wallTitle: 'Dusk ridge',
  replace: replace,
  repository: _QaRepo(),
  pickImage: pick,
  measure: measure,
);

Future<Uint8List?> _pickWide() async => _wideBytes;

Future<Uint8List?> _pickPortrait() async => _phoneBytes;

Future<Size?> _measureWide(Uint8List bytes) async => const Size(2560, 1600);

Future<Size?> _measurePortrait(Uint8List bytes) async => const Size(1080, 1920);

void _noop(bool replace) {}

Widget _screen(Widget child) => Scaffold(
  body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: child),
);

/// Text scale for a scene. 1 is the default size, 2 is the large text check.
Widget _scaled(Widget child, double scale) => Builder(
  builder: (BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child,
  ),
);

DesktopSubmission _submission() => DesktopSubmission(
  id: 'sub_dusk_ridge',
  wallDocId: 'wall_dusk_ridge',
  shareId: 'wall_share_dusk_ridge',
  creatorUid: 'uid_noor_qa',
  state: DesktopSubmissionState.pending,
  reason: null,
  thumbUrl: _wideUrl,
  sourceWidth: 2560,
  sourceHeight: 1600,
  aspect: '16:10',
  wallThumb: _phoneUrl,
  wallTitle: 'Dusk ridge',
  creatorName: 'Noor QA',
  replaces: true,
  createdAt: DateTime.now().subtract(const Duration(hours: 3)),
);

/// Saves as `<name>_<light|dark>[_2x].png` in the output folder.
Future<void> _save(QaShot shot, String name, double scale) async {
  final String suffix = scale == 1 ? '' : '_2x';
  final RenderRepaintBoundary render = shot.boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final File file = File('$_outDir/${name}_${shot.mode}$suffix.png');
  await shot.tester.runAsync(() async {
    final ui.Image image = await render.toImage(pixelRatio: 3);
    final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

/// Registers the scene at 1x and at 2x text scale, each in light and dark (via [qaScreen]).
void _scene(String name, Future<void> Function(QaShot shot, double scale) body, {double height = 844}) {
  for (final double scale in <double>[1, 2]) {
    final String suffix = scale == 1 ? '' : '_2x';
    qaScreen('$name$suffix', height: height, (QaShot shot) async {
      await _prepare(shot.tester);
      await body(shot, scale);
      // The default cache store schedules a 10 s cleanup timer when it reads a thumbnail. Run it out before the test ends.
      await shot.tester.pump(const Duration(seconds: 11));
      await _save(shot, name, scale);
    });
  }
}

void main() {
  setUpAll(() async {
    registerFallbackValue(WallpaperDetailRoute());
    if (qaRender) await loadFonts();
  });

  _scene('upload_empty', (QaShot shot, double scale) async {
    await shot.pump(_scaled(_upload(replace: false), scale));
  });

  _scene('upload_ready', (QaShot shot, double scale) async {
    await shot.pump(_scaled(_upload(replace: false, pick: _pickWide, measure: _measureWide), scale));
    await shot.tester.tap(find.text('Choose image'));
    await shot.settle();
  });

  _scene('upload_error', (QaShot shot, double scale) async {
    await shot.pump(_scaled(_upload(replace: false, pick: _pickPortrait, measure: _measurePortrait), scale));
    await shot.tester.tap(find.text('Choose image'));
    await shot.settle();
  });

  _scene('upload_replace', (QaShot shot, double scale) async {
    await shot.pump(_scaled(_upload(replace: true, pick: _pickWide, measure: _measureWide), scale));
    await shot.tester.tap(find.text('Choose image'));
    await shot.settle();
  });

  _scene('menu_states', (QaShot shot, double scale) async {
    await shot.pump(
      _scaled(
        _screen(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: <Widget>[
              DesktopVersionAction(
                wallDocId: 'wall_dusk_ridge',
                uid: 'uid_noor_qa',
                hasDesktop: false,
                onOpen: _noop,
                repository: _QaRepo(),
              ),
              DesktopVersionAction(
                wallDocId: 'wall_dusk_ridge',
                uid: 'uid_noor_qa',
                hasDesktop: true,
                onOpen: _noop,
                repository: _QaRepo(),
              ),
              DesktopVersionAction(
                wallDocId: 'wall_dusk_ridge',
                uid: 'uid_noor_qa',
                hasDesktop: true,
                onOpen: _noop,
                repository: _QaRepo(pending: true),
              ),
            ],
          ),
        ),
        scale,
      ),
    );
  }, height: 900);

  _scene('admin_card', (QaShot shot, double scale) async {
    await shot.pump(
      _scaled(
        _screen(DesktopSubmissionCard(submission: _submission(), onApprove: () async {}, onReject: () async {})),
        scale,
      ),
    );
    // The card loads both thumbnails through the default cache, which reads files on real IO. Give it time.
    await shot.settle(frames: 20);
  }, height: 1200);
}
