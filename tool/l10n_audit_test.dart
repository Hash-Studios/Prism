import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _dartExecutablePath() {
  final List<String> roots = <String>[];
  final String? flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) roots.add(flutterRoot);
  Directory root = File(Platform.resolvedExecutable).parent;
  while (root.parent.path != root.path) {
    roots.add(root.path);
    root = root.parent;
  }

  final String executable = Platform.isWindows ? 'dart.exe' : 'dart';
  for (final String candidateRoot in roots) {
    final File candidate = File('$candidateRoot/bin/cache/dart-sdk/bin/$executable');
    if (candidate.existsSync()) return candidate.path;
  }
  throw StateError('Could not find the Dart SDK next to the Flutter test runtime.');
}

Future<ProcessResult> _runL10nAudit(Directory project) => Process.run(_dartExecutablePath(), <String>[
  'run',
  '${Directory.current.path}/tool/l10n_audit.dart',
  '--root',
  project.path,
  '--check',
]);

void main() {
  test('fails the guard for malformed source without UI findings', () async {
    final Directory project = await Directory.systemTemp.createTemp('l10n-audit-invalid-');
    addTearDown(() => project.delete(recursive: true));
    await File('${project.path}/pubspec.yaml').writeAsString('name: audit_fixture\n');
    final Directory lib = Directory('${project.path}/lib')..createSync();
    await File('${lib.path}/broken.dart').writeAsString('void broken( {');
    final ProcessResult result = await _runL10nAudit(project);
    final Map<String, dynamic> report = jsonDecode(result.stdout as String) as Map<String, dynamic>;
    expect(result.exitCode, 1);
    expect(report['probableUiCount'], 0);
    expect(report['parseErrorCount'], greaterThan(0));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('reports UI text and inventories interpolated, adjacent, and indirect strings', () async {
    final Directory project = await Directory.systemTemp.createTemp('l10n-audit-');
    addTearDown(() => project.delete(recursive: true));
    await File('${project.path}/pubspec.yaml').writeAsString('name: audit_fixture\n');
    final Directory lib = Directory('${project.path}/lib')..createSync();
    await File('${lib.path}/sample.dart').writeAsString('''
void sampleDefault({String dismissLabel = 'Maybe later'}) {}
void sample(String name) {
  Text('Hello');
  Text('Welcome \$name');
  const PrismButton(label: 'Save');
  const ApiResult(message: 'session_changed');
  debugPrint('request finished');
  toasts.error('Could not save');
  Text(data['recordKey']);
  Text(name == 'protocolValue' ? name : name);
  AndroidNotificationDetails('downloads', 'Download status');
  showPrismConfirm(context, message: 'This cannot be undone');
  PagedChipSliver(failureTitle: 'Could not load', emptyTitle: 'No posts', emptyBody: 'Come back later');
  BottomBar(iconTooltip: 'Scroll to top');
  Text('123');
  Text('…');
  showDialog(builder: (context) => AlertDialog(
    title: Text('Dialog copy'),
    onPressed: () => navigate('route-key'),
  ));
  final String joined = 'one ' 'two';
}
''');
    final Directory localization = Directory('${lib.path}/l10n')..createSync();
    await File(
      '${localization.path}/app_localizations.dart',
    ).writeAsString("String get greeting => 'Generated localized copy';\n");

    final ProcessResult result = await _runL10nAudit(project);

    expect(result.exitCode, 1);
    final Map<String, dynamic> report = jsonDecode(result.stdout as String) as Map<String, dynamic>;
    final List<dynamic> findings = report['findings'] as List<dynamic>;
    final Map<String, String> classifications = <String, String>{
      for (final dynamic finding in findings)
        (finding as Map<String, dynamic>)['literal'] as String: finding['classification'] as String,
    };

    expect(classifications['Maybe later'], 'probable_ui');
    expect(classifications['Hello'], 'probable_ui', reason: result.stdout as String);
    expect(classifications[r"'Welcome $name'"], 'probable_ui');
    expect(classifications['Save'], 'probable_ui');
    expect(classifications['Could not save'], 'probable_ui');
    expect(classifications['recordKey'], isNot('probable_ui'));
    expect(classifications['protocolValue'], isNot('probable_ui'));
    expect(classifications['Download status'], 'probable_ui');
    expect(classifications['This cannot be undone'], 'probable_ui');
    expect(classifications['Could not load'], 'probable_ui');
    expect(classifications['No posts'], 'probable_ui');
    expect(classifications['Come back later'], 'probable_ui');
    expect(classifications['Scroll to top'], 'probable_ui');
    expect(classifications['downloads'], isNot('probable_ui'));
    expect(classifications['123'], 'review');
    expect(classifications['…'], 'review');
    expect(classifications['session_changed'], 'review');
    expect(classifications['request finished'], 'non_ui');
    expect(classifications['route-key'], 'review');
    expect(classifications.containsKey("'one ' 'two'"), isTrue);
    expect(classifications['Dialog copy'], 'probable_ui');
    expect(classifications.containsKey('Generated localized copy'), isFalse);
  }, timeout: const Timeout(Duration(minutes: 2)));
}
