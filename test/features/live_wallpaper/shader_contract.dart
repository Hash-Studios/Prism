/// Dart mirror of the checks in `ShaderProgramValidator.kt` (async_wallpaper 3.3.0).
List<String> validateShaderContract(String shader, {required int textureCount}) {
  final List<String> problems = <String>[];
  if (shader.codeUnits.length > 64 * 1024) problems.add('shader is larger than 64 KiB');

  final String source = _stripComments(shader);
  if (!RegExp(r'\bvoid\s+main\s*\(\s*\)').hasMatch(source)) problems.add('missing void main()');

  for (final RegExpMatch match in RegExp(
    r'^[\t ]*#\s*([A-Za-z_][A-Za-z0-9_]*)\b(.*)$',
    multiLine: true,
  ).allMatches(source)) {
    final String name = match.group(1)!.toLowerCase();
    if (name == 'version') {
      if (match.group(2)!.trim() != '100') problems.add('unsupported #version');
    } else if (!<String>{'define', 'if', 'ifdef', 'ifndef', 'elif', 'else', 'endif'}.contains(name)) {
      problems.add('unsupported directive #$name');
    }
  }

  if (RegExp(
    r'\b(?:samplerExternalOES|sampler2DArray|sampler3D|samplerCube|image[A-Za-z0-9_]*|atomic[A-Za-z0-9_]*|layout|buffer|shared|coherent|readonly|writeonly|gl_FragData|gl_FragDepth|gl_InstanceID|gl_VertexID|texelFetch|textureLod|textureGrad|textureOffset|dFdx|dFdy|fwidth)\b',
  ).hasMatch(source)) {
    problems.add('forbidden construct');
  }
  if (RegExp(r'\b(?:while|do)\b').hasMatch(source)) problems.add('while or do loop');

  final RegExp staticFor = RegExp(
    r'(?:int|float)\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(-?\d+)\s*;\s*\1\s*(<=|<|>=|>)\s*(-?\d+)\s*;\s*((?:\1\s*(?:\+\+|--|\+=\s*\d+|-=\s*\d+))|(?:(?:\+\+|--)\s*\1))',
  );
  for (final RegExpMatch start in RegExp(r'\bfor\s*\(').allMatches(source)) {
    final int open = source.indexOf('(', start.start);
    final int close = _matchingParenthesis(source, open);
    if (close < 0) {
      problems.add('incomplete for header');
      continue;
    }
    final String header = source.substring(open + 1, close).trim();
    final RegExpMatch? parsed = staticFor.firstMatch(header);
    if (parsed == null || parsed.start != 0 || parsed.end != header.length) {
      problems.add('dynamic for loop: $header');
      continue;
    }
    final int initial = int.parse(parsed.group(2)!);
    final int bound = int.parse(parsed.group(4)!);
    final String comparison = parsed.group(3)!;
    final String update = parsed.group(5)!;
    final int step = update.contains('++')
        ? 1
        : update.contains('--')
        ? -1
        : 0;
    final int iterations = switch (comparison) {
      '<' when step > 0 => initial >= bound ? 0 : ((bound - initial - 1) ~/ step) + 1,
      '<=' when step > 0 => initial > bound ? 0 : ((bound - initial) ~/ step) + 1,
      _ => -1,
    };
    if (iterations < 0) problems.add('for loop makes no progress: $header');
    if (iterations > 128) problems.add('for loop runs more than 128 times');
  }

  const Map<String, int> componentCost = <String, int>{
    'bool': 1,
    'int': 1,
    'float': 1,
    'vec2': 2,
    'vec3': 3,
    'vec4': 4,
    'mat2': 4,
    'mat3': 9,
    'mat4': 16,
    'sampler2D': 1,
  };
  const Map<String, String> rendererTypes = <String, String>{
    'u_time': 'float',
    'u_resolution': 'vec2',
    'u_touch': 'vec2',
    'u_offset': 'vec2',
  };
  int declarations = 0;
  int components = 0;
  for (final RegExpMatch statement in RegExp(r'\buniform\b([^;]*);').allMatches(source)) {
    final RegExpMatch? declaration = RegExp(
      r'^(?:(?:lowp|mediump|highp)\s+)?([A-Za-z_][A-Za-z0-9_]*)\s+([A-Za-z_][A-Za-z0-9_]*)(?:\s*\[\s*(\d+)\s*])?$',
    ).firstMatch(statement.group(1)!.trim());
    if (declaration == null) {
      problems.add('invalid uniform: ${statement.group(1)}');
      continue;
    }
    declarations++;
    final String type = declaration.group(1)!;
    final String name = declaration.group(2)!;
    final int length = int.tryParse(declaration.group(3) ?? '1') ?? 1;
    if (length < 1 || length > 16) problems.add('uniform array too large');
    final int? cost = componentCost[type];
    if (cost == null) {
      problems.add('unsupported uniform type $type');
    } else {
      components += cost * length;
    }
    final String? expected = rendererTypes[name];
    if (expected != null && (type != expected || length != 1)) problems.add('$name must be $expected');
    if (type.startsWith('sampler')) {
      final RegExpMatch? texture = RegExp(r'^u_texture([0-3])$').firstMatch(name);
      if (texture == null || type != 'sampler2D') {
        problems.add('unsupported sampler $name');
      } else if (int.parse(texture.group(1)!) >= textureCount) {
        problems.add('$name has no texture');
      }
    } else if (expected == null) {
      problems.add('unknown uniform $name');
    }
  }
  if (declarations > 32) problems.add('too many uniform declarations');
  if (components > 64) problems.add('uniforms exceed 64 components');

  if (!shader.contains('precision mediump float;')) problems.add('missing precision mediump float;');
  if (shader.contains('{{')) problems.add('unreplaced placeholder');
  if (_count(source, '{') != _count(source, '}')) problems.add('unbalanced braces');
  if (_count(source, '(') != _count(source, ')')) problems.add('unbalanced parentheses');
  return problems;
}

int _count(String source, String char) => char.allMatches(source).length;

int _matchingParenthesis(String source, int open) {
  if (open < 0) return -1;
  int depth = 0;
  for (int index = open; index < source.length; index++) {
    if (source[index] == '(') depth++;
    if (source[index] == ')') {
      depth--;
      if (depth == 0) return index;
    }
  }
  return -1;
}

String _stripComments(String source) {
  final StringBuffer out = StringBuffer();
  int i = 0;
  while (i < source.length) {
    if (source[i] == '/' && i + 1 < source.length && source[i + 1] == '/') {
      while (i < source.length && source[i] != '\n') {
        out.write(' ');
        i++;
      }
      continue;
    }
    if (source[i] == '/' && i + 1 < source.length && source[i + 1] == '*') {
      i += 2;
      while (i + 1 < source.length && !(source[i] == '*' && source[i + 1] == '/')) {
        out.write(source[i] == '\n' ? '\n' : ' ');
        i++;
      }
      i += 2;
      continue;
    }
    out.write(source[i]);
    i++;
  }
  return out.toString();
}
