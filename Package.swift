// swift-tools-version:5.1
import Foundation
import PackageDescription

let package = Package(
    name: "SwiftyRedux",
    products: [
    .library(name: "Core",
             targets: ["SwiftyReduxCore"]),
    .library(name: "Command",
             targets: ["SwiftyReduxCommand"]),
    .library(name: "SideEffects",
    targets: ["SwiftyReduxSideEffects"]),
    
    ],
    dependencies: [],
    targets: [
        .target(name: "SwiftyReduxCore",
                dependencies: [],
                path: "./SwiftyRedux/Sources/Core"),
        .testTarget(name: "SwiftyReduxTests",
                    dependencies: [],
                    path: "./SwiftyRedux/Tests/Core"),
        .target(name: "SwiftyReduxCommand",
                dependencies: ["SwiftyReduxCore"],
                path: "./SwiftyRedux/Sources/Command"),
        .testTarget(name: "SwiftyReduxCommandTests",
                    dependencies: [],
                path: "./SwiftyRedux/Tests/Command"),
        .target(name: "SwiftyReduxSideEffects",
                dependencies: ["SwiftyReduxCore"],
                path: "./SwiftyRedux/Sources/SideEffects"),
        .testTarget(name: "SwiftyReduxSideEffectsTests",
                    dependencies: [],
                    path: "./SwiftyRedux/Tests/SideEffects")
    ]
)
