//
//  FriendsListView+DataManagement.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//

import Foundation
import SwiftUI

// MARK: - Data Management Extensions
extension FriendsListView {
    
    /// 加载好友列表 - 使用标准好友关系API
    func loadFriends(showLoading: Bool = true) {
        
        // 防止重复调用
        guard !isRefreshing else {
            return
        }
        
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        isRefreshing = true
        if showLoading {
            isLoading = true
        }
        
        let startTime = Date()
        
        // 使用标准好友关系管理器查询好友列表
        FriendshipManager.shared.fetchFriendsList { friends, error in
            DispatchQueue.main.async {
                self.isRefreshing = false
                if showLoading {
                    self.isLoading = false
                }
                
                if error != nil {
                    return
                }
                
                guard let friends = friends else {
                    return
                }
                
                
                // 将UserInfo转换为MatchRecord格式以保持兼容性
                var friendsList: [MatchRecord] = []
                var friendIds: [String] = []
                
                for friend in friends {
                    // 创建MatchRecord对象
                    // 🔧 修复：使用真实的 userId 而不是 objectId
                    // 🎯 修改：user2Name 使用空字符串，不从 friend.fullName 获取（friend.fullName 来自 _Followee 表，可能不准确）
                    // 真实的用户名将通过 updateFriendsUserInfo 从 UserNameRecord 表获取
                    let friendId = friend.userId
                    friendIds.append(friendId)
                    
                    let matchRecord = MatchRecord(
                        user1Id: currentUser.userId,  // 使用真实的 userId
                        user2Id: friendId,  // 使用真实的 userId，而不是 friend.id (objectId)
                        user1Name: currentUser.fullName,
                        user2Name: "",  // 🎯 修改：使用空字符串，不从 _Followee 表的 displayName 获取
                        user1Avatar: "😀", // 默认头像
                        user2Avatar: "😀", // 默认头像
                        user1LoginType: currentUser.loginType == .apple ? "apple" : "guest",
                        user2LoginType: friend.loginType == .apple ? "apple" : "guest",
                        matchTime: Date(),
                        matchLocation: nil, // 使用nil作为默认位置
                        deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
                        timezone: TimeZone.current.identifier,
                        deviceTime: Date()
                    )
                    friendsList.append(matchRecord)
                }
                
                // 🎯 新增：从 UserDefaults 恢复缓存（类似于用户头像界面的缓存机制）
                self.restoreCacheForFriends(friendIds)
                
                // 异步更新用户信息（头像、用户名、登录类型）
                self.updateFriendsUserInfo(friendsList) { updatedFriends in
                    DispatchQueue.main.async {
                        let _ = Date().timeIntervalSince(startTime)
                        
                        self.friends = updatedFriends
                        
                        // 🎯 新增：写入 UserDefaults
                        if let currentUser = self.userManager.currentUser {
                            UserDefaultsManager.setFriendsList(updatedFriends, userId: currentUser.userId)
                        }
                        
                        if showLoading {
                            self.isLoading = false
                        }
                        
                        // 在数据加载完成后清理过期缓存
                        self.cleanupCacheAfterUpdate()
                        
                        // 打印本地缓存状态
                        self.printAllLocalOnlineStatusCache()
                        
                        self.isRefreshing = false
                        
                        // 打印每个好友的在线状态
                        self.printFriendsOnlineStatus()
                    }
                }
            }
        }
    }
    
    /// 更新好友的用户信息
    func updateFriendsUserInfo(_ friends: [MatchRecord], completion: @escaping ([MatchRecord]) -> Void) {
        guard let currentUser = userManager.currentUser else {
            completion(friends)
            return
        }
        
        var updatedFriends = friends
        let dispatchGroup = DispatchGroup()
        
        for (index, friend) in friends.enumerated() {
            let friendId = friend.user1Id == currentUser.id ? friend.user2Id : friend.user1Id
            let friendLoginType = friend.user1Id == currentUser.id ? friend.user2LoginType : friend.user1LoginType
            
            dispatchGroup.enter()
            
            // 获取好友头像（使用正确的登录类型）
            // 🎯 注意：getCachedUserAvatar 内部已经会更新 UserDefaults 缓存，这里不需要额外操作
            getCachedUserAvatar(userId: friendId, loginType: friendLoginType) { avatar in
                updatedFriends[index].user2Avatar = avatar
                dispatchGroup.leave()
            }
            
            dispatchGroup.enter()
            
            // 🎯 修改：使用 fetchUserNameAndLoginType 同时获取用户名和登录类型，确保获取到正确的用户名
            LeanCloudService.shared.fetchUserNameAndLoginType(objectId: friendId) { userName, loginType, error in
                DispatchQueue.main.async {
                    // 更新用户名
                    if let userName = userName, !userName.isEmpty {
                        updatedFriends[index].user2Name = userName
                        // 更新内存缓存
                        self.userNameCache[friendId] = userName
                        self.userNameCacheTimestamps[friendId] = Date()
                        
                        // 🎯 新增：更新 UserDefaults 持久化缓存（类似于用户头像界面）
                        UserDefaultsManager.setFriendUserName(userId: friendId, userName: userName)
                    }
                    
                    // 更新登录类型（如果获取到了）
                    if let loginType = loginType, !loginType.isEmpty {
                        updatedFriends[index].user2LoginType = loginType
                    }
                    
                    dispatchGroup.leave()
                }
            }
            
            // 🎯 注意：登录类型已经通过 fetchUserNameAndLoginType 获取，这里不需要再次获取
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(updatedFriends)
        }
    }
    
