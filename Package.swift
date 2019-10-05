// swift-tools-version:5.1
import Foundation
import PackageDescription

let package = Package(
    name: "SwiftyRedux",
    products: [
    .library(name: "SwiftyReduxCore",
             targets: ["SwiftyReduxCore"]),
    ],
    targets: [
        .target(name: "SwiftyReduxCore",
                dependencies: [],
                path: "./SwiftyRedux/Sources/Core"),
        .testTarget(name: "SwiftyReduxTests",
                    dependencies: [],
                    path: "./SwiftyRedux/Tests/Core")
    ]
)
