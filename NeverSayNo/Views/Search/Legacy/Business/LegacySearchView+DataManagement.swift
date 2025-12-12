//
//  LegacySearchView+DataManagement.swift
//  NeverSayNo
//
//  Created by AI Assistant on 2024
//  Data management methods for LegacySearchView
//

import SwiftUI
import Foundation
import CoreLocation
import LeanCloud

// MARK: - Data Management Extension
extension LegacySearchView {
    
    // loadFavoriteRecords method moved to LegacySearchView+CacheManagement.swift
    
    /// 获取指定用户的爱心状态
    func getHeartStatusForUser(userId: String) -> String {
        return UserHelpers.getHeartStatusForUser(
            userId: userId,
            isUserFavorited: isUserFavorited,
            isUserFavoritedByMe: isUserFavoritedByMe
        )
    }
    
    
    // printMyFriendsList and printFriendsListAfterSync methods moved to LegacySearchView+FriendsListManagement.swift
    
    // syncMessagesAndPrintNewFriendsList, verifyPatMessageSync, fetchAndPrintMessages, and handleMessageButtonTap methods moved to LegacySearchView+MessageSync.swift
    
    // printNewFriendsListAfterSync method moved to LegacySearchView+FriendsListManagement.swift
    
    // detectAndPrintMatchSuccessStatus, detectAndUpdateMatchStatus, handleMatchSuccess, and updateMessageMatchStatusForUser methods moved to LegacySearchView+MatchStatus.swift
    
    /// 详细打印我的好友列表
    // printDetailedFriendsList method moved to LegacySearchView+FriendsListManagement.swift
    
    /// 将MatchRecord保存到LeanCloud
    func saveMatchRecordsToLeanCloud(_ matchRecords: [MatchRecord]) {
        
        for (_, matchRecord) in matchRecords.enumerated() {
            LeanCloudService.shared.uploadMatchRecord(
                user1Id: matchRecord.user1Id,
                user1Name: matchRecord.user1Name,
                user1Avatar: matchRecord.user1Avatar,
                user1LoginType: matchRecord.user1LoginType,
                user2Id: matchRecord.user2Id,
                user2Name: matchRecord.user2Name,
                user2Avatar: matchRecord.user2Avatar,
                user2LoginType: matchRecord.user2LoginType,
                matchTime: matchRecord.matchTime,
                matchLocation: CLLocation(latitude: matchRecord.matchLocationLat, longitude: matchRecord.matchLocationLng)
            ) { success, error in
                if success {
                } else {
                }
            }
        }
        
    }
    
    // getCachedFavoriteRecords, getCachedUsersWhoLikedMe, and updateMessageViewDataWithCache methods moved to LegacySearchView+CacheManagement.swift
    
    // analyzeFriendsOnlineStatus, analyzeUserOnlineStatus, getUserNameById, and getMessagesForUser methods moved to LegacySearchView+UserDataQuery.swift
    
    
    /// 打印好友列表信息
    // printFriendsListInfo, getFriendsList, getFriendLastOnlineTime, printFriendsListAndLoginRecords, printLoginRecords, and printInternalLoginRecords methods moved to LegacySearchView+FriendsListManagement.swift
    
    // checkMatchStatusConsistency method moved to LegacySearchView+MatchStatus.swift
    
    // printNewFriendsList method moved to LegacySearchView+FriendsListManagement.swift
    
    // saveFavoriteRecords method moved to LegacySearchView+CacheManagement.swift
    
    /// 回滚喜欢操作的UI状态
    func rollbackFavoriteUI(userId: String, currentUser: UserInfo) {
        // 从本地数组中移除刚才添加的喜欢记录
        favoriteRecords.removeAll { $0.favoriteUserId == userId && $0.userId == currentUser.userId }
        saveFavoriteRecords()
        
        // 重新加载usersWhoLikedMe数组，恢复匹配状态
        loadUsersWhoLikedMe {
            // 发送UI更新通知，恢复原状态
            NotificationCenter.default.post(name: NSNotification.Name("RefreshMatchStatus"), object: nil)
            NotificationCenter.default.post(name: NSNotification.Name("RefreshFriendsList"), object: nil)
        }
    }
    
