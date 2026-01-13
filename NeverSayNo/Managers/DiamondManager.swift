import SwiftUI
import Combine

class DiamondManager: ObservableObject {
    // 🎯 修改：使用单例模式，确保只有一个实例
    static let shared = DiamondManager()
    
    // 🎯 修改：直接使用 DiamondStore 作为底层存储
    internal var diamondStore: DiamondStore?
    
    @Published var diamonds: Int = 0 {
        didSet {
            // 当余额变为0时，自动从服务器重新检查一次
            if diamonds == 0 && oldValue != 0 {
                recheckBalanceFromServer()
            }
        }
    }
    
    // 🎯 新增：获取钻石余额（完全实时查询版本）
    // 每次调用时都会触发后台刷新，但立即返回当前值
    func getDiamonds() -> Int {
        // 触发后台刷新
        diamondStore?.refreshBalanceInBackground()
        // 立即返回当前值
        return diamonds
    }
    @Published var ownedAvatars: [String] = []
    @Published var isLoading: Bool = false
    @Published var isServerConnected: Bool = false
    
    var currentUserId: String?
    var currentLoginType: String?
    var currentUserName: String?
    var currentUserEmail: String?
    
    private var isRecheckingBalance = false  // 防止重复检查
    var diamondRetryCount: Int = 0 // 🔧 新增：钻石查询重试次数（最多重试2次）
    private var cancellables = Set<AnyCancellable>()
    
