import SwiftUI
import StoreKit

// MARK: - SKProductsRequestDelegate
extension IAPManager: SKProductsRequestDelegate {
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        DispatchQueue.main.async {
            self.isLoadingProducts = false
            // 🔧 修复：对商品列表按 productIDs 顺序排序，确保每次显示顺序一致
            let sortedProducts = response.products.sorted { product1, product2 in
                let index1 = self.productIDs.firstIndex(of: product1.productIdentifier) ?? Int.max
                let index2 = self.productIDs.firstIndex(of: product2.productIdentifier) ?? Int.max
                return index1 < index2
            }
            self.products = sortedProducts
            
            
            // 检查是否有无效的商品ID
            if !response.invalidProductIdentifiers.isEmpty {
                // 如果所有商品ID都无效，说明商品还未在App Store Connect中配置或还未生效
                let totalRequested = response.products.count + response.invalidProductIdentifiers.count
                if response.invalidProductIdentifiers.count == totalRequested {
                    #if DEBUG
                    let bundleId = Bundle.main.bundleIdentifier ?? "未知"
                    self.productLoadError = "所有商品ID无效。\n\n调试信息：\n- Bundle ID: \(bundleId)\n- 请求商品数: \(self.productIDs.count)\n- 无效商品数: \(response.invalidProductIdentifiers.count)\n\n可能的原因：\n1. 商品刚创建，需要等待最多1小时生效\n2. Bundle ID不匹配（检查App Store Connect中的应用Bundle ID）\n3. 需要在App版本页面关联商品\n4. 需要在真机上测试（模拟器无法测试IAP）\n5. 需要退出当前Apple ID，使用沙盒测试账号\n\n请检查：\n- App Store Connect中的应用Bundle ID是否为: \(bundleId)\n- 商品是否已创建超过1小时\n- 是否在真机上测试"
                    #else
                    self.productLoadError = "所有商品ID无效。请检查App Store Connect配置，或等待商品生效。"
                    #endif
                } else {
                    let invalidIds = response.invalidProductIdentifiers.joined(separator: ", ")
                    self.productLoadError = "部分商品ID无效: \(invalidIds)。请检查App Store Connect配置。"
                }
            }
            
            // 检查是否在模拟器上（模拟器无法加载真实商品）
            #if targetEnvironment(simulator)
            if self.products.isEmpty {
                self.productLoadError = "模拟器无法加载真实商品。请在真机上测试，或确保商品已在App Store Connect中配置。"
            }
            #endif
            
            // 如果商品为空且没有错误，可能是网络问题
            if self.products.isEmpty && self.productLoadError == nil {
                #if DEBUG
                // 开发环境提示
                self.productLoadError = "未加载到商品信息。请检查：\n1. 网络连接\n2. 商品是否已在App Store Connect中配置\n3. 是否在真机上测试（模拟器无法测试IAP）\n4. 是否使用沙盒测试账号"
                #else
                self.productLoadError = "未加载到商品信息。请检查网络连接，或确保商品已在App Store Connect中配置。"
                #endif
            }
            
        }
    }
    
    func request(_ request: SKRequest, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isLoadingProducts = false
            let nsError = error as NSError
            
            // 提供更详细的错误信息
            var errorMessage = "获取商品失败"
            switch nsError.code {
            case -1009: // NSURLErrorNotConnectedToInternet
                errorMessage = "网络连接失败，请检查网络设置"
            case -1001: // NSURLErrorTimedOut
                errorMessage = "请求超时，请稍后重试"
            default:
                errorMessage = "获取商品失败: \(error.localizedDescription)"
            }
            
            self.productLoadError = errorMessage
            self.purchaseError = errorMessage
        }
    }
}

// 通知名称扩展
extension Notification.Name {
    static let iapPurchaseSuccessful = Notification.Name("iapPurchaseSuccessful")
    static let iapPurchaseDeferred = Notification.Name("iapPurchaseDeferred")
    static let iapRestoreCompleted = Notification.Name("iapRestoreCompleted")
    static let iapRestoreFailed = Notification.Name("iapRestoreFailed")
    static let iapDiamondAddedSuccessfully = Notification.Name("iapDiamondAddedSuccessfully")
}
