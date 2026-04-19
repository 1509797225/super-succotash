import Foundation
import StoreKit

struct StoreKitClient {
    static let proMonthlyProductID = "jellytodo.pro.monthly"

    var productIDs: [String] = [Self.proMonthlyProductID]

    func refreshEntitlement() async -> StoreKitEntitlementSnapshot {
        do {
            let products = try await Product.products(for: productIDs)
            var activeProductID: String?
            var activeTransaction: StoreKitTransactionPayload?

            for await result in Transaction.currentEntitlements {
                guard case .verified(let transaction) = result else { continue }
                guard productIDs.contains(transaction.productID) else { continue }
                guard transaction.revocationDate == nil else { continue }

                if let expirationDate = transaction.expirationDate, expirationDate <= Date() {
                    continue
                }

                activeProductID = transaction.productID
                activeTransaction = Self.payload(from: transaction)
                break
            }

            if let activeProductID {
                return StoreKitEntitlementSnapshot(
                    state: .active,
                    availableProductIDs: products.map(\.id),
                    activeProductID: activeProductID,
                    transaction: activeTransaction,
                    message: "Active Pro subscription"
                )
            }

            if products.isEmpty {
                return StoreKitEntitlementSnapshot(
                    state: .productsUnavailable,
                    availableProductIDs: [],
                    activeProductID: nil,
                    message: "StoreKit products are not configured yet"
                )
            }

            return StoreKitEntitlementSnapshot(
                state: .notSubscribed,
                availableProductIDs: products.map(\.id),
                activeProductID: nil,
                message: "No active Pro subscription"
            )
        } catch {
            return StoreKitEntitlementSnapshot(
                state: .failed,
                availableProductIDs: [],
                activeProductID: nil,
                message: error.localizedDescription
            )
        }
    }

    func purchaseProMonthly() async -> StoreKitEntitlementSnapshot {
        do {
            guard let product = try await Product.products(for: [Self.proMonthlyProductID]).first else {
                return StoreKitEntitlementSnapshot(
                    state: .productsUnavailable,
                    availableProductIDs: [],
                    activeProductID: nil,
                    message: "Pro subscription product is unavailable"
                )
            }

            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    return StoreKitEntitlementSnapshot(
                        state: .failed,
                        availableProductIDs: [product.id],
                        activeProductID: nil,
                        message: "Transaction could not be verified"
                    )
                }

                await transaction.finish()
                return await refreshEntitlement()
            case .pending:
                return StoreKitEntitlementSnapshot(
                    state: .pending,
                    availableProductIDs: [product.id],
                    activeProductID: nil,
                    message: "Purchase is pending"
                )
            case .userCancelled:
                return StoreKitEntitlementSnapshot(
                    state: .notSubscribed,
                    availableProductIDs: [product.id],
                    activeProductID: nil,
                    message: "Purchase cancelled"
                )
            @unknown default:
                return StoreKitEntitlementSnapshot(
                    state: .failed,
                    availableProductIDs: [product.id],
                    activeProductID: nil,
                    message: "Unknown purchase result"
                )
            }
        } catch {
            return StoreKitEntitlementSnapshot(
                state: .failed,
                availableProductIDs: [],
                activeProductID: nil,
                message: error.localizedDescription
            )
        }
    }

    private static func payload(from transaction: Transaction) -> StoreKitTransactionPayload {
        StoreKitTransactionPayload(
            productID: transaction.productID,
            transactionID: String(transaction.id),
            originalTransactionID: String(transaction.originalID),
            expirationDate: transaction.expirationDate,
            environment: String(describing: transaction.environment),
            signedTransactionJWS: "client-verified-storekit2:\(transaction.id)"
        )
    }
}
