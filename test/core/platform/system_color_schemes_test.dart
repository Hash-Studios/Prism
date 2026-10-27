import 'dart:async';

import 'package:Prism/core/platform/system_color_schemes.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const List<String> _roleKeys = <String>[
  'primary',
  'onPrimary',
  'primaryContainer',
  'onPrimaryContainer',
  'primaryFixed',
  'primaryFixedDim',
  'onPrimaryFixed',
  'onPrimaryFixedVariant',
  'secondary',
  'onSecondary',
  'secondaryContainer',
  'onSecondaryContainer',
  'secondaryFixed',
  'secondaryFixedDim',
  'onSecondaryFixed',
  'onSecondaryFixedVariant',
  'tertiary',
  'onTertiary',
  'tertiaryContainer',
  'onTertiaryContainer',
  'tertiaryFixed',
  'tertiaryFixedDim',
  'onTertiaryFixed',
  'onTertiaryFixedVariant',
  'error',
  'onError',
  'errorContainer',
  'onErrorContainer',
  'surface',
  'onSurface',
  'surfaceDim',
  'surfaceBright',
  'surfaceContainerLowest',
  'surfaceContainerLow',
  'surfaceContainer',
  'surfaceContainerHigh',
  'surfaceContainerHighest',
  'onSurfaceVariant',
  'outline',
  'outlineVariant',
  'shadow',
  'scrim',
  'inverseSurface',
  'onInverseSurface',
  'inversePrimary',
  'surfaceTint',
];

/// Every role gets a distinct value: `0xFF000000 + index`, except primary, which is [primary].
Map<String, int> roles(int primary) {
  return <String, int>{
    for (int index = 0; index < _roleKeys.length; index++)
      _roleKeys[index]: _roleKeys[index] == 'primary' ? primary : 0xFF000000 + index,
  };
}

Color _colorOf(ColorScheme scheme, String role) => switch (role) {
  'primary' => scheme.primary,
  'onPrimary' => scheme.onPrimary,
  'primaryContainer' => scheme.primaryContainer,
  'onPrimaryContainer' => scheme.onPrimaryContainer,
  'primaryFixed' => scheme.primaryFixed,
  'primaryFixedDim' => scheme.primaryFixedDim,
  'onPrimaryFixed' => scheme.onPrimaryFixed,
  'onPrimaryFixedVariant' => scheme.onPrimaryFixedVariant,
  'secondary' => scheme.secondary,
  'onSecondary' => scheme.onSecondary,
  'secondaryContainer' => scheme.secondaryContainer,
  'onSecondaryContainer' => scheme.onSecondaryContainer,
  'secondaryFixed' => scheme.secondaryFixed,
  'secondaryFixedDim' => scheme.secondaryFixedDim,
  'onSecondaryFixed' => scheme.onSecondaryFixed,
  'onSecondaryFixedVariant' => scheme.onSecondaryFixedVariant,
  'tertiary' => scheme.tertiary,
  'onTertiary' => scheme.onTertiary,
  'tertiaryContainer' => scheme.tertiaryContainer,
  'onTertiaryContainer' => scheme.onTertiaryContainer,
  'tertiaryFixed' => scheme.tertiaryFixed,
  'tertiaryFixedDim' => scheme.tertiaryFixedDim,
  'onTertiaryFixed' => scheme.onTertiaryFixed,
  'onTertiaryFixedVariant' => scheme.onTertiaryFixedVariant,
  'error' => scheme.error,
  'onError' => scheme.onError,
  'errorContainer' => scheme.errorContainer,
  'onErrorContainer' => scheme.onErrorContainer,
  'surface' => scheme.surface,
  'onSurface' => scheme.onSurface,
  'surfaceDim' => scheme.surfaceDim,
  'surfaceBright' => scheme.surfaceBright,
  'surfaceContainerLowest' => scheme.surfaceContainerLowest,
  'surfaceContainerLow' => scheme.surfaceContainerLow,
  'surfaceContainer' => scheme.surfaceContainer,
  'surfaceContainerHigh' => scheme.surfaceContainerHigh,
  'surfaceContainerHighest' => scheme.surfaceContainerHighest,
  'onSurfaceVariant' => scheme.onSurfaceVariant,
  'outline' => scheme.outline,
  'outlineVariant' => scheme.outlineVariant,
  'shadow' => scheme.shadow,
  'scrim' => scheme.scrim,
  'inverseSurface' => scheme.inverseSurface,
  'onInverseSurface' => scheme.onInverseSurface,
  'inversePrimary' => scheme.inversePrimary,
  'surfaceTint' => scheme.surfaceTint,
  _ => throw ArgumentError('Unknown role $role'),
};

