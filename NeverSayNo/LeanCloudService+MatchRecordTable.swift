//
//  LeanCloudService+MatchRecordTable.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//

import Foundation
import CoreLocation
import UIKit

// MARK: - Match Record Table Management Extensions
extension LeanCloudService {
    
    /// 创建MatchRecord表
    func createMatchRecordTable(completion: @escaping (Bool) -> Void) {
        // 通过插入一条测试记录来创建表
        let testData: [String: Any] = [
            "user1Id": "test_user1",
            "user2Id": "test_user2",
            "user1Name": "测试用户1",
            "user2Name": "测试用户2",
            "user1Avatar": "person.circle",
            "user2Avatar": "person.circle",
            "user1LoginType": "test",
            "user2LoginType": "test",
            "matchTime": ISO8601DateFormatter().string(from: Date()),
            "matchLocationLat": 0.0,
            "matchLocationLng": 0.0,
            "status": "active",
            "deviceId": "test_device",
            "timezone": "UTC",
            "deviceTime": ISO8601DateFormatter().string(from: Date())
        ]
        
        let urlString = "\(serverUrl)/1.1/classes/MatchRecord"
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
                                    self.deleteMatchRecordTestRecord(objectId: objectId) {
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
    
    /// 删除MatchRecord测试记录
    private func deleteMatchRecordTestRecord(objectId: String, completion: @escaping () -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/MatchRecord/\(objectId)"
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
    
    /// 确保MatchRecord表存在
    func ensureMatchRecordTableExists(completion: @escaping (Bool) -> Void) {
        // 先尝试查询表是否存在
        let urlString = "\(serverUrl)/1.1/classes/MatchRecord?limit=1"
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        // 表存在
                        completion(true)
                    } else if httpResponse.statusCode == 404 {
                        // 表不存在，创建表
                        self.createMatchRecordTable(completion: completion)
                    } else {
                        completion(false)
                    }
                } else {
                    completion(false)
                }
            }
        }.resume()
    }
}
