//
//  LegacySearchView+MessageSending.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//

import Foundation
import UIKit

// MARK: - Message Sending Extensions
extension LegacySearchView {
    
    /// 发送取消喜欢消息（使用正确用户名）
    func sendUnfavoriteMessageWithCorrectName(senderId: String, senderName: String, senderAvatar: String, receiverId: String, receiverName: String, receiverAvatar: String, receiverLoginType: String) {
        let senderLoginType = userManager.currentUser?.loginType == .apple ? "apple" :
                              "guest"
        let messageData: [String: Any] = [
            "senderId": senderId,
            "senderName": senderName,
            "senderAvatar": senderAvatar,
            "senderLoginType": senderLoginType,
            "receiverId": receiverId,
            "receiverName": receiverName,
            "receiverAvatar": receiverAvatar,
            "receiverLoginType": receiverLoginType,
            "content": "\(senderName) 撤销了好友申请",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "isRead": false,
            "type": "text",
            "messageType": "unfavorite",
            "deviceId": UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            "status": "active"
        ]
        LeanCloudService.shared.sendMessage(messageData: messageData) { success, _ in
            DispatchQueue.main.async {
                if success {
                } else {
                }
            }
        }
    }
    
    /// 发送取消喜欢消息
    func sendUnfavoriteMessage(senderId: String, senderName: String, senderAvatar: String, receiverId: String, receiverName: String, receiverAvatar: String, receiverLoginType: String) {
        // 获取当前用户的登录类型
        let senderLoginType = userManager.currentUser?.loginType == .apple ? "apple" : 
                             "guest"
        
        let messageData: [String: Any] = [
            "senderId": senderId,
            "senderName": senderName,
            "senderAvatar": senderAvatar,
            "senderLoginType": senderLoginType,
            "receiverId": receiverId,
            "receiverName": receiverName,
            "receiverAvatar": receiverAvatar,
            "receiverLoginType": receiverLoginType,
            "content": "\(senderName) 撤销了好友申请",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "isRead": false,
            "type": "text",
            "messageType": "unfavorite",
            "deviceId": UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            "status": "active"
        ]
        
        LeanCloudService.shared.sendMessage(messageData: messageData) { success, _ in
            DispatchQueue.main.async {
                if success {
                } else {
                }
            }
        }
    }
    
    /// 发送同意好友申请消息 - 使用标准好友关系API
    func sendAcceptMessage(senderId: String, senderName: String, senderAvatar: String, receiverId: String, receiverName: String, receiverAvatar: String, receiverLoginType: String) {
        
        // 首先查询待处理的好友申请
        FriendshipManager.shared.fetchFriendshipRequests { requests, error in
            DispatchQueue.main.async {
                if error != nil {
                    return
                }
                
                guard let requests = requests else {
                    return
                }
                
                // 查找对应的好友申请
                let targetRequest = requests.first { request in
                    request.user.id == receiverId && request.friend.id == senderId && request.status == "pending"
                }
                
                guard let request = targetRequest else {
                    return
                }
                
                // 使用标准API接受好友申请
                FriendshipManager.shared.acceptFriendshipRequest(
                    request,
                    attributes: [
                        "group": "default",
                        "remark": "通过喜欢功能添加"
                    ]
                ) { success, errorMessage in
                    DispatchQueue.main.async {
                        if success {
                            // 发送刷新通知
                            NotificationCenter.default.post(name: NSNotification.Name("RefreshNewFriends"), object: nil)
                        } else {
                        }
                    }
                }
            }
        }
    }
    
    /// 发送拒绝好友申请消息 - 使用标准好友关系API
    func sendRejectMessage(senderId: String, senderName: String, senderAvatar: String, receiverId: String, receiverName: String, receiverAvatar: String, receiverLoginType: String) {
        
        // 首先查询待处理的好友申请
        FriendshipManager.shared.fetchFriendshipRequests { requests, error in
            DispatchQueue.main.async {
                if error != nil {
                    return
                }
                
                guard let requests = requests else {
                    return
                }
                
                // 查找对应的好友申请
                let targetRequest = requests.first { request in
                    request.user.id == receiverId && request.friend.id == senderId && request.status == "pending"
                }
                
                guard let request = targetRequest else {
                    return
                }
                
                // 使用标准API拒绝好友申请
                FriendshipManager.shared.declineFriendshipRequest(request) { success, errorMessage in
                    DispatchQueue.main.async {
                        if success {
                            // 发送刷新通知
                            NotificationCenter.default.post(name: NSNotification.Name("RefreshNewFriends"), object: nil)
                        } else {
                        }
                    }
                }
            }
        }
    }
    
