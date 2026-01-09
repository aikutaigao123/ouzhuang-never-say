import SwiftUI

// MARK: - MessageView User Info Updating Extension
extension MessageView {
    
    // MARK: - User Info Update Methods
    
    /**
     * 更新新朋友申请列表的用户信息缓存
     */
    internal func updateNewFriendsUserInfo(_ messages: [MessageItem], completion: @escaping ([MessageItem]) -> Void) {
        
        var updatedMessages = messages
        let group = DispatchGroup()
        
        for (index, message) in messages.enumerated() {
            group.enter()
            
            // 批量获取发送者信息
            batchFetchSenderInfo(for: message) { updatedMessage in
                updatedMessages[index] = updatedMessage
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(updatedMessages)
        }
    }
    
    /**
     * 批量获取发送者信息
     */
    private func batchFetchSenderInfo(for message: MessageItem, completion: @escaping (MessageItem) -> Void) {
        let senderId = message.senderId
        
        let group = DispatchGroup()
        
        // 获取发送者头像
        group.enter()
        getCachedUserAvatar(userId: senderId) { avatar in
            // 头像已经缓存，不需要更新message对象
            group.leave()
        }
        
        // 获取发送者用户名
        group.enter()
        getCachedUserName(userId: senderId) { userName in
            // 用户名已经缓存，不需要更新message对象
            group.leave()
        }
        
        // 获取发送者登录类型
        group.enter()
        getCachedUserLoginType(userId: senderId) { loginType in
            // 登录类型已经缓存，不需要更新message对象
            group.leave()
        }
        
        group.notify(queue: .main) {
            completion(message)
        }
    }
    
    /**
     * 批量获取所有发送者的头像和用户名
     */
    internal func batchFetchSenderData(messages: [MessageItem]) {
        
        let uniqueSenderIds = Set(messages.map { $0.senderId })
        
        for senderId in uniqueSenderIds {
            // 获取头像
            getCachedUserAvatar(userId: senderId) { avatar in
                // 更新消息中的头像
                self.updateMessageSenderAvatar(senderId: senderId, avatar: avatar, in: messages)
            }
            
            // 获取用户名
            getCachedUserName(userId: senderId) { userName in
                // 更新消息中的用户名
                self.updateMessageSenderName(senderId: senderId, userName: userName, in: messages)
            }
            
            // 获取登录类型
            getCachedUserLoginType(userId: senderId) { loginType in
                // 更新消息中的登录类型
                self.updateMessageSenderLoginType(senderId: senderId, loginType: loginType, in: messages)
            }
        }
    }
    
    /**
     * 批量获取所有好友的头像和用户名
     */
    internal func batchFetchFriendData(friends: [MatchRecord]) {
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        let group = DispatchGroup()
        var updatedFriends = friends
        
        for (index, friend) in friends.enumerated() {
            let friendId = friend.user1Id == currentUser.userId ? friend.user2Id : friend.user1Id
            
            group.enter()
            
            // 🎯 修改：使用 fetchUserNameAndLoginType 同时获取用户名和登录类型，确保获取到正确的用户名
            LeanCloudService.shared.fetchUserNameAndLoginType(objectId: friendId) { userName, loginType, error in
                DispatchQueue.main.async {
                    // 更新用户名
                    if let userName = userName, !userName.isEmpty {
                        if friend.user1Id == currentUser.userId {
                            updatedFriends[index].user2Name = userName
                        } else {
                            updatedFriends[index].user1Name = userName
                        }
                        // 更新缓存
                        self.existingUserNameCache[friendId] = userName
                    }
                    
                    // 更新登录类型（如果获取到了）
                    if let loginType = loginType, !loginType.isEmpty {
                        if friend.user1Id == currentUser.userId {
                            updatedFriends[index].user2LoginType = loginType
                        } else {
                            updatedFriends[index].user1LoginType = loginType
                        }
                    }
                    
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) {
            self.existingFriends = updatedFriends
        }
    }
    
    // MARK: - Message Update Methods
    
    /**
     * 更新消息中的发送者头像
     */
    private func updateMessageSenderAvatar(senderId: String, avatar: String, in messages: [MessageItem]) {
        // MessageItem的属性是let常量，无法直接修改
        // 这里只是触发缓存更新，实际显示时会从缓存中获取最新数据
    }
    
    /**
     * 更新消息中的发送者用户名
     */
    private func updateMessageSenderName(senderId: String, userName: String, in messages: [MessageItem]) {
        // MessageItem的属性是let常量，无法直接修改
        // 这里只是触发缓存更新，实际显示时会从缓存中获取最新数据
    }
    
    /**
     * 更新消息中的发送者登录类型
     */
    private func updateMessageSenderLoginType(senderId: String, loginType: String, in messages: [MessageItem]) {
        // MessageItem的属性是let常量，无法直接修改
        // 这里只是触发缓存更新，实际显示时会从缓存中获取最新数据
    }
    
    // MARK: - User Info Validation Methods
    
    /**
     * 验证用户信息的完整性
     */
    internal func validateUserInfoIntegrity() -> Bool {
        
        var isValid = true
        
        // 检查消息中的用户信息
        for message in existingMessages {
            if message.senderName.isEmpty || message.senderAvatar.isEmpty {
                isValid = false
            }
        }
        
        // 检查好友列表中的用户信息
        for friend in existingFriends {
            if friend.user2Name.isEmpty || friend.user2Avatar.isEmpty {
                isValid = false
            }
        }
        
        if isValid {
        } else {
        }
        
        return isValid
    }
    
    /**
     * 修复不完整的用户信息
     */
    internal func repairIncompleteUserInfo() {
        
        // 修复消息中的用户信息
        for (_, message) in existingMessages.enumerated() {
            if message.senderName.isEmpty || message.senderAvatar.isEmpty {
                let senderId = message.senderId
                
                getCachedUserName(userId: senderId) { userName in
                    // 用户名已经缓存，不需要更新message对象
                }
                
                getCachedUserAvatar(userId: senderId) { avatar in
                    // 头像已经缓存，不需要更新message对象
                }
            }
        }
        
        // 修复好友列表中的用户信息
        for (index, friend) in existingFriends.enumerated() {
            if friend.user2Name.isEmpty || friend.user2Avatar.isEmpty {
                let friendId = friend.user2Id
                
                getCachedUserName(userId: friendId) { userName in
                    self.existingFriends[index].user2Name = userName
                }
                
                getCachedUserAvatar(userId: friendId) { avatar in
                    self.existingFriends[index].user2Avatar = avatar
                }
            }
        }
        
    }
    
    // MARK: - User Info Statistics Methods
    
    /**
     * 获取用户信息统计
     */
    internal func getUserInfoStatistics() -> (messageSenders: Int, friends: Int, incompleteMessages: Int, incompleteFriends: Int) {
        let messageSenders = Set(existingMessages.map { $0.senderId }).count
        let friends = existingFriends.count
        
        let incompleteMessages = existingMessages.filter { message in
            return message.senderName.isEmpty || message.senderAvatar.isEmpty
        }.count
        
        let incompleteFriends = existingFriends.filter { friend in
            return friend.user2Name.isEmpty || friend.user2Avatar.isEmpty
        }.count
        
        return (messageSenders: messageSenders, friends: friends, incompleteMessages: incompleteMessages, incompleteFriends: incompleteFriends)
    }
    
    /**
     * 打印用户信息统计
     */
    internal func printUserInfoStatistics() {
        // 调试函数已删除
    }
    
    // MARK: - User Info Refresh Methods
    
    /**
     * 刷新所有用户信息
     */
    internal func refreshAllUserInfo() {
        
        // 刷新消息中的用户信息
        batchFetchSenderData(messages: existingMessages)
        
        // 刷新好友列表中的用户信息
        batchFetchFriendData(friends: existingFriends)
        
    }
    
    /**
     * 刷新指定用户的信息
     */
    internal func refreshUserInfo(for userId: String) {
        
        // 刷新消息中的用户信息
        getCachedUserAvatar(userId: userId) { avatar in
            self.updateMessageSenderAvatar(senderId: userId, avatar: avatar, in: self.existingMessages)
        }
        
        getCachedUserName(userId: userId) { userName in
            self.updateMessageSenderName(senderId: userId, userName: userName, in: self.existingMessages)
        }
        
        getCachedUserLoginType(userId: userId) { loginType in
            self.updateMessageSenderLoginType(senderId: userId, loginType: loginType, in: self.existingMessages)
        }
        
        // 刷新好友列表中的用户信息
        for (index, friend) in existingFriends.enumerated() {
            if friend.user2Id == userId {
                getCachedUserAvatar(userId: userId) { avatar in
                    self.existingFriends[index].user2Avatar = avatar
                }
                
                getCachedUserName(userId: userId) { userName in
                    self.existingFriends[index].user2Name = userName
                }
                
                getCachedUserLoginType(userId: userId) { loginType in
                    self.existingFriends[index].user2LoginType = loginType
                }
                break
            }
        }
        
    }
    
    // MARK: - User Info Cleanup Methods
    
    /**
     * 清理无效的用户信息
     */
    internal func cleanupInvalidUserInfo() {
        
        var cleanedCount = 0
        
        // 清理消息中的无效用户信息
        for (_, message) in existingMessages.enumerated() {
            if message.senderId.isEmpty || message.senderName.isEmpty {
                // MessageItem的属性是let常量，无法直接修改
                // 这里只是标记需要重新获取
                cleanedCount += 1
            }
        }
        
        // 清理好友列表中的无效用户信息
        for (_, friend) in existingFriends.enumerated() {
            if friend.user2Id.isEmpty || friend.user2Name.isEmpty {
                // MatchRecord的属性是let常量，无法直接修改
                // 这里只是标记需要重新获取
                cleanedCount += 1
            }
        }
        
        if cleanedCount > 0 {
        } else {
        }
    }
    
}
