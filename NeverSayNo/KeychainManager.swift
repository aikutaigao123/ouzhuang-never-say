import Foundation
import Security

class KeychainManager {
    static let shared = KeychainManager()
    
    private init() {}
    
    // MARK: - 保存数据到 Keychain
    func save(key: String, data: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // 先删除已存在的项目
        SecItemDelete(query as CFDictionary)
        
        // 保存新项目
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // MARK: - 从 Keychain 获取数据
    func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        _ = SecItemCopyMatching(query as CFDictionary, &result)
        
        return (result as? Data)
    }
    
    // MARK: - 删除 Keychain 中的数据
    func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
    
    // MARK: - 检查 Keychain 中是否存在某个键
    func exists(key: String) -> Bool {
        return load(key: key) != nil
    }
    
    // MARK: - 保存字符串
    func saveString(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return save(key: key, data: data)
    }
    
    // MARK: - 获取字符串
    func loadString(key: String) -> String? {
        guard let data = load(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    // MARK: - 错误处理
    func getErrorMessage(_ status: OSStatus) -> String {
        switch status {
        case errSecSuccess:
            return "操作成功"
        case errSecDuplicateItem:
            return "项目已存在"
        case errSecItemNotFound:
            return "项目未找到"
        case errSecParam:
            return "参数错误"
        case errSecAllocate:
            return "内存分配失败"
        case errSecNotAvailable:
            return "Keychain 不可用"
        case errSecAuthFailed:
            return "认证失败"
        case errSecDecode:
            return "解码失败"
        default:
            return "未知错误: \(status)"
        }
    }
}

// MARK: - API 密钥管理扩展
extension KeychainManager {
    
    // MARK: - LeanCloud API 密钥管理
    private enum LeanCloudKeys {
        static let appId = "leancloud_app_id"
        static let appKey = "leancloud_app_key"
        static let serverUrl = "leancloud_server_url"
    }
    
    // MARK: - 保存 LeanCloud 配置
    func saveLeanCloudConfig(appId: String, appKey: String, serverUrl: String) -> Bool {
        let appIdSuccess = saveString(key: LeanCloudKeys.appId, value: appId)
        let appKeySuccess = saveString(key: LeanCloudKeys.appKey, value: appKey)
        let serverUrlSuccess = saveString(key: LeanCloudKeys.serverUrl, value: serverUrl)
        
        return appIdSuccess && appKeySuccess && serverUrlSuccess
    }
    
    // MARK: - 获取 LeanCloud 配置
    func getLeanCloudConfig() -> (appId: String?, appKey: String?, serverUrl: String?) {
        let appId = loadString(key: LeanCloudKeys.appId)
        let appKey = loadString(key: LeanCloudKeys.appKey)
        let serverUrl = loadString(key: LeanCloudKeys.serverUrl)
        
        return (appId: appId, appKey: appKey, serverUrl: serverUrl)
    }
    
    // MARK: - 检查 LeanCloud 配置是否完整
    func isLeanCloudConfigComplete() -> Bool {
        let config = getLeanCloudConfig()
        return config.appId != nil && config.appKey != nil && config.serverUrl != nil
    }
    
    // MARK: - 清除 LeanCloud 配置
    func clearLeanCloudConfig() -> Bool {
        let appIdSuccess = delete(key: LeanCloudKeys.appId)
        let appKeySuccess = delete(key: LeanCloudKeys.appKey)
        let serverUrlSuccess = delete(key: LeanCloudKeys.serverUrl)
        
        return appIdSuccess && appKeySuccess && serverUrlSuccess
    }
    
    // MARK: - 初始化默认配置（安全版本）
    func initializeDefaultConfig() {
        // 只在开发环境中检查配置状态，不自动设置默认值
        #if DEBUG
        if !isLeanCloudConfigComplete() {
            // LeanCloud配置未完成
        }
        #endif
    }
    
    // MARK: - 验证配置安全性
    func validateConfigSecurity() -> (isSecure: Bool, issues: [String]) {
        var issues: [String] = []
        
        let config = getLeanCloudConfig()
        
        // 检查是否为空
        if config.appId == nil || config.appId?.isEmpty == true {
            issues.append("App ID 未配置")
        }
        
        if config.appKey == nil || config.appKey?.isEmpty == true {
            issues.append("App Key 未配置")
        }
        
        if config.serverUrl == nil || config.serverUrl?.isEmpty == true {
            issues.append("Server URL 未配置")
        }
        
        // 检查是否为明显的测试值
        if let appId = config.appId, appId.contains("test") || appId.contains("demo") {
            issues.append("App ID 可能为测试值")
        }
        
        if let appKey = config.appKey, appKey.count < 10 {
            issues.append("App Key 长度过短，可能不安全")
        }
        
        return (isSecure: issues.isEmpty, issues: issues)
    }
} 