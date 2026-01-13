import SwiftUI

// MARK: - MessageView Helper Methods Extension
extension MessageView {
    
    // MARK: - Button Action Methods
    
    /**
     * 处理添加朋友按钮点击 - 与赠与按钮中的搜索用户一致：直接打开搜索界面
     */
    internal func handleAddFriendButtonTap() {
        addFriendSearchText = ""
        addFriendSearchResults = []
        addFriendErrorMessage = nil
        showingAddFriendSheet = true
    }
    
    /**
     * 处理拒绝好友申请（根据 requestId）
     */
    internal func handleDeclineFriendRequest(requestId: String) {
        
        FriendshipManager.shared.fetchFriendshipRequests { requests, error in
            DispatchQueue.main.async {
                if error != nil {
                    return
                }
                
                guard let requests = requests,
                      let request = requests.first(where: { $0.objectId == requestId }) else {
                    return
                }
                
                
                FriendshipManager.shared.declineFriendshipRequest(request) { success, errorMessage in
                    DispatchQueue.main.async {
                        if success {
                            
                            // 刷新新的朋友列表
                            self.refreshNewFriendsList()
                            
                            // 通知其他界面刷新
                            NotificationCenter.default.post(name: NSNotification.Name("RefreshNewFriends"), object: nil)
                            NotificationCenter.default.post(name: NSNotification.Name("FriendshipRequestUpdated"), object: nil)
                            
                            // 延迟再次刷新，确保服务器数据同步完成
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                NotificationCenter.default.post(name: NSNotification.Name("RefreshNewFriends"), object: nil)
                                NotificationCenter.default.post(name: NSNotification.Name("FriendshipRequestUpdated"), object: nil)
                            }
                        } else {
                        }
                    }
                }
            }
        }
    }

    /**
     * 处理搜索好友按钮点击（搜索用户名）- 与赠与按钮中的搜索用户一致：实时搜索
     */
    internal func performFriendSearch(query: String) {
        // 与赠与按钮一致：至少2个字符才搜索
        guard !query.isEmpty, query.count >= 2 else {
            addFriendSearchResults = []
            return
        }
        
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        isSearchingFriend = true
        addFriendErrorMessage = nil
        
        // 执行搜索
        FriendshipManager.shared.searchUsers(byName: query, excludingUserId: currentUser.id) { users, error in
            DispatchQueue.main.async {
                self.isSearchingFriend = false
                
                if error != nil {
                    // 搜索失败，清空结果但不显示错误（与赠与按钮一致）
                    self.addFriendSearchResults = []
                    return
                } else if let users = users {
                    self.addFriendSearchResults = users
                } else {
                    self.addFriendSearchResults = []
                }
            }
        }
    }
    
    /**
     * 处理选择好友结果 - 与历史记录按钮一致：根据userId查询最新位置记录并跳转
     */
    internal func handleFriendSelection(user: UserInfo) {
        showingAddFriendSheet = false
        
        // 调用回调，将用户信息传递到ContentView处理
        // 如果回调存在，使用回调；否则显示Toast提示
        if let onUserSearchTap = onUserSearchTap {
            onUserSearchTap(user)
        } else {
            stateManager.showAntiSpamToast(message: "已选择用户：\(user.fullName)")
        }
    }
    
    /**
     * 处理消息点击事件
     */
    internal func handleMessageTap(_ message: MessageItem) {
        
        // 标记消息为已读
        if let index = existingMessages.firstIndex(where: { $0.id == message.id }) {
            existingMessages[index].isRead = true
        }
        
        // 更新未读消息计数
        unreadCount = calculateUnreadCount()
        
        // 🎯 新增：将点击事件传递给父级回调（ContentView 或外部调用者）
        // 这样可以复用主界面的匹配显示逻辑，使新的朋友列表与历史记录按钮行为一致
        onMessageTap(message)
    }
    
    /**
     * 处理标记为已读事件
     */
    internal func handleMarkAsRead(_ message: MessageItem) {
        
        // 标记消息为已读
        if let index = existingMessages.firstIndex(where: { $0.id == message.id }) {
            existingMessages[index].isRead = true
        }
        
        // 更新未读消息计数
        unreadCount = calculateUnreadCount()
        
    }
    
    /**
     * 处理查看位置事件
     */
    internal func handleViewLocation(friendId: String) {
        
        // 这里可以添加查看位置的具体逻辑
        // 例如：打开地图应用、显示位置信息等
    }
    
    /**
     * 处理删除好友事件（视为取消爱心点亮）
     */
    internal func handleUnfriend(_ friend: MatchRecord) {
        
        // 调用onUnfriend回调，传递到ContentView处理
        onUnfriend(friend)
    }
    
    /**
     * 处理删除消息事件
     */
    internal func deleteMessage(_ message: MessageItem) {
        
        // 从本地消息列表中移除
        existingMessages.removeAll { $0.id == message.id }
        
        // 更新未读消息计数
        unreadCount = calculateUnreadCount()
        // 同时更新新朋友申请数量
        newFriendsCountManager.updateCount(unreadCount)
        
        // 这里可以添加删除消息的具体逻辑
        // 例如：调用API删除服务器端消息等
    }
    
    // MARK: - Message Management Methods
    
    /**
     * 检查用户是否被喜欢
     */
    internal func isUserFavorited(_ userId: String) -> Bool {
        // 这里可以添加检查用户是否被喜欢的具体逻辑
        // 例如：检查本地缓存、查询数据库等
        return false // 简化版本
    }
    
    // MARK: - Data Validation Methods
    
    /**
     * 验证消息数据的有效性
     */
    internal func validateMessageData(_ message: MessageItem) -> Bool {
        // 检查必要字段
        guard !message.senderId.isEmpty,
              !message.content.isEmpty,
              !message.senderName.isEmpty else {
            return false
        }
        
        // 检查时间戳
        guard message.timestamp <= Date() else {
            return false
        }
        
        return true
    }
    
    /**
     * 验证好友数据的有效性
     */
    internal func validateFriendData(_ friend: MatchRecord) -> Bool {
        // 检查必要字段
        guard !friend.user1Id.isEmpty,
              !friend.user2Id.isEmpty,
              !friend.user1Name.isEmpty,
              !friend.user2Name.isEmpty else {
            return false
        }
        
        // 检查用户ID不能相同
        guard friend.user1Id != friend.user2Id else {
            return false
        }
        
        return true
    }
    
    // MARK: - Utility Methods
    
    /**
     * 格式化时间显示
     */
    internal func formatTimeDisplay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /**
     * 格式化相对时间显示
     */
    internal func formatRelativeTime(_ date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 60 {
            return "刚刚"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)分钟前"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)小时前"
        } else {
            // 🎯 修改：超过24小时的都显示"1天前"
            return "1天前"
        }
    }
    
    /**
     * 生成唯一ID
     */
    internal func generateUniqueId() -> String {
        return UUID().uuidString
    }
    
    /**
     * 检查字符串是否为空或只包含空白字符
     */
    internal func isStringEmptyOrWhitespace(_ string: String) -> Bool {
        return string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Debug Methods
    
    // MARK: - Performance Methods
    
    /**
     * 测量方法执行时间
     */
    internal func measureExecutionTime<T>(_ operation: () -> T) -> (result: T, time: TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = operation()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        return (result: result, time: timeElapsed)
    }
    
    /**
     * 异步执行任务
     */
    internal func executeAsync<T>(_ operation: @escaping () -> T, completion: @escaping (T) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = operation()
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    /**
     * 延迟执行任务
     */
    internal func executeAfterDelay(_ delay: TimeInterval, operation: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            operation()
        }
    }
    
    // MARK: - Error Handling Methods
    
    /**
     * 处理错误
     */
    internal func handleError(_ error: Error, context: String) {
        
        // 这里可以添加错误处理的具体逻辑
        // 例如：显示错误提示、记录错误日志等
    }
    
    /**
     * 处理网络错误
     */
    internal func handleNetworkError(_ error: Error) {
        
        // 检查网络连接状态（简化版本）
        // if !NetworkMonitor.shared.isConnected {
        // }
        
        // 这里可以添加网络错误处理的具体逻辑
        // 例如：显示网络错误提示、重试机制等
    }
    
    /**
     * 处理数据错误
     */
    internal func handleDataError(_ error: Error, dataType: String) {
        
        // 这里可以添加数据错误处理的具体逻辑
        // 例如：清理损坏的数据、重新加载数据等
    }
    
    // MARK: - State Management Methods
    
    /**
     * 重置UI状态
     */
    internal func resetUIState() {
        
        isMessagesExpanded = false
        isNewFriendsVisible = false
        // patButtonPressed = false  // 类型不匹配，暂时注释
        patMessagesExpandedStates.removeAll()
        
    }
    
    /**
     * 重置数据状态
     */
    internal func resetDataState() {
        
        existingMessages.removeAll()
        existingPatMessages.removeAll()
        existingFriends.removeAll()
        onlineStatusCache.removeAll()
        unreadCount = 0
        
    }
    
    /**
     * 保存当前状态
     */
    internal func saveCurrentState() {
        
        // 这里可以添加保存状态的具体逻辑
        // 例如：保存到UserDefaults、CoreData等
        
    }
    
    /**
     * 恢复保存的状态
     */
    internal func restoreSavedState() {
        
        // 这里可以添加恢复状态的具体逻辑
        // 例如：从UserDefaults、CoreData等读取状态
        
    }
    
}
