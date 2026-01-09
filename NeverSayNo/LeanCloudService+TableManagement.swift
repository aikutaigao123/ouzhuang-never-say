//
//  LeanCloudService+TableManagement.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//

import Foundation
import UIKit

// MARK: - Table Management Extensions
extension LeanCloudService {
    
    /// 创建账户删除请求表
    func createAccountDeletionRequestTable(completion: @escaping (Bool) -> Void) {
        // 通过插入一条测试记录来创建表
        let testData: [String: Any] = [
            "userId": "test_user",
            "userName": "测试用户",
            "userAvatar": "person.circle",
            "deviceId": "test_device",
            "request_time": ISO8601DateFormatter().string(from: Date()),
            "status": "pending",
            "deletion_date": ISO8601DateFormatter().string(from: Date().addingTimeInterval(7 * 24 * 3600))
        ]
        
        let urlString = "\(serverUrl)/1.1/classes/AccountDeletionRequest"
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
                                    self.deleteAccountDeletionRequestTestRecord(objectId: objectId) {
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
    
    /// 创建消息表
    func createMessageTable(completion: @escaping (Bool) -> Void) {
        // 通过插入一条测试记录来创建表
        let testData: [String: Any] = [
            "sender_id": "test_sender",
            "receiver_id": "test_receiver",
            "message_type": "text",
            "content": "测试消息",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "status": "sent"
        ]
        
        let urlString = "\(serverUrl)/1.1/classes/Message"
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
                                    self.deleteMessageTestRecord(objectId: objectId) {
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
    
    /// 删除账户删除请求测试记录
    private func deleteAccountDeletionRequestTestRecord(objectId: String, completion: @escaping () -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/AccountDeletionRequest/\(objectId)"
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
    
    /// 删除消息测试记录
    private func deleteMessageTestRecord(objectId: String, completion: @escaping () -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/Message/\(objectId)"
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