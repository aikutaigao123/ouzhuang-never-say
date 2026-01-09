//
//  LeanCloudService+CurrentUserSync.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation
import LeanCloud

// MARK: - 当前用户数据同步功能
extension LeanCloudService {
    
    // 同步当前用户的头像数据到UserScore表
    func syncCurrentUserAvatarData(objectId: String, loginType: String, newAvatar: String, completion: @escaping (Bool) -> Void) {
        
        // 1. 查找用户的UserScore记录
        let urlString = "\(serverUrl)/1.1/classes/UserScore?where={\"userId\":\"\(objectId)\"}&limit=1"
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if error != nil {
                    completion(false)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200, let data = data {
                        do {
                            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                            if let results = json?["results"] as? [[String: Any]], let firstResult = results.first {
                                if let objectId = firstResult["objectId"] as? String {
                                    // 找到记录，更新头像
                                    let updateData: [String: Any] = [
                                        "userAvatar": newAvatar,
                                        "lastUpdated": ISO8601DateFormatter().string(from: Date())
                                    ]
                                    
                                    self.updateUserScoreData(objectId: objectId, updateData: updateData) { success in
                                        if success {
                                        } else {
                                        }
                                    }
                                    completion(true)
                                } else {
                                    completion(false)
                                }
                            } else {
                                completion(false)
                            }
                        } catch {
                            completion(false)
                        }
                    } else {
                        completion(false)
                    }
                } else {
                    completion(false)
                }
            }
        }.resume()
    }
    
    // 同步当前用户的用户名数据到UserScore表
    func syncCurrentUserNameData(objectId: String, loginType: String, newUserName: String, completion: @escaping (Bool) -> Void) {
        
        // 1. 查找用户的UserScore记录
        let urlString = "\(serverUrl)/1.1/classes/UserScore?where={\"userId\":\"\(objectId)\"}&limit=1"
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if error != nil {
                    completion(false)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200, let data = data {
                        do {
                            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                            if let results = json?["results"] as? [[String: Any]], let firstResult = results.first {
                                if let objectId = firstResult["objectId"] as? String {
                                    // 找到记录，更新用户名
                                    let updateData: [String: Any] = [
                                        "userName": newUserName,
                                        "lastUpdated": ISO8601DateFormatter().string(from: Date())
                                    ]
                                    
                                    self.updateUserScoreData(objectId: objectId, updateData: updateData) { success in
                                        if success {
                                        } else {
                                        }
                                    }
                                    completion(true)
                                } else {
                                    completion(false)
                                }
                            } else {
                                completion(false)
                            }
                        } catch {
                            completion(false)
                        }
                    } else {
                        completion(false)
                    }
                } else {
                    completion(false)
                }
            }
        }.resume()
    }
    
    // 同步用户头像到所有相关表 - 已禁用，只保留本地缓存更新
    func syncAvatarToAllTables(userId: String, loginType: String, newAvatar: String, completion: @escaping (Bool) -> Void) {
        
        // 只更新本地缓存，不再同步到其他表
        updateLocalAvatarCache(userId: userId, newAvatar: newAvatar) { success in
            completion(success)
        }
    }
    
    // 同步InternalLoginRecord表的头像
    private func syncInternalLoginRecordAvatar(userId: String, newAvatar: String, completion: @escaping (Bool) -> Void) {
        // 查找用户的所有InternalLoginRecord记录
        let urlString = "\(serverUrl)/1.1/classes/InternalLoginRecord?where={\"user_id\":\"\(userId)\"}&limit=1000"
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if error != nil {
                    completion(false)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200,
                      let data = data else {
                    completion(false)
                    return
                }
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    guard let results = json?["results"] as? [[String: Any]] else {
                        completion(false)
                        return
                    }
                    
                    if results.isEmpty {
                        completion(true)
                        return
                    }
                    
                    // 分批更新所有记录（每批3条，避免API限流）
                    self.updateInternalLoginRecordsInBatches(results: results, newAvatar: newAvatar, batchSize: 3) { successCount, totalCount in
                        let allSuccess = successCount == totalCount
                        
                        
                        completion(allSuccess)
                    }
                    
                } catch {
                    completion(false)
                }
            }
        }.resume()
    }
    
    // 分批更新InternalLoginRecord记录
    private func updateInternalLoginRecordsInBatches(results: [[String: Any]], newAvatar: String, batchSize: Int, completion: @escaping (Int, Int) -> Void) {
        let totalCount = results.count
        var successCount = 0
        var currentIndex = 0
        
        
        func processNextBatch() {
            let endIndex = min(currentIndex + batchSize, totalCount)
            let batch = Array(results[currentIndex..<endIndex])
            
            
            let batchGroup = DispatchGroup()
            var batchResults: [Bool] = []
            
            for result in batch {
                guard let objectId = result["objectId"] as? String else { continue }
                
                batchGroup.enter()
                self.updateInternalLoginRecordAvatarWithRetry(objectId: objectId, newAvatar: newAvatar, maxRetries: 2) { success in
                    batchResults.append(success)
                    if success {
                        successCount += 1
                    }
                    batchGroup.leave()
                }
            }
            
            batchGroup.notify(queue: .main) {
                let _ = batchResults.filter { $0 }.count
                
                currentIndex = endIndex
                
                if currentIndex < totalCount {
                    // 批次间延迟，避免API限流
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        processNextBatch()
                    }
                } else {
                    // 所有批次完成
                    completion(successCount, totalCount)
                }
            }
        }
        
        processNextBatch()
    }
    
    // 带重试机制的更新单个InternalLoginRecord记录
    private func updateInternalLoginRecordAvatarWithRetry(objectId: String, newAvatar: String, maxRetries: Int, completion: @escaping (Bool) -> Void) {
        var retryCount = 0
        
        func attemptUpdate() {
            self.updateInternalLoginRecordAvatar(objectId: objectId, newAvatar: newAvatar) { success in
                if success {
                    completion(true)
                } else if retryCount < maxRetries {
                    retryCount += 1
                    // 重试前延迟
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        attemptUpdate()
                    }
                } else {
                    completion(false)
                }
            }
        }
        
        attemptUpdate()
    }
    
    // 更新单个InternalLoginRecord记录的头像
    private func updateInternalLoginRecordAvatar(objectId: String, newAvatar: String, completion: @escaping (Bool) -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/InternalLoginRecord/\(objectId)"
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        setLeanCloudHeaders(&request, contentType: "application/json")
        request.timeoutInterval = 10.0
        
        let updateData: [String: Any] = [
            "userAvatar": newAvatar
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: updateData)
        } catch {
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if error != nil {
                    completion(false)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false)
                    return
                }
                
                completion(httpResponse.statusCode == 200)
            }
        }.resume()
    }
    
    // 同步DiamondRecord表的头像 - 遵循数据存储开发指南，使用 LCQuery
    private func syncDiamondRecordAvatar(userId: String, newAvatar: String, completion: @escaping (Bool) -> Void) {
        // ✅ 按照开发指南：使用 LCQuery 创建查询
        let query = LCQuery(className: "DiamondRecord")
        query.whereKey("userId", .equalTo(userId))
        query.limit = 1000
        
        query.find { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let records):
                    if records.isEmpty {
                        completion(true)
                        return
                    }
                    
                    // 转换为字典数组
                    let results = records.compactMap { record -> [String: Any]? in
                        guard let objectId = record.objectId?.stringValue else { return nil }
                        var dict: [String: Any] = [:]
                        dict["objectId"] = objectId
                        return dict
                    }
                    
                    // 分批更新所有记录（每批3条，避免API限流）
                    self.updateDiamondRecordsInBatches(results: results, newAvatar: newAvatar, batchSize: 3) { successCount, totalCount in
                        let allSuccess = successCount == totalCount
                        completion(allSuccess)
                    }
                case .failure:
                    completion(false)
                }
            }
        }
    }
    
    // 分批更新DiamondRecord记录
    private func updateDiamondRecordsInBatches(results: [[String: Any]], newAvatar: String, batchSize: Int, completion: @escaping (Int, Int) -> Void) {
        let totalCount = results.count
        var successCount = 0
        var currentIndex = 0
        
        
        func processNextBatch() {
            let endIndex = min(currentIndex + batchSize, totalCount)
            let batch = Array(results[currentIndex..<endIndex])
            
            
            let batchGroup = DispatchGroup()
            var batchResults: [Bool] = []
            
            for result in batch {
                guard let objectId = result["objectId"] as? String else { continue }
                
                batchGroup.enter()
                self.updateDiamondRecordAvatarWithRetry(objectId: objectId, newAvatar: newAvatar, maxRetries: 2) { success in
                    batchResults.append(success)
                    if success {
                        successCount += 1
                    }
                    batchGroup.leave()
                }
            }
            
            batchGroup.notify(queue: .main) {
                let _ = batchResults.filter { $0 }.count
                
                currentIndex = endIndex
                
                if currentIndex < totalCount {
                    // 批次间延迟，避免API限流
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        processNextBatch()
                    }
                } else {
                    // 所有批次完成
                    completion(successCount, totalCount)
                }
            }
        }
        
        processNextBatch()
    }
    
    // 带重试机制的更新单个DiamondRecord记录
    private func updateDiamondRecordAvatarWithRetry(objectId: String, newAvatar: String, maxRetries: Int, completion: @escaping (Bool) -> Void) {
        var retryCount = 0
        
        func attemptUpdate() {
            self.updateDiamondRecordAvatar(objectId: objectId, newAvatar: newAvatar) { success in
                if success {
                    completion(true)
                } else if retryCount < maxRetries {
                    retryCount += 1
                    // 重试前延迟
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        attemptUpdate()
                    }
                } else {
                    completion(false)
                }
            }
        }
        
        attemptUpdate()
    }
    
    // 更新单个DiamondRecord记录的头像
    private func updateDiamondRecordAvatar(objectId: String, newAvatar: String, completion: @escaping (Bool) -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/DiamondRecord/\(objectId)"
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        setLeanCloudHeaders(&request, contentType: "application/json")
        request.timeoutInterval = 10.0
        
        let updateData: [String: Any] = [
            "userAvatar": newAvatar
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: updateData)
        } catch {
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if error != nil {
                    completion(false)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false)
                    return
                }
                
                completion(httpResponse.statusCode == 200)
            }
        }.resume()
    }
    
    // 更新本地头像缓存
    private func updateLocalAvatarCache(userId: String, newAvatar: String, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            // 🔍 检查更新前的 UserDefaults 值
            let _ = UserDefaultsManager.getCustomAvatar(userId: userId)
            
            // 1. 更新UserDefaults
            UserDefaults.standard.set(newAvatar, forKey: "custom_avatar_\(userId)")
            
            // 2. 更新LeanCloudService内存缓存
            self.userAvatarCache[userId] = (avatar: newAvatar, timestamp: Date())
            
            completion(true)
        }
    }
    
    // 检查并修复用户头像数据一致性
    func checkAndFixAvatarConsistency(userId: String, completion: @escaping (Bool) -> Void) {
        // 🔍 先获取 UserDefaults 中的当前值
        let userDefaultsAvatar = UserDefaultsManager.getCustomAvatar(userId: userId)
        
        // 🎯 修改：使用 fetchUserAvatarByUserId，不依赖 loginType，直接从 UserAvatarRecord 表获取
        fetchUserAvatarByUserId(objectId: userId) { authoritativeAvatar, error in
            if error != nil {
                completion(false)
                return
            }
            
            guard let correctAvatar = authoritativeAvatar, !correctAvatar.isEmpty else {
                completion(true)
                return
            }
            
            // 🔍 检查 UserDefaults 与服务器数据是否一致
            if let defaultsAvatar = userDefaultsAvatar, !defaultsAvatar.isEmpty {
                if defaultsAvatar != correctAvatar {
                } else {
                }
            } else {
            }
            
            // 2. 检查并修复所有相关表
            self.syncAvatarToAllTables(userId: userId, loginType: "guest", newAvatar: correctAvatar) { success in
                completion(success)
            }
        }
    }
    
    // 批量检查所有用户的头像数据一致性
    func checkAllUsersAvatarConsistency(completion: @escaping (Bool) -> Void) {
        
        // 获取所有UserAvatarRecord记录
        fetchAllUserAvatarRecords { records, error in
            if error != nil {
                completion(false)
                return
            }
            
            guard let userRecords = records, !userRecords.isEmpty else {
                completion(true)
                return
            }
            
            
            let dispatchGroup = DispatchGroup()
            var checkResults: [Bool] = []
            
            for record in userRecords {
                guard let userId = record["userId"] as? String,
                      let _ = record["loginType"] as? String else { continue }
                
                dispatchGroup.enter()
                self.checkAndFixAvatarConsistency(userId: userId) { success in
                    checkResults.append(success)
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                let _ = checkResults.filter { $0 }.count
                let allSuccess = checkResults.allSatisfy { $0 }
                
                
                completion(allSuccess)
            }
        }
    }
}
