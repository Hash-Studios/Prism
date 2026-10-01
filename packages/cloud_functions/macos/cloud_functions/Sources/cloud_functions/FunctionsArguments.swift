// Copyright 2025 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import CoreFoundation
import Foundation

struct CallableArguments {
  enum Target {
    case name(String)
    case url(URL)
  }

  let target: Target
  let origin: URL?
  let timeout: TimeInterval?
  let parameters: Any?
  let limitedUseAppCheckToken: Bool

  init(_ arguments: [String: Any?]) throws {
    let name = try optionalString(arguments, "functionName")
    let uri = try optionalString(arguments, "functionUri")
    if let name {
      target = .name(name)
    } else if let uri, let url = URL(string: uri), isCallableURL(url) {
      target = .url(url)
    } else {
      throw functionsArgumentError("Either functionName or a valid functionUri must be set")
    }
    if let value = try optionalString(arguments, "origin") {
      guard let url = URL(string: value), isCallableURL(url),
            let port = url.port, (1...65535).contains(port) else {
        throw functionsArgumentError("origin must be an HTTP URL with a valid port")
      }
      origin = url
    } else {
      origin = nil
    }
    if let value = argumentValue(arguments, "timeout") {
      guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
            !["f", "d"].contains(String(cString: number.objCType)),
            number.doubleValue.isFinite, number.doubleValue > 0,
            number.compare(NSNumber(value: Int64.max)) != .orderedDescending else {
        throw functionsArgumentError("timeout must be a positive integer")
      }
      timeout = number.doubleValue / 1000
    } else {
      timeout = nil
    }
    guard let number = argumentValue(arguments, "limitedUseAppCheckToken") as? NSNumber,
          CFGetTypeID(number) == CFBooleanGetTypeID() else {
      throw functionsArgumentError("limitedUseAppCheckToken must be a boolean")
    }
    limitedUseAppCheckToken = number.boolValue
    parameters = argumentValue(arguments, "parameters")
  }
}

private func argumentValue(_ arguments: [String: Any?], _ key: String) -> Any? {
  guard let value = arguments[key] ?? nil, !(value is NSNull) else { return nil }
  return value
}

private func optionalString(_ arguments: [String: Any?], _ key: String) throws -> String? {
  guard let value = argumentValue(arguments, key) else { return nil }
  guard let string = value as? String, !string.isEmpty else {
    throw functionsArgumentError("\(key) must be a non-empty string")
  }
  return string
}

func functionsRequiredString(_ arguments: [String: Any?], _ key: String) throws -> String {
  guard let value = try optionalString(arguments, key) else {
    throw functionsArgumentError("\(key) must be a non-empty string")
  }
  return value
}

private func isCallableURL(_ url: URL) -> Bool {
  let validPort = url.port.map { (1...65535).contains($0) } ?? true
  return ["http", "https"].contains(url.scheme ?? "") && !(url.host ?? "").isEmpty &&
    url.user == nil && url.password == nil && validPort
}
