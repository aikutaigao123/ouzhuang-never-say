//
//  LegacySearchView+AvatarManagement.swift
//  NeverSayNo
//
//  Created by AI Assistant on 2024
//  Avatar management logic for LegacySearchView
//

import SwiftUI
import Foundation

// MARK: - Avatar Management Extension
extension LegacySearchView {
    
    /// 刷新所有显示用户的最新头像和用户名（优化版本）
    func refreshSearchViewAvatars() {
        // 防止重复调用
        guard !isRefreshing else {
            return
        }
        
        isRefreshing = true
        
        // 收集所有需要获取数据的用户ID（去重）
        var uniqueUserIds: [String] = []
        var loginTypes: [String] = []
        
        // 添加当前匹配用户
        if let record = randomRecord {
            let userId = record.userId
            uniqueUserIds.append(userId)
            // 修正登录类型：对于没有前缀的用户ID，应该是internal类型
            let correctedLoginType = record.loginType ?? UserTypeUtils.getLoginTypeFromUserId(record.userId)
            loginTypes.append(correctedLoginType)
        }
        
        // 添加历史记录中的所有用户
        for historyItem in randomMatchHistory {
            let userId = historyItem.record.userId
            if !uniqueUserIds.contains(userId) { // 避免重复
                uniqueUserIds.append(userId)
                // 修正登录类型：对于没有前缀的用户ID，应该是internal类型
                let correctedLoginType = historyItem.record.loginType ?? UserTypeUtils.getLoginTypeFromUserId(historyItem.record.userId)
                loginTypes.append(correctedLoginType)
            }
        }
        
        
        // 使用优化的批量获取方法
        if !uniqueUserIds.isEmpty {
            LeanCloudService.shared.batchFetchUserDataForHistory(userIds: uniqueUserIds, loginTypes: loginTypes) { avatarResults, nameResults in
                DispatchQueue.main.async {
                    // 更新本地缓存
                    self.latestAvatars = avatarResults
                    self.latestUserNames = nameResults
                    
                    // 更新缓存时间戳
                    let now = Date()
                    for userId in uniqueUserIds {
                        if avatarResults[userId] != nil {
                            self.avatarCacheTimestamps[userId] = now
                        }
                        if nameResults[userId] != nil {
                            self.userNameCacheTimestamps[userId] = now
                        }
                    }
                    
                    
                    // 重置刷新标志
                    self.isRefreshing = false
                }
            }
        } else {
            self.isRefreshing = false
        }
        
        // 清理过期的缓存
        LeanCloudService.shared.performCacheCleanup()
    }
}
