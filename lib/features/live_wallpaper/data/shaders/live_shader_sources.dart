import 'dart:ui' show Color;

import 'package:Prism/features/live_wallpaper/domain/entities/live_palette.dart';
import 'package:Prism/features/live_wallpaper/domain/entities/live_style.dart';

/// Fragment shaders for the OpenGL live wallpaper renderer in `async_wallpaper`.
///
/// Rules these sources follow (see `ShaderProgramValidator.kt`): GLSL ES 1.00, only the renderer
/// uniforms `u_time`, `u_resolution`, `u_touch`, `u_offset` and `u_texture0`, no `while` loops,
/// only `for` loops with integer literal bounds, and under 64 KiB.
///
/// Colours are templated as `vec3` constants. Every time-based phase uses a multiple of 0.1 rad/s
/// on `loopTime()`, so the animation repeats cleanly when the clock wraps and `mediump` devices
/// never lose precision on a long-running wallpaper.
// ignore: avoid_classes_with_only_static_members
abstract final class LiveShaderSources {
  static const int maxBytes = 64 * 1024;

  static const List<String> placeholders = <String>['{{C0}}', '{{C1}}', '{{C2}}', '{{C3}}', '{{BG}}'];

  static const Set<String> allowedUniforms = <String>{'u_time', 'u_resolution', 'u_touch', 'u_offset', 'u_texture0'};

  static const String _header = '''
precision mediump float;
#ifdef GL_FRAGMENT_PRECISION_HIGH
#define HP highp
uniform highp float u_time;
#else
#define HP mediump
uniform mediump float u_time;
#endif
uniform vec2 u_resolution;
uniform vec2 u_touch;
uniform vec2 u_offset;
varying vec2 v_uv;

float loopTime() {
  return mod(u_time, 62.831853);
}

float grain() {
  HP vec2 p = gl_FragCoord.xy;
  return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
}
''';

  static const String _colors = '''
const vec3 c0 = {{C0}};
const vec3 c1 = {{C1}};
const vec3 c2 = {{C2}};
const vec3 c3 = {{C3}};
const vec3 bg = {{BG}};
''';

  static const String _textureHeader = '''
uniform sampler2D u_texture0;

vec4 samplePhoto(vec2 uv) {
  return texture2D(u_texture0, vec2(uv.x, 1.0 - uv.y));
}
''';

  static const String _aurora = '''
void main() {
  vec2 uv = v_uv;
  float t = loopTime();
  float aspect = u_resolution.x / u_resolution.y;
  float shift = (u_offset.x - 0.5) * 0.3;
  vec3 col = mix(bg * 0.6, bg, uv.y) + c0 * 0.05 * (1.0 - uv.y);
  for (int i = 0; i < 3; i++) {
    float fi = float(i);
    float wave = sin(uv.x * aspect * (1.6 + fi * 0.7) + shift + t * (0.3 + fi * 0.1) + fi * 1.7) * 0.08
      + sin(uv.x * aspect * (3.1 + fi) - t * 0.2 + fi) * 0.035;
    float centre = 0.62 + fi * 0.1 + wave;
    float d = uv.y - centre;
    float falloff = d > 0.0 ? 9.0 : 3.5;
    float band = exp(-d * d * falloff * (14.0 - fi * 2.0));
    vec3 tint = i == 0 ? c0 : (i == 1 ? c1 : c2);
    col += tint * band * (0.55 - fi * 0.08);
  }
  col *= 1.0 - 0.35 * distance(uv, vec2(0.5, 0.55));
  gl_FragColor = vec4(clamp(col + grain() / 255.0, 0.0, 1.0), 1.0);
}
''';

