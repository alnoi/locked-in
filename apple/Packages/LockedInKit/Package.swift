// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LockedInKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "LockedInWidgetUI", targets: ["LockedInWidgetUI"]),
        .library(name: "LockedInActivity", targets: ["LockedInActivity"]),
        .library(name: "LockedInUI", targets: ["LockedInUI"]),
        .library(name: "LockedInData", targets: ["LockedInData"]),
        .library(name: "LockedInDomain", targets: ["LockedInDomain"])
    ],
    targets: [
        .target(name: "LockedInDomain"),
        .target(name: "LockedInActivity"),
        .target(name: "LockedInData", dependencies: ["LockedInDomain", "LockedInActivity"]),
        .target(name: "LockedInWidgetUI", dependencies: ["LockedInDomain", "LockedInData"]),
        .target(name: "LockedInUI", dependencies: ["LockedInDomain", "LockedInData"], resources: [.process("Resources")]),
        .testTarget(name: "LockedInWidgetUITests", dependencies: ["LockedInWidgetUI"]),
        .testTarget(name: "LockedInDomainTests", dependencies: ["LockedInDomain"]),
        .testTarget(name: "LockedInUITests", dependencies: ["LockedInUI"]),
        .testTarget(name: "LockedInDataTests", dependencies: ["LockedInData", "LockedInDomain"])
    ]
)
