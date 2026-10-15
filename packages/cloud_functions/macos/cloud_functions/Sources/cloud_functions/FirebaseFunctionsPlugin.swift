// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#if canImport(FlutterMacOS)
  import FlutterMacOS
#else
  import Flutter
#endif

#if canImport(firebase_core)
  import firebase_core
#else
  import firebase_core_shared
#endif
import FirebaseFunctions

let kFLTFirebaseFunctionsChannelName = "plugins.flutter.io/firebase_functions"

public final class FirebaseFunctionsPlugin: NSObject, FLTFirebasePluginProtocol, FlutterPlugin,
  CloudFunctionsHostApi {
  func call(arguments: [String: Any?], completion: @escaping (Result<Any?, any Error>) -> Void) {
    httpsFunctionCall(arguments: arguments) { result, error in
      if let error {
        completion(.failure(error))
      } else {
        completion(.success(result))
      }
    }
  }

  func registerEventChannel(arguments: [String: Any],
                            completion: @escaping (Result<Void, any Error>) -> Void) {
    guard let eventChannelId = arguments["eventChannelId"] as? String, !eventChannelId.isEmpty else {
      completion(.failure(functionsArgumentError("eventChannelId must be a non-empty string")))
      return
    }
    let functions: Functions
    do {
      functions = try getFunctions(arguments: arguments)
    } catch {
      completion(.failure(error))
      return
    }
    let eventChannelName = "\(kFLTFirebaseFunctionsChannelName)/\(eventChannelId)"
    let eventChannel = FlutterEventChannel(name: eventChannelName, binaryMessenger: binaryMessenger)
    streams[eventChannelId]?.1.cancel()
    streams[eventChannelId]?.0.setStreamHandler(nil)
    let streamHandler = FunctionsStreamHandler(functions: functions) { [weak self] cancelled in
      guard let current = self?.streams[eventChannelId], current.1 === cancelled else { return }
      self?.streams.removeValue(forKey: eventChannelId)
      current.0.setStreamHandler(nil)
    }
    streams[eventChannelId] = (eventChannel, streamHandler)
    eventChannel.setStreamHandler(streamHandler)
    completion(.success(()))
  }

  private let binaryMessenger: FlutterBinaryMessenger
  private var streams: [String: (FlutterEventChannel, FunctionsStreamHandler)] = [:]

  init(binaryMessenger: FlutterBinaryMessenger) {
    self.binaryMessenger = binaryMessenger
  }

  public func firebaseLibraryVersion() -> String {
    versionNumber
  }

  public func didReinitializeFirebaseCore(_ completion: @escaping () -> Void) {
    completion()
  }

  public func pluginConstants(for firebaseApp: FirebaseApp) -> [AnyHashable: Any] {
    [:]
  }

  @objc public func firebaseLibraryName() -> String {
    "flutter-fire-fn"
  }

  @objc public func flutterChannelName() -> String {
    kFLTFirebaseFunctionsChannelName
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let binaryMessenger: FlutterBinaryMessenger
    #if os(macOS)
      binaryMessenger = registrar.messenger
    #elseif os(iOS)
      binaryMessenger = registrar.messenger()
    #endif

    let instance = FirebaseFunctionsPlugin(binaryMessenger: binaryMessenger)
    registrar.publish(instance)
    CloudFunctionsHostApiSetup.setUp(binaryMessenger: binaryMessenger, api: instance)
  }

  #if os(iOS)
  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    CloudFunctionsHostApiSetup.setUp(binaryMessenger: binaryMessenger, api: nil)
    for (channel, handler) in streams.values {
      handler.cancel()
      channel.setStreamHandler(nil)
    }
    streams.removeAll()
  }
  #endif

  deinit {
    for (_, handler) in streams.values { handler.cancel() }
  }

  private func httpsFunctionCall(arguments: [String: Any?],
                                 completion: @escaping (Any?, FlutterError?) -> Void) {
    do {
      let values = try CallableArguments(arguments)
      let functions = try getFunctions(arguments: arguments)
      if let origin = values.origin, let host = origin.host, let port = origin.port {
        functions.useEmulator(withHost: host, port: port)
      }
      let options = HTTPSCallableOptions(requireLimitedUseAppCheckTokens: values.limitedUseAppCheckToken)
      let function: HTTPSCallable
      switch values.target {
      case let .name(name): function = functions.httpsCallable(name, options: options)
      case let .url(url): function = functions.httpsCallable(url, options: options)
      }
      if let timeout = values.timeout { function.timeoutInterval = timeout }

      // The callback API crashes in the iOS 26.3.1 concurrency thunk.
      Task { @MainActor in
        do {
          let result = try await function.call(values.parameters)
          completion(result.data, nil)
        } catch {
          completion(nil, functionsFlutterError(error))
        }
      }
    } catch {
      completion(nil, error as? FlutterError ?? functionsFlutterError(error))
    }
  }

  private func getFunctions(arguments: [String: Any?]) throws -> Functions {
    let appName = try functionsRequiredString(arguments, "appName")
    let region = try functionsRequiredString(arguments, "region")
    guard let app = FLTFirebasePlugin.firebaseAppNamed(appName) else {
      throw functionsArgumentError("Firebase app is not initialized")
    }
    return Functions.functions(app: app, region: region)
  }
}

func functionsArgumentError(_ message: String) -> FlutterError {
  FlutterError(code: "invalid-argument", message: message,
               details: ["code": "invalid-argument", "message": message])
}

func functionsFlutterError(_ error: Error) -> FlutterError {
  let nsError = error as NSError
  var errorCode = "unknown"
  var additionalDetails: [String: Any] = [:]

  if nsError.domain == "com.firebase.functions" {
    errorCode = mapFunctionsErrorCode(nsError.code)
    if let details = nsError.userInfo["details"] {
      additionalDetails["additionalData"] = details
    }
  }

  additionalDetails["code"] = errorCode
  additionalDetails["message"] = nsError.localizedDescription

  return FlutterError(
    code: errorCode,
    message: nsError.localizedDescription,
    details: additionalDetails
  )
}

private func mapFunctionsErrorCode(_ code: Int) -> String {
  switch code {
  case FunctionsErrorCode.aborted.rawValue: return "aborted"
  case FunctionsErrorCode.alreadyExists.rawValue: return "already-exists"
  case FunctionsErrorCode.cancelled.rawValue: return "cancelled"
  case FunctionsErrorCode.dataLoss.rawValue: return "data-loss"
  case FunctionsErrorCode.deadlineExceeded.rawValue: return "deadline-exceeded"
  case FunctionsErrorCode.failedPrecondition.rawValue: return "failed-precondition"
  case FunctionsErrorCode.internal.rawValue: return "internal"
  case FunctionsErrorCode.invalidArgument.rawValue: return "invalid-argument"
  case FunctionsErrorCode.notFound.rawValue: return "not-found"
  case FunctionsErrorCode.OK.rawValue: return "ok"
  case FunctionsErrorCode.outOfRange.rawValue: return "out-of-range"
  case FunctionsErrorCode.permissionDenied.rawValue: return "permission-denied"
  case FunctionsErrorCode.resourceExhausted.rawValue: return "resource-exhausted"
  case FunctionsErrorCode.unauthenticated.rawValue: return "unauthenticated"
  case FunctionsErrorCode.unavailable.rawValue: return "unavailable"
  case FunctionsErrorCode.unimplemented.rawValue: return "unimplemented"
  default: return "unknown"
  }
}
