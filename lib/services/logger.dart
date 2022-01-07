import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
// import 'package:flutter_archive/flutter_archive.dart';
import 'package:logger/logger.dart';
import 'package:logger_flutter/logger_flutter.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

final printer = PrettyPrinter();
final logger = Logger(
  level: Level.debug,
  printer: printer,
  output: LogConsole.wrap(innerOutput: ConsoleOutput()),
  filter: kDebugMode
      ? PassThroughFilter()
      : PassThroughFilter(), //!ProductionFilter(), Add before final release
);

class PassThroughFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    return true;
  }
}

class LogOutputPrinter extends PrettyPrinter {
  late String _logFolderPath;
  RandomAccessFile? _logFile;

  LogOutputPrinter() {
    getExternalStorageDirectory().then((cacheDir) async {
      if (cacheDir == null) {
        getApplicationDocumentsDirectory().then((cDir) async {
          _logFolderPath = join(cDir.path, "logs");
          try {
            await Directory(_logFolderPath).create();
          } catch (e) {
            // Ignore if it already exists
          }
          await setLogCapture(true);
        });
      } else {
        _logFolderPath = join(cacheDir.path, "logs");
        try {
          await Directory(_logFolderPath).create();
        } catch (e) {
          // Ignore if it already exists
        }
        await setLogCapture(true);
      }
    });
  }

  @override
  List<String> log(LogEvent event) {
    final logMsg = event.message;
    final logLvl = event.level;
    final logStrace = event.stackTrace;
    final logError = event.error;
    final color = PrettyPrinter.levelColors[logLvl];
    final prefix = SimplePrinter.levelPrefixes[logLvl];
    final str =
        "---------------------------------------------------------------------------\nLEVEL : $logLvl\nMESSAGE : ${DateTime.now().toString().substring(11, 22)} :: $logMsg\nERROR : $logError\nSTACKTRACE : $logStrace";
    Future.delayed(const Duration(seconds: 1))
        .then((value) => _logFile?.writeStringSync('$str\n'));
    final timeStr = getTime().substring(0, 12);
    if (logStrace != null) {
      // print(color!('$timeStr $prefix - $logMsg \n$logStrace'));
      developer.log(
        color!('$logMsg \n$logError'),
        name: "$timeStr :: ${prefix!.replaceAll("[", "").replaceAll("]", "")}",
        stackTrace: logStrace,
        level: 2000,
      );
    } else {
      // print(color!('$timeStr $prefix - $logMsg'));
      developer.log(
        color!('$logMsg'),
        name: "$timeStr :: ${prefix!.replaceAll("[", "").replaceAll("]", "")}",
      );
    }
    return [];
  }

  Future<void> setLogCapture(bool state) async {
    if (state) {
      final today = DateTime.now().toString().substring(0, 10);
      final logFilePath = join(_logFolderPath, '$today.txt');
      _logFile = await File(logFilePath).open(mode: FileMode.append);
    } else {
      if (_logFile != null) {
        await _logFile!.close();
      }
      _logFile = null;
    }
  }

  String filePathForDate(DateTime dt) {
    final date = dt.toString().substring(0, 10);
    return join(_logFolderPath, '$date.txt');
  }

  String logsFolderPath() {
    return _logFolderPath;
  }

  List<String> filePathsForDates(int n) {
    final DateTime today = DateTime.now();
    final l = <String>[];
    for (var i = 0; i < n; i++) {
      final String fp = filePathForDate(
        today.subtract(
          Duration(days: i),
        ),
      );
      if (File(fp).existsSync()) {
        l.add(fp);
      } else {
        logger.i("Log file $fp not found");
      }
    }

    return l;
  }

  Iterable<String> fetchLogs() sync* {
    final today = DateTime.now();
    for (final msg in fetchLogsForDate(today)) {
      yield msg;
    }
  }

  Iterable<String> fetchLogsForDate(DateTime date) sync* {
    final file = File(filePathForDate(date));
    if (!file.existsSync()) {
      logger.i("No log file for $date, path = ${file.path}");
      return;
    }

    final str = file.readAsStringSync();
    for (final line in str.split("\n")) {
      yield line;
    }
  }
}

// Future<String> zipLogs() async {
//   logger.v("Zipping Logs");
//   final sourceDir = Directory(printer.logsFolderPath());
//   final files = printer.filePathsForDates(2).map((e) => File(e)).toList();
//   final zipFile = File(join(printer.logsFolderPath(), 'logs.zip'));
//   try {
//     logger.v("Zipping Started");
//     await ZipFile.createFromFiles(
//         sourceDir: sourceDir, files: files, zipFile: zipFile);
//     logger.v("Zipping Finished Successfully");
//     logger.v("Renaming Zip File");
//     await zipFile.rename(join(printer.logsFolderPath(), 'logs'));
//     logger.v("Renaming Done");
//   } catch (e, strace) {
//     logger.e(e, e, strace);
//   }
//   return join(printer.logsFolderPath(), 'logs');
// }
