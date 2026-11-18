// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "EpaySDK",
    platforms: [.iOS(.v16)],
    products: [.library(name: "EpaySDK", targets: ["EpaySDK", "EpayPayPal"])],
    dependencies: [.package(url: "https://github.com/paypal/paypal-ios", exact: "3.1.1")],
    targets: [
        .binaryTarget(name: "EpaySDK", url: "https://github.com/ePay/sdk-ios/releases/download/v0.0.12/EpaySDK.xcframework.zip", checksum: "25fce44a9a532c429e963e593c67e2f4482462a94eaf973a46111234b55891ba"),
        .target(name: "EpayPayPal", dependencies: [
            "EpaySDK",
            .product(name: "CorePayments", package: "paypal-ios"),
            .product(name: "PayPalPayments", package: "paypal-ios"),
            .product(name: "FraudProtection", package: "paypal-ios")
        ])
    ]
)
