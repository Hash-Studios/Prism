import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final _KotlinToolchain? kotlin = _KotlinToolchain.find();
  test(
    'Android hands off distinct immutable files and rejects cache escapes',
    () async {
      final Directory fixture = Directory.systemTemp.createTempSync('prism_android_share_');
      addTearDown(() => fixture.deleteSync(recursive: true));
      for (final MapEntry<String, String> source in _kotlinSources.entries) {
        File('${fixture.path}/${source.key}').writeAsStringSync(source.value);
      }
      final String output = '${fixture.path}/classes';
      final ProcessResult compile = await Process.run(kotlin!.java, <String>[
        '-cp',
        kotlin.classPath,
        'org.jetbrains.kotlin.cli.jvm.K2JVMCompiler',
        '-no-stdlib',
        '-no-reflect',
        '-classpath',
        kotlin.classPath,
        '-d',
        output,
        'android/app/src/main/kotlin/com/hash/prism/PrismShareHostApiImpl.kt',
        for (final String name in _kotlinSources.keys) '${fixture.path}/$name',
      ]);
      expect(compile.exitCode, 0, reason: '${compile.stdout}\n${compile.stderr}');
      final ProcessResult run = await Process.run(kotlin.java, <String>[
        '-cp',
        '$output${Platform.isWindows ? ';' : ':'}${kotlin.classPath}',
        'com.hash.prism.ShareChecksKt',
        fixture.path,
      ]);
      expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
      expect((run.stdout as String).trim(), 'distinct immutable handoffs and failure cleanup passed');
    },
    skip: kotlin == null
        ? 'Needs an existing Java runtime and cached project Kotlin compiler; never installs either.'
        : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('iOS shares cache and temp cards but rejects canonical paths outside those roots', () async {
    final Directory fixture = Directory.systemTemp.createTempSync('prism_native_share_');
    addTearDown(() => fixture.deleteSync(recursive: true));
    for (final String name in <String>['cache', 'temp', 'outside', 'cache_sibling']) {
      Directory('${fixture.path}/$name').createSync();
      File('${fixture.path}/$name/card.png').writeAsBytesSync(<int>[137, 80, 78, 71]);
    }
    Link('${fixture.path}/cache/escape.png').createSync('${fixture.path}/outside/card.png');
    Link('${fixture.path}/cache/inside.png').createSync('${fixture.path}/cache/card.png');
    final String implementation = File(
      'ios/Runner/PrismShareHostApiImpl.swift',
    ).readAsStringSync().replaceFirst('import UIKit', 'import Foundation');
    final File harness = File('${fixture.path}/share_contract.swift')
      ..writeAsStringSync('$_swiftStubs\n$implementation\n$_swiftChecks');

    final ProcessResult result = await Process.run(
      'swift',
      <String>[harness.path],
      environment: <String, String>{'PRISM_SHARE_FIXTURE': fixture.path},
    );
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    final List<Object?> rows = jsonDecode(result.stdout as String) as List<Object?>;
    final Map<String, Map<String, Object?>> results = <String, Map<String, Object?>>{
      for (final Map<String, Object?> row in rows.cast<Map<String, Object?>>()) row['name']! as String: row,
    };
    for (final String name in <String>['cache/card.png', 'temp/card.png', 'cache/inside.png']) {
      expect(results[name], <String, Object?>{
        'name': name,
        'result': true,
        'bytes': <int>[137, 80, 78, 71],
        'key': 'com.instagram.sharedSticker.backgroundImage',
        'expiresInFiveMinutes': true,
        'url': 'instagram-stories://share?source_application=123',
      });
    }
    for (final String name in <String>[
      'outside/card.png',
      'cache_sibling/card.png',
      'cache/../outside/card.png',
      'cache/escape.png',
      'cache/missing.png',
      'cache',
    ]) {
      expect(results[name], <String, Object?>{'name': name, 'result': false});
    }
  }, skip: !Platform.isMacOS ? 'The native regression needs the installed macOS Swift toolchain.' : false);
}

class _KotlinToolchain {
  const _KotlinToolchain(this.java, this.classPath);
  final String java;
  final String classPath;

