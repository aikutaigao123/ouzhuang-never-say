import SwiftUI

extension FriendRowView {
    // 计算属性：获取当前好友的展开状态
    var isPatMessagesExpanded: Bool {
        let friendId = friend.user1Id == currentUserId ? friend.user2Id : friend.user1Id
        return patMessagesExpandedStates[friendId] ?? false
    }
    
    // 设置展开状态的方法
    func setPatMessagesExpanded(_ expanded: Bool) {
        let friendId = friend.user1Id == currentUserId ? friend.user2Id : friend.user1Id
        
        patMessagesExpandedStates[friendId] = expanded
        
        // 🔧 新增：展开时标记该好友的拍一拍消息为已读
        if expanded {
            markPatMessagesAsRead(for: friendId)
        }
    }
    
    // 🔧 新增：标记指定好友的拍一拍消息为已读
    func markPatMessagesAsRead(for friendId: String) {
        // 🔧 修复：获取好友的 objectId（如果有）
        let friendObjectId = friend.objectId
        
        var markedCount = 0
        var alreadyReadCount = 0
        var notFoundCount = 0
        
        // 查找该好友的拍一拍消息（修复ID匹配）
        let friendPatMessages = patMessages.filter { message in
            let isPatMessage = message.content.contains("拍了拍") || message.messageType == "pat"
            let isFromFriend = message.senderId == friendId || (friendObjectId != nil && message.senderId == friendObjectId)
            let isToCurrentUser = message.receiverId == currentUserId
            return isPatMessage && isFromFriend && isToCurrentUser
        }
        
        // 标记未读的拍一拍消息为已读
        for (index, message) in friendPatMessages.enumerated() {
            if !message.isRead {
                // 🔧 修复：使用id（UUID）来匹配消息，因为objectId可能为nil
                // 优先使用objectId匹配，如果objectId为nil则使用id匹配
                var messageIndex: Int?
                if let objectId = message.objectId, !objectId.isEmpty {
                    messageIndex = patMessages.firstIndex(where: { $0.objectId == objectId })
                } else {
                    // objectId为nil时，使用id（UUID）匹配
                    messageIndex = patMessages.firstIndex(where: { $0.id == message.id })
                }
                
                if let foundIndex = messageIndex {
                    patMessages[foundIndex].isRead = true
                } else {
                    notFoundCount += 1
                }
                
                // 异步更新服务器状态，添加频率限制
                if let objectId = message.objectId {
                    // 🔧 新增：API 频率限制 - 1/17秒间隔
                    let delay = Double(index) / 17.0 // 每个请求间隔 1/17 秒
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        LeanCloudService.shared.markMessageAsRead(messageId: objectId) { success in
                            DispatchQueue.main.async {
                                if success {
                                    // 🔧 新增：验证服务器状态
                                    self.verifyServerReadStatus(messageId: objectId, content: message.content)
                                }
                            }
                        }
                    }
                }
                markedCount += 1
            } else {
                alreadyReadCount += 1
            }
        }
        
