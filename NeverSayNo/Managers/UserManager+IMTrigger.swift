import Foundation

// MARK: - IM 触发器生命周期管理
extension UserManager {
    
    /**
     * 初始化 IM 触发器
     * 在用户登录成功后调用
     * 使用 WebSocket 模式
     */
    func initializeIMTrigger() {
        guard let user = currentUser else {
            return
        }
        
        // 🔧 使用 user_id 而非 id 作为 IM 客户端 ID
        // user.id 是 LCUser 的 objectId（如 68fb9c52096517792f2daf15）
        // user.userId 是用户的唯一标识（如 guest_4898F189-0343-54FC-8B73-5A803AB5856E）
        let imClientId = user.userId
        
        // 使用WebSocket IM
        initializeWebSocketIM(userId: imClientId, userName: user.fullName)
        
        // 🔧 重要：用户登录后，刷新设备令牌以确保正确关联到用户
        // 这样LeanCloud才能根据clientId推送消息到正确的设备
        RemoteNotificationManager.shared.refreshDeviceTokenAfterLogin()
    }
    
    /**
     * 初始化WebSocket IM
     * 🚀 修复：确保在 background QoS 线程上执行，避免线程优先级反转
     */
    private func initializeWebSocketIM(userId: String, userName: String) {
        // 🚀 修复：确保在 background QoS 线程上执行，避免线程优先级反转
        let currentQoS = Thread.current.qualityOfService
        if currentQoS == .userInteractive || currentQoS == .userInitiated {
            DispatchQueue.global(qos: .background).async {
                // 启动迁移管理器
                LeanCloudIMMigrationManager.shared.startMigration()
                
                // 初始化WebSocket IM服务
                LeanCloudWebSocketIMService.shared.initializeService(userId: userId, userName: userName)
            }
        } else {
            // 启动迁移管理器
            LeanCloudIMMigrationManager.shared.startMigration()
            
            // 初始化WebSocket IM服务
            LeanCloudWebSocketIMService.shared.initializeService(userId: userId, userName: userName)
        }
    }
    
    /**
     * 判断是否应该使用WebSocket IM
     */
    private func shouldUseWebSocketIM() -> Bool {
        // 检查配置是否启用WebSocket
        let config = Configuration.shared
        return config.isWebSocketIMEnabled
    }
    
    /**
     * 断开 IM 触发器
     * 在用户登出时调用
     */
    func disconnectIMTrigger() {
        // 断开WebSocket IM
        LeanCloudWebSocketIMService.shared.disconnectService()
        LeanCloudIMMigrationManager.shared.disconnectWebSocket()
    }
    
    /**
     * 检查 IM 连接状态
     */
    var isIMConnected: Bool {
        return LeanCloudWebSocketIMService.shared.isConnected
    }
    
    /**
     * 手动触发 IM 消息检查
     */
    func triggerIMMessageCheck() {
        LeanCloudIMTrigger.shared.triggerManualCheck()
    }
    
    /**
     * 获取 IM 连接统计信息
     */
    func getIMConnectionStats() -> (isConnected: Bool, userId: String?, reconnectAttempts: Int) {
        return LeanCloudIMTrigger.shared.getConnectionStats()
    }
    
    /**
     * 重新初始化 IM 触发器
     * 用于网络恢复或重连场景
     */
    func reinitializeIMTrigger() {
        guard isLoggedIn, let _ = currentUser else {
            // 无法重新初始化 IM 触发器：用户未登录
            return
        }
        
        // 重新初始化 IM 触发器
        
        // 先断开现有连接
        disconnectIMTrigger()
        
        // 延迟重新初始化，避免频繁重连
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.initializeIMTrigger()
        }
    }
}
