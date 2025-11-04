// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ZyraForm",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "ZyraForm",
            targets: ["ZyraForm"]),
        .library(
            name: "ZyraFormSupabase",
            targets: ["ZyraFormSupabase"])
    ],
    dependencies: [
        .package(url: "https://github.com/powersync-ja/powersync-swift.git", from: "1.6.0"),
        .package(url: "https://github.com/supabase/supabase-swift", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "ZyraForm",
            dependencies: [
                .product(name: "PowerSync", package: "powersync-swift")
            ]),
        .target(
            name: "ZyraFormSupabase",
            dependencies: [
                "ZyraForm",
                .product(name: "Supabase", package: "supabase-swift")
            ],
            path: "Sources/ZyraFormSupabase"),
        .testTarget(
            name: "ZyraFormTests",
            dependencies: ["ZyraForm"],
            path: "Tests/ZyraFormTests")
    ]
)

