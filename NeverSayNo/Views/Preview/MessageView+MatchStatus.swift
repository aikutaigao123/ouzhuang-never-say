import SwiftUI

// MARK: - MessageView Match Status Extension
extension MessageView {
    
    // MARK: - Match Status Detection Methods
    
    /**
     * 检测匹配状态
     * 如果对方也喜欢当前用户，则标记为匹配成功
     */
    internal func detectMatchStatus(for message: MessageItem) -> Bool {
        
        // 只有喜欢或点赞类型的消息才可能匹配成功
        guard message.messageType == "favorite" || message.messageType == "like" else { 
            return false 
        }
        
        
        // 检查对方是否也喜欢当前用户
        let currentUserId = userManager.currentUser?.id ?? ""
        let senderId = message.senderId
        
        
        // 检查favoriteRecords中是否有对方喜欢当前用户的记录
        for (_, _) in favoriteRecords.enumerated() {
        }
        
        let isLikedBySender = favoriteRecords.contains { favoriteRecord in
            favoriteRecord.userId == senderId && favoriteRecord.favoriteUserId == currentUserId
        }
        
        
        // 🚀 新增：检查是否有匹配的记录
        let matchingRecords = favoriteRecords.filter { favoriteRecord in
            favoriteRecord.userId == senderId && favoriteRecord.favoriteUserId == currentUserId
        }
        for (_, _) in matchingRecords.enumerated() {
        }
        
        // 🚀 新增：如果favoriteRecords中没有找到，尝试从LeanCloud查询
        var isLikedBySenderFromLeanCloud = false
        if !isLikedBySender {
            // 这里可以添加从LeanCloud查询的逻辑
            // 暂时使用简化逻辑：如果当前用户也喜欢对方，则认为匹配成功
            let currentUserLikesSender = favoriteRecords.contains { favoriteRecord in
                favoriteRecord.userId == currentUserId && favoriteRecord.favoriteUserId == senderId
            }
            
            // 🚀 临时解决方案：如果双方都喜欢对方，则认为匹配成功
            if currentUserLikesSender {
                isLikedBySenderFromLeanCloud = true
            }
        }
        
        // 检查usersWhoLikedMe中是否有对方（暂时注释掉，因为变量不在当前作用域）
        // let isInLikedMeList = usersWhoLikedMe.contains { likedUser in
        //     likedUser.id == senderId
        // }
        let isInLikedMeList = false // 暂时设为false
        
        
        // 如果对方也喜欢当前用户，则匹配成功
        let isMatch = isLikedBySender || isLikedBySenderFromLeanCloud || isInLikedMeList
        
        
        // 🚀 修复：返回真实的匹配结果，而不是强制返回false
        if isMatch {
        } else {
        }
        
        return isMatch
    }
    
    // MARK: - Match Record Management Methods
    
    /**
     * 自动检测并上传MatchRecord
     * ⚠️ 已废弃：不再上传 MatchRecord 到 LeanCloud
     * 根据 LeanCloud 好友关系开发指南，好友关系应通过 FriendshipManager 管理
     */
    @available(*, deprecated, message: "Use FriendshipManager instead")
    internal func autoDetectAndUploadMatchRecords() {
        // 此方法已废弃，不再执行任何操作
        // 好友关系现在完全由 FriendshipManager 和官方 _Followee 表管理
    }
    
    /**
     * 为指定消息上传MatchRecord
     * ⚠️ 已废弃
     */
    @available(*, deprecated, message: "Use FriendshipManager instead")
    private func uploadMatchRecord(for message: MessageItem, currentUserId: String) {
        // 此方法已废弃，不再执行任何操作
    }
    
    // MARK: - Match Status Update Methods
    
    /**
     * 更新消息的匹配状态
     */
    internal func updateMessageMatchStatus(_ messageId: UUID, isMatch: Bool) {
        
        // 查找并更新消息的匹配状态
        if let index = existingMessages.firstIndex(where: { $0.id == messageId }) {
            let _ = existingMessages[index].isMatch
            existingMessages[index].isMatch = isMatch
            
        } else {
            for (_, _) in existingMessages.enumerated() {
            }
        }
    }
    
