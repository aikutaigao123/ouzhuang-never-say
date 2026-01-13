import SwiftUI

// MARK: - State Management
extension AvatarZoomView {
    
    // 初始化头像显示
    func initializeAvatarDisplay() {
        // 加载已保存的头像
        // 🔧 统一使用 objectId 作为 userId
        if currentAvatarEmoji == nil {
            if let userId = userManager.currentUser?.id,
               let savedEmoji = UserDefaultsManager.getCustomAvatar(userId: userId) {
                currentAvatarEmoji = savedEmoji
            }
        }
    }
    
    // 加载最大连击记录
    func loadMaxComboCount() {
        // 🔧 统一使用 objectId 作为 userId
        if let userId = userManager.currentUser?.id {
            maxComboCount = UserDefaultsManager.getMaxComboCount(userId: userId)
        }
    }
    
    // 启动状态定时器
    func startStatusTimer() {
        // 启动定时器，每3秒输出当前状态
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            // 定时器逻辑
        }
    }
    
    // 清理定时器
    func cleanupTimers() {
        // 停止定时器
        timer?.invalidate()
        timer = nil
        
        // 停止长按连击定时器
        longPressTimer?.invalidate()
        longPressTimer = nil
        isLongPressing = false
        comboCount = 0
    }
}
