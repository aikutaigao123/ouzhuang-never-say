//
//  FriendsListView+CacheManagement.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//

import Foundation
import SwiftUI

// MARK: - Cache Management Extensions
extension FriendsListView {
    
    /// 获取缓存的用户头像
    func getCachedUserAvatar(userId: String, completion: @escaping (String) -> Void) {
        // 🎯 修改：不限制 loginType，尝试多种方式获取
        getCachedUserAvatar(userId: userId, loginType: nil, completion: completion)
    }
    
    /// 获取缓存的用户头像（带登录类型参数）
    func getCachedUserAvatar(userId: String, loginType: String?, completion: @escaping (String) -> Void) {
        // 🎯 新增：类似于用户头像界面的缓存机制
        // 1. 先检查内存缓存（快速）
        if let timestamp = avatarCacheTimestamps[userId],
           Date().timeIntervalSince(timestamp) < cacheExpirationInterval,
           let cachedAvatar = avatarCache[userId] {
            completion(cachedAvatar)
            return
        }
        
        // 2. 检查 UserDefaults 持久化缓存（次快）
        var persistedAvatar: String? = nil
        if let persisted = UserDefaultsManager.getFriendAvatar(userId: userId), !persisted.isEmpty {
            persistedAvatar = persisted
            // 先返回持久化缓存的数据，立即显示
            self.avatarCache[userId] = persisted
            self.avatarCacheTimestamps[userId] = Date()
            completion(persisted)
        }
        
        // 3. 从服务器获取最新数据（异步，更新缓存）
        // 🎯 修改：使用 fetchUserAvatarByUserId，不依赖 loginType，直接从 UserAvatarRecord 表获取
        LeanCloudService.shared.fetchUserAvatarByUserId(objectId: userId) { avatar, error in
            DispatchQueue.main.async {
                if let avatar = avatar, !avatar.isEmpty {
                    // 更新内存缓存
                    self.avatarCache[userId] = avatar
                    self.avatarCacheTimestamps[userId] = Date()
                    
                    // 🎯 新增：更新 UserDefaults 持久化缓存（类似于用户头像界面）
                    UserDefaultsManager.setFriendAvatar(userId: userId, avatar: avatar)
                    
                    // 如果之前没有持久化缓存，或者服务器数据与缓存不同，再次调用 completion 更新显示
                    if persistedAvatar == nil || persistedAvatar != avatar {
                        completion(avatar)
                    }
                } else {
                    // 如果查询失败，使用默认头像
                    let loginTypeToUse = loginType ?? UserTypeUtils.getLoginTypeFromUserId(userId)
                    let defaultAvatar = UserAvatarUtils.defaultAvatar(for: loginTypeToUse)
                    
                    // 更新内存缓存
                    self.avatarCache[userId] = defaultAvatar
                    self.avatarCacheTimestamps[userId] = Date()
                    
                    // 🎯 新增：更新 UserDefaults 持久化缓存
                    UserDefaultsManager.setFriendAvatar(userId: userId, avatar: defaultAvatar)
                    
                    // 如果之前没有返回持久化缓存，现在返回默认头像
                    if persistedAvatar == nil {
                        completion(defaultAvatar)
                    }
                }
            }
        }
    }
    
    /// 获取缓存的用户名
    func getCachedUserName(userId: String, completion: @escaping (String) -> Void) {
        // 🎯 修改：不限制 loginType，使用 fetchUserNameByUserId 方法
        getCachedUserName(userId: userId, loginType: nil, completion: completion)
    }
    
    /// 获取缓存的用户名（带登录类型参数）
    func getCachedUserName(userId: String, loginType: String?, completion: @escaping (String) -> Void) {
        // 检查缓存是否过期
        if let timestamp = userNameCacheTimestamps[userId],
           Date().timeIntervalSince(timestamp) < cacheExpirationInterval,
           let cachedName = userNameCache[userId] {
            completion(cachedName)
            return
        }
        
        // 🎯 修改：统一使用 fetchUserNameByUserId，不依赖 loginType，直接从 UserNameRecord 表获取
        fetchUserNameWithoutLoginType(userId: userId, completion: completion)
    }
    
