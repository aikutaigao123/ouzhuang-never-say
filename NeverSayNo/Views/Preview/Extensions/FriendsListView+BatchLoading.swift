//
//  FriendsListView+BatchLoading.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//

import Foundation
import SwiftUI

// MARK: - Batch Loading Extensions
extension FriendsListView {
    
    // MARK: - Batch Loading Methods
    
    /// 批量查询所有好友的用户名和头像（像最近上线时间一样的逻辑）
    func batchLoadUserNameAndAvatar() {
        // 防止重复调用
        guard !hasBatchLoadedUserNameAvatar && !isBatchLoadingUserNameAvatar else {
            return
        }
        
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        for (_, _) in friends.enumerated() {
        }
        
        // 收集所有需要检查用户名和头像的好友ID
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
        
        isBatchLoadingUserNameAvatar = true
        let friendIdsArray = Array(friendIds)
        let batchStartTime = Date()
        
        LeanCloudService.shared.batchFetchUserNameAndAvatar(userIds: friendIdsArray) { avatarResults, userNameResults, loginTypeResults in
            DispatchQueue.main.async {
                // 批量更新缓存
                for (userId, avatar) in avatarResults {
                    self.avatarCache[userId] = avatar
                    
                    // 打印每个好友的头像
                }
                
                for (userId, userName) in userNameResults {
                    self.userNameCache[userId] = userName
                    
                    // 打印每个好友的用户名
                }
                
                for (userId, loginType) in loginTypeResults {
                    self.loginTypeCache[userId] = loginType
                    
                    // 打印每个好友的用户类型
                }
                
                // 计算批量查询总耗时
                let batchEndTime = Date()
                let _ = batchEndTime.timeIntervalSince(batchStartTime)
                
                self.hasBatchLoadedUserNameAvatar = true
                self.isBatchLoadingUserNameAvatar = false
            }
        }
    }
}

