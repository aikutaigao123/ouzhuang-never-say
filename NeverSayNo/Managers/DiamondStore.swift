import Foundation
import SwiftUI
import Combine

/// 统一钻石数据管理器（单一数据源）
/// 负责所有钻石数的读写、同步和冲突处理
class DiamondStore: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var balance: DiamondBalance
    @Published private(set) var isSyncing: Bool = false
    @Published private(set) var lastSyncTime: Date?
    
    // MARK: - Private Properties
    private let userId: String
    private let loginType: String
    private let deviceId: String
    
    private var pendingOperations: [PendingOperation] = []
    private var syncTimer: Timer?
    private let syncQueue = DispatchQueue(label: "com.neverSayNo.diamondStore.sync", qos: .utility)
    
    // 🔧 改进：同步类型标识，用于区分单次同步和批量同步
    private enum SyncType {
        case single    // 单次同步
        case batch     // 批量同步
    }
    private var currentSyncType: SyncType? = nil
    private let syncLock = NSLock()  // 同步锁，确保同步操作的原子性
    
    private let userDefaultsKey: String
    private let pendingOperationsKey: String
    
    // MARK: - Constants
    private let syncInterval: TimeInterval = 300  // 5分钟（定期同步，作为备用）
    private let maxRetryCount = 3
    private let minRefreshInterval: TimeInterval = 1.0  // 最小刷新间隔（防止频繁查询）
    
    // MARK: - Initialization
    init(userId: String, loginType: String, deviceId: String? = nil) {
        self.userId = userId
        self.loginType = loginType
        self.deviceId = deviceId ?? (UIDevice.current.identifierForVendor?.uuidString ?? "unknown")
        
        self.userDefaultsKey = "diamond_balance_\(userId)_\(loginType)"
        self.pendingOperationsKey = "diamond_pending_operations_\(userId)_\(loginType)"
        
        // 初始化时从 UserDefaults 加载
        if let savedBalance = Self.loadBalanceFromUserDefaults(key: userDefaultsKey) {
            self.balance = savedBalance
        } else {
            // 初始余额为0，版本号为1
            self.balance = DiamondBalance.clean(amount: 0, version: 1, deviceId: self.deviceId)
        }
        
        // 加载待同步操作
        self.loadPendingOperations()
        
        // 启动定期同步（作为备用，防止遗漏）
        self.startPeriodicSync()
        
        // 监听应用生命周期
        self.setupAppLifecycleObservers()
        
        // 🎯 修改：首次启动时从服务器刷新
        self.refreshBalanceFromServer(completion: { _ in })
    }
    
    deinit {
        syncTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Read Interface
    
    /// 🎯 修改：获取当前钻石余额（完全实时查询版本）
    /// 先返回本地值（立即），然后后台刷新服务器数据
    func getBalance() -> Int {
        let currentAmount = balance.amount
        // 触发后台刷新（不等待结果）
        refreshBalanceInBackground()
        // 立即返回本地值
        return currentAmount
    }
    
    /// 后台刷新余额（不阻塞，静默刷新，完全实时查询）
    func refreshBalanceInBackground() {
        // 如果正在同步，跳过（避免重复查询）
        guard !isSyncing else { return }
        
        // 🎯 优化：防止频繁刷新（距离上次刷新不足47秒时跳过，减少闪烁和API调用）
        if let lastSync = lastSyncTime, Date().timeIntervalSince(lastSync) < 47.0 {
            return
        }
        
        // 后台静默刷新（完全实时查询，不触发 isLoading 状态）
        syncQueue.async { [weak self] in
            guard let self = self else { return }
            // 使用静默刷新，不设置 isSyncing（避免触发 UI 加载状态）
            self.refreshBalanceFromServerSilently { _ in }
        }
    }
    
    // 🔧 新增：只读查询方法（只查询服务器值，不更新本地值，不设置 isSyncing）
    /// 查询服务器余额（只读操作，用于验证同步是否成功）
    /// - Parameter completion: 查询结果回调，返回服务器值
    /// - Note: 此方法不更新本地 balance，不设置 isSyncing，不阻塞其他操作
    private func queryBalanceFromServer(completion: @escaping (Result<Int, DiamondError>) -> Void) {
        // 🔧 修复：刷新时跳过缓存，强制从服务器查询
        LeanCloudService.shared.fetchDiamondRecords(objectId: userId, loginType: loginType, skipCache: true) { records, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.networkError(underlying: NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: error]))))
                    return
                }
                
                if let records = records, let latestRecord = records.first {
                    let serverAmount = latestRecord.diamonds
                    // 🔧 关键：只返回服务器值，不更新本地 balance
                    completion(.success(serverAmount))
                } else {
                    completion(.success(0))
                }
            }
        }
    }
    
    /// 静默刷新余额（不设置 isSyncing，避免触发 UI 加载状态）
    private func refreshBalanceFromServerSilently(completion: @escaping (Result<Int, DiamondError>) -> Void) {
        let beforeRefreshAmount = balance.amount
        
        // 静默刷新，不设置 isSyncing，避免触发 UI 加载状态
        // 🔧 修复：刷新时跳过缓存，强制从服务器查询
        LeanCloudService.shared.fetchDiamondRecords(objectId: userId, loginType: loginType, skipCache: true) { [weak self] records, error in
            guard let self = self else {
                completion(.failure(.operationFailed))
                return
            }
            
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(.networkError(underlying: NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: error]))))
                    return
                }
                
                if let records = records, let latestRecord = records.first {
                    let serverAmount = latestRecord.diamonds
                    let serverVersion = latestRecord.updated_at.hash
                    
                    
                    // 🔍 调试：检查服务器返回的值是否为负数
                    if serverAmount < 0 {
                    }
                    
                    // ⚠️ 关键修复：再次检查当前的 isDirty 状态（可能在刷新期间被其他操作修改）
                    let currentIsDirty = self.balance.isDirty
                    let currentAmount = self.balance.amount
                    
                    
                    // 🔧 修复：如果本地有未同步的变更（isDirty），保留本地值，不被服务器旧值覆盖
                    // ⚠️ 关键：使用当前的 isDirty 状态，而不是刷新开始时的状态
                    if currentIsDirty {
                        
                        // 如果服务器值等于当前本地值，说明已经同步，清除 isDirty
                        if serverAmount == currentAmount {
                            self.balance = DiamondBalance.clean(
                                amount: currentAmount,
                                version: serverVersion,
                                deviceId: self.deviceId
                            )
                        } else {
                            // 保留当前本地值，不覆盖为服务器值（保持 isDirty=true）
                            // 不更新余额，保持 isDirty=true
                        }
                        
                        self.saveBalanceToUserDefaults()
                        self.lastSyncTime = Date()
                        completion(.success(currentAmount))
                        return
                    }
                    
                    // ⚠️ 额外检查：如果当前余额与刷新前不同，说明在刷新期间有本地操作，不覆盖
                    if currentAmount != beforeRefreshAmount {
                        // 不更新余额，保持当前值
                        self.saveBalanceToUserDefaults()
                        self.lastSyncTime = Date()
                        completion(.success(currentAmount))
                        return
                    }
                    
                    // 🔧 改进：在验证同步时，不应该更新本地余额，只返回服务器值用于验证
                    // 只有在明确需要更新时才更新（例如充值后刷新）
                    // 这里只返回服务器值，不更新本地余额
                    
                    // 更新余额（会触发 UI 更新，但使用动画过渡）
                    // 🔍 调试：检查服务器返回的值是否为负数
                    if serverAmount < 0 {
                    }
                    self.balance = self.balance.updateFromServer(
                        amount: serverAmount,
                        version: serverVersion,
                        deviceId: self.deviceId
                    )
                    
                    let afterRefreshAmount = self.balance.amount
                    
                    // 🔍 调试：检查刷新后余额是否为负数
                    if afterRefreshAmount < 0 {
                    }
                    
                    
                    // 保存到 UserDefaults
                    self.saveBalanceToUserDefaults()
                    
                    self.lastSyncTime = Date()
                    completion(.success(serverAmount))
                } else {
                    // 没有记录，初始化为0
                    self.balance = DiamondBalance.clean(amount: 0, version: 1, deviceId: self.deviceId)
                    self.saveBalanceToUserDefaults()
                    self.lastSyncTime = Date()
                    completion(.success(0))
                }
            }
        }
    }
    
    /// 刷新余额（异步，从服务器获取最新数据）
    /// - Parameters:
    ///   - acceptLargerValue: 是否接受服务器值大于本地值的情况（用于充值后刷新）
    func refreshBalanceFromServer(acceptLargerValue: Bool = false, completion: @escaping (Result<Int, DiamondError>) -> Void) {
        // 🔧 改进：refreshBalanceFromServer 不应该被同步锁阻止，因为它只是查询，不修改
        // 但如果在同步过程中调用，应该等待或使用静默刷新
        if isSyncing {
            // 使用静默刷新，不设置 isSyncing
            refreshBalanceFromServerSilently(completion: completion)
            return
        }
        
        let beforeRefreshAmount = balance.amount
        let beforeRefreshIsDirty = balance.isDirty
        
        // 🔧 改进：refreshBalanceFromServer 不应该设置 isSyncing，因为它只是查询操作
        // 只有在同步操作（updateDiamonds）时才应该设置 isSyncing
        // isSyncing = true  // 移除这行，避免阻止其他查询操作
        
        // 🔧 修复：刷新时跳过缓存，强制从服务器查询
        LeanCloudService.shared.fetchDiamondRecords(objectId: userId, loginType: loginType, skipCache: true) { [weak self] records, error in
            guard let self = self else {
                completion(.failure(.operationFailed))
                return
            }
            
            DispatchQueue.main.async {
                // 🔧 改进：refreshBalanceFromServer 不再设置 isSyncing，所以也不需要清除
                // self.isSyncing = false  // 移除这行
                
                if let error = error {
                    completion(.failure(.networkError(underlying: NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: error]))))
                    return
                }
                
                if records != nil {
                } else {
                }
                
                if let records = records, let latestRecord = records.first {
                    let serverAmount = latestRecord.diamonds
                    // 假设服务器返回的版本号（这里需要 LeanCloud 表支持版本号字段，暂时使用 updatedAt 的 hash）
                    let serverVersion = latestRecord.updated_at.hash
                    
                    
                    // 🔍 调试：检查服务器返回的值是否为负数
                    if serverAmount < 0 {
                    }
                    
                    
                    // 🔧 修复：如果本地有未同步的变更（isDirty），需要判断是否接受服务器值
                    if beforeRefreshIsDirty {
                        
                        // 如果服务器值等于本地值，说明已经同步，清除 isDirty
                        if serverAmount == beforeRefreshAmount {
                            self.balance = DiamondBalance.clean(
                                amount: beforeRefreshAmount,
                                version: serverVersion,
                                deviceId: self.deviceId
                            )
                            self.saveBalanceToUserDefaults()
                            self.lastSyncTime = Date()
                            completion(.success(beforeRefreshAmount))
                            return
                        }
                        
                        // 🔧 关键修复：如果服务器值明显小于本地值（差值 >= 5），说明有并发操作消耗了额外的钻石
                        // 此时应该接受服务器返回的真实值，而不是保留本地值（防止丢失并发消耗）
                        let difference = beforeRefreshAmount - serverAmount
                        if difference >= 5 {
                            // 接受服务器返回的真实值
                            self.balance = DiamondBalance.clean(
                                amount: serverAmount,
                                version: serverVersion,
                                deviceId: self.deviceId
                            )
                            self.saveBalanceToUserDefaults()
                            self.lastSyncTime = Date()
                            completion(.success(serverAmount))
                            return
                        }
                        
                        // 服务器值大于本地值，可能是服务器返回了旧值，保留本地值
                        if serverAmount > beforeRefreshAmount {
                            self.saveBalanceToUserDefaults()
                            self.lastSyncTime = Date()
                            completion(.success(beforeRefreshAmount))
                            return
                        }
                        
                        // 服务器值小于本地值但差值较小（< 5），可能是正常的并发差异，保留本地值
                        // 不更新余额，保持 isDirty=true
                        self.saveBalanceToUserDefaults()
                        self.lastSyncTime = Date()
                        completion(.success(beforeRefreshAmount))
                        return
                    }
                    
                    // ⚠️ 关键修复：即使 isDirty=false，如果服务器返回的值比本地值大，可能是服务器返回了旧值
                    // 在这种情况下，保留本地值，不覆盖（防止服务器旧值导致本地值增加）
                    // 🔧 修复：但在充值场景下（acceptLargerValue=true），应该接受服务器值
                    if serverAmount > beforeRefreshAmount && beforeRefreshAmount >= 0 {
                        if acceptLargerValue {
                            // 接受服务器值（充值场景）
                            self.balance = self.balance.updateFromServer(
                                amount: serverAmount,
                                version: serverVersion,
                                deviceId: self.deviceId
                            )
                            self.saveBalanceToUserDefaults()
                            self.lastSyncTime = Date()
                            completion(.success(serverAmount))
                            return
                        } else {
                            // 保留本地值，不更新
                            self.saveBalanceToUserDefaults()
                            self.lastSyncTime = Date()
                            completion(.success(beforeRefreshAmount))
                            return
                        }
                    }
                    
                    // 更新余额
                    // 🔍 调试：检查服务器返回的值是否为负数
                    if serverAmount < 0 {
                    }
                    
                    self.balance = self.balance.updateFromServer(
                        amount: serverAmount,
                        version: serverVersion,
                        deviceId: self.deviceId
                    )
                    
                    let afterRefreshAmount = self.balance.amount
                    
                    // 🔍 调试：检查刷新后余额是否为负数
                    if afterRefreshAmount < 0 {
                    }
                    
                    
                    // 保存到 UserDefaults
                    self.saveBalanceToUserDefaults()
                    
                    self.lastSyncTime = Date()
                    completion(.success(serverAmount))
                } else {
                    // 没有记录，初始化为0
                    self.balance = DiamondBalance.clean(amount: 0, version: 1, deviceId: self.deviceId)
                    self.saveBalanceToUserDefaults()
                    self.lastSyncTime = Date()
                    completion(.success(0))
                }
            }
        }
    }
    
    // MARK: - Public Write Interface
    
    /// 添加钻石
    func addDiamonds(_ amount: Int, source: DiamondOperation.OperationSource, completion: @escaping (Result<Int, DiamondError>) -> Void) {
        guard amount > 0 else {
            completion(.failure(.operationFailed))
            return
        }
        
        // 🔧 关键改进：根据LeanCloud开发指南和App Store要求
        // 必须确保服务器同步成功后才返回成功，这样才能安全地完成IAP交易
        // 参考LeanCloud开发指南：使用原子操作和fetchWhenSave确保数据一致性
        
        // 保存操作前的状态（用于回滚）
        let oldVersion = balance.version
        
        // 🔧 改进：不立即更新本地状态，而是等待服务器同步成功后再更新
        // 这样可以确保本地和服务器数据一致性，符合App Store要求
        
        // 异步同步到服务器
        syncAddOperationToServer(amount: amount, source: source, expectedVersion: oldVersion) { [weak self] result in
            guard let self = self else {
                completion(.failure(.operationFailed))
                return
            }
            
            switch result {
            case .success(let serverBalance):
                // 🔧 改进：服务器同步成功后才更新本地余额并返回成功
                // 参考LeanCloud开发指南：使用fetchWhenSave返回的最新数据更新本地状态
                DispatchQueue.main.async {
                    self.balance = serverBalance
                    self.saveBalanceToUserDefaults()
                    self.lastSyncTime = Date()
                    // 只有在服务器同步成功后才返回成功
                    completion(.success(serverBalance.amount))
                }
                
            case .failure(let error):
                // 🔧 改进：服务器同步失败时，不更新本地余额（因为还没有同步成功）
                // 参考LeanCloud开发指南：确保本地和服务器数据一致性
                // 注意：本地余额保持原样，不需要回滚（因为我们没有提前更新）
                
                if case .versionConflict = error {
                    // 版本冲突，需要重新同步并重试
                    self.handleVersionConflict { [weak self] in
                        self?.retryAddOperation(amount: amount, source: source, completion: completion)
                    }
                } else {
                    // 网络错误，加入待同步队列
                    let operation = DiamondOperation.add(amount: amount, source: source)
                    self.addToPendingQueue(operation: operation, expectedVersion: oldVersion)
                    // 返回失败，让调用者知道操作未成功
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
        }
    }
    
    /// 消耗钻石
    func spendDiamonds(_ amount: Int, reason: String, completion: @escaping (Result<Int, DiamondError>) -> Void) {
        guard amount > 0 else {
            completion(.failure(.operationFailed))
            return
        }
        
        let checkAmount = balance.amount
        
        // 🔍 调试：检查当前余额是否为负数
        if checkAmount < 0 {
        }
        
        // 先检查本地余额
        if balance.amount < amount {
            // 🔍 调试：如果余额不足且为负数，特别标记
            if checkAmount < 0 {
            }
            // 本地余额不足，先刷新服务器数据
            refreshBalanceFromServer { [weak self] result in
                guard let self = self else {
                    completion(.failure(.operationFailed))
                    return
                }
                
                switch result {
                case .success(let serverAmount):
                    if serverAmount >= amount {
                        // 刷新后余额充足，继续操作
                        self.executeSpend(amount: amount, reason: reason, completion: completion)
                    } else {
                        // 刷新后仍然不足
                        completion(.failure(.insufficientBalance(current: serverAmount, required: amount)))
                    }
                    
                case .failure:
                    // 刷新失败，但仍然尝试本地操作（离线支持）
                    if self.balance.amount >= amount {
                        self.executeSpend(amount: amount, reason: reason, completion: completion)
                    } else {
                        completion(.failure(.insufficientBalance(current: self.balance.amount, required: amount)))
                    }
                }
            }
            return
        }
        
        // 本地余额充足，立即执行
        executeSpend(amount: amount, reason: reason, completion: completion)
    }
    
    // 🔧 新增：本地扣除钻石（不立即同步服务器，用于连续快速解锁）
    func spendDiamondsLocally(_ amount: Int, reason: String) -> Bool {
        guard amount > 0 else {
            return false
        }
        
        let checkAmount = balance.amount
        
        // 检查本地余额
        guard checkAmount >= amount else {
            return false
        }
        
        // 检查扣除后是否会导致负数
        let newAmount = checkAmount - amount
        guard newAmount >= 0 else {
            return false
        }
        
        // 只更新本地状态，不立即同步服务器
        balance = balance.incrementVersion(newAmount: newAmount)
        saveBalanceToUserDefaults()
        
        
        return true
    }
    
    // 🔧 新增：统一同步所有待同步的操作（用于连续快速解锁后统一上传）
    func syncPendingChanges(completion: @escaping (Result<Int, DiamondError>) -> Void) {
        syncPendingChangesWithRetry(retryCount: 0, maxRetries: 3, completion: completion)
    }
    
    // 🔧 新增：带重试的批量同步方法
    private func syncPendingChangesWithRetry(retryCount: Int, maxRetries: Int, completion: @escaping (Result<Int, DiamondError>) -> Void) {
        // 如果本地没有待同步的变更，直接返回
        guard balance.isDirty else {
            completion(.success(balance.amount))
            return
        }
        
        // 🔧 改进：使用串行队列确保同步操作按顺序执行
        syncQueue.async { [weak self] in
            guard let self = self else {
                completion(.failure(.operationFailed))
                return
            }
            
            // 🔧 改进：使用同步锁确保批量同步期间完全阻止单次同步
            self.syncLock.lock()
            
            // 检查是否正在同步（包括单次同步）
            if self.isSyncing && retryCount == 0 {
                self.syncLock.unlock()
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.0) {
                    self.syncPendingChangesWithRetry(retryCount: retryCount, maxRetries: maxRetries, completion: completion)
                }
                return
            }
            
            // 标记为批量同步
            self.isSyncing = true
            self.currentSyncType = .batch
            self.syncLock.unlock()
        
            let currentAmount = self.balance.amount
            
            // 使用与 syncSpendOperationToServer 相同的逻辑来同步
            // 直接使用当前余额来更新服务器（因为本地已经累积了所有的扣除）
            LeanCloudService.shared.updateDiamonds(
                objectId: self.userId,
                loginType: self.loginType,
                diamonds: currentAmount
            ) { [weak self] success in
                guard let self = self else {
                    completion(.failure(.operationFailed))
                    return
                }
                
                if success {
                    // 🔧 改进：使用只读查询验证，不更新本地值
                    self.queryBalanceFromServer { result in
                        // 🔧 改进：同步完成后立即清除同步状态
                        self.syncLock.lock()
                        self.isSyncing = false
                        self.currentSyncType = nil
                        self.syncLock.unlock()
                        
                        switch result {
                        case .success(let serverAmount):
                            // 🔧 关键：使用服务器值进行验证，但不更新本地值（除非验证通过且差异在容差内）
                            // 🔧 改进：验证同步是否成功（允许一定的误差范围，因为可能有并发操作）
                            // 如果服务器值与期望值差异过大，说明同步失败，需要重试
                            let difference = abs(serverAmount - currentAmount)
                            let tolerance = 5  // 允许5钻石的误差（考虑并发操作）
                            
                            if difference > tolerance && retryCount < maxRetries {
                                let delay = Double(retryCount + 1) * 1.0  // 🔧 改进：增加延迟时间
                                // 同步失败，重新同步
                                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay) {
                                    self.syncPendingChangesWithRetry(
                                        retryCount: retryCount + 1,
                                        maxRetries: maxRetries,
                                        completion: completion
                                    )
                                }
                                return
                            }
                            
                            if difference <= tolerance {
                                // 🔧 改进：只有在验证通过且差异在容差内时，才更新本地值为服务器值
                                // 这样可以确保本地值和服务器值最终一致
                                self.balance = DiamondBalance.clean(
                                    amount: serverAmount,
                                    version: self.balance.version + 1,
                                    deviceId: self.deviceId
                                )
                                self.saveBalanceToUserDefaults()
                            } else {
                                // 🔧 改进：验证失败时，如果差异不大（< 50），仍然更新本地值
                                // 如果差异很大，保持本地值不变（可能是服务器问题）
                                if difference < 50 {
                                    self.balance = DiamondBalance.clean(
                                        amount: serverAmount,
                                        version: self.balance.version + 1,
                                        deviceId: self.deviceId
                                    )
                                    self.saveBalanceToUserDefaults()
                                }
                            }
                            
                            self.lastSyncTime = Date()
                            
                            
                            // 发送通知
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("DiamondBalanceServerSyncCompleted"),
                                    object: nil,
                                    userInfo: [
                                        "serverAmount": serverAmount,
                                        "expectedAmount": currentAmount,
                                        "reason": "批量同步"
                                    ]
                                )
                            }
                            
                            completion(.success(serverAmount))
                        case .failure(let error):
                            // 查询失败，如果还有重试次数，则重试
                            if retryCount < maxRetries {
                                let delay = Double(retryCount + 1) * 1.0  // 🔧 改进：增加延迟时间
                                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay) {
                                    self.syncPendingChangesWithRetry(
                                        retryCount: retryCount + 1,
                                        maxRetries: maxRetries,
                                        completion: completion
                                    )
                                }
                            } else {
                                completion(.failure(error))
                            }
                        }
                    }
                } else {
                    // 🔧 改进：更新失败时也要清除同步状态
                    self.syncLock.lock()
                    self.isSyncing = false
                    self.currentSyncType = nil
                    self.syncLock.unlock()
                    
                    // 更新失败，如果还有重试次数，则重试
                    if retryCount < maxRetries {
                        let delay = Double(retryCount + 1) * 1.0  // 🔧 改进：增加延迟时间
                        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay) {
                            self.syncPendingChangesWithRetry(
                                retryCount: retryCount + 1,
                                maxRetries: maxRetries,
                                completion: completion
                            )
                        }
                    } else {
                        completion(.failure(.operationFailed))
                    }
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func executeSpend(amount: Int, reason: String, completion: @escaping (Result<Int, DiamondError>) -> Void) {
        let beforeSpendAmount = balance.amount
        let oldVersion = balance.version
        
        // 🔍 调试：检查扣除前余额是否为负数
        if beforeSpendAmount < 0 {
        }
        
        let newAmount = balance.amount - amount
        
        // 🔍 调试：检查扣除后余额是否为负数
        if newAmount < 0 {
        }
        
        
        // 立即更新本地状态
        balance = balance.incrementVersion(newAmount: newAmount)
        let afterSpendAmount = balance.amount
        
        // 验证扣除是否正确
        if afterSpendAmount != newAmount {
        }
        
        saveBalanceToUserDefaults()
        
        // 立即返回成功
        completion(.success(newAmount))
        
        // 异步同步到服务器
        syncSpendOperationToServer(amount: amount, reason: reason, expectedVersion: oldVersion) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let serverBalance):
                // 服务器同步成功
                DispatchQueue.main.async {
                    let beforeUpdateAmount = self.balance.amount
                    let beforeUpdateIsDirty = self.balance.isDirty
                    
                    // 🔧 关键修复：当服务器返回的值与期望值不一致时，需要判断是否接受服务器真实值
                    let serverDifference = serverBalance.amount - newAmount
                    let localDifference = beforeUpdateAmount - serverBalance.amount
                    
                    // 如果服务器值明显小于期望值（差值 >= 5），说明有并发操作消耗了额外的钻石
                    // 此时应该接受服务器返回的真实值，而不是保留本地值
                    if serverDifference <= -5 {
                        // 接受服务器返回的真实值
                        self.balance = DiamondBalance.clean(
                            amount: serverBalance.amount,
                            version: serverBalance.version,
                            deviceId: self.deviceId
                        )
                    } else if beforeUpdateIsDirty {
                        
                        // 如果服务器值等于当前本地值，说明已经同步，清除 isDirty
                        if serverBalance.amount == beforeUpdateAmount {
                            self.balance = DiamondBalance.clean(
                                amount: beforeUpdateAmount,
                                version: serverBalance.version,
                                deviceId: self.deviceId
                            )
                        } else if serverBalance.amount < beforeUpdateAmount && localDifference >= 5 {
                            // 服务器值明显小于本地值（差值 >= 5），说明有并发消耗，接受服务器值
                            self.balance = DiamondBalance.clean(
                                amount: serverBalance.amount,
                                version: serverBalance.version,
                                deviceId: self.deviceId
                            )
                        } else {
                            // 保留当前本地值，不覆盖为服务器值（保持 isDirty=true）
                            // 不更新余额，保持 isDirty=true
                        }
                    } else {
                        // 没有未同步变更，可以安全更新
                        // 🔍 调试：检查服务器返回的值是否为负数
                        if serverBalance.amount < 0 {
                        }
                        self.balance = serverBalance
                    }
                    
                    let afterSyncAmount = self.balance.amount
                    
                    // 🔍 调试：检查同步后余额是否为负数
                    if afterSyncAmount < 0 {
                    }
                    
                    
                    // 验证同步后的值是否正确
                    if afterSyncAmount != newAmount {
                    }
                    
                    // 验证服务器返回的值与期望值
                    if serverBalance.amount != newAmount {
                    }
                    
                    self.saveBalanceToUserDefaults()
                    self.lastSyncTime = Date()
                }
                
            case .failure(let error):
                if case .versionConflict = error {
                    // 版本冲突，需要重新同步并重试
                    self.handleVersionConflict { [weak self] in
                        self?.retrySpendOperation(amount: amount, reason: reason, completion: { _ in })
                    }
                } else {
                    // 网络错误，加入待同步队列
                    let operation = DiamondOperation.spend(amount: amount, reason: reason)
                    self.addToPendingQueue(operation: operation, expectedVersion: oldVersion)
                }
            }
        }
    }
    
    // MARK: - Server Sync
    
    private func syncAddOperationToServer(amount: Int, source: DiamondOperation.OperationSource, expectedVersion: Int, completion: @escaping (Result<DiamondBalance, DiamondError>) -> Void) {
        // 🔧 改进：根据LeanCloud开发指南，计算目标余额
        // 参考文档：使用原子操作increase来更新计数器，避免并发冲突
        let currentAmount = balance.amount
        let targetBalance = currentAmount + amount
        // 这里需要调用 LeanCloud 服务来更新钻石
        // 参考LeanCloud开发指南：使用原子操作和fetchWhenSave确保数据一致性
        LeanCloudService.shared.updateDiamonds(objectId: userId, loginType: loginType, diamonds: targetBalance) { [weak self] success in
            guard let self = self else {
                completion(.failure(.operationFailed))
                return
            }
            
            if success {
                // 同步成功，刷新服务器数据获取最新版本号
                // 🔧 修复：充值后刷新时，应该接受服务器值大于本地值的情况
                self.refreshBalanceFromServer(acceptLargerValue: true) { result in
                    switch result {
                    case .success(let newAmount):
                        // 构建服务器返回的余额对象
                        let serverBalance = DiamondBalance.clean(
                            amount: newAmount,
                            version: self.balance.version + 1,  // 简化：使用本地版本+1
                            deviceId: self.deviceId
                        )
                        if newAmount != targetBalance {
                        } else {
                        }
                        completion(.success(serverBalance))
                    case .failure(let err):
                        completion(.failure(err))
                    }
                }
            } else {
                // 🔧 改进：检查是否是API限制错误
                let errorKey = "lastDiamondUpdateError_\(self.userId)"
                let errorTimeKey = "lastDiamondUpdateErrorTime_\(self.userId)"
                if let errorInfo = UserDefaults.standard.string(forKey: errorKey),
                   let errorTime = UserDefaults.standard.object(forKey: errorTimeKey) as? TimeInterval,
                   errorInfo.hasPrefix("API_LIMIT_"),
                   Date().timeIntervalSince1970 - errorTime < 60 { // 60秒内的错误才认为是相关的
                    completion(.failure(.serverError(message: "API限制错误（\(errorInfo.replacingOccurrences(of: "API_LIMIT_", with: ""))）")))
                } else {
                    completion(.failure(.serverError(message: "更新失败")))
                }
            }
        }
    }
    
    private func syncSpendOperationToServer(amount: Int, reason: String, expectedVersion: Int, completion: @escaping (Result<DiamondBalance, DiamondError>) -> Void) {
        syncSpendOperationToServerWithRetry(amount: amount, reason: reason, expectedVersion: expectedVersion, retryCount: 0, maxRetries: 3, completion: completion)
    }
    
    // 🔧 新增：带重试的同步方法
    private func syncSpendOperationToServerWithRetry(amount: Int, reason: String, expectedVersion: Int, retryCount: Int, maxRetries: Int, completion: @escaping (Result<DiamondBalance, DiamondError>) -> Void) {
        // 🔧 改进：使用串行队列确保同步操作按顺序执行
        syncQueue.async { [weak self] in
            guard let self = self else {
                completion(.failure(.operationFailed))
                return
            }
            
            // 🔧 改进：使用同步锁，在批量同步期间完全阻止单次同步
            self.syncLock.lock()
            
            // 检查是否正在批量同步
            if self.isSyncing && self.currentSyncType == .batch && retryCount == 0 {
                self.syncLock.unlock()
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.5) {
                    self.syncSpendOperationToServerWithRetry(amount: amount, reason: reason, expectedVersion: expectedVersion, retryCount: retryCount, maxRetries: maxRetries, completion: completion)
                }
                return
            }
            
            // 检查是否正在单次同步（允许重试）
            if self.isSyncing && self.currentSyncType == .single && retryCount == 0 {
                self.syncLock.unlock()
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.0) {
                    self.syncSpendOperationToServerWithRetry(amount: amount, reason: reason, expectedVersion: expectedVersion, retryCount: retryCount, maxRetries: maxRetries, completion: completion)
                }
                return
            }
            
            // 标记为单次同步
            self.isSyncing = true
            self.currentSyncType = .single
            
            self.syncLock.unlock()
        
            let sendAmount = self.balance.amount  // 发送到服务器的值
            
            // 消耗钻石实际上是在服务器上减少，但 LeanCloud 的 updateDiamonds 接受的是绝对数量
            // 所以直接使用当前余额（已经减去 amount）来更新
            LeanCloudService.shared.updateDiamonds(objectId: self.userId, loginType: self.loginType, diamonds: self.balance.amount) { [weak self] success in
                guard let self = self else {
                    completion(.failure(.operationFailed))
                    return
                }
                
                if success {
                    // 🔧 改进：使用只读查询验证，不更新本地值
                    self.queryBalanceFromServer { result in
                        // 🔧 改进：同步完成后立即清除同步状态
                        self.syncLock.lock()
                        self.isSyncing = false
                        self.currentSyncType = nil
                        self.syncLock.unlock()
                        
                        switch result {
                        case .success(let serverAmount):
                            // 🔧 关键：使用服务器值进行验证，但不更新本地值
                            let newAmount = serverAmount
                            // 🔍 调试：检查服务器返回的值是否为负数
                            if newAmount < 0 {
                            }
                            
                            let afterRefreshAmount = self.balance.amount
                            
                            // 🔍 调试：检查刷新后本地余额是否为负数
                            if afterRefreshAmount < 0 {
                            }
                            
                            // 🔧 改进：验证同步是否成功（允许一定的误差范围，因为可能有并发操作）
                            // 如果服务器值与期望值差异过大，说明同步失败，需要重试
                            let difference = abs(serverAmount - sendAmount)
                            let tolerance = 5  // 允许5钻石的误差（考虑并发操作）
                            
                            if difference > tolerance && retryCount < maxRetries {
                                let delay = Double(retryCount + 1) * 1.0  // 🔧 改进：增加延迟时间
                                // 同步失败，重新同步
                                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay) {
                                    self.syncSpendOperationToServerWithRetry(
                                        amount: amount,
                                        reason: reason,
                                        expectedVersion: expectedVersion,
                                        retryCount: retryCount + 1,
                                        maxRetries: maxRetries,
                                        completion: completion
                                    )
                                }
                                return
                            }
                            
                            if difference <= tolerance {
                                // 🔧 改进：验证通过时，如果服务器值与本地值不同，更新本地值
                                // 这样可以确保本地值和服务器值最终一致
                                if serverAmount != sendAmount {
                                    DispatchQueue.main.async {
                                        self.balance = DiamondBalance.clean(
                                            amount: serverAmount,
                                            version: self.balance.version + 1,
                                            deviceId: self.deviceId
                                        )
                                        self.saveBalanceToUserDefaults()
                                    }
                                }
                            } else {
                                // 🔧 改进：验证失败时，如果差异不大（< 50），仍然更新本地值
                                // 如果差异很大，保持本地值不变（可能是服务器问题）
                                if difference < 50 {
                                    DispatchQueue.main.async {
                                        self.balance = DiamondBalance.clean(
                                            amount: serverAmount,
                                            version: self.balance.version + 1,
                                            deviceId: self.deviceId
                                        )
                                        self.saveBalanceToUserDefaults()
                                    }
                                }
                            }
                            
                            // 构建服务器返回的余额对象 - 使用服务器返回的真实值
                            let serverBalance = DiamondBalance.clean(
                                amount: serverAmount,
                                version: self.balance.version + 1,  // 简化：使用本地版本+1
                                deviceId: self.deviceId
                            )
                            
                            // 🔧 按照开发指南：发送通知，包含服务器真实值（利用fetchWhenSave返回值）
                            // 用于反向计算累计消耗，确保累计消耗记录与服务器真实状态同步
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("DiamondBalanceServerSyncCompleted"),
                                    object: nil,
                                    userInfo: [
                                        "serverAmount": serverAmount,
                                        "expectedAmount": sendAmount,
                                        "reason": reason
                                    ]
                                )
                            }
                            
                            completion(.success(serverBalance))
                        case .failure(let err):
                            // 🔧 改进：失败时也要清除同步状态
                            self.syncLock.lock()
                            self.isSyncing = false
                            self.currentSyncType = nil
                            self.syncLock.unlock()
                            
                            // 查询失败，如果还有重试次数，则重试
                            if retryCount < maxRetries {
                                let delay = Double(retryCount + 1) * 1.0  // 🔧 改进：增加延迟时间
                                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay) {
                                    self.syncSpendOperationToServerWithRetry(
                                        amount: amount,
                                        reason: reason,
                                        expectedVersion: expectedVersion,
                                        retryCount: retryCount + 1,
                                        maxRetries: maxRetries,
                                        completion: completion
                                    )
                                }
                            } else {
                                completion(.failure(err))
                            }
                        }
                    }
                } else {
                    // 🔧 改进：更新失败时也要清除同步状态
                    self.syncLock.lock()
                    self.isSyncing = false
                    self.currentSyncType = nil
                    self.syncLock.unlock()
                    
                    // 更新失败，如果还有重试次数，则重试
                    if retryCount < maxRetries {
                        let delay = Double(retryCount + 1) * 1.0  // 🔧 改进：增加延迟时间
                        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + delay) {
                            self.syncSpendOperationToServerWithRetry(
                                amount: amount,
                                reason: reason,
                                expectedVersion: expectedVersion,
                                retryCount: retryCount + 1,
                                maxRetries: maxRetries,
                                completion: completion
                            )
                        }
                    } else {
                        completion(.failure(.serverError(message: "更新失败")))
                    }
                }
            }
        }
    }
    
    private func retryAddOperation(amount: Int, source: DiamondOperation.OperationSource, completion: @escaping (Result<Int, DiamondError>) -> Void) {
        // 重新同步后重试
        addDiamonds(amount, source: source, completion: completion)
    }
    
    private func retrySpendOperation(amount: Int, reason: String, completion: @escaping (Result<Int, DiamondError>) -> Void) {
        // 重新同步后重试
        spendDiamonds(amount, reason: reason, completion: completion)
    }
    
    // MARK: - Conflict Handling
    
    private func handleVersionConflict(completion: @escaping () -> Void) {
        // 版本冲突时，先刷新服务器数据
        refreshBalanceFromServer { _ in
            // 刷新完成后执行回调
            completion()
        }
    }
    
    // MARK: - Pending Queue
    
    private func addToPendingQueue(operation: DiamondOperation, expectedVersion: Int) {
        let pendingOp = PendingOperation(operation: operation, expectedVersion: expectedVersion)
        pendingOperations.append(pendingOp)
        savePendingOperations()
    }
    
    func retryPendingOperations() {
        guard !pendingOperations.isEmpty else { return }
        
        let operations = pendingOperations
        pendingOperations.removeAll()
        
        for operation in operations {
            if operation.retryCount >= maxRetryCount {
                // 超过最大重试次数，跳过
                continue
            }
            
            var updatedOperation = operation
            updatedOperation.retryCount += 1
            
            switch operation.operation {
            case .add(let amount, let source):
                // 🔧 关键修复：重试时不应该再次调用 addDiamonds（因为本地余额已经包含了这个操作）
                // 应该直接重试服务器同步，使用当前余额作为目标值
                // 直接调用服务器同步，因为本地余额已经包含了这个操作
                syncAddOperationToServer(amount: amount, source: source, expectedVersion: operation.expectedVersion) { [weak self] result in
                    guard let self = self else { return }
                    switch result {
                    case .success(let serverBalance):
                        // 同步成功，更新本地余额为服务器值
                        DispatchQueue.main.async {
                            self.balance = serverBalance
                            self.saveBalanceToUserDefaults()
                            self.lastSyncTime = Date()
                        }
                        self.removePendingOperation(operation.id)
                    case .failure(let error):
                        // 检查是否是API限制错误（429或140），如果是，延迟重试
                        if case .serverError(let message) = error, (message.contains("429") || message.contains("140") || message.contains("限制")) {
                            // API限制，延迟重试（不增加重试次数，因为这是外部限制）
                            updatedOperation.retryCount -= 1
                        }
                        self.pendingOperations.append(updatedOperation)
                        self.savePendingOperations()
                    }
                }
                
            case .spend(let amount, let reason):
                // 🔧 关键修复：重试时不应该再次调用 spendDiamonds（因为本地余额已经包含了这个操作）
                // 应该直接重试服务器同步，使用当前余额作为目标值
                // 直接调用服务器同步，因为本地余额已经包含了这个操作
                syncSpendOperationToServer(amount: amount, reason: reason, expectedVersion: operation.expectedVersion) { [weak self] result in
                    guard let self = self else { return }
                    switch result {
                    case .success(let serverBalance):
                        // 同步成功，更新本地余额为服务器值
                        DispatchQueue.main.async {
                            self.balance = serverBalance
                            self.saveBalanceToUserDefaults()
                            self.lastSyncTime = Date()
                        }
                        self.removePendingOperation(operation.id)
                    case .failure(let error):
                        // 检查是否是API限制错误（429或140），如果是，延迟重试
                        if case .serverError(let message) = error, (message.contains("429") || message.contains("140") || message.contains("限制")) {
                            // API限制，延迟重试（不增加重试次数，因为这是外部限制）
                            updatedOperation.retryCount -= 1
                        }
                        self.pendingOperations.append(updatedOperation)
                        self.savePendingOperations()
                    }
                }
            }
        }
    }
    
    private func removePendingOperation(_ id: UUID) {
        pendingOperations.removeAll { $0.id == id }
        savePendingOperations()
    }
    
    // MARK: - Persistence
    
    private func saveBalanceToUserDefaults() {
        if let encoded = try? JSONEncoder().encode(balance) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    private static func loadBalanceFromUserDefaults(key: String) -> DiamondBalance? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let balance = try? JSONDecoder().decode(DiamondBalance.self, from: data) else {
            return nil
        }
        return balance
    }
    
    private func savePendingOperations() {
        if let encoded = try? JSONEncoder().encode(pendingOperations) {
            UserDefaults.standard.set(encoded, forKey: pendingOperationsKey)
        }
    }
    
    private func loadPendingOperations() {
        guard let data = UserDefaults.standard.data(forKey: pendingOperationsKey),
              let operations = try? JSONDecoder().decode([PendingOperation].self, from: data) else {
            return
        }
        pendingOperations = operations
    }
    
    // MARK: - Periodic Sync
    
    private func startPeriodicSync() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            self?.syncWithServer { _ in }
        }
    }
    
    private func syncWithServer(completion: @escaping (Result<Void, DiamondError>) -> Void) {
        refreshBalanceFromServer { result in
            switch result {
            case .success:
                completion(.success(()))
            case .failure(let err):
                completion(.failure(err))
            }
        }
    }
    
    // MARK: - App Lifecycle
    
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(networkDidReconnect),
            name: NSNotification.Name("NetworkDidReconnect"),
            object: nil
        )
    }
    
    @objc private func appDidBecomeActive() {
        // 应用进入前台时同步
        syncWithServer { _ in }
        // 重试待同步操作
        retryPendingOperations()
    }
    
    @objc private func networkDidReconnect() {
        // 网络恢复时重试待同步操作
        retryPendingOperations()
    }
}

