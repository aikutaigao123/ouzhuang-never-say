import SwiftUI
import Foundation

struct CacheHelpers {
    // 清理过期缓存
    static func cleanupExpiredCache(
        avatarCacheTimestamps: inout [String: Date],
        userNameCacheTimestamps: inout [String: Date],
        latestAvatars: inout [String: String],
        latestUserNames: inout [String: String],
        cacheExpirationInterval: TimeInterval
    ) {
        // 清理LeanCloudService的缓存
        LeanCloudService.shared.performCacheCleanup()
        
        // 清理本地UI缓存
        let now = Date()
        var cleanedAvatars = 0
        var cleanedUserNames = 0
        
        // 清理过期的头像缓存
        for (userId, timestamp) in avatarCacheTimestamps {
            let timeAgo = now.timeIntervalSince(timestamp)
            if timeAgo > cacheExpirationInterval {
                latestAvatars.removeValue(forKey: userId)
                avatarCacheTimestamps.removeValue(forKey: userId)
                cleanedAvatars += 1
            }
        }
        
        // 清理过期的用户名缓存
        for (userId, timestamp) in userNameCacheTimestamps {
            let timeAgo = now.timeIntervalSince(timestamp)
            if timeAgo > cacheExpirationInterval {
                latestUserNames.removeValue(forKey: userId)
                userNameCacheTimestamps.removeValue(forKey: userId)
                cleanedUserNames += 1
            }
        }
    }
    
    // 在数据更新完成后清理过期缓存
    static func cleanupCacheAfterUpdate(
        avatarCacheTimestamps: inout [String: Date],
        userNameCacheTimestamps: inout [String: Date],
        latestAvatars: inout [String: String],
        latestUserNames: inout [String: String],
        cacheExpirationInterval: TimeInterval
    ) {
        cleanupExpiredCache(
            avatarCacheTimestamps: &avatarCacheTimestamps,
            userNameCacheTimestamps: &userNameCacheTimestamps,
            latestAvatars: &latestAvatars,
            latestUserNames: &latestUserNames,
            cacheExpirationInterval: cacheExpirationInterval
        )
    }
    
    // 检查缓存是否过期
    static func isCacheExpired(
        for userId: String,
        avatarCacheTimestamps: [String: Date],
        userNameCacheTimestamps: [String: Date],
        cacheExpirationInterval: TimeInterval
    ) -> Bool {
        let now = Date()
        
        // 检查头像缓存是否过期
        if let avatarTimestamp = avatarCacheTimestamps[userId] {
            if now.timeIntervalSince(avatarTimestamp) > cacheExpirationInterval {
                return true
            }
        }
        
        // 检查用户名缓存是否过期
        if let userNameTimestamp = userNameCacheTimestamps[userId] {
            if now.timeIntervalSince(userNameTimestamp) > cacheExpirationInterval {
                return true
            }
        }
        
        return false
    }
    
    // 根据用户ID获取登录类型
    static func getLoginTypeForUser(userId: String, randomMatchHistory: [RandomMatchHistory]) -> String? {
        // 从历史记录中查找用户的登录类型
        for historyItem in randomMatchHistory {
            if historyItem.record.userId == userId {
                return historyItem.record.loginType
            }
        }
        return nil
    }
    
    // 拉取并缓存指定用户的最新头像（仅当缓存不存在时）
    static func ensureLatestAvatar(
        userId: String?,
        loginType: String?,
        latestAvatars: [String: String],
        onAvatarFetched: @escaping (String, String) -> Void
    ) {
        guard let userId = userId, !userId.isEmpty else { return }
        if latestAvatars[userId] != nil { return }
        // 🎯 修改：使用 fetchUserAvatarByUserId，不依赖 loginType，直接从 UserAvatarRecord 表获取
        LeanCloudService.shared.fetchUserAvatarByUserId(objectId: userId) { avatar, _ in
            DispatchQueue.main.async {
                if let avatar = avatar, !avatar.isEmpty {
                    onAvatarFetched(userId, avatar)
                }
            }
        }
    }
    
    // 用户名解析器（优先使用缓存的最新用户名）
    static func userNameResolver(userId: String?, latestUserNames: [String: String]) -> String? {
        guard let userId = userId, !userId.isEmpty else { return nil }
        return latestUserNames[userId]
    }
}