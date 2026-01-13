//
//  LeanCloudService+LocationMerge.swift
//  NeverSayNo
//
//  Created by AI Assistant on 2024-12-19.
//

import Foundation
import LeanCloud

// MARK: - 用户积分合并方法
extension LeanCloudService {
    
    // 批量获取用户在线状态（与头像批量获取机制一致）
    func batchFetchUserOnlineStatus(userIds: [String], completion: @escaping ([String: (Bool, Date?)]) -> Void) {
        
        guard !userIds.isEmpty else {
            completion([:])
            return
        }
        
        var onlineStatusCache: [String: (Bool, Date?)] = [:]
        let dispatchGroup = DispatchGroup()
        
        // 🎯 修改：只从 LoginRecord 表读取上线时间，不再从 LocationRecord 和 InternalLoginRecord 表读取
        // 批量获取所有登录记录
        dispatchGroup.enter()
        fetchAllLoginRecords { loginRecords, error in
            if error != nil {
            } else if let records = loginRecords {
                for (_, record) in records.enumerated() {
                    if let userId = record["userId"] as? String,
                       let loginTime = record["loginTime"] as? String {
                        // 尝试多种时间格式解析
                        var date: Date?
                        
                        // 1. 尝试ISO8601格式（带毫秒）
                        let formatter1 = ISO8601DateFormatter()
                        formatter1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        date = formatter1.date(from: loginTime)
                        
                        // 2. 如果失败，尝试ISO8601格式（不带毫秒）
                        if date == nil {
                            let formatter2 = ISO8601DateFormatter()
                            formatter2.formatOptions = [.withInternetDateTime]
                            date = formatter2.date(from: loginTime)
                        }
                        
                        // 3. 如果还是失败，尝试自定义格式
                        if date == nil {
                            let formatter3 = DateFormatter()
                            formatter3.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                            formatter3.timeZone = TimeZone(abbreviation: "UTC")
                            date = formatter3.date(from: loginTime)
                        }
                        
                        if let date = date {
                            // 比较位置记录和登录记录，取最新的（使用本地时间）
                            if let existing = onlineStatusCache[userId] {
                                let oldTime = existing.1!
                                let newTime = date
                                let isNewer = newTime > oldTime
                                
                                // 添加本地时间比较调试信息
                                let formatter = DateFormatter()
                                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                                formatter.timeZone = TimeZone.current
                                
                                
                                if isNewer {
                                    onlineStatusCache[userId] = (false, newTime)
                                } else {
                                }
                            } else {
                                onlineStatusCache[userId] = (false, date)
                            }
                        } else {
                        }
                    } else {
                    }
                }
            }
            dispatchGroup.leave()
        }
        
        // 🎯 修改：不再从 InternalLoginRecord 表读取上线时间，统一只从 LoginRecord 表读取
        
        dispatchGroup.notify(queue: .main) {
            // 计算在线状态 - 使用本地时间
            let now = Date()
            for userId in userIds {
                if let (_, lastActiveTime) = onlineStatusCache[userId] {
                    // 使用本地时间计算时间差
                    let timeInterval = now.timeIntervalSince(lastActiveTime!)
                    let isOnline = timeInterval <= 600 // 10分钟 = 600秒
                    onlineStatusCache[userId] = (isOnline, lastActiveTime)
                    
                    // 同时更新全局缓存
                    self.cacheOnlineStatus(isOnline, lastActiveTime: lastActiveTime, for: userId)
                    
                    // 添加本地时间调试信息
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    formatter.timeZone = TimeZone.current
                    
                } else {
                    // 如果没有记录，设为离线，最近上线时间设为7天前
                    let sevenDaysAgo = now.addingTimeInterval(-7 * 24 * 3600)
                    onlineStatusCache[userId] = (false, sevenDaysAgo)
                    
                    // 同时更新全局缓存
                    self.cacheOnlineStatus(false, lastActiveTime: sevenDaysAgo, for: userId)
                    
                }
            }
            completion(onlineStatusCache)
        }
    }
    