  static _KotlinToolchain? find() {
    final String? userDirectory = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (userDirectory == null) return null;
    final String gradle = Platform.environment['GRADLE_USER_HOME'] ?? '$userDirectory/.gradle';
    final String cache = '$gradle/caches/modules-2/files-2.1';
    final String settings = File('android/settings.gradle').readAsStringSync();
    final String? version = RegExp('org.jetbrains.kotlin.android" version "([^"]+)"').firstMatch(settings)?.group(1);
    if (version == null) return null;
    final List<String> jars = <String>[];
    for (final String artifact in <String>[
      'org.jetbrains.kotlin/kotlin-compiler-embeddable/$version',
      'org.jetbrains.kotlin/kotlin-stdlib/$version',
      'org.jetbrains.kotlin/kotlin-script-runtime/$version',
      'org.jetbrains.kotlin/kotlin-daemon-embeddable/$version',
      'org.jetbrains.kotlin/kotlin-reflect/1.6.10',
      'org.jetbrains.kotlinx/kotlinx-coroutines-core-jvm/1.8.0',
      'org.jetbrains/annotations/13.0',
    ]) {
      final Directory directory = Directory('$cache/$artifact');
      if (!directory.existsSync()) return null;
      final List<File> matches = directory
          .listSync(recursive: true)
          .whereType<File>()
          .where((File f) => f.path.endsWith('.jar'))
          .toList();
      if (matches.isEmpty) return null;
      jars.add(matches.first.path);
    }
    final String? javaDirectory = Platform.environment['JAVA_HOME'];
    final List<String> candidates = <String>[
      if (javaDirectory != null) '$javaDirectory/bin/java',
      if (Platform.isMacOS) '/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/java',
      '/usr/bin/java',
    ];
    final String? java = candidates.where((String path) => File(path).existsSync()).firstOrNull;
    if (java == null) return null;
    return _KotlinToolchain(java, jars.join(Platform.isWindows ? ';' : ':'));
  }
}

const Map<String, String> _kotlinSources = <String, String>{
  'Activity.kt': '''
package android.app
import android.content.Intent
import java.io.File
class PackageManager {
  var installed = true
  fun resolveActivity(intent: Intent, flags: Int): Any? = if (installed) Any() else null
}
class Activity(val cacheDir: File) {
  val packageManager = PackageManager()
  val packageName = "com.hash.prism"
  val launched = mutableListOf<Intent>()
  val grants = mutableListOf<Pair<String, File>>()
  var throwOnStart = false
  fun grantUriPermission(target: String, uri: File, flags: Int) { grants.add(target to uri) }
  fun revokeUriPermission(uri: File, flags: Int) { grants.removeAll { it.second == uri } }
  fun startActivityForResult(intent: Intent, request: Int) {
    if (throwOnStart) throw IllegalStateException("launch failed")
    launched.add(intent)
  }
}
''',
  'Intent.kt': '''
package android.content
import java.io.File
class Intent(val action: String) {
  var targetPackage: String? = null
  var mime: String? = null
  var data: File? = null
  var flags = 0
  val extras = mutableMapOf<String, String>()
  fun setPackage(value: String) = apply { targetPackage = value }
  fun setType(value: String) = apply { mime = value }
  fun setDataAndType(uri: File, value: String) = apply { data = uri; mime = value }
  fun addFlags(value: Int) = apply { flags = flags or value }
  fun putExtra(key: String, value: String) = apply { extras[key] = value }
  companion object { const val FLAG_GRANT_READ_URI_PERMISSION = 1 }
}
''',
  'FileProvider.kt': '''
package androidx.core.content
import android.app.Activity
import java.io.File
object FileProvider {
  fun getUriForFile(activity: Activity, authority: String, file: File): File {
    check(authority == "com.hash.prism.wallpaper_crop")
    check(file.canonicalPath.startsWith(File(activity.cacheDir, "share_cards").canonicalPath + File.separator))
    return file.canonicalFile
  }
}
''',
  'Api.kt': '''
package com.hash.prism.pigeon
data class InstagramStoryTarget(
  val appId: String = "123",
  val androidAction: String = "com.instagram.share.ADD_TO_STORY",
  val androidPackage: String = "com.instagram.android",
  val androidAppIdExtra: String = "source_application",
  val mimeType: String = "image/png"
)
interface PrismShareHostApi {
  fun canShareInstagramStory(target: InstagramStoryTarget): Boolean
  fun shareInstagramStory(target: InstagramStoryTarget, imagePath: String, callback: (Result<Boolean>) -> Unit)
}
''',
  'ShareChecks.kt': r'''
package com.hash.prism
import android.app.Activity
import com.hash.prism.pigeon.InstagramStoryTarget
import java.io.File
import java.nio.file.Files
fun main(args: Array<String>) {
  val root = File(args[0])
  val cache = File(root, "cache").apply { mkdirs() }
  val first = File(cache, "first.png").apply { writeText("first-image") }
  val second = File(cache, "second.png").apply { writeText("second-image") }
  val activity = Activity(cache)
  val host = PrismShareHostApiImpl(activity)
  val target = InstagramStoryTarget()
  fun share(file: File): Boolean {
    var answer: Boolean? = null
    host.shareInstagramStory(target, file.path) { answer = it.getOrThrow() }
    return answer ?: error("missing completion")
  }
  check(host.canShareInstagramStory(target))
  check(share(first))
  val firstUri = activity.launched.single().data!!
  check(firstUri.readText() == "first-image")
  check(share(second))
  val secondUri = activity.launched.last().data!!
  check(firstUri != secondUri) { "second share reused the earlier content URI" }
  check(firstUri.readText() == "first-image") { "second share changed the earlier payload" }
  check(secondUri.readText() == "second-image")
  for (intent in activity.launched) {
    check(intent.action == "com.instagram.share.ADD_TO_STORY")
    check(intent.targetPackage == "com.instagram.android")
    check(intent.mime == "image/png")
    check(intent.flags == 1)
    check(intent.extras == mapOf("source_application" to "123"))
  }
  check(activity.grants == listOf("com.instagram.android" to firstUri, "com.instagram.android" to secondUri))
  val outside = File(root, "outside.png").apply { writeText("outside") }
  val sibling = File(root, "cache_sibling/card.png").apply { parentFile.mkdirs(); writeText("sibling") }
  val link = File(cache, "escape.png")
  Files.createSymbolicLink(link.toPath(), outside.toPath())
  for (file in listOf(outside, sibling, File(cache, "../outside.png"), link, cache, File(cache, "missing.png"))) {
    check(!share(file)) { "shared invalid source: $file" }
  }
  check(activity.launched.size == 2)
  activity.packageManager.installed = false
  check(!host.canShareInstagramStory(target))
  val cards = File(cache, "share_cards")
  val successfulCopies = cards.listFiles()!!.toSet()
  check(!share(first))
  check(cards.listFiles()!!.toSet() == successfulCopies) { "unavailable target left a failed share copy" }
  check(activity.launched.size == 2)
  activity.packageManager.installed = true
  activity.throwOnStart = true
  val grantsBeforeFailure = activity.grants.toList()
  check(!share(first))
  check(cards.listFiles()!!.toSet() == successfulCopies) { "failed launch left a failed share copy" }
  check(activity.grants == grantsBeforeFailure) { "failed launch left a stale URI grant" }
  println("distinct immutable handoffs and failure cleanup passed")
}
''',
};

