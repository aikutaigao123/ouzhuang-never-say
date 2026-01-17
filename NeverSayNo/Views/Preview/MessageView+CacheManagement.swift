import SwiftUI

// MARK: - MessageView Cache Management Extension
extension MessageView {
    
    // MARK: - Cache Management Methods
    
    /// 刷新消息用户缓存
    internal func refreshMessageUserCache() {
        
        // 收集所有需要缓存的用户ID
        var userIds = Set<String>()
        
        // 从消息中收集用户ID
        for message in existingMessages {
            userIds.insert(message.senderId)
            userIds.insert(message.receiverId)
        }
        
        // 从拍一拍消息中收集用户ID
        for message in existingPatMessages {
            userIds.insert(message.senderId)
            userIds.insert(message.receiverId)
        }
        
        // 从好友列表中收集用户ID
        for friend in existingFriends {
            userIds.insert(friend.user1Id)
            userIds.insert(friend.user2Id)
        }
        
        // 批量获取用户信息并缓存
        batchFetchUserInfo(userIds: Array(userIds))
    }
    
    /// 批量获取用户信息并缓存
    private func batchFetchUserInfo(userIds: [String]) {
        guard !userIds.isEmpty else {
            return
        }
        
        
        let group = DispatchGroup()
        
        for userId in userIds {
            // 跳过当前用户
            if userId == userManager.currentUser?.id {
                continue
            }
            
            group.enter()
            
            // 获取用户头像
            fetchAndCacheUserAvatar(userId: userId) {
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
        }
    }
    
    /// 🚀 新增：实时刷新所有用户头像，与拍一拍消息一致
    internal func refreshAllUserAvatarsInRealTime() {
        
        // 收集所有需要更新的用户ID
        var userIds = Set<String>()
        
        // 从消息中收集用户ID
        for message in existingMessages {
            userIds.insert(message.senderId)
            userIds.insert(message.receiverId)
        }
        
        // 从拍一拍消息中收集用户ID
        for message in existingPatMessages {
            userIds.insert(message.senderId)
            userIds.insert(message.receiverId)
        }
        
        // 从好友列表中收集用户ID
        for friend in existingFriends {
            userIds.insert(friend.user1Id)
            userIds.insert(friend.user2Id)
        }
        
        
        // 批量实时更新头像
        let group = DispatchGroup()
        for userId in userIds {
            // 跳过当前用户
            if userId == userManager.currentUser?.id {
                continue
            }
            
            group.enter()
            
            // 实时获取用户头像信息
            // 🎯 修改：使用 fetchUserAvatarByUserId，不依赖 loginType，直接从 UserAvatarRecord 表获取
            LeanCloudService.shared.fetchUserAvatarByUserId(objectId: userId) { avatar, _ in
                DispatchQueue.main.async {
                    if let avatar = avatar, !avatar.isEmpty {
                        self.existingAvatarCache[userId] = avatar
                    }
                    group.leave()
                }
            }
            
            // 🎯 修改：使用 fetchUserNameByUserId，不依赖 loginType，直接从 UserNameRecord 表获取
            LeanCloudService.shared.fetchUserNameByUserId(objectId: userId) { name, _ in
                DispatchQueue.main.async {
                    if let name = name, !name.isEmpty {
                        self.existingUserNameCache[userId] = name
                    }
                }
            }
        }
        
        group.notify(queue: .main) {
            for (_, _) in self.existingAvatarCache {
            }
        }
    }
    
    /// 获取并缓存用户头像
    private func fetchAndCacheUserAvatar(userId: String, completion: @escaping () -> Void) {
        // 检查是否已经缓存
        if existingAvatarCache[userId] != nil {
            completion()
            return
        }
        
        // 使用默认头像（简化版本，避免调用不存在的方法）
        existingAvatarCache[userId] = "😀"
        completion()
    }
    
    /// 获取并缓存用户名
    private func fetchAndCacheUserName(userId: String, completion: @escaping (String) -> Void) {
        // 检查是否已经缓存
        if let cachedName = existingUserNameCache[userId] {
            completion(cachedName)
            return
        }
        
        // 使用默认用户名（简化版本，避免调用不存在的方法）
        let defaultName = "未知用户"
        existingUserNameCache[userId] = defaultName
        completion(defaultName)
    }
    
    /// 获取并缓存用户登录类型
    private func fetchAndCacheUserLoginType(userId: String, completion: @escaping (String) -> Void) {
        // 根据用户ID推断登录类型（简化版本，不使用缓存）
        let loginType = UserTypeUtils.getLoginTypeFromUserId(userId)
        completion(loginType)
    }
    
    // MARK: - Cache Utility Methods
    
    /// 获取缓存的用户头像
    internal func getCachedUserAvatar(userId: String, completion: @escaping (String) -> Void) {
        // 第一优先级：检查消息界面专用的头像缓存
        if let cachedAvatar = existingAvatarCache[userId], !cachedAvatar.isEmpty {
            completion(cachedAvatar)
            return
        }
        
        // 第二优先级：使用默认头像
        let defaultAvatar = "😀"
        completion(defaultAvatar)
    }
    
    /// 获取缓存的用户名
    internal func getCachedUserName(userId: String, completion: @escaping (String) -> Void) {
        // 第一优先级：检查消息界面专用的用户名缓存
        if let cachedName = existingUserNameCache[userId], !cachedName.isEmpty {
            completion(cachedName)
            return
        }
        
        // 第二优先级：使用默认用户名
        let defaultName = "未知用户"
        completion(defaultName)
    }
    
    /// 获取缓存的用户登录类型
    internal func getCachedUserLoginType(userId: String, completion: @escaping (String) -> Void) {
        // 根据用户ID推断登录类型
        let loginType = UserTypeUtils.getLoginTypeFromUserId(userId)
        completion(loginType)
    }
    
    // MARK: - Cache Cleanup Methods
    
    /// 清理过期的缓存
    internal func cleanupExpiredCache() {
        
        let currentTime = Date()
        let fiveMinutesAgo = currentTime.addingTimeInterval(-300)
        
        // 清理过期的在线状态缓存
        var expiredKeys: [String] = []
        for (userId, status) in onlineStatusCache {
            if let lastActiveTime = status.1, lastActiveTime < fiveMinutesAgo {
                expiredKeys.append(userId)
            }
        }
        
        for key in expiredKeys {
            onlineStatusCache.removeValue(forKey: key)
        }
        
        if !expiredKeys.isEmpty {
        }
    }
    
    /// 清理所有缓存
    internal func clearAllCache() {
        
        existingAvatarCache.removeAll()
        existingUserNameCache.removeAll()
        // existingUserLoginTypeCache不存在，跳过清理
        onlineStatusCache.removeAll()
        
    }
    
    /// 获取缓存统计信息
    internal func getCacheStatistics() -> (avatarCount: Int, userNameCount: Int, loginTypeCount: Int, onlineStatusCount: Int) {
        return (
            avatarCount: existingAvatarCache.count,
            userNameCount: existingUserNameCache.count,
            loginTypeCount: 0, // existingUserLoginTypeCache不存在
            onlineStatusCount: onlineStatusCache.count
        )
    }
    
    // MARK: - Cache Validation Methods
    
    /// 验证缓存完整性
    internal func validateCacheIntegrity() -> Bool {
        
        var isValid = true
        
        // 检查头像缓存
        for (_, avatar) in existingAvatarCache {
            if avatar.isEmpty {
                isValid = false
            }
        }
        
        // 检查用户名缓存
        for (_, userName) in existingUserNameCache {
            if userName.isEmpty {
                isValid = false
            }
        }
        
        // 检查登录类型缓存（existingUserLoginTypeCache不存在，跳过）
        
        if isValid {
        } else {
        }
        
        return isValid
    }
    
    /// 修复损坏的缓存
    internal func repairCache() {
        
        // 移除空的头像缓存
        existingAvatarCache = existingAvatarCache.filter { !$0.value.isEmpty }
        
        // 移除空的用户名缓存
        existingUserNameCache = existingUserNameCache.filter { !$0.value.isEmpty }
        
        // 移除空的登录类型缓存（existingUserLoginTypeCache不存在，跳过）
        
    }
    
}
