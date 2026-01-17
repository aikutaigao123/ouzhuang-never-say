import SwiftUI

extension MessageView {
    // MARK: - Utility Methods
    
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



