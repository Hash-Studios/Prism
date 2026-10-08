import 'dart:async';
import 'dart:io';

import 'package:Prism/core/monitoring/sentry_before_send.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class ClientException implements Exception {}

void main() {
  SentryEvent? filter(Object? error) => dropNetworkNoise(SentryEvent(throwable: error), Hint());

  test('drops socket, timeout, handshake, http client and Firestore unavailable errors', () {
    expect(filter(const SocketException('no route')), isNull);
    expect(filter(TimeoutException('slow')), isNull);
    expect(filter(const HandshakeException('tls')), isNull);
    expect(filter(ClientException()), isNull);
    expect(filter(FirebaseException(plugin: 'cloud_firestore', code: 'unavailable')), isNull);
  });

  test('keeps real bugs and other Firestore errors', () {
    expect(filter(StateError('bug')), isNotNull);
    expect(filter(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied')), isNotNull);
    expect(filter(null), isNotNull);
  });

  test('drops an event with only network exception types and no throwable', () {
    final event = SentryEvent(
      exceptions: <SentryException>[SentryException(type: 'SocketException', value: 'x')],
    );

    expect(dropNetworkNoise(event, Hint()), isNull);
  });
}