    // 🎯 新增：待处理的IAP交易队列（当DiamondStore未初始化时保存）
    private struct PendingIAPTransaction {
        let diamonds: Int
        let transactionId: String
        let timestamp: TimeInterval
    }
    private var pendingIAPTransactions: [PendingIAPTransaction] = []
    private let pendingTransactionsQueue = DispatchQueue(label: "com.neverSayNo.diamondManager.pendingTransactions", qos: .userInitiated)
    
    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleIAPPurchase),
            name: .iapPurchaseSuccessful,
            object: nil
        )
    }
    
    deinit {
        var finalQueueSize = 0
        pendingTransactionsQueue.sync {
            finalQueueSize = pendingIAPTransactions.count
        }
        if finalQueueSize > 0 {
        }
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleIAPPurchase(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let diamonds = userInfo["diamonds"] as? Int,
           let transactionId = userInfo["transactionId"] as? String {
            
            
            // 🔧 修复：检查是否已经处理过这个交易
            let processedKey = "processed_transaction_\(transactionId)"
            let wasProcessed = UserDefaults.standard.bool(forKey: processedKey)
            
            
            if wasProcessed {
                return
            }
            
            
            // 🎯 修改：先检查DiamondStore是否已初始化
            guard let store = diamondStore else {
                
                // 🔧 修复：使用串行队列保护待处理队列的并发访问
                var wasAdded = false
                var finalQueueSize = 0
                // 🔧 修复：在添加前再次检查队列状态（防止并发问题）
                var queueSizeBeforeAdd = 0
                pendingTransactionsQueue.sync {
                    queueSizeBeforeAdd = pendingIAPTransactions.count
                    if queueSizeBeforeAdd > 0 {
                    }
                }
                
                pendingTransactionsQueue.sync {
                    let initialQueueSize = pendingIAPTransactions.count
                    
                    if initialQueueSize != queueSizeBeforeAdd {
                    }
                    
                    
                    let existingIndex = pendingIAPTransactions.firstIndex { $0.transactionId == transactionId }
                    if existingIndex != nil {
                        finalQueueSize = pendingIAPTransactions.count
                        return
                    }
                    
                    // 🔧 修复：保存到待处理队列，不检查processing标记（因为DiamondStore未初始化时无法处理）
                    pendingIAPTransactions.append(PendingIAPTransaction(
                        diamonds: diamonds,
                        transactionId: transactionId,
                        timestamp: Date().timeIntervalSince1970
                    ))
                    finalQueueSize = pendingIAPTransactions.count
                    wasAdded = true
                }
                
                // 🔧 修复：添加后再次检查队列状态（确认添加成功）
                var queueSizeAfterAdd = 0
                pendingTransactionsQueue.sync {
                    queueSizeAfterAdd = pendingIAPTransactions.count
                    if queueSizeAfterAdd != finalQueueSize {
                    }
                }
                
                if wasAdded {
                } else {
                }
                return
            }
            
            // 🔧 新增：如果DiamondStore已初始化，检查并处理待处理队列中的交易
            var queueSizeBeforeProcess = 0
            
            // 检查待处理队列
            pendingTransactionsQueue.sync {
                queueSizeBeforeProcess = pendingIAPTransactions.count
            }
            
            // 如果有待处理交易，处理它们
            if queueSizeBeforeProcess > 0 {
                processPendingIAPTransactions()
            }
            
            // 🔒 检查是否正在处理（防止并发）- 只在DiamondStore已初始化时检查
            let processingKey = "processing_transaction_\(transactionId)"
            // processedKey 已在第87行定义，这里直接使用
            let isProcessing = UserDefaults.standard.bool(forKey: processingKey)
            // wasProcessed 已在第88行定义，这里直接使用
            
            var inPendingQueue = false
            pendingTransactionsQueue.sync {
                inPendingQueue = pendingIAPTransactions.contains { $0.transactionId == transactionId }
            }
            
            
            if isProcessing {
                if inPendingQueue {
                    // 🔧 修复：如果交易在待处理队列中，立即处理队列
                    processPendingIAPTransactions()
                } else if wasProcessed {
                    // 清除processing标记，因为已经处理过了
                    UserDefaults.standard.set(false, forKey: processingKey)
                } else {
                    // 🔧 修复：如果processing标记为true，但交易未处理过，且不在队列中，说明可能是IAPManager设置的标记，但DiamondManager还没有处理
                    // 在这种情况下，应该清除processing标记并处理交易
                    UserDefaults.standard.set(false, forKey: processingKey)
                    // 继续处理，不return
                }
            }
            
            // 如果wasProcessed为true，直接跳过
            if wasProcessed {
                return
            }
            
            // 设置processing标记
            UserDefaults.standard.set(true, forKey: processingKey)
            
            store.addDiamonds(diamonds, source: .iap) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        // 🔧 关键改进：根据LeanCloud开发指南和App Store要求
                        // 只有当服务器同步成功后才标记交易为已处理
                        // addDiamonds的success回调表示服务器同步成功（因为失败会进入待同步队列）
                        // 因此可以安全地标记交易为已处理并完成交易
                        UserDefaults.standard.set(true, forKey: processedKey)
                        UserDefaults.standard.set(false, forKey: processingKey) // 清除处理标记
                        
                        // 🎯 新增：充值成功后，更新该用户所有推荐记录的综合点赞数
                        self.updateRecommendationEffectiveLikeCountAfterRecharge()
                        
                        // 🎯 新增：充值成功后，更新排行榜的积分（totalScore）
                        self.updateUserScoreAfterRecharge()
                        
                    case .failure(let error):
                        // 🔧 改进：检查是否是API限制错误，如果是，延迟重试而不是立即失败
                        if case .serverError(let message) = error, (message.contains("API限制") || message.contains("429") || message.contains("140")) {
                            // API限制错误，保留交易以便稍后重试
                            // 不标记为已处理，不清除processing标记，让系统稍后重试
                        } else {
                            // 其他错误，清除处理标记，允许重试
                            UserDefaults.standard.set(false, forKey: processingKey)
                        }
                    }
                }
            }
        } else {
        }
    }
    
    // 🎯 新增：处理待处理的IAP交易
    private func processPendingIAPTransactions() {
        // 🔧 修复：使用串行队列保护待处理队列的并发访问
        var transactions: [PendingIAPTransaction] = []
        var shouldProcess = false
        
        pendingTransactionsQueue.sync {
            guard diamondStore != nil, !pendingIAPTransactions.isEmpty else {
                return
            }
            
            shouldProcess = true
            transactions = pendingIAPTransactions
            pendingIAPTransactions.removeAll()
        }
        
        guard shouldProcess, let store = diamondStore, !transactions.isEmpty else {
            if !shouldProcess {
            } else if diamondStore == nil {
            } else if transactions.isEmpty {
            }
            return
        }
        
        
        for transaction in transactions {
            let processedKey = "processed_transaction_\(transaction.transactionId)"
            let wasProcessed = UserDefaults.standard.bool(forKey: processedKey)
            
            
            if wasProcessed {
                let processingKey = "processing_transaction_\(transaction.transactionId)"
                UserDefaults.standard.set(false, forKey: processingKey)
                continue
            }
            
            let processingKey = "processing_transaction_\(transaction.transactionId)"
            let isProcessing = UserDefaults.standard.bool(forKey: processingKey)
            // 🔧 修复：处理所有待处理交易，不管processing标记（因为可能是DiamondStore未初始化时保存的）
            
            // 🔧 修复：如果processing标记为true，说明可能正在处理，但我们仍然要处理（因为这是从待处理队列中取出的）
            // 如果processing标记为false，设置它以防止并发
            if !isProcessing {
                UserDefaults.standard.set(true, forKey: processingKey)
            } else {
            }
            
            store.addDiamonds(transaction.diamonds, source: .iap) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        UserDefaults.standard.set(true, forKey: processedKey)
                        UserDefaults.standard.set(false, forKey: processingKey)
                    case .failure:
                        UserDefaults.standard.set(false, forKey: processingKey)
                        // 重新加入队列以便重试（使用串行队列保护）
                        if let self = self {
                            self.pendingTransactionsQueue.sync {
                                self.pendingIAPTransactions.append(transaction)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // 设置当前用户信息
    func setCurrentUser(userId: String, loginType: String, userName: String? = nil, userEmail: String? = nil) {
        self.currentUserId = userId
        self.currentLoginType = loginType
        self.currentUserName = userName
        self.currentUserEmail = userEmail
        self.isServerConnected = true
        
        // 🎯 修改：创建或获取 DiamondStore 实例
        diamondStore = DiamondStore(userId: userId, loginType: loginType)
        
        // 🔧 修复：处理待处理的IAP交易
        // 延迟一小段时间，确保DiamondStore完全初始化
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            var delayedQueueSize = 0
            self.pendingTransactionsQueue.sync {
                delayedQueueSize = self.pendingIAPTransactions.count
            }
            if delayedQueueSize > 0 {
                self.processPendingIAPTransactions()
            }
        }
        
        // 监听 DiamondStore 的余额变化，同步到 DiamondManager
        diamondStore?.$balance
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newBalance in
                guard let self = self else { return }
                let oldDiamonds = self.diamonds
                // 🎯 优化：使用动画更新钻石数，避免闪烁
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.diamonds = newBalance.amount
                }
                if oldDiamonds != newBalance.amount {
                }
                var queueSize = 0
                self.pendingTransactionsQueue.sync {
                    queueSize = self.pendingIAPTransactions.count
                }
                
                // 🔧 新增：当DiamondStore余额稳定后，检查并处理待处理交易
                if !newBalance.isDirty && queueSize > 0 {
                    // 延迟一小段时间，确保DiamondStore完全初始化
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        var delayedQueueSize = 0
                        self.pendingTransactionsQueue.sync {
                            delayedQueueSize = self.pendingIAPTransactions.count
                        }
                        if delayedQueueSize > 0 {
                            self.processPendingIAPTransactions()
                        }
                    }
                }
                
                self.isServerConnected = !newBalance.isDirty || self.diamondStore?.lastSyncTime != nil
                // 🎯 优化：只在真正的长时间操作时显示加载状态（如 spendDiamonds）
                // self?.isLoading = self?.diamondStore?.isSyncing ?? false
            }
            .store(in: &cancellables)
        
        // 🎯 优化：移除自动同步 isSyncing 到 isLoading
        // 只在真正的长时间操作时手动设置 isLoading（如 spendDiamonds 时）
        // diamondStore?.$isSyncing
        //     .receive(on: DispatchQueue.main)
        //     .assign(to: \.isLoading, on: self)
        //     .store(in: &cancellables)
        
        // 初始化余额
        let initialBalance = diamondStore?.getBalance() ?? 0
        self.diamonds = initialBalance
        self.diamondRetryCount = 0 // 🔧 新增：初始化时重置重试计数器
        
        // 🎯 删除新用户判断逻辑，改为在打开个人信息界面或用户头像界面时自动创建
        // 从服务器刷新余额（DiamondStore 会自动处理）
        DispatchQueue.main.async {
            self.diamondStore?.refreshBalanceFromServer { result in
                switch result {
                case .success:
                    break
                case .failure:
                    break
                }
            }
            
            self.loadUserNameFromServer()
            self.loadUserAvatarFromServer()
            self.loadOwnedAvatarsFromServer()
        }
    }
    
    // 清除用户信息（退出登录时调用）
    func clearUser() {
        // 取消所有订阅
        cancellables.removeAll()
        
        currentUserId = nil
        currentLoginType = nil
        currentUserName = nil
        currentUserEmail = nil
        diamonds = 0
        ownedAvatars = []
        isServerConnected = false
        diamondStore = nil
        diamondRetryCount = 0 // 🔧 新增：重置重试计数器
        isRecheckingBalance = false // 🔧 新增：重置重试状态
    }
    
    // 对外暴露：重新从服务器加载余额
    func retryPendingDiamondSync() {
        diamondStore?.refreshBalanceFromServer { _ in }
        diamondStore?.retryPendingOperations()
    }
    
    // 检查钻石系统状态
    func checkDiamondSystemStatus() {
    }
    
    // 当余额为0时，从服务器重新检查余额
    private func recheckBalanceFromServer() {
        // 防止重复检查
        guard !isRecheckingBalance else {
            return
        }
        
        guard isServerConnected else {
            return
        }
        
        guard diamondStore != nil else {
            return
        }
        
        isRecheckingBalance = true
        
        diamondStore?.refreshBalanceFromServer { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isRecheckingBalance = false
                
                if case .success(let newBalance) = result {
                    // 如果服务器余额不为0，发送通知
                    if newBalance != 0 {
                        NotificationCenter.default.post(
                            name: .diamondBalanceUpdated,
                            object: nil,
                            userInfo: ["newBalance": newBalance]
                        )
                    }
                }
            }
        }
    }
    
    // 🔧 新增：检查是否显示0钻石（类似isShowingUnknownUser）
    var isShowingZeroDiamonds: Bool {
        return diamonds == 0
    }
    
    // 🔧 新增：重试查询钻石余额（最多重试2次，类似retryLoadUserNameFromServer）
    func retryLoadDiamondsFromServer() {
        guard diamondRetryCount < 2 else {
            return
        }
        
        guard diamondStore != nil else {
            return
        }
        
        diamondRetryCount += 1
        
        // 🎯 根据重试次数决定延迟时间（与用户名重试机制一致）
        // 第一次重试：延迟1/17秒；第二次重试：延迟0.5秒
        let delay: TimeInterval = diamondRetryCount == 1 ? 1.0 / 17.0 : 0.5
        
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // 检查钻石数仍为0（查询失败的情况）
            if self.diamonds == 0 {
                self.diamondStore?.refreshBalanceFromServer { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let amount):
                            if amount > 0 {
                            }
                        case .failure:
                            break
                        }
                    }
                }
            } else {
            }
        }
    }
    
    // 🎯 新增：对外暴露的钻石余额刷新方法（用于充值界面调用）
    func refreshBalanceFromServer(completion: @escaping (Result<Int, DiamondError>) -> Void) {
        guard let store = diamondStore else {
            completion(.failure(.operationFailed))
            return
        }
        
        // 🔧 关键修复：主动查询时应该接受服务器值大于本地值的情况
        // 这是用户主动打开充值界面查询，应该无条件接受服务器的真实值
        store.refreshBalanceFromServer(acceptLargerValue: true) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let amount):
                    // DiamondStore 的 refreshBalanceFromServer 会自动：
                    // 1. 更新 store.balance（触发 @Published）
                    // 2. 调用 saveBalanceToUserDefaults() 更新缓存
                    // 3. DiamondManager 监听 store.$balance 会自动更新 self.diamonds
                    // 4. RechargeView 作为 @ObservedObject 会自动刷新 UI
                    completion(.success(amount))
                    
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    // 🎯 新增：充值成功后更新所有推荐记录的综合点赞数
    private func updateRecommendationEffectiveLikeCountAfterRecharge() {
        // 使用已保存的当前用户信息
        guard let userId = self.currentUserId,
              let loginType = self.currentLoginType else {
            return
        }
        
        let newDiamonds = self.diamonds
        
        // 调用 LeanCloudService 批量更新该用户的所有推荐记录
        LeanCloudService.shared.updateAllRecommendationsEffectiveLikeCount(
            userId: userId,
            loginType: loginType,
            newDiamonds: newDiamonds
        ) { _, _ in
        }
    }
    
    // 🎯 新增：充值成功后更新排行榜积分（UserScore 的 totalScore）
    // 🔧 处理方式与寻找按钮保持一致，但不包含位置信息
    private func updateUserScoreAfterRecharge() {
        // 使用已保存的当前用户信息
        guard let userId = self.currentUserId,
              let loginType = self.currentLoginType else {
            return
        }
        
        let userName = self.currentUserName ?? ""
        let userEmail = self.currentUserEmail
        let newDiamonds = self.diamonds
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
        
        // 🎯 构建UserScore对象（与寻找按钮一致，但不包含位置信息）
        let userScore = UserScore(
            userId: userId,
            userName: userName,
            userAvatar: "",  // 充值时不需要头像信息
            userEmail: userEmail,
            loginType: loginType,
            favoriteCount: 0,
            likeCount: 0,
            distance: nil,
            latitude: nil,   // ❌ 充值时不上传位置信息
            longitude: nil,  // ❌ 充值时不上传位置信息
            deviceId: deviceID,
            totalScore: newDiamonds
        )
        
        // 🎯 使用与寻找按钮相同的方法：uploadUserScore
        // 这会查找现有记录并更新，或创建新记录（与寻找按钮的处理方式完全一致）
        LeanCloudService.shared.uploadUserScore(
            userScore: userScore,
            locationRecordLatitude: nil,  // 不传递位置信息
            locationRecordLongitude: nil  // 不传递位置信息
        ) { updateSuccess, _ in
            if updateSuccess {
                // 🎯 与寻找按钮一致：合并当前用户的UserScore记录
                LeanCloudService.shared.mergeCurrentUserScoreRecords { mergeSuccess, _ in
                    if mergeSuccess {
                        // 合并成功
                    }
                }
                
                // 🎯 发送通知刷新排行榜
                NotificationCenter.default.post(name: NSNotification.Name("RefreshRankingList"), object: nil)
            }
        }
    }
}

// 通知名称扩展
extension Notification.Name {
    static let diamondBalanceUpdated = Notification.Name("diamondBalanceUpdated")
}
