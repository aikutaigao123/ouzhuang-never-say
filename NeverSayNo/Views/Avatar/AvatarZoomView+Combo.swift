import SwiftUI

// MARK: - Combo System
extension AvatarZoomView {
    
    // 开始长按连击
    func startLongPressCombo() {
        isLongPressing = true
        comboCount = 0
        
        // 启动连击定时器，每1/17秒执行一次
        longPressTimer = Timer.scheduledTimer(withTimeInterval: 1.0/17.0, repeats: true) { _ in
            comboCount += 1
            
            randomizeAvatar()
            
            // 触觉反馈
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            // 连击成就检查
            checkComboAchievement()
        }
    }
    
    // 停止长按连击
    func stopLongPressCombo() {
        isLongPressing = false
        longPressTimer?.invalidate()
        longPressTimer = nil
        
        // 🔧 修复：在重置前保存 comboCount，避免延迟重置导致的问题
        let finalComboCount = comboCount
        
        // 更新最大连击记录
        if finalComboCount > maxComboCount {
            maxComboCount = finalComboCount
            // 保存到UserDefaults - 统一使用 objectId 作为 userId
            if let userId = userManager.currentUser?.id {
                UserDefaultsManager.setMaxComboCount(userId: userId, count: maxComboCount)
            }
        }
        
        // 🔧 新增：统一同步所有待同步的钻石变更到服务器
        if let diamondStore = userManager.diamondManager?.diamondStore {
            let beforeSyncDiamonds = diamondStore.balance.amount
            diamondStore.syncPendingChanges { result in
                switch result {
                case .success(let serverAmount):
                    // 🔧 改进：验证：同步后的钻石数应该等于同步前 - 累计消耗
                    // 注意：如果同步期间有其他操作，期望值可能不准确
                    let expectedAfterSync = beforeSyncDiamonds - (finalComboCount * 5)
                    let difference = abs(serverAmount - expectedAfterSync)
                    if difference > 5 {
                        // 🔧 改进：如果差异较大，可能是同步期间有其他操作
                        if difference > 20 {
                        }
                    }
                case .failure:
                    break
                }
            }
        }
        
        // 重置连击计数
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            comboCount = 0
        }
    }
    
    // 强制停止连击（用于钻石不足等情况）
    func forceStopLongPressCombo() {
        isLongPressing = false
        longPressTimer?.invalidate()
        longPressTimer = nil
        let finalComboCount = comboCount
        comboCount = 0
        
        // 🔧 新增：统一同步所有待同步的钻石变更到服务器
        if let diamondStore = userManager.diamondManager?.diamondStore {
            let beforeSyncDiamonds = diamondStore.balance.amount
            diamondStore.syncPendingChanges { result in
                switch result {
                case .success(let serverAmount):
                    // 验证：同步后的钻石数应该等于同步前 - 累计消耗
                    let expectedAfterSync = beforeSyncDiamonds - (finalComboCount * 5)
                    let difference = abs(serverAmount - expectedAfterSync)
                    if difference > 5 {
                    }
                case .failure:
                    break
                }
            }
        }
    }
    
    // 检查连击成就
    func checkComboAchievement() {
        // 连击成就检查逻辑
    }
}