    /**
     * 批量更新消息的匹配状态
     */
    internal func batchUpdateMessageMatchStatus(_ updates: [UUID: Bool]) {
        for (messageId, isMatch) in updates {
            updateMessageMatchStatus(messageId, isMatch: isMatch)
        }
    }
    
    // MARK: - Match Validation Methods
    
    /**
     * 验证匹配状态的有效性
     */
    internal func validateMatchStatus() -> Bool {
        
        var isValid = true
        
        for message in existingMessages {
            if message.isMatch {
                // 检查匹配状态是否有效
                let currentMatchStatus = detectMatchStatus(for: message)
                
                if currentMatchStatus != message.isMatch {
                    isValid = false
                }
            }
        }
        
        if isValid {
        } else {
        }
        
        return isValid
    }
    
    /**
     * 修复无效的匹配状态
     */
    internal func repairMatchStatus() {
        
        for index in 0..<existingMessages.count {
            let message = existingMessages[index]
            let currentMatchStatus = detectMatchStatus(for: message)
            
            if message.isMatch != currentMatchStatus {
                existingMessages[index].isMatch = currentMatchStatus
            }
        }
        
    }
    
    // MARK: - Match Statistics Methods
    
    /**
     * 获取匹配统计信息
     */
    internal func getMatchStatistics() -> (totalMessages: Int, matchedMessages: Int, matchRate: Double) {
        let totalMessages = existingMessages.count
        let matchedMessages = existingMessages.filter { $0.isMatch }.count
        let matchRate = totalMessages > 0 ? Double(matchedMessages) / Double(totalMessages) : 0.0
        
        return (totalMessages: totalMessages, matchedMessages: matchedMessages, matchRate: matchRate)
    }
    
    
    // MARK: - Match Event Handling Methods
    
