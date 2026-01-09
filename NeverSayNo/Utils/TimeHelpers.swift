import SwiftUI
import Foundation

struct TimeHelpers {
    // 格式化时间显示
    static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    // 格式化日期显示
    static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    // 格式化日期时间显示
    static func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
    
    // 获取相对时间描述
    static func getRelativeTimeDescription(_ date: Date) -> String {
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
            let days = Int(timeInterval / 86400)
            return "\(days)天前"
        }
    }
    
    // 检查是否为今天
    static func isToday(_ date: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDateInToday(date)
    }
    
    // 检查是否为昨天
    static func isYesterday(_ date: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDateInYesterday(date)
    }
    
    // 获取时区偏移描述
    static func getTimezoneOffsetDescription(_ timezone: TimeZone) -> String {
        let offset = timezone.secondsFromGMT()
        let hours = offset / 3600
        let minutes = abs(offset % 3600) / 60
        
        if hours >= 0 {
            return String(format: "UTC+%d:%02d", hours, minutes)
        } else {
            return String(format: "UTC%d:%02d", hours, minutes)
        }
    }
    
    // 验证时间戳是否有效
    static func isValidTimestamp(_ timestamp: TimeInterval) -> Bool {
        let date = Date(timeIntervalSince1970: timestamp)
        let now = Date()
        let year = Calendar.current.component(.year, from: date)
        return year >= 2020 && year <= Calendar.current.component(.year, from: now) + 1
    }
}
