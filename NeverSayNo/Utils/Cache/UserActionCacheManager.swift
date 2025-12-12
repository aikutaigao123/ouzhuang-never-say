import Foundation

// MARK: - 用户操作缓存管理器
// 防止用户通过频繁点赞/取消来刷排行榜数据
class UserActionCacheManager {
    
    // 单例模式
    static let shared = UserActionCacheManager()
    
    // 操作类型枚举
    enum ActionType: String, CaseIterable, Codable {
        case like = "like"           // 点赞
        case favorite = "favorite"   // 爱心
        case unlike = "unlike"       // 取消点赞
        case unfavorite = "unfavorite" // 取消爱心
    }
    
    // 操作记录结构
    struct ActionRecord: Codable {
        let targetUserId: String     // 目标用户ID
        let actionType: ActionType   // 操作类型
        let timestamp: Date          // 操作时间
        let isProcessed: Bool        // 是否已处理（上传到服务器）
        
        init(targetUserId: String, actionType: ActionType, isProcessed: Bool = false) {
            self.targetUserId = targetUserId
            self.actionType = actionType
            self.timestamp = Date()
            self.isProcessed = isProcessed
        }
    }
    
    // 缓存配置
    private struct CacheConfig {
        static let maxCacheSize = 1000        // 最大缓存记录数
        static let cacheExpirationHours = 24  // 缓存过期时间（小时）
        static let duplicateActionThreshold = 0.1 // 重复操作阈值（秒）
    }
    
    // 内存缓存
    private var actionCache: [String: [ActionRecord]] = [:]
    private let cacheQueue = DispatchQueue(label: "com.neversayno.actioncache", attributes: .concurrent)
    
    private init() {
        loadCacheFromDisk()
        // 注释掉自动清理定时器，改为在更新时手动清理
        // startCleanupTimer()
    }
    
    // MARK: - 缓存操作
    
    /// 检查是否可以执行操作（防刷机制）
    /// - Parameters:
    ///   - targetUserId: 目标用户ID
    ///   - actionType: 操作类型
    ///   - currentUserId: 当前用户ID
    /// - Returns: 是否可以执行操作
    func canPerformAction(targetUserId: String, actionType: ActionType, currentUserId: String) -> Bool {
        return cacheQueue.sync {
            let cacheKey = getCacheKey(currentUserId: currentUserId, targetUserId: targetUserId)
            let records = actionCache[cacheKey] ?? []
            
            // 检查是否有重复操作
            let now = Date()
            let threshold = CacheConfig.duplicateActionThreshold
            
            // 查找最近的相同操作
            let recentSameAction = records.last { record in
                record.actionType == actionType &&
                now.timeIntervalSince(record.timestamp) < Double(threshold)
            }
            
            if let recentAction = recentSameAction {
                // 检测到重复操作
                let _ = now.timeIntervalSince(recentAction.timestamp)
                return false
            }
            
            return true
        }
    }
    
    /// 记录操作到缓存
    /// - Parameters:
    ///   - targetUserId: 目标用户ID
    ///   - actionType: 操作类型
    ///   - currentUserId: 当前用户ID
    ///   - isProcessed: 是否已处理
    func recordAction(targetUserId: String, actionType: ActionType, currentUserId: String, isProcessed: Bool = false) {
        cacheQueue.async(flags: .barrier) {
            let cacheKey = self.getCacheKey(currentUserId: currentUserId, targetUserId: targetUserId)
            let record = ActionRecord(targetUserId: targetUserId, actionType: actionType, isProcessed: isProcessed)
            
            if self.actionCache[cacheKey] == nil {
                self.actionCache[cacheKey] = []
            }
            
            self.actionCache[cacheKey]?.append(record)
            
            // 限制缓存大小
            if let records = self.actionCache[cacheKey], records.count > CacheConfig.maxCacheSize {
                self.actionCache[cacheKey] = Array(records.suffix(CacheConfig.maxCacheSize))
            }
            
            // 记录操作
            let _ = self.actionCache[cacheKey]?.count ?? 0
            
            // 保存到磁盘
            self.saveCacheToDisk()
        }
    }
    
    /// 标记操作为已处理
    /// - Parameters:
    ///   - targetUserId: 目标用户ID
    ///   - actionType: 操作类型
    ///   - currentUserId: 当前用户ID
    func markActionAsProcessed(targetUserId: String, actionType: ActionType, currentUserId: String) {
        cacheQueue.async(flags: .barrier) {
            let cacheKey = self.getCacheKey(currentUserId: currentUserId, targetUserId: targetUserId)
            
            if let records = self.actionCache[cacheKey] {
                // 找到最新的未处理记录并标记为已处理
                for i in stride(from: records.count - 1, through: 0, by: -1) {
                    if records[i].actionType == actionType && !records[i].isProcessed {
                        self.actionCache[cacheKey]?[i] = ActionRecord(
                            targetUserId: targetUserId,
                            actionType: actionType,
                            isProcessed: true
                        )
                        // 标记操作已处理
                        break
                    }
                }
            }
            
            self.saveCacheToDisk()
        }
    }
    
    /// 获取用户的操作历史
    /// - Parameters:
    ///   - currentUserId: 当前用户ID
    ///   - targetUserId: 目标用户ID
    /// - Returns: 操作记录数组
    func getActionHistory(currentUserId: String, targetUserId: String) -> [ActionRecord] {
        return cacheQueue.sync {
            let cacheKey = getCacheKey(currentUserId: currentUserId, targetUserId: targetUserId)
            return actionCache[cacheKey] ?? []
        }
    }
    