  static const String _mesh = '''
void main() {
  vec2 uv = v_uv;
  float t = loopTime();
  float aspect = u_resolution.x / u_resolution.y;
  vec2 p = vec2(uv.x * aspect, uv.y);
  vec2 par = vec2((u_offset.x - 0.5) * 0.2, 0.0);
  vec2 q0 = vec2(0.25 * aspect + 0.22 * sin(t * 0.3), 0.8 + 0.1 * cos(t * 0.4)) + par;
  vec2 q1 = vec2(0.8 * aspect + 0.2 * cos(t * 0.3), 0.7 + 0.12 * sin(t * 0.5)) + par;
  vec2 q2 = vec2(0.3 * aspect + 0.25 * cos(t * 0.4), 0.25 + 0.1 * sin(t * 0.3)) + par;
  vec2 q3 = vec2(0.75 * aspect + 0.18 * sin(t * 0.5), 0.2 + 0.12 * cos(t * 0.3)) + par;
  float w0 = 1.0 / (0.04 + dot(p - q0, p - q0));
  float w1 = 1.0 / (0.04 + dot(p - q1, p - q1));
  float w2 = 1.0 / (0.04 + dot(p - q2, p - q2));
  float w3 = 1.0 / (0.04 + dot(p - q3, p - q3));
  float wb = 0.9;
  vec3 col = (c0 * w0 + c1 * w1 + c2 * w2 + c3 * w3 + bg * wb) / (w0 + w1 + w2 + w3 + wb);
  gl_FragColor = vec4(clamp(col + grain() / 255.0, 0.0, 1.0), 1.0);
}
''';

  static const String _waves = '''
void main() {
  vec2 uv = v_uv;
  float t = loopTime();
  float aspect = u_resolution.x / u_resolution.y;
  float x = uv.x * aspect + (u_offset.x - 0.5) * 0.3;
  vec3 col = mix(bg, c3 * 0.5 + bg * 0.5, uv.y);
  for (int i = 0; i < 4; i++) {
    float fi = float(i);
    float edge = 0.72 - fi * 0.15
      + sin(x * (1.8 + fi * 0.6) + t * (0.3 + fi * 0.1) + fi * 2.1) * (0.045 - fi * 0.006)
      + sin(x * (3.7 + fi) - t * 0.2) * 0.012;
    float fill = smoothstep(edge + 0.012, edge - 0.012, uv.y);
    vec3 tint = i == 0 ? c0 : (i == 1 ? c1 : (i == 2 ? c2 : c3));
    float shade = 0.55 + 0.45 * (1.0 - uv.y);
    col = mix(col, mix(tint * shade, bg, 0.25 + fi * 0.12), fill * 0.9);
  }
  gl_FragColor = vec4(clamp(col + grain() / 255.0, 0.0, 1.0), 1.0);
}
''';

  static const String _plasma = '''
void main() {
  vec2 uv = v_uv;
  float t = loopTime();
  float aspect = u_resolution.x / u_resolution.y;
  vec2 p = vec2(uv.x * aspect + (u_offset.x - 0.5) * 0.2, uv.y);
  float v = sin(p.x * 3.0 + t * 0.5)
    + sin(p.y * 4.0 - t * 0.4)
    + sin((p.x + p.y) * 2.5 + t * 0.3)
    + sin(length(p - vec2(0.5 * aspect, 0.5)) * 5.0 - t * 0.6);
  v = v * 0.125 + 0.5;
  vec3 col = mix(c0, c1, smoothstep(0.15, 0.5, v));
  col = mix(col, c2, smoothstep(0.45, 0.8, v));
  col = mix(col, c3, smoothstep(0.75, 1.0, v) * 0.6);
  col = mix(bg, col, 0.85);
  gl_FragColor = vec4(clamp(col + grain() / 255.0, 0.0, 1.0), 1.0);
}
''';

  static const String _starfield = '''
float hash21(HP vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

void main() {
  vec2 uv = v_uv;
  float t = loopTime();
  float aspect = u_resolution.x / u_resolution.y;
  vec3 col = vec3(0.0);
  for (int i = 0; i < 3; i++) {
    float fi = float(i);
    float scale = 9.0 + fi * 8.0;
    vec2 p = vec2(uv.x * aspect, uv.y);
    p += vec2(sin(t * 0.1 + fi), cos(t * 0.1 + fi * 2.0)) * 0.015 * (fi + 1.0);
    p.x += (u_offset.x - 0.5) * 0.12 * (fi + 1.0);
    vec2 cell = floor(p * scale);
    vec2 local = fract(p * scale);
    float rnd = hash21(cell + fi * 17.0);
    vec2 pos = vec2(0.2 + 0.6 * fract(rnd * 7.0), 0.2 + 0.6 * fract(rnd * 13.0));
    float present = step(0.6, rnd);
    float d = distance(local, pos);
    float speed = 0.5 + floor(rnd * 50.0) * 0.1;
    float twinkle = 0.65 + 0.35 * sin(t * mod(speed, 2.5) + rnd * 40.0);
    float size = 0.07 - fi * 0.015;
    float star = exp(-d * d / (size * size)) * present * twinkle;
    vec3 tint = mix(vec3(1.0), c0, step(0.5, fract(rnd * 31.0)) * 0.55);
    col += tint * star * (0.95 - fi * 0.2);
  }
  gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
''';

