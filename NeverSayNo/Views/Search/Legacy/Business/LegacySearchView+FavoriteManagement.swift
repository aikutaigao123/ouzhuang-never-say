//
//  LegacySearchView+FavoriteManagement.swift
//  NeverSayNo
//
//  Created by Auto on 2025/11/11.
//

import SwiftUI
import Foundation

// MARK: - 喜欢记录管理
extension LegacySearchView {
    
    // MARK: - 添加和移除喜欢记录
    
    /// 添加喜欢记录
    func addFavoriteRecord(userId: String, userName: String?, userEmail: String?, loginType: String?, userAvatar: String?, recordObjectId: String?) {
        guard let currentUser = userManager.currentUser else { 
            return 
        }
        
        // 🎯 检查24小时内好友申请数量限制（在点击时检查，不依赖API结果）
        let (canSend, errorMessage) = UserDefaultsManager.canSendFriendRequest()
        if !canSend {
            // 超过限制，显示弹窗提示，不执行任何操作
            stateManager.showFriendRequestLimitAlert(message: errorMessage)
            return
        }
        
        // 🎯 立即记录发送时间（在点击时记录，不依赖API结果）
        let _ = UserDefaultsManager.getFriendRequestCountInLast24Hours()
        UserDefaultsManager.recordFriendRequestSent(to: userId)
        
        // 检查是否已经喜欢过
        let alreadyFavorited = isUserFavorited(userId: userId)
        
        if !alreadyFavorited {
            // 乐观更新：立即更新UI状态，提供即时反馈
            let favoriteRecord = FavoriteRecord(
                userId: currentUser.id,
                favoriteUserId: userId,
                favoriteUserName: userName,
                favoriteUserEmail: userEmail,
                favoriteUserLoginType: loginType,
                favoriteUserAvatar: userAvatar,
                recordObjectId: recordObjectId
            )
            
            favoriteRecords.append(favoriteRecord)
            saveFavoriteRecords()
            
            // 立即发送UI更新通知，提供即时反馈
            NotificationCenter.default.post(name: NSNotification.Name("RefreshMatchStatus"), object: nil)
            NotificationCenter.default.post(name: NSNotification.Name("RefreshFriendsList"), object: nil)
            NotificationCenter.default.post(name: NSNotification.Name("RefreshFriendsList"), object: nil)
            
            // 准备数据
            let favoriteData: [String: Any] = [
                "userId": currentUser.id,
                "favoriteUserId": userId,
                "favoriteUserName": userName ?? "",
                "favoriteUserEmail": userEmail ?? "",
                "favoriteUserLoginType": loginType ?? "",
                "favoriteUserAvatar": userAvatar ?? "",
                "recordObjectId": recordObjectId ?? "",
                "favoriteTime": ISO8601DateFormatter().string(from: Date()),
                "status": "active",
                "userLoginType": currentUser.loginType == .apple ? "apple" : "guest",
                "userName": currentUser.fullName,
                "userEmail": currentUser.email ?? "",
                "deviceId": UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
            ]
            
            // 在后台同步服务器状态
            LeanCloudService.shared.updateOrCreateFavoriteRecord(favoriteData: favoriteData) { success, errorMessage in
                DispatchQueue.main.async {
                    if success {
                        // 发送消息给被喜欢的用户
                        let currentUserAvatar = UserDefaultsManager.getCustomAvatarWithDefault(userId: currentUser.userId)
                        
                        // 检查是否已经互相喜欢
                        let isFavoritedByMe = self.isUserFavoritedByMe(userId: userId)
                        
                        if isFavoritedByMe {
                            // 如果对方已经喜欢了我，现在我也喜欢对方，直接匹配成功
                            DispatchQueue.main.async {
                                if let matchedMessage = self.messageViewMessages.first(where: { $0.senderId == userId }) {
                                    self.handleMatchSuccess(for: matchedMessage)
                                }
                            }
                            
                            NotificationCenter.default.post(name: NSNotification.Name("RefreshFriendsList"), object: nil)
                            NotificationCenter.default.post(name: NSNotification.Name("RefreshNewFriends"), object: nil)
                        } else {
                            // 如果对方还没有喜欢我，发送"好友申请"消息
                            // 🎯 注意：限制检查已经在 addFavoriteRecord 开始时完成，这里直接发送
                            MessageHelpers.sendFavoriteMessage(
                                senderId: currentUser.id,
                                senderName: currentUser.fullName,
                                senderAvatar: currentUserAvatar,
                                receiverId: userId,
                                receiverName: userName ?? "未知用户",
                                receiverAvatar: userAvatar ?? "",
                                receiverLoginType: loginType ?? "guest",
                                currentUser: currentUser
                            )
                        }
                        
                        // 重新加载usersWhoLikedMe数组
                        self.loadUsersWhoLikedMe {
                            NotificationCenter.default.post(name: NSNotification.Name("RefreshMatchStatus"), object: nil)
                            self.checkMatchStatusConsistency()
                        }
                        
                    } else {
                        // 服务器操作失败，回滚UI状态
                        self.rollbackFavoriteUI(userId: userId, currentUser: currentUser)
                        stateManager.showAntiSpamToast(message: "操作失败，已恢复原状态")
                    }
                }
            }
        }
    }
    
