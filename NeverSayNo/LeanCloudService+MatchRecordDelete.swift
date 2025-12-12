//
//  LeanCloudService+MatchRecordDelete.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//

import Foundation
import CoreLocation
import UIKit
import LeanCloud

// MARK: - Match Record Delete Extensions
extension LeanCloudService {
    
    /// 删除指定用户对的所有活跃匹配记录 - 遵循数据存储开发指南，使用 LCQuery
    func deleteActiveMatchRecordsForUsers(user1Id: String, user2Id: String, completion: @escaping (Int) -> Void) {
        // ✅ 按照开发指南：使用并行查询替代复杂的OR查询
        var allRecords: [LCObject] = []
        let queryGroup = DispatchGroup()
        
        // 查询1: user1_id 和 user2_id 匹配
        queryGroup.enter()
        let query1 = LCQuery(className: "MatchRecord")
        query1.whereKey("user1Id", .equalTo(user1Id))
        query1.whereKey("user2Id", .equalTo(user2Id))
        query1.whereKey("status", .equalTo("active"))
        query1.find { result in
            switch result {
            case .success(let records):
                allRecords.append(contentsOf: records)
            case .failure:
                break
            }
            queryGroup.leave()
        }
        
        // 查询2: 反向匹配
        queryGroup.enter()
        let query2 = LCQuery(className: "MatchRecord")
        query2.whereKey("user1Id", .equalTo(user2Id))
        query2.whereKey("user2Id", .equalTo(user1Id))
        query2.whereKey("status", .equalTo("active"))
        query2.find { result in
            switch result {
            case .success(let records):
                allRecords.append(contentsOf: records)
            case .failure:
                break
            }
            queryGroup.leave()
        }
        
        queryGroup.notify(queue: .main) {
            // 去重
            var uniqueRecords: [LCObject] = []
            var seenIds = Set<String>()
            for record in allRecords {
                if let objectId = record.objectId?.stringValue,
                   !seenIds.contains(objectId) {
                    seenIds.insert(objectId)
                    uniqueRecords.append(record)
                }
            }
            
            var deletedCount = 0
            let deleteGroup = DispatchGroup()
            
            for record in uniqueRecords {
                if let objectId = record.objectId?.stringValue {
                    deleteGroup.enter()
                    self.deleteMatchRecord(objectId: objectId) { success in
                        if success {
                            deletedCount += 1
                        }
                        deleteGroup.leave()
                    }
                }
            }
            
            deleteGroup.notify(queue: .main) {
                if deletedCount > 0 {
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshFriendsList"), object: nil)
                }
                completion(deletedCount)
            }
        }
    }
    
    /// 删除单个匹配记录
    func deleteMatchRecord(objectId: String, completion: @escaping (Bool) -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/MatchRecord/\(objectId)"
        
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
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
                
                if httpResponse.statusCode == 200 {
                    completion(true)
                } else {
                    completion(false)
                }
            }
        }.resume()
    }
    
    /// 删除匹配记录（带错误信息）
    func deleteMatchRecord(objectId: String, completion: @escaping (Bool, String) -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/MatchRecord/\(objectId)"
        
        guard let url = URL(string: urlString) else {
            completion(false, "无效的URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, "删除失败: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        completion(true, "")
                    } else {
                        var errorMessage = "删除失败: \(httpResponse.statusCode)"
                        if let data = data {
                            do {
                                let errorJson = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                                if let error = errorJson?["error"] as? String {
                                    errorMessage = "LeanCloud错误: \(error)"
                                }
                            } catch {
                                errorMessage = "删除失败: \(httpResponse.statusCode)"
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
    
    /// 更新匹配记录状态
    func updateMatchRecordStatus(objectId: String, status: String, completion: @escaping (Bool, String) -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/MatchRecord/\(objectId)"
        
        guard let url = URL(string: urlString) else {
            completion(false, "无效的URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        let updateData: [String: Any] = [
            "status": status,
            "updatedAt": ISO8601DateFormatter().string(from: Date())
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: updateData)
        } catch {
            completion(false, "数据序列化失败: \(error.localizedDescription)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, "更新失败: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        completion(true, "")
                    } else {
                        var errorMessage = "更新失败: \(httpResponse.statusCode)"
                        if let data = data {
                            do {
                                let errorJson = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                                if let error = errorJson?["error"] as? String {
                                    errorMessage = "LeanCloud错误: \(error)"
                                }
                            } catch {
                                errorMessage = "更新失败: \(httpResponse.statusCode)"
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
    
    /// 根据用户对更新匹配记录状态 - 遵循数据存储开发指南，使用 LCQuery
    func updateMatchRecordStatusByUsers(user1Id: String, user2Id: String, status: String, completion: @escaping (Bool, String) -> Void) {
        // ✅ 按照开发指南：使用并行查询替代复杂的OR查询
        var allRecords: [LCObject] = []
        let group = DispatchGroup()
        
        // 查询1: user1_id 和 user2_id 匹配
        group.enter()
        let query1 = LCQuery(className: "MatchRecord")
        query1.whereKey("user1Id", .equalTo(user1Id))
        query1.whereKey("user2Id", .equalTo(user2Id))
        query1.limit = 1
        query1.find { result in
            switch result {
            case .success(let records):
                allRecords.append(contentsOf: records)
            case .failure:
                break
            }
            group.leave()
        }
        
        // 查询2: 反向匹配
        group.enter()
        let query2 = LCQuery(className: "MatchRecord")
        query2.whereKey("user1Id", .equalTo(user2Id))
        query2.whereKey("user2Id", .equalTo(user1Id))
        query2.limit = 1
        query2.find { result in
            switch result {
            case .success(let records):
                allRecords.append(contentsOf: records)
            case .failure:
                break
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            if let firstRecord = allRecords.first,
               let objectId = firstRecord.objectId?.stringValue {
                self.updateMatchRecordStatus(objectId: objectId, status: status, completion: completion)
            } else {
                completion(false, "未找到匹配记录")
            }
        }
    }
}
