// swift-tools-version:5.9
// GS Remap's engine as a reference for MegaconvertGS's save formats and remap options
// (used by test/save.sh, test/remap2.sh and test/filters.sh).
import PackageDescription

let package = Package(
    name: "sc4save",
    platforms: [.macOS(.v13)],
    dependencies: [.package(path: "../../../GS Remap")],
    targets: [
        .executableTarget(name: "sc4save", dependencies: [.product(name: "SCCore", package: "GS Remap")]),
        .executableTarget(name: "sc4remap", dependencies: [.product(name: "SCCore", package: "GS Remap")]),
        .executableTarget(name: "sc4filter", dependencies: [.product(name: "SCCore", package: "GS Remap")]),
    ]
)
