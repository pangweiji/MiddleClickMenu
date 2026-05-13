// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MiddleClickMenu",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .target(
            name: "MiddleClickMenuLib",
            path: "Sources/MiddleClickMenu",
            exclude: ["Resources/Info.plist", "App/MiddleClickMenuApp.swift"],
            swiftSettings: [
                .swiftLanguageMode(.v5),
                // MiddleClickMenuTests is an executableTarget, so SPM does not pass -enable-testing to this dependency automatically.
                .unsafeFlags(["-enable-testing"])
            ]
        ),
        .executableTarget(
            name: "MiddleClickMenu",
            dependencies: ["MiddleClickMenuLib"],
            path: "Sources/App",
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", "Sources/MiddleClickMenu/Resources/Info.plist"])
            ]
        ),
        .executableTarget(
            name: "MiddleClickMenuTests",
            dependencies: ["MiddleClickMenuLib"],
            path: "Tests/MiddleClickMenuTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
