//
//  LegacySearchView+CacheManagement.swift
//  NeverSayNo
//
//  Created by AI Assistant on 2024
//  Cache management methods for LegacySearchView
//

import SwiftUI
import Foundation
import LeanCloud

// MARK: - Cache Management Extension
extension LegacySearchView {
    
    /// 加载所有本地缓存数据（登录时调用）
    func loadAllLocalCacheDataOnLogin() {
        var cacheData = ""
        var totalCacheCount = 0
        
        // 1. 读取UserDefaults中的所有数据
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        cacheData += "📱 [登录成功] UserDefaults 缓存数据:\n"
        cacheData += "总键数: \(allKeys.count)\n\n"
        
        for key in allKeys.sorted() {
            if let value = userDefaults.object(forKey: key) {
                totalCacheCount += 1
                cacheData += "🔑 \(key): \(value)\n"
            }
        }
        
        // 2. 读取LeanCloudService的内存缓存
        cacheData += "\n\n🧠 [登录成功] LeanCloudService 内存缓存:\n"
        
        // 头像缓存
        let avatarCacheCount = LeanCloudService.shared.userAvatarCache.count
        cacheData += "👤 用户头像缓存: \(avatarCacheCount) 条\n"
        for (userId, avatarCache) in LeanCloudService.shared.userAvatarCache {
            cacheData += "   - \(userId): \(avatarCache.avatar) (时间: \(avatarCache.timestamp))\n"
        }
        
        // 用户名缓存
        let nameCacheCount = LeanCloudService.shared.userNameCache.count
        cacheData += "📝 用户名缓存: \(nameCacheCount) 条\n"
        for (userId, nameCache) in LeanCloudService.shared.userNameCache {
            cacheData += "   - \(userId): \(nameCache.name) (时间: \(nameCache.timestamp))\n"
        }
        
        // 登录记录缓存
        let loginCacheCount = LeanCloudService.shared.loginRecordCache.count
        cacheData += "🔐 登录记录缓存: \(loginCacheCount) 条\n"
        for (userId, loginCache) in LeanCloudService.shared.loginRecordCache {
            cacheData += "   - \(userId): \(loginCache.record != nil ? "有记录" : "无记录") (时间: \(loginCache.timestamp))\n"
        }
        
        // 内部登录记录缓存已删除
        
        // 在线状态缓存
        let onlineStatusCacheCount = LeanCloudService.shared.onlineStatusCache.count
        cacheData += "🟢 在线状态缓存: \(onlineStatusCacheCount) 条\n"
        for (userId, onlineStatusCache) in LeanCloudService.shared.onlineStatusCache {
            cacheData += "   - \(userId): \(onlineStatusCache.isOnline ? "在线" : "离线") (时间: \(onlineStatusCache.timestamp))\n"
        }
        
        // 3. 读取UserActionCacheManager的缓存
        cacheData += "\n\n⚡ [登录成功] UserActionCacheManager 缓存:\n"
        // 这里可以添加获取UserActionCacheManager缓存的方法
        
        // 4. 读取MessageButtonCacheManager的缓存
        cacheData += "\n\n💬 [登录成功] MessageButtonCacheManager 缓存:\n"
        // 这里可以添加获取MessageButtonCacheManager缓存的方法
        
        // 5. 读取Keychain数据（如果有的话）
        cacheData += "\n\n🔐 [登录成功] Keychain 数据:\n"
        // 这里可以添加Keychain数据的读取
        
        // 完成读取
    }
    
    /// 清理过期的缓存
    func cleanupExpiredCache() {
        CacheHelpers.cleanupExpiredCache(
            avatarCacheTimestamps: &avatarCacheTimestamps,
            userNameCacheTimestamps: &userNameCacheTimestamps,
            latestAvatars: &latestAvatars,
            latestUserNames: &latestUserNames,
            cacheExpirationInterval: cacheExpirationInterval
        )
    }
    
    /// 在数据更新完成后清理过期缓存
    func cleanupCacheAfterUpdate() {
        CacheHelpers.cleanupCacheAfterUpdate(
            avatarCacheTimestamps: &avatarCacheTimestamps,
            userNameCacheTimestamps: &userNameCacheTimestamps,
            latestAvatars: &latestAvatars,
            latestUserNames: &latestUserNames,
            cacheExpirationInterval: cacheExpirationInterval
        )
    }
    