    /// 批量获取好友数据
    func batchFetchFriendData(friends: [MatchRecord]) {
        guard let currentUser = userManager.currentUser else { return }
        
        let batchStartTime = Date()
        
        // 收集所有唯一的好友ID和登录类型
        var uniqueFriends: [(userId: String, loginType: String)] = []
        
        for friend in friends {
            // 获取非当前用户的好友信息
            let friendId = friend.user1Id == currentUser.id ? friend.user2Id : friend.user1Id
            let friendLoginType = friend.user1Id == currentUser.id ? friend.user2LoginType : friend.user1LoginType
            
            // 避免重复添加
            if !uniqueFriends.contains(where: { $0.userId == friendId }) {
                uniqueFriends.append((friendId, friendLoginType))
            }
        }
        
        let userIds = uniqueFriends.map { $0.userId }
        let loginTypes = uniqueFriends.map { $0.loginType }
        
        // 使用批量获取方法
        LeanCloudService.shared.batchFetchUserDataForHistory(userIds: userIds, loginTypes: loginTypes) { avatarResults, nameResults in
            DispatchQueue.main.async {
                let batchEndTime = Date()
                let _ = batchEndTime.timeIntervalSince(batchStartTime)
                
                // 更新本地缓存
                for (userId, avatar) in avatarResults {
                    self.avatarCache[userId] = avatar
                    self.avatarCacheTimestamps[userId] = Date()
                    
                    // 🎯 新增：更新 UserDefaults 持久化缓存（类似于用户头像界面）
                    UserDefaultsManager.setFriendAvatar(userId: userId, avatar: avatar)
                }
                
                for (userId, name) in nameResults {
                    self.userNameCache[userId] = name
                    self.userNameCacheTimestamps[userId] = Date()
                    
                    // 🎯 新增：更新 UserDefaults 持久化缓存（类似于用户头像界面）
                    UserDefaultsManager.setFriendUserName(userId: userId, userName: name)
                }
            }
        }
    }
    
