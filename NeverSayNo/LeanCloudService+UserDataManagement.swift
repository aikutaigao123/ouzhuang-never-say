//
//  LeanCloudService+UserDataManagement.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//

import Foundation
import UIKit
import LeanCloud

// MARK: - User Data Management Extensions
extension LeanCloudService {
    
    /// 批量获取用户数据（消息按钮专用）
    func batchFetchUserDataForMessages(userIds: [String], loginTypes: [String], completion: @escaping ([String: String], [String: String]) -> Void) {
        guard !userIds.isEmpty else {
            completion([:], [:])
            return
        }
        
        var avatarResults: [String: String] = [:]
        var nameResults: [String: String] = [:]
        let group = DispatchGroup()
        
        // 首先检查缓存，减少不必要的网络请求
        var uncachedUserIds: [String] = []
        var uncachedLoginTypes: [String] = []
        
        for (index, userId) in userIds.enumerated() {
            let loginType = index < loginTypes.count ? loginTypes[index] : "apple"
            
            // 检查头像缓存
            if let cachedAvatar = getCachedUserAvatar(for: userId) {
                avatarResults[userId] = cachedAvatar
            } else {
                uncachedUserIds.append(userId)
                uncachedLoginTypes.append(loginType)
            }
            
            // 检查用户名缓存
            if let cachedName = getCachedUserName(for: userId) {
                nameResults[userId] = cachedName
            }
        }
        
        // 如果没有需要网络请求的用户，直接返回缓存结果
        if uncachedUserIds.isEmpty {
            completion(avatarResults, nameResults)
            return
        }
        
        // 批量获取头像
        if !uncachedUserIds.isEmpty {
            group.enter()
            batchFetchUserAvatars(userIds: uncachedUserIds, loginTypes: uncachedLoginTypes) { newAvatarResults in
                // 合并新获取的头像结果
                for (userId, avatar) in newAvatarResults {
                    avatarResults[userId] = avatar
                }
                group.leave()
            }
        }
        
        // 批量获取用户名
        if !uncachedUserIds.isEmpty {
            group.enter()
            batchFetchUserNames(userIds: uncachedUserIds, loginTypes: uncachedLoginTypes) { newNameResults in
                // 合并新获取的用户名结果
                for (userId, name) in newNameResults {
                    nameResults[userId] = name
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(avatarResults, nameResults)
        }
    }
    
    /// 批量查询用户名、头像和用户类型（像最近上线时间一样的逻辑）
    func batchFetchUserNameAndAvatar(userIds: [String], completion: @escaping ([String: String], [String: String], [String: String]) -> Void) {
        
        guard !userIds.isEmpty else {
            completion([:], [:], [:])
            return
        }
        
        var avatarResults: [String: String] = [:]
        var nameResults: [String: String] = [:]
        var loginTypeResults: [String: String] = [:]
        let group = DispatchGroup()
        
        // 首先检查缓存，减少不必要的网络请求
        var uncachedUserIds: [String] = []
        var uncachedLoginTypes: [String] = []
        
        for userId in userIds {
            let loginType = UserTypeUtils.getLoginTypeFromUserId(userId)
            
            // 检查头像缓存
            if let cachedAvatar = getCachedUserAvatar(for: userId) {
                avatarResults[userId] = cachedAvatar
            } else {
                uncachedUserIds.append(userId)
                uncachedLoginTypes.append(loginType)
            }
            
            // 检查用户名缓存
            if let cachedName = getCachedUserName(for: userId) {
                nameResults[userId] = cachedName
            } else {
                // 如果用户名不在缓存中，也需要查询
                if !uncachedUserIds.contains(userId) {
                    uncachedUserIds.append(userId)
                    uncachedLoginTypes.append(loginType)
                }
            }
        }
        
        // 如果没有需要网络请求的用户，直接返回缓存结果（用户类型从缓存中获取）
        if uncachedUserIds.isEmpty {
            // 🎯 参考头像界面方式：如果没有需要网络请求的用户，但仍需查询用户类型
            // 由于用户类型不再使用全局缓存，这里返回空字典，让调用方决定是否需要查询
            completion(avatarResults, nameResults, loginTypeResults)
            return
        }
        
        
        // 批量获取头像
        if !uncachedUserIds.isEmpty {
            group.enter()
            batchFetchUserAvatars(userIds: uncachedUserIds, loginTypes: uncachedLoginTypes) { newAvatarResults in
                // 合并新获取的头像结果
                for (userId, avatar) in newAvatarResults {
                    avatarResults[userId] = avatar
                }
                group.leave()
            }
        }
        
        // 🎯 参考头像界面方式：批量获取用户名和用户类型（使用新的批量查询方法）
        if !uncachedUserIds.isEmpty {
            group.enter()
            batchFetchUserNamesAndLoginTypes(userIds: uncachedUserIds) { newNameResults, newLoginTypeResults in
                // 合并新获取的用户名结果
                for (userId, name) in newNameResults {
                    nameResults[userId] = name
                }
                // 🎯 合并新获取的用户类型结果（参考头像界面方式，不使用全局缓存）
                for (userId, loginType) in newLoginTypeResults {
                    loginTypeResults[userId] = loginType
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(avatarResults, nameResults, loginTypeResults)
        }
    }
    
    /// 批量获取用户数据（历史按钮专用）
    func batchFetchUserDataForHistory(userIds: [String], loginTypes: [String], completion: @escaping ([String: String], [String: String]) -> Void) {
        guard !userIds.isEmpty else {
            completion([:], [:])
            return
        }
        
        var avatarResults: [String: String] = [:]
        var nameResults: [String: String] = [:]
        let group = DispatchGroup()
        
        // 首先检查缓存，减少不必要的网络请求
        var uncachedUserIds: [String] = []
        var uncachedLoginTypes: [String] = []
        
        for (index, userId) in userIds.enumerated() {
            let loginType = index < loginTypes.count ? loginTypes[index] : "apple"
            
            // 检查头像缓存
            if let cachedAvatar = getCachedUserAvatar(for: userId) {
                avatarResults[userId] = cachedAvatar
            } else {
                uncachedUserIds.append(userId)
                uncachedLoginTypes.append(loginType)
            }
            
            // 检查用户名缓存
            if let cachedName = getCachedUserName(for: userId) {
                nameResults[userId] = cachedName
            }
        }
        
        // 如果没有需要网络请求的用户，直接返回缓存结果
        if uncachedUserIds.isEmpty {
            completion(avatarResults, nameResults)
            return
        }
        
        // 批量获取头像
        if !uncachedUserIds.isEmpty {
            group.enter()
            batchFetchUserAvatars(userIds: uncachedUserIds, loginTypes: uncachedLoginTypes) { newAvatarResults in
                // 合并新获取的头像结果
                for (userId, avatar) in newAvatarResults {
                    avatarResults[userId] = avatar
                }
                group.leave()
            }
        }
        
        // 批量获取用户名
        if !uncachedUserIds.isEmpty {
            group.enter()
            batchFetchUserNames(userIds: uncachedUserIds, loginTypes: uncachedLoginTypes) { newNameResults in
                // 合并新获取的用户名结果
                for (userId, name) in newNameResults {
                    nameResults[userId] = name
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(avatarResults, nameResults)
        }
    }
    
    /// 获取用户最后在线时间 - 参考用户头像查询方式，使用 LCQuery
    // 🎯 新增：添加重试机制（与用户头像查询一致）
    func fetchUserLastOnlineTime(userId: String, completion: @escaping (Bool, Date?) -> Void) {
        var retryCount = 0
        
        func attempt() {
            // ✅ 按照开发指南：使用 LCQuery 创建查询（与 fetchUserAvatar 一致）
            let query = LCQuery(className: "LoginRecord")
            query.whereKey("userId", .equalTo(userId))
            query.whereKey("updatedAt", .descending) // 🔧 统一：使用 updatedAt（与用户头像查询一致）
            query.limit = 1
            
            query.find { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let records):
                        if let firstRecord = records.first {
                            // 🎯 修改：统一使用 updatedAt 字段（与用户头像查询一致）
                            var date: Date?
                            
                            // 优先使用 updatedAt 字段（Date 类型）
                            if let updatedAt = firstRecord.updatedAt {
                                date = updatedAt.value
                            } else if let createdAt = firstRecord.createdAt {
                                // 回退到 createdAt 字段
                                date = createdAt.value
                            }
                            
                            if let date = date {
                                let now = Date()
                                let timeInterval = now.timeIntervalSince(date)
                                let isOnline = timeInterval < 600 // 10分钟内算在线
                                completion(isOnline, date)
                            } else {
                                // 🎯 修改：查询失败时，如果未达到最大重试次数，触发重试
                                if retryCount < LeanCloudRetryConfig.maxRetries {
                                    retryCount += 1
                                    let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                        attempt()
                                    }
                                } else {
                                    completion(false, nil)
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
                                completion(false, nil)
                            }
                        }
                    case .failure(_):
                        // 🎯 修改：查询失败时，如果未达到最大重试次数，触发重试
                        if retryCount < LeanCloudRetryConfig.maxRetries {
                            retryCount += 1
                            let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                attempt()
                            }
                        } else {
                            completion(false, nil)
                        }
                    }
                }
            }
        }
        
        attempt()
    }
    
    /// 批量获取多个用户的最后在线时间（优化版本）
    func batchFetchUserLastOnlineTime(userIds: [String], completion: @escaping ([String: (Bool, Date?)]) -> Void) {
        // 验证API配置
        guard validateAPIConfig() else {
            completion([:])
            return
        }
        
        // 如果用户ID为空，直接返回空结果
        guard !userIds.isEmpty else {
            completion([:])
            return
        }
        
        // 🎯 修改：统一使用 LoginRecord 表，不再区分用户类型
        // 分别查询所有用户（统一使用 LoginRecord 表）
        let dispatchGroup = DispatchGroup()
        var allResults: [String: (Bool, Date?)] = [:]
        
        // 🎯 修改：参考用户头像查询方式，使用 LCQuery 进行批量查询
        // 由于 LCQuery 不支持 $in 操作符，我们使用循环查询每个用户（与用户头像批量查询方式一致）
        // 🎯 新增：为每个查询添加重试机制（与用户头像查询一致）
        if !userIds.isEmpty {
            for userId in userIds {
                dispatchGroup.enter()
                
                var retryCount = 0
                
                func attempt() {
                    // ✅ 按照开发指南：使用 LCQuery 创建查询（与 fetchUserAvatar 一致）
                    let query = LCQuery(className: "LoginRecord")
                    query.whereKey("userId", .equalTo(userId))
                    query.whereKey("updatedAt", .descending) // 🔧 统一：使用 updatedAt（与用户头像查询一致）
                    query.limit = 1
                    
                    query.find { result in
                        DispatchQueue.main.async {
                            switch result {
                            case .success(let records):
                                if let firstRecord = records.first {
                                    // 🎯 修改：统一使用 updatedAt 字段（与用户头像查询一致）
                                    var date: Date?
                                    
                                    // 优先使用 updatedAt 字段（Date 类型）
                                    if let updatedAt = firstRecord.updatedAt {
                                        date = updatedAt.value
                                    } else if let createdAt = firstRecord.createdAt {
                                        // 回退到 createdAt 字段
                                        date = createdAt.value
                                    }
                                    
                                    if let date = date {
                                        let now = Date()
                                        let timeInterval = now.timeIntervalSince(date)
                                        let isOnline = timeInterval < 600 // 10分钟内算在线
                                        allResults[userId] = (isOnline, date)
                                    } else {
                                        // 🎯 修改：查询失败时，如果未达到最大重试次数，触发重试
                                        if retryCount < LeanCloudRetryConfig.maxRetries {
                                            retryCount += 1
                                            let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                                attempt()
                                            }
                                            return
                                        } else {
                                            allResults[userId] = (false, nil)
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
                                        return
                                    } else {
                                        allResults[userId] = (false, nil)
                                    }
                                }
                                dispatchGroup.leave()
                            case .failure:
                                // 🎯 修改：查询失败时，如果未达到最大重试次数，触发重试
                                if retryCount < LeanCloudRetryConfig.maxRetries {
                                    retryCount += 1
                                    let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                        attempt()
                                    }
                                } else {
                                    allResults[userId] = (false, nil)
                                    dispatchGroup.leave()
                                }
                            }
                        }
                    }
                }
                
                attempt()
            }
        }
        
        // 等待所有查询完成
        dispatchGroup.notify(queue: .main) {
            // 为没有记录的用户设置默认值
            for userId in userIds {
                if allResults[userId] == nil {
                    allResults[userId] = (false, nil)
                }
            }
            
            completion(allResults)
        }
    }
    
    /// 处理批量查询结果
    private func processBatchQueryResults(data: Data?, response: URLResponse?, error: Error?, userIds: [String], isInternal: Bool, results: inout [String: (Bool, Date?)]) {
        if error != nil {
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            return
        }
        
        
        if httpResponse.statusCode == 200 {
            do {
                if let jsonData = data {
                    if let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                       let records = json["results"] as? [[String: Any]] {
                        
                        
                        // 按用户ID分组，取最新的记录
                        var userLatestRecords: [String: [String: Any]] = [:]
                        for record in records {
                            if let userId = record["userId"] as? String {
                                // 只保留每个用户的最新记录
                                if userLatestRecords[userId] == nil {
                                    userLatestRecords[userId] = record
                                }
                            }
                        }
                        
                        
                        // 转换为结果格式
                        for (userId, record) in userLatestRecords {
                            // 🎯 修改：统一使用 updatedAt 字段（与用户头像查询一致）
                            var date: Date?
                            
                            // 优先尝试从 updatedAt 字段获取（Date 类型）
                            if let updatedAtDict = record["updatedAt"] as? [String: Any],
                               let updatedAtString = updatedAtDict["iso"] as? String {
                                let formatter = ISO8601DateFormatter()
                                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                                date = formatter.date(from: updatedAtString)
                                if date == nil {
                                    let formatterWithoutFractional = ISO8601DateFormatter()
                                    formatterWithoutFractional.formatOptions = [.withInternetDateTime]
                                    date = formatterWithoutFractional.date(from: updatedAtString)
                                }
                            } else if let updatedAtString = record["updatedAt"] as? String {
                                // 如果 updatedAt 是字符串格式
                                let formatter = ISO8601DateFormatter()
                                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                                date = formatter.date(from: updatedAtString)
                                if date == nil {
                                    let formatterWithoutFractional = ISO8601DateFormatter()
                                    formatterWithoutFractional.formatOptions = [.withInternetDateTime]
                                    date = formatterWithoutFractional.date(from: updatedAtString)
                                }
                            } else if let createdAtDict = record["createdAt"] as? [String: Any],
                                      let createdAtString = createdAtDict["iso"] as? String {
                                // 回退到 createdAt 字段
                                let formatter = ISO8601DateFormatter()
                                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                                date = formatter.date(from: createdAtString)
                                if date == nil {
                                    let formatterWithoutFractional = ISO8601DateFormatter()
                                    formatterWithoutFractional.formatOptions = [.withInternetDateTime]
                                    date = formatterWithoutFractional.date(from: createdAtString)
                                }
                            } else if let createdAtString = record["createdAt"] as? String {
                                // 如果 createdAt 是字符串格式
                                let formatter = ISO8601DateFormatter()
                                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                                date = formatter.date(from: createdAtString)
                                if date == nil {
                                    let formatterWithoutFractional = ISO8601DateFormatter()
                                    formatterWithoutFractional.formatOptions = [.withInternetDateTime]
                                    date = formatterWithoutFractional.date(from: createdAtString)
                                }
                            }
                            
                            if let date = date {
                                let now = Date()
                                let timeInterval = now.timeIntervalSince(date)
                                let isOnline = timeInterval < 600 // 10分钟内算在线
                                
                                results[userId] = (isOnline, date)
                            } else {
                                results[userId] = (false, nil)
                            }
                        }
                    } else {
                    }
                } else {
                }
            } catch {
            }
        } else {
        }
    }
    
    /// 格式化时间差
    private func formatTimeAgo(_ timeInterval: TimeInterval) -> String {
        if timeInterval < 60 {
            return "刚刚"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)分钟前"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)小时前"
        } else if timeInterval < 604800 {
            let days = Int(timeInterval / 86400)
            return "\(days)天前"
        } else {
            return "7天前"
        }
    }
    
