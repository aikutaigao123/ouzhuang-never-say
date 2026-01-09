import SwiftUI

extension MessageView {
    // MARK: - New Friends Button Handling
    
    // 处理新的朋友按钮点击
    internal func handleNewFriendsButtonTap() {
        // 记录点击时间
        let clickTime = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        let _ = formatter.string(from: clickTime)
        
        
        // 🔍 新增：详细检查并打印新的朋友申请消息
        let newFriendsMessages = existingMessages.filter { $0.content.contains("对你发送了好友申请") }
        
        
        // 🔍 新增：详细分析消息ID变化
        let messageIds = existingMessages.map { $0.id.uuidString }
        
        // 🔍 新增：分析消息内容变化
        let friendRequestMessages = existingMessages.filter { $0.content.contains("对你发送了好友申请") }
        let patMessages = existingMessages.filter { $0.content.contains("拍了拍") }
        let revokeMessages = existingMessages.filter { $0.content.contains("撤销了好友申请") }
        
        
        if !friendRequestMessages.isEmpty {
        }
        if !patMessages.isEmpty {
        }
        if !revokeMessages.isEmpty {
        }
        
        // 🔍 新增：分析消息ID变化模式
        let messageIdSet = Set(messageIds)
        
        if messageIds.count != messageIdSet.count {
            let _ = messageIds.filter { id in messageIds.filter { $0 == id }.count > 1 }
        }
        
        // 🔍 新增：分析消息时间分布
        let sortedMessages = existingMessages.sorted { $0.timestamp > $1.timestamp }
        if !sortedMessages.isEmpty {
            let _ = sortedMessages.first!
            let _ = sortedMessages.last!
        }
        
        if newFriendsMessages.isEmpty {
            
            // 尝试其他可能的过滤条件
            let _ = existingMessages.filter({ $0.content.contains("拍") })
            let _ = existingMessages.filter({ $0.content.contains("朋友") })
            let _ = existingMessages.filter({ $0.content.contains("申请") })
            
            
            // 打印所有消息的概要信息
            if !existingMessages.isEmpty {
                for (_, _) in existingMessages.prefix(10).enumerated() {
                }
                if existingMessages.count > 10 {
                }
            }
        } else {
            for (_, message) in newFriendsMessages.enumerated() {
                let _ = isUserFavorited(message.senderId)
            }
        }
        
        
        // 打印缓存状态
        
        // 打印界面状态
        
        
        // 切换新的朋友列表的显示状态
        // 🔍 新增：分析消息发送者变化
        let messageSenders = existingMessages.map { $0.senderId }
        let uniqueSenders = Set(messageSenders)
        
        if messageSenders.count != uniqueSenders.count {
            let _ = messageSenders.filter { sender in messageSenders.filter { $0 == sender }.count > 1 }
        }
        
        // 🔍 新增：分析消息类型变化
        let messageTypes = existingMessages.map { $0.type }
        let uniqueTypes = Set(messageTypes)
        
        if messageTypes.count != uniqueTypes.count {
            let _ = messageTypes.filter { type in messageTypes.filter { $0 == type }.count > 1 }
        }
        
        // 🔍 新增：分析消息内容变化
        let messageContents = existingMessages.map { $0.content.prefix(30) }
        let uniqueContents = Set(messageContents)
        
        if messageContents.count != uniqueContents.count {
            let _ = messageContents.filter { content in messageContents.filter { $0 == content }.count > 1 }
        }
        
        // 🔍 新增：分析消息时间变化
        let messageTimes = existingMessages.map { $0.timestamp }
        let uniqueTimes = Set(messageTimes)
        
        if messageTimes.count != uniqueTimes.count {
            let _ = messageTimes.filter { time in messageTimes.filter { $0 == time }.count > 1 }
        }
        
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        _ = FriendshipManager.shared.friendshipRequests.filter { request in
            request.status == "pending" && request.user.id != currentUser.id
        }.count
        
        withAnimation(.easeInOut(duration: 0.3)) {
            // 直接展开并显示"新的朋友"列表
            isNewFriendsVisible = true
            isMessagesExpanded = true
        }
        
        // ✅ 新增：在展开时主动拉取一次最新的好友申请并刷新列表，避免徽章数量>0但列表为空的情况
        FriendshipManager.shared.fetchFriendshipRequestsWithRetry(maxAttempts: 3) { requests, error in
            DispatchQueue.main.async {
                if error != nil {
                    return
                }
                guard let requests = requests else {
                    self.existingMessages = []
                    return
                }
                guard let currentUser = userManager.currentUser else {
                    return
                }
                
                // 🎯 新增：获取"一键已读"的时间戳，用于判断已读状态
                let markAllAsReadKey = "MarkAllAsReadTimestamp_\(currentUser.id)"
                let markAllAsReadTimestamp = UserDefaults.standard.object(forKey: markAllAsReadKey) as? Date
                
                // 🎯 修改：只统计别人发送的 pending 申请
                let _ = requests.filter { request in
                    request.status == "pending" && request.user.id != currentUser.id
                }.count
                // 🎯 修改：过滤掉当前用户发出的好友申请
                let friendRequestMessages = requests.compactMap { request -> MessageItem? in
                    guard request.status == "pending" else {
                        return nil
                    }
                    // 过滤掉当前用户发出的申请
                    guard request.user.id != currentUser.id else {
                        return nil
                    }
                    
                    // 🎯 新增：如果好友申请的创建时间早于或等于"一键已读"的时间戳，则标记为已读
                    // 🔧 修复：添加1秒容差，避免时间精度问题导致相同时间的消息被误判为未读
                    let isRead: Bool
                    if let markAllAsReadTime = markAllAsReadTimestamp {
                        let timeDifference = request.createdAt.timeIntervalSince(markAllAsReadTime)
                        // 如果 createdAt 早于或等于 markAllAsReadTime（允许1秒容差），则标记为已读
                        isRead = timeDifference <= 1.0
                    } else {
                        isRead = false
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
                    
                    let content = "\(senderName) 对你发送了好友申请"
                    
                    return MessageItem(
                        objectId: request.objectId,
                        senderId: request.user.id,
                        senderName: senderName, // 🔧 修复：使用处理后的 senderName
                        senderAvatar: "",
                        senderLoginType: "unknown",
                        receiverId: request.friend.id,
                        receiverName: request.friend.fullName,
                        receiverAvatar: "",
                        receiverLoginType: "unknown",
                        content: content, // 🔧 修复：使用包含用户名的 content
                        timestamp: request.createdAt,
                        isRead: isRead, // 🎯 修复：使用时间比较逻辑而不是硬编码 false
                        type: .text,
                        deviceId: nil,
                        messageType: "friend_request", // 🎯 修复：使用 "friend_request" 而不是 "favorite"
                        isMatch: false
                    )
                }
                
                // 🎯 新增：批量查询 UserNameRecord，更新 senderName
                let senderIds = friendRequestMessages.map { $0.senderId }
                LeanCloudService.shared.batchFetchUserNames(userIds: senderIds, loginTypes: Array(repeating: "unknown", count: senderIds.count)) { userNameDict in
                    DispatchQueue.main.async {
                        // 更新 MessageItem 的 senderName
                        var updatedMessages = friendRequestMessages
                        for (index, message) in friendRequestMessages.enumerated() {
                            if let userName = userNameDict[message.senderId], !userName.isEmpty, userName != "未知用户" {
                                // 更新 senderName
                                updatedMessages[index] = MessageItem(
                                    id: message.id,
                                    objectId: message.objectId,
                                    senderId: message.senderId,
                                    senderName: userName, // 使用从 UserNameRecord 查询到的用户名
                                    senderAvatar: message.senderAvatar,
                                    senderLoginType: message.senderLoginType,
                                    receiverId: message.receiverId,
                                    receiverName: message.receiverName,
                                    receiverAvatar: message.receiverAvatar,
                                    receiverLoginType: message.receiverLoginType,
                                    content: "\(userName) 对你发送了好友申请", // 更新内容
                                    timestamp: message.timestamp,
                                    isRead: message.isRead,
                                    type: message.type,
                                    deviceId: message.deviceId,
                                    messageType: message.messageType,
                                    isMatch: message.isMatch
                                )
                            }
                        }
                        
                        // 🚀 修复：使用 withAnimation 确保 SwiftUI 检测到变化并立即刷新
                        withAnimation {
                            self.existingMessages = updatedMessages
                        }
                    }
                }
                
                // 🚀 修复：先使用原始数据，等批量查询完成后再更新
                self.existingMessages = friendRequestMessages
            }
        }
        
    }
}



