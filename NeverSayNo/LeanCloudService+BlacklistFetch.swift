//
//  LeanCloudService+BlacklistFetch.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation

// MARK: - 黑名单获取功能
extension LeanCloudService {
    // 从LeanCloud获取黑名单ID列表（包括设备ID和用户ID）
    // 🎯 新增：添加重试机制（与用户头像查询一致）
    func fetchBlacklist(completion: @escaping ([String]?, String?) -> Void) {
        var retryCount = 0
        
        func attempt() {
            let urlString = "\(serverUrl)/1.1/classes/Blacklist?order=-createdAt&limit=1000"
            guard let url = URL(string: urlString) else {
                if retryCount < LeanCloudRetryConfig.maxRetries {
                    retryCount += 1
                    let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        attempt()
                    }
                } else {
                    completion([], "无效的URL")
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
                            return
                        }
                        // 🎯 使用缓存：网络错误时使用最近一次成功的黑名单数据（参考用户头像缓存机制）
                        if let cached = self.getCachedBlacklist(), !cached.isEmpty {
                            completion(cached, nil)
                        } else {
                            completion([], "获取失败: \(error.localizedDescription)")
                        }
                        return
                    }
                    
                    if let httpResponse = response as? HTTPURLResponse {
                        
                        if httpResponse.statusCode == 200, let data = data {
                            do {
                                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                                
                                if let results = json?["results"] as? [[String: Any]] {
                                    
                                    // 打印第一条记录的字段信息
                                    _ = results.first
                                    
                                    var blacklistedIds: [String] = []
                                    
                                    for blacklistDict in results {
                                        // 检查是否已过期
                                        var isExpired = false
                                        if let expiresAtDict = blacklistDict["expires_at"] as? [String: Any],
                                           let expiresAtString = expiresAtDict["iso"] as? String {
                                            let formatter = ISO8601DateFormatter()
                                            if let expiresAt = formatter.date(from: expiresAtString) {
                                                let now = Date()
                                                if now > expiresAt {
                                                    isExpired = true
                                                }
                                            }
                                        }
                                        
                                        if !isExpired {
                                            // 🎯 修复：添加用户ID（reported_user_id）- 这是最重要的字段
                                            if let reportedUserId = blacklistDict["reported_user_id"] as? String {
                                                blacklistedIds.append(reportedUserId)
                                            }
                                            
                                            // 添加设备ID
                                            if let deviceId = blacklistDict["deviceId"] as? String {
                                                blacklistedIds.append(deviceId)
                                            }
                                            
                                            // 添加用户名
                                            if let reportedUserName = blacklistDict["reported_user_name"] as? String {
                                                blacklistedIds.append(reportedUserName)
                                            }
                                        }
                                    }
                                    
                                    if !blacklistedIds.isEmpty {
                                    }
                                    
                                    // 🎯 更新缓存：保存成功的黑名单数据（参考用户头像缓存机制）
                                    self.cacheBlacklist(blacklistedIds)
                                    
                                    completion(blacklistedIds, nil)
                                } else {
                                    completion([], nil)
                                }
                            } catch {
                                // 🎯 使用缓存：解析失败时使用缓存的黑名单数据（参考用户头像缓存机制）
                                if let cached = self.getCachedBlacklist(), !cached.isEmpty {
                                    completion(cached, nil)
                                } else {
                                    // 🎯 修改：查询失败时，如果未达到最大重试次数，触发重试
                                    if retryCount < LeanCloudRetryConfig.maxRetries {
                                        retryCount += 1
                                        let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                            attempt()
                                        }
                                    } else {
                                        completion([], "数据解析失败: \(error.localizedDescription)")
                                    }
                                }
                            }
                        } else if httpResponse.statusCode == 404 {
                            // 404错误表示表不存在，尝试自动创建表
                            self.createBlacklistTable { tableCreated in
                                if tableCreated {
                                    // 表创建成功后，重新尝试获取黑名单（重置重试计数）
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
                                        completion([], "表创建失败")
                                    }
                                }
                            }
                            return
                        } else {
                            var errorMessage = "服务器错误: \(httpResponse.statusCode)"
                            if let data = data {
                                do {
                                    let errorJson = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                                    if let error = errorJson?["error"] as? String {
                                        errorMessage = "LeanCloud错误: \(error)"
                                    }
                                } catch {
                                    errorMessage = "服务器错误: \(httpResponse.statusCode)"
                                }
                            }
                            
                            // 🎯 修改：查询失败时，如果未达到最大重试次数，触发重试
                            if retryCount < LeanCloudRetryConfig.maxRetries {
                                retryCount += 1
                                let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                    attempt()
                                }
                            } else {
                                // 🎯 使用缓存：对于 "Too many requests" 等错误，使用缓存的黑名单数据（参考用户头像缓存机制）
                                if let cached = self.getCachedBlacklist(), !cached.isEmpty {
                                    if errorMessage.contains("Too many requests") || httpResponse.statusCode == 429 {
                                    } else {
                                    }
                                    completion(cached, nil)
                                } else {
                                    if errorMessage.contains("Too many requests") || httpResponse.statusCode == 429 {
                                    }
                                    completion([], errorMessage)
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
                            // 🎯 使用缓存：无效响应时使用缓存的黑名单数据（参考用户头像缓存机制）
                            if let cached = self.getCachedBlacklist(), !cached.isEmpty {
                                completion(cached, nil)
                            } else {
                                completion([], "无效的服务器响应")
                            }
                        }
                    }
                }
            }.resume()
        }
        
        attempt()
    }
    
    // 从LeanCloud获取黑名单用户ID列表
    // 🎯 新增：添加重试机制（与用户头像查询一致）
    func fetchUserBlacklist(completion: @escaping ([String]?, String?) -> Void) {
        var retryCount = 0
        
        func attempt() {
            let urlString = "\(serverUrl)/1.1/classes/Blacklist?order=-createdAt&limit=1000"
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
                            completion(nil, "获取失败: \(error.localizedDescription)")
                        }
                        return
                    }
                    
                    if let httpResponse = response as? HTTPURLResponse {
                        
                        if httpResponse.statusCode == 200, let data = data {
                            do {
                                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                                
                                if let results = json?["results"] as? [[String: Any]] {
                                    
                                    let blacklistedUserIds = results.compactMap { blacklistDict -> String? in
                                        // 检查是否有reported_user_id字段（存储的是设备ID）
                                        guard let deviceId = blacklistDict["reported_user_id"] as? String else {
                                            return nil
                                        }
                                        
                                        // 检查是否已过期
                                        if let expiresAtDict = blacklistDict["expires_at"] as? [String: Any],
                                           let expiresAtString = expiresAtDict["iso"] as? String {
                                            let formatter = ISO8601DateFormatter()
                                            if let expiresAt = formatter.date(from: expiresAtString) {
                                                let now = Date()
                                                if now > expiresAt {
                                                    return nil // 已过期，不返回
                                                }
                                            }
                                        }
                                        
                                        return deviceId
                                    }
                                    
                                    completion(blacklistedUserIds, nil)
                                } else {
                                    completion([], nil)
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
                            var errorMessage = "服务器错误: \(httpResponse.statusCode)"
                            if let data = data {
                                do {
                                    let errorJson = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                                    if let error = errorJson?["error"] as? String {
                                        errorMessage = "LeanCloud错误: \(error)"
                                    }
                                } catch {
                                    errorMessage = "服务器错误: \(httpResponse.statusCode)"
                                }
                            }
                            // 🎯 修改：查询失败时，如果未达到最大重试次数，触发重试
                            if retryCount < LeanCloudRetryConfig.maxRetries {
                                retryCount += 1
                                let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                    attempt()
                                }
                            } else {
                                completion(nil, errorMessage)
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
                            completion(nil, "无效的服务器响应")
                        }
                    }
                }
            }.resume()
        }
        
        attempt()
    }
}
