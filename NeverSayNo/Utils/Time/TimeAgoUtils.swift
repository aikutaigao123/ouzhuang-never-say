import Foundation

struct TimeAgoUtils {
    // 格式化时间为"多少分钟之前"的格式
    static func formatTimeAgo(from date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        let minutes = Int(timeInterval / 60)
        let hours = Int(timeInterval / 3600)
        let days = Int(timeInterval / 86400)
        
        let result: String
        if minutes < 1 {
            result = "刚刚"
        } else if minutes < 60 {
            result = "\(minutes)分钟前"
        } else if hours < 24 {
            result = "\(hours)小时前"
        } else if days < 7 {
            result = "\(days)天前"
        } else {
            // 超过7天的都显示"7天前"
            result = "7天前"
        }
        
        return result
    }
    
    // 格式化时间戳（用于消息）
    static func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 60 {
            return "刚刚"
        } else if timeInterval < 3600 {
            return "\(Int(timeInterval / 60))分钟前"
        } else if timeInterval < 86400 {
            return "\(Int(timeInterval / 3600))小时前"
        } else {
            formatter.dateFormat = "MM-dd HH:mm"
            return formatter.string(from: date)
        }
    }
}
