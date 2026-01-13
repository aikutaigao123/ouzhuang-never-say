//
//  LeanCloudService+DataMerge.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation

// MARK: - 数据合并功能
extension LeanCloudService {
    
    // 解析ISO8601日期字符串
    private func parseISO8601Date(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: dateString) ?? formatter.date(from: dateString.replacingOccurrences(of: "\\.\\d+", with: "", options: .regularExpression))
    }
    
    // 合并UserScore表中的重复记录，保留积分最高的记录
    func mergeDuplicateUserScoreRecords(completion: @escaping (Int, Int, [String]) -> Void) {
        
        var mergedCount = 0
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
                    completion(mergedCount, errorCount, errorMessages)
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let data = data else {
                DispatchQueue.main.async {
                    errorCount += 1
                    errorMessages.append("UserScore响应无效: \(response?.description ?? "未知")")
                    completion(mergedCount, errorCount, errorMessages)
                }
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let results = json?["results"] as? [[String: Any]] else {
                    DispatchQueue.main.async {
                        errorCount += 1
                        errorMessages.append("UserScore数据格式错误")
                        completion(mergedCount, errorCount, errorMessages)
                    }
                    return
                }
                
                
                // 2. 按用户ID分组，识别有重复的userId
                var userIdSet: Set<String> = []
                var duplicateUserIds: Set<String> = []
                for result in results {
                    guard let userId = result["userId"] as? String else { continue }
                    if userIdSet.contains(userId) {
                        duplicateUserIds.insert(userId)
                    } else {
                        userIdSet.insert(userId)
                    }
                }
                
                // 如果没有重复记录，直接返回
                if duplicateUserIds.isEmpty {
                    DispatchQueue.main.async {
                        completion(mergedCount, errorCount, errorMessages)
                    }
                    return
                }
                
                
                // 3. 对每个有重复的userId，单独查询该userId的所有记录
                let group = DispatchGroup()
                
                for userId in duplicateUserIds {
                    group.enter()
                    
                    // 按userId查询该用户的所有记录（不限制limit，确保获取所有重复记录）
                    // 使用URL编码处理userId中的特殊字符
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
                            
                            // 如果只有一条记录，跳过
                            if userRecords.count <= 1 {
                                return
                            }
                            
                            // 按积分排序，保留最高的（如果积分相同，保留lastUpdated最新的）
                            let sortedRecords = userRecords.sorted {
                                let score0 = ($0["totalScore"] as? Int) ?? 0
                                let score1 = ($1["totalScore"] as? Int) ?? 0
                                if score0 != score1 {
                                    return score0 > score1
                                }
                                // 积分相同，比较lastUpdated
                                let date0 = self.parseISO8601Date($0["lastUpdated"] as? String) ?? Date.distantPast
                                let date1 = self.parseISO8601Date($1["lastUpdated"] as? String) ?? Date.distantPast
                                return date0 > date1
                            }
                            
                            let recordsToDelete = Array(sortedRecords.dropFirst())
                            
                            // 如果没有需要删除的记录，直接返回
                            if recordsToDelete.isEmpty {
                                return
                            }
                            
                            // 删除重复记录（异步方式）
                            let deleteGroup = DispatchGroup()
                            for record in recordsToDelete {
                                guard let objectId = record["objectId"] as? String else { continue }
                                
                                deleteGroup.enter()
                                self.deleteUserScoreRecord(objectId: objectId) { success in
                                    defer { deleteGroup.leave() }
                                    
                                    if success {
                                        mergedCount += 1
                                    } else {
                                        errorCount += 1
                                        errorMessages.append("删除记录失败: \(objectId)")
                                    }
                                }
                            }
                            
                            // 等待所有删除操作完成（在后台线程中等待，不会阻塞主线程）
                            deleteGroup.wait()
                            
                        } catch {
                            errorCount += 1
                            errorMessages.append("解析用户 \(userId) 数据失败: \(error.localizedDescription)")
                        }
                    }.resume()
                }
                
                // 等待所有查询和删除操作完成
                group.notify(queue: .main) {
                    completion(mergedCount, errorCount, errorMessages)
                }
                
            } catch {
                DispatchQueue.main.async {
                    errorCount += 1
                    errorMessages.append("数据解析失败: \(error.localizedDescription)")
                    completion(mergedCount, errorCount, errorMessages)
                }
            }
        }.resume()
    }
}
