import Foundation

struct TimestampUtils {
    // 🎯 新增：将日期转换到指定时区（类似 toTimeZone）
    // 暂时注释，保留原有逻辑
    /*
    /// 将日期转换到指定时区
    /// - Parameters:
    ///   - date: 原始日期
    ///   - timeZoneIdentifier: 目标时区标识符（如 "Asia/Shanghai"）
    /// - Returns: 转换后的日期
    static func toTimeZone(_ date: Date, timeZoneIdentifier: String) -> Date {
        guard let targetTimeZone = TimeZone(identifier: timeZoneIdentifier) else {
            // 如果时区无效，返回原日期
            return date
        }
        
        // 获取当前时区和目标时区的偏移量差
        let currentOffset = TimeZone.current.secondsFromGMT(for: date)
        let targetOffset = targetTimeZone.secondsFromGMT(for: date)
        let offsetDifference = targetOffset - currentOffset
        
        // 转换日期
        return date.addingTimeInterval(TimeInterval(offsetDifference))
    }
    */
    
    // 🎯 新增：将日期转换为 YYYYMMDD 格式字符串（类似 toYYYYMMDD）
    // 暂时注释，保留原有逻辑
    /*
    /// 将日期转换为 YYYYMMDD 格式字符串，用于按日期分组统计
    /// - Parameters:
    ///   - date: 日期
    ///   - timeZoneIdentifier: 时区标识符（默认为 "Asia/Shanghai"）
    /// - Returns: YYYYMMDD 格式的字符串（如 "20250117"）
    static func toYYYYMMDD(_ date: Date, timeZoneIdentifier: String = "Asia/Shanghai") -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.locale = Locale(identifier: "zh_CN")
        
        if let timeZone = TimeZone(identifier: timeZoneIdentifier) {
            formatter.timeZone = timeZone
        }
        
        return formatter.string(from: date)
    }
    
    /// 从时间戳字符串转换为 YYYYMMDD 格式，用于按日期分组统计
    /// - Parameters:
    ///   - timestamp: 时间戳字符串
    ///   - timeZoneIdentifier: 时区标识符（默认为 "Asia/Shanghai"）
    /// - Returns: YYYYMMDD 格式的字符串（如 "20250117"）
    static func toYYYYMMDD(from timestamp: String, timeZoneIdentifier: String = "Asia/Shanghai") -> String? {
        guard let date = parseTimestamp(timestamp) else {
            return nil
        }
        return toYYYYMMDD(date, timeZoneIdentifier: timeZoneIdentifier)
    }
    
    /// 解析时间戳字符串为 Date（内部辅助方法）
    private static func parseTimestamp(_ timestamp: String) -> Date? {
        let formatters: [DateFormatter] = [
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                formatter.timeZone = nil
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                formatter.timeZone = nil
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
                formatter.timeZone = nil
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                formatter.timeZone = TimeZone(abbreviation: "UTC")
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
                formatter.timeZone = TimeZone(abbreviation: "UTC")
                return formatter
            }()
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: timestamp) {
                return date
            }
        }
        
        return nil
    }
    */
    
    // 格式化时间戳（保留原有逻辑）
    static func formatTimestamp(_ timestamp: String, tzID: String?) -> String {
        
        let formatters: [DateFormatter] = [
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                formatter.timeZone = nil
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                formatter.timeZone = nil
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
                formatter.timeZone = nil
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                formatter.timeZone = TimeZone(abbreviation: "UTC")
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
                formatter.timeZone = TimeZone(abbreviation: "UTC")
                return formatter
            }()
        ]
        
        for (_, formatter) in formatters.enumerated() {
            if let date = formatter.date(from: timestamp) {
                let displayFormatter = DateFormatter()
                displayFormatter.dateFormat = "yyyy-M-d HH:mm"
                displayFormatter.locale = Locale(identifier: "zh_CN")
                displayFormatter.timeZone = nil
                let result = displayFormatter.string(from: date)
                return result
            }
        }
        
        return timestamp
        
