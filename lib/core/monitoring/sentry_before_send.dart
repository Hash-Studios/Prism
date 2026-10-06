import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

const Set<String> _networkNoiseTypeNames = <String>{
  'SocketException',
  'ClientException',
  'TimeoutException',
  'HandshakeException',
};

bool isNetworkNoise(Object? error) {
  if (error == null) {
    return false;
  }
  if (error is SocketException || error is TimeoutException || error is HandshakeException) {
    return true;
  }
  if (error is FirebaseException) {
    return error.code == 'unavailable';
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