    /// 获取用户的操作统计
    /// - Parameters:
    ///   - currentUserId: 当前用户ID
    ///   - targetUserId: 目标用户ID
    /// - Returns: 操作统计字典
    func getActionStats(currentUserId: String, targetUserId: String) -> [ActionType: Int] {
        let history = getActionHistory(currentUserId: currentUserId, targetUserId: targetUserId)
        var stats: [ActionType: Int] = [:]
        
        for actionType in ActionType.allCases {
            stats[actionType] = history.filter { $0.actionType == actionType }.count
        }
        
        return stats
    }
    
    // MARK: - 缓存管理
    
    /// 清理过期缓存
    func cleanupExpiredCache() {
        cacheQueue.async(flags: .barrier) {
            let expirationDate = Date().addingTimeInterval(-Double(CacheConfig.cacheExpirationHours * 3600))
            var hasChanges = false
            
            for (key, records) in self.actionCache {
                let validRecords = records.filter { $0.timestamp > expirationDate }
                if validRecords.count != records.count {
                    self.actionCache[key] = validRecords
                    hasChanges = true
                }
            }
            
            // 清理空的缓存项
            self.actionCache = self.actionCache.filter { !$0.value.isEmpty }
            
            if hasChanges {
                // 清理过期缓存完成
                self.saveCacheToDisk()
            }
        }
    }
    
    /// 清空所有缓存
    func clearAllCache() {
        cacheQueue.async(flags: .barrier) {
            self.actionCache.removeAll()
            self.saveCacheToDisk()
            // 清空所有操作缓存
        }
    }
    
    /// 清空指定用户的缓存
    /// - Parameter currentUserId: 当前用户ID
    func clearUserCache(currentUserId: String) {
        cacheQueue.async(flags: .barrier) {
            let keysToRemove = self.actionCache.keys.filter { $0.hasPrefix("\(currentUserId)_") }
            for key in keysToRemove {
                self.actionCache.removeValue(forKey: key)
            }
            self.saveCacheToDisk()
            // 清空用户操作缓存
        }
    }
    
    // MARK: - 私有方法
    
    /// 获取缓存键
    private func getCacheKey(currentUserId: String, targetUserId: String) -> String {
        return "\(currentUserId)_\(targetUserId)"
    }
    
    /// 从磁盘加载缓存
    private func loadCacheFromDisk() {
        if let data = UserDefaults.standard.data(forKey: "UserActionCache"),
           let cache = try? JSONDecoder().decode([String: [ActionRecord]].self, from: data) {
            actionCache = cache
            // 从磁盘加载操作缓存
        }
    }
    
    /// 保存缓存到磁盘
    private func saveCacheToDisk() {
        if let data = try? JSONEncoder().encode(actionCache) {
            UserDefaults.standard.set(data, forKey: "UserActionCache")
        }
    }
    
    /// 启动清理定时器 - 已禁用，改为在更新时手动清理
    private func startCleanupTimer() {
        // 注释掉自动定时清理，改为在数据更新时手动清理
        // Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
        //     self.cleanupExpiredCache()
        // }
    }
    
    /// 在数据更新完成后清理过期缓存
    func cleanupCacheAfterUpdate() {
        cleanupExpiredCache()
    }
}

// MARK: - 扩展方法

extension UserActionCacheManager {
    
    /// 检查是否可以点赞
    func canLike(targetUserId: String, currentUserId: String) -> Bool {
        return canPerformAction(targetUserId: targetUserId, actionType: .like, currentUserId: currentUserId)
    }
    
    /// 检查是否可以取消点赞
    func canUnlike(targetUserId: String, currentUserId: String) -> Bool {
        return canPerformAction(targetUserId: targetUserId, actionType: .unlike, currentUserId: currentUserId)
    }
    
    /// 检查是否可以爱心
    func canFavorite(targetUserId: String, currentUserId: String) -> Bool {
        return canPerformAction(targetUserId: targetUserId, actionType: .favorite, currentUserId: currentUserId)
    }
    
    /// 检查是否可以取消爱心
    func canUnfavorite(targetUserId: String, currentUserId: String) -> Bool {
        return canPerformAction(targetUserId: targetUserId, actionType: .unfavorite, currentUserId: currentUserId)
    }
    
    /// 记录点赞操作
    func recordLike(targetUserId: String, currentUserId: String, isProcessed: Bool = false) {
        recordAction(targetUserId: targetUserId, actionType: .like, currentUserId: currentUserId, isProcessed: isProcessed)
    }
    
    /// 记录取消点赞操作
    func recordUnlike(targetUserId: String, currentUserId: String, isProcessed: Bool = false) {
        recordAction(targetUserId: targetUserId, actionType: .unlike, currentUserId: currentUserId, isProcessed: isProcessed)
    }
    
    /// 记录爱心操作
    func recordFavorite(targetUserId: String, currentUserId: String, isProcessed: Bool = false) {
        recordAction(targetUserId: targetUserId, actionType: .favorite, currentUserId: currentUserId, isProcessed: isProcessed)
    }
    
    /// 记录取消爱心操作
    func recordUnfavorite(targetUserId: String, currentUserId: String, isProcessed: Bool = false) {
        recordAction(targetUserId: targetUserId, actionType: .unfavorite, currentUserId: currentUserId, isProcessed: isProcessed)
    }
}
