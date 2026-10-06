import 'package:Prism/features/live_wallpaper/data/shaders/live_shader_sources.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_palette.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shader_contract.dart';

void main() {
  final LivePalette darkPalette = LivePalette.fromAccent(const Color(0xFFE57697), dark: true);
  final LivePalette lightPalette = LivePalette.fromAccent(const Color(0xFF2962FF), dark: false);

  group('shader contract mirror', () {
    test('rejects what the plugin validator rejects', () {
      const String head = 'precision mediump float;\nvoid main() { gl_FragColor = vec4(1.0); }\n';
      expect(validateShaderContract(head, textureCount: 0), isEmpty);
      expect(validateShaderContract('$head uniform vec3 u_custom;', textureCount: 0), isNotEmpty);
      expect(validateShaderContract('$head uniform vec3 u_time;', textureCount: 0), isNotEmpty);
      expect(validateShaderContract('$head uniform sampler2D u_texture0;', textureCount: 0), isNotEmpty);
      expect(validateShaderContract('$head uniform sampler2D u_texture0;', textureCount: 1), isEmpty);
      expect(validateShaderContract('$head #pragma optimize(off)', textureCount: 0), isNotEmpty);
      expect(validateShaderContract('$head #version 300 es', textureCount: 0), isNotEmpty);
      expect(
        validateShaderContract('$head void f() { int n = 0; while (n < 2) { n++; } }', textureCount: 0),
        isNotEmpty,
      );
      expect(
        validateShaderContract('$head void f(int n) { for (int i = 0; i < n; i++) {} }', textureCount: 0),
        isNotEmpty,
      );
      expect(
        validateShaderContract('$head void f() { for (int i = 0; i < 129; i++) {} }', textureCount: 0),
        isNotEmpty,
      );
      expect(validateShaderContract('${head}float x = dFdx(1.0);', textureCount: 0), isNotEmpty);
    });
  });

  group('gradient shaders', () {
    for (final GradientStyle style in GradientStyle.values) {
      for (final (String name, LivePalette palette) in <(String, LivePalette)>[
        ('dark', darkPalette),
        ('light', lightPalette),
      ]) {
        test('${style.name} ($name) meets the contract', () {
          final String shader = LiveShaderSources.gradient(style, palette);
          expect(validateShaderContract(shader, textureCount: 0), isEmpty);
          expect(shader.contains('u_texture0'), isFalse);
        });
      }
    }
  });

  group('motion shaders', () {
    for (final MotionStyle style in MotionStyle.values) {
      test('${style.name} meets the contract with one texture', () {
        final String shader = LiveShaderSources.motion(style, darkPalette);
        expect(validateShaderContract(shader, textureCount: 1), isEmpty);
        expect(shader, contains('uniform sampler2D u_texture0;'));
      });

      test('${style.name} fails the contract with no texture', () {
        final String shader = LiveShaderSources.motion(style, darkPalette);
        expect(validateShaderContract(shader, textureCount: 0), isNotEmpty);
      });
    }
  });

  group('colour templating', () {
    test('writes valid vec3 literals in range', () {
      final String shader = LiveShaderSources.gradient(GradientStyle.mesh, darkPalette);
      final RegExp literal = RegExp(r'const vec3 (c0|c1|c2|c3|bg) = vec3\((\d\.\d{4}), (\d\.\d{4}), (\d\.\d{4})\);');
      final List<RegExpMatch> matches = literal.allMatches(shader).toList();
      expect(matches.map((match) => match.group(1)), <String>['c0', 'c1', 'c2', 'c3', 'bg']);
      for (final RegExpMatch match in matches) {
        for (final int group in <int>[2, 3, 4]) {
          final double value = double.parse(match.group(group)!);
          expect(value, inInclusiveRange(0.0, 1.0));
        }
      }
    });

    test('vec3Literal always has a decimal point', () {
      expect(LiveShaderSources.vec3Literal(const Color(0xFF000000)), 'vec3(0.0000, 0.0000, 0.0000)');
      expect(LiveShaderSources.vec3Literal(const Color(0xFFFFFFFF)), 'vec3(1.0000, 1.0000, 1.0000)');
    });

    test('different accents give different shaders', () {
      expect(
        LiveShaderSources.gradient(GradientStyle.aurora, darkPalette),
        isNot(LiveShaderSources.gradient(GradientStyle.aurora, lightPalette)),
      );
    });

    test('every template placeholder is a known one', () {
      for (final GradientStyle style in GradientStyle.values) {
        final Iterable<String> found = RegExp(
          r'\{\{[A-Z0-9]+\}\}',
        ).allMatches(LiveShaderSources.gradientTemplate(style)).map((match) => match.group(0)!);
        expect(LiveShaderSources.placeholders, containsAll(found));
      }
    });

    test('the starfield stays pure black whatever the theme', () {
      final String shader = LiveShaderSources.gradient(GradientStyle.starfield, lightPalette);
      expect(shader, contains('vec3 col = vec3(0.0);'));
      expect(shader.contains('col = bg'), isFalse);
    });
  });

  group('palette', () {
    test('has four colours and a background that follows the theme', () {
      expect(darkPalette.colors, hasLength(4));
      expect(darkPalette.background.computeLuminance(), lessThan(0.05));
      expect(lightPalette.background.computeLuminance(), greaterThan(0.7));
    });
  });
}
