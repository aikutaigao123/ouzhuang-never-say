import SwiftUI
import StoreKit

// MARK: - SKPaymentTransactionObserver
extension IAPManager: SKPaymentTransactionObserver {
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            let transactionId = transaction.transactionIdentifier ?? "无ID"
            
            switch transaction.transactionState {
            case .purchasing:
                // 购买中，保持 isPurchasing 为 true
                DispatchQueue.main.async {
                    self.isPurchasing = true
                }
                break
                
            case .purchased:
                // 🔧 修复：检查是否是新交易（通过检查交易时间）
                // 如果交易时间超过10秒前，可能是待处理的旧交易
                let transactionAge = transaction.transactionDate?.timeIntervalSinceNow ?? -999999
                let isRecentTransaction = abs(transactionAge) < 10 // 10秒内的交易认为是新交易
                
                if !isRecentTransaction {
                    // 对于旧交易，检查是否已经处理过（通过UserDefaults标记）
                    let processedKey = "processed_transaction_\(transactionId)"
                    let wasProcessed = UserDefaults.standard.bool(forKey: processedKey)
                    
                    if wasProcessed {
                        queue.finishTransaction(transaction)
                        return
                    }
                }
                handleSuccessfulPurchase(transaction) { success in
                    if success {
                        queue.finishTransaction(transaction)
                    } else {
                        // 钻石添加失败，保留交易以便重试
                        // 交易将在下次应用启动时重新处理
                    }
                }
                
            case .failed:
                handleFailedPurchase(transaction)
                queue.finishTransaction(transaction)
                
            case .restored:
                handleSuccessfulPurchase(transaction, isRestored: true) { success in
                    if success {
                        queue.finishTransaction(transaction)
                    } else {
                        // 钻石添加失败，保留交易以便重试
                    }
                }
                
            case .deferred:
                handleDeferredPurchase(transaction)
                break
                
            @unknown default:
                break
            }
        }
    }
    
    private func handleSuccessfulPurchase(_ transaction: SKPaymentTransaction, isRestored: Bool = false, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            self.isPurchasing = false
            
            let productId = transaction.payment.productIdentifier
            guard let diamonds = self.productToDiamonds[productId] else {
                completion(false)
                return
            }
            
            // 🔒 验证收据（防止欺诈）
            self.verifyReceipt(transaction: transaction) { isValid in
                guard isValid else {
                    // 收据验证失败，不处理购买
                    DispatchQueue.main.async {
                        self.purchaseError = "购买验证失败，请重试"
                    }
                    completion(false)
                    return
                }
                
                // 验证通过，发送购买成功通知
                let transactionId = transaction.transactionIdentifier ?? ""
                
                // 🔧 检查是否已经处理过这个交易（防止重复通知）
                let processedKey = "processed_transaction_\(transactionId)"
                let wasProcessed = UserDefaults.standard.bool(forKey: processedKey)
                
                if wasProcessed {
                    completion(true) // 直接完成，因为已经处理过了
                    return
                }
                
                // 🔒 立即标记为正在处理（防止并发重复通知）
                let processingKey = "processing_transaction_\(transactionId)"
                if UserDefaults.standard.bool(forKey: processingKey) {
                    completion(true) // 直接完成，因为正在处理中
                    return
                }
                UserDefaults.standard.set(true, forKey: processingKey)
                NotificationCenter.default.post(
                    name: .iapPurchaseSuccessful,
                    object: nil,
                    userInfo: [
                        "diamonds": diamonds,
                        "productId": productId,
                        "transactionId": transactionId,
                        "transactionDate": transaction.transactionDate ?? Date(),
                        "isRestored": isRestored
                    ]
                )
                
                // 等待钻石添加完成后再调用 completion
                // 通过轮询检查交易是否已处理
                var checkCount = 0
                let maxChecks = 50  // 最多检查5秒（50次 * 0.1秒）
                
                let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                    checkCount += 1
                    let processedKey = "processed_transaction_\(transactionId)"
                    let isProcessed = UserDefaults.standard.bool(forKey: processedKey)
                    
                    if isProcessed {
                        timer.invalidate()
                        completion(true)
                    } else if checkCount >= maxChecks {
                        timer.invalidate()
                        // 超时，检查是否应该完成交易
                        // 如果钻石添加失败，保留交易以便重试
                        completion(false)
                    }
                }
                
                // 确保定时器在主线程运行
                RunLoop.main.add(timer, forMode: .common)
            }
        }
    }
    
    // 🔒 验证收据（基本验证）
    private func verifyReceipt(transaction: SKPaymentTransaction, completion: @escaping (Bool) -> Void) {
        // 基本验证：检查交易ID和日期是否有效
        guard let transactionId = transaction.transactionIdentifier,
              !transactionId.isEmpty,
              let transactionDate = transaction.transactionDate else {
            completion(false)
            return
        }
        
        // 检查交易日期是否合理（不能是未来时间，不能太旧）
        let now = Date()
        if transactionDate > now.addingTimeInterval(60) {
            // 交易日期在未来（允许1分钟误差）
            completion(false)
            return
        }
        
        // 检查交易是否过期（超过1年的交易可能有问题）
        if transactionDate < now.addingTimeInterval(-365 * 24 * 60 * 60) {
            completion(false)
            return
        }
        
        // 基本验证通过
        // 注意：生产环境应该实现服务器端收据验证
        // 这里只做基本的客户端验证
        completion(true)
    }
    
    private func handleFailedPurchase(_ transaction: SKPaymentTransaction) {
        DispatchQueue.main.async {
            self.isPurchasing = false
            
            if let error = transaction.error {
                let nsError = error as NSError
                var errorMessage = "购买失败"
                
                // 根据错误代码提供更详细的错误信息
                switch nsError.code {
                case SKError.paymentCancelled.rawValue:
                    errorMessage = "购买已取消"
                case SKError.paymentNotAllowed.rawValue:
                    errorMessage = "设备不允许支付，请检查支付设置"
                case SKError.paymentInvalid.rawValue:
                    errorMessage = "支付信息无效"
                case SKError.storeProductNotAvailable.rawValue:
                    errorMessage = "商品不可用"
                case SKError.cloudServicePermissionDenied.rawValue:
                    errorMessage = "iCloud服务权限被拒绝"
                case SKError.cloudServiceNetworkConnectionFailed.rawValue:
                    errorMessage = "网络连接失败，请检查网络设置"
                default:
                    errorMessage = "购买失败: \(error.localizedDescription)"
                }
                
                self.purchaseError = errorMessage
            } else {
                self.purchaseError = "购买失败，请重试"
            }
        }
    }
    
    private func handleDeferredPurchase(_ transaction: SKPaymentTransaction) {
        DispatchQueue.main.async {
            // Deferred 状态通常需要家长批准（儿童账户）
            // 保持 isPurchasing 为 true，等待后续状态更新
            self.isPurchasing = true
            
            // 发送延迟购买通知
            NotificationCenter.default.post(
                name: .iapPurchaseDeferred,
                object: nil,
                userInfo: [
                    "productId": transaction.payment.productIdentifier
                ]
            )
        }
    }
    
    // 恢复购买完成
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        DispatchQueue.main.async {
            self.isPurchasing = false
            // 发送恢复完成通知
            NotificationCenter.default.post(
                name: .iapRestoreCompleted,
                object: nil
            )
        }
    }
    
    // 恢复购买失败
    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        DispatchQueue.main.async {
            self.isPurchasing = false
            let nsError = error as NSError
            var errorMessage = "恢复购买失败"
            
            // 根据错误代码提供更详细的错误信息
            switch nsError.code {
            case SKError.paymentCancelled.rawValue:
                errorMessage = "恢复购买已取消"
            case SKError.cloudServiceNetworkConnectionFailed.rawValue:
                errorMessage = "网络连接失败，请检查网络设置"
            default:
                errorMessage = "恢复购买失败: \(error.localizedDescription)"
            }
            
            self.purchaseError = errorMessage
            
            // 发送恢复失败通知
            NotificationCenter.default.post(
                name: .iapRestoreFailed,
                object: nil,
                userInfo: ["error": errorMessage]
            )
        }
    }
}
