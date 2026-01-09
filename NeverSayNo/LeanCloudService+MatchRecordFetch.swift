//
//  LeanCloudService+MatchRecordFetch.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//

import Foundation
import CoreLocation
import UIKit
import LeanCloud

// MARK: - Match Record Fetch Extensions
extension LeanCloudService {
    
    /// 获取所有匹配记录
    func fetchMatchRecords(completion: @escaping ([MatchRecord]?) -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/MatchRecord?order=-match_time&limit=1000"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if error != nil {
                    completion(nil)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(nil)
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    if let data = data {
                        do {
                            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let results = json["results"] as? [[String: Any]] {
                                
                                // 转换为MatchRecord对象
                                let matchRecords = results.compactMap { recordData in
                                    MatchRecord.fromLeanCloudData(recordData)
                                }
                                completion(matchRecords)
                            } else {
                                completion(nil)
                            }
                        } catch {
                            completion(nil)
                        }
                    } else {
                        completion(nil)
                    }
                } else {
                    completion(nil)
                }
            }
        }.resume()
    }
    
    /// 根据用户ID查询匹配记录（包含自动修正功能）- 遵循数据存储开发指南，使用 LCQuery
    // 🎯 新增：添加重试机制（与用户头像查询一致）
    func fetchMatchRecords(userId: String, completion: @escaping ([MatchRecord]?, String?) -> Void) {
        var retryCount = 0
        
        func attempt() {
            // ✅ 按照开发指南：使用并行查询替代复杂的OR查询
            var allRecords: [LCObject] = []
            let group = DispatchGroup()
            var hasError = false
            var errorMessage: String? = nil
            
            // 查询1: user1_id 是当前用户
            group.enter()
            let query1 = LCQuery(className: "MatchRecord")
            query1.whereKey("user1Id", .equalTo(userId))
            query1.whereKey("matchTime", .descending)
            query1.limit = 1000
            query1.find { result in
                switch result {
                case .success(let records):
                    allRecords.append(contentsOf: records)
                case .failure(let error):
                    hasError = true
                    errorMessage = error.localizedDescription
                }
                group.leave()
            }
            
            // 查询2: user2_id 是当前用户
            group.enter()
            let query2 = LCQuery(className: "MatchRecord")
            query2.whereKey("user2Id", .equalTo(userId))
            query2.whereKey("matchTime", .descending)
            query2.limit = 1000
            query2.find { result in
                switch result {
                case .success(let records):
                    allRecords.append(contentsOf: records)
                case .failure(let error):
                    hasError = true
                    if errorMessage == nil {
                        errorMessage = error.localizedDescription
                    }
                }
                group.leave()
            }
            
            group.notify(queue: .main) {
                // 如果有错误，检查是否需要重试
                if hasError {
                    if retryCount < LeanCloudRetryConfig.maxRetries {
                        retryCount += 1
                        let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            attempt()
                        }
                        return
                    } else {
                        completion(nil, errorMessage ?? "查询失败")
                        return
                    }
                }
                
                // 转换为字典数组
                var results: [[String: Any]] = []
                var seenIds = Set<String>()
                
                for record in allRecords {
                    guard let objectId = record.objectId?.stringValue,
                          !seenIds.contains(objectId) else {
                        continue
                    }
                    seenIds.insert(objectId)
                    
                    var dict: [String: Any] = [:]
                    dict["objectId"] = objectId
                    dict["user1Id"] = record["user1Id"]?.stringValue ?? ""
                    dict["user2Id"] = record["user2Id"]?.stringValue ?? ""
                    dict["user1Name"] = record["user1Name"]?.stringValue ?? ""
                    dict["user2Name"] = record["user2Name"]?.stringValue ?? ""
                    dict["user1Avatar"] = record["user1Avatar"]?.stringValue ?? ""
                    dict["user2Avatar"] = record["user2Avatar"]?.stringValue ?? ""
                    dict["user1LoginType"] = record["user1LoginType"]?.stringValue ?? ""
                    dict["user2LoginType"] = record["user2LoginType"]?.stringValue ?? ""
                    dict["matchTime"] = record["matchTime"]?.stringValue ?? ""
                    dict["matchLocationLat"] = record["matchLocationLat"]?.doubleValue ?? 0
                    dict["matchLocationLng"] = record["matchLocationLng"]?.doubleValue ?? 0
                    dict["status"] = record["status"]?.stringValue ?? "active"
                    dict["deviceId"] = record["deviceId"]?.stringValue ?? ""
                    dict["timezone"] = record["timezone"]?.stringValue ?? ""
                    dict["deviceTime"] = record["deviceTime"]?.stringValue ?? ""
                    
                    results.append(dict)
                }
                
                // 按时间排序
                results.sort { (r1, r2) -> Bool in
                    let time1 = r1["matchTime"] as? String ?? ""
                    let time2 = r2["matchTime"] as? String ?? ""
                    return time1 > time2
                }
                
                // 检查并修正cancelled状态的MatchRecord
                self.checkAndCorrectCancelledMatchRecords(userId: userId, allMatchRecords: results) { correctedMatchRecords, error in
                    if let error = error {
                        completion(nil, error)
                        return
                    }
                    
                    // 过滤出active状态的记录
                    let activeMatchRecords = correctedMatchRecords.filter { $0.status == "active" }
                    completion(activeMatchRecords, nil)
                }
            }
        }
        
        attempt()
    }
    
    // getUserInfoFromMessages method is defined in LeanCloudService+MatchRecord.swift
}
