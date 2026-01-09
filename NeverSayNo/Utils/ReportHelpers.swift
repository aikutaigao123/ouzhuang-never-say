import SwiftUI
import Foundation

struct ReportHelpers {
    // 检查用户是否已被举报
    static func hasReportedUser(_ userId: String, reportRecords: [ReportRecord]) -> Bool {
        return reportRecords.contains { $0.reportedUserId == userId }
    }
    
    // 计算好友申请数量
    static func calculateFriendRequestCount(
        from messages: [MessageItem],
        isUserFavorited: (String) -> Bool
    ) -> Int {
        let filteredMessages = messages.filter { message in
            // 如果消息已读，则不计入未读
            if message.isRead {
                return false
            }
            
            // 如果爱心已点亮，则视为已读，不计入未读
            if isUserFavorited(message.senderId) {
                return false
            }
            
            // 只计算好友申请消息
            return message.content.contains("对你发送了好友申请")
        }
        
        return filteredMessages.count
    }
    
    // 计算爱心数量
    static func calculateFavoriteCount(for userId: String) -> Int {
        // 这里需要从LeanCloud查询目标用户收到的爱心数量
        // 暂时返回0，实际应该异步查询
        return 0
    }
}
