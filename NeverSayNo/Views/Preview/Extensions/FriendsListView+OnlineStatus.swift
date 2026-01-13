//
//  FriendsListView+OnlineStatus.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//

import Foundation
import SwiftUI

// MARK: - Online Status Extensions
extension FriendsListView {
    
    // MARK: - Online Status Methods
    
    /// 批量查询所有好友的在线状态（优化版本）
    func batchLoadOnlineStatus() {
        // 防止重复调用
        guard !hasBatchLoadedOnlineStatus && !isBatchLoadingOnlineStatus else {
            return
        }
        
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        for (_, _) in friends.enumerated() {
        }
        
        // 收集所有需要检查在线状态的好友ID
        var friendIds: Set<String> = []
        
        for friend in friends {
            let friendId = friend.user1Id == currentUser.id ? friend.user2Id : friend.user1Id
            friendIds.insert(friendId)
        }
        
        for _ in friendIds {
        }
        
        guard !friendIds.isEmpty else {
            return
        }
        
        isBatchLoadingOnlineStatus = true
        let friendIdsArray = Array(friendIds)
        let batchStartTime = Date()
        
        
        LeanCloudService.shared.batchFetchUserLastOnlineTime(userIds: friendIdsArray) { results in
            DispatchQueue.main.async {
                // 批量更新缓存
                for (userId, (isOnline, lastActiveTime)) in results {
                    self.onlineStatusCache[userId] = (isOnline, lastActiveTime)
                    
                    // 更新全局缓存
                    LeanCloudService.shared.cacheOnlineStatus(isOnline, lastActiveTime: lastActiveTime, for: userId)
                    
                    // 打印每个好友的在线状态
                    if let lastActive = lastActiveTime {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                        formatter.timeZone = TimeZone.current
                        let _ = formatter.string(from: lastActive)
                        
                        let _ = Date()
                        let _ = Date().timeIntervalSince(lastActive)
                        let _ = self.formatTimeAgo(Date().timeIntervalSince(lastActive))
                        
                    } else {
                    }
                }
                
                // 计算批量查询总耗时
                let batchEndTime = Date()
                let _ = batchEndTime.timeIntervalSince(batchStartTime)
                
                self.hasBatchLoadedOnlineStatus = true
                self.isBatchLoadingOnlineStatus = false
            }
        }
    }
    
    /// 打印每个好友的在线状态
    func printFriendsOnlineStatus() {
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        for (_, friend) in friends.enumerated() {
            let _ = friend.user1Id == currentUser.id ? friend.user2Id : friend.user1Id
            let _ = friend.user1Id == currentUser.id ? friend.user2Name : friend.user1Name
            
            // 异步获取在线状态
            friend.getFriendOnlineStatus(currentUserId: currentUser.id) { isOnline, lastActiveTime in
                DispatchQueue.main.async {
                    let _ = isOnline ? "🟢 在线" : "🔴 离线"
                    if let lastActive = lastActiveTime {
                        let timeInterval = Date().timeIntervalSince(lastActive)
                        let _ = " (最后活跃: \(self.formatTimeAgo(timeInterval)))"
                    }
                    
                    // 好友在线状态已获取
                }
            }
        }
    }
    
    /// 格式化时间间隔
    func formatTimeAgo(_ timeInterval: TimeInterval) -> String {
        let seconds = Int(timeInterval)
        let minutes = seconds / 60
        let hours = minutes / 60
        let days = hours / 24
        
        if days > 0 {
            // 与 TimeAgoUtils 保持一致：超过7天统一显示“7天前”
            return days > 7 ? "7天前" : "\(days)天前"
        } else if hours > 0 {
            return "\(hours)小时前"
        } else if minutes > 0 {
            return "\(minutes)分钟前"
        } else {
            return "刚刚"
        }
    }
}

