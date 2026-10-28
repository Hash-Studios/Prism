// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "PrismNative",
  platforms: [.macOS(.v12), .iOS(.v15)],
  targets: [
    .target(name: "PrismMediaStorage", path: "Runner/Media"),
    .target(name: "PrismShortcutsCore", path: "Runner/Shortcuts/Core"),
    .target(name: "PrismNotificationCore", path: "PrismNotificationService/Core"),
    .testTarget(
      name: "PrismMediaStorageTests",
      dependencies: ["PrismMediaStorage", "PrismShortcutsCore", "PrismNotificationCore"],
      path: "RunnerTests",
      exclude: ["RunnerTests.swift"]
    )
  ]
)
