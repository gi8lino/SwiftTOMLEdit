// swift-tools-version: 5.10

import PackageDescription

let strictConcurrencySettings: [SwiftSetting] = [
  .enableUpcomingFeature("StrictConcurrency")
]

let package = Package(
  name: "SwiftTOMLEdit",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(name: "SwiftTOMLEdit", targets: ["SwiftTOMLEdit"])
  ],
  targets: [
    .binaryTarget(
      name: "CSwiftTOMLEdit",
      path: "Artifacts/CSwiftTOMLEdit.xcframework"
    ),
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
