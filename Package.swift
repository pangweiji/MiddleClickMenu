// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MiddleClickMenu",
    platforms: [
        .macOS(.v13)
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
            dependencies: ["MiddleClickMenu"],
            path: "Tests/MiddleClickMenuTests"
        )
    ]
)