    /// 加载新朋友（好友申请）
    func loadNewFriends() {
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        // 🎯 方案1：完全使用 _FriendshipRequest 表管理好友申请
        // 使用 FriendshipManager 从 _FriendshipRequest 表获取好友申请
        FriendshipManager.shared.fetchFriendshipRequestsWithRetry(maxAttempts: 4) { requests, error in
            DispatchQueue.main.async {
                if error != nil {
                    self.newFriends = []
                    return
                }
                
                guard let requests = requests else {
                    self.newFriends = []
                    return
                }
                
                
                // 🎯 修改：只显示 pending 状态的好友申请，已接受或已拒绝的申请应该从列表中移除
                // 🎯 修改：过滤掉当前用户发出的好友申请，只显示别人发送的申请
                // 将 FriendshipRequest 转换为 MessageItem 格式以保持兼容性
                
                // 🎯 新增：获取"一键已读"的时间戳，用于判断已读状态
                let markAllAsReadKey = "MarkAllAsReadTimestamp_\(currentUser.id)"
                let markAllAsReadTimestamp = UserDefaults.standard.object(forKey: markAllAsReadKey) as? Date
                
                if markAllAsReadTimestamp != nil {
                } else {
                }
                
                // 🎯 新增：获取本地黑名单
                let localBlacklistedUserIds = LocalBlacklistManager.shared.getAllLocalBlacklistedUserIds()
                
                let friendRequestMessages = requests.compactMap { request -> MessageItem? in
                    // 🚀 修复：只显示 pending 状态的好友申请
                    guard request.status == "pending" else {
                        return nil
                    }
                    
                    let currentUserId = currentUser.id
                    let isSentByCurrentUser = request.user.id == currentUserId
                    
                    // 🎯 修改：过滤掉当前用户发出的好友申请
                    guard !isSentByCurrentUser else {
                        return nil
                    }
                    
                    // 🎯 新增：过滤掉黑名单中的用户发送的好友申请
                    let senderId = request.user.id
                    if localBlacklistedUserIds.contains(senderId) {
                        return nil
                    }
                    
                    // 🔧 修复：如果 fullName 为空，从缓存获取或使用"未知用户"
                    let senderName: String
                    if request.user.fullName.isEmpty {
                        // 尝试从缓存获取用户名
                        let cachedName = LeanCloudService.shared.getCachedUserName(for: request.user.id)
                        senderName = cachedName ?? "未知用户"
                    } else {
                        senderName = request.user.fullName
                    }
                    
                    // 别人向当前用户发送的申请
                    let content = "\(senderName) 对你发送了好友申请"
                    
                    // 🎯 新增：如果好友申请的创建时间早于或等于"一键已读"的时间戳，则标记为已读
                    // 🔧 修复：添加1秒容差，避免时间精度问题导致相同时间的消息被误判为未读
                    let isRead: Bool
                    if let markAllAsReadTime = markAllAsReadTimestamp {
                        let timeDifference = request.createdAt.timeIntervalSince(markAllAsReadTime)
                        // 如果 createdAt 早于或等于 markAllAsReadTime（允许1秒容差），则标记为已读
                        isRead = timeDifference <= 1.0
                        
                        
                        if isRead {
                        } else {
                        }
                    } else {
                        isRead = false
                    }
                    
                    return MessageItem(
                        objectId: request.objectId,
                        senderId: request.user.id,
                        senderName: senderName, // 🔧 修复：使用处理后的 senderName
                        senderAvatar: "",
                        senderLoginType: nil,
                        receiverId: request.friend.id,
                        receiverName: request.friend.fullName,
                        receiverAvatar: "",
                        receiverLoginType: nil,
                        content: content, // 🔧 修复：使用包含用户名的 content
                        timestamp: request.createdAt,
                        isRead: isRead,
                        type: .text,
                        deviceId: nil,
                        messageType: "friend_request",
                        isMatch: false
                    )
                }
                
                
                // 🔍 新增：打印转换后的消息
                for (_, _) in friendRequestMessages.enumerated() {
                }
                
                // 更新新朋友列表
                // 🚀 修复：使用 withAnimation 确保 SwiftUI 检测到变化并立即刷新
                withAnimation {
                    self.newFriends = friendRequestMessages
                }
            }
        }
    }
    
    /// 设置通知监听，收到好友申请时立即刷新
    func setupNewFriendsNotificationObserver() {
        // 监听刷新新朋友列表通知
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RefreshNewFriends"),
            object: nil,
            queue: .main
        ) { _ in
            self.loadNewFriends()
        }
        
        // 监听新好友申请通知（LiveQuery）
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NewFriendshipRequest"),
            object: nil,
            queue: .main
        ) { _ in
            self.loadNewFriends()
        }
        
        // 监听好友申请状态更新通知
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("FriendshipRequestUpdated"),
            object: nil,
            queue: .main
        ) { _ in
            self.loadNewFriends()
        }
    }
    
    /// 批量获取新朋友数据
    func batchFetchNewFriendsData(messages: [MessageItem]) {
        guard userManager.currentUser != nil else { return }
        
        let batchStartTime = Date()
        
        // 收集所有唯一的发送者ID
        var uniqueSenders: [String] = []
        
        for message in messages {
            if !uniqueSenders.contains(message.senderId) {
                uniqueSenders.append(message.senderId)
            }
        }
        
        // 使用批量获取方法
        LeanCloudService.shared.batchFetchUserDataForHistory(userIds: uniqueSenders, loginTypes: Array(repeating: "guest", count: uniqueSenders.count)) { avatarResults, nameResults in
            DispatchQueue.main.async {
                let batchEndTime = Date()
                let _ = batchEndTime.timeIntervalSince(batchStartTime)
                
                // 更新本地缓存
                for (userId, avatar) in avatarResults {
                    self.avatarCache[userId] = avatar
                    self.avatarCacheTimestamps[userId] = Date()
                }
                
                for (userId, name) in nameResults {
                    self.userNameCache[userId] = name
                    self.userNameCacheTimestamps[userId] = Date()
                }
            }
        }
    }
}
