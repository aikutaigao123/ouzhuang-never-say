//
//  LeanCloudService+UserAvatar.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation
import UIKit
import LeanCloud

// MARK: - 用户头像相关功能
extension LeanCloudService {
    
    // 获取用户头像 - 遵循数据存储开发指南，使用 LCQuery
    func fetchUserAvatar(objectId: String, loginType: String, completion: @escaping (String?, String?) -> Void) {
        // ✅ 按照开发指南：使用 LCQuery 创建查询
        let query = LCQuery(className: "UserAvatarRecord")
        query.whereKey("userId", .equalTo(objectId))
        query.whereKey("loginType", .equalTo(loginType))
        query.whereKey("updatedAt", .descending) // 🔧 统一：使用 updatedAt（与钻石查询一致）
        query.limit = 1
        
        query.find { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let records):
                    if let firstRecord = records.first,
                       let userAvatar = firstRecord["userAvatar"]?.stringValue {
                        let recordUserId = firstRecord["userId"]?.stringValue ?? "unknown"
                        let recordLoginType = firstRecord["loginType"]?.stringValue ?? "unknown"
                        
                        // 验证查询到的记录的 userId 和 loginType 是否匹配
                        if recordUserId != objectId || recordLoginType != loginType {
                        }
                        // 缓存获取到的头像
                        self.cacheUserAvatar(userAvatar, for: objectId)
                        completion(userAvatar, nil)
                    } else {
                        completion(nil, "未找到用户的头像记录")
                    }
                case .failure(let error):
                    completion(nil, "获取失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // 🎯 新增：根据 objectId 查询用户头像（不限制 loginType）- 用于处理 loginType 未知的情况
    func fetchUserAvatarByUserId(objectId: String, completion: @escaping (String?, String?) -> Void) {
        // ✅ 按照开发指南：使用 LCQuery 创建查询，只根据 objectId 查询，不限制 loginType
        let query = LCQuery(className: "UserAvatarRecord")
        query.whereKey("userId", .equalTo(objectId))
        query.whereKey("updatedAt", .descending) // 🔧 统一：使用 updatedAt（与钻石查询一致）
        query.limit = 1
        
        query.find { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let records):
                    if let firstRecord = records.first,
                       let userAvatar = firstRecord["userAvatar"]?.stringValue,
                       !userAvatar.isEmpty {
                        // 缓存获取到的头像
                        self.cacheUserAvatar(userAvatar, for: objectId)
                        completion(userAvatar, nil)
                    } else {
                        completion(nil, "未找到头像记录")
                    }
                case .failure(let error):
                    completion(nil, "获取失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // 创建用户头像记录 - ✅ 遵循 Swift 开发指南，使用 LCObject 的 save() 方法
    func createUserAvatarRecord(objectId: String, loginType: String, userAvatar: String, completion: @escaping (Bool) -> Void) {
        
        // 验证objectId格式：对于Apple用户，objectId应该是Apple ID标识符（类似 000737.xxx），不应该是objectId格式（纯字母数字，24字符）
        if loginType == "apple" {
            if objectId.count == 24 && objectId.allSatisfy({ $0.isLetter || $0.isNumber }) {
            }
        }
        
        do {
            // ✅ 按照开发指南：构建 LCObject
            let record = LCObject(className: "UserAvatarRecord")
        
        // 获取设备ID
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
        
        // 获取用户名（从UserDefaults或使用默认值）
        let userName = UserDefaultsManager.getCurrentUserName()
        
        // 获取邮箱（从UserDefaults或使用默认值）
        let userEmail = UserDefaultsManager.getCurrentUserEmail()
        
        
            // ✅ 按照开发指南：为属性赋值
            try record.set("userId", value: objectId)
            try record.set("loginType", value: loginType)
            try record.set("userName", value: userName)
            try record.set("userEmail", value: userEmail)
            try record.set("userAvatar", value: userAvatar)
            try record.set("deviceId", value: deviceID)
            try record.set("deviceTime", value: ISO8601DateFormatter().string(from: Date()))
            
            // ✅ 按照开发指南：将对象保存到云端
            _ = record.save { result in
            DispatchQueue.main.async {
                    switch result {
                    case .success:
                        completion(true)
                    case .failure(let error):
                        // 如果错误是表不存在，尝试自动创建表
                        if error.code == 404 || error.code == 1 {
                        self.createUserAvatarRecordTable { success in
                            if success {
                                    // 重新尝试创建记录
                                    self.createUserAvatarRecord(objectId: objectId, loginType: loginType, userAvatar: userAvatar, completion: completion)
                            } else {
                                completion(false)
                            }
                        }
                    } else {
                        completion(false)
                        }
                    }
                }
                    }
        } catch {
            DispatchQueue.main.async {
                    completion(false)
                }
            }
    }
    
    // 更新用户头像记录 - 遵循数据存储开发指南，使用 LCQuery
    // 🔧 优化：如果有记录则更新，没有记录则创建（只根据 userId 查询，不限制 loginType）
    func updateUserAvatarRecord(objectId: String, loginType: String, userAvatar: String, completion: @escaping (Bool) -> Void) {
        
        // ✅ 按照开发指南：使用 LCQuery 创建查询，只根据 userId 查询，不限制 loginType
        // 这样可以确保即使 loginType 不同，也能找到并更新现有记录
        let query = LCQuery(className: "UserAvatarRecord")
        query.whereKey("userId", .equalTo(objectId))
        query.whereKey("updatedAt", .descending) // 🔧 统一：使用 updatedAt（与钻石查询一致）
        query.limit = 1
        
        query.find { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let records):
                    if let firstRecord = records.first,
                       let recordObjectId = firstRecord.objectId?.stringValue {
                        // 🔧 找到现有记录，更新它
                        self.updateExistingAvatarRecord(objectId: recordObjectId, userAvatar: userAvatar, completion: completion)
                    } else {
                        // 没有找到记录，创建新记录
                        self.createUserAvatarRecord(objectId: objectId, loginType: loginType, userAvatar: userAvatar, completion: completion)
                    }
                case .failure:
                    // 查询失败，尝试创建新记录
                    self.createUserAvatarRecord(objectId: objectId, loginType: loginType, userAvatar: userAvatar, completion: completion)
                }
            }
        }
    }
    
    // 更新现有的头像记录 - ✅ 遵循 Swift 开发指南，使用 LCObject 的 save() 方法
    private func updateExistingAvatarRecord(objectId: String, userAvatar: String, completion: @escaping (Bool) -> Void) {
        
        do {
            // ✅ 按照开发指南：构建已存在的 LCObject（通过 objectId）
            let record = LCObject(className: "UserAvatarRecord", objectId: objectId)
            
            // ✅ 按照开发指南：指定需要更新的属性名和属性值
            try record.set("userAvatar", value: userAvatar)
            try record.set("deviceTime", value: ISO8601DateFormatter().string(from: Date()))
            
            // ✅ 按照开发指南：调用 save 方法更新对象
            _ = record.save { result in
            DispatchQueue.main.async {
                    switch result {
                    case .success:
                        completion(true)
                    case .failure:
                        completion(false)
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                    completion(false)
                }
            }
    }
    
    // MARK: - 改进的上传逻辑
    
    // 智能上传用户头像（检查是否存在，不存在则创建，存在则更新）
    func uploadUserAvatarIfNotExists(objectId: String, loginType: String, userAvatar: String, completion: @escaping (Bool, String) -> Void) {
        
        // 1. 先查询是否存在记录
        fetchUserAvatar(objectId: objectId, loginType: loginType) { existingAvatar, error in
            if let error = error {
                completion(false, "查询失败: \(error)")
                return
            }
            
            if existingAvatar != nil {
                // 2. 如果存在，更新记录
                self.updateUserAvatarRecord(objectId: objectId, loginType: loginType, userAvatar: userAvatar) { success in
                    if success {
                        completion(true, "头像记录更新成功")
                    } else {
                        completion(false, "头像记录更新失败")
                    }
                }
            } else {
                // 3. 如果不存在，创建新记录
                self.createUserAvatarRecord(objectId: objectId, loginType: loginType, userAvatar: userAvatar) { success in
                    if success {
                        completion(true, "头像记录创建成功")
                    } else {
                        completion(false, "头像记录创建失败")
                    }
                }
            }
        }
    }
    
    // 检查用户头像记录是否存在
    func checkUserAvatarRecordExists(objectId: String, loginType: String, completion: @escaping (Bool, String?) -> Void) {
        
        fetchUserAvatar(objectId: objectId, loginType: loginType) { existingAvatar, error in
            if let error = error {
                completion(false, error)
                return
            }
            
            let exists = existingAvatar != nil
            if exists {
            }
            
            completion(exists, existingAvatar)
        }
    }
    
    // 🎯 新增：生成随机emoji头像
    private func generateRandomEmojiAvatar() -> String {
        return EmojiList.allEmojis.randomElement() ?? "🙂"
    }
    
    // 🎯 新增：自动检查并创建当前用户的UserAvatarRecord（如果不存在）
    func ensureCurrentUserAvatarRecordExists(
        objectId: String,
        loginType: String,
        userAvatar: String? = nil,
        completion: @escaping (Bool, String) -> Void
    ) {
        // 1. 先查询是否存在记录
        fetchUserAvatarByUserId(objectId: objectId) { existingAvatar, error in
            // 区分真正的错误和"未找到记录"：如果是"未找到头像记录"或"未找到用户的头像记录"，应该继续创建流程
            if let error = error, !error.contains("未找到") {
                // 真正的错误（如网络错误、权限错误等）
                completion(false, "查询失败: \(error)")
                return
            }
            
            if let existingAvatar = existingAvatar, !existingAvatar.isEmpty {
                // 2. 如果已存在记录，直接返回成功
                completion(true, "记录已存在")
                return
            }
            
            // 3. 如果不存在，自动创建新记录
            // 获取头像：优先使用传入参数，其次生成随机emoji
            let finalAvatar: String
            if let avatar = userAvatar, !avatar.isEmpty {
                finalAvatar = avatar
            } else {
                // 🎯 新增：生成随机emoji头像
                finalAvatar = self.generateRandomEmojiAvatar()
            }
            
            // 创建新记录
            self.createUserAvatarRecord(objectId: objectId, loginType: loginType, userAvatar: finalAvatar) { success in
                if success {
                    // 更新本地缓存和UserDefaults
                    self.cacheUserAvatar(finalAvatar, for: objectId)
                    UserDefaults.standard.set(finalAvatar, forKey: "custom_avatar_\(objectId)")
                    
                    // 发送通知更新UI
                    NotificationCenter.default.post(
                        name: NSNotification.Name("UserAvatarUpdated"),
                        object: nil,
                        userInfo: [
                            "userAvatar": finalAvatar,
                            "userId": objectId
                        ]
                    )
                    
                    completion(true, "记录创建成功")
                } else {
                    completion(false, "记录创建失败")
                }
            }
        }
    }
    
    // 获取所有UserAvatarRecord记录（完整内容，无限制）
    // 🎯 新增：为每页查询添加重试机制（与用户头像查询一致）
    func fetchAllUserAvatarRecords(completion: @escaping ([[String: Any]]?, String?) -> Void) {
        
        var allRecords: [[String: Any]] = []
        let pageSize = 1000 // 每页获取1000条记录
        var skip = 0
        var hasMore = true
        
        let dispatchGroup = DispatchGroup()
        
        func fetchPage() {
            guard hasMore else {
                dispatchGroup.leave()
                return
            }
            
            var retryCount = 0
            
            func attemptPage() {
                let urlString = "\(serverUrl)/1.1/classes/UserAvatarRecord?order=-createdAt&limit=\(pageSize)&skip=\(skip)"
                
                guard let url = URL(string: urlString) else {
                    if retryCount < LeanCloudRetryConfig.maxRetries {
                        retryCount += 1
                        let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            attemptPage()
                        }
                    } else {
                        completion(nil, "URL创建失败")
                        dispatchGroup.leave()
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
                                dispatchGroup.leave()
                            }
                            return
                        }
                        
                        if let httpResponse = response as? HTTPURLResponse {
                            if httpResponse.statusCode == 200 {
                                if let data = data {
                                    do {
                                        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                                        
                                        if let results = json?["results"] as? [[String: Any]] {
                                            allRecords.append(contentsOf: results)
                                            
                                            // 检查是否还有更多数据
                                            if results.count < pageSize {
                                                hasMore = false
                                                // 数据获取完成
                                                dispatchGroup.leave()
                                            } else {
                                                skip += pageSize
                                                fetchPage() // 继续获取下一页，不调用leave
                                            }
                                        } else {
                                            dispatchGroup.leave()
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
                                            dispatchGroup.leave()
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
                                        dispatchGroup.leave()
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
                                    dispatchGroup.leave()
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
                                dispatchGroup.leave()
                            }
                        }
                    }
                }.resume()
            }
            
            attemptPage()
        }
        
        dispatchGroup.enter()
        fetchPage()
        
        dispatchGroup.notify(queue: .main) {
            if allRecords.isEmpty {
                completion(nil, "未能获取到任何数据")
            } else {
                completion(allRecords, nil)
            }
        }
    }
    
}
