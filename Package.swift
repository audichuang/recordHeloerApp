// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "RecordHeloerApp",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "RecordAnalyzerDependencies",
            targets: ["RecordAnalyzerDependencies"]),
    ],
    dependencies: [
        .package(url: "https://github.com/markiv/SwiftUI-Shimmer", from: "1.4.0"),
        .package(url: "https://github.com/exyte/PopupView", from: "2.9.0"),
        .package(url: "https://github.com/exyte/AnimatedTabBar", from: "0.0.2"),
        .package(url: "https://github.com/siteline/SwiftUI-Introspect", from: "1.1.1"),
        .package(url: "https://github.com/lorenzofiamingo/swiftui-cached-async-image", from: "2.1.1"),
        .package(url: "https://github.com/airbnb/lottie-ios", branch: "master"),
    ],
    targets: [
        .target(
            name: "RecordAnalyzerDependencies",
            dependencies: [
                .product(name: "Shimmer", package: "SwiftUI-Shimmer"),
                .product(name: "PopupView", package: "PopupView"),
                .product(name: "AnimatedTabBar", package: "AnimatedTabBar"),
                .product(name: "Introspect", package: "SwiftUI-Introspect"),
                .product(name: "CachedAsyncImage", package: "swiftui-cached-async-image"),
                .product(name: "Lottie", package: "lottie-ios"),
            ]
        ),
    ]
) 