# ePay iOS SDK

Add `https://github.com/ePay/sdk-ios` in Xcode under **File → Add Package Dependencies**, then select version `0.0.12` or a compatible version range. Add the `EpaySDK` product to your app target and import `EpayPayPal` for the standard iOS host integration.

Requires iOS 16 or later. Swift Package Manager downloads the compiled XCFramework and the pinned PayPal dependencies automatically. This repository contains the package manifest and Swift PayPal adapter; the main SDK implementation is distributed as a binary.

- [Integration documentation](https://docs.epay.eu/native-sdk)
- Support: support@epay.dk
- [MIT License](LICENSE); third-party dependencies retain their own licenses.
- [ePay service terms](https://epay.eu/terms) apply separately to payment services.

Published versions and their binary downloads are retained permanently. To update, select a newer package version in Xcode.