    /// 发送取消点赞消息
    func sendUnlikeMessage(senderId: String, senderName: String, senderAvatar: String, receiverId: String, receiverName: String, receiverAvatar: String, receiverLoginType: String) {
        
        // 获取当前用户的登录类型
        let senderLoginType = userManager.currentUser?.loginType == .apple ? "apple" : 
                             "guest"
        
        let messageData: [String: Any] = [
            "senderId": senderId,
            "senderName": senderName,
            "senderAvatar": senderAvatar,
            "senderLoginType": senderLoginType,
            "receiverId": receiverId,
            "receiverName": receiverName,
            "receiverAvatar": receiverAvatar,
            "receiverLoginType": receiverLoginType,
            "content": "\(senderName) 取消点赞了你 👎",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "isRead": false,
            "type": "text",
            "messageType": "unlike",
            "deviceId": UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            "status": "active"
        ]
        
        LeanCloudService.shared.sendMessage(messageData: messageData) { success, _ in
            DispatchQueue.main.async {
                if success {
                    // 取消点赞消息发送成功
                } else {
                    // 取消点赞消息发送失败
                }
            }
        }
    }
    
    /// 更新MatchRecord表状态
    func updateMatchRecordStatusForUsers(user1Id: String, user2Id: String, status: String, completion: (() -> Void)? = nil) {
        
        LeanCloudService.shared.updateMatchRecordStatusByUsers(user1Id: user1Id, user2Id: user2Id, status: status) { success, error in
            DispatchQueue.main.async {
                if success {
                    // 匹配记录状态更新成功
                } else {
                    // 匹配记录状态更新失败
                }
                // 无论成功还是失败，都执行完成回调
                completion?()
            }
        }
    }
    
    /// 发送点赞消息
    func sendLikeMessage(senderId: String, senderName: String, senderAvatar: String, receiverId: String, receiverName: String, receiverAvatar: String, receiverLoginType: String) {
        
        // 获取当前用户的登录类型
        let senderLoginType = userManager.currentUser?.loginType == .apple ? "apple" : 
                             "guest"
        
        let messageData: [String: Any] = [
            "senderId": senderId,
            "senderName": senderName,
            "senderAvatar": senderAvatar,
            "senderLoginType": senderLoginType,
            "receiverId": receiverId,
            "receiverName": receiverName,
            "receiverAvatar": receiverAvatar,
            "receiverLoginType": receiverLoginType,
            "content": "\(senderName) 点赞了你 👍",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "isRead": false,
            "type": "text",
            "messageType": "like",
            "deviceId": UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            "status": "active" // 修复：添加状态字段
        ]
        
        LeanCloudService.shared.sendMessage(messageData: messageData) { success, _ in
            DispatchQueue.main.async {
                if success {
                    // 喜欢消息发送成功
                } else {
                    // 喜欢消息发送失败
                }
            }
        }
    }
    
    /// 发送喜欢消息
    func sendFavoriteMessage(senderId: String, senderName: String, senderAvatar: String, receiverId: String, receiverName: String, receiverAvatar: String, receiverLoginType: String) {
        MessageHelpers.sendFavoriteMessage(
            senderId: senderId,
            senderName: senderName,
            senderAvatar: senderAvatar,
            receiverId: receiverId,
            receiverName: receiverName,
            receiverAvatar: receiverAvatar,
            receiverLoginType: receiverLoginType,
            currentUser: userManager.currentUser
        )
    }
    
    /// 处理MessageView中的拍一拍回调
    func handlePatFriendInMessageView(friendId: String) {
        
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        
        // 🎯 新增：拍一拍按钮点击时，更新 LoginRecord 表
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
        let loginType: String
        switch currentUser.loginType {
        case .apple:
            loginType = "apple"
        case .guest:
            loginType = "guest"
        }
        let userEmail = currentUser.email
        
        
        if loginType == "apple" {
            // Apple 登录需要 authData，这里使用简化版本
            let authData: [String: Any] = [
                "lc_apple": [
                    "uid": currentUser.id
                ]
            ]
            LeanCloudService.shared.recordAppleLoginWithAuthData(
                userId: currentUser.id,
                userName: currentUser.fullName,
                userEmail: userEmail,
                authData: authData,
                deviceId: deviceID
            ) { loginRecordSuccess in
                if loginRecordSuccess {
                } else {
                }
            }
        } else {
            LeanCloudService.shared.recordLogin(
                userId: currentUser.id,
                userName: currentUser.fullName,
                userEmail: userEmail,
                loginType: loginType,
                deviceId: deviceID
            ) { loginRecordSuccess in
                if loginRecordSuccess {
                } else {
                }
            }
        }
        
        // 查找好友信息
        guard let friend = messageViewFriends.first(where: { friend in
            friend.user1Id == friendId || friend.user2Id == friendId
        }) else {
            return
        }
        
        // 获取好友信息
        let friendName = friend.user1Id == currentUser.userId ? friend.user2Name : friend.user1Name
        let _ = friend.user1Id == currentUser.userId ? friend.user2LoginType : friend.user1LoginType
        
        // 🎯 修改：如果 friendName 为空字符串或看起来像 objectId，从 UserNameRecord 表获取正确的用户名
        if friendName.isEmpty || looksLikeObjectId(friendName) {
            LeanCloudService.shared.fetchUserNameAndLoginType(objectId: friendId) { userName, _, _ in
                DispatchQueue.main.async {
                    // 更新 friendName
                    let resolvedFriendName: String
                    if let name = userName, !name.isEmpty {
                        resolvedFriendName = name
                    } else {
                        resolvedFriendName = "未知用户"
                    }
                    
                    // 发送拍一拍消息
                    self.sendPatMessageWithFriendName(
                        currentUser: currentUser,
                        friendId: friendId,
                        friendName: resolvedFriendName,
                        locationManager: self.locationManager
                    )
                }
            }
            return
        }
        
        // 发送拍一拍消息
        sendPatMessageWithFriendName(
            currentUser: currentUser,
            friendId: friendId,
            friendName: friendName,
            locationManager: locationManager
        )
    }
    
