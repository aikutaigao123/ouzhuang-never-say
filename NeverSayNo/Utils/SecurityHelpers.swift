import SwiftUI
import Foundation
import CryptoKit

struct SecurityHelpers {
    // 生成随机字符串
    static func generateRandomString(length: Int) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in characters.randomElement()! })
    }
    
    // 生成UUID
    static func generateUUID() -> String {
        return UUID().uuidString
    }
    
    // 生成短UUID（前8位）
    static func generateShortUUID() -> String {
        return String(UUID().uuidString.prefix(8))
    }
    
    // 计算字符串的SHA256哈希
    static func sha256(_ string: String) -> String {
        let data = Data(string.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // 计算字符串的MD5哈希
    static func md5(_ string: String) -> String {
        let data = Data(string.utf8)
        let hash = Insecure.MD5.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    // 生成随机盐值
    static func generateSalt() -> String {
        return generateRandomString(length: 32)
    }
    
    // 验证密码强度
    static func validatePasswordStrength(_ password: String) -> PasswordStrength {
        var score = 0
        
        // 长度检查
        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        
        // 字符类型检查
        if password.range(of: "[a-z]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[A-Z]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[0-9]", options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[^a-zA-Z0-9]", options: .regularExpression) != nil { score += 1 }
        
        switch score {
        case 0...2: return .weak
        case 3...4: return .medium
        case 5...6: return .strong
        default: return .veryStrong
        }
    }
    
    // 检查是否为有效密码
    static func isValidPassword(_ password: String) -> Bool {
        return password.count >= 8 && validatePasswordStrength(password) != .weak
    }
    
    // 生成访问令牌
    static func generateAccessToken() -> String {
        let timestamp = String(Int(Date().timeIntervalSince1970))
        let random = generateRandomString(length: 16)
        return "\(timestamp)_\(random)"
    }
    
    // 验证访问令牌格式
    static func isValidAccessToken(_ token: String) -> Bool {
        let components = token.split(separator: "_")
        return components.count == 2 && components[0].allSatisfy { $0.isNumber }
    }
    
    // 生成会话ID
    static func generateSessionId() -> String {
        return generateUUID()
    }
    
    // 检查字符串是否包含敏感信息
    static func containsSensitiveInfo(_ text: String) -> Bool {
        let sensitivePatterns = [
            "password", "passwd", "pwd",
            "secret", "key", "token",
            "credit", "card", "ssn",
            "social", "security"
        ]
        
        let lowercased = text.lowercased()
        return sensitivePatterns.contains { lowercased.contains($0) }
    }
    
    // 清理敏感信息
    static func sanitizeText(_ text: String) -> String {
        if containsSensitiveInfo(text) {
            return "[敏感信息已隐藏]"
        }
        return text
    }
    
    // 生成设备指纹
    static func generateDeviceFingerprint() -> String {
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        let systemVersion = UIDevice.current.systemVersion
        let model = UIDevice.current.model
        
        let combined = "\(deviceId)_\(systemVersion)_\(model)"
        return sha256(combined)
    }
    
    // 验证设备指纹
    static func verifyDeviceFingerprint(_ fingerprint: String) -> Bool {
        return fingerprint == generateDeviceFingerprint()
    }
    
    // 生成API密钥
    static func generateAPIKey() -> String {
        let timestamp = String(Int(Date().timeIntervalSince1970))
        let random = generateRandomString(length: 24)
        return "api_\(timestamp)_\(random)"
    }
    
    // 验证API密钥格式
    static func isValidAPIKey(_ key: String) -> Bool {
        return key.hasPrefix("api_") && key.count > 20
    }
}

// 密码强度枚举
enum PasswordStrength {
    case weak
    case medium
    case strong
    case veryStrong
    
    var description: String {
        switch self {
        case .weak: return "弱"
        case .medium: return "中等"
        case .strong: return "强"
        case .veryStrong: return "很强"
        }
    }
    
    var color: Color {
        switch self {
        case .weak: return .red
        case .medium: return .orange
        case .strong: return .yellow
        case .veryStrong: return .green
        }
    }
}
