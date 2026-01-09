//
//  FriendsListView+Actions.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//

import Foundation
import SwiftUI

// MARK: - Actions Extensions
extension FriendsListView {
    
    // MARK: - Action Methods
    
    /// 处理查看位置功能
    func handleViewLocation(friendId: String) {
        // 从LeanCloud获取该用户的最新位置记录
        LeanCloudService.shared.fetchLatestLocationForUser(userId: friendId) { locationRecord, error in
            DispatchQueue.main.async {
                if error != nil {
                    // 可以显示错误提示
                } else if let locationRecord = locationRecord {
                    // 发送通知显示位置信息
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ShowFriendLocation"),
                        object: locationRecord
                    )
                    // 跳转回主页面
                    dismiss()
                } else {
                    // 可以显示"好友暂无位置信息"的提示
                }
            }
        }
    }
    
    /// 检查匹配成功UI显示与好友数量的一致性
    func checkMatchStatusConsistency(matchedUsersCount: Int) {
        // 计算匹配成功的消息数量（从消息界面获取）
        // 这里我们需要从消息界面获取匹配成功的消息数量
        // 由于FriendsListView没有直接访问消息数据，我们通过计算来验证
        
        // 计算实际的好友数量（基于双向喜欢关系）
        var actualFriendCount = 0
        for favoriteRecord in favoriteRecords {
            let targetUserId = favoriteRecord.favoriteUserId
            let currentUserLikesTarget = isUserFavorited(targetUserId)
            let targetLikesCurrentUser = isUserFavoritedByMe(targetUserId)
            
            if currentUserLikesTarget && targetLikesCurrentUser {
                actualFriendCount += 1
            }
        }
        
        // 如果不一致，打印详细信息
        if matchedUsersCount != actualFriendCount {
            // 一致性检查逻辑已移除
        }
    }
    
    /// 打印所有本地在线状态缓存
    func printAllLocalOnlineStatusCache() {
        if onlineStatusCache.isEmpty {
            return
        }
        
        for (_, _) in onlineStatusCache {
        }
    }
}

