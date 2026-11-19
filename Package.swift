// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "EpaySDK",
    platforms: [.iOS(.v16)],
    products: [.library(name: "EpaySDK", targets: ["EpaySDK", "EpayPayPal"])],
    dependencies: [.package(url: "https://github.com/paypal/paypal-ios", exact: "3.1.1")],
    targets: [
        .binaryTarget(name: "EpaySDK", url: "https://github.com/ePay/sdk-ios/releases/download/v0.0.13/EpaySDK.xcframework.zip", checksum: "e0671d0787a4f23487fbf79fb6f5c5b546eddfd311cb025e06a4bf106a5cb864"),
        .target(name: "EpayPayPal", dependencies: [
            "EpaySDK",
            .product(name: "CorePayments", package: "paypal-ios"),
            .product(name: "PayPalPayments", package: "paypal-ios"),
            .product(name: "FraudProtection", package: "paypal-ios")
        ])
    ]
)
