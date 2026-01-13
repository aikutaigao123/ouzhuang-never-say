import SwiftUI

extension DiamondManager {
    // 🎯 修改：直接使用 DiamondStore
    func addDiamonds(_ amount: Int) -> Bool {
        guard let store = diamondStore else {
            return false
        }
        
        var success = false
        let semaphore = DispatchSemaphore(value: 0)
        
        // 确定操作来源
        let source: DiamondOperation.OperationSource = .system
        
        store.addDiamonds(amount, source: source) { result in
            switch result {
            case .success:
                success = true
            case .failure:
                success = false
            }
            semaphore.signal()
        }
        
        // 等待操作完成（最多等待2秒）
        _ = semaphore.wait(timeout: .now() + 2.0)
        
        return success
    }
    
    // 🎯 修改：直接使用 DiamondStore（异步方法保持不变）
    func spendDiamonds(_ amount: Int, completion: @escaping (Bool) -> Void) {
        guard let store = diamondStore else {
            completion(false)
            return
        }
        
        // 使用 DiamondStore 消耗钻石（内部会自动处理同步和冲突）
        store.spendDiamonds(amount, reason: "用户操作") { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    completion(true)
                case .failure(_):
                    completion(false)
                }
            }
        }
    }
    
    // 🎯 保留同步版本（已弃用，保留以兼容旧代码）
    @available(*, deprecated, message: "请使用 spendDiamonds(_:completion:) 异步版本，以支持多设备同步")
    func spendDiamondsSync(_ amount: Int) -> Bool {
        guard isServerConnected else {
            return false
        }
        
        guard let userId = currentUserId else {
            return false
        }
        
        if diamonds >= amount {
            diamonds -= amount
            
            // 🎯 立即同步到 UserDefaults
            UserDefaultsManager.setCustomDiamonds(userId: userId, diamonds: diamonds)
            
            updateDiamondsOnServer()
            return true
        } else {
            return false
        }
    }
    
    // 🎯 修改：检查是否有足够的钻石（完全实时查询版本）
    func hasEnoughDiamonds(_ amount: Int) -> Bool {
        // 触发后台刷新（完全实时查询）
        diamondStore?.refreshBalanceInBackground()
        // 使用 DiamondStore 的余额（已自动同步），离线时也允许使用本地余额
        return diamonds >= amount
    }
    
    // 🎯 修改：检查余额（完全实时查询版本）
    // 注意：离线时也允许使用本地余额，实际扣除时会在 spendDiamonds 中同步服务器
    func checkDiamondsWithDebug(_ amount: Int) -> Bool {
        // 触发后台刷新（完全实时查询）
        diamondStore?.refreshBalanceInBackground()
        // 直接检查本地余额（DiamondStore 会自动同步，所以是实时的）
        return diamonds >= amount
    }
    
    // 🎯 修改：使用 DiamondStore 检查余额
    func checkDiamondsWithServerConfirmation(_ amount: Int, completion: @escaping (Bool) -> Void) {
        guard let store = diamondStore else {
            completion(false)
            return
        }
        
        // 如果本地余额充足，直接返回true（避免不必要的服务器查询）
        if diamonds >= amount {
            completion(true)
            return
        }
        
        // 如果本地余额不足，刷新服务器数据并检查
        store.refreshBalanceFromServer { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let serverBalance):
                    let hasEnough = serverBalance >= amount
                    completion(hasEnough)
                case .failure(_):
                    completion(false)
                }
            }
        }
    }
    
    // 手动打印当前余额（含上下文）
    func debugPrintDiamonds() {
        // 暂时空实现
    }
    
    // 新增：显示LeanCloud中的完整钻石记录
    func displayLeanCloudDiamondRecords() {
        guard let userId = currentUserId, let loginType = currentLoginType else {
            return
        }
        
        LeanCloudService.shared.fetchDiamondRecords(objectId: userId, loginType: loginType) { records, error in
            DispatchQueue.main.async {
                if error != nil {
                    return
                }
                
                if records != nil {
                    // 暂时空实现，等待后续功能开发
                }
            }
        }
    }
}
