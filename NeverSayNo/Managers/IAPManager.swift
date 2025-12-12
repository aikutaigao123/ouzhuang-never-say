import SwiftUI
import StoreKit

// IAP管理器 - 处理真实的iOS交易
class IAPManager: NSObject, ObservableObject {
    @Published var products: [SKProduct] = []
    @Published var isPurchasing = false
    @Published var purchaseError: String?
    @Published var isLoadingProducts = false
    @Published var productLoadError: String?
    
    // 商品ID - 需要在App Store Connect中配置 (简化版本)
    let productIDs = [
        "NeverSayNo10",      // 10钻石 (1元)
        "NeverSayNo60",      // 60钻石 (6元)
        "NeverSayNo500",     // 500钻石 (48元)
        "NeverSayNo715",    // 715钻石 (68元)
        "NeverSayNo1345",    // 1345钻石 (128元)
        "NeverSayNo2100",   // 2100钻石 (198元)
        "NeverSayNo3690",   // 3690钻石 (348元)
        "NeverSayNo7400"    // 7400钻石 (698元)
    ]
    
    // 商品ID到钻石数量的映射
    let productToDiamonds: [String: Int] = [
        "NeverSayNo10": 10,
        "NeverSayNo60": 60,
        "NeverSayNo500": 500,
        "NeverSayNo715": 715,
        "NeverSayNo1345": 1345,
        "NeverSayNo2100": 2100,
        "NeverSayNo3690": 3690,
        "NeverSayNo7400": 7400
    ]
    
    override init() {
        super.init()
        // 设置交易观察者
        SKPaymentQueue.default().add(self)
    }
    
    deinit {
        SKPaymentQueue.default().remove(self)
    }
    
    // 获取商品信息
    func fetchProducts() {
        isLoadingProducts = true
        productLoadError = nil
        let request = SKProductsRequest(productIdentifiers: Set(productIDs))
        request.delegate = self
        request.start()
    }
    
    // 购买商品
    func purchaseProduct(_ product: SKProduct, diamondManager: DiamondManager) {
        
        guard SKPaymentQueue.canMakePayments() else {
            purchaseError = "设备不支持支付"
            return
        }
        
        // 🔧 修复：检查并完成待处理的交易，避免阻塞新购买
        let queue = SKPaymentQueue.default()
        let pendingTransactions = queue.transactions.filter { transaction in
            transaction.payment.productIdentifier == product.productIdentifier &&
            transaction.transactionState == .purchased
        }
        
        if !pendingTransactions.isEmpty {
            
            // 先完成所有待处理的交易
            for transaction in pendingTransactions {
                // 直接完成交易，因为已经处理过了（通过 transaction observer）
                queue.finishTransaction(transaction)
            }
            
            // 提示用户
            DispatchQueue.main.async {
                self.purchaseError = "检测到待处理的购买记录，已自动完成。如需再次购买，请稍后再试。"
            }
            
            return
        }
        
        // 🔧 关键改进：在购买前检查LeanCloud连接
        // 参考LeanCloud开发指南和App Store要求：确保服务器连接正常后再允许购买
        // 这样可以防止用户付费后无法同步到服务器的情况
        checkLeanCloudConnectionBeforePurchase(diamondManager: diamondManager) { [weak self] isConnected, errorMessage in
            guard let self = self else { return }
            
            if !isConnected {
                // 连接失败，禁止购买并提示用户
                DispatchQueue.main.async {
                    self.purchaseError = errorMessage ?? "无法连接到服务器，请检查网络连接后重试"
                }
                return
            }
            
            // 连接成功，继续购买流程
            DispatchQueue.main.async {
                self.isPurchasing = true
                self.purchaseError = nil
                
                let payment = SKPayment(product: product)
                queue.add(payment)
            }
        }
    }
    
    // 🔧 新增：检查LeanCloud连接
    private func checkLeanCloudConnectionBeforePurchase(diamondManager: DiamondManager, completion: @escaping (Bool, String?) -> Void) {
        // 使用DiamondStore的refreshBalanceFromServer来测试连接
        // 这是一个轻量级的查询操作，可以验证服务器连接是否正常
        guard let store = diamondManager.diamondStore else {
            completion(false, "钻石系统未初始化，请稍后重试")
            return
        }
        
        // 设置超时时间（5秒）
        var hasCompleted = false
        let timeoutWorkItem = DispatchWorkItem {
            if !hasCompleted {
                hasCompleted = true
                completion(false, "连接超时，请检查网络连接后重试")
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: timeoutWorkItem)
        
        // 尝试刷新余额来测试连接
        store.refreshBalanceFromServer { result in
            guard !hasCompleted else { return }
            hasCompleted = true
            timeoutWorkItem.cancel()
            
            switch result {
            case .success:
                // 连接成功
                completion(true, nil)
            case .failure(let error):
                // 连接失败，根据错误类型提供不同的提示
                let errorMessage: String
                if case .serverError(let message) = error, (message.contains("API限制") || message.contains("429") || message.contains("140")) {
                    errorMessage = "服务器繁忙，请稍后再试"
                } else if case .networkError = error {
                    errorMessage = "网络连接失败，请检查网络设置后重试"
                } else {
                    errorMessage = "无法连接到服务器，请稍后重试"
                }
                completion(false, errorMessage)
            }
        }
    }
    
    // 恢复购买
    func restorePurchases() {
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
}
