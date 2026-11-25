// swift-tools-version: 5.10

import Foundation
import PackageDescription

let strictConcurrencySettings: [SwiftSetting] = [
  .enableUpcomingFeature("StrictConcurrency")
]

// The release workflow updates these values before creating each version tag.
let releaseTag = "v0.2.4"
let releaseChecksum = "1596ee14e7692480cda3a47ec06295f4ee6c566125ad2815d2c481e0863c9bea"

let nativeTarget: Target =
  ProcessInfo.processInfo.environment["SWIFT_TOML_EDIT_USE_LOCAL_ARTIFACT"] == "1"
  ? .binaryTarget(
    name: "CSwiftTOMLEdit",
    path: "Artifacts/CSwiftTOMLEdit.xcframework"
  )
  : .binaryTarget(
    name: "CSwiftTOMLEdit",
    url:
      "https://github.com/gi8lino/SwiftTOMLEdit/releases/download/\(releaseTag)/CSwiftTOMLEdit.xcframework.zip",
    checksum: releaseChecksum
  )

let package = Package(
  name: "SwiftTOMLEdit",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(name: "SwiftTOMLEdit", targets: ["SwiftTOMLEdit"])
  ],
  targets: [
    nativeTarget,
    .target(
      name: "SwiftTOMLEdit",
      dependencies: ["CSwiftTOMLEdit"],
      path: "Sources/SwiftTOMLEdit",
      swiftSettings: strictConcurrencySettings
    ),
    .testTarget(
      name: "SwiftTOMLEditTests",
      dependencies: ["SwiftTOMLEdit"],
      path: "Tests/SwiftTOMLEditTests",
      swiftSettings: strictConcurrencySettings
    ),
  ]
)
