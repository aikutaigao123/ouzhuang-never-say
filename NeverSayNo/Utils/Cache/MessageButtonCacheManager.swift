//
//  MessageButtonCacheManager.swift
//  NeverSayNo
//
//  Created by Assistant on 2024-12-19.
//  Copyright © 2024. All rights reserved.
//

import Foundation

// MARK: - 消息按钮缓存管理器
class MessageButtonCacheManager {
    
    // 单例模式
    static let shared = MessageButtonCacheManager()
    
    // 缓存键名（按用户隔离）
    private struct CacheKeys {
        static func locationRecords(userId: String) -> String { "MessageButtonCache_LocationRecords_\(userId)" }
        static func loginRecords(userId: String) -> String { "MessageButtonCache_LoginRecords_\(userId)" }
        static func internalLoginRecords(userId: String) -> String { "MessageButtonCache_InternalLoginRecords_\(userId)" }
        static func userNameRecords(userId: String) -> String { "MessageButtonCache_UserNameRecords_\(userId)" }
        static func userAvatarRecords(userId: String) -> String { "MessageButtonCache_UserAvatarRecords_\(userId)" }
        static func lastUpdateTime(userId: String) -> String { "MessageButtonCache_LastUpdateTime_\(userId)" }
    }
    
    // 🎯 新增：获取当前用户ID
    private func getCurrentUserId() -> String? {
        return UserDefaultsManager.getCurrentUserId()
    }
    
    // 缓存过期时间（5分钟）
    private let cacheExpirationInterval: TimeInterval = 300
    
    // 重试配置
    private let maxRetryAttempts = 3
    private let retryDelay: TimeInterval = 2.0
    
    private init() {}
    
    // MARK: - 缓存操作方法
    
    /// 缓存位置记录
    func cacheLocationRecords(_ records: [LocationRecord]) {
        guard let userId = getCurrentUserId() else { return }
        do {
            let data = try JSONEncoder().encode(records)
            UserDefaults.standard.set(data, forKey: CacheKeys.locationRecords(userId: userId))
            updateLastCacheTime(userId: userId)
        } catch {
        }
    }
    
    /// 缓存登录记录
    func cacheLoginRecords(_ records: [LoginRecord]) {
        guard let userId = getCurrentUserId() else { return }
        do {
            let data = try JSONEncoder().encode(records)
            UserDefaults.standard.set(data, forKey: CacheKeys.loginRecords(userId: userId))
            updateLastCacheTime(userId: userId)
        } catch {
        }
    }
    
    /// 缓存内部登录记录
    func cacheInternalLoginRecords(_ records: [InternalLoginRecord]) {
        guard let userId = getCurrentUserId() else { return }
        do {
            let data = try JSONEncoder().encode(records)
            UserDefaults.standard.set(data, forKey: CacheKeys.internalLoginRecords(userId: userId))
            updateLastCacheTime(userId: userId)
        } catch {
        }
    }
    
    /// 缓存用户名记录
    func cacheUserNameRecords(_ records: [[String: Any]]) {
        guard let userId = getCurrentUserId() else { return }
        do {
            let data = try JSONSerialization.data(withJSONObject: records)
            UserDefaults.standard.set(data, forKey: CacheKeys.userNameRecords(userId: userId))
            updateLastCacheTime(userId: userId)
        } catch {
        }
    }
    
    /// 缓存用户头像记录
    func cacheUserAvatarRecords(_ records: [[String: Any]]) {
        guard let userId = getCurrentUserId() else { return }
        do {
            let data = try JSONSerialization.data(withJSONObject: records)
            UserDefaults.standard.set(data, forKey: CacheKeys.userAvatarRecords(userId: userId))
            updateLastCacheTime(userId: userId)
        } catch {
        }
    }
    
    // MARK: - 读取缓存方法
    