    // 获取所有位置记录
    private func fetchAllLocationRecords(completion: @escaping ([[String: Any]]?, String?) -> Void) {
        var allRecords: [[String: Any]] = []
        let pageSize = 1000
        var skip = 0
        var hasMore = true
        
        func fetchPage() {
            guard hasMore else {
                completion(allRecords, nil)
                return
            }
            
            let urlString = "\(serverUrl)/1.1/classes/LocationRecord?order=-createdAt&limit=\(pageSize)&skip=\(skip)"
            guard let url = URL(string: urlString) else {
                completion(nil, "URL创建失败")
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            setLeanCloudHeaders(&request)
            request.timeoutInterval = 30.0
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(nil, "请求失败: \(error.localizedDescription)")
                        return
                    }
                    
                    if let httpResponse = response as? HTTPURLResponse,
                       httpResponse.statusCode == 200,
                       let data = data {
                        do {
                            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                            if let results = json?["results"] as? [[String: Any]] {
                                allRecords.append(contentsOf: results)
                                
                                if results.count < pageSize {
                                    hasMore = false
                                    completion(allRecords, nil)
                                } else {
                                    skip += pageSize
                                    fetchPage()
                                }
                            } else {
                                completion(nil, "数据格式错误")
                            }
                        } catch {
                            completion(nil, "响应解析失败")
                        }
                    } else {
                        completion(nil, "请求失败")
                    }
                }
            }.resume()
        }
        
        fetchPage()
    }
    
    // 获取所有登录记录
    private func fetchAllLoginRecords(completion: @escaping ([[String: Any]]?, String?) -> Void) {
        var allRecords: [[String: Any]] = []
        let pageSize = 1000
        var skip = 0
        var hasMore = true
        
        func fetchPage() {
            guard hasMore else {
                completion(allRecords, nil)
                return
            }
            
            let urlString = "\(serverUrl)/1.1/classes/LoginRecord?order=-createdAt&limit=\(pageSize)&skip=\(skip)"
            guard let url = URL(string: urlString) else {
                completion(nil, "URL创建失败")
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            setLeanCloudHeaders(&request)
            request.timeoutInterval = 30.0
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(nil, "请求失败: \(error.localizedDescription)")
                        return
                    }
                    
                    if let httpResponse = response as? HTTPURLResponse,
                       httpResponse.statusCode == 200,
                       let data = data {
                        do {
                            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                            if let results = json?["results"] as? [[String: Any]] {
                                allRecords.append(contentsOf: results)
                                
                                if results.count < pageSize {
                                    hasMore = false
                                    completion(allRecords, nil)
                                } else {
                                    skip += pageSize
                                    fetchPage()
                                }
                            } else {
                                completion(nil, "数据格式错误")
                            }
                        } catch {
                            completion(nil, "响应解析失败")
                        }
                    } else {
                        completion(nil, "请求失败")
                    }
                }
            }.resume()
        }
        
        fetchPage()
    }
    
    // 获取所有内部登录记录
    private func fetchAllInternalLoginRecords(completion: @escaping ([[String: Any]]?, String?) -> Void) {
        var allRecords: [[String: Any]] = []
        let pageSize = 1000
        var skip = 0
        var hasMore = true
        
        func fetchPage() {
            guard hasMore else {
                completion(allRecords, nil)
                return
            }
            
            let urlString = "\(serverUrl)/1.1/classes/InternalLoginRecord?order=-login_time&limit=\(pageSize)&skip=\(skip)"
            guard let url = URL(string: urlString) else {
                completion(nil, "URL创建失败")
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            setLeanCloudHeaders(&request)
            request.timeoutInterval = 30.0
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        completion(nil, "请求失败: \(error.localizedDescription)")
                        return
                    }
                    
                    if let httpResponse = response as? HTTPURLResponse,
                       httpResponse.statusCode == 200,
                       let data = data {
                        do {
                            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                            if let results = json?["results"] as? [[String: Any]] {
                                allRecords.append(contentsOf: results)
                                
                                if results.count < pageSize {
                                    hasMore = false
                                    completion(allRecords, nil)
                                } else {
                                    skip += pageSize
                                    fetchPage()
                                }
                            } else {
                                completion(nil, "数据格式错误")
                            }
                        } catch {
                            completion(nil, "响应解析失败")
                        }
                    } else {
                        completion(nil, "请求失败")
                    }
                }
            }.resume()
        }
        
        fetchPage()
    }
    
    // 获取指定用户的最新位置记录（用于在线状态判断）
    // ✅ 改为：与用户头像查询方式一致，使用 LCQuery
    // 🎯 新增：添加重试机制（与用户头像查询一致）
    func fetchLatestLocationForUser(userId: String, completion: @escaping (LocationRecord?, String?) -> Void) {
        var retryCount = 0
        
        func attempt() {
            // ✅ 按照开发指南：使用 LCQuery 创建查询（与用户头像查询方式一致）
            let query = LCQuery(className: "LocationRecord")
            query.whereKey("userId", .equalTo(userId))
            query.whereKey("createdAt", .descending)
            query.limit = 1
            
            query.find { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let records):
                        if let firstRecord = records.first {
                            // 解析位置记录
                            let latitude = firstRecord["latitude"]?.doubleValue ?? 0.0
                            let longitude = firstRecord["longitude"]?.doubleValue ?? 0.0
                            let accuracy = firstRecord["accuracy"]?.doubleValue ?? 0.0
                            let user_id = firstRecord["userId"]?.stringValue ?? ""
                            let user_name = firstRecord["userName"]?.stringValue ?? "未知用户"
                            let login_type = firstRecord["loginType"]?.stringValue ?? "unknown"
                            let device_id = firstRecord["deviceId"]?.stringValue ?? ""
                            
                            // 获取时间戳
                            let timestamp: String
                            if let deviceTime = firstRecord["deviceTime"]?.stringValue, !deviceTime.isEmpty {
                                timestamp = deviceTime
                            } else if let createdAt = firstRecord.createdAt {
                                timestamp = ISO8601DateFormatter().string(from: createdAt.value)
                            } else {
                                timestamp = ISO8601DateFormatter().string(from: Date())
                            }
                            
                            let user_email: String? = nil // 🎯 不再从LocationRecord表读取userEmail，统一从UserNameRecord表读取
                            // 🎯 不再从LocationRecord表读取userAvatar，统一从UserAvatarRecord表读取
                            let user_avatar: String? = nil
                            let client_timestamp = firstRecord["clientTimestamp"]?.doubleValue
                            let timezone = firstRecord["timezone"]?.stringValue
                            let objectId = firstRecord.objectId?.stringValue ?? ""
                            
                            // 检查必需字段是否有效
                            if user_id.isEmpty {
                                completion(nil, "用户ID为空")
                                return
                            }
                            
                            let locationRecord = LocationRecord(
                                id: 0,
                                objectId: objectId,
                                timestamp: timestamp,
                                latitude: latitude,
                                longitude: longitude,
                                accuracy: accuracy,
                                userId: user_id,
                                userName: user_name,
                                loginType: login_type,
                                userEmail: user_email,
                                userAvatar: user_avatar,
                                deviceId: device_id,
                                clientTimestamp: client_timestamp,
                                timezone: timezone,
                                status: firstRecord["status"]?.stringValue,
                                recordCount: firstRecord["recordCount"]?.intValue,
                                likeCount: firstRecord["likeCount"]?.intValue
                            )
                            
                            completion(locationRecord, nil)
                        } else {
                            // 🎯 修改：查询失败时，如果未达到最大重试次数，触发重试
                            if retryCount < LeanCloudRetryConfig.maxRetries {
                                retryCount += 1
                                let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                    attempt()
                                }
                            } else {
                                completion(nil, "未找到用户的位置记录")
                            }
                        }
                    case .failure(let error):
                        // 🎯 修改：查询失败时，如果未达到最大重试次数，触发重试
                        if retryCount < LeanCloudRetryConfig.maxRetries {
                            retryCount += 1
                            let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                attempt()
                            }
                        } else {
                            completion(nil, "查询失败: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
        
        attempt()
    }
    
    // 获取指定用户在特定时间附近的位置记录
    // 🎯 新增：添加重试机制（与用户头像查询一致）
    func fetchLocationAtTime(userId: String, targetTime: Date, completion: @escaping (LocationRecord?, String?) -> Void) {
        var retryCount = 0
        
        func attempt() {
            // 获取该用户的所有位置记录，然后找到最接近目标时间的记录
            // 🔧 修复：使用正确的字段名 userId（不是 user_id）
            let urlString = "\(serverUrl)/1.1/classes/LocationRecord?where={\"userId\":\"\(userId)\"}&order=-createdAt&limit=100"
            guard let url = URL(string: urlString) else {
                if retryCount < LeanCloudRetryConfig.maxRetries {
                    retryCount += 1
                    let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        attempt()
                    }
                } else {
                    completion(nil, "无效的URL")
                }
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            setLeanCloudHeaders(&request)
            request.timeoutInterval = 10.0
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    if let error = error {
                        // 🎯 修改：查询失败时，如果未达到最大重试次数，触发重试
                        if retryCount < LeanCloudRetryConfig.maxRetries {
                            retryCount += 1
                            let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                attempt()
                            }
                        } else {
                            completion(nil, "网络错误: \(error.localizedDescription)")
                        }
                        return
                    }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200, let data = data {
                        do {
                            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                            
                            
                            if let results = json?["results"] as? [[String: Any]], !results.isEmpty {
                                
                                // 解析所有位置记录并找到最接近目标时间的记录
                                var closestRecord: LocationRecord?
                                var minTimeDifference: TimeInterval = Double.greatestFiniteMagnitude
                                
                                for (_, result) in results.enumerated() {
                                    // 解析位置记录
                                    let latitude = result["latitude"] as? Double ?? 0.0
                                    let longitude = result["longitude"] as? Double ?? 0.0
                                    let accuracy = result["accuracy"] as? Double ?? 0.0
                                    let user_id = result["userId"] as? String ?? ""
                                    let user_name = result["userName"] as? String ?? "未知用户"
                                    let login_type = result["loginType"] as? String ?? "unknown"
                                    let device_id = result["deviceId"] as? String ?? ""
                                    let timestamp = result["deviceTime"] as? String ?? result["createdAt"] as? String ?? ISO8601DateFormatter().string(from: Date())
                                    
                                    let user_email: String? = nil // 🎯 不再从LocationRecord表读取userEmail，统一从UserNameRecord表读取
                                    // 🎯 不再从LocationRecord表读取userAvatar，统一从UserAvatarRecord表读取
                                    let user_avatar: String? = nil
                                    let client_timestamp = result["clientTimestamp"] as? Double
                                    let timezone = result["timezone"] as? String
                                    let objectId = result["objectId"] as? String
                                    
                                    // 解析记录时间
                                    let recordTime = self.parseTimestamp(timestamp)
                                    let timeDifference = abs(recordTime.timeIntervalSince(targetTime))
                                    
                                    
                                    // 如果这个记录更接近目标时间，则更新最接近的记录
                                    if timeDifference < minTimeDifference {
                                        minTimeDifference = timeDifference
                                        closestRecord = LocationRecord(
                                            id: 0,
                                            objectId: objectId ?? "",
                                            timestamp: timestamp,
                                            latitude: latitude,
                                            longitude: longitude,
                                            accuracy: accuracy,
                                            userId: user_id,
                                            userName: user_name,
                                            loginType: login_type,
                                            userEmail: user_email,
                                            userAvatar: user_avatar,
                                            deviceId: device_id,
                                            clientTimestamp: client_timestamp,
                                            timezone: timezone,
                                            status: result["status"] as? String,
                                            recordCount: result["recordCount"] as? Int,
                                            likeCount: result["likeCount"] as? Int
                                        )
                                    }
                                }
                                
                                if let closestRecord = closestRecord {
                                    completion(closestRecord, nil)
                                } else {
                                    // 🎯 修改：查询失败时，如果未达到最大重试次数，触发重试
                                    if retryCount < LeanCloudRetryConfig.maxRetries {
                                        retryCount += 1
                                        let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                            attempt()
                                        }
                                    } else {
                                        completion(nil, "未找到有效的位置记录")
                                    }
                                }
                            } else {
                                // 🎯 修改：查询失败时，如果未达到最大重试次数，触发重试
                                if retryCount < LeanCloudRetryConfig.maxRetries {
                                    retryCount += 1
                                    let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                        attempt()
                                    }
                                } else {
                                    completion(nil, "用户没有位置记录")
                                }
                            }
                        } catch {
                            // 🎯 修改：查询失败时，如果未达到最大重试次数，触发重试
                            if retryCount < LeanCloudRetryConfig.maxRetries {
                                retryCount += 1
                                let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                    attempt()
                                }
                            } else {
                                completion(nil, "数据解析失败: \(error.localizedDescription)")
                            }
                        }
                    } else {
                        // 🎯 修改：查询失败时，如果未达到最大重试次数，触发重试
                        if retryCount < LeanCloudRetryConfig.maxRetries {
                            retryCount += 1
                            let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                attempt()
                            }
                        } else {
                            completion(nil, "服务器错误: \(httpResponse.statusCode)")
                        }
                    }
                } else {
                    // 🎯 修改：查询失败时，如果未达到最大重试次数，触发重试
                    if retryCount < LeanCloudRetryConfig.maxRetries {
                        retryCount += 1
                        let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            attempt()
                        }
                    } else {
                        completion(nil, "无效的响应")
                    }
                }
            }
        }.resume()
        }
        
        attempt()
    }
    
    // 解析时间戳的辅助方法
    private func parseTimestamp(_ timestamp: String) -> Date {
        // 尝试多种时间格式解析
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
        
        // 如果所有格式都解析失败，返回当前时间
        return Date()
    }
    
    // 清除所有位置记录（使用状态更新方式）
    func clearAllLocations(completion: @escaping (Bool, String) -> Void) {
        fetchLocations { records, error in
            if let error = error {
                completion(false, error)
                return
            }
            
            if let records = records, !records.isEmpty {
                let group = DispatchGroup()
                var successCount = 0
                var failureCount = 0
                
                for record in records {
                    group.enter()
                    self.clearLocation(objectId: record.objectId) { success, error in
                        if success {
                            successCount += 1
                        } else {
                            failureCount += 1
                        }
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    if failureCount == 0 {
                        completion(true, "成功清除 \(successCount) 条记录")
                    } else {
                        completion(false, "清除完成，成功 \(successCount) 条，失败 \(failureCount) 条")
                    }
                }
            } else {
                completion(true, "没有需要清除的记录")
            }
        }
    }
}
