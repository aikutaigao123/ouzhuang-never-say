import SwiftUI

extension MessageView {
    // MARK: - Friend Interaction Methods
    
    // 处理好友点击 - 导航到好友详情页面
    internal func handleFriendTap(_ friend: MatchRecord) {
        // 获取好友信息（非当前用户）
        let friendInfo: (id: String, name: String, avatar: String, loginType: String)
        if friend.user1Id == userManager.currentUser?.id {
            friendInfo = (friend.user2Id, friend.user2Name, friend.user2Avatar, friend.user2LoginType)
        } else {
            friendInfo = (friend.user1Id, friend.user1Name, friend.user1Avatar, friend.user1LoginType)
        }
        
        // 与用户头像界面一致：实时查询服务器
        // 🎯 修改：使用 fetchUserAvatarByUserId，不依赖 loginType，直接从 UserAvatarRecord 表获取
        LeanCloudService.shared.fetchUserAvatarByUserId(objectId: friendInfo.id) { avatar, _ in
            DispatchQueue.main.async {
                if let avatar = avatar, !avatar.isEmpty {
                    self.existingAvatarCache[friendInfo.id] = avatar
                    
                    // 🎯 新增：更新 UserDefaults 中的头像缓存（用于其他用户的信息）
                    let userDefaultsAvatar = UserDefaultsManager.getCustomAvatar(userId: friendInfo.id)
                    if userDefaultsAvatar != avatar {
                        UserDefaultsManager.setCustomAvatar(userId: friendInfo.id, emoji: avatar)
                    }
                }
            }
        }
        
        // 🎯 修改：使用 fetchUserNameByUserId，不依赖 loginType，直接从 UserNameRecord 表获取
        LeanCloudService.shared.fetchUserNameByUserId(objectId: friendInfo.id) { name, _ in
            DispatchQueue.main.async {
                if let name = name, !name.isEmpty {
                    self.existingUserNameCache[friendInfo.id] = name
                    
                    // 🎯 新增：更新 UserDefaults 中的用户名缓存（用于其他用户的信息）
                    let userDefaultsUserName = UserDefaultsManager.getFriendUserName(userId: friendInfo.id)
                    if userDefaultsUserName != name {
                        UserDefaultsManager.setFriendUserName(userId: friendInfo.id, userName: name)
                    }
                }
            }
        }
        
        // 创建匹配消息 - 与用户头像界面一致：优先使用实时查询的用户名
        // 注意：实际显示时会在MessageItemView的onAppear中实时查询，这里使用缓存值或默认值
        let resolvedReceiverName = existingUserNameCache[friendInfo.id] ?? friendInfo.name
        let matchMessage = MessageItem(
            id: UUID(),
            objectId: nil,
            senderId: userManager.currentUser?.id ?? "",
            senderName: userManager.currentUser?.fullName ?? "我",
            senderAvatar: "😊", // 默认头像，实际应该从缓存获取
            senderLoginType: userManager.currentUser?.loginType.toString(),
            receiverId: friendInfo.id,
            receiverName: resolvedReceiverName,
            receiverAvatar: friendInfo.avatar,
            receiverLoginType: friendInfo.loginType,
            content: "匹配成功！",
            timestamp: Date(),
            isRead: false,
            type: MessageItem.MessageType.text,
            deviceId: UIDevice.current.identifierForVendor?.uuidString,
            messageType: "match",
            isMatch: true
        )
        
        
        // 触发消息点击回调
        onMessageTap(matchMessage)
    }
    
    // 预加载消息相关用户的缓存数据
    private func preloadMessageUserCache() {
        // 收集所有消息中的用户ID
        var userIds = Set<String>()
        
        for message in existingMessages {
            userIds.insert(message.senderId)
        }
        
        // 预加载缓存数据
        if !userIds.isEmpty {
            let userIdArray = Array(userIds)
            LeanCloudService.shared.preloadMessageUserCache(userIds: userIdArray)
        }
    }
    
    // 🚀 新增：自动显示所有好友的匹配状态
    internal func autoShowAllFriendsMatchStatus() {
        
        if existingFriends.isEmpty {
            return
        }
        
        // 为每个好友创建匹配消息并触发匹配逻辑
        let currentUserId = userManager.currentUser?.id ?? ""
        for (_, friend) in existingFriends.enumerated() {
            
            // 确定好友ID（不是当前用户的那个）
            let friendId = friend.user1Id == currentUserId ? friend.user2Id : friend.user1Id
            let friendName = friend.user1Id == currentUserId ? friend.user2Name : friend.user1Name
            let friendAvatar = friend.user1Id == currentUserId ? friend.user2Avatar : friend.user1Avatar
            let friendLoginType = friend.user1Id == currentUserId ? friend.user2LoginType : friend.user1LoginType
            
            // 与用户头像界面一致：优先使用实时查询的用户名（从缓存中获取）
            // 注意：实际显示时会在MessageItemView的onAppear中实时查询，这里使用缓存值或默认值
            let resolvedSenderName = existingUserNameCache[friendId] ?? (friendName.isEmpty ? "未知好友" : friendName)
            
            // 创建匹配消息
            let matchMessage = MessageItem(
                id: UUID(),
                objectId: nil,
                senderId: friendId,
                senderName: resolvedSenderName,
                senderAvatar: friendAvatar.isEmpty ? (friendLoginType == "apple" ? "person.circle.fill" : "person.circle") : friendAvatar, // 与用户头像界面一致：根据loginType设置默认头像
                // Note: friendAvatar and friendLoginType are used in the expression above
                senderLoginType: friendLoginType,
                receiverId: currentUserId,
                receiverName: userManager.currentUser?.fullName ?? "我",
                receiverAvatar: "😊",
                receiverLoginType: userManager.currentUser?.loginType.toString(),
                content: "匹配成功！",
                timestamp: Date(),
                isRead: false,
                type: MessageItem.MessageType.text,
                deviceId: UIDevice.current.identifierForVendor?.uuidString,
                messageType: "match",
                isMatch: true
            )
            
            
            // 触发消息点击回调（匹配逻辑）
            onMessageTap(matchMessage)
        }
        
    }
}

