import SwiftUI

// MARK: - MessageView Pat Message Handling Extension
extension MessageView {
    
    // MARK: - Pat Message Detection Methods
    
    /**
     * 检测新的拍一拍消息
     */
    internal func detectNewPatMessages(_ newPatMessages: [MessageItem]) {
        
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        // 🔧 修复：比较新旧拍一拍消息，找出新增的（不再跳过空列表）
        let oldPatMessageIds = Set(existingPatMessages.map { $0.objectId ?? $0.id.uuidString })
        var hasNewMessages = false
        var newMessagesToAdd: [MessageItem] = []
        
        // 查找新增的消息
        for newMessage in newPatMessages {
            let messageId = newMessage.objectId ?? newMessage.id.uuidString
            if !oldPatMessageIds.contains(messageId) {
                // 这是一条新消息
                let isReceivedMessage = newMessage.receiverId == currentUser.id || newMessage.receiverId == currentUser.userId
                let isSentMessage = newMessage.senderId == currentUser.id || newMessage.senderId == currentUser.userId
                
                if isReceivedMessage || isSentMessage {
                    newMessagesToAdd.append(newMessage)
                    hasNewMessages = true
                    
                    // 🎯 新增：收到新消息时保存到本地
                    UserDefaultsManager.addPatMessage(newMessage, userId: currentUser.id)
                    
                    // 🔧 修复：如果是接收到的消息，触发处理
                    if isReceivedMessage && newMessage.senderId != currentUser.id && newMessage.senderId != currentUser.userId {
                        // 🎯 新增：检查发送方是否在我的好友列表中
                        let senderId = newMessage.senderId
                        let isFriend = FriendshipManager.shared.isFriend(senderId) || 
                                      existingFriends.contains { friend in
                                          friend.user1Id == senderId || friend.user2Id == senderId
                                      }
                        
                        if isFriend {
                            handleNewPatMessage(newMessage)
                        } else {
                            // 发送方不在好友列表中，不处理这个消息
                        }
                    }
                }
            }
        }
        
        // 🎯 修复：如果有新消息，立即更新 existingPatMessages 数组，触发UI刷新
        if hasNewMessages {
            // 合并新消息到现有列表
            var updatedMessages = existingPatMessages
            for newMessage in newMessagesToAdd {
                // 检查是否已存在（避免重复）
                let messageId = newMessage.objectId ?? newMessage.id.uuidString
                let exists = updatedMessages.contains { existing in
                    let existingId = existing.objectId ?? existing.id.uuidString
                    return existingId == messageId
                }
                
                if !exists {
                    updatedMessages.insert(newMessage, at: 0)
                }
            }
            
            // 按时间排序
            updatedMessages.sort { $0.timestamp > $1.timestamp }
            
            // 🔧 修复：立即更新 existingPatMessages，触发好友列表刷新
            existingPatMessages = updatedMessages
            
            // 🎯 新增：保存更新后的消息列表到本地
            UserDefaultsManager.savePatMessages(updatedMessages, userId: currentUser.id)
        }
        
    }
    
    /**
     * 处理新的拍一拍消息
     */
    private func handleNewPatMessage(_ message: MessageItem) {
        
        // 更新拍一拍消息的展开状态
        patMessagesExpandedStates[message.senderId] = true
        
        // 触发拍一拍通知
        triggerPatNotification(for: message)
        
        // 可以在这里添加其他处理逻辑，如播放音效、显示动画等
    }
    
    /**
     * 触发拍一拍通知
     */
    private func triggerPatNotification(for message: MessageItem) {
        
        // 发送通知
        NotificationCenter.default.post(
            name: NSNotification.Name("PatMessageReceived"),
            object: nil,
            userInfo: [
                "senderId": message.senderId,
                "senderName": message.senderName,
                "timestamp": message.timestamp
            ]
        )
        
    }
    
    // MARK: - Pat Message Interaction Methods
    
    /**
     * 处理拍一拍好友
     */
    internal func handlePatFriend(_ friendId: String) {
        
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        // 🎯 检查24小时内拍一拍数量限制（在点击时检查，不依赖API结果）
        let (canSend, limitErrorMessage) = UserDefaultsManager.canSendPatAction()
        if !canSend {
            // 超过限制，通过 NotificationCenter 发送通知显示提示
            NotificationCenter.default.post(
                name: NSNotification.Name("PatActionLimitExceeded"),
                object: nil,
                userInfo: ["message": limitErrorMessage, "showAlert": true]
            )
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
        
        // 设置拍一拍按钮状态
        patButtonPressed[friendId] = true
        
        // 发送拍一拍消息
        sendPatMessage(to: friendId)
        
        // 延迟重置按钮状态（2秒防误触）
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.patButtonPressed[friendId] = false
        }
        
    }
    
