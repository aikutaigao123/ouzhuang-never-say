//
//  LeanCloudService+OwnedAvatarsTable.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation

// MARK: - 头像列表表管理功能
extension LeanCloudService {
    
    // 确保OwnedAvatarsRecord表存在
    func ensureOwnedAvatarsTableExists(completion: @escaping (Bool) -> Void) {
        // 尝试查询表是否存在（通过查询一条记录来测试）
        let urlString = "\(serverUrl)/1.1/classes/OwnedAvatarsRecord?limit=1"
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
                    // 200表示表存在，404表示表不存在
                    if httpResponse.statusCode == 200 {
                        completion(true)
                    } else if httpResponse.statusCode == 404 {
                        self.createOwnedAvatarsTable(completion: completion)
                    } else {
                        completion(false)
                    }
                } else {
                    completion(false)
                }
            }
        }.resume()
    }
    
    // 创建OwnedAvatarsRecord表
    private func createOwnedAvatarsTable(completion: @escaping (Bool) -> Void) {
        // 通过插入一条测试记录来创建表
        let testData: [String: Any] = [
            "userId": "test_user",
            "loginType": "test",
            "owned_avatars": ["person.circle", "😊"],
            "created_at": ISO8601DateFormatter().string(from: Date()),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        let urlString = "\(serverUrl)/1.1/classes/OwnedAvatarsRecord"
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
                                    self.deleteOwnedAvatarsTestRecord(objectId: objectId) {
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
    
    // 删除OwnedAvatarsRecord测试记录
    private func deleteOwnedAvatarsTestRecord(objectId: String, completion: @escaping () -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/OwnedAvatarsRecord/\(objectId)"
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
}
