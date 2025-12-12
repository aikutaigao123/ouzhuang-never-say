//
//  LeanCloudService+BlacklistTable.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation

// MARK: - 黑名单表管理功能
extension LeanCloudService {
    
    // 创建Blacklist表
    func createBlacklistTable(completion: @escaping (Bool) -> Void) {
        // 通过插入一条测试记录来创建表
        let testData: [String: Any] = [
            "reported_user_id": "test_device_id",
            "reported_user_name": "测试用户",
            "deviceId": "test_device_id",
            "expires_at": [
                "iso": ISO8601DateFormatter().string(from: Date().addingTimeInterval(86400)) // 1天后过期
            ]
        ]
        
        let urlString = "\(serverUrl)/1.1/classes/Blacklist"
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: testData)
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
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 201 {
                        // 删除测试记录
                        if let data = data {
                            do {
                                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                                if let objectId = json?["objectId"] as? String {
                                    self.deleteBlacklistTestRecord(objectId: objectId) {
                                        completion(true)
                                    }
                                } else {
                                    completion(true)
                                }
                            } catch {
                                completion(true)
                            }
                        } else {
                            completion(true)
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
    
    // 删除Blacklist测试记录
    private func deleteBlacklistTestRecord(objectId: String, completion: @escaping () -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/Blacklist/\(objectId)"
        guard let url = URL(string: urlString) else {
            completion()
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { _, _, _ in
            DispatchQueue.main.async {
                completion()
            }
        }.resume()
    }
    
    // 创建LocalBlacklist表
    func createLocalBlacklistTable(completion: @escaping (Bool) -> Void) {
        // 通过插入一条测试记录来创建表
        let testData: [String: Any] = [
            "reported_user_id": "test_device_id",
            "reported_user_name": "测试用户",
            "deviceId": "test_device_id",
            "expires_at": [
                "iso": ISO8601DateFormatter().string(from: Date().addingTimeInterval(86400)) // 1天后过期
            ]
        ]
        
        let urlString = "\(serverUrl)/1.1/classes/localBlacklist"
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: testData)
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
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 201 {
                        // 删除测试记录
                        if let data = data {
                            do {
                                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                                if let objectId = json?["objectId"] as? String {
                                    self.deleteLocalBlacklistTestRecord(objectId: objectId) {
                                        completion(true)
                                    }
                                } else {
                                    completion(true)
                                }
                            } catch {
                                completion(true)
                            }
                        } else {
                            completion(true)
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
    
    // 删除LocalBlacklist测试记录
    private func deleteLocalBlacklistTestRecord(objectId: String, completion: @escaping () -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/localBlacklist/\(objectId)"
        guard let url = URL(string: urlString) else {
            completion()
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { _, _, _ in
            DispatchQueue.main.async {
                completion()
            }
        }.resume()
    }
    
    // 🎯 新增：添加用户到本地黑名单表
    func addUserToLocalBlacklistTable(userId: String, userName: String, currentUserId: String, completion: @escaping (Bool, String?) -> Void) {
        // 构建本地黑名单数据
        let localBlacklistData: [String: Any] = [
            "reported_user_id": userId, // 被拉黑的用户ID
            "reported_user_name": userName,
            "deviceId": userId,
            "current_user_id": currentUserId // 当前用户ID（谁创建的黑名单）
        ]
        
        let urlString = "\(serverUrl)/1.1/classes/localBlacklist"
        guard let url = URL(string: urlString) else {
            completion(false, "无效的URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        // 添加ACL权限
        let localBlacklistDataWithACL = addACLToData(localBlacklistData)
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: localBlacklistDataWithACL)
        } catch {
            completion(false, "数据编码失败: \(error.localizedDescription)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, "网络错误: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 201 {
                        completion(true, nil)
                    } else {
                        var errorMessage = "服务器错误: \(httpResponse.statusCode)"
                        if let data = data {
                            do {
                                let errorJson = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                                if let error = errorJson?["error"] as? String {
                                    errorMessage = "LeanCloud错误: \(error)"
                                }
                            } catch {
                                // 忽略解析错误
                            }
                        }
                        completion(false, errorMessage)
                    }
                } else {
                    completion(false, "无效的服务器响应")
                }
            }
        }.resume()
    }
    
    // 🎯 新增：从本地黑名单表删除用户
    func removeUserFromLocalBlacklistTable(userId: String, currentUserId: String, completion: @escaping (Bool, String?) -> Void) {
        // 先查询要删除的记录
        let baseUrlString = "\(serverUrl)/1.1/classes/localBlacklist"
        guard let baseUrl = URL(string: baseUrlString) else {
            completion(false, "无效的URL")
            return
        }
        
        // 构建查询条件
        let whereCondition: [String: Any] = [
            "reported_user_id": userId,
            "current_user_id": currentUserId
        ]
        
        // 使用 URLComponents 构建查询参数
        var components = URLComponents(url: baseUrl, resolvingAgainstBaseURL: false)
        do {
            let whereData = try JSONSerialization.data(withJSONObject: whereCondition)
            let whereString = String(data: whereData, encoding: .utf8) ?? "{}"
            components?.queryItems = [
                URLQueryItem(name: "where", value: whereString)
            ]
        } catch {
            completion(false, "查询参数序列化失败: \(error.localizedDescription)")
            return
        }
        
        guard let url = components?.url else {
            completion(false, "无效的URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, "查询失败: \(error.localizedDescription)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200,
                      let data = data else {
                    completion(false, "查询失败: 无效的服务器响应")
                    return
                }
                
                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    if let results = json?["results"] as? [[String: Any]], !results.isEmpty {
                        // 删除所有匹配的记录
                        let objectIds = results.compactMap { $0["objectId"] as? String }
                        self.deleteLocalBlacklistRecords(objectIds: objectIds, completion: completion)
                    } else {
                        // 没有找到记录，认为删除成功
                        completion(true, nil)
                    }
                } catch {
                    completion(false, "解析响应失败: \(error.localizedDescription)")
                }
            }
        }.resume()
    }
    
    // 删除多条本地黑名单记录
    private func deleteLocalBlacklistRecords(objectIds: [String], completion: @escaping (Bool, String?) -> Void) {
        guard !objectIds.isEmpty else {
            completion(true, nil)
            return
        }
        
        // LeanCloud 批量删除需要逐个删除或使用批量接口
        var deletedCount = 0
        var lastError: String?
        
        let group = DispatchGroup()
        
        for objectId in objectIds {
            group.enter()
            let urlString = "\(serverUrl)/1.1/classes/localBlacklist/\(objectId)"
            guard let url = URL(string: urlString) else {
                group.leave()
                continue
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            setLeanCloudHeaders(&request)
            request.timeoutInterval = 10.0
            
            URLSession.shared.dataTask(with: request) { _, response, error in
                DispatchQueue.main.async {
                    if let httpResponse = response as? HTTPURLResponse {
                        if httpResponse.statusCode == 200 {
                            deletedCount += 1
                        } else {
                            lastError = "删除失败: \(httpResponse.statusCode)"
                        }
                    } else if let error = error {
                        lastError = "删除失败: \(error.localizedDescription)"
                    }
                    group.leave()
                }
            }.resume()
        }
        
        group.notify(queue: .main) {
            if deletedCount > 0 {
                completion(true, nil)
            } else {
                completion(false, lastError ?? "删除失败")
            }
        }
    }
    
    // 🎯 新增：添加用户到黑名单
    func addUserToBlacklist(userId: String, userName: String, loginType: String, completion: @escaping (Bool, String?) -> Void) {
        // 构建黑名单数据
        let blacklistData: [String: Any] = [
            "reported_user_id": userId, // 用户ID
            "reported_user_name": userName,
            "deviceId": userId // 如果没有设备ID，使用用户ID
        ]
        
        // 可选：设置过期时间（这里设置为永久，不设置 expires_at）
        // 如果需要设置过期时间，可以添加：
        // blacklistData["expires_at"] = [
        //     "iso": ISO8601DateFormatter().string(from: Date().addingTimeInterval(86400 * 365)) // 1年后过期
        // ]
        
        let urlString = "\(serverUrl)/1.1/classes/Blacklist"
        guard let url = URL(string: urlString) else {
            completion(false, "无效的URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        // 添加ACL权限
        let blacklistDataWithACL = addACLToData(blacklistData)
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: blacklistDataWithACL)
        } catch {
            completion(false, "数据编码失败: \(error.localizedDescription)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, "网络错误: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 201 {
                        completion(true, nil)
                    } else {
                        var errorMessage = "服务器错误: \(httpResponse.statusCode)"
                        if let data = data {
                            do {
                                let errorJson = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                                if let error = errorJson?["error"] as? String {
                                    errorMessage = "LeanCloud错误: \(error)"
                                }
                            } catch {
                                // 忽略解析错误
                            }
                        }
                        completion(false, errorMessage)
                    }
                } else {
                    completion(false, "无效的服务器响应")
                }
            }
        }.resume()
    }
}