    /// 检查用户缓存是否过期
    func isCacheExpired(for userId: String) -> Bool {
        return CacheHelpers.isCacheExpired(
            for: userId,
            avatarCacheTimestamps: avatarCacheTimestamps,
            userNameCacheTimestamps: userNameCacheTimestamps,
            cacheExpirationInterval: cacheExpirationInterval
        )
    }
    
    /// 获取缓存的消息数据
    func getCachedMessages() -> [MessageItem]? {
        guard let currentUser = userManager.currentUser else { return nil }
        
        let cacheKey = "CachedMessages_\(currentUser.userId)"
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let lastUpdateTime = UserDefaults.standard.object(forKey: "\(cacheKey)_LastUpdate") as? Date,
              Date().timeIntervalSince(lastUpdateTime) < 300 else { // 5分钟过期
            return nil
        }
        
        do {
            return try JSONDecoder().decode([MessageItem].self, from: data)
        } catch {
            return nil
        }
    }
    
    /// 获取缓存的拍一拍消息数据
    func getCachedPatMessages() -> [MessageItem]? {
        guard let currentUser = userManager.currentUser else { return nil }
        
        let cacheKey = "CachedPatMessages_\(currentUser.userId)"
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let lastUpdateTime = UserDefaults.standard.object(forKey: "\(cacheKey)_LastUpdate") as? Date,
              Date().timeIntervalSince(lastUpdateTime) < 300 else { // 5分钟过期
            return nil
        }
        
        do {
            return try JSONDecoder().decode([MessageItem].self, from: data)
        } catch {
            return nil
        }
    }
    
    /// 获取缓存的好友数据
    func getCachedFriends() -> [MatchRecord]? {
        guard let currentUser = userManager.currentUser else { return nil }
        
        let cacheKey = "CachedFriends_\(currentUser.userId)"
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let lastUpdateTime = UserDefaults.standard.object(forKey: "\(cacheKey)_LastUpdate") as? Date,
              Date().timeIntervalSince(lastUpdateTime) < 300 else { // 5分钟过期
            return nil
        }
        
        do {
            return try JSONDecoder().decode([MatchRecord].self, from: data)
        } catch {
            return nil
        }
    }
    
