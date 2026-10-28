import 'dart:async';

import 'package:Prism/core/updates/code_push_updater.dart';

class FakeCodePushUpdater implements CodePushUpdater {
  @override
  bool isAvailable = true;
  int? current;
  int? next;
  CodePushStatus status = CodePushStatus.upToDate;
  int? nextAfterDownload;
  Object? checkError;
  Object? downloadError;
  Completer<void>? checkGate;
  Completer<void>? downloadGate;
  Completer<void>? currentGate;
  Completer<void>? nextGate;
  int currentCalls = 0;
  int nextCalls = 0;
  int checkCalls = 0;
  int downloadCalls = 0;
  bool nextIsNull = false;

  @override
  Future<int?> currentPatchNumber() async {
    currentCalls++;
    await currentGate?.future;
    return current;
  }

  @override
  Future<int?> nextPatchNumber() async {
    nextCalls++;
    await nextGate?.future;
    return nextIsNull ? null : (next ?? current);
  }

  @override
  Future<CodePushStatus> checkForUpdate() async {
    checkCalls++;
    await checkGate?.future;
    if (checkError != null) throw checkError!;
    return status;
  }

  @override
  Future<void> downloadUpdate() async {
    downloadCalls++;
    await downloadGate?.future;
    if (downloadError != null) throw downloadError!;
    next = nextAfterDownload;
  }
}