    /// 回滚取消喜欢的UI状态
    func rollbackUnfavoriteUI(userId: String, currentUser: UserInfo) {
        // 重新添加喜欢记录到本地数组
        let favoriteRecord = FavoriteRecord(
            userId: currentUser.userId,
            favoriteUserId: userId,
            favoriteUserName: nil, // 回滚时我们不知道用户名
            favoriteUserEmail: nil,
            favoriteUserLoginType: nil,
            favoriteUserAvatar: nil,
            recordObjectId: nil
        )
        favoriteRecords.append(favoriteRecord)
        saveFavoriteRecords()
        
        // 重新加载usersWhoLikedMe数组，恢复匹配状态
        loadUsersWhoLikedMe {
            // 发送UI更新通知，恢复原状态
            NotificationCenter.default.post(name: NSNotification.Name("RefreshMatchStatus"), object: nil)
            NotificationCenter.default.post(name: NSNotification.Name("RefreshFriendsList"), object: nil)
        }
    }
    
    /// 处理拍一拍消息接收
    func handlePatMessageReceived(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let senderName = userInfo["senderName"] as? String else {
            return
        }
        
        let currentUserId = userManager.currentUser?.userId ?? ""
        let currentUserName = userManager.currentUser?.fullName ?? ""
        
        // 🔧 关键检查：验证消息是否真的是发给当前用户的
        // 检查消息内容中的接收者
        if let content = userInfo["content"] as? String {
            // 从消息内容中提取接收者："{fromUserName} 拍了拍 {toUserName}"
            if content.contains("拍了拍") {
                // 检查接收者是否是当前用户
                let receiverName = content.components(separatedBy: "拍了拍 ").last ?? ""
                
                // 如果接收者不是当前用户，不应该显示弹窗
                if receiverName != currentUserName && receiverName != currentUserId && !receiverName.isEmpty {
                    return
                }
            }
        }
        
        // 更新弹窗状态
        stateManager.patMessageSenderName = senderName
        stateManager.showPatMessageAlert = true
        
        // 3秒后自动隐藏弹窗
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.stateManager.showPatMessageAlert = false
        }
    }
    
    /// 获取点赞记录存储键
    // getLikeRecordsKey, loadLikeRecords, and saveLikeRecords methods moved to LegacySearchView+CacheManagement.swift
    
    // createMatchRecordsFromDualLike and validateUsersWhoLikedMeWithMessageHistory methods moved to LegacySearchView+FavoriteSync.swift
    
    /// 获取当前用户头像
    // getCurrentUserAvatar method moved to LegacySearchView+UserDataQuery.swift
    
    /// 打印消息表数据
    // printMessageTable method moved to LegacySearchView+MessageSync.swift
    
    // forceSyncWithServerData, syncFavoriteRecordsFromLeanCloud, and syncLikeRecordsFromLeanCloud methods moved to LegacySearchView+FavoriteSync.swift
    
    // setMatchResult, showHistoricalMatch, addToAllFriendsMatchResults, and calculateFriendRequestCount methods moved to LegacySearchView+MatchStatus.swift
    
    /// 打印好友列表
    // printFriendsList and printFriendsListDetails methods moved to LegacySearchView+FriendsListManagement.swift
    
    // deleteFriendRequestMessages and updateMessageViewData methods moved to LegacySearchView+MessageSync.swift
    
    // MARK: - Additional Data Management Methods
    
    // 🚀 新增：实时更新所有好友头像的方法，与拍一拍消息一致
    func updateAllFriendsAvatarsInRealTime() {
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        
        // 收集所有需要更新的好友ID
        var friendIds = Set<String>()
        for friend in messageViewFriends {
            let friendId = friend.user1Id == currentUser.userId ? friend.user2Id : friend.user1Id
            friendIds.insert(friendId)
        }
        
        
        // 批量实时更新头像
        let group = DispatchGroup()
        for friendId in friendIds {
            group.enter()
            
            // 实时获取用户头像信息
            // 🎯 修改：使用 fetchUserAvatarByUserId，不依赖 loginType，直接从 UserAvatarRecord 表获取
            LeanCloudService.shared.fetchUserAvatarByUserId(objectId: friendId) { avatar, _ in
                DispatchQueue.main.async {
                    if let avatar = avatar, !avatar.isEmpty {
                        self.messageViewAvatarCache[friendId] = avatar
                    }
                    group.leave()
                }
            }
            
            // 🎯 修改：使用 fetchUserNameByUserId，不依赖 loginType，直接从 UserNameRecord 表获取
            LeanCloudService.shared.fetchUserNameByUserId(objectId: friendId) { name, _ in
                DispatchQueue.main.async {
                    if let name = name, !name.isEmpty {
                        self.messageViewUserNameCache[friendId] = name
                    }
                }
            }
        }
        
        group.notify(queue: .main) {
            for (_, _) in self.messageViewAvatarCache {
            }
            
            // 触发UI刷新 - 通过更新状态变量
            self.messageViewAvatarCache = self.messageViewAvatarCache
        }
        
        // 🔍 调试信息：消息按钮点击时的当前登录用户信息
        
        // 🔍 调试信息：当前数据状态
        
        // 🔧 新增：检查最近是否有拍一拍消息发送
        let recentPatMessages = messageViewPatMessages.filter { message in
            message.messageType == "pat" && 
            message.timestamp.timeIntervalSinceNow > -300 // 最近5分钟
        }
        if !recentPatMessages.isEmpty {
        }
        
        // 🔧 新增：打印每个好友右上角的数字
        
        // 🔧 新增：检查UI中实际显示的好友数据
        
        // 🔧 新增：如果MessageView正在显示，检查其内部的好友数据
        if showMessageSheet {
        }
        
        // 🔧 新增：详细的数据源对比分析
        
        // 🔧 新增：检查最近的消息时间
        if !messageViewPatMessages.isEmpty {
        }
        
        for (_, friend) in messageViewFriends.enumerated() {
            
            // 计算该好友的拍一拍消息数量（用于统计，但不使用）
            _ = messageViewPatMessages.filter { message in
                // 显示朋友拍我的消息
                let isFriendPatMe = message.senderId == (friend.user1Id == currentUser.id ? friend.user2Id : friend.user1Id) && message.receiverId == currentUser.id
                // 显示我拍朋友的消息
                let isIPatFriend = message.senderId == currentUser.id && message.receiverId == (friend.user1Id == currentUser.id ? friend.user2Id : friend.user1Id)
                return isFriendPatMe || isIPatFriend
            }
        }
        
        // 🔧 优化缓存检查逻辑 - 确保数据完整性
        let hasCachedFriends = !messageViewFriends.isEmpty
        let hasCachedData = !favoriteRecords.isEmpty || !usersWhoLikedMe.isEmpty
        let hasCachedPatMessages = !messageViewPatMessages.isEmpty
        
        
        
        // 🔧 优化：确保所有必要数据都存在才使用缓存
        let hasCompleteCachedData = hasCachedFriends && hasCachedData && hasCachedPatMessages
        
        if hasCompleteCachedData {
            
            // 🔧 新增：即使有缓存，也进行轻量级数据刷新，确保数据最新
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.fetchAndPrintMessages()
            }
        }
    }
    
    // cacheFavoriteRecords and cacheUsersWhoLikedMe methods moved to LegacySearchView+CacheManagement.swift
    
    // getFriendTableData method moved to LegacySearchView+UserDataQuery.swift
    
    func printTableStatus(operation: String, userId: String) {
        
        // 打印本地FavoriteRecord状态
        for (_, _) in favoriteRecords.enumerated() {
        }
        
        // 打印本地usersWhoLikedMe状态
        for (_, _) in usersWhoLikedMe.enumerated() {
        }
        
        // ⚠️ 已废弃：不再打印 MatchRecord 表状态
        // 好友关系现在由 FriendshipManager 和 _Followee 表管理
        
        // 从服务器获取最新的FavoriteRecord状态
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        LeanCloudService.shared.fetchActiveFavoriteRecords(userId: currentUser.id) { favoriteRecords, error in
            DispatchQueue.main.async {
                if error != nil {
                } else if favoriteRecords != nil {
                } else {
                }
            }
        }
    }
    
    func debugPrintFavoriteRecordState(header: String) {
        // 调试函数已禁用，避免不必要的网络请求和潜在崩溃
        // 如需调试，可以在此处添加调试代码
    }
    
    // 获取用户的最新头像 - 🎯 统一从 UserAvatarRecord 表获取
    func getLatestUserAvatar(userId: String, loginType: String, completion: @escaping (String) -> Void) {
        // 🎯 修改：使用 fetchUserAvatarByUserId，不依赖 loginType，直接从 UserAvatarRecord 表获取
        LeanCloudService.shared.fetchUserAvatarByUserId(objectId: userId) { avatar, _ in
            DispatchQueue.main.async {
                if let avatar = avatar, !avatar.isEmpty {
                    self.latestAvatars[userId] = avatar
                    completion(avatar)
                } else {
                    let defaultAvatar = UserAvatarUtils.defaultAvatar(for: loginType)
                    self.latestAvatars[userId] = defaultAvatar
                    completion(defaultAvatar)
                }
            }
        }
    }
    
    // loadUsersWhoLikedMe and cleanupInvalidFavoriteRecords methods moved to LegacySearchView+FavoriteSync.swift
}

