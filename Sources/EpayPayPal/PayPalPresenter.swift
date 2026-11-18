import Foundation
import UIKit
@_exported import EpaySDK
import CorePayments
import PayPalPayments
import FraudProtection

/// SDK-owned integration with PayPal's Swift-only library. Business processing stays in the bridge.
public extension IosPaymentHost {
    convenience init(viewController: UIViewController, config: PaymentHostConfig = PaymentHostConfig()) {
        precondition(Thread.isMainThread)
        let presenter = NativePayPalPresenter(
            base: config.appUniversalLink.flatMap { URL(string: $0) },
            fallback: config.appReturnUrl.flatMap { URL(string: $0) }.flatMap { $0.scheme == "https" ? nil : $0 })
        self.init(viewController: viewController, config: config, payPalPresenter: presenter)
    }
}

private final class NativePayPalPresenter: NSObject, PayPalPresenter {
    private let base: URL?
    private let fallback: URL?
    private var urls: PayPalURLConfig?
    private var returnId: String?
    private var client: PayPalClient?
    private var vaultOnly = false
    private var generation = 0
    private var awaitingReturn = false
    private var orderId: String?

    init(base: URL?, fallback: URL?) {
        self.base = base
        self.fallback = fallback
        super.init()
    }

    private func returnURL(base: URL, action: String, id: String) -> URL {
        var components = URLComponents(url: base.appendingPathComponent("paypal/" + action), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "epayAttempt", value: id)]
        return components.url!
    }

    func prepare(configuration: PayPalConfiguration, completion: PayPalPreparationCompletion) {
        precondition(Thread.isMainThread)
        dispose()
        guard let base, base.scheme == "https" else {
            completion.complete(result_: PayPalPreparation(clientMetadataId: nil, errorMessage:
                "PayPal on iOS requires PaymentHostConfig.appUniversalLink to be a registered HTTPS Universal Link"))
            return
        }
        let id = UUID().uuidString
        returnId = id
        let urls = PayPalURLConfig(
            returnAppURL: returnURL(base: base, action: "return", id: id),
            cancelAppURL: returnURL(base: base, action: "cancel", id: id),
            fallbackSchemeURL: fallback.map { returnURL(base: $0, action: "return", id: id) }
        )
        self.urls = urls
        let config = CoreConfig(clientID: configuration.clientId, environment: configuration.test ? .sandbox : .live,
                                merchantID: configuration.merchantId, bnCode: configuration.partnerAttributionId)
        let paypal = PayPalClient(config: config)
        client = paypal
        vaultOnly = configuration.vaultOnly
        paypal.createPayPalSession(sessionType: vaultOnly ? .vaultWithoutPurchase : .checkout, urlConfig: urls,
                                   userAction: vaultOnly ? .setupNow : .payNow)
        // Magnes on iOS wraps the identifier in JSON; the server header needs the identifier itself.
        let raw = PayPalDataCollector(config: config).collectDeviceData()
        let data = raw.data(using: .utf8)
        let object = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        let identifier = object?["correlation_id"] as? String
        let prepared = PayPalPreparation(clientMetadataId: identifier, errorMessage: nil)
        prepared.returnUrl = returnURL(base: base, action: "return", id: id).absoluteString
        prepared.cancelUrl = returnURL(base: base, action: "cancel", id: id).absoluteString
        completion.complete(result_: prepared)
    }

    func present(orderId: String, completion: PayPalApprovalCompletion) {
        precondition(Thread.isMainThread)
        guard let paypal = client, !awaitingReturn else {
            completion.complete(result: PayPalApproval(state: .failed, errorMessage: "PayPal is not ready"))
            return
        }
        self.orderId = orderId
        awaitingReturn = true
        let attempt = generation
        if vaultOnly {
            paypal.vault(setupTokenID: orderId) { [weak self] result in
                guard let self, attempt == generation, awaitingReturn else { return }
                awaitingReturn = false
                switch result {
                case .success: completion.complete(result: PayPalApproval(state: .approved, errorMessage: nil))
                case .failure(let error):
                    completion.complete(result: PayPalApproval(state: PayPalError.isVaultCanceled(error) ? .cancelled : .failed,
                                           errorMessage: PayPalError.isVaultCanceled(error) ? nil : "PayPal approval failed"))
                }
            }
        } else {
            paypal.start(orderID: orderId) { [weak self] result in
                guard let self, attempt == generation, awaitingReturn else { return }
                awaitingReturn = false
                switch result {
                case .success: completion.complete(result: PayPalApproval(state: .approved, errorMessage: nil))
                case .failure(let error):
                    completion.complete(result: PayPalApproval(state: PayPalError.isCheckoutCanceled(error) ? .cancelled : .failed,
                                           errorMessage: PayPalError.isCheckoutCanceled(error) ? nil : "PayPal approval failed"))
                }
            }
        }
    }

    func handleReturnUrl(url: String) -> Bool {
        guard awaitingReturn, let client, let urls, let returnId, let incoming = URL(string: url) else { return false }
        let allowed = [urls.returnAppURL, urls.cancelAppURL, urls.fallbackSchemeURL].compactMap { $0 }
        guard allowed.contains(where: { $0.scheme == incoming.scheme && $0.host == incoming.host && $0.path == incoming.path }) else { return false }
        let parameters = URLComponents(url: incoming, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let ids = parameters.filter { $0.name == "epayAttempt" }
        guard ids.count == 1, ids[0].value == returnId else { return false }
        let token = parameters.first { $0.name == (vaultOnly ? "approval_token_id" : "token") }?.value
        if let token, token != orderId { return false }
        client.handleReturnURL(incoming)
        return true
    }

    func dispose() {
        generation += 1
        awaitingReturn = false
        orderId = nil
        client = nil
        urls = nil
        returnId = nil
    }
}
