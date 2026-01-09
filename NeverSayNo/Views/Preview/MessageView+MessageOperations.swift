import SwiftUI

extension MessageView {
    // MARK: - Message Operations Methods
    
    // 加载模拟消息（当LeanCloud加载失败时使用）
    private func loadMockMessages() {
        // 不显示任何模拟消息，只显示真实消息
        existingMessages = []
        // 不要重置unreadCount，保持之前的值，避免影响主界面的newFriendsCount
        // unreadCount = 0
    }
    
    // 标记单条消息为已读
    private func markMessageAsRead(_ message: MessageItem) {
        // 更新本地消息状态
        if let index = existingMessages.firstIndex(where: { $0.id == message.id }) {
            existingMessages[index].isRead = true
        }
        
        // 更新未读消息计数 - 同步到主界面
        let newUnreadCount = calculateUnreadCount()
        
        // 计算新的朋友申请数量（统计所有未读的相关消息，排除拍一拍消息）
        let newFriendsCount = existingMessages.filter { message in
            // 检查是否为相关消息类型
            let isRelevantMessage = message.content.contains("对你发送了好友申请") ||
                                   message.content.contains("已同意") ||
                                   message.content.contains("已拒绝") ||
                                   message.content.contains("撤销好友申请")
            
            // 排除拍一拍消息
            let isNotPatMessage = !message.content.contains("拍了拍你") && 
                                 message.messageType != "pat"
            
            let isUnread = !message.isRead
            return isRelevantMessage && isNotPatMessage && isUnread
        }.count
        
        DispatchQueue.main.async {
            self.unreadCount = newUnreadCount
            // 更新新朋友申请数量（使用专门的计算逻辑）
            self.newFriendsCountManager.updateCount(newFriendsCount)
        }
        
        // 异步更新服务器状态
        if let objectId = message.objectId {
            LeanCloudService.shared.markMessageAsRead(messageId: objectId) { _ in
                // 忽略服务器响应，本地状态已经更新
            }
        }
    }
}