    /// 🎯 修改：统一查询 LoginRecord 表（取消 InternalLoginRecord 表）- 参考用户头像查询方式
    // 🎯 新增：添加重试机制（与用户头像查询一致）
    func fetchUserLastOnlineTimeWithLCQuery(userId: String, completion: @escaping (Bool, Date?) -> Void) {
        var retryCount = 0
        
        func attempt() {
            // 🎯 修改：统一使用 LoginRecord 表，不再区分用户类型
            // ✅ 按照开发指南：使用 LCQuery 创建查询（与 fetchUserAvatar 一致）
            let query = LCQuery(className: "LoginRecord")
            query.whereKey("userId", .equalTo(userId))
            query.whereKey("updatedAt", .descending) // 🔧 统一：使用 updatedAt（与用户头像查询一致）
            query.limit = 1
            
            query.find { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let records):
                        if let firstRecord = records.first {
                            // 🎯 修改：统一使用 updatedAt 字段（与用户头像查询一致）
                            var date: Date?
                            
                            // 优先使用 updatedAt 字段（Date 类型）
                            if let updatedAt = firstRecord.updatedAt {
                                date = updatedAt.value
                            } else if let createdAt = firstRecord.createdAt {
                                // 回退到 createdAt 字段
                                date = createdAt.value
                            }
                            
                            if let date = date {
                                let now = Date()
                                let timeInterval = now.timeIntervalSince(date)
                                let isOnline = timeInterval < 600 // 10分钟内算在线
                                completion(isOnline, date)
                            } else {
                                // 🎯 修改：查询失败时，如果未达到最大重试次数，触发重试
                                if retryCount < LeanCloudRetryConfig.maxRetries {
                                    retryCount += 1
                                    let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                        attempt()
                                    }
                                } else {
                                    completion(false, nil)
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
                                completion(false, nil)
                            }
                        }
                    case .failure:
                        // 🎯 修改：查询失败时，如果未达到最大重试次数，触发重试
                        if retryCount < LeanCloudRetryConfig.maxRetries {
                            retryCount += 1
                            let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                attempt()
                            }
                        } else {
                            completion(false, nil)
                        }
                    }
                }
            }
        }
        
        attempt()
    }
}
