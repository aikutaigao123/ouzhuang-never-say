import SwiftUI

extension MessageView {
    // MARK: - Utility and Debug Methods
    
    // 检查匹配成功UI显示与好友数量的一致性
    private func checkMatchStatusConsistency() {
        // 计算匹配成功的消息数量
        let matchSuccessCount = existingMessages.filter { $0.isMatch }.count
        
        // 计算实际的好友数量（基于双向喜欢关系）
        var actualFriendCount = 0
        for favoriteRecord in favoriteRecords {
            let targetUserId = favoriteRecord.favoriteUserId
            let currentUserLikesTarget = isUserFavorited(targetUserId)
            let targetLikesCurrentUser = isUserFavoritedByMe(targetUserId)
            
            if currentUserLikesTarget && targetLikesCurrentUser {
                actualFriendCount += 1
            }
        }
        
        // 如果不一致，打印详细信息
        if matchSuccessCount != actualFriendCount {
            // 一致性检查逻辑已移除
        }
    }
    
    // 使用实际好友数量检查一致性
    private func checkMatchStatusConsistencyWithActualCount(_ actualFriendCount: Int) {
        // 计算匹配成功的消息数量
        let matchSuccessCount = existingMessages.filter { $0.isMatch }.count
        
        // 如果不一致，打印详细信息
        if matchSuccessCount != actualFriendCount {
            // 一致性检查逻辑已移除
        }
    }
    
    // 打印所有本地在线状态缓存
    private func printAllLocalOnlineStatusCache() {
        
        if onlineStatusCache.isEmpty {
            return
        }
        
        for (_, _) in onlineStatusCache {
        }
    }
    
    // 收到拍一拍消息时打印好友列表
    private func printFriendsListOnPatMessage() {
        
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        
        if existingFriends.isEmpty {
            return
        }
        
        for (_, friend) in existingFriends.enumerated() {
            // 获取好友信息（非当前用户）
            // 计算该好友的拍一拍消息数量
            let friendId = friend.user1Id == currentUser.id ? friend.user2Id : friend.user1Id
            _ = existingPatMessages.filter { message in
                (message.senderId == friendId && message.receiverId == currentUser.id) ||
                (message.senderId == currentUser.id && message.receiverId == friendId)
            }
            
        }
    }
    
    // 根据用户ID获取用户名
    private func getUserNameById(_ userId: String) -> String? {
        return existingUserNameCache[userId]
    }
    
    // 获取指定用户的消息
    private func getMessagesForUser(_ userId: String) -> [MessageItem] {
        // 合并所有消息数据
        let allMessages = existingMessages + existingPatMessages
        return allMessages.filter { message in
            // 检查消息是否与当前用户和指定用户相关
            let isFromCurrentUser = message.senderId == userManager.currentUser?.id
            let isToCurrentUser = message.receiverId == userManager.currentUser?.id
            let isFromFriend = message.senderId == userId
            let isToFriend = message.receiverId == userId
            
            // 消息必须涉及当前用户和指定好友
            return (isFromCurrentUser && isToFriend) || (isFromFriend && isToCurrentUser)
        }
    }
}