  static const String _drift = '''
void main() {
  vec2 uv = v_uv;
  float t = loopTime();
  float zoom = 1.12 + 0.03 * sin(t * 0.1);
  vec2 pan = vec2(sin(t * 0.1), cos(t * 0.2)) * 0.022 + vec2((u_offset.x - 0.5) * 0.03, 0.0);
  vec2 st = (uv - 0.5) / zoom + 0.5 + pan;
  gl_FragColor = vec4(samplePhoto(st).rgb, 1.0);
}
''';

  static const String _breathe = '''
void main() {
  vec2 uv = v_uv;
  float t = loopTime();
  float pulse = sin(t * 0.5);
  float zoom = 1.08 + 0.025 * pulse;
  vec2 st = (uv - 0.5) / zoom + 0.5;
  vec3 col = samplePhoto(st).rgb * (1.0 + 0.035 * pulse);
  gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
''';

  static const String _ripple = '''
void main() {
  vec2 uv = v_uv;
  float t = loopTime();
  float aspect = u_resolution.x / u_resolution.y;
  vec2 touch = vec2(u_touch.x, 1.0 - u_touch.y);
  vec2 d = uv - touch;
  d.x *= aspect;
  float r = length(d);
  vec2 dir = d / max(r, 0.0001);
  dir.x /= aspect;
  float wave = sin(r * 38.0 - t * 4.0);
  float falloff = exp(-r * 3.2);
  vec2 st = (uv - 0.5) / 1.05 + 0.5 + dir * wave * falloff * 0.012;
  vec3 col = samplePhoto(st).rgb + wave * falloff * 0.035;
  gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
''';

  static const String _shimmer = '''
void main() {
  vec2 uv = v_uv;
  float t = loopTime();
  vec2 st = (uv - 0.5) / 1.05 + 0.5 + vec2((u_offset.x - 0.5) * 0.03, 0.0);
  vec3 col = samplePhoto(st).rgb;
  float sweep = fract(t / 12.566371);
  float centre = -0.4 + sweep * 1.8;
  float diag = uv.x * 0.6 + uv.y * 0.8;
  float k = (diag - centre) * 5.0;
  float band = exp(-k * k);
  vec3 glow = mix(vec3(1.0), c0, 0.25) * band * 0.2;
  col = 1.0 - (1.0 - col) * (1.0 - glow);
  gl_FragColor = vec4(clamp(col, 0.0, 1.0), 1.0);
}
''';

  static String gradientTemplate(GradientStyle style) {
    final String body = switch (style) {
      GradientStyle.aurora => _aurora,
      GradientStyle.mesh => _mesh,
      GradientStyle.waves => _waves,
      GradientStyle.plasma => _plasma,
      GradientStyle.starfield => _starfield,
    };
    return '$_header\n$_colors\n$body';
  }

  static String motionTemplate(MotionStyle style) {
    final String body = switch (style) {
      MotionStyle.drift => _drift,
      MotionStyle.breathe => _breathe,
      MotionStyle.ripple => _ripple,
      MotionStyle.shimmer => _shimmer,
    };
    return '$_header\n$_colors\n$_textureHeader\n$body';
  }

  static String gradient(GradientStyle style, LivePalette palette) => applyPalette(gradientTemplate(style), palette);

  static String motion(MotionStyle style, LivePalette palette) => applyPalette(motionTemplate(style), palette);

  static String applyPalette(String template, LivePalette palette) {
    final List<Color> colors = palette.colors;
    return template
        .replaceAll('{{C0}}', vec3Literal(colors[0]))
        .replaceAll('{{C1}}', vec3Literal(colors[1]))
        .replaceAll('{{C2}}', vec3Literal(colors[2]))
        .replaceAll('{{C3}}', vec3Literal(colors[3]))
        .replaceAll('{{BG}}', vec3Literal(palette.background));
  }

  static String vec3Literal(Color color) {
    String channel(double value) => value.clamp(0.0, 1.0).toStringAsFixed(4);
    return 'vec3(${channel(color.r)}, ${channel(color.g)}, ${channel(color.b)})';
  }
}