    /**
     * 发送拍一拍消息
     */
    private func sendPatMessage(to friendId: String) {
        
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        
        // 从好友列表中查找好友信息，获取真实的好友名称
        var friendName: String
        if let friend = existingFriends.first(where: { friend in
            friend.user1Id == friendId || friend.user2Id == friendId
        }) {
            // 从好友记录中获取真实名称
            friendName = friend.user1Id == currentUser.id ? friend.user2Name : friend.user1Name
        } else {
            // 如果找不到好友记录，尝试从缓存中获取用户名
            friendName = existingUserNameCache[friendId] ?? "好友"
        }
        
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
                        friendName: resolvedFriendName
                    )
                }
            }
            return
        }
        
        // 发送拍一拍消息
        sendPatMessageWithFriendName(
            currentUser: currentUser,
            friendId: friendId,
            friendName: friendName
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
    private func sendPatMessageWithFriendName(currentUser: UserInfo, friendId: String, friendName: String) {
        // 🔧 修复：直接使用 friendId（objectId），不再转换为用户名
        let toUserId = friendId
        
        // 🎯 立即记录发送时间（在点击时记录，不依赖API结果）
        UserDefaultsManager.recordPatActionSent(to: toUserId)
        
        // 使用新的拍一拍消息服务（与测试按钮一致）
        PatMessageService.shared.sendPatMessage(
            fromUserId: currentUser.id, // 🔧 修复：使用 objectId
            toUserId: toUserId, // 🔧 修复：使用 objectId
            fromUserName: currentUser.fullName,
            toUserName: friendName
        ) { success, error in
            DispatchQueue.main.async {
                if success {
                    // 拍一拍发送成功，由ContentView统一处理消息添加
                } else {
                    // 拍一拍发送失败
                }
            }
        }
    }
    
    /**
     * 添加拍一拍消息到本地列表（优化：平滑过渡机制）
     */
    private func addPatMessageToLocal(_ message: MessageItem) {
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        // 添加到拍一拍消息列表的开头
        existingPatMessages.insert(message, at: 0)
        
        // 🎯 新增：保存到本地存储
        UserDefaultsManager.addPatMessage(message, userId: currentUser.id)
    }
    
    // MARK: - Pat Message Display Methods
    
    /**
     * 切换拍一拍消息的展开状态
     */
    internal func togglePatMessageExpansion(for friendId: String) {
        let currentState = patMessagesExpandedStates[friendId] ?? false
        patMessagesExpandedStates[friendId] = !currentState
        
    }
    
    /**
     * 获取拍一拍消息的展开状态
     */
    internal func isPatMessageExpanded(for friendId: String) -> Bool {
        return patMessagesExpandedStates[friendId] ?? false
    }
    
    /**
     * 设置拍一拍消息的展开状态
     */
    internal func setPatMessageExpansion(for friendId: String, isExpanded: Bool) {
        patMessagesExpandedStates[friendId] = isExpanded
        
        // 🔧 新增：展开时标记该好友的拍一拍消息为已读
        if isExpanded {
            markPatMessagesAsRead(for: friendId)
        }
    }
    
    // 🔧 新增：标记指定好友的拍一拍消息为已读
    private func markPatMessagesAsRead(for friendId: String) {
        
        // 标记未读的拍一拍消息为已读
        var requestIndex = 0
        for index in existingPatMessages.indices {
            let message = existingPatMessages[index]
            let isPatMessage = message.content.contains("拍了拍") || message.messageType == "pat"
            let isFromFriend = message.senderId == friendId
            let isToCurrentUser = message.receiverId == userManager.currentUser?.id
            
            if isPatMessage && isFromFriend && isToCurrentUser {
                if !message.isRead {
                    
                    // 更新本地状态
                    existingPatMessages[index].isRead = true
                    
                    // 异步更新服务器状态，添加频率限制
                    if let objectId = message.objectId {
                        
                        // 🔧 新增：API 频率限制 - 1/17秒间隔
                        let delay = Double(requestIndex) / 17.0 // 每个请求间隔 1/17 秒
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            LeanCloudService.shared.markMessageAsRead(messageId: objectId) { success in
                                DispatchQueue.main.async {
                                    if success {
                                        // 🔧 新增：验证服务器状态
                                        self.verifyMessageViewServerReadStatus(messageId: objectId, content: message.content)
                                    } else {
                                        // 🔧 新增：记录失败原因
                                    }
                                }
                            }
                        }
                        requestIndex += 1
                    }
                }
            }
        }
        
        // 🔧 修复：立即触发UI刷新，确保数字立刻变化
        DispatchQueue.main.async {
            // MessageView 通过更新 @State 变量来触发UI刷新
            self.existingPatMessages = self.existingPatMessages
            
            // 🎯 新增：保存更新后的拍一拍消息到本地
            if let currentUser = self.userManager.currentUser {
                UserDefaultsManager.savePatMessages(self.existingPatMessages, userId: currentUser.id)
            }
        }
    }
    
    // 🔧 新增：验证MessageView服务器已读状态
    private func verifyMessageViewServerReadStatus(messageId: String, content: String) {
        
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
    
    /**
     * 展开所有拍一拍消息
     */
    internal func expandAllPatMessages() {
        for friendId in patMessagesExpandedStates.keys {
            patMessagesExpandedStates[friendId] = true
            // 🔧 新增：展开时标记该好友的拍一拍消息为已读
            markPatMessagesAsRead(for: friendId)
        }
    }
    
    /**
     * 折叠所有拍一拍消息
     */
    internal func collapseAllPatMessages() {
        for friendId in patMessagesExpandedStates.keys {
            patMessagesExpandedStates[friendId] = false
        }
    }
    
    // MARK: - Pat Message Filtering Methods
    
    /**
     * 获取指定好友的拍一拍消息
     */
    internal func getPatMessages(for friendId: String) -> [MessageItem] {
        return existingPatMessages.filter { message in
            return message.senderId == friendId || message.receiverId == friendId
        }
    }
    
    /**
     * 获取最近的拍一拍消息
     */
    internal func getRecentPatMessages(limit: Int = 10) -> [MessageItem] {
        return Array(existingPatMessages.prefix(limit))
    }
    
    /**
     * 按时间排序拍一拍消息
     */
    internal func sortPatMessagesByTime() {
        existingPatMessages.sort { $0.timestamp > $1.timestamp }
    }
    
    /**
     * 按发送者分组拍一拍消息
     */
    internal func groupPatMessagesBySender() -> [String: [MessageItem]] {
        var grouped: [String: [MessageItem]] = [:]
        
        for message in existingPatMessages {
            let senderId = message.senderId
            if grouped[senderId] == nil {
                grouped[senderId] = []
            }
            grouped[senderId]?.append(message)
        }
        
        return grouped
    }
    
    // MARK: - Pat Message Statistics Methods
    
    /**
     * 获取拍一拍消息统计信息
     */
    internal func getPatMessageStatistics() -> (totalCount: Int, uniqueSenders: Int, recentCount: Int) {
        let totalCount = existingPatMessages.count
        let uniqueSenders = Set(existingPatMessages.map { $0.senderId }).count
        let recentCount = existingPatMessages.filter { message in
            let fiveMinutesAgo = Date().addingTimeInterval(-300)
            return message.timestamp > fiveMinutesAgo
        }.count
        
        return (totalCount: totalCount, uniqueSenders: uniqueSenders, recentCount: recentCount)
    }
    
    /**
     * 打印拍一拍消息统计信息
     */
    internal func printPatMessageStatistics() {
        // 调试函数已删除
    }
    
    // MARK: - Pat Message Cleanup Methods
    
    /**
     * 清理过期的拍一拍消息
     */
    internal func cleanupExpiredPatMessages() {
        let oneWeekAgo = Date().addingTimeInterval(-604800) // 7天前
        existingPatMessages = existingPatMessages.filter { message in
            return message.timestamp > oneWeekAgo
        }
    }
    
    /**
     * 清理重复的拍一拍消息
     */
    internal func cleanupDuplicatePatMessages() {
        var uniqueMessages: [MessageItem] = []
        var seenMessages: Set<String> = []
        
        for message in existingPatMessages {
            let messageKey = "\(message.senderId)-\(message.receiverId)-\(message.timestamp.timeIntervalSince1970)"
            if !seenMessages.contains(messageKey) {
                uniqueMessages.append(message)
                seenMessages.insert(messageKey)
            }
        }
        
        let duplicateCount = existingPatMessages.count - uniqueMessages.count
        if duplicateCount > 0 {
            existingPatMessages = uniqueMessages
        }
    }
    
    // MARK: - Pat Message Event Handling Methods
    
    /**
     * 处理拍一拍消息接收事件
     */
    internal func handlePatMessageReceived(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let senderId = userInfo["senderId"] as? String else {
            return
        }
        
        
        // 更新UI状态
        patMessagesExpandedStates[senderId] = true
        
        // 可以在这里添加其他处理逻辑
        // 例如：播放提示音、显示通知等
    }
    
    /**
     * 处理拍一拍消息发送成功事件
     */
    internal func handlePatMessageSent(_ friendId: String) {
        
        // 更新按钮状态
        patButtonPressed[friendId] = false
        
        // 可以在这里添加其他处理逻辑
    }
    
    /**
     * 处理拍一拍消息发送失败事件
     */
    internal func handlePatMessageSendFailed(_ friendId: String, error: String) {
        
        // 更新按钮状态
        patButtonPressed[friendId] = false
        
        // 可以在这里添加错误处理逻辑
        // 例如：显示错误提示、重试机制等
    }
}
