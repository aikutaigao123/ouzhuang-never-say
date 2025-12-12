//
//  ContentView+Login.swift
//  NeverSayNo
//
//  Created by Auto on 2025/11/11.
//

import SwiftUI
import Foundation

// MARK: - 登录相关功能
extension ContentView {
    
    // MARK: - 登录后打印 _FriendshipRequest 表
    
    /// 登录成功后打印 _FriendshipRequest 表内容
    private func printFriendshipRequestTableOnLogin() {
        guard userManager.currentUser != nil else {
            return
        }
        
        // 使用 FriendshipManager 查询好友申请
        FriendshipManager.shared.fetchFriendshipRequests { requests, error in
            DispatchQueue.main.async {
                if error != nil {
                } else if let requests = requests {
                    
                    if requests.isEmpty {
                    } else {
                        
                        for (_, _) in requests.enumerated() {
                        }
                        
                        let _ = requests.filter { $0.status == "pending" }.count
                        let _ = requests.filter { $0.status == "accepted" }.count
                        let _ = requests.filter { $0.status == "declined" }.count
                        
                    }
                    
                } else {
                }
            }
        }
    }
    
    // MARK: - 登录时检查黑名单和待删除账号
    
    /// 检查当前用户是否在黑名单或待删除账号中（登录时调用）
    func checkUserBlacklistAndPendingDeletionOnLogin(completion: @escaping (Bool, Bool) -> Void) {
        guard let currentUser = userManager.currentUser else {
            completion(false, false)
            return
        }
        
        let currentUserId = currentUser.id
        let currentUserName = currentUser.fullName
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
        
        // 获取黑名单和待删除账号列表
        LeanCloudService.shared.fetchBlacklist { blacklistedIds, error in
            if error != nil {
                completion(false, false)
                return
            }
            
            let blacklistedIds = blacklistedIds ?? []
            
            // 检查黑名单：同时检查用户ID、用户名和设备ID（与排行榜一致）
            let isBlacklisted = blacklistedIds.contains(currentUserId) ||
                               blacklistedIds.contains(currentUserName) ||
                               blacklistedIds.contains(deviceID)
            
            LeanCloudService.shared.fetchPendingDeletionUserIds { pendingDeletionIds, error in
                if error != nil {
                    completion(isBlacklisted, false)
                    return
                }
                
                let pendingDeletionIds = pendingDeletionIds ?? []
                
                // 检查待删除账号：检查用户ID、用户名和设备ID（与排行榜一致）
                let isPendingDeletion = pendingDeletionIds.contains(currentUserId) ||
                                       pendingDeletionIds.contains(currentUserName) ||
                                       pendingDeletionIds.contains(deviceID)
                
                if isBlacklisted {
                }
                
                if isPendingDeletion {
                }
                
                completion(isBlacklisted, isPendingDeletion)
            }
        }
    }
    
    // MARK: - 登录成功后加载数据
    
    /// 登录成功后加载新朋友申请数量
    func loadMessagesOnLogin() {
        guard let currentUser = userManager.currentUser else { 
            return 
        }
        
        // 防止重复调用
        if hasLoadedMessagesOnLogin {
            return
        }
        
        hasLoadedMessagesOnLogin = true
        
        // 🎯 新增：登录成功后自动检查并创建当前用户的UserNameRecord（如果不存在）
        let userId = currentUser.id
        let loginType = currentUser.loginType == .apple ? "apple" : "guest"
        let userName = currentUser.fullName
        let userEmail = currentUser.email
        
        LeanCloudService.shared.ensureCurrentUserUserNameRecordExists(
            objectId: userId,
            loginType: loginType,
            userName: userName,
            userEmail: userEmail
        ) { success, message in
            if success {
                // 记录已存在或创建成功
            } else {
                // 创建失败
            }
            
            // 🎯 在UserNameRecord检查完成后，延迟执行UserAvatarRecord检查，避免请求过于频繁
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                LeanCloudService.shared.ensureCurrentUserAvatarRecordExists(
                    objectId: userId,
                    loginType: loginType,
                    userAvatar: nil // 传入nil会自动生成随机emoji
                ) { success, message in
                    if success {
                        // 记录已存在或创建成功
                    } else {
                        // 创建失败
                    }
                }
            }
        }
        
        // 🔍 新增：登录成功后打印 _FriendshipRequest 表
        printFriendshipRequestTableOnLogin()
        
