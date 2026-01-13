import SwiftUI

extension MessageView {
    // MARK: - Message Data Refresh Methods
    
    /// 🔧 修复数据同步问题：强制刷新消息数据
    internal func refreshMessageData() {
        
        // 直接重新加载消息数据，避免多次缓存操作导致数据源地址变化
        self.reloadMessageData()
    }
    
    /// 重新加载消息数据
    private func reloadMessageData() {
        
        // 从LeanCloud服务获取最新的消息数据
        let currentUserId = userManager.currentUser?.id ?? ""
        LeanCloudService.shared.fetchMessages(userId: currentUserId) { messages, error in
            DispatchQueue.main.async {
                if let messages = messages {
                    
                    // 处理消息数据，确保数据一致性
                    self.processLoadedMessages(messages)
                } else {
                }
            }
        }
    }
}



