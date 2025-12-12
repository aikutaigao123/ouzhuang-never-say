//
//  LegacySearchView+UserDataQuery.swift
//  NeverSayNo
//
//  Created by Die chen on 2025/7/1.
//

import SwiftUI
import Foundation
import LeanCloud

extension LegacySearchView {
    // MARK: - User Data Query Methods
    
    /// 分析好友在线状态和3个表的数据
    func analyzeFriendsOnlineStatus() {
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        // 开始分析所有好友的最近上线时间
        // 当前用户ID: \(currentUser.userId)
        // favoriteRecords总数: \(favoriteRecords.count)
        
        // 打印所有favoriteRecords
        for (_, _) in favoriteRecords.enumerated() {
            // \(index+1). 用户ID: \(record.favoriteUserId)
        }
        
        // 获取所有双向喜欢的用户（好友）
        var friendsList: [String] = []
        var allTargetUsers: [String] = []
        
        for favoriteRecord in favoriteRecords {
            let targetUserId = favoriteRecord.favoriteUserId
            allTargetUsers.append(targetUserId)
            
            if targetUserId == currentUser.userId {
                // 跳过自己: \(targetUserId)
                continue
            }
            
            let currentUserLikesTarget = isUserFavorited(userId: targetUserId)
            let targetLikesCurrentUser = isUserFavoritedByMe(userId: targetUserId)
            
            // 用户: \(targetUserId)
            // 我喜欢他: \(currentUserLikesTarget)
            // 他喜欢我: \(targetLikesCurrentUser)
            
            if currentUserLikesTarget && targetLikesCurrentUser {
                if !friendsList.contains(targetUserId) {
                    friendsList.append(targetUserId)
                    // 添加为好友: \(targetUserId)
                }
            } else {
                // 不是好友: \(targetUserId)
            }
        }
        
        // 所有目标用户: \(allTargetUsers)
        // 找到 \(friendsList.count) 个好友: \(friendsList)
        
        // 分析每个好友的在线状态
        if friendsList.isEmpty {
            // 没有找到好友，显示所有用户的最近上线时间
            
            // 如果没有好友，显示所有用户的最近上线时间
            let allUsers = Set(allTargetUsers).filter { $0 != currentUser.userId }
            // 开始分析 \(allUsers.count) 个用户的最近上线时间
            
            for (_, userId) in allUsers.enumerated() {
                // 分析用户 \(index+1)/\(allUsers.count): \(userId)
                self.analyzeUserOnlineStatus(userId: userId, isFriend: false)
            }
        } else {
            for (_, friendId) in friendsList.enumerated() {
                // 分析好友 \(index+1)/\(friendsList.count): \(friendId)
                self.analyzeUserOnlineStatus(userId: friendId, isFriend: true)
            }
        }
    }
    
    /// 分析用户在线状态
    func analyzeUserOnlineStatus(userId: String, isFriend: Bool) {
        let _ = isFriend ? "好友" : "用户"
        // 开始分析 \(userType): \(userId)
        
        // 获取用户的最近上线时间
        LeanCloudService.shared.fetchUserLastOnlineTime(userId: userId) { isOnline, lastActiveTime in
            DispatchQueue.main.async {
                // 在线状态: \(isOnline ? "🟢 在线" : "🔴 离线")
                
                if let lastActiveTime = lastActiveTime {
                    let timeFormatter = DateFormatter()
                    timeFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    timeFormatter.timeZone = TimeZone.current
                    let _ = timeFormatter.string(from: lastActiveTime)
                    
                    let now = Date()
                    let _ = now.timeIntervalSince(lastActiveTime)
                    let _ = TimeAgoUtils.formatTimeAgo(from: lastActiveTime)
                    
                    // 最近上线时间: \(formattedTime)
                    // 时间差: \(timeAgo)
                } else {
                    // 最近上线时间: 无数据
                }
                
                // 获取3个表中的具体数据
                self.getFriendTableData(friendId: userId)
            }
        }
    }
    
    /// 根据用户ID获取用户名
    func getUserNameById(_ userId: String) -> String? {
        return UserHelpers.getUserNameById(userId, latestUserNames: latestUserNames)
    }
    
    /// 获取指定用户的消息
    func getMessagesForUser(_ userId: String) -> [MessageItem] {
        // 合并所有消息数据
        let allMessages = messageViewMessages + messageViewPatMessages
        return allMessages.filter { message in
            // 检查消息是否与当前用户和指定用户相关
            let isFromCurrentUser = message.senderId == userManager.currentUser?.id
            let isToCurrentUser = message.receiverId == userManager.currentUser?.id
            let isFromFriend = message.senderId == userId
            let isToFriend = message.receiverId == userId
            
            // 消息必须涉及当前用户和指定好友
            return (isFromCurrentUser && isToFriend) || (isFromFriend && isToCurrentUser)
        }
    }
    
    /// 获取好友在3个表中的具体数据
    func getFriendTableData(friendId: String) {
        // 开始查询好友 \(friendId) 在3个表中的数据
        
        let group = DispatchGroup()
        
        // 1. 查询 LocationRecord 表
        group.enter()
        LeanCloudService.shared.fetchLatestLocationForUser(userId: friendId) { locationRecord, error in
            if locationRecord != nil {
                // 好友 \(friendId):
                // 时间戳: \(locationRecord.timestamp)
                // 位置: \(locationRecord.latitude), \(locationRecord.longitude)
                // 用户名: \(locationRecord.userName ?? "无")
                // 登录类型: \(locationRecord.loginType ?? "无")
            } else {
                // 好友 \(friendId): 无位置记录
            }
            group.leave()
        }
        
        // 2. 查询 LoginRecord 表
        group.enter()
        LeanCloudService.shared.fetchLatestLoginRecord(userId: friendId) { loginRecord in
            if loginRecord != nil {
                // 好友 \(friendId):
                // 登录时间: \(loginRecord.loginTime)
                // 用户名: \(loginRecord.userName)
                // 登录类型: \(loginRecord.loginType)
                // 邮箱: \(loginRecord.userEmail ?? "无")
                // 设备ID: \(loginRecord.deviceId)
            } else {
                // 好友 \(friendId): 无登录记录
            }
            group.leave()
        }
        
        // 3. 查询 LoginRecord 表（InternalLoginRecord 已删除）
        group.enter()
        LeanCloudService.shared.fetchLatestLoginRecord(userId: friendId) { loginRecord in
            if let loginRecord = loginRecord {
                let loginTimeString = loginRecord.loginTime
                let formatter = ISO8601DateFormatter()
                if let loginTime = formatter.date(from: loginTimeString) {
                    let timeFormatter = DateFormatter()
                    timeFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    timeFormatter.timeZone = TimeZone.current
                    let _ = timeFormatter.string(from: loginTime)
                    
                    // 好友 \(friendId):
                    // 登录时间: \(formattedTime)
                }
            } else {
                // 好友 \(friendId): 无登录记录
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            // 好友 \(friendId) 的3个表数据查询完成
        }
    }
    
    /// 获取当前用户头像
    func getCurrentUserAvatar() -> String {
        return UserHelpers.getCurrentUserAvatar(currentUser: userManager.currentUser)
    }
}

