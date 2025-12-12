//
//  LeanCloudService+DataSync.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation

// MARK: - 数据同步功能
extension LeanCloudService {
    
    // 同步并修正UserScore中的头像和用户名数据，使其与UserAvatarRecord和UserRecord保持一致
    func syncAndCorrectUserScoreData(completion: @escaping (Int, Int, [String]) -> Void) {
        
        var correctedCount = 0
        var errorCount = 0
        var errorMessages: [String] = []
        
        // 1. 获取UserScore记录（limit=1000）
        let userScoreUrlString = "\(serverUrl)/1.1/classes/UserScore?order=-totalScore&limit=1000"
        guard let userScoreUrl = URL(string: userScoreUrlString) else {
            completion(0, 1, ["无效的UserScore URL"])
            return
        }
        
        var userScoreRequest = URLRequest(url: userScoreUrl)
        userScoreRequest.httpMethod = "GET"
        setLeanCloudHeaders(&userScoreRequest)
        userScoreRequest.timeoutInterval = 15.0
        
        URLSession.shared.dataTask(with: userScoreRequest) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    errorCount += 1
                    errorMessages.append("获取UserScore失败: \(error.localizedDescription)")
                    completion(correctedCount, errorCount, errorMessages)
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let data = data else {
                DispatchQueue.main.async {
                    errorCount += 1
                    errorMessages.append("UserScore响应无效: \(response?.description ?? "未知")")
                    completion(correctedCount, errorCount, errorMessages)
                }
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let results = json?["results"] as? [[String: Any]] else {
                    DispatchQueue.main.async {
                        errorCount += 1
                        errorMessages.append("UserScore数据格式错误")
                        completion(correctedCount, errorCount, errorMessages)
                    }
                    return
                }
                
                
                // 2. 提取所有唯一的userId
                var userIdSet: Set<String> = []
                for result in results {
                    if let userId = result["userId"] as? String {
                        userIdSet.insert(userId)
                    }
                }
                
                // 如果没有记录，直接返回
                if userIdSet.isEmpty {
                    DispatchQueue.main.async {
                        completion(correctedCount, errorCount, errorMessages)
                    }
                    return
                }
                
                
                // 3. 对每个userId，单独查询该userId的所有UserScore记录
                let group = DispatchGroup()
                
                for userId in userIdSet {
                    group.enter()
                    
                    // 按userId查询该用户的所有记录（不限制limit，确保获取所有记录）
                    guard let encodedUserId = userId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                          let whereClause = "{\"userId\":\"\(encodedUserId)\"}".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                        errorCount += 1
                        errorMessages.append("无效的userId: \(userId)")
                        group.leave()
                        continue
                    }
                    
                    let queryUrlString = "\(self.serverUrl)/1.1/classes/UserScore?where=\(whereClause)&limit=1000"
                    guard let queryUrl = URL(string: queryUrlString) else {
                        errorCount += 1
                        errorMessages.append("无效的查询URL: \(userId)")
                        group.leave()
                        continue
                    }
                    
                    var queryRequest = URLRequest(url: queryUrl)
                    queryRequest.httpMethod = "GET"
                    self.setLeanCloudHeaders(&queryRequest)
                    queryRequest.timeoutInterval = 15.0
                    
                    URLSession.shared.dataTask(with: queryRequest) { queryData, queryResponse, queryError in
                        defer { group.leave() }
                        
                        if let queryError = queryError {
                            errorCount += 1
                            errorMessages.append("查询用户 \(userId) 失败: \(queryError.localizedDescription)")
                            return
                        }
                        
                        guard let httpResponse = queryResponse as? HTTPURLResponse,
                              httpResponse.statusCode == 200,
                              let queryData = queryData else {
                            errorCount += 1
                            errorMessages.append("查询用户 \(userId) 响应无效")
                            return
                        }
                        
                        do {
                            let queryJson = try JSONSerialization.jsonObject(with: queryData) as? [String: Any]
                            guard let userRecords = queryJson?["results"] as? [[String: Any]] else {
                                errorCount += 1
                                errorMessages.append("用户 \(userId) 数据格式错误")
                                return
                            }
                            
                            // 如果没有记录，跳过
                            if userRecords.isEmpty {
                                return
                            }
                            
                            // 4. 对每条记录，同步头像和用户名
                            let syncGroup = DispatchGroup()
                            
                            for result in userRecords {
                                guard let objectId = result["objectId"] as? String else { continue }
                                
                                syncGroup.enter()
                                
                                // 🎯 使用 fetchUserAvatarByUserId 和 fetchUserNameByUserId，不依赖 loginType
                                self.fetchUserAvatarByUserId(objectId: userId) { avatar, avatarError in
                                    self.fetchUserNameByUserId(objectId: userId) { userName, nameError in
                                        defer { syncGroup.leave() }
                                        
                                        // 检查是否需要更新
                                        let currentAvatar = result["userAvatar"] as? String ?? ""
                                        let currentUserName = result["userName"] as? String ?? ""
                                        
                                        let newAvatar = avatar ?? currentAvatar
                                        let newUserName = userName ?? currentUserName
                                        
                                        if newAvatar != currentAvatar || newUserName != currentUserName {
                                            // 需要更新
                                            var updateData: [String: Any] = [:]
                                            
                                            if newAvatar != currentAvatar {
                                                updateData["userAvatar"] = newAvatar
                                            }
                                            
                                            if newUserName != currentUserName {
                                                updateData["userName"] = newUserName
                                            }
                                            
                                            updateData["lastUpdated"] = ISO8601DateFormatter().string(from: Date())
                                            
                                            self.updateUserScoreData(objectId: objectId, updateData: updateData) { success in
                                                if success {
                                                    correctedCount += 1
                                                } else {
                                                    errorCount += 1
                                                    let errorMsg = "用户 \(userId) 记录 \(objectId) 数据修正失败"
                                                    errorMessages.append(errorMsg)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // 等待该用户的所有同步操作完成（在后台线程中等待，不会阻塞主线程）
                            syncGroup.wait()
                            
                        } catch {
                            errorCount += 1
                            errorMessages.append("解析用户 \(userId) 数据失败: \(error.localizedDescription)")
                        }
                    }.resume()
                }
                
                // 等待所有用户的查询和同步操作完成
                group.notify(queue: .main) {
                    completion(correctedCount, errorCount, errorMessages)
                }
                
            } catch {
                DispatchQueue.main.async {
                    errorCount += 1
                    errorMessages.append("数据解析失败: \(error.localizedDescription)")
                    completion(correctedCount, errorCount, errorMessages)
                }
            }
        }.resume()
    }
    
    // 更新UserScore中的多个字段
    func updateUserScoreData(objectId: String, updateData: [String: Any], completion: @escaping (Bool) -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/UserScore/\(objectId)"
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
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
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        completion(true)
                    } else {
                        completion(false)
                    }
                } else {
                    completion(false)
                }
            }
        }.resume()
    }
    
    // 兼容旧版本的方法名，保持向后兼容
    func syncAndCorrectUserScoreAvatars(completion: @escaping (Int, Int, [String]) -> Void) {
        syncAndCorrectUserScoreData(completion: completion)
    }
}
