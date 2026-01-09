//
//  LegacySearchView+FriendsListManagement.swift
//  NeverSayNo
//
//  Created by Die chen on 2025/7/1.
//

import SwiftUI
import Foundation
import LeanCloud

extension LegacySearchView {
    // MARK: - Friends List Management Methods
    
    /// 打印同步后的好友列表
    func printFriendsListAfterSync() {
        // 🚀 在好友数据加载完成后，更新所有好友头像
        updateAllFriendsAvatarsInRealTime()
    }
    
    /// 打印同步后的新朋友列表
    func printNewFriendsListAfterSync() {
        // 调试函数已删除
    }
    
    /// 详细打印我的好友列表
    func printDetailedFriendsList() {
        // 调试函数已删除
    }
    
    /// 打印好友列表信息
    func printFriendsListInfo() {
        guard userManager.currentUser != nil else {
            return
        }
        
        // 使用匹配成功判断逻辑：基于favoriteRecords和usersWhoLikedMe
        // 获取所有双向喜欢的用户对
        var matchedUsers: [String] = []
        
        // 遍历当前用户喜欢的所有用户
        for favoriteRecord in favoriteRecords {
            let targetUserId = favoriteRecord.favoriteUserId
            
            // 检查是否双向喜欢：当前用户喜欢目标用户 && 目标用户喜欢当前用户
            let currentUserLikesTarget = isUserFavorited(userId: targetUserId)
            let targetLikesCurrentUser = isUserFavoritedByMe(userId: targetUserId)
            
            if currentUserLikesTarget && targetLikesCurrentUser {
                matchedUsers.append(targetUserId)
            }
        }
        
    }
    
    /// 获取好友列表
    func getFriendsList() {
        guard userManager.currentUser != nil else {
            return
        }
        
        // 使用匹配成功判断逻辑：基于favoriteRecords和usersWhoLikedMe
        // 获取所有双向喜欢的用户对
        var matchedUsers: [String] = []
        
        // 遍历当前用户喜欢的所有用户
        for favoriteRecord in favoriteRecords {
            let targetUserId = favoriteRecord.favoriteUserId
            
            // 检查是否双向喜欢：当前用户喜欢目标用户 && 目标用户喜欢当前用户
            let currentUserLikesTarget = isUserFavorited(userId: targetUserId)
            let targetLikesCurrentUser = isUserFavoritedByMe(userId: targetUserId)
            
            if currentUserLikesTarget && targetLikesCurrentUser {
                matchedUsers.append(targetUserId)
            }
        }
        
        for userId in matchedUsers {
            // 从favoriteRecords中获取好友信息
            if favoriteRecords.first(where: { $0.favoriteUserId == userId }) != nil {
                // 获取好友的最近上线时间
                self.getFriendLastOnlineTime(userId: userId) { lastOnlineTime in
                    // 处理最近上线时间，但不打印
                }
            }
        }
    }
    
    /// 获取好友的最近上线时间（使用统一方法）
    func getFriendLastOnlineTime(userId: String, completion: @escaping (Date?) -> Void) {
        
        LeanCloudService.shared.fetchUserLastOnlineTime(userId: userId) { isOnline, lastActiveTime in
            completion(lastActiveTime)
        }
    }
    