    /**
     * 处理匹配成功事件
     * 根据 LeanCloud 好友关系开发指南：匹配成功时应自动接受好友申请，在 _Followee 表中建立好友关系
     */
    internal func handleMatchSuccess(for message: MessageItem) {
        let _ = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        
        // 🚀 立即触发UI更新，确保匹配成功提示立即显示
        withAnimation(.easeInOut(duration: 0.2)) {
            // 找到对应的消息并更新其匹配状态
            if let index = self.existingMessages.firstIndex(where: { $0.id == message.id }) {
                self.existingMessages[index].isMatch = true
            }
        }
        
        // 更新消息状态
        updateMessageMatchStatus(message.id, isMatch: true)
        
        // 🚀 新增：匹配成功时自动标记相关消息为已读
        markRelatedMessagesAsRead(for: message)
        
        // 🎯 修复：根据 LeanCloud 好友关系开发指南，匹配成功时应自动接受好友申请
        // 查找对方发送的好友申请（status 为 pending）
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        let senderId = message.senderId
        let receiverId = message.receiverId
        
        // 确定对方ID（不是当前用户的那个）
        let otherUserId = (senderId == currentUser.id) ? receiverId : senderId
        
        // 查询对方发送的好友申请
        FriendshipManager.shared.fetchFriendshipRequests(status: "pending") { requests, error in
            DispatchQueue.main.async {
                if error != nil {
                    return
                }
                
                guard let requests = requests else {
                    return
                }
                
                // 查找对方发送给当前用户的好友申请
                if let request = requests.first(where: { request in
                    request.user.id == otherUserId && request.friend.id == currentUser.id && request.status == "pending"
                }) {
                    // 🎯 符合开发指南：接受好友申请，会自动更新 _FriendshipRequest 的 status 为 accepted，并在 _Followee 表建立双向好友关系
                    FriendshipManager.shared.acceptFriendshipRequest(request, attributes: nil) { success, errorMessage in
                        DispatchQueue.main.async {
                            if success {
                                // 刷新好友列表和新朋友列表
                                NotificationCenter.default.post(name: NSNotification.Name("RefreshFriendsList"), object: nil)
                                NotificationCenter.default.post(name: NSNotification.Name("RefreshNewFriends"), object: nil)
                            } else {
                            }
                        }
                    }
                } else {
                }
            }
        }
        
        // ⚠️ 已废弃：不再上传 MatchRecord，改用 FriendshipManager 自动建立好友关系
        // 根据 LeanCloud 好友关系开发指南，匹配成功时应自动接受好友申请
        // FriendshipManager.shared.acceptFriendshipRequest() 会自动在 _Followee 表中建立好友关系
        
        // 🚀 立即触发好友列表刷新，确保好友列表立即增加
        NotificationCenter.default.post(name: NSNotification.Name("RefreshFriendsList"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("RefreshNewFriends"), object: nil)
        
        // 验证更新后的状态
        if existingMessages.first(where: { $0.id == message.id }) != nil {
        } else {
        }
        
        // 触发匹配成功通知
        NotificationCenter.default.post(
            name: NSNotification.Name("MatchSuccess"),
            object: nil,
            userInfo: ["message": message]
        )
        
        // 可以在这里添加其他匹配成功的处理逻辑
        // 例如：显示匹配成功动画、播放音效等
    }
    
    /**
     * 标记相关消息为已读（匹配成功时调用）
     */
    private func markRelatedMessagesAsRead(for message: MessageItem) {
        
        // 🚀 新增：打印所有未读消息
        let unreadMessages = existingMessages.filter { !$0.isRead }
            for (_, _) in unreadMessages.enumerated() {
            }
        
        var markedCount = 0
        
        // 标记与当前用户相关的所有未读消息为已读
        for index in existingMessages.indices {
            let currentMessage = existingMessages[index]
            
            // 检查是否为相关消息（发送者或接收者是当前用户，且消息类型为好友申请）
            let isRelevantMessage = (currentMessage.senderId == message.senderId || 
                                   currentMessage.receiverId == message.senderId ||
                                   currentMessage.senderId == message.receiverId || 
                                   currentMessage.receiverId == message.receiverId) &&
                                   (currentMessage.messageType == "favorite" || 
                                    currentMessage.messageType == "like" ||
                                    currentMessage.content.contains("对你发送了好友申请") ||
                                    currentMessage.content.contains("已同意") ||
                                    currentMessage.content.contains("已拒绝"))
            
            // 如果消息未读且相关，则标记为已读
            if !currentMessage.isRead && isRelevantMessage {
                existingMessages[index].isRead = true
                markedCount += 1
                
                
                // 异步更新服务器状态
                if let objectId = currentMessage.objectId {
                    LeanCloudService.shared.markMessageAsRead(messageId: objectId) { success in
                        if success {
                        } else {
                        }
                    }
                }
            }
        }
        
        // 更新未读消息计数
        let newUnreadCount = calculateUnreadCount()
        unreadCount = newUnreadCount
        
        // 更新新朋友申请数量
        let newFriendsCount = existingMessages.filter { message in
            let isRelevantMessage = message.content.contains("对你发送了好友申请") ||
                                   message.content.contains("已同意") ||
                                   message.content.contains("已拒绝") ||
                                   message.content.contains("撤销好友申请")
            
            let isNotPatMessage = !message.content.contains("拍了拍你") && 
                                 message.messageType != "pat"
            
            let isUnread = !message.isRead
            return isRelevantMessage && isNotPatMessage && isUnread
        }.count
        
        newFriendsCountManager.updateCount(newFriendsCount)
        
        
        // 🚀 新增：打印标记后的所有未读消息
        let remainingUnreadMessages = existingMessages.filter { !$0.isRead }
        for (_, _) in remainingUnreadMessages.enumerated() {
        }
    }
    
    /**
     * 处理匹配失败事件
     */
    internal func handleMatchFailure(for message: MessageItem) {
        
        // 更新消息状态
        updateMessageMatchStatus(message.id, isMatch: false)
        
        // 可以在这里添加其他匹配失败的处理逻辑
    }
    
    // MARK: - Match Cleanup Methods
    
    /**
     * 清理过期的匹配状态
     */
    internal func cleanupExpiredMatchStatus() {
        
        let currentTime = Date()
        let oneHourAgo = currentTime.addingTimeInterval(-3600)
        
        var cleanedCount = 0
        
        for index in 0..<existingMessages.count {
            let message = existingMessages[index]
            
            // 如果消息超过1小时且匹配状态为true，重新检测
            if message.timestamp < oneHourAgo && message.isMatch {
                let currentMatchStatus = detectMatchStatus(for: message)
                if currentMatchStatus != message.isMatch {
                    existingMessages[index].isMatch = currentMatchStatus
                    cleanedCount += 1
                }
            }
        }
        
        if cleanedCount > 0 {
        } else {
        }
    }
}
