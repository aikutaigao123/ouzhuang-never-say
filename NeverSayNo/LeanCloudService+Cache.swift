import Foundation

// MARK: - 缓存管理扩展
extension LeanCloudService {
    
    // 启动缓存清理定时器 - 已禁用，改为在更新时手动清理
    func startCacheCleanupTimer() {
        // 注释掉自动定时清理，改为在数据更新时手动清理
        // Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
        //     self.cleanupExpiredCache()
        // }
    }
    
    // 清理过期缓存
    private func cleanupExpiredCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        let currentTime = Date()
        let expirationTime = currentTime.addingTimeInterval(-cacheExpirationInterval)
        let loginRecordExpirationTime = currentTime.addingTimeInterval(-loginRecordCacheExpirationInterval)
        
        // 清理头像缓存
        userAvatarCache = userAvatarCache.filter { _, value in
            value.timestamp > expirationTime
        }
        
        // 清理用户名缓存
        userNameCache = userNameCache.filter { _, value in
            value.timestamp > expirationTime
        }
        
        // 清理邮箱缓存
        userEmailCache = userEmailCache.filter { _, value in
            value.timestamp > expirationTime
        }
        
        // 清理钻石缓存
        userDiamondsCache = userDiamondsCache.filter { _, value in
            value.timestamp > expirationTime
        }
        
        // 清理登录记录缓存
        loginRecordCache = loginRecordCache.filter { _, value in
            value.timestamp > loginRecordExpirationTime
        }
        
        // 内部登录记录缓存已删除
        
        // 清理在线状态缓存
        let onlineStatusExpirationTime = currentTime.addingTimeInterval(-onlineStatusCacheExpirationInterval)
        onlineStatusCache = onlineStatusCache.filter { _, value in
            value.timestamp > onlineStatusExpirationTime
        }
        
        // 🎯 清理黑名单缓存（参考用户头像缓存机制）
        if let blacklistCacheEntry = blacklistCache,
           currentTime.timeIntervalSince(blacklistCacheEntry.timestamp) > blacklistCacheExpirationInterval {
            blacklistCache = nil
        }
        
    }
    
    // 公开的缓存清理方法，供外部调用
    func performCacheCleanup() {
        cleanupExpiredCache()
    }
    
    // 在数据更新完成后清理过期缓存
    func cleanupCacheAfterUpdate() {
        cleanupExpiredCache()
    }
    
    // 获取缓存的用户头像
    func getCachedUserAvatar(for userId: String) -> String? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        
        guard let cacheEntry = userAvatarCache[userId] else { 
            return nil 
        }
        
        // 检查是否过期
        let timeSinceCache = Date().timeIntervalSince(cacheEntry.timestamp)
        
        if timeSinceCache > cacheExpirationInterval {
            userAvatarCache.removeValue(forKey: userId)
            return nil
        }
        
        return cacheEntry.avatar
    }
    
    // 缓存用户头像
    func cacheUserAvatar(_ avatar: String, for userId: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        
        userAvatarCache[userId] = (avatar: avatar, timestamp: Date())
        
    }
    
    // 获取缓存的用户名
    func getCachedUserName(for userId: String) -> String? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        guard let cacheEntry = userNameCache[userId] else { return nil }
        
        // 检查是否过期
        if Date().timeIntervalSince(cacheEntry.timestamp) > cacheExpirationInterval {
            userNameCache.removeValue(forKey: userId)
            return nil
        }
        
        return cacheEntry.name
    }
    
    // 缓存用户名
    func cacheUserName(_ name: String, for userId: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        userNameCache[userId] = (name: name, timestamp: Date())
    }
    
    // 获取缓存的用户邮箱
    func getCachedUserEmail(for userId: String) -> String? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        guard let cacheEntry = userEmailCache[userId] else { return nil }
        
        // 检查是否过期
        if Date().timeIntervalSince(cacheEntry.timestamp) > cacheExpirationInterval {
            userEmailCache.removeValue(forKey: userId)
            return nil
        }
        
        return cacheEntry.email
    }
    
    // 缓存用户邮箱
    func cacheUserEmail(_ email: String, for userId: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        userEmailCache[userId] = (email: email, timestamp: Date())
    }
    
    // 获取缓存的钻石数
    func getCachedUserDiamonds(for userId: String) -> Int? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        guard let cacheEntry = userDiamondsCache[userId] else {
            return nil
        }
        
        // 检查是否过期
        let age = Date().timeIntervalSince(cacheEntry.timestamp)
        if age > cacheExpirationInterval {
            userDiamondsCache.removeValue(forKey: userId)
            return nil
        }
        
        return cacheEntry.diamonds
    }
    
    // 缓存钻石数
    func cacheUserDiamonds(_ diamonds: Int, for userId: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        userDiamondsCache[userId] = (diamonds: diamonds, timestamp: Date())
    }
    
    // 获取缓存的在线状态
    func getCachedOnlineStatus(for userId: String) -> (Bool, Date?)? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        guard let cacheEntry = onlineStatusCache[userId] else { 
            return nil 
        }
        
        // 检查是否过期
        if Date().timeIntervalSince(cacheEntry.timestamp) > onlineStatusCacheExpirationInterval {
            onlineStatusCache.removeValue(forKey: userId)
            return nil
        }
        
        return (cacheEntry.isOnline, cacheEntry.lastActiveTime)
    }
    
    // 缓存在线状态
    func cacheOnlineStatus(_ isOnline: Bool, lastActiveTime: Date?, for userId: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        onlineStatusCache[userId] = (isOnline: isOnline, lastActiveTime: lastActiveTime, timestamp: Date())
    }
    
    // 清除指定用户的缓存
    func clearCacheForUser(_ userId: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        userAvatarCache.removeValue(forKey: userId)
        userNameCache.removeValue(forKey: userId)
        userEmailCache.removeValue(forKey: userId)
        userDiamondsCache.removeValue(forKey: userId)
        onlineStatusCache.removeValue(forKey: userId)
    }
    
    // 清除所有缓存
    func clearAllCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        userAvatarCache.removeAll()
        userNameCache.removeAll()
        userEmailCache.removeAll()
        userDiamondsCache.removeAll()
        onlineStatusCache.removeAll()
        blacklistCache = nil // 🎯 清除黑名单缓存
    }
    
    // 🎯 获取缓存的黑名单（参考用户头像缓存机制）
    func getCachedBlacklist() -> [String]? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        guard let cacheEntry = blacklistCache else {
            return nil
        }
        
        // 检查是否过期
        let timeSinceCache = Date().timeIntervalSince(cacheEntry.timestamp)
        
        if timeSinceCache > blacklistCacheExpirationInterval {
            blacklistCache = nil
            return nil
        }
        
        return cacheEntry.blacklist
    }
    
    // 🎯 缓存黑名单（参考用户头像缓存机制）
    func cacheBlacklist(_ blacklist: [String]) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        blacklistCache = (blacklist: blacklist, timestamp: Date())
    }
    
    // 打印所有在线状态缓存
    func printAllOnlineStatusCache() {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        
        if onlineStatusCache.isEmpty {
            return
        }
        
        for (_, _) in onlineStatusCache {
        }
    }
}
