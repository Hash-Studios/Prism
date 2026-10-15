// swift-tools-version: 5.9
// Copyright 2024, the Chromium project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import Foundation
import PackageDescription

let packageDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let pluginDirectory = packageDirectory.deletingLastPathComponent().deletingLastPathComponent()
let sdkVersion = try String(
  contentsOf: pluginDirectory.appendingPathComponent("ios/generated_firebase_sdk_version.txt"),
  encoding: .utf8
).trimmingCharacters(in: .whitespacesAndNewlines)
guard let firebaseVersion = Version(sdkVersion) else {
  fatalError("Invalid Firebase SDK version")
}

let package = Package(
  name: "cloud_functions",
  platforms: [.macOS("10.15")],
  products: [.library(name: "cloud-functions", targets: ["cloud_functions"])],
  dependencies: [
    .package(url: "https://github.com/firebase/firebase-ios-sdk", exact: firebaseVersion),
    .package(name: "firebase_core", path: "../firebase_core"),
    .package(name: "FlutterFramework", path: "../FlutterFramework")
  ],
  targets: [
    .target(name: "cloud_functions", dependencies: [
      .product(name: "FirebaseFunctions", package: "firebase-ios-sdk"),
      .product(name: "firebase-core", package: "firebase_core"),
      .product(name: "FlutterFramework", package: "FlutterFramework")
    ])
  ]
)
