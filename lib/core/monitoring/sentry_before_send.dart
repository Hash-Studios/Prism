import 'dart:async';
import 'dart:io';

import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

const Set<String> _networkNoiseTypeNames = <String>{
  'SocketException',
  'ClientException',
  'TimeoutException',
  'HandshakeException',
};

const Set<String> _networkNoiseFirebaseCodes = <String>{'unavailable', 'deadline-exceeded', 'network-request-failed'};

bool isNetworkNoise(Object? error) {
  if (error == null) {
    return false;
  }
  if (error is FirestoreError) {
    return isNetworkNoise(error.original);
  }
  if (error is SocketException ||
      error is TimeoutException ||
      error is HandshakeException ||
      error is HttpException ||
      error is TlsException) {
    return true;
  }
  // Covers FirebaseAuthException and FirebaseFunctionsException, which extend FirebaseException.
  if (error is FirebaseException) {
    return _networkNoiseFirebaseCodes.contains(error.code);
  }
  return _networkNoiseTypeNames.contains(error.runtimeType.toString());
}

/// Drops errors that come from a weak or missing connection. The user can do nothing about them.
SentryEvent? dropNetworkNoise(SentryEvent event, Hint hint) {
  if (isNetworkNoise(event.throwable)) {
    return null;
  }
  final List<SentryException>? exceptions = event.exceptions;
  if (exceptions != null && exceptions.isNotEmpty && exceptions.every((e) => _networkNoiseTypeNames.contains(e.type))) {
    return null;
  }
  return event;
}

/// The iOS SDK reports every 5xx that any native SDK gets, for example a Remote Config fetch or an FCM topic call,
/// and those events skip [dropNetworkNoise]. The SDKs already retry or fall back, and our own native downloads check
/// the status code themselves, so these reports are noise.
void applyNetworkNoiseFilters(SentryFlutterOptions options) {
  options.beforeSend = dropNetworkNoise;
  options.captureNativeFailedRequests = false;
}