    /// 移除喜欢记录
    func removeFavoriteRecord(userId: String) {
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        // 检查是否存在好友关系
        if let friendRecord = messageViewFriends.first(where: { friend in
            let friendId = friend.user1Id == currentUser.userId ? friend.user2Id : friend.user1Id
            return friendId == userId
        }) {
            // 情况1：存在好友关系，删除好友关系
            let friendId = friendRecord.user1Id == currentUser.userId ? friendRecord.user2Id : friendRecord.user1Id
            let friendObjectId = friendId
            FriendshipManager.shared.removeFriend(friendObjectId) { success, errorMessage in
                DispatchQueue.main.async {
                    if success {
                        self.messageViewFriends.removeAll { friend in
                            let fId = friend.user1Id == currentUser.userId ? friend.user2Id : friend.user1Id
                            return fId == userId
                        }
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshFriendsList"), object: nil)
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshNewFriends"), object: nil)
                    }
                }
            }
        } else {
            // 情况2：不存在好友关系，检查是否有 pending 状态的好友申请
            let currentUserId = currentUser.id
            
            FriendshipManager.shared.fetchFriendshipRequests(status: nil) { requests, error in
                DispatchQueue.main.async {
                    guard let requests = requests else {
                        return
                    }
                    
                    if let requestToDelete = requests.first(where: { request in
                        request.user.id == currentUserId && request.friend.id == userId && request.status == "pending"
                    }) {
                        FriendshipManager.shared.deleteFriendshipRequest(requestId: requestToDelete.objectId) { success, errorMessage in
                            if success {
                                NotificationCenter.default.post(name: NSNotification.Name("RefreshNewFriends"), object: nil)
                            }
                        }
                    }
                }
            }
        }
        
        // 乐观更新：立即更新UI状态
        favoriteRecords.removeAll { $0.favoriteUserId == userId }
        saveFavoriteRecords()
        
        usersWhoLikedMe.removeAll { $0.userId == userId }
        
        let isMatched = isUserFavorited(userId: userId) && isUserFavoritedByMe(userId: userId)
        updateMessageMatchStatusForUser(userId: userId, isMatch: isMatched)
        
        DispatchQueue.main.async {
            self.messageViewMessages = self.messageViewMessages
        }
        
        usersWhoLikedMe.removeAll { $0.userId == userId }
        
        // 立即发送UI更新通知
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("RefreshMatchStatus"), object: nil)
            NotificationCenter.default.post(name: NSNotification.Name("RefreshFriendsList"), object: nil)
            NotificationCenter.default.post(name: NSNotification.Name("RefreshNewFriends"), object: nil)
        }
        
        // 在后台同步服务器状态
        LeanCloudService.shared.cancelFavoriteRecord(userId: currentUser.id, favoriteUserId: userId) { success, error in
            DispatchQueue.main.async {
                if success {
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshMatchStatus"), object: nil)
                    
                    if self.isUserFavoritedByMe(userId: userId) {
                        // 如果对方已经喜欢了我，现在取消喜欢，直接拒绝好友申请
                    } else {
                        // 如果对方还没有喜欢我，发送"撤销了好友申请"消息
                        let safeSenderId = currentUser.userId
                        let safeSenderName = currentUser.fullName
                        let safeSenderAvatar = self.getCurrentUserAvatar()
                        let safeReceiverId = userId
                        let safeReceiverName = self.latestUserNames[userId] ?? 
                                              self.getUserNameFromCache(userId) ?? 
                                              "未知用户"
                        
                        let correctedLoginType = UserTypeUtils.getLoginTypeFromUserId(userId)
                        let safeReceiverLoginType = correctedLoginType.isEmpty ? "guest" : correctedLoginType
                        let latestAvatar = self.latestAvatars[userId] ?? UserAvatarUtils.defaultAvatar(for: safeReceiverLoginType)
                        let safeReceiverAvatar = latestAvatar.isEmpty ? UserAvatarUtils.defaultAvatar(for: safeReceiverLoginType) : latestAvatar
                        
                        if safeReceiverName == "未知用户" {
                            self.fetchUserNameFromLeanCloud(userId) { leanCloudUserName in
                                if let leanCloudUserName = leanCloudUserName {
                                    self.latestUserNames[userId] = leanCloudUserName
                                    self.sendUnfavoriteMessageWithCorrectName(
                                        senderId: safeSenderId,
                                        senderName: safeSenderName,
                                        senderAvatar: safeSenderAvatar,
                                        receiverId: safeReceiverId,
                                        receiverName: leanCloudUserName,
                                        receiverAvatar: safeReceiverAvatar,
                                        receiverLoginType: safeReceiverLoginType
                                    )
                                }
                            }
                        } else {
                            self.sendUnfavoriteMessage(
                                senderId: safeSenderId,
                                senderName: safeSenderName,
                                senderAvatar: safeSenderAvatar,
                                receiverId: safeReceiverId,
                                receiverName: safeReceiverName,
                                receiverAvatar: safeReceiverAvatar,
                                receiverLoginType: safeReceiverLoginType
                            )
                        }
                    }
                    
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshFriendsList"), object: nil)
                    self.printUserScoreTableContent()
                    self.printUserNameRecordTableContent()
                    
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshNewFriends"), object: nil)
                    
                    self.deleteFriendRequestMessages(user1Id: currentUser.userId, user2Id: userId) {
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshNewFriends"), object: nil)
                    }
                    
                    self.syncFavoriteRecordsFromLeanCloud()
                    self.printUserScoreTableContent()
                } else {
                    // 服务器操作失败，回滚UI状态
                    self.rollbackUnfavoriteUI(userId: userId, currentUser: currentUser)
                    stateManager.showAntiSpamToast(message: "操作失败，已恢复原状态")
                }
            }
        }
    }
    
    // MARK: - 检查喜欢状态
    
    /// 检查用户是否已被喜欢
    func isUserFavorited(userId: String) -> Bool {
        return favoriteRecords.contains { $0.favoriteUserId == userId }
    }
    
    /// 检查指定用户是否喜欢了当前用户
    func isUserFavoritedByMe(userId: String) -> Bool {
        return DataHelpers.isUserFavoritedByMe(userId: userId, usersWhoLikedMe: usersWhoLikedMe)
    }
    
    // MARK: - 解除好友关系
    
    /// 处理解除好友关系（删除好友关系 + 取消爱心点亮）
    func handleUnfriend(_ friend: MatchRecord) {
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        let friendId = friend.user1Id == currentUser.userId ? friend.user2Id : friend.user1Id
        let friendObjectId = friendId
        
        FriendshipManager.shared.removeFriend(friendObjectId) { success, errorMessage in
            DispatchQueue.main.async {
                if success {
                    self.removeFavoriteRecord(userId: friendId)
                    
                    // 🎯 新增：清空该好友的拍一拍消息
                    self.clearPatMessagesForFriend(friendId: friendId, currentUserId: currentUser.id)
                    
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshMatchStatus"), object: nil)
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshFriendsList"), object: nil)
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshNewFriends"), object: nil)
                } else {
                    self.removeFavoriteRecord(userId: friendId)
                    
                    // 🎯 新增：即使删除好友关系失败，也清空该好友的拍一拍消息
                    self.clearPatMessagesForFriend(friendId: friendId, currentUserId: currentUser.id)
                }
            }
        }
    }
    
    /// 🎯 新增：清空指定好友的拍一拍消息
    private func clearPatMessagesForFriend(friendId: String, currentUserId: String) {
        // 从 messageViewPatMessages 中移除与该好友相关的所有消息
        messageViewPatMessages.removeAll { message in
            // 移除发送者或接收者是该好友的消息
            return message.senderId == friendId || message.receiverId == friendId
        }
        
        // 保存更新后的消息列表到本地
        UserDefaultsManager.savePatMessages(messageViewPatMessages, userId: currentUserId)
        
        // 更新 PatMessageUpdateManager 中的消息列表
        PatMessageUpdateManager.shared.clearPatMessagesForUser(friendId)
        
    }
    
    // MARK: - 辅助函数
    
    /// 从缓存中获取用户名
    private func getUserNameFromCache(_ userId: String) -> String? {
        if let cachedName = latestUserNames[userId], !cachedName.isEmpty {
            return cachedName
        }
        return nil
    }
    
    /// 从UserNameRecord表查询用户名
    private func fetchUserNameFromLeanCloud(_ userId: String, completion: @escaping (String?) -> Void) {
        LeanCloudService.shared.fetchUserNameByUserId(objectId: userId) { userName, error in
            DispatchQueue.main.async {
                if let userName = userName, !userName.isEmpty {
                    self.latestUserNames[userId] = userName
                    completion(userName)
                } else {
                    completion(nil)
                }
            }
        }
    }
}


