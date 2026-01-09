import SwiftUI
import Foundation

struct ValidationHelpers {
    // 验证用户输入
    static func validateUserInput(_ input: String) -> Bool {
        return !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // 验证邮箱格式
    static func validateEmail(_ email: String) -> Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. 先检查是否是邮箱格式
        if trimmedEmail.contains("@") {
            let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}$"
            let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
            return emailPredicate.evaluate(with: trimmedEmail)
        }
        
        let wechatIdRegex = "^[a-zA-Z][a-zA-Z0-9_-]{5,19}$"
        let wechatIdPredicate = NSPredicate(format: "SELF MATCHES %@", wechatIdRegex)
        return wechatIdPredicate.evaluate(with: trimmedEmail)
    }
    
    // 验证用户ID格式
    static func validateUserId(_ userId: String) -> Bool {
        return !userId.isEmpty && userId.count >= 3
    }
    
    // 验证设备ID
    static func validateDeviceId(_ deviceId: String) -> Bool {
        return !deviceId.isEmpty && deviceId != "unknown_device"
    }
    
    // 验证登录类型
    static func validateLoginType(_ loginType: String) -> Bool {
        let validTypes = ["apple", "guest"]
        return validTypes.contains(loginType)
    }
}
