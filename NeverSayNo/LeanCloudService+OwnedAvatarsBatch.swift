//
//  LeanCloudService+OwnedAvatarsBatch.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation
import LeanCloud

// MARK: - 头像列表批量处理功能
extension LeanCloudService {
    
    // 批量获取用户头像
    func batchFetchUserAvatars(userIds: [String], loginTypes: [String], completion: @escaping ([String: String]) -> Void) {
        guard !userIds.isEmpty else {
            completion([:])
            return
        }
        
        var avatarCache: [String: String] = [:]
        let dispatchGroup = DispatchGroup()
        
        for (index, userId) in userIds.enumerated() {
            // 修正登录类型：对于没有前缀的用户ID，应该是internal类型
            let loginType = index < loginTypes.count ? loginTypes[index] : UserTypeUtils.getLoginTypeFromUserId(userId)
            
            // 先检查缓存
            if let cachedAvatar = getCachedUserAvatar(userId: userId) {
                avatarCache[userId] = cachedAvatar
                continue
            }
            
            dispatchGroup.enter()
            
            // 🔍 追踪 userId 来源
            
            // ✅ 按照开发指南：使用 LCQuery 创建查询
            let query = LCQuery(className: "UserAvatarRecord")
            query.whereKey("userId", .equalTo(userId))
            query.whereKey("loginType", .equalTo(loginType))
            query.whereKey("createdAt", .descending)
            query.limit = 1
            
            query.find { result in
                defer { dispatchGroup.leave() }
                
                switch result {
                case .success(let records):
                    if let firstRecord = records.first,
                       let userAvatar = firstRecord["userAvatar"]?.stringValue {
                        avatarCache[userId] = userAvatar
                        self.cacheUserAvatar(userId: userId, avatar: userAvatar)
                    } else {
                        // 未找到头像，使用默认头像
                        avatarCache[userId] = UserAvatarUtils.defaultAvatar(for: "guest")
                    }
                case .failure:
                    // 查询失败，使用默认头像
                    avatarCache[userId] = UserAvatarUtils.defaultAvatar(for: "guest")
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(avatarCache)
        }
    }
    
    // 获取缓存的用户头像
    private func getCachedUserAvatar(userId: String) -> String? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        if let cachedData = userAvatarCache[userId],
           Date().timeIntervalSince(cachedData.timestamp) < cacheExpirationInterval {
            return cachedData.avatar
        }
        return nil
    }
    
    // 缓存用户头像
    private func cacheUserAvatar(userId: String, avatar: String) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        userAvatarCache[userId] = (avatar: avatar, timestamp: Date())
    }
}
