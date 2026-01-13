import SwiftUI
import Foundation
import UIKit

struct MessageHelpers {
    // 获取IM状态信息
    static func getIMStatusInfo(userManager: UserManager) -> String {
        let stats = userManager.getIMConnectionStats()
        
        if stats.isConnected {
            return "IM 连接正常 (用户: \(stats.userId ?? "未知"), 重连次数: \(stats.reconnectAttempts))"
        } else {
            return "IM 连接断开 (重连次数: \(stats.reconnectAttempts))"
        }
    }
    
    // 加载新朋友数量
    static func loadNewFriendsCount(
        currentUser: UserInfo?,
        newFriendsCountManager: NewFriendsCountManager,
        onCountUpdated: @escaping (Int) -> Void
    ) {
        guard let currentUser = currentUser else { return }
        
        // 🎯 方案1：完全使用 _FriendshipRequest 表管理好友申请
        // 使用 FriendshipManager 从 _FriendshipRequest 表获取好友申请
        FriendshipManager.shared.fetchFriendshipRequestsWithRetry(maxAttempts: 3) { requests, error in
            DispatchQueue.main.async {
                if error != nil {
                    return
                }
                
                if let requests = requests {
                    // 🎯 修改：只统计 pending 状态的好友申请（只统计别人发送的申请）
                    let pendingRequests = requests.filter { request in
                        request.status == "pending" && request.user.id != currentUser.id
                    }
                    
                    let markAllAsReadKey = "MarkAllAsReadTimestamp_\(currentUser.id)"
                    let markAllAsReadTimestamp = UserDefaults.standard.object(forKey: markAllAsReadKey) as? Date
                    
                    if markAllAsReadTimestamp != nil {
                    } else {
                    }
                    
                    let unreadCount = pendingRequests.filter { request in
                        guard let markAllTime = markAllAsReadTimestamp else { return true }
                        let timeDifference = request.createdAt.timeIntervalSince(markAllTime)
                        let isUnread = timeDifference > 1.0
                        
                        
                        return isUnread
                    }.count
                    
                    
                    // 更新新朋友数量（只统计未读 pending）
                    newFriendsCountManager.updateCount(unreadCount)
                    onCountUpdated(unreadCount)
                } else {
                    newFriendsCountManager.updateCount(0)
                    onCountUpdated(0)
                }
            }
        }
    }
    
    // 发送喜欢消息 - 🎯 方案1：使用 _FriendshipRequest 表管理好友申请
    static func sendFavoriteMessage(
        senderId: String,
        senderName: String,
        senderAvatar: String,
        receiverId: String,
        receiverName: String,
        receiverAvatar: String,
        receiverLoginType: String,
        currentUser: UserInfo?
    ) {
        
        // 🎯 注意：限制检查和记录已经在 addFavoriteRecord 开始时完成，这里直接发送API请求
        
        // 🎯 方案1：使用 FriendshipManager 创建 _FriendshipRequest 记录
        FriendshipManager.shared.sendFriendshipRequest(
            to: receiverId,
            attributes: nil
        ) { success, errorMessage in
            if success {
                // 🎯 新增：好友申请发送成功后，更新 LoginRecord 表
                updateLoginRecordAfterFriendRequest(senderId: senderId, senderName: senderName)
                
                // 可选：同时通过 IM 发送消息作为通知（支持离线推送）
                PatConversationManager.shared.sendFriendRequestMessage(
                    fromUserId: senderId,
                    toUserId: receiverId,
                    fromUserName: senderName,
                    toUserName: receiverName
                ) { _, _ in }
            }
        }
    }
    
    // 🎯 新增：发送好友申请后更新 LoginRecord 表
    private static func updateLoginRecordAfterFriendRequest(senderId: String, senderName: String) {
        
        // 获取用户信息
        let userName = UserDefaultsManager.getCurrentUserName()
        let userEmail = UserDefaultsManager.getCurrentUserEmail()
        let loginType = UserDefaultsManager.getLoginType() ?? "guest"
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
        
        
        // 根据登录类型选择不同的更新方法
        if loginType == "apple" {
            // Apple 登录需要 authData
            let authData: [String: Any] = [
                "lc_apple": [
                    "uid": senderId
                ]
            ]
            LeanCloudService.shared.recordAppleLoginWithAuthData(
                userId: senderId,
                userName: userName.isEmpty ? senderName : userName,
                userEmail: userEmail.isEmpty ? nil : userEmail,
                authData: authData,
                deviceId: deviceId
            ) { success in
                if success {
                } else {
                }
            }
        } else {
            // 游客登录
            LeanCloudService.shared.recordLogin(
                userId: senderId,
                userName: userName.isEmpty ? senderName : userName,
                userEmail: userEmail.isEmpty ? nil : userEmail,
                loginType: loginType,
                deviceId: deviceId
            ) { success in
                if success {
                } else {
                }
            }
        }
    }
}