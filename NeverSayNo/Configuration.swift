import Foundation

// 配置管理类
class Configuration {
    static let shared = Configuration()
    
    // API配置
    let leanCloudAppId: String
    let leanCloudAppKey: String
    let leanCloudServerUrl: String
    
    private init() {
        // 使用正确的LeanCloud配置
        self.leanCloudAppId = "ummvIkxIM1Dq3EHUfCkSp54O-gzGzoHsz"  // 项目唯一标识符
        self.leanCloudAppKey = "tPrA1mVg3PdboG0TdFSrpInH"  // 公开的AppKey
        self.leanCloudServerUrl = "https://api.yonderspace-cd.com"  // REST API 服务器地址（从 LeanCloud 控制台获取）
        
        // 验证配置
        validateConfiguration()
        
        // 尝试从环境变量获取配置（如果存在）
        if ProcessInfo.processInfo.environment["LEANCLOUD_APP_ID"] != nil,
           ProcessInfo.processInfo.environment["LEANCLOUD_APP_KEY"] != nil,
           ProcessInfo.processInfo.environment["LEANCLOUD_SERVER_URL"] != nil {
            // 这里可以覆盖默认配置
            // self.leanCloudAppId = envAppId
            // self.leanCloudAppKey = envAppKey
            // self.leanCloudServerUrl = envServerUrl
        }
    }
    
    // 验证配置的有效性
    private func validateConfiguration() {
        #if DEBUG
        // 检查App ID格式
        if leanCloudAppId.isEmpty {
        } else if leanCloudAppId.count < 10 {
        }
        
        // 检查App Key格式
        if leanCloudAppKey.isEmpty {
        } else if leanCloudAppKey.count < 10 {
        }
        
        // 检查Server URL格式
        if leanCloudServerUrl.isEmpty {
        } else if !leanCloudServerUrl.hasPrefix("https://") {
        }
        
        // 检查App ID后缀（国际版应用）
        if leanCloudAppId.hasSuffix("-MdYXbMMI") {
        } else {
        }
        #endif
    }
    
    // 检查配置是否有效
    var isValid: Bool {
        return !leanCloudAppId.isEmpty && 
               !leanCloudAppKey.isEmpty && 
               !leanCloudServerUrl.isEmpty &&
               leanCloudServerUrl.hasPrefix("https://")
    }
    
    // 检查配置是否来自 Keychain（更安全的配置）
    var isConfigFromKeychain: Bool {
        let config = KeychainManager.shared.getLeanCloudConfig()
        return config.appId != nil && config.appKey != nil && config.serverUrl != nil
    }
    
    // 检查配置是否为默认值（安全检查）
    var isUsingDefaultValues: Bool {
        return leanCloudAppId.isEmpty || leanCloudAppKey.isEmpty || leanCloudServerUrl.isEmpty
    }
    
    // MARK: - 更新配置方法
    func updateLeanCloudConfig(appId: String, appKey: String, serverUrl: String) -> Bool {
        return KeychainManager.shared.saveLeanCloudConfig(
            appId: appId,
            appKey: appKey,
            serverUrl: serverUrl
        )
    }
    
    // MARK: - 测试连接方法
    func testConnection(completion: @escaping (Bool, String) -> Void) {
        // 简单的配置验证测试
        if isValid {
            completion(true, "配置验证通过")
        } else {
            completion(false, "配置验证失败")
        }
    }
}

// MARK: - IM 即时通讯配置扩展
extension Configuration {
    /**
     * LeanCloud IM 应用 ID（复用现有配置）
     */
    var leanCloudIMAppId: String {
        return leanCloudAppId  // 使用现有配置
    }
    
    /**
     * LeanCloud IM 应用 Key（复用现有配置）
     */
    var leanCloudIMAppKey: String {
        return leanCloudAppKey  // 使用现有配置
    }
    
    /**
     * LeanCloud IM 服务器 URL（复用现有配置）
     */
    var leanCloudIMServerUrl: String {
        return leanCloudServerUrl  // 使用现有配置
    }
    
    /**
     * 检查是否支持即时通讯服务
     */
    var isIMServiceEnabled: Bool {
        // 基于现有配置的有效性判断
        let enabled = isValid
        // IM 服务状态检查: \(enabled)
        // App ID: \(leanCloudAppId)
        // Server URL: \(leanCloudServerUrl)
        return enabled
    }
    
    /**
     * IM 服务连接超时时间
     */
    var imConnectionTimeout: TimeInterval {
        return 10.0  // 10秒超时
    }
    
    /**
     * IM 重连最大尝试次数
     */
    var imMaxReconnectAttempts: Int {
        return 3  // 最多重连3次
    }
    
    /**
     * 是否启用WebSocket IM
     */
    var isWebSocketIMEnabled: Bool {
        return true  // 启用WebSocket IM
    }
    
    /**
     * WebSocket IM 连接超时时间（秒）
     */
    var webSocketIMTimeout: TimeInterval {
        return 30.0  // 30秒超时
    }
    
    /**
     * WebSocket IM 心跳间隔（秒）
     */
    var webSocketIMHeartbeatInterval: TimeInterval {
        return 30.0  // 30秒心跳
    }
    
    /**
     * WebSocket IM 自动重连间隔（秒）
     */
    var webSocketIMReconnectInterval: TimeInterval {
        return 5.0  // 5秒重连间隔
    }
} 