        // 🎯 改进版逻辑（已注释，保留原有逻辑）
        /*
        // 🎯 改进：默认使用 Asia/Shanghai（服务器时区）解析，然后转换到目标时区显示
        let serverTimeZone = TimeZone(identifier: "Asia/Shanghai") ?? TimeZone.current
        let targetTimeZone: TimeZone
        
        if let tzID = tzID, let timeZone = TimeZone(identifier: tzID) {
            targetTimeZone = timeZone
        } else {
            // 如果没有指定时区，使用系统时区
            targetTimeZone = TimeZone.current
        }
        
        let formatters: [DateFormatter] = [
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                formatter.timeZone = serverTimeZone
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                formatter.timeZone = serverTimeZone
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
                formatter.timeZone = serverTimeZone
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                formatter.timeZone = TimeZone(abbreviation: "UTC")
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
                formatter.timeZone = TimeZone(abbreviation: "UTC")
                return formatter
            }()
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: timestamp) {
                // 🎯 改进：转换到目标时区显示
                let displayFormatter = DateFormatter()
                displayFormatter.dateFormat = "yyyy-M-d HH:mm"
                displayFormatter.locale = Locale(identifier: "zh_CN")
                displayFormatter.timeZone = targetTimeZone
                return displayFormatter.string(from: date)
            }
        }
        
        return timestamp
        */
    }
    
    // 格式化日期（保留原有逻辑）
    static func formatDate(_ dateString: String, tzID: String?) -> String {
        let localFormatter = DateFormatter()
        localFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        localFormatter.timeZone = nil
        
        if let date = localFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            displayFormatter.timeStyle = .medium
            displayFormatter.locale = Locale(identifier: "zh_CN")
            displayFormatter.timeZone = nil
            return displayFormatter.string(from: date)
        }
        
        let otherFormatters: [DateFormatter] = [
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                formatter.timeZone = nil
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
                formatter.timeZone = nil
                return formatter
            }()
        ]
        
        for formatter in otherFormatters {
            if let date = formatter.date(from: dateString) {
                let displayFormatter = DateFormatter()
                displayFormatter.dateStyle = .short
                displayFormatter.timeStyle = .medium
                displayFormatter.locale = Locale(identifier: "zh_CN")
                displayFormatter.timeZone = nil
                return displayFormatter.string(from: date)
            }
        }
        
        return dateString
        
        // 🎯 改进版逻辑（已注释，保留原有逻辑）
        /*
        // 🎯 改进：默认使用 Asia/Shanghai（服务器时区）解析，然后转换到目标时区显示
        let serverTimeZone = TimeZone(identifier: "Asia/Shanghai") ?? TimeZone.current
        let targetTimeZone: TimeZone
        
        if let tzID = tzID, let timeZone = TimeZone(identifier: tzID) {
            targetTimeZone = timeZone
        } else {
            targetTimeZone = TimeZone.current
        }
        
        let localFormatter = DateFormatter()
        localFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        localFormatter.timeZone = serverTimeZone
        
        if let date = localFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            displayFormatter.timeStyle = .medium
            displayFormatter.locale = Locale(identifier: "zh_CN")
            displayFormatter.timeZone = targetTimeZone
            return displayFormatter.string(from: date)
        }
        
        let otherFormatters: [DateFormatter] = [
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                formatter.timeZone = serverTimeZone
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
                formatter.timeZone = serverTimeZone
                return formatter
            }()
        ]
        
        for formatter in otherFormatters {
            if let date = formatter.date(from: dateString) {
                let displayFormatter = DateFormatter()
                displayFormatter.dateStyle = .short
                displayFormatter.timeStyle = .medium
                displayFormatter.locale = Locale(identifier: "zh_CN")
                displayFormatter.timeZone = targetTimeZone
                return displayFormatter.string(from: date)
            }
        }
        
        return dateString
        */
    }
    
    // 格式化匹配时间（保留原有逻辑）
    static func formatMatchTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = nil
        return formatter.string(from: date)
        
        // 🎯 改进版逻辑（已注释，保留原有逻辑）
        /*
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? TimeZone.current
        return formatter.string(from: date)
        */
    }
    
    // 🎯 新增：按日期分组统计（类似 GROUP BY toYYYYMMDD）
    // 暂时注释，保留原有逻辑
    /*
    /// 按日期分组统计数据
    /// - Parameters:
    ///   - items: 数据项数组
    ///   - dateKeyPath: 获取日期的时间戳字符串的键路径
    ///   - timeZoneIdentifier: 时区标识符（默认为 "Asia/Shanghai"）
    /// - Returns: 按日期分组的字典，key 为 YYYYMMDD 格式的日期字符串
    static func groupByDate<T>(
        _ items: [T],
        dateKeyPath: KeyPath<T, String>,
        timeZoneIdentifier: String = "Asia/Shanghai"
    ) -> [String: [T]] {
        var grouped: [String: [T]] = [:]
        
        for item in items {
            let timestamp = item[keyPath: dateKeyPath]
            if let dateStr = toYYYYMMDD(from: timestamp, timeZoneIdentifier: timeZoneIdentifier) {
                if grouped[dateStr] == nil {
                    grouped[dateStr] = []
                }
                grouped[dateStr]?.append(item)
            }
        }
        
        return grouped
    }
    */
    
    // 🎯 新增：提取最新版本数据（类似 argMax）
    // 暂时注释，保留原有逻辑
    /*
    /// 提取每个键的最新版本数据
    /// - Parameters:
    ///   - items: 数据项数组
    ///   - keyPath: 用于分组的键路径
    ///   - dateKeyPath: 用于比较日期的时间戳字符串的键路径
    /// - Returns: 每个键对应的最新数据项字典
    static func argMax<T>(
        _ items: [T],
        keyPath: KeyPath<T, String>,
        dateKeyPath: KeyPath<T, String>
    ) -> [String: T] {
        var latestByKey: [String: T] = [:]
        
        for item in items {
            let key = item[keyPath: keyPath]
            let timestamp = item[keyPath: dateKeyPath]
            
            guard let date = parseTimestamp(timestamp) else {
                continue
            }
            
            if let existingItem = latestByKey[key],
               let existingDate = parseTimestamp(existingItem[keyPath: dateKeyPath]),
               existingDate >= date {
                // 已有更新的数据，跳过
                continue
            }
            
            latestByKey[key] = item
        }
        
        return latestByKey
    }
    */
}