SystemColorSchemes _schemesFor(int primary) =>
    SystemColorSchemes.fromPayload(<String, Object?>{'light': roles(primary), 'dark': roles(primary)})!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('systemColorSchemeFromRoles', () {
    test('complete payload sets every one of the 46 roles and the requested brightness', () {
      final Map<String, int> payload = roles(0xFF112233);
      final ColorScheme scheme = systemColorSchemeFromRoles(payload, Brightness.light)!;

      expect(_roleKeys, hasLength(46));
      for (final String role in _roleKeys) {
        expect(_colorOf(scheme, role), Color(payload[role]!), reason: role);
      }
      expect(scheme.primary, const Color(0xFF112233));
      expect(scheme.onPrimary, const Color(0xFF000001));
      expect(scheme.secondary, const Color(0xFF000008));
      expect(scheme.tertiaryContainer, const Color(0xFF000012));
      expect(scheme.error, const Color(0xFF000018));
      expect(scheme.surface, const Color(0xFF00001C));
      expect(scheme.onSurface, const Color(0xFF00001D));
      expect(scheme.surfaceContainerHighest, const Color(0xFF000024));
      expect(scheme.outlineVariant, const Color(0xFF000027));
      expect(scheme.inversePrimary, const Color(0xFF00002C));
      expect(scheme.surfaceTint, const Color(0xFF00002D));
      expect(scheme.primaryFixedDim, const Color(0xFF000005));
      expect(scheme.brightness, Brightness.light);
    });

    test('complete payload keeps the requested dark brightness', () {
      final ColorScheme scheme = systemColorSchemeFromRoles(roles(0xFF445566), Brightness.dark)!;

      expect(scheme.brightness, Brightness.dark);
      expect(scheme.primary, const Color(0xFF445566));
    });

    test('missing roles fall back to the seed scheme', () {
      final ColorScheme scheme = systemColorSchemeFromRoles(<String, Object?>{
        'primary': 0xFF3366CC,
        'surface': 0xFF101010,
      }, Brightness.dark)!;

      expect(scheme.primary, const Color(0xFF3366CC));
      expect(scheme.surface, const Color(0xFF101010));
      expect(
        scheme.onSurface,
        ColorScheme.fromSeed(seedColor: const Color(0xFF3366CC), brightness: Brightness.dark).onSurface,
      );
    });

    test('no primary returns null', () {
      expect(systemColorSchemeFromRoles(<String, int>{'surface': 0xFF101010}, Brightness.light), isNull);
    });

    test('null returns null', () {
      expect(systemColorSchemeFromRoles(null, Brightness.light), isNull);
    });

    test('non-map returns null', () {
      expect(systemColorSchemeFromRoles('x', Brightness.light), isNull);
    });

    test('a non-int role value is ignored and falls back to the seed', () {
      final ColorScheme scheme = systemColorSchemeFromRoles(<String, Object?>{
        'primary': 0xFF3366CC,
        'surface': 'red',
      }, Brightness.light)!;

      expect(scheme.surface, ColorScheme.fromSeed(seedColor: const Color(0xFF3366CC)).surface);
    });
  });

  group('SystemColorSchemes.fromPayload', () {
    test('reads light and dark sides with their brightness', () {
      final SystemColorSchemes schemes = SystemColorSchemes.fromPayload(<String, Object?>{
        'light': roles(0xFF112233),
        'dark': roles(0xFF445566),
      })!;

      expect(schemes.light.primary, const Color(0xFF112233));
      expect(schemes.dark.primary, const Color(0xFF445566));
      expect(schemes.light.brightness, Brightness.light);
      expect(schemes.dark.brightness, Brightness.dark);
    });

    test('missing dark returns null', () {
      expect(SystemColorSchemes.fromPayload(<String, Object?>{'light': roles(0xFF112233)}), isNull);
    });

    test('null returns null', () {
      expect(SystemColorSchemes.fromPayload(null), isNull);
    });

    test('payloads built from the same maps are equal with equal hashCode', () {
      final SystemColorSchemes a = _schemesFor(0xFF112233);
      final SystemColorSchemes b = _schemesFor(0xFF112233);

      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
    });

    test('a different primary is not equal', () {
      expect(_schemesFor(0xFF112233) == _schemesFor(0xFF445566), isFalse);
    });
  });

  group('SystemColorSchemesSource', () {
    late List<Duration> waits;

    Future<void> fakeWait(Duration duration) {
      waits.add(duration);
      return Future<void>.value();
    }

    setUp(() {
      waits = <Duration>[];
    });

    test('refresh stores the value and emits it once', () async {
      final SystemColorSchemes a = _schemesFor(0xFF112233);
      final SystemColorSchemesSource source = SystemColorSchemesSource.withReader(() async => a, wait: fakeWait);

      final Future<void> emitted = expectLater(source.changes, emits(a));
      await source.refresh();
      await emitted;

      expect(source.current, a);
    });

    test('a second refresh with an equal value emits nothing more', () async {
      final SystemColorSchemesSource source = SystemColorSchemesSource.withReader(
        () async => _schemesFor(0xFF112233),
        wait: fakeWait,
      );
      final List<SystemColorSchemes?> events = <SystemColorSchemes?>[];
      final StreamSubscription<SystemColorSchemes?> subscription = source.changes.listen(events.add);
      addTearDown(subscription.cancel);

      await source.refresh();
      await source.refresh();
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
    });

    test('refresh failure keeps the last good value and does not throw', () async {
      final SystemColorSchemes a = _schemesFor(0xFF112233);
      int calls = 0;
      final SystemColorSchemesSource source = SystemColorSchemesSource.withReader(() async {
        calls++;
        if (calls == 1) return a;
        throw PlatformException(code: 'x');
      }, wait: fakeWait);

      await source.refresh();
      final SystemColorSchemes? second = await source.refresh();

      expect(source.current, a);
      expect(second, a);
      expect(calls, 2);
    });

    test('refreshAfterWallpaperSet stops once the colours change', () async {
      final SystemColorSchemes a = _schemesFor(0xFF112233);
      final SystemColorSchemes b = _schemesFor(0xFF445566);
      final List<SystemColorSchemes> responses = <SystemColorSchemes>[a, a, a, b];
      int calls = 0;
      final SystemColorSchemesSource source = SystemColorSchemesSource.withReader(
        () async => responses[calls++],
        wait: fakeWait,
      );

      await source.refresh();
      calls = 1;
      waits.clear();
      final bool changed = await source.refreshAfterWallpaperSet();

      expect(changed, isTrue);
      expect(source.current, b);
      expect(calls, 4);
      expect(waits, hasLength(3));
      expect(waits, everyElement(const Duration(milliseconds: 500)));
    });

    test('refreshAfterWallpaperSet gives up after the time limit', () async {
      final SystemColorSchemes a = _schemesFor(0xFF112233);
      int calls = 0;
      final SystemColorSchemesSource source = SystemColorSchemesSource.withReader(() async {
        calls++;
        return a;
      }, wait: fakeWait);

      await source.refresh();
      calls = 0;
      waits.clear();
      final bool changed = await source.refreshAfterWallpaperSet();

      expect(changed, isFalse);
      expect(waits, hasLength(12));
      expect(waits, everyElement(const Duration(milliseconds: 500)));
      expect(calls, 12);
      expect(source.current, a);
    });

    test('refreshAfterWallpaperSet does not count a failed read as a change', () async {
      final SystemColorSchemes a = _schemesFor(0xFF112233);
      int calls = 0;
      final SystemColorSchemesSource source = SystemColorSchemesSource.withReader(() async {
        calls++;
        if (calls == 1) return a;
        throw PlatformException(code: 'x');
      }, wait: fakeWait);

      await source.refresh();
      final bool changed = await source.refreshAfterWallpaperSet();

      expect(changed, isFalse);
      expect(source.current, a);
    });
  });

  group('SystemColorSchemesSource platform channel', () {
    const MethodChannel channel = MethodChannel('prism/system_colors');
    late TestDefaultBinaryMessenger messenger;
    late List<String> calls;

    void mockChannel(Future<Object?> Function(MethodCall call) handler) {
      messenger.setMockMethodCallHandler(channel, (MethodCall call) {
        calls.add(call.method);
        return handler(call);
      });
    }

    setUp(() {
      messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      calls = <String>[];
    });

    tearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    });

    test('on iOS refresh returns null and never calls the channel', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      mockChannel((MethodCall call) async => <String, Object?>{'light': roles(0xFF112233), 'dark': roles(0xFF445566)});
      final SystemColorSchemesSource source = SystemColorSchemesSource();

      final SystemColorSchemes? result = await source.refresh();

      expect(result, isNull);
      expect(source.current, isNull);
      expect(calls, isEmpty);
    });

    test('on Android a null payload returns null and calls the scheme method once', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      mockChannel((MethodCall call) async => null);
      final SystemColorSchemesSource source = SystemColorSchemesSource();

      final SystemColorSchemes? result = await source.refresh();

      expect(result, isNull);
      expect(calls, <String>['scheme']);
    });

    test('on Android a valid payload is read into current', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      mockChannel((MethodCall call) async => <String, Object?>{'light': roles(0xFF112233), 'dark': roles(0xFF445566)});
      final SystemColorSchemesSource source = SystemColorSchemesSource();

      final SystemColorSchemes? result = await source.refresh();

      expect(result?.light.primary, const Color(0xFF112233));
      expect(source.current?.light.primary, const Color(0xFF112233));
    });

    test('on Android a malformed payload returns null without throwing', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      mockChannel(
        (MethodCall call) async => <String, Object?>{'light': <String, Object?>{}, 'dark': <String, Object?>{}},
      );
      final SystemColorSchemesSource source = SystemColorSchemesSource();

      final SystemColorSchemes? result = await source.refresh();

      expect(result, isNull);
      expect(source.current, isNull);
    });
  });
}