    /// 打印好友列表和登录记录
    func printFriendsListAndLoginRecords() {
        guard userManager.currentUser != nil else {
            return
        }
        
        // 使用匹配成功判断逻辑：基于favoriteRecords和usersWhoLikedMe
        // 获取所有双向喜欢的用户对
        var matchedUsers: [String] = []
        
        // 遍历当前用户喜欢的所有用户
        for favoriteRecord in favoriteRecords {
            let targetUserId = favoriteRecord.favoriteUserId
            
            // 检查是否双向喜欢：当前用户喜欢目标用户 && 目标用户喜欢当前用户
            let currentUserLikesTarget = isUserFavorited(userId: targetUserId)
            let targetLikesCurrentUser = isUserFavoritedByMe(userId: targetUserId)
            
            if currentUserLikesTarget && targetLikesCurrentUser {
                matchedUsers.append(targetUserId)
            }
        }
        
        if matchedUsers.isEmpty {
            return
        }
        
        // 使用DispatchGroup来等待所有好友的详细信息获取完成
        let group = DispatchGroup()
        
        for userId in matchedUsers {
            group.enter()
            
            // 从favoriteRecords中获取好友基本信息
            if favoriteRecords.first(where: { $0.favoriteUserId == userId }) != nil {
                // 获取好友的最近上线时间
                self.getFriendLastOnlineTime(userId: userId) { lastOnlineTime in
                    if let lastOnlineTime = lastOnlineTime {
                        let now = Date()
                        let timeInterval = now.timeIntervalSince(lastOnlineTime)
                        let isOnline = timeInterval <= 600 // 10分钟 = 600秒
                        
                        if !isOnline {
                            if timeInterval >= 7 * 24 * 3600 {
                            } else {
                            }
                        }
                    }
                    
                    group.leave()
                }
            } else {
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            // 打印LoginRecord表和InternalLoginRecord表
            let tableGroup = DispatchGroup()
            
            // 打印LoginRecord表内容
            tableGroup.enter()
            self.printLoginRecords { 
                tableGroup.leave()
            }
            
            // 打印InternalLoginRecord表内容
            tableGroup.enter()
            self.printInternalLoginRecords { 
                tableGroup.leave()
            }
            
            tableGroup.notify(queue: .main) {
            }
        }
    }
    
    /// 打印LoginRecord表内容
    func printLoginRecords(completion: @escaping () -> Void) {
        LeanCloudService.shared.fetchAllLoginRecords { records in
            DispatchQueue.main.async {
                completion()
            }
        }
    }
    
    /// 打印InternalLoginRecord表内容
    func printInternalLoginRecords(completion: @escaping () -> Void) {
        LeanCloudService.shared.fetchAllInternalLoginRecords { records in
            DispatchQueue.main.async {
                completion()
            }
        }
    }
    
    /// 打印好友列表
    func printFriendsList() {
        // ⚠️ 已废弃：不再从 MatchRecord 表获取好友列表
        // 好友列表现在由 FriendshipManager 从 _Followee 表获取
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        
        // ⚠️ 已废弃：不再重新获取好友数据
        if false {
            // 重新获取好友数据（已废弃）
            LeanCloudService.shared.fetchMatchRecords(userId: currentUser.userId) { friends, error in
                DispatchQueue.main.async {
                    // 🔧 修复：保护已创建的好友数据，避免被服务器空数据覆盖
                    if let friends = friends {
                        if friends.isEmpty {
                            // 检查双向喜欢逻辑
                            var matchedUsers: [String] = []
                            for favoriteRecord in self.favoriteRecords {
                                let targetUserId = favoriteRecord.favoriteUserId
                                
                                if targetUserId != currentUser.userId {
                                    // 检查当前用户是否喜欢目标用户
                                    let currentUserLikesTarget = self.isUserFavorited(userId: targetUserId)
                                    
                                    // 检查目标用户是否喜欢当前用户
                                    let targetLikesCurrentUser = self.isUserFavoritedByMe(userId: targetUserId)
                                    
                                    if currentUserLikesTarget && targetLikesCurrentUser {
                                        if !matchedUsers.contains(targetUserId) {
                                            matchedUsers.append(targetUserId)
                                        }
                                    }
                                }
                            }
                            if !matchedUsers.isEmpty {
                                
                                // 执行双向喜欢逻辑并创建好友记录
                                let friendsFromMatchedUsers = self.createMatchRecordsFromDualLike(matchedUsers: matchedUsers, usersWhoLikedMeToUse: self.usersWhoLikedMe)
                                
                                self.printFriendsListDetails(friends: friendsFromMatchedUsers, currentUser: currentUser)
                                
                                // 将双向喜欢逻辑创建的好友记录传递给UI和缓存
                                DispatchQueue.main.async {
                                    
                                    // 🔧 修复：正确更新好友列表，支持添加新好友
                                    
                                    // 合并现有好友和新匹配的好友，避免重复
                                    var updatedFriends = self.messageViewFriends
                                    for newFriend in friendsFromMatchedUsers {
                                        // 检查是否已存在相同的好友
                                        let friendId = newFriend.user1Id == currentUser.userId ? newFriend.user2Id : newFriend.user1Id
                                        let exists = updatedFriends.contains { existingFriend in
                                            let existingFriendId = existingFriend.user1Id == currentUser.userId ? existingFriend.user2Id : existingFriend.user1Id
                                            return existingFriendId == friendId
                                        }
                                        
                                        if !exists {
                                            updatedFriends.append(newFriend)
                                        } else {
                                        }
                                    }
                                    
                                    // 更新好友列表
                                    self.messageViewFriends = updatedFriends
                                    self.cacheFriends(updatedFriends)
                                    
                                    // 🔧 新增：将好友记录保存到LeanCloud的MatchRecord表
                                    self.saveMatchRecordsToLeanCloud(friendsFromMatchedUsers)
                                    
                                    
                                    
                                    // 立即检查MessageView是否已经显示
                                    if self.showMessageSheet {
                                    } else {
                                        // 🔧 修复：数据加载完成后显示MessageView
                                        self.showMessageSheet = true
                                    }
                                }
                            } else {
                                self.printFriendsListDetails(friends: friends, currentUser: currentUser)
                            }
                        } else {
                            self.printFriendsListDetails(friends: friends, currentUser: currentUser)
                        }
                    }
                }
            }
        } else {
            printFriendsListDetails(friends: messageViewFriends, currentUser: currentUser)
        }
    }
    
    /// 打印好友列表详情
    func printFriendsListDetails(friends: [MatchRecord], currentUser: UserInfo) {
        // 调试函数已删除
    }
}