    /// 🎯 新增：检查字符串是否看起来像是 objectId（长度较长、全是字母数字）
    private func looksLikeObjectId(_ string: String) -> Bool {
        // objectId 通常是 24 个字符的十六进制字符串（MongoDB ObjectId）
        // 或者长度在 20-30 之间，全是字母数字
        if string.count >= 20 && string.count <= 30 {
            let characterSet = CharacterSet.alphanumerics
            return string.unicodeScalars.allSatisfy { characterSet.contains($0) }
        }
        return false
    }
    
    /// 🎯 新增：发送拍一拍消息的辅助方法
    private func sendPatMessageWithFriendName(currentUser: UserInfo, friendId: String, friendName: String, locationManager: LocationManager) {
        let userAvatar = UserDefaultsManager.getCustomAvatarWithDefault(userId: currentUser.id)
        let userLoginTypeString = currentUser.loginType == .apple ? "apple" : "guest"
        
        // 使用新的拍一拍消息服务
        PatMessageService.shared.sendPatMessage(
            fromUserId: currentUser.id,
            toUserId: friendId,
            fromUserName: currentUser.fullName,
            toUserName: friendName,
            locationManager: locationManager,
            userLoginType: userLoginTypeString,
            userEmail: currentUser.email,
            userAvatar: userAvatar
        ) { success in
            
            DispatchQueue.main.async {
                if success {
                    
                    // 立即创建并添加新的拍一拍消息到MessageView的拍一拍消息列表
                    let newPatMessage = MessageItem(
                        senderId: currentUser.id,
                        senderName: currentUser.fullName,
                        senderAvatar: userAvatar,
                        senderLoginType: currentUser.loginType == .apple ? "apple" : "guest",
                        receiverId: friendId,
                        receiverName: friendName,
                        receiverAvatar: "",
                        receiverLoginType: "pat",
                        content: "\(currentUser.fullName) 拍了拍 \(friendName)",
                        timestamp: Date(),
                        isRead: false,
                        type: .text,
                        messageType: "pat"
                    )
                    
                    // 添加到MessageView的拍一拍消息列表的开头
                    self.messageViewPatMessages.insert(newPatMessage, at: 0)
                    
                    // 🎯 新增：保存到本地存储
                    if let currentUserId = self.userManager.currentUser?.id {
                        UserDefaultsManager.addPatMessage(newPatMessage, userId: currentUserId)
                    }
                    
                    // 🔢 新增：打印拍一拍消息发送成功后右上角数字的变化（只统计收到的消息）
                    let friendPatMessages = self.messageViewPatMessages.filter { message in
                        // 只统计朋友拍我的消息
                        let isFriendPatMe = message.senderId == friendId && message.receiverId == currentUser.id
                        return isFriendPatMe
                    }
                    let _ = friendPatMessages.count
                    
                    
                    // 🔧 新增：延迟同步数据到LeanCloud，确保数据持久化
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        
                        // 🔧 新增：记录同步前的数据状态，用于后续验证
                        let beforeSyncPatCount = self.messageViewPatMessages.count
                        let beforeSyncFriendPatCount = self.messageViewPatMessages.filter { message in
                            let isFriendPatMe = message.senderId == friendId && message.receiverId == currentUser.id
                            let isIPatFriend = message.senderId == currentUser.id && message.receiverId == friendId
                            return isFriendPatMe || isIPatFriend
                        }.count
                        
                        
                        self.fetchAndPrintMessages()
                        
                        // 🔧 新增：延迟验证同步结果
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            self.verifyPatMessageSync(friendId: friendId, beforeSyncCount: beforeSyncPatCount, beforeFriendCount: beforeSyncFriendPatCount)
                        }
                    }
                    
                    // 移除拍一拍消息数量限制：保留所有消息
                    
                    
                    // 🔧 修复：移除重复的消息创建，避免一次点击产生两条消息
                    // 不再创建第二个MessageItem，因为上面已经创建了一个
                    
                    
                } else {
                }
            }
        }
    }
}
