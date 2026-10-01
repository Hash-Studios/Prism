// swift-tools-version: 5.9
// Copyright 2024, the Chromium project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import Foundation
import PackageDescription

let packageDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let pluginDirectory = packageDirectory.deletingLastPathComponent().deletingLastPathComponent()
let pubspec = try String(
  contentsOf: pluginDirectory.appendingPathComponent("pubspec.yaml"), encoding: .utf8
)
guard let coreLine = pubspec.split(separator: "\n").first(where: {
  $0.trimmingCharacters(in: .whitespaces).hasPrefix("firebase_core:")
}), let coreValue = coreLine.split(separator: ":", maxSplits: 1).last else {
  fatalError("Missing firebase_core dependency in pubspec.yaml")
}
let coreVersion = coreValue.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "^", with: "")
let sdkVersion = try String(
  contentsOf: pluginDirectory.appendingPathComponent("ios/generated_firebase_sdk_version.txt"),
  encoding: .utf8
).trimmingCharacters(in: .whitespacesAndNewlines)
guard let firebaseVersion = Version(sdkVersion),
      let sharedVersion = Version("\(coreVersion)-firebase-core-swift") else {
  fatalError("Invalid Firebase SDK or firebase_core version")
}

let package = Package(
  name: "cloud_functions",
  platforms: [.macOS("10.15")],
  products: [.library(name: "cloud-functions", targets: ["cloud_functions"])],
  dependencies: [
    .package(url: "https://github.com/firebase/firebase-ios-sdk", from: firebaseVersion),
    .package(url: "https://github.com/firebase/flutterfire", exact: sharedVersion),
  ],
  targets: [
    .target(name: "cloud_functions", dependencies: [
      .product(name: "FirebaseFunctions", package: "firebase-ios-sdk"),
      .product(name: "firebase-core-shared", package: "flutterfire"),
    ]),
  ]
)