    /// 不限制 loginType 获取用户名
    private func fetchUserNameWithoutLoginType(userId: String, completion: @escaping (String) -> Void) {
        // 🎯 新增：类似于用户头像界面的缓存机制
        // 1. 先检查内存缓存（快速）
        if let timestamp = userNameCacheTimestamps[userId],
           Date().timeIntervalSince(timestamp) < cacheExpirationInterval,
           let cachedName = userNameCache[userId] {
            completion(cachedName)
            return
        }
        
        // 2. 检查 UserDefaults 持久化缓存（次快）
        var persistedName: String? = nil
        if let persisted = UserDefaultsManager.getFriendUserName(userId: userId), !persisted.isEmpty {
            persistedName = persisted
            // 先返回持久化缓存的数据，立即显示
            self.userNameCache[userId] = persisted
            self.userNameCacheTimestamps[userId] = Date()
            completion(persisted)
        }
        
        // 3. 从服务器获取最新数据（异步，更新缓存）
        LeanCloudService.shared.fetchUserNameByUserId(objectId: userId) { name, error in
            DispatchQueue.main.async {
                if let name = name, !name.isEmpty {
                    // 更新内存缓存
                    self.userNameCache[userId] = name
                    self.userNameCacheTimestamps[userId] = Date()
                    
                    // 🎯 新增：更新 UserDefaults 持久化缓存（类似于用户头像界面）
                    UserDefaultsManager.setFriendUserName(userId: userId, userName: name)
                    
                    // 如果之前没有持久化缓存，或者服务器数据与缓存不同，再次调用 completion 更新显示
                    if persistedName == nil || persistedName != name {
                        completion(name)
                    }
                } else {
                    // 使用默认用户名
                    let defaultName = "未知用户"
                    
                    // 更新内存缓存
                    self.userNameCache[userId] = defaultName
                    self.userNameCacheTimestamps[userId] = Date()
                    
                    // 🎯 新增：更新 UserDefaults 持久化缓存
                    UserDefaultsManager.setFriendUserName(userId: userId, userName: defaultName)
                    
                    // 如果之前没有返回持久化缓存，现在返回默认用户名
                    if persistedName == nil {
                        completion(defaultName)
                    }
                }
            }
        }
    }
    
    /// 获取缓存的用户登录类型
    func getCachedUserLoginType(userId: String, completion: @escaping (String) -> Void) {
        // 🎯 修改：从服务器获取真实的登录类型
        // 首先尝试从 UserNameRecord 表获取
        LeanCloudService.shared.fetchUserLoginType(objectId: userId) { loginType in
            DispatchQueue.main.async {
                if let loginType = loginType, !loginType.isEmpty {
                    completion(loginType)
                } else {
                    // 如果获取失败，根据 userId 推断（兜底逻辑）
                    let inferredType = UserTypeUtils.getLoginTypeFromUserId(userId)
                    completion(inferredType)
                }
            }
        }
    }
    
    /// 从持久化存储恢复缓存（类似于用户头像界面的缓存机制）
    func restoreCacheFromPersistence() {
        // 🎯 修改：不再使用批量恢复，而是在需要时从 UserDefaults 逐个读取
        // 这样可以保持与用户头像界面一致的缓存机制
        // 在线状态缓存不进行持久化存储，因为包含复杂类型
    }
    
    /// 为好友列表批量恢复缓存（在加载好友列表时调用）
    func restoreCacheForFriends(_ friendIds: [String]) {
        // 🎯 新增：为好友列表批量从 UserDefaults 恢复缓存
        for friendId in friendIds {
            // 恢复头像缓存
            if let persistedAvatar = UserDefaultsManager.getFriendAvatar(userId: friendId), !persistedAvatar.isEmpty {
                self.avatarCache[friendId] = persistedAvatar
                self.avatarCacheTimestamps[friendId] = Date()
            }
            
            // 恢复用户名缓存
            if let persistedName = UserDefaultsManager.getFriendUserName(userId: friendId), !persistedName.isEmpty {
                self.userNameCache[friendId] = persistedName
                self.userNameCacheTimestamps[friendId] = Date()
            }
        }
    }
    
    /// 清理过期缓存
    func cleanupExpiredCache() {
        let now = Date()
        
        // 清理过期的头像缓存
        avatarCacheTimestamps = avatarCacheTimestamps.filter { (userId, timestamp) in
            now.timeIntervalSince(timestamp) < cacheExpirationInterval
        }
        
        // 清理过期的用户名缓存
        userNameCacheTimestamps = userNameCacheTimestamps.filter { (userId, timestamp) in
            now.timeIntervalSince(timestamp) < cacheExpirationInterval
        }
        
        // 清理过期的在线状态缓存
        onlineStatusCache = onlineStatusCache.filter { (userId, status) in
            if let lastUpdate = status.1 {
                return now.timeIntervalSince(lastUpdate) < cacheExpirationInterval
            }
            return true
        }
    }
    
    /// 更新后清理缓存
    func cleanupCacheAfterUpdate() {
        // 清理所有缓存，强制重新获取
        avatarCache.removeAll()
        userNameCache.removeAll()
        onlineStatusCache.removeAll()
        avatarCacheTimestamps.removeAll()
        userNameCacheTimestamps.removeAll()
    }
}
