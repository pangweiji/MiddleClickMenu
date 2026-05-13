// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MiddleClickMenu",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-testing.git", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "MiddleClickMenu",
            path: "Sources/MiddleClickMenu",
            exclude: ["Resources/Info.plist"],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", "Sources/MiddleClickMenu/Resources/Info.plist"])
            ]
        ),
        .testTarget(
            name: "MiddleClickMenuTests",
            dependencies: [
                "MiddleClickMenu",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "Tests/MiddleClickMenuTests"
        )
    ]
)
