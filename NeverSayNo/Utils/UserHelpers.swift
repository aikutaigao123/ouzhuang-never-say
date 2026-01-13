import SwiftUI
import Foundation

struct UserHelpers {
    // 获取用户头像 - 与用户头像界面一致：不使用全局缓存
    static func getCorrectUserAvatar(userId: String, fallbackAvatar: String) -> String {
        // 与用户头像界面一致：不再使用全局缓存，直接返回fallbackAvatar
        // 实际头像查询应在各个组件onAppear时实时查询
        return fallbackAvatar
    }
    
    // 根据用户ID获取用户名
    static func getUserNameById(_ userId: String, latestUserNames: [String: String]) -> String? {
        return latestUserNames[userId]
    }
    
    // 获取点赞记录键
    static func getLikeRecordsKey(currentUser: UserInfo?) -> String {
        guard let currentUser = currentUser else { return "likeRecords" }
        let loginType = currentUser.loginType == .apple ? "apple" : "guest"
        return "likeRecords_\(currentUser.userId)_\(loginType)"
    }
    
    // 获取当前用户头像
    static func getCurrentUserAvatar(currentUser: UserInfo?) -> String {
        guard let userId = currentUser?.userId else {
            return UserAvatarUtils.defaultAvatar(for: "guest")
        }
        
        // 检查是否有自定义头像
        if let customAvatar = UserDefaultsManager.getCustomAvatar(userId: userId) {
            return customAvatar
        }
        
        // 返回默认头像（根据 loginType）
        let loginType = currentUser?.loginType == .apple ? "apple" : "guest"
        let defaultAvatar = UserAvatarUtils.defaultAvatar(for: loginType)
        return defaultAvatar
    }
    
    // 获取用户爱心状态
    static func getHeartStatusForUser(
        userId: String,
        isUserFavorited: (String) -> Bool,
        isUserFavoritedByMe: (String) -> Bool
    ) -> String {
        let isFavorited = isUserFavorited(userId)
        let isFavoritedByMe = isUserFavoritedByMe(userId)
        let isMatched = isFavorited && isFavoritedByMe
        
        if isMatched {
            return "💕 双向匹配 (我喜欢TA + TA喜欢我)"
        } else if isFavorited {
            return "❤️ 我喜欢TA (单向喜欢)"
        } else if isFavoritedByMe {
            return "💙 TA喜欢我 (被喜欢)"
        } else {
            return "🤍 无关系 (未喜欢)"
        }
    }
}
