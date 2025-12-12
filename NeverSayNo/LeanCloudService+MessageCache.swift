//
//  LeanCloudService+MessageCache.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation

// MARK: - 消息按钮专用缓存优化
extension LeanCloudService {
    
    // 消息按钮专用：智能缓存管理
    func optimizeMessageCache(userIds: [String], completion: @escaping ([String: String], [String: String]) -> Void) {
        guard !userIds.isEmpty else {
            completion([:], [:])
            return
        }
        
        let startTime = Date()
        var avatarResults: [String: String] = [:]
        var nameResults: [String: String] = [:]
        
        // 第一步：立即返回所有可用的缓存数据
        var uncachedUserIds: [String] = []
        
        for userId in userIds {
            // 检查头像缓存
            if let cachedAvatar = getCachedUserAvatar(for: userId) {
                avatarResults[userId] = cachedAvatar
            } else {
                uncachedUserIds.append(userId)
            }
            
            // 检查用户名缓存
            if let cachedName = getCachedUserName(for: userId) {
                nameResults[userId] = cachedName
            }
        }
        
        // 立即返回缓存数据，提供快速UI响应
        _ = Date().timeIntervalSince(startTime) * 1000
        completion(avatarResults, nameResults)
        
        // 第二步：后台检查并更新冲突数据
        if !uncachedUserIds.isEmpty {
            checkAndUpdateConflicts(userIds: uncachedUserIds, completion: { updatedAvatars, updatedNames in
                DispatchQueue.main.async {
                    // 合并更新后的数据
                    var finalAvatars = avatarResults
                    var finalNames = nameResults
                    
                    for (userId, avatar) in updatedAvatars {
                        finalAvatars[userId] = avatar
                    }
                    
                    for (userId, name) in updatedNames {
                        finalNames[userId] = name
                    }
                    
                    _ = Date().timeIntervalSince(startTime) * 1000
                }
            })
        }
    }
    
    // 检查并更新数据冲突
    private func checkAndUpdateConflicts(userIds: [String], completion: @escaping ([String: String], [String: String]) -> Void) {
        guard !userIds.isEmpty else {
            completion([:], [:])
            return
        }
        
        // 推断登录类型
        let loginTypes = userIds.map { UserTypeUtils.getLoginTypeFromUserId($0) }
        
        let group = DispatchGroup()
        var avatarResults: [String: String] = [:]
        var nameResults: [String: String] = [:]
        let lock = NSLock()
        
        // 批量获取头像
        group.enter()
        batchFetchUserAvatars(userIds: userIds, loginTypes: loginTypes) { avatars in
            lock.lock()
            avatarResults = avatars
            lock.unlock()
            group.leave()
        }
        
        // 批量获取用户名
        group.enter()
        batchFetchUserNames(userIds: userIds, loginTypes: loginTypes) { names in
            lock.lock()
            nameResults = names
            lock.unlock()
            group.leave()
        }
        
        group.notify(queue: .main) {
            // 更新全局缓存
            for (userId, avatar) in avatarResults {
                self.cacheUserAvatar(avatar, for: userId)
            }
            
            for (userId, name) in nameResults {
                self.cacheUserName(name, for: userId)
            }
            
            completion(avatarResults, nameResults)
        }
    }
    
    // 预加载消息相关用户的缓存数据
    func preloadMessageUserCache(userIds: [String]) {
        guard !userIds.isEmpty else { return }
        
        // 异步预加载，不阻塞UI
        DispatchQueue.global(qos: .background).async {
            let loginTypes = userIds.map { UserTypeUtils.getLoginTypeFromUserId($0) }
            
            // 预加载头像
            self.batchFetchUserAvatars(userIds: userIds, loginTypes: loginTypes) { avatars in
                for (userId, avatar) in avatars {
                    self.cacheUserAvatar(avatar, for: userId)
                }
            }
            
            // 预加载用户名
            self.batchFetchUserNames(userIds: userIds, loginTypes: loginTypes) { names in
                for (userId, name) in names {
                    self.cacheUserName(name, for: userId)
                }
            }
        }
    }
}

// MARK: - 用户类型工具类（使用现有的UserTypeUtils）
