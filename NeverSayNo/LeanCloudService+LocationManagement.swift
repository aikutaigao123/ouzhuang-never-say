//
//  LeanCloudService+LocationManagement.swift
//  NeverSayNo
//
//  Created by AI Assistant on 2024-12-19.
//

import Foundation

// MARK: - 位置记录管理扩展
extension LeanCloudService {
    
    // MARK: - 位置记录获取
    
    /// 获取所有位置记录（分页获取完整内容）
    func fetchAllLocationRecords(completion: @escaping ([LocationRecord]?, String?) -> Void) {
        
        var allRecords: [LocationRecord] = []
        let pageSize = 1000 // 每页获取1000条记录
        var skip = 0
        var hasMore = true
        
        let dispatchGroup = DispatchGroup()
        
        func fetchPage() {
            guard hasMore else {
                dispatchGroup.leave()
                return
            }
            
            let urlString = "\(serverUrl)/1.1/classes/LocationRecord?order=-createdAt&limit=\(pageSize)&skip=\(skip)"
            
            guard let url = URL(string: urlString) else {
                completion(nil, "URL创建失败")
                dispatchGroup.leave()
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            setLeanCloudHeaders(&request)
            request.timeoutInterval = 30.0
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(nil, "网络错误: \(error.localizedDescription)")
                    dispatchGroup.leave()
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(nil, "无效的响应")
                    dispatchGroup.leave()
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    guard let data = data else {
                        completion(nil, "无数据返回")
                        dispatchGroup.leave()
                        return
                    }
                    
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let results = json["results"] as? [[String: Any]] {
                            
                            
                            let records = results.compactMap { dict -> LocationRecord? in
                                guard let objectId = dict["objectId"] as? String,
                                      let latitude = dict["latitude"] as? Double,
                                      let longitude = dict["longitude"] as? Double,
                                      let accuracy = dict["accuracy"] as? Double,
                                      let userId = dict["userId"] as? String,
                                      let deviceId = dict["deviceId"] as? String else {
                                    return nil
                                }
                                
                                // 使用device_time作为timestamp，如果没有则使用createdAt
                                let timestamp = (dict["deviceTime"] as? String) ?? 
                                              (dict["timestamp"] as? String) ?? 
                                              (dict["createdAt"] as? String) ?? ""
                                
                                return LocationRecord(
                                    id: 0, // 临时ID，实际使用objectId
                                    objectId: objectId,
                                    timestamp: timestamp,
                                    latitude: latitude,
                                    longitude: longitude,
                                    accuracy: accuracy,
                                    userId: userId,
                                    userName: dict["userName"] as? String,
                                    loginType: dict["loginType"] as? String,
                                    userEmail: dict["userEmail"] as? String,
                                    userAvatar: dict["userAvatar"] as? String,
                                    deviceId: deviceId,
                                    clientTimestamp: dict["clientTimestamp"] as? Double,
                                    timezone: dict["timezone"] as? String,
                                    status: dict["status"] as? String,
                                    recordCount: dict["recordCount"] as? Int,
                                    likeCount: dict["likeCount"] as? Int
                                )
                            }
                            
                            allRecords.append(contentsOf: records)
                            
                            // 检查是否还有更多数据
                            if results.count < pageSize {
                                hasMore = false
                            } else {
                                skip += pageSize
                            }
                            
                            fetchPage() // 继续获取下一页
                        } else {
                            completion(nil, "数据格式错误")
                            dispatchGroup.leave()
                        }
                    } catch {
                        completion(nil, "数据解析错误")
                        dispatchGroup.leave()
                    }
                } else {
                    completion(nil, "服务器错误: \(httpResponse.statusCode)")
                    dispatchGroup.leave()
                }
            }.resume()
        }
        
        dispatchGroup.enter()
        fetchPage()
        
        dispatchGroup.notify(queue: .main) {
            completion(allRecords, nil)
        }
    }
    
    // MARK: - 位置记录删除
    
    /// 删除位置记录（使用状态字段，不删除记录）
    func deleteLocationRecords(recordIds: [String], completion: @escaping (Bool, String?) -> Void) {
        let group = DispatchGroup()
        var successCount = 0
        var errorCount = 0
        var lastError: String?
        
        for recordId in recordIds {
            group.enter()
            updateLocationStatus(objectId: recordId, status: "deleted") { success, error in
                if success {
                    successCount += 1
                } else {
                    errorCount += 1
                    lastError = error
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if errorCount == 0 {
                completion(true, nil)
            } else {
                completion(false, lastError)
            }
        }
    }
    
    /// 更新位置记录状态
    private func updateLocationStatus(objectId: String, status: String, completion: @escaping (Bool, String?) -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/LocationRecord/\(objectId)"
        guard let url = URL(string: urlString) else {
            completion(false, "无效的URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        setLeanCloudHeaders(&request, contentType: "application/json")
        request.timeoutInterval = 10.0
        
        let updateData = ["status": status]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: updateData)
            request.httpBody = jsonData
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(false, "网络错误: \(error.localizedDescription)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false, "无效的响应")
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    completion(true, nil)
                } else {
                    completion(false, "服务器错误: \(httpResponse.statusCode)")
                }
            }.resume()
            
        } catch {
            completion(false, "数据格式错误")
        }
    }
    
    // MARK: - 位置清理
    
    /// 清除位置记录（使用状态字段，不删除记录）
    func clearLocation(objectId: String, completion: @escaping (Bool, String) -> Void) {
        
        // 直接更新位置记录状态为cleared
        updateLocationStatus(objectId: objectId, status: "cleared") { success, error in
            if success {
                completion(true, "位置记录清除成功")
            } else {
                completion(false, error ?? "位置记录清除失败")
            }
        }
    }
    
    // MARK: - 表创建
    
    /// 创建LocationRecord表
    func createLocationRecordTable(completion: @escaping (Bool) -> Void) {
        // 通过插入一条测试记录来创建表
        let testData: [String: Any] = [
            "latitude": 0.0,
            "longitude": 0.0,
            "accuracy": 0.0,
            "userId": "test_user",
            "userName": "测试用户",
            "loginType": "test",
            "userEmail": "test@example.com",
            "userAvatar": "person.circle",
            "deviceId": "test_device",
            "deviceTime": ISO8601DateFormatter().string(from: Date()),
            "status": "active",
            "likeCount": 0
        ]
        
        let urlString = "\(serverUrl)/1.1/classes/LocationRecord"
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
            let jsonData = try JSONSerialization.data(withJSONObject: testData)
            request.httpBody = jsonData
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if error != nil {
                    completion(false)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false)
                    return
                }
                
                if httpResponse.statusCode == 201 {
                    completion(true)
                } else {
                    completion(false)
                }
            }.resume()
            
        } catch {
            completion(false)
        }
    }
    
    // MARK: - 点赞数管理
    
    /// 更新LocationRecord的点赞数
    func updateLocationLikeCount(objectId: String, increment: Bool = true, completion: @escaping (Bool, String?) -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/LocationRecord/\(objectId)"
        guard let url = URL(string: urlString) else {
            completion(false, "无效的URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        // 构建更新数据 - 使用LeanCloud的Increment操作
        let updateData: [String: Any] = [
            "likeCount": increment ? ["__op": "Increment", "amount": 1] : ["__op": "Increment", "amount": -1]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: updateData)
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
                    if httpResponse.statusCode == 200 {
                        completion(true, nil)
                    } else {
                        var errorMessage = "更新失败: \(httpResponse.statusCode)"
                        if let data = data {
                            do {
                                let errorJson = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                                if let error = errorJson?["error"] as? String {
                                    errorMessage = "LeanCloud错误: \(error)"
                                }
                            } catch {
                                // 错误响应解析失败
                            }
                        }
                        completion(false, errorMessage)
                    }
                } else {
                    completion(false, "无效的响应")
                }
            }
        }.resume()
    }
    
    // MARK: - 打印LocationRecord表数据
    
    /// 打印LocationRecord表的完整数据
    func printLocationRecordTable(completion: @escaping () -> Void = {}) {
        _ = Date()
        
        fetchAllLocationRecords { records, error in
            DispatchQueue.main.async {
                completion()
            }
        }
    }
}