        // 🎯 新增：信息确认完成后查询并显示通知栏
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // 检查用户是否仍然登录（信息确认完成后）
            if userManager.isLoggedIn {
                LeanCloudService.shared.fetchNotificationMessage { message, error in
                    DispatchQueue.main.async {
                        // 再次检查用户是否仍然登录
                        if userManager.isLoggedIn, let message = message, !message.isEmpty {
                            // 如果有通知内容，显示通知栏
                            stateManager.showAppLaunchToast(message: message)
                        }
                    }
                }
            }
        }
        
        // 登录成功后立即读取LeanCloud所有数据
        LeanCloudService.shared.fetchAllLeanCloudData { data, error in
            DispatchQueue.main.async {
                // 处理数据
            }
        }

        // 与用户头像界面一致：不再使用全局缓存，改为各个组件onAppear时实时查询
        // LeanCloudService.shared.initializeGlobalUserCache { success in
        //     // 已删除：不再使用全局缓存
        // }

        // 2) 同步到本地状态（latestUserNames / latestAvatars）供当前UI直接使用
        let preloadGroup = DispatchGroup()
        
        preloadGroup.enter()
        LeanCloudService.shared.fetchAllUserNameRecords { records, _ in
            if let records = records {
                var nameMap: [String: String] = [:]
                for record in records {
                    if let uid = record["userId"] as? String, let name = record["userName"] as? String {
                        if nameMap[uid] == nil { nameMap[uid] = name }
                    }
                }
                let _ = nameMap.count
            }
            preloadGroup.leave()
        }

        preloadGroup.enter()
        LeanCloudService.shared.fetchAllUserAvatarRecords { records, _ in
            if let records = records {
                var avatarMap: [String: String] = [:]
                for record in records {
                    if let uid = record["userId"] as? String, let avatar = record["userAvatar"] as? String {
                        if avatarMap[uid] == nil { avatarMap[uid] = avatar }
                    }
                }
                let _ = avatarMap.count
            }
            preloadGroup.leave()
        }

        preloadGroup.notify(queue: .main) {
        }
        
        // 登录成功后自动检查并修复头像数据一致性
        if let currentUserId = userManager.currentUser?.id {
            LeanCloudService.shared.checkAndFixAvatarConsistency(userId: currentUserId) { success in
                DispatchQueue.main.async {
                    // 处理结果
                }
            }
        }
        
        // 从 _FriendshipRequest 加载新朋友申请（不再查询 Message 表）
        // 先用缓存更新计数，避免空白
        guard let currentUser = userManager.currentUser else { return }
        let cached = FriendshipManager.shared.friendshipRequests.filter { request in
            request.status == "pending" && request.user.id != currentUser.id
        }
        
        let markAllAsReadKey = "MarkAllAsReadTimestamp_\(currentUser.id)"
        let markAllAsReadTimestamp = UserDefaults.standard.object(forKey: markAllAsReadKey) as? Date
        
        if markAllAsReadTimestamp != nil {
        } else {
        }
        
        let unreadCachedCount = cached.filter { request in
            guard let markAllTime = markAllAsReadTimestamp else { return true }
            let timeDifference = request.createdAt.timeIntervalSince(markAllTime)
            let isUnread = timeDifference > 1.0
            
            return isUnread
        }.count
        
        self.newFriendsCountManager.updateCount(unreadCachedCount)
        self.unreadMessageCount = self.newFriendsCountManager.count
        // 再带退避重试拉取最新
        FriendshipManager.shared.fetchFriendshipRequestsWithRetry { requests, error in
            DispatchQueue.main.async {
                if error != nil {
                    return
                }
                let pending = (requests ?? []).filter { request in
                    request.status == "pending" && request.user.id != currentUser.id
                }
                
                let markAllAsReadKey = "MarkAllAsReadTimestamp_\(currentUser.id)"
                let markAllAsReadTimestamp = UserDefaults.standard.object(forKey: markAllAsReadKey) as? Date
                
                if markAllAsReadTimestamp != nil {
                } else {
                }
                
                let unreadPendingCount = pending.filter { request in
                    guard let markAllTime = markAllAsReadTimestamp else { return true }
                    let timeDifference = request.createdAt.timeIntervalSince(markAllTime)
                    let isUnread = timeDifference > 1.0
                    
                    return isUnread
                }.count
                
                self.newFriendsCountManager.updateCount(unreadPendingCount)
                self.unreadMessageCount = self.newFriendsCountManager.count
            }
        }
        
        // 注释掉这行代码，因为它会覆盖异步获取消息后设置的正确数量
        // self.unreadMessageCount = 0
        
        // 🔧 修复：只在特定条件下自动检测并上传匹配记录
        // 避免在每次加载时都重新激活已取消的MatchRecord
        // LeanCloudService.shared.autoDetectAndUploadMatchRecords(for: currentUser.userId) { success in
        //     DispatchQueue.main.async {
        //         // 自动匹配检测完成
        //     }
        // }
        
        // 加载历史记录并检查是否有匹配记录
        loadHistoryAndCheckLatestMatch()
    }
}