    /// 缓存消息数据
    func cacheMessages(_ messages: [MessageItem]) {
        guard let currentUser = userManager.currentUser else { return }
        
        let cacheKey = "CachedMessages_\(currentUser.userId)"
        do {
            let data = try JSONEncoder().encode(messages)
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: "\(cacheKey)_LastUpdate")
        } catch {
        }
    }
    
    /// 缓存拍一拍消息数据（优化：增加缓存容量）
    func cachePatMessages(_ messages: [MessageItem]) {
        guard let currentUser = userManager.currentUser else { return }
        
        // 优化：处理消息数量，确保缓存容量充足
        let processedMessages = MessageUtils.processPatMessages(messages)
        
        let cacheKey = "CachedPatMessages_\(currentUser.userId)"
        do {
            let data = try JSONEncoder().encode(processedMessages)
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: "\(cacheKey)_LastUpdate")
        } catch {
        }
    }
    
    /// 缓存好友数据
    func cacheFriends(_ friends: [MatchRecord]) {
        guard let currentUser = userManager.currentUser else { return }
        
        
        for (_, _) in friends.enumerated() {
        }
        
        let cacheKey = "CachedFriends_\(currentUser.userId)"
        do {
            let data = try JSONEncoder().encode(friends)
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: "\(cacheKey)_LastUpdate")
        } catch {
        }
    }
    
    // MARK: - Favorite Records Cache Management
    
    /// 加载喜欢记录
    func loadFavoriteRecords() {
        let key = StorageKeyUtils.getFavoriteRecordsKey(for: userManager.currentUser)
        // 从UserDefaults加载喜欢记录
        
        if let data = UserDefaults.standard.data(forKey: key),
           let records = try? JSONDecoder().decode([FavoriteRecord].self, from: data) {
            favoriteRecords = records
            // 成功从UserDefaults加载喜欢记录
        } else {
            // 无法从UserDefaults加载喜欢记录
            favoriteRecords = []
        }
    }
    
    /// 保存喜欢记录
    func saveFavoriteRecords() {
        let key = StorageKeyUtils.getFavoriteRecordsKey(for: userManager.currentUser)
        // 保存喜欢记录到UserDefaults
        
        if let data = try? JSONEncoder().encode(favoriteRecords) {
            UserDefaults.standard.set(data, forKey: key)
            // 成功保存到UserDefaults
        } else {
            // 编码失败，无法保存到UserDefaults
        }
    }
    
    /// 获取缓存的喜欢记录
    func getCachedFavoriteRecords() -> [FavoriteRecord]? {
        guard let currentUser = userManager.currentUser else { return nil }
        
        // 检查缓存是否过期（5分钟）
        let cacheKey = "CachedFavoriteRecords_\(currentUser.userId)"
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let lastUpdateTime = UserDefaults.standard.object(forKey: "\(cacheKey)_LastUpdate") as? Date,
              Date().timeIntervalSince(lastUpdateTime) < 300 else { // 5分钟过期
            if let lastUpdateTime = UserDefaults.standard.object(forKey: "\(cacheKey)_LastUpdate") as? Date {
                let _ = Date().timeIntervalSince(lastUpdateTime)
            } else {
            }
            return nil
        }
        
        do {
            let records = try JSONDecoder().decode([FavoriteRecord].self, from: data)
            return records
        } catch {
            return nil
        }
    }
    
    /// 获取缓存的喜欢我的用户记录
    func getCachedUsersWhoLikedMe() -> [FavoriteRecord]? {
        guard let currentUser = userManager.currentUser else { return nil }
        
        // 检查缓存是否过期（5分钟）
        let cacheKey = "CachedUsersWhoLikedMe_\(currentUser.userId)"
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let lastUpdateTime = UserDefaults.standard.object(forKey: "\(cacheKey)_LastUpdate") as? Date,
              Date().timeIntervalSince(lastUpdateTime) < 300 else { // 5分钟过期
            if let lastUpdateTime = UserDefaults.standard.object(forKey: "\(cacheKey)_LastUpdate") as? Date {
                let _ = Date().timeIntervalSince(lastUpdateTime)
            } else {
            }
            return nil
        }
        
        do {
            let records = try JSONDecoder().decode([FavoriteRecord].self, from: data)
            return records
        } catch {
            return nil
        }
    }
    
    /// 缓存喜欢记录
    func cacheFavoriteRecords(_ records: [FavoriteRecord]) {
        guard let currentUser = userManager.currentUser else { return }
        
        let cacheKey = "CachedFavoriteRecords_\(currentUser.userId)"
        do {
            let data = try JSONEncoder().encode(records)
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: "\(cacheKey)_LastUpdate")
        } catch {
        }
    }
    
    /// 缓存喜欢我的用户记录
    func cacheUsersWhoLikedMe(_ records: [FavoriteRecord]) {
        guard let currentUser = userManager.currentUser else { return }
        
        let cacheKey = "CachedUsersWhoLikedMe_\(currentUser.userId)"
        do {
            let data = try JSONEncoder().encode(records)
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date(), forKey: "\(cacheKey)_LastUpdate")
        } catch {
        }
    }
    
    // MARK: - Like Records Cache Management
    
    /// 获取点赞记录键名
    func getLikeRecordsKey() -> String {
        return UserHelpers.getLikeRecordsKey(currentUser: userManager.currentUser)
    }
    
    /// 加载点赞记录
    func loadLikeRecords() {
        let key = getLikeRecordsKey()
        // 从UserDefaults加载点赞记录
        
        if let data = UserDefaults.standard.data(forKey: key),
           let records = try? JSONDecoder().decode([LikeRecord].self, from: data) {
            // 🔧 修复：暂时保留所有记录，在 removeLikeRecord 中清理 recordObjectId 为 nil 的旧数据
            // 因为无法确定 recordObjectId 为 nil 的记录对应哪个 recordObjectId，所以暂时保留
            likeRecords = records
            // 成功从UserDefaults加载点赞记录
        } else {
            // 无法从UserDefaults加载点赞记录
            likeRecords = []
        }
    }
    
    /// 保存点赞记录
    func saveLikeRecords() {
        let key = getLikeRecordsKey()
        if let data = try? JSONEncoder().encode(likeRecords) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    // MARK: - Message View Data Cache Update
    
    /// 使用缓存数据更新消息界面
    func updateMessageViewDataWithCache() {
        guard let currentUser = userManager.currentUser else { return }
        
        
        // 检查是否有缓存的消息数据
        let cachedMessages = getCachedMessages()
        let cachedPatMessages = getCachedPatMessages()
        let cachedFriends = getCachedFriends()
        
        
        if let cachedMessages = cachedMessages,
           let cachedPatMessages = cachedPatMessages,
           let cachedFriends = cachedFriends {
            
            
            // 直接使用缓存数据更新UI
            
            // 直接在主线程执行，不使用异步
            
            
            // 强制立即赋值，不使用异步
            self.messageViewMessages = cachedMessages
            
            self.messageViewPatMessages = cachedPatMessages
            
            self.messageViewFriends = cachedFriends
            
            // 🚀 新增：设置消息数据后，检测匹配状态
            self.detectAndUpdateMatchStatus()
            
            // 打印缓存中的好友列表详情
            if cachedFriends.isEmpty {
            } else {
                for (_, friend) in cachedFriends.enumerated() {
                    let currentUserId = currentUser.userId
                    let _ = friend.user1Id == currentUserId ? friend.user2Id : friend.user1Id
                    let _ = friend.user1Id == currentUserId ? friend.user2Name : friend.user1Name
                    let _ = friend.user1Id == currentUserId ? friend.user2LoginType : friend.user1LoginType
                    let _ = friend.matchTime
                    
                }
            }
            
            
            // 检查UI状态
            
            // 强制UI刷新
            
            // 延迟检查，看看是否有其他代码在修改这些变量
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            }
            
        } else {
            
            // 缓存无效，从服务器获取数据
            DispatchQueue.global(qos: .userInitiated).async {
                // 获取消息数据
                LeanCloudService.shared.fetchMessages(userId: currentUser.id) { messages, error in
                    DispatchQueue.global(qos: .userInitiated).async {
                        if let messages = messages {
                            // 🎯 方案1：完全使用 _FriendshipRequest 表管理好友申请
                            // 不再从 Message 表过滤好友申请消息，好友申请由 FriendshipManager 管理
                            // 只处理拍一拍消息
                            let patMessages = MessageUtils.filterPatMessagesByUserId(messages, currentUserId: currentUser.id)
                            
                            // 处理拍一拍消息
                            let processedPatMessages = MessageUtils.processPatMessages(patMessages)
                            
                            // 缓存拍一拍消息数据
                            self.cachePatMessages(processedPatMessages)
                            
                            // 🎯 好友申请消息由 FriendshipManager 管理，不在这里处理
                            // messageViewMessages 应该由 FriendshipManager 的数据填充
                            // 这里只更新拍一拍消息
                            
                            // 回到主线程更新UI
                            DispatchQueue.main.async {
                            
                            // 更新消息界面数据（只更新拍一拍消息）
                            // messageViewMessages 由 FriendshipManager 管理，不在这里更新
                            self.messageViewPatMessages = processedPatMessages
                            
                            
                            
                            // 🚀 新增：设置消息数据后，检测匹配状态
                            self.detectAndUpdateMatchStatus()
                            
                            
                            // 🔧 新增：数据一致性验证
                            
                            }
                        } else {
                            DispatchQueue.main.async {
                                self.messageViewMessages = []
                                self.messageViewPatMessages = []
                                
                                
                                // 🚀 新增：设置消息数据后，检测匹配状态
                                self.detectAndUpdateMatchStatus()
                            }
                        }
                    }
                }
            }
            
            // ⚠️ 已废弃：不再从 MatchRecord 表获取好友数据
            // 好友列表现在由 FriendshipManager 从 _Followee 表获取
        }
    }
}
