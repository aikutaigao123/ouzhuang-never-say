//
//  LeanCloudService+TableCreation.swift
//  NeverSayNo
//
//  Created by AI Assistant on 2024-12-19.
//

import Foundation

// MARK: - 表创建扩展
extension LeanCloudService {
    
    // MARK: - 表创建方法
    
    /// 创建FavoriteRecord表
    func createFavoriteRecordTable(completion: @escaping (Bool) -> Void) {
        // 通过插入一条测试记录来创建表
        let testData: [String: Any] = [
            "userId": "test_user",
            "favoriteUserId": "test_favorite_user",
            "favoriteTime": ISO8601DateFormatter().string(from: Date()),
            "status": "active"
        ]
        
        let urlString = "\(serverUrl)/1.1/classes/FavoriteRecord"
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
    
    /// 创建UserAvatarRecord表
    func createUserAvatarRecordTable(completion: @escaping (Bool) -> Void) {
        // 通过插入一条测试记录来创建表
        let testData: [String: Any] = [
            "userId": "test_user",
            "loginType": "test",
            "userName": "测试用户",
            "userEmail": "test@example.com",
            "userAvatar": "person.circle",
            "deviceId": "test_device",
            "deviceTime": ISO8601DateFormatter().string(from: Date())
        ]
        
        let urlString = "\(serverUrl)/1.1/classes/UserAvatarRecord"
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
    
    /// 创建DiamondRecord表
    func createDiamondRecordTable(completion: @escaping (Bool) -> Void) {
        // 通过插入一条测试记录来创建表
        let testData: [String: Any] = [
            "userId": "test_user",
            "userName": "测试用户",
            "userEmail": "test@example.com",
            "userAvatar": "person.circle",
            "loginType": "test",
            "deviceId": "test_device",
            "diamonds": 0
        ]
        
        let urlString = "\(serverUrl)/1.1/classes/DiamondRecord"
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
    
    /// 创建UserNameRecord表
    func createUserNameRecordTable(completion: @escaping (Bool) -> Void) {
        // 通过插入一条测试记录来创建表
        let testData: [String: Any] = [
            "userId": "test_user",
            "loginType": "test",
            "userName": "测试用户",
            "userEmail": "test@example.com",
            "deviceId": "test_device",
            "deviceTime": ISO8601DateFormatter().string(from: Date())
        ]
        
        let urlString = "\(serverUrl)/1.1/classes/UserNameRecord"
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
                    // 成功创建表，删除测试记录
                    if let data = data {
                        do {
                            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                            if let objectId = json?["objectId"] as? String {
                                self.deleteUserNameRecordTestRecord(objectId: objectId) {
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
            }.resume()
            
        } catch {
            completion(false)
        }
    }
    
    // 删除UserNameRecord测试记录
    private func deleteUserNameRecordTestRecord(objectId: String, completion: @escaping () -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/UserNameRecord/\(objectId)"
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
    
    /// 创建Notifications表
    func createNotificationsTable(completion: @escaping (Bool) -> Void) {
        // 通过插入一条测试记录来创建表
        let testData: [String: Any] = [
            "title": "测试通知",
            "message": "", // message 字段为空
            "isActive": true,
            "priority": 1,
            "userId": "", // userId 字段，为空表示全局通知
            "Blacklist": false // Blacklist 字段，为true时点击同意也退出登录
        ]
        
        let urlString = "\(serverUrl)/1.1/classes/Notifications"
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
}
