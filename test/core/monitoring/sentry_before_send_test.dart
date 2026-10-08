import 'dart:async';
import 'dart:io';

import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/monitoring/sentry_before_send.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class ClientException implements Exception {}

class _FunctionsException extends FirebaseFunctionsException {
  _FunctionsException(String code) : super(message: 'failed', code: code);
}

void main() {
  SentryEvent? filter(Object? error) => dropNetworkNoise(SentryEvent(throwable: error), Hint());

  test('drops socket, timeout, handshake, http client and Firestore unavailable errors', () {
    expect(filter(const SocketException('no route')), isNull);
    expect(filter(TimeoutException('slow')), isNull);
    expect(filter(const HandshakeException('tls')), isNull);
    expect(filter(ClientException()), isNull);
    expect(filter(FirebaseException(plugin: 'cloud_firestore', code: 'unavailable')), isNull);
  });

  test('drops deadline, auth network, HTTP, TLS and Cloud Functions network errors', () {
    expect(filter(FirebaseException(plugin: 'cloud_firestore', code: 'deadline-exceeded')), isNull);
    expect(filter(FirebaseAuthException(code: 'network-request-failed')), isNull);
    expect(filter(const HttpException('connection closed')), isNull);
    expect(filter(const TlsException('bad record')), isNull);
    expect(filter(_FunctionsException('unavailable')), isNull);
    expect(filter(_FunctionsException('deadline-exceeded')), isNull);
  });

  test('looks inside a FirestoreError for the network error it wraps', () {
    final wrapped = mapFirestoreError(FirebaseException(plugin: 'cloud_firestore', code: 'unavailable'));
    expect(filter(wrapped), isNull);
    expect(filter(mapFirestoreError(const SocketException('no route'))), isNull);
    expect(
      filter(mapFirestoreError(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'))),
      isNotNull,
    );
    expect(filter(FirestoreError(message: 'no cause')), isNotNull);
  });

  test('keeps real bugs and other Firestore errors', () {
    expect(filter(StateError('bug')), isNotNull);
    expect(filter(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied')), isNotNull);
    expect(filter(_FunctionsException('permission-denied')), isNotNull);
    expect(filter(null), isNotNull);
  });

  test('drops an event with only network exception types and no throwable', () {
    final event = SentryEvent(
      exceptions: <SentryException>[SentryException(type: 'SocketException', value: 'x')],
    );

    expect(dropNetworkNoise(event, Hint()), isNull);
  });
}