// Replace only the platform boundary. The production host, Foundation URL
// canonicalization and filesystem reads execute unchanged in the Swift process.
const String _swiftStubs = '''
import Foundation

let fixtureRoot = ProcessInfo.processInfo.environment["PRISM_SHARE_FIXTURE"]!
func NSTemporaryDirectory() -> String { fixtureRoot + "/temp/" }
final class FileManager {
  static let `default` = FileManager()
  func urls(for directory: Foundation.FileManager.SearchPathDirectory,
            in domain: Foundation.FileManager.SearchPathDomainMask) -> [URL] {
    precondition(directory == .cachesDirectory && domain == .userDomainMask)
    return [URL(fileURLWithPath: fixtureRoot + "/cache/", isDirectory: true)]
  }
}
struct InstagramStoryTarget {
  let iosUrl = "instagram-stories://share?source_application=123"
  let iosPasteboardKey = "com.instagram.sharedSticker.backgroundImage"
}
protocol PrismShareHostApi {
  func canShareInstagramStory(target: InstagramStoryTarget) throws -> Bool
  func shareInstagramStory(target: InstagramStoryTarget, imagePath: String,
                          completion: @escaping (Result<Bool, Error>) -> Void)
}
final class UIApplication {
  static let shared = UIApplication()
  var openedURL: String?
  func canOpenURL(_ url: URL) -> Bool { true }
  func open(_ url: URL, options: [String: Any], completionHandler: (Bool) -> Void) {
    openedURL = url.absoluteString
    completionHandler(true)
  }
}
final class UIPasteboard {
  enum OptionsKey { case expirationDate }
  static let general = UIPasteboard()
  var items: [[String: Data]] = []
  var expiresInFiveMinutes = false
  func setItems(_ items: [[String: Data]], options: [OptionsKey: Any]) {
    self.items = items
    let remaining = (options[.expirationDate] as? Date)?.timeIntervalSinceNow ?? 0
    expiresInFiveMinutes = remaining > 295 && remaining <= 300
  }
}
''';

const String _swiftChecks = r'''
@MainActor
func checkShares() throws {
  let host = PrismShareHostApiImpl()
  var rows: [[String: Any]] = []
  for name in ["cache/card.png", "temp/card.png", "cache/inside.png",
               "outside/card.png", "cache_sibling/card.png", "cache/../outside/card.png",
               "cache/escape.png", "cache/missing.png", "cache"] {
    UIPasteboard.general.items = []
    UIApplication.shared.openedURL = nil
    var answer: Bool?
    host.shareInstagramStory(target: InstagramStoryTarget(), imagePath: fixtureRoot + "/" + name) {
      answer = try! $0.get()
    }
    var row: [String: Any] = ["name": name, "result": answer as Any]
    if let item = UIPasteboard.general.items.first, let key = item.keys.first {
      row["bytes"] = Array(item[key]!)
      row["key"] = key
      row["expiresInFiveMinutes"] = UIPasteboard.general.expiresInFiveMinutes
    }
    if let url = UIApplication.shared.openedURL { row["url"] = url }
    rows.append(row)
  }
  let data = try JSONSerialization.data(withJSONObject: rows, options: [.sortedKeys])
  print(String(data: data, encoding: .utf8)!)
}
try await checkShares()
''';
