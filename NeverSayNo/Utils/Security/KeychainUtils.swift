import Foundation
import Security

struct KeychainUtils {
    // 保存密码到钥匙串
    static func savePasswordToKeychain(username: String, password: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrAccount as String: username,
            kSecAttrServer as String: "internal_login",
            kSecValueData as String: password.data(using: .utf8)!
        ]
        
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // 从钥匙串删除密码
    static func deletePasswordFromKeychain(username: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrAccount as String: username,
            kSecAttrServer as String: "internal_login"
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
    
    // 从钥匙串获取密码
    static func getPasswordFromKeychain(username: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrAccount as String: username,
            kSecAttrServer as String: "internal_login",
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let password = String(data: data, encoding: .utf8) {
            return password
        }
        return nil
    }
    
    // 获取错误消息
    static func getErrorMessage(_ status: OSStatus) -> String {
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
            return "服务不可用"
        case errSecAuthFailed:
            return "认证失败"
        default:
            return "未知错误: \(status)"
        }
    }
}
