import Foundation
import SwiftUI

struct UserTypeUtils {
    // 获取用户类型显示文本
    static func getUserTypeText(_ loginType: String?) -> String {
        switch loginType {
        case "apple":
            return "Apple ID用户"
        case "guest":
            return "游客用户"
        default:
            return "未知用户"
        }
    }
    
    // 从用户ID推断登录类型
    // ⚠️ 注意：由于现在所有登录类型（Apple、Guest）的 userId 都统一使用 LeanCloud objectId，
    // 无法通过 userId 前缀准确判断登录类型。此方法主要用于向后兼容和回退场景。
    // 在实际使用中，应该优先使用明确的 loginType 字段。
    static func getLoginTypeFromUserId(_ userId: String) -> String {
        // 检查旧格式（向后兼容）
        if userId.hasPrefix("apple_") {
            return "apple"
        } else if userId.hasPrefix("guest_") {
            // 🎯 注意：新版本的游客账号 userId 也是 objectId，不再使用此格式
            // 此判断仅用于向后兼容旧数据
            return "guest"
        } else if userId.contains(".") && userId.contains("1a3cac8727264e249eb8d8fd69e3c8e0") {
            // Apple登录用户的特殊格式：000737.1a3cac8727264e249eb8d8fd69e3c8e0.1242
            return "apple"
        } else {
            // 🎯 修改：对于 objectId 格式的 userId（24位十六进制字符串），默认返回 guest
            // 因为无法通过 objectId 判断具体类型，需要依赖其他信息（如 loginType 字段）
            return "guest"
        }
    }
    
    // 获取用户类型背景颜色
    static func getUserTypeBackground(_ loginType: String?) -> Color {
        switch loginType {
        case "apple":
            return Color.purple.opacity(0.1)
        case "guest":
            return Color.blue.opacity(0.1)
        default:
            return Color.gray.opacity(0.1)
        }
    }
    
    // 获取用户类型颜色
    static func getUserTypeColor(_ loginType: String?) -> Color {
        switch loginType {
        case "apple":
            return Color.purple
        case "guest":
            return Color.blue
        default:
            return Color.gray
        }
    }
    
    // 将登录类型字符串转为 UserInfo.LoginType 枚举
    static func loginType(from rawValue: String) -> UserInfo.LoginType {
        switch rawValue {
        case "apple":
            return .apple
        case "guest":
            return .guest
        default:
            return .guest
        }
    }
}