        // 🔧 修复：立即触发UI刷新，确保数字立刻变化
        DispatchQueue.main.async {
            // 🎯 修改：强制触发UI刷新，确保数字立即清0
            // 通过更新 @Binding 变量来触发UI刷新
            let updatedMessages = self.patMessages
            // 强制更新数组引用，触发SwiftUI重新计算patCount
            self.patMessages = updatedMessages
            
            // 🎯 新增：保存更新后的拍一拍消息到本地，确保重新进入消息界面时已读状态不丢失
            UserDefaultsManager.savePatMessages(updatedMessages, userId: self.currentUserId)
        }
    }
    
    // 🔧 新增：验证服务器已读状态
    func verifyServerReadStatus(messageId: String, content: String) {
        
        // 延迟验证，给服务器一些时间更新
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            LeanCloudService.shared.fetchMessageReadStatus(messageId: messageId) { isRead in
                DispatchQueue.main.async {
                    if let isRead = isRead {
                        if !isRead {
                        }
                    } else {
                    }
                }
            }
        }
    }
    
    // 检查数字变化（初始化时调用）
    func checkPatCountChange() {
        if !hasInitializedPatCount {
            // 首次初始化
            previousPatCount = patCount
            hasInitializedPatCount = true
            
        }
    }
    
    // 打印数字变化
    func printPatCountChange(newCount: Int) {
        let friendObjectId = friend.objectId
        
        if newCount != previousPatCount {
            
            // 简化的数据源追踪
            
            // 🔧 新增：显示未读消息详情（修复ID匹配）
            let friendId = friend.user1Id == currentUserId ? friend.user2Id : friend.user1Id
            let unreadMessages = patMessages.filter { message in
                let senderMatches = message.senderId == friendId || (friendObjectId != nil && message.senderId == friendObjectId)
                let receiverMatches = message.receiverId == currentUserId
                let isFriendPatMe = senderMatches && receiverMatches
                let isUnread = !message.isRead
                return isFriendPatMe && isUnread
            }
            
            _ = patMessages.filter { message in
                let senderMatches = message.senderId == friendId || (friendObjectId != nil && message.senderId == friendObjectId)
                let receiverMatches = message.receiverId == currentUserId
                let isFriendPatMe = senderMatches && receiverMatches
                return isFriendPatMe
            }
            
            
            // 🔧 新增：详细分析消息状态变化（修复ID匹配）
            _ = patMessages.filter { message in
                let senderMatches = message.senderId == friendId || (friendObjectId != nil && message.senderId == friendObjectId)
                let receiverMatches = message.receiverId == currentUserId
                let isFriendPatMe = senderMatches && receiverMatches
                let isRead = message.isRead
                return isFriendPatMe && isRead
            }
            
            // 🔧 新增：检查消息类型分布（修复ID匹配）
            _ = patMessages.filter { message in
                let senderMatches = message.senderId == friendId || (friendObjectId != nil && message.senderId == friendObjectId)
                let receiverMatches = message.receiverId == currentUserId
                let isFriendPatMe = senderMatches && receiverMatches
                let isPatType = message.messageType == "pat"
                return isFriendPatMe && isPatType
            }
            
            _ = patMessages.filter { message in
                let senderMatches = message.senderId == friendId || (friendObjectId != nil && message.senderId == friendObjectId)
                let receiverMatches = message.receiverId == currentUserId
                let isFriendPatMe = senderMatches && receiverMatches
                let hasPatContent = message.content.contains("拍了拍")
                return isFriendPatMe && hasPatContent
            }
            
            // 🔧 新增：检查数据一致性
            if newCount != unreadMessages.count {
            }
            
            // 简化的消息信息（修复ID匹配）
            let friendObjectId = friend.objectId
            let allMessagesFromFriend = patMessages.filter { message in
                let senderMatches = message.senderId == friendId || (friendObjectId != nil && message.senderId == friendObjectId)
                let receiverMatches = message.receiverId == currentUserId
                return senderMatches && receiverMatches
            }
            
            if !allMessagesFromFriend.isEmpty {
                _ = allMessagesFromFriend.sorted { $0.timestamp > $1.timestamp }.first!
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm:ss"
            }
            
            if newCount > previousPatCount {
                let increase = newCount - previousPatCount
                
                // 打印导致数字增加的新消息
                printNewMessages(friendId: friendId, increase: increase)
                
            } else if newCount < previousPatCount {
                let decrease = previousPatCount - newCount
                
                // 打印导致数字减少的消息（可能是被标记为已读）
                printReadMessages(friendId: friendId, decrease: decrease)
            }
            
            // 显示变化时间
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            
            // 📊 好友头像右上角数字发生变化时触发本地缓存的更新
            updateLocalCacheOnMessageCountChange(friendId: friendId, newCount: newCount)
            
            // 更新之前的数字
            previousPatCount = newCount
            
        }
    }
    
    // 打印导致数字增加的新消息
    func printNewMessages(friendId: String, increase: Int) {
        // 🔧 修复：获取好友的 objectId（如果有）
        let friendObjectId = friend.objectId
        
        // 获取该好友发送给我的所有消息（修复ID匹配）
        let allMessagesFromFriend = patMessages.filter { message in
            let senderMatches = message.senderId == friendId || (friendObjectId != nil && message.senderId == friendObjectId)
            let receiverMatches = message.receiverId == currentUserId
            return senderMatches && receiverMatches
        }
        
        // 按时间排序，获取最新的几条消息
        let sortedMessages = allMessagesFromFriend.sorted { $0.timestamp > $1.timestamp }
        let recentMessages = Array(sortedMessages.prefix(increase))
        
        if !recentMessages.isEmpty {
            for (_, _) in recentMessages.enumerated() {
                let formatter = DateFormatter()
                formatter.dateFormat = "MM-dd HH:mm:ss"
                
            }
        } else {
        }
    }
    
    // 📊 好友头像右上角数字发生变化时触发本地缓存的更新
    func updateLocalCacheOnMessageCountChange(friendId: String, newCount: Int) {
        
        // 1. 更新消息按钮缓存
        MessageButtonCacheManager.shared.updateMessageCount(for: friendId, count: newCount)
        
        // 2. 发送通知，让其他界面知道缓存已更新
        NotificationCenter.default.post(
            name: NSNotification.Name("MessageCountCacheUpdated"),
            object: nil,
            userInfo: [
                "friendId": friendId,
                "newCount": newCount,
                "timestamp": Date()
            ]
        )
        
    }
    
    // 打印导致数字减少的消息（被标记为已读）
    func printReadMessages(friendId: String, decrease: Int) {
        // 🔧 修复：获取好友的 objectId（如果有）
        let friendObjectId = friend.objectId
        
        // 获取该好友发送给我的所有消息（修复ID匹配）
        let allMessagesFromFriend = patMessages.filter { message in
            let senderMatches = message.senderId == friendId || (friendObjectId != nil && message.senderId == friendObjectId)
            let receiverMatches = message.receiverId == currentUserId
            return senderMatches && receiverMatches
        }
        
        // 按时间排序，获取最新的几条消息
        let sortedMessages = allMessagesFromFriend.sorted { $0.timestamp > $1.timestamp }
        let recentMessages = Array(sortedMessages.prefix(decrease))
        
        if !recentMessages.isEmpty {
            for (_, _) in recentMessages.enumerated() {
                let formatter = DateFormatter()
                formatter.dateFormat = "MM-dd HH:mm:ss"
                
            }
        } else {
        }
    }
    
    // 计算该好友的未读拍一拍消息数量
    var patCount: Int {
        let friendId = friend.user1Id == currentUserId ? friend.user2Id : friend.user1Id
        
        // 🔧 修复：根据 FriendshipManager 的实现，userId 实际上就是 objectId
        // 所以 friendId 和 currentUserId 应该能直接匹配消息的 senderId 和 receiverId
        // 但为了安全起见，我们也检查 friend.objectId（如果有的话）
        let friendObjectId = friend.objectId
        
        // 确保数据源一致性：使用当前传入的patMessages数组
        let matchingMessages = patMessages.filter { message in
            // 只统计朋友拍我的未读消息
            // 发送者匹配：消息的 senderId 可能是 friendId (userId，即objectId) 或 friendObjectId
            let senderMatches = message.senderId == friendId || (friendObjectId != nil && message.senderId == friendObjectId)
            
            // 接收者匹配：消息的 receiverId 应该是 currentUserId (userId，即objectId)
            // 注意：根据 FriendshipManager，currentUserId 就是 objectId
            let receiverMatches = message.receiverId == currentUserId
            
            let isFriendPatMe = senderMatches && receiverMatches
            let isUnread = !message.isRead
            return isFriendPatMe && isUnread
        }
        
        let count = matchingMessages.count
        
        return count
    }
    
    // 获取该好友的拍一拍消息（只统计收到的消息：朋友拍我的）
    var friendPatMessages: [MessageItem] {
        let friendId = friend.user1Id == currentUserId ? friend.user2Id : friend.user1Id
        let friendObjectId = friend.objectId
        
        // 🔧 修复：同时匹配 userId 和 objectId，因为消息的 senderId/receiverId 可能是 objectId 或 userId
        // 确保数据源一致性：使用当前传入的patMessages数组
        let filteredMessages = patMessages.filter { message in
            // 只统计朋友拍我的消息
            // 发送者匹配：消息的 senderId 可能是 friendId (userId，即objectId) 或 friendObjectId
            let senderMatches = message.senderId == friendId || (friendObjectId != nil && message.senderId == friendObjectId)
            // 接收者匹配：消息的 receiverId 应该是 currentUserId (userId，即objectId)
            let receiverMatches = message.receiverId == currentUserId
            let isFriendPatMe = senderMatches && receiverMatches
            return isFriendPatMe
        }
        
        return filteredMessages
    }
    
    // 获取该好友的所有拍一拍消息（双向显示：包括我拍朋友的和朋友拍我的）
    var allFriendPatMessages: [MessageItem] {
        let friendId = friend.user1Id == currentUserId ? friend.user2Id : friend.user1Id
        let friendObjectId = friend.objectId
        
        // 🔧 修复：同时匹配 userId 和 objectId
        let filteredMessages = patMessages.filter { message in
            // 显示朋友拍我的消息
            let senderMatches = message.senderId == friendId || (friendObjectId != nil && message.senderId == friendObjectId)
            let receiverMatches = message.receiverId == currentUserId
            let isFriendPatMe = senderMatches && receiverMatches
            
            // 显示我拍朋友的消息
            let mySenderMatches = message.senderId == currentUserId
            let friendReceiverMatches = message.receiverId == friendId || (friendObjectId != nil && message.receiverId == friendObjectId)
            let isIPatFriend = mySenderMatches && friendReceiverMatches
            
            return isFriendPatMe || isIPatFriend
        }
        
        return filteredMessages
    }
    
    // 🎯 新增：获取最新拍一拍消息的显示文本（用于主行显示）
    func getLatestPatMessage() -> String? {
        let allMessages = allFriendPatMessages
        guard !allMessages.isEmpty else {
            return nil
        }
        
        // 按时间排序，获取最新一条
        let sortedMessages = allMessages.sorted { $0.timestamp > $1.timestamp }
        guard let latestMessage = sortedMessages.first else {
            return nil
        }
        
        let friendId = friend.user1Id == currentUserId ? friend.user2Id : friend.user1Id
        let friendObjectId = friend.objectId
        let friendDisplayName = displayedName
        
        // 判断消息方向
        let isIPatFriend = latestMessage.senderId == currentUserId && 
                         (latestMessage.receiverId == friendId || (friendObjectId != nil && latestMessage.receiverId == friendObjectId))
        
        let isFriendPatMe = (latestMessage.senderId == friendId || (friendObjectId != nil && latestMessage.senderId == friendObjectId)) && 
                           latestMessage.receiverId == currentUserId
        
        // 生成显示文本
        if isIPatFriend {
            return "你拍了拍 \(friendDisplayName)"
        } else if isFriendPatMe {
            let senderName = (!latestMessage.senderName.isEmpty && latestMessage.senderName != "未知用户") ? latestMessage.senderName : friendDisplayName
            return "\(senderName) 拍了拍你"
        }
        
        return nil
    }
}



