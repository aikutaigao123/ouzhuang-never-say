import Foundation

struct UserAvatarUtils {
    // 获取默认头像 - 与用户头像界面一致
    static func defaultAvatar(for loginType: String) -> String {
        switch loginType {
        case "apple": 
            return "person.circle.fill"
        case "guest": 
            return "person.circle" // SF Symbol
        default: 
            return "person.circle" // 默认使用游客头像
        }
    }
    
    // 检查头像是否为SF Symbol
    static func isSFSymbol(_ avatar: String) -> Bool {
        return avatar == "applelogo" || avatar == "apple_logo" || avatar == "person.circle.fill" || avatar == "person.circle"
    }
    
    // 获取头像显示文本 - 与用户头像界面一致
    static func getAvatarDisplayText(_ avatar: String?, loginType: String?) -> String {
        if let avatar = avatar, !avatar.isEmpty {
            return avatar
        }
        
        switch loginType {
        case "apple":
            return "person.circle.fill"
        case "guest":
            return "person.circle"
        default:
            return "person.circle"
        }
    }
}