    /// 读取缓存的位置记录
    func getCachedLocationRecords() -> [LocationRecord]? {
        guard let userId = getCurrentUserId() else { return nil }
        guard let data = UserDefaults.standard.data(forKey: CacheKeys.locationRecords(userId: userId)),
              !isCacheExpired(userId: userId) else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode([LocationRecord].self, from: data)
        } catch {
            return nil
        }
    }
    
    /// 读取缓存的登录记录
    func getCachedLoginRecords() -> [LoginRecord]? {
        guard let userId = getCurrentUserId() else { return nil }
        guard let data = UserDefaults.standard.data(forKey: CacheKeys.loginRecords(userId: userId)),
              !isCacheExpired(userId: userId) else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode([LoginRecord].self, from: data)
        } catch {
            return nil
        }
    }
    
    /// 读取缓存的内部登录记录
    func getCachedInternalLoginRecords() -> [InternalLoginRecord]? {
        guard let userId = getCurrentUserId() else { return nil }
        guard let data = UserDefaults.standard.data(forKey: CacheKeys.internalLoginRecords(userId: userId)),
              !isCacheExpired(userId: userId) else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode([InternalLoginRecord].self, from: data)
        } catch {
            return nil
        }
    }
    
    /// 读取缓存的用户名记录
    func getCachedUserNameRecords() -> [[String: Any]]? {
        guard let userId = getCurrentUserId() else { return nil }
        guard let data = UserDefaults.standard.data(forKey: CacheKeys.userNameRecords(userId: userId)),
              !isCacheExpired(userId: userId) else {
            return nil
        }
        
        do {
            if let records = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                return records
            }
        } catch {
        }
        
        return nil
    }
    
    /// 读取缓存的用户头像记录
    func getCachedUserAvatarRecords() -> [[String: Any]]? {
        guard let userId = getCurrentUserId() else { return nil }
        guard let data = UserDefaults.standard.data(forKey: CacheKeys.userAvatarRecords(userId: userId)),
              !isCacheExpired(userId: userId) else {
            return nil
        }
        
        do {
            if let records = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                return records
            }
        } catch {
        }
        
        return nil
    }
    
    // MARK: - 批量更新缓存
    
    /// 更新所有表的缓存 - 参考Manager 3的实现方式
    func updateAllCaches(completion: @escaping (Bool, String?) -> Void) {
        
        // 首先尝试获取所有可用的数据表（智能发现机制）
        fetchAllAvailableClasses { classes, error in
            if error != nil {
                self.updateCachesWithPredefinedClasses(completion: completion)
                return
            }
            
            guard let classes = classes else {
                self.updateCachesWithPredefinedClasses(completion: completion)
                return
            }
            
            // 过滤出我们关心的数据表
            let targetClasses = ["UserNameRecord", "UserAvatarRecord"]
            let availableClasses = classes.filter { targetClasses.contains($0) }
            
            self.updateCachesWithClasses(classes: availableClasses, completion: completion)
        }
    }
    
    /// 使用预定义的数据表列表更新缓存
    private func updateCachesWithPredefinedClasses(completion: @escaping (Bool, String?) -> Void) {
        let predefinedClasses = ["UserNameRecord", "UserAvatarRecord"]
        updateCachesWithClasses(classes: predefinedClasses, completion: completion)
    }
    
    /// 使用指定的数据表列表更新缓存
    private func updateCachesWithClasses(classes: [String], completion: @escaping (Bool, String?) -> Void) {
        // 定义需要缓存的数据表列表 - 只包含UserNameRecord和UserAvatarRecord
        let cacheClasses = [
            "UserNameRecord": { (completion: @escaping (Bool, Int) -> Void) in
                LeanCloudService.shared.fetchAllUserNameRecords { records, error in
                    if let records = records {
                        self.cacheUserNameRecords(records)
                        completion(true, records.count)
                    } else {
                        completion(false, 0)
                    }
                }
            },
            "UserAvatarRecord": { (completion: @escaping (Bool, Int) -> Void) in
                LeanCloudService.shared.fetchAllUserAvatarRecords { records, error in
                    if let records = records {
                        self.cacheUserAvatarRecords(records)
                        completion(true, records.count)
                    } else {
                        completion(false, 0)
                    }
                }
            }
        ]
        
        var cacheResults: [String: (success: Bool, count: Int)] = [:]
        let group = DispatchGroup()
        var completedCount = 0
        let _ = cacheClasses.count
        
        // 获取需要缓存的表名列表
        let classNames = Array(cacheClasses.keys)
        
        // 使用非递归的方式处理请求
        for (index, className) in classNames.enumerated() {
            group.enter()
            
            // 为每个请求添加延迟
            let delay = Double(index) * (1.0/17.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                // 确保每个请求只调用一次group.leave()
                defer {
                    group.leave()
                }
                
                self.fetchWithRetry(className: className, cacheClasses: cacheClasses, attempt: 1) { success, count in
                    cacheResults[className] = (success: success, count: count)
                    completedCount += 1
                    
                    if success {
                    } else {
                    }
                }
            }
        }
        
        // 等待所有请求完成
        group.notify(queue: .main) {
            // 在缓存更新完成后清理过期缓存
            LeanCloudService.shared.cleanupCacheAfterUpdate()
            UserActionCacheManager.shared.cleanupCacheAfterUpdate()
            
            self.generateCacheReport(results: cacheResults, completion: completion)
        }
    }
    
    /// 获取所有可用的数据表类名 - 参考Manager 3的实现
    private func fetchAllAvailableClasses(completion: @escaping ([String]?, String?) -> Void) {
        let urlString = "\(LeanCloudService.shared.serverUrl)/1.1/schemas"
        
        guard let url = URL(string: urlString) else {
            completion(nil, "无效的URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        LeanCloudService.shared.setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(nil, "网络错误: \(error.localizedDescription)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(nil, "无效的响应")
                return
            }
            
            if httpResponse.statusCode == 200 {
                guard let data = data else {
                    completion(nil, "无数据返回")
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let classes = json["classes"] as? [[String: Any]] {
                        let classNames = classes.compactMap { $0["className"] as? String }
                        completion(classNames, nil)
                    } else {
                        completion(nil, "数据格式错误")
                    }
                } catch {
                    completion(nil, "数据解析错误: \(error.localizedDescription)")
                }
            } else {
                completion(nil, "服务器错误: \(httpResponse.statusCode)")
            }
        }.resume()
    }
    
    /// 带重试机制的数据获取方法
    private func fetchWithRetry(className: String, cacheClasses: [String: (@escaping (Bool, Int) -> Void) -> Void], attempt: Int, completion: @escaping (Bool, Int) -> Void) {
        
        cacheClasses[className]! { success, count in
            if success {
                // 成功时调用completion
                completion(true, count)
            } else if attempt < self.maxRetryAttempts {
                // 重试时递归调用，不调用completion
                DispatchQueue.main.asyncAfter(deadline: .now() + self.retryDelay) {
                    self.fetchWithRetry(className: className, cacheClasses: cacheClasses, attempt: attempt + 1, completion: completion)
                }
            } else {
                // 重试失败，调用completion
                completion(false, 0)
            }
        }
    }
    
    /// 生成缓存报告
    private func generateCacheReport(results: [String: (success: Bool, count: Int)], completion: @escaping (Bool, String?) -> Void) {
        var report = "📊 消息按钮缓存更新报告\n\n"
        var successCount = 0
        var totalRecords = 0
        
        for (className, result) in results {
            if result.success {
                report += "✅ \(className): \(result.count) 条记录\n"
                successCount += 1
                totalRecords += result.count
            } else {
                report += "❌ \(className): 缓存失败\n"
            }
        }
        
        report += "\n📈 总结: \(successCount)/\(results.count) 个表缓存成功，共 \(totalRecords) 条记录"
        
        let allSuccess = successCount == results.count
        
        // 更新最后缓存时间
        if let userId = getCurrentUserId() {
            updateLastCacheTime(userId: userId)
        }
        
        completion(allSuccess, report)
    }
    
    // MARK: - 私有方法
    
    /// 更新最后缓存时间
    private func updateLastCacheTime(userId: String) {
        UserDefaults.standard.set(Date(), forKey: CacheKeys.lastUpdateTime(userId: userId))
    }
    
    /// 检查缓存是否过期
    private func isCacheExpired(userId: String) -> Bool {
        guard let lastUpdateTime = UserDefaults.standard.object(forKey: CacheKeys.lastUpdateTime(userId: userId)) as? Date else {
            return true
        }
        
        return Date().timeIntervalSince(lastUpdateTime) > cacheExpirationInterval
    }
    
    /// 清除所有缓存（按当前用户）
    func clearAllCaches() {
        guard let userId = getCurrentUserId() else { return }
        // 只清除UserNameRecord和UserAvatarRecord的缓存
        UserDefaults.standard.removeObject(forKey: CacheKeys.userNameRecords(userId: userId))
        UserDefaults.standard.removeObject(forKey: CacheKeys.userAvatarRecords(userId: userId))
        UserDefaults.standard.removeObject(forKey: CacheKeys.lastUpdateTime(userId: userId))
    }
    
    /// 获取缓存统计信息
    func getCacheStats() -> [String: Any] {
        guard let userId = getCurrentUserId() else { return [:] }
        var stats: [String: Any] = [:]
        
        // 只统计UserNameRecord和UserAvatarRecord的缓存
        if let userNameRecords = getCachedUserNameRecords() {
            stats["userNameRecordsCount"] = userNameRecords.count
        }
        
        if let userAvatarRecords = getCachedUserAvatarRecords() {
            stats["userAvatarRecordsCount"] = userAvatarRecords.count
        }
        
        if let lastUpdateTime = UserDefaults.standard.object(forKey: CacheKeys.lastUpdateTime(userId: userId)) as? Date {
            stats["lastUpdateTime"] = lastUpdateTime
            stats["isExpired"] = isCacheExpired(userId: userId)
        }
        
        return stats
    }
    
    /// 更新指定好友的消息数量缓存（按当前用户隔离）
    func updateMessageCount(for friendId: String, count: Int) {
        guard let userId = getCurrentUserId() else { return }
        let key = "MessageCount_\(userId)_\(friendId)"
        UserDefaults.standard.set(count, forKey: key)
        updateLastCacheTime(userId: userId)
    }
    
    /// 获取指定好友的消息数量缓存（按当前用户隔离）
    func getMessageCount(for friendId: String) -> Int? {
        guard let userId = getCurrentUserId() else { return nil }
        let key = "MessageCount_\(userId)_\(friendId)"
        let count = UserDefaults.standard.integer(forKey: key)
        return count > 0 ? count : nil
    }
    
    /// 从本地缓存构建全局缓存，避免重复网络请求
    func buildGlobalCacheFromLocalCache() {
        
        // 从UserDefaults获取缓存的UserNameRecord数据
        if let userNameRecords = getCachedUserNameRecords() {
            // 构建全局用户名缓存
            for record in userNameRecords {
                if let userId = record["userId"] as? String,
                   let userName = record["userName"] as? String {
                    LeanCloudService.shared.cacheUserName(userName, for: userId)
                }
            }
        }
        
        // 从UserDefaults获取缓存的UserAvatarRecord数据
        if let userAvatarRecords = getCachedUserAvatarRecords() {
            // 构建全局用户头像缓存
            for record in userAvatarRecords {
                if let userId = record["userId"] as? String,
                   let userAvatar = record["userAvatar"] as? String {
                    LeanCloudService.shared.cacheUserAvatar(userAvatar, for: userId)
                }
            }
        }
        
    }
}
