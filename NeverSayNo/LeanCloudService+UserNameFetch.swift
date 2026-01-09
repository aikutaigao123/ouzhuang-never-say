//
//  LeanCloudService+UserNameFetch.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation
import LeanCloud

// MARK: - 用户名获取和状态管理功能
extension LeanCloudService {
    
    // 获取用户名 - 遵循数据存储开发指南，使用 LCQuery
    // 🎯 新增：添加重试机制（与用户头像查询一致）
    func fetchUserName(objectId: String, loginType: String, completion: @escaping (String?, String?) -> Void) {
        var retryCount = 0
        
        func attempt() {
            // ✅ 按照开发指南：使用 LCQuery 创建查询
            let query = LCQuery(className: "UserNameRecord")
            query.whereKey("userId", .equalTo(objectId))
            query.whereKey("loginType", .equalTo(loginType))
            query.whereKey("createdAt", .descending)
            query.limit = 1
            
            query.find { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let records):
                        if let firstRecord = records.first,
                           let userName = firstRecord["userName"]?.stringValue,
                           !userName.isEmpty {
                            let recordObjectId = firstRecord.objectId?.stringValue ?? ""
                            let recordUserId = firstRecord["userId"]?.stringValue ?? "unknown"
                            let recordLoginType = firstRecord["loginType"]?.stringValue ?? "unknown"
                            let _: String
                            if let createdAt = firstRecord.createdAt {
                                _ = createdAt.value.description
                            } else {
                                _ = "unknown"
                            }
                            let _: String
                            if let updatedAt = firstRecord.updatedAt {
                                _ = updatedAt.value.description
                            } else {
                                _ = "unknown"
                            }
                            
                            // 打印完整的UserNameRecord记录信息
                            
                            // 验证查询到的记录的 userId 和 loginType 是否匹配
                            if recordUserId != objectId || recordLoginType != loginType {
                            }
                            // 缓存获取到的用户名
                            self.cacheUserName(userName, for: objectId)
                            let cacheKey = "user_name_object_id_\(objectId)_\(loginType)"
                            if !recordObjectId.isEmpty {
                                UserDefaults.standard.set(recordObjectId, forKey: cacheKey)
                                UserDefaults.standard.set(true, forKey: "user_name_record_created_\(objectId)_\(loginType)")
                            }
                            completion(userName, nil)
                        } else {
                            // 🎯 修改：查询失败时，如果未达到最大重试次数，触发重试
                            if retryCount < LeanCloudRetryConfig.maxRetries {
                                retryCount += 1
                                let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                    attempt()
                                }
                            } else {
                                completion(nil, nil)  // 没有记录不是错误，返回nil, nil
                            }
                        }
                    case .failure(let error):
                        // 如果是表不存在错误，尝试自动创建表
                        if error.localizedDescription.contains("404") || error.localizedDescription.contains("not found") {
                            self.createUserNameRecordTable { success in
                                if success {
                                    // 表创建成功后，重新尝试获取用户名（重置重试计数）
                                    retryCount = 0
                                    attempt()
                                } else {
                                    // 🎯 修改：表创建失败时，如果未达到最大重试次数，触发重试
                                    if retryCount < LeanCloudRetryConfig.maxRetries {
                                        retryCount += 1
                                        let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                            attempt()
                                        }
                                    } else {
                                        completion(nil, "表创建失败")
                                    }
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
                                completion(nil, error.localizedDescription)
                            }
                        }
                    }
                }
            }
        }
        
        attempt()
    }
    
    // 检查用户名记录是否已创建
    func isUserNameRecordCreated(objectId: String, loginType: String) -> Bool {
        let userDefaultsKey = "user_name_record_created_\(objectId)_\(loginType)"
        return UserDefaults.standard.bool(forKey: userDefaultsKey)
    }
    
    // 获取用户名记录创建日期
    func getUserNameRecordCreatedDate(objectId: String, loginType: String) -> Date? {
        let userDefaultsKey = "user_name_record_created_\(objectId)_\(loginType)_date"
        return UserDefaults.standard.object(forKey: userDefaultsKey) as? Date
    }
    
    // 获取用户名最后更新日期
    func getUserNameLastUpdatedDate(objectId: String) -> Date? {
        let userDefaultsKey = "user_name_last_updated_\(objectId)"
        return UserDefaults.standard.object(forKey: userDefaultsKey) as? Date
    }
    
    // 从UserNameRecord获取用户的loginType - 遵循数据存储开发指南，使用 LCQuery
    // 🎯 新增：添加重试机制（与用户头像查询一致）
    func fetchUserLoginType(objectId: String, completion: @escaping (String?) -> Void) {
        var retryCount = 0
        
        func attempt() {
            // ✅ 按照开发指南：使用 LCQuery 创建查询
            let query = LCQuery(className: "UserNameRecord")
            query.whereKey("userId", .equalTo(objectId))
            query.whereKey("createdAt", .descending)
            query.limit = 1
            
            query.find { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let records):
                        if let firstRecord = records.first,
                           let loginType = firstRecord["loginType"]?.stringValue {
                            completion(loginType)
                        } else {
                            // 🎯 修改：查询失败时，如果未达到最大重试次数，触发重试
                            if retryCount < LeanCloudRetryConfig.maxRetries {
                                retryCount += 1
                                let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                    attempt()
                                }
                            } else {
                                completion(nil)
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
                            completion(nil)
                        }
                    }
                }
            }
        }
        
        attempt()
    }
    
    // 根据 objectId 查询用户名（不限制 loginType）- 用于处理 loginType 未知的情况
    // 🎯 新增：添加重试机制（与用户头像查询一致）
    func fetchUserNameByUserId(objectId: String, completion: @escaping (String?, String?) -> Void) {
        var retryCount = 0
        
        func attempt() {
            // ✅ 按照开发指南：使用 LCQuery 创建查询，只根据 objectId 查询，不限制 loginType
            let query = LCQuery(className: "UserNameRecord")
            query.whereKey("userId", .equalTo(objectId))
            query.whereKey("createdAt", .descending)
            query.limit = 1
            
            query.find { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let records):
                        if let firstRecord = records.first,
                           let userName = firstRecord["userName"]?.stringValue,
                           !userName.isEmpty {
                            // 缓存获取到的用户名
                            self.cacheUserName(userName, for: objectId)
                            
                            // 🎯 新增：保存 recordObjectId 和 loginType（如果还没有保存）
                            let recordObjectId = firstRecord.objectId?.stringValue ?? ""
                            let recordLoginType = firstRecord["loginType"]?.stringValue ?? ""
                            if !recordObjectId.isEmpty && !recordLoginType.isEmpty {
                                let objectIdKey = "user_name_object_id_\(objectId)_\(recordLoginType)"
                                if UserDefaults.standard.string(forKey: objectIdKey) == nil {
                                    UserDefaults.standard.set(recordObjectId, forKey: objectIdKey)
                                }
                            }
                            
                            completion(userName, nil)
                        } else {
                            // 🎯 修改：查询失败时，如果未达到最大重试次数，触发重试
                            if retryCount < LeanCloudRetryConfig.maxRetries {
                                retryCount += 1
                                let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                    attempt()
                                }
                            } else {
                                completion(nil, nil)
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
                            completion(nil, error.localizedDescription)
                        }
                    }
                }
            }
        }
        
        attempt()
    }
    
    // 🎯 新增：获取双头像模式解锁状态
    // 🎯 新增：添加重试机制（与用户头像查询一致）
    func fetchDualAvatarUnlockedStatus(objectId: String, loginType: String, completion: @escaping (Bool?) -> Void) {
        var retryCount = 0
        
        func attempt() {
            // 首先尝试从 UserDefaults 获取 recordObjectId
            let objectIdKey = "user_name_object_id_\(objectId)_\(loginType)"
            if let recordObjectId = UserDefaults.standard.string(forKey: objectIdKey) {
                // 直接查询该记录
                let query = LCQuery(className: "UserNameRecord")
                query.whereKey("objectId", .equalTo(recordObjectId))
                query.limit = 1
                
                query.find { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let records):
                            if let firstRecord = records.first {
                                // 读取 dualAvatarUnlocked 字段
                                if let dualAvatarUnlocked = firstRecord["dualAvatarUnlocked"]?.boolValue {
                                    completion(dualAvatarUnlocked)
                                } else {
                                    // 如果字段不存在，默认为 false
                                    completion(false)
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
                                    completion(nil)
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
                                completion(nil)
                            }
                        }
                    }
                }
            } else {
                // 如果没有 recordObjectId，通过 userId 和 loginType 查询
                let query = LCQuery(className: "UserNameRecord")
                query.whereKey("userId", .equalTo(objectId))
                query.whereKey("loginType", .equalTo(loginType))
                query.whereKey("createdAt", .descending)
                query.limit = 1
                
                query.find { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let records):
                            if let firstRecord = records.first {
                                // 保存 recordObjectId 以便下次使用
                                let recordObjectId = firstRecord.objectId?.stringValue ?? ""
                                if !recordObjectId.isEmpty {
                                    UserDefaults.standard.set(recordObjectId, forKey: objectIdKey)
                                }
                                
                                // 读取 dualAvatarUnlocked 字段
                                if let dualAvatarUnlocked = firstRecord["dualAvatarUnlocked"]?.boolValue {
                                    completion(dualAvatarUnlocked)
                                } else {
                                    // 如果字段不存在，默认为 false
                                    completion(false)
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
                                    completion(nil)
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
                                completion(nil)
                            }
                        }
                    }
                }
            }
        }
        
        attempt()
    }
    
    // 🎯 新增：获取彩色模式开关状态
    // 🎯 新增：添加重试机制（与用户头像查询一致）
    func fetchColorfulModeEnabled(objectId: String, loginType: String, completion: @escaping (Bool?) -> Void) {
        var retryCount = 0
        
        func attempt() {
            // 首先尝试从 UserDefaults 获取 recordObjectId
            let objectIdKey = "user_name_object_id_\(objectId)_\(loginType)"
            if let recordObjectId = UserDefaults.standard.string(forKey: objectIdKey) {
                // 直接查询该记录
                let query = LCQuery(className: "UserNameRecord")
                query.whereKey("objectId", .equalTo(recordObjectId))
                query.limit = 1
                
                query.find { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let records):
                            if let firstRecord = records.first {
                                // 读取 colorfulModeEnabled 字段
                                if let colorfulModeEnabled = firstRecord["colorfulModeEnabled"]?.boolValue {
                                    completion(colorfulModeEnabled)
                                } else {
                                    // 如果字段不存在，默认为 false
                                    completion(false)
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
                                    completion(nil)
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
                                completion(nil)
                            }
                        }
                    }
                }
            } else {
                // 如果没有 recordObjectId，通过 userId 和 loginType 查询
                let query = LCQuery(className: "UserNameRecord")
                query.whereKey("userId", .equalTo(objectId))
                query.whereKey("loginType", .equalTo(loginType))
                query.whereKey("createdAt", .descending)
                query.limit = 1
                
                query.find { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let records):
                            if let firstRecord = records.first {
                                // 保存 recordObjectId 以便下次使用
                                let recordObjectId = firstRecord.objectId?.stringValue ?? ""
                                if !recordObjectId.isEmpty {
                                    UserDefaults.standard.set(recordObjectId, forKey: objectIdKey)
                                }
                                
                                // 读取 colorfulModeEnabled 字段
                                if let colorfulModeEnabled = firstRecord["colorfulModeEnabled"]?.boolValue {
                                    completion(colorfulModeEnabled)
                                } else {
                                    // 如果字段不存在，默认为 false
                                    completion(false)
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
                                    completion(nil)
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
                                completion(nil)
                            }
                        }
                    }
                }
            }
        }
        
        attempt()
    }
    
    // 🎯 新增：根据 objectId 同时获取用户名和用户类型（不限制 loginType）- 优化性能，减少查询次数
    // 🎯 新增：添加重试机制（与用户头像查询一致）
    func fetchUserNameAndLoginType(objectId: String, completion: @escaping (String?, String?, String?) -> Void) {
        var retryCount = 0
        
        func attempt() {
            // ✅ 按照开发指南：使用 LCQuery 创建查询，只根据 objectId 查询，不限制 loginType
            let query = LCQuery(className: "UserNameRecord")
            query.whereKey("userId", .equalTo(objectId))
            query.whereKey("createdAt", .descending)
            query.limit = 1
            
            query.find { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let records):
                        if let firstRecord = records.first {
                            let userName = firstRecord["userName"]?.stringValue
                            let loginType = firstRecord["loginType"]?.stringValue
                            
                            // 如果用户名不为空，缓存用户名
                            if let userName = userName, !userName.isEmpty {
                                self.cacheUserName(userName, for: objectId)
                            }
                            
                            completion(userName, loginType, nil)
                        } else {
                            // 🎯 修改：查询失败时，如果未达到最大重试次数，触发重试
                            if retryCount < LeanCloudRetryConfig.maxRetries {
                                retryCount += 1
                                let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                    attempt()
                                }
                            } else {
                                completion(nil, nil, nil)
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
                            completion(nil, nil, error.localizedDescription)
                        }
                    }
                }
            }
        }
        
        attempt()
    }
    
    
    // 获取所有UserNameRecord记录并更新全局缓存（分页获取完整内容）
    // 🎯 新增：为每页查询添加重试机制（与用户头像查询一致）
    func fetchAllUserNameRecords(completion: @escaping ([[String: Any]]?, String?) -> Void) {
        
        var allRecords: [[String: Any]] = []
        let pageSize = 1000 // 每页获取1000条记录
        let interval: TimeInterval = 1.0/17.0 // 间隔1/17秒
        var skip = 0
        var hasMore = true
        var pageCount = 0
        var totalCachedCount = 0
        
        func fetchPage() {
            guard hasMore else {
                // 所有页面获取完成，返回结果
                completion(allRecords, nil)
                return
            }
            
            pageCount += 1
            var retryCount = 0
            
            func attemptPage() {
                let urlString = "\(serverUrl)/1.1/classes/UserNameRecord?order=-createdAt&limit=\(pageSize)&skip=\(skip)"
                
                
                guard let url = URL(string: urlString) else {
                    if retryCount < LeanCloudRetryConfig.maxRetries {
                        retryCount += 1
                        let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            attemptPage()
                        }
                    } else {
                        completion(nil, "URL创建失败")
                    }
                    return
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                setLeanCloudHeaders(&request)
                request.timeoutInterval = 30.0
                
                URLSession.shared.dataTask(with: request) { data, response, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            // 🎯 修改：查询失败时，如果未达到最大重试次数，触发重试
                            if retryCount < LeanCloudRetryConfig.maxRetries {
                                retryCount += 1
                                let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                    attemptPage()
                                }
                            } else {
                                completion(nil, "请求失败: \(error.localizedDescription)")
                            }
                            return
                        }
                        
                        if let httpResponse = response as? HTTPURLResponse {
                            
                            if httpResponse.statusCode == 200 {
                                if let data = data {
                                    do {
                                        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                                        
                                        if let results = json?["results"] as? [[String: Any]] {
                                            
                                            // 更新全局缓存并统计
                                            var pageCachedCount = 0
                                            for record in results {
                                                if let objectId = record["userId"] as? String,
                                                   let userName = record["userName"] as? String,
                                                   !userName.isEmpty {
                                                    // 更新全局用户名缓存
                                                    self.cacheUserName(userName, for: objectId)
                                                    pageCachedCount += 1
                                                }
                                            }
                                            totalCachedCount += pageCachedCount
                                            
                                            
                                            // 打印前5条记录的详细信息作为示例
                                            for (_, _) in results.prefix(5).enumerated() {
                                            }
                                            
                                            if results.count > 5 {
                                            }
                                            
                                            allRecords.append(contentsOf: results)
                                            
                                            // 检查是否还有更多数据
                                            if results.count < pageSize {
                                                hasMore = false
                                            } else {
                                                skip += pageSize
                                            }
                                            
                                            // 延迟后继续获取下一页
                                            DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
                                                fetchPage()
                                            }
                                        } else {
                                            // 🎯 修改：查询失败时，如果未达到最大重试次数，触发重试
                                            if retryCount < LeanCloudRetryConfig.maxRetries {
                                                retryCount += 1
                                                let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                                                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                                    attemptPage()
                                                }
                                            } else {
                                                completion(nil, "数据格式错误")
                                            }
                                        }
                                    } catch {
                                        // 🎯 修改：查询失败时，如果未达到最大重试次数，触发重试
                                        if retryCount < LeanCloudRetryConfig.maxRetries {
                                            retryCount += 1
                                            let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                                attemptPage()
                                            }
                                        } else {
                                            completion(nil, "响应解析失败")
                                        }
                                    }
                                } else {
                                    // 🎯 修改：查询失败时，如果未达到最大重试次数，触发重试
                                    if retryCount < LeanCloudRetryConfig.maxRetries {
                                        retryCount += 1
                                        let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                            attemptPage()
                                        }
                                    } else {
                                        completion(nil, "无响应数据")
                                    }
                                }
                            } else if httpResponse.statusCode == 404 {
                                // 404错误表示表不存在，尝试自动创建表
                                self.createUserNameRecordTable { success in
                                    if success {
                                        // 表创建成功后，重新开始获取数据（重置重试计数）
                                        retryCount = 0
                                        allRecords = []
                                        skip = 0
                                        hasMore = true
                                        pageCount = 0
                                        totalCachedCount = 0
                                        fetchPage()
                                    } else {
                                        // 🎯 修改：表创建失败时，如果未达到最大重试次数，触发重试
                                        if retryCount < LeanCloudRetryConfig.maxRetries {
                                            retryCount += 1
                                            let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                                attemptPage()
                                            }
                                        } else {
                                            completion(nil, "表创建失败")
                                        }
                                    }
                                }
                            } else if httpResponse.statusCode == 429 {
                                // 🔧 修复：429错误时等待后重试（使用统一的重试延迟）
                                let delay: TimeInterval = retryCount < LeanCloudRetryConfig.maxRetries ? (retryCount == 0 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay) : 5.0
                                retryCount += 1
                                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                    if retryCount <= LeanCloudRetryConfig.maxRetries {
                                        attemptPage()
                                    } else {
                                        fetchPage() // 超过重试次数后，继续下一页
                                    }
                                }
                            } else {
                                // 🎯 修改：查询失败时，如果未达到最大重试次数，触发重试
                                if retryCount < LeanCloudRetryConfig.maxRetries {
                                    retryCount += 1
                                    let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                        attemptPage()
                                    }
                                } else {
                                    completion(nil, "请求失败，状态码: \(httpResponse.statusCode)")
                                }
                            }
                        } else {
                            // 🎯 修改：查询失败时，如果未达到最大重试次数，触发重试
                            if retryCount < LeanCloudRetryConfig.maxRetries {
                                retryCount += 1
                                let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                    attemptPage()
                                }
                            } else {
                                completion(nil, "无效响应")
                            }
                        }
                    }
                }.resume()
            }
            
            attemptPage()
        }
        
        // 开始获取第一页
        fetchPage()
    }
    
    // 获取用户邮箱 - 遵循数据存储开发指南，使用 LCQuery（从 UserNameRecord 表查询 userEmail 字段）
    // 🎯 新增：添加重试机制（与用户头像查询一致）
    func fetchUserEmail(objectId: String, loginType: String, completion: @escaping (String?, String?) -> Void) {
        var retryCount = 0
        
        func attempt() {
            // ✅ 按照开发指南：使用 LCQuery 创建查询
            let query = LCQuery(className: "UserNameRecord")
            query.whereKey("userId", .equalTo(objectId))
            query.whereKey("loginType", .equalTo(loginType))
            query.whereKey("createdAt", .descending)
            query.limit = 1
            
            query.find { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let records):
                        if let firstRecord = records.first,
                           let userEmail = firstRecord["userEmail"]?.stringValue,
                           !userEmail.isEmpty {
                            let recordObjectId = firstRecord.objectId?.stringValue ?? ""
                            if !recordObjectId.isEmpty {
                                let cacheKey = "user_name_object_id_\(objectId)_\(loginType)"
                                UserDefaults.standard.set(recordObjectId, forKey: cacheKey)
                                UserDefaults.standard.set(true, forKey: "user_name_record_created_\(objectId)_\(loginType)")
                            }
                            // 缓存获取到的邮箱
                            self.cacheUserEmail(userEmail, for: objectId)
                            completion(userEmail, nil)
                        } else {
                            // 🎯 修改：查询失败时，如果未达到最大重试次数，触发重试
                            if retryCount < LeanCloudRetryConfig.maxRetries {
                                retryCount += 1
                                let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                    attempt()
                                }
                            } else {
                                completion(nil, nil)  // 没有记录或邮箱为空不是错误，返回nil, nil
                            }
                        }
                    case .failure(let error):
                        // 如果是表不存在错误，尝试自动创建表
                        if error.localizedDescription.contains("404") || error.localizedDescription.contains("not found") {
                            self.createUserNameRecordTable { success in
                                if success {
                                    // 表创建成功后，重新尝试获取邮箱（重置重试计数）
                                    retryCount = 0
                                    attempt()
                                } else {
                                    // 🎯 修改：表创建失败时，如果未达到最大重试次数，触发重试
                                    if retryCount < LeanCloudRetryConfig.maxRetries {
                                        retryCount += 1
                                        let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                            attempt()
                                        }
                                    } else {
                                        completion(nil, "表创建失败")
                                    }
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
                                completion(nil, error.localizedDescription)
                            }
                        }
                    }
                }
            }
        }
        
        attempt()
    }
    
    // 根据 objectId 查询用户邮箱（不限制 loginType）- 用于处理 loginType 未知的情况
    // 🎯 新增：添加重试机制（与用户头像查询一致）
    func fetchUserEmailByUserId(objectId: String, completion: @escaping (String?, String?) -> Void) {
        // 🎯 检查缓存
        if let cachedEmail = self.getCachedUserEmail(for: objectId), !cachedEmail.isEmpty {
            completion(cachedEmail, nil)
            return
        }
        
        var retryCount = 0
        
        func attempt() {
            // ✅ 按照开发指南：使用 LCQuery 创建查询，只根据 objectId 查询，不限制 loginType
            let query = LCQuery(className: "UserNameRecord")
            query.whereKey("userId", .equalTo(objectId))
            query.whereKey("createdAt", .descending)
            query.limit = 1
            
            query.find { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let records):
                        if let firstRecord = records.first,
                           let userEmail = firstRecord["userEmail"]?.stringValue,
                           !userEmail.isEmpty {
                            // 缓存获取到的邮箱
                            self.cacheUserEmail(userEmail, for: objectId)
                            completion(userEmail, nil)
                        } else {
                            // 🎯 修改：查询失败时，如果未达到最大重试次数，触发重试
                            if retryCount < LeanCloudRetryConfig.maxRetries {
                                retryCount += 1
                                let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                    attempt()
                                }
                            } else {
                                completion(nil, nil)
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
                            completion(nil, error.localizedDescription)
                        }
                    }
                }
            }
        }
        
        attempt()
    }
}
