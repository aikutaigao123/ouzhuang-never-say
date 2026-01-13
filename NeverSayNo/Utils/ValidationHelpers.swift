import SwiftUI
import Foundation

struct ValidationHelpers {
    // 验证用户输入
    static func validateUserInput(_ input: String) -> Bool {
        return !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // 验证邮箱格式（支持emoji）
    static func validateEmail(_ email: String) -> Bool {
        // 🎯 修改：使用统一的验证工具，支持emoji
        return ValidationUtils.isValidEmail(email)
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
