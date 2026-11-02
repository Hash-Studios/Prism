import 'dart:io';
import 'dart:ui' as ui;

import 'package:Prism/core/share/share_card_renderer.dart';
import 'package:Prism/features/wrapped/domain/wrapped.dart';
import 'package:Prism/features/wrapped/views/widgets/wrapped_card_view.dart';
import 'package:Prism/features/wrapped/views/wrapped_copy.dart';
import 'package:Prism/features/wrapped/views/wrapped_share.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'wrapped_fixture.dart';

/// Decodes an in-memory image, or resolves anything else (the logo asset) through the production resolver.
Future<ui.Image> _resolve(ImageProvider provider) async {
  final ImageProvider inner = provider is ResizeImage ? provider.imageProvider : provider;
  if (inner is! MemoryImage) return resolveShareCardImage(provider);
  final ui.Codec codec = await ui.instantiateImageCodec(inner.bytes);
  final ui.Image image = (await codec.getNextFrame()).image;
  codec.dispose();
  return image;
}

void main() {
  testWidgets('renders a 1080x1920 PNG story file', (tester) async {
    final AppLocalizations l10n = await loadAppLocalizations(const Locale('en'));
    final WrappedYear year = fixtureWrappedYear();
    final WrappedCopy copy = wrappedCopy(l10n, 'en', year, year.cards[3]);
    await tester.runAsync(() async {
      final Directory tempDir = await Directory.systemTemp.createTemp('prism_wrapped_share_test_');
      const MethodChannel channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (MethodCall call) async => tempDir.path,
      );
      addTearDown(() async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
        await tempDir.delete(recursive: true);
      });

      final ui.Image pixel = await createTestImage();
      final ByteData? pixelBytes = await pixel.toByteData(format: ui.ImageByteFormat.png);
      pixel.dispose();
      final Uint8List pixelPng = pixelBytes!.buffer.asUint8List();

      final File file = await renderWrappedShareFile(
        copy,
        <String>['a', 'b', 'c', 'd'],
        const Color(0xFF0066CC),
        loadImage: (_) async => MemoryImage(pixelPng),
        resolveImage: _resolve,
      );

      expect(file.existsSync(), isTrue);
      final Uint8List png = await file.readAsBytes();
      expect(png.sublist(0, 8), <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      final ByteData header = ByteData.sublistView(png);
      expect(header.getUint32(16), 1080);
      expect(header.getUint32(20), 1920);
      await file.delete();
    });
  });

  testWidgets('the creator card view shows its public handle and not its profile name', (tester) async {
    final AppLocalizations l10n = await loadAppLocalizations(const Locale('en'));
    final WrappedYear year = fixtureWrappedYear();
    final WrappedCopy copy = wrappedCopy(l10n, 'en', year, year.cards[3]);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 360,
          height: 640,
          child: WrappedCardView(copy: copy, background: const SizedBox.expand(), accent: const Color(0xFFFFFFFF)),
        ),
      ),
    );

    expect(find.text('@maya'), findsOneWidget);
    expect(find.textContaining('Maya'), findsNothing);
  });

  test('wrappedCardImages uses the four summary thumbs', () {
    const WrappedCard summary = WrappedCard(
      kind: WrappedCardKind.summary,
      heroUrl: '',
      thumbs: <String>['a', 'b', 'c', 'd'],
    );

    expect(wrappedCardImages(summary), <String>['a', 'b', 'c', 'd']);
  });

  test('wrappedCardImages uses the hero for a saves card', () {
    const WrappedCard saves = WrappedCard(
      kind: WrappedCardKind.saves,
      heroUrl: 'https://cdn.example.test/wrapped/saves.jpg',
      value: 12,
    );

    expect(wrappedCardImages(saves), <String>['https://cdn.example.test/wrapped/saves.jpg']);
  });
}
