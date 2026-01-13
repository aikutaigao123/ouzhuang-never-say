//
//  LeanCloudService+UserNameUpdate.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation
import UIKit
import LeanCloud

// MARK: - 用户名更新功能
extension LeanCloudService {
    
    // 获取默认邮箱（根据登录类型）
    private func getDefaultEmail(userName: String, loginType: String) -> String {
        switch loginType {
        case "apple":
            return "\(userName)@apple.com"
        case "guest":
            return "\(userName)@guest.com"
        default:
            return ""
        }
    }
    
    // 更新用户名记录
    func updateUserNameRecord(objectId: String, loginType: String, userName: String, userEmail: String? = nil, completion: @escaping (Bool) -> Void) {
        
        // 首先获取现有的recordObjectId
        let objectIdKey = "user_name_object_id_\(objectId)_\(loginType)"
        guard let recordObjectId = UserDefaults.standard.string(forKey: objectIdKey) else {
            completion(false)
            return
        }
        
        let urlString = "\(serverUrl)/1.1/classes/UserNameRecord/\(recordObjectId)"
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        // 获取设备ID
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
        
        // 获取邮箱：优先使用传入的参数，其次从UserDefaults读取，最后使用默认邮箱格式
        let finalEmail: String
        if let email = userEmail, !email.isEmpty {
            finalEmail = email
        } else {
            let userDefaultsEmail = UserDefaultsManager.getCurrentUserEmail()
            if userDefaultsEmail.isEmpty {
                // 如果 UserDefaults 中也没有，使用默认邮箱格式
                finalEmail = getDefaultEmail(userName: userName, loginType: loginType)
            } else {
                finalEmail = userDefaultsEmail
            }
        }
        
        let data: [String: Any] = [
            "userName": userName,
            "userEmail": finalEmail,
            "deviceId": deviceID,
            "deviceTime": ISO8601DateFormatter().string(from: Date())
        ]
        
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: data)
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
                        
                        // 更新最后更新时间
                        UserDefaults.standard.set(Date(), forKey: "user_name_last_updated_\(recordObjectId)")
                        
                        completion(true)
                    } else if httpResponse.statusCode == 404 {
                        // 404错误表示表不存在，尝试自动创建表
                        self.createUserNameRecordTable { success in
                            if success {
                                // 表创建成功后，重新尝试更新用户名记录
                                self.updateUserNameRecord(objectId: objectId, loginType: loginType, userName: userName, userEmail: userEmail, completion: completion)
                            } else {
                                completion(false)
                            }
                        }
                    } else {
                        if data != nil {
                        }
                        completion(false)
                    }
                } else {
                    completion(false)
                }
            }
        }.resume()
    }
    
    // 更新用户邮箱记录（更新 UserNameRecord 表中的 userEmail 字段）
    func updateUserEmailRecord(objectId: String, loginType: String, userEmail: String, completion: @escaping (Bool) -> Void) {
        
        // 首先获取现有的recordObjectId
        let objectIdKey = "user_name_object_id_\(objectId)_\(loginType)"
        guard let recordObjectId = UserDefaults.standard.string(forKey: objectIdKey) else {
            completion(false)
            return
        }
        
        let urlString = "\(serverUrl)/1.1/classes/UserNameRecord/\(recordObjectId)"
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        // 获取设备ID
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
        
        // 获取当前用户名（从UserDefaults或使用默认值）
        let userName = UserDefaults.standard.string(forKey: "current_user_name") ?? "未知用户"
        
        // 如果邮箱为空，使用默认邮箱格式
        let finalEmail: String
        if userEmail.isEmpty {
            finalEmail = getDefaultEmail(userName: userName, loginType: loginType)
        } else {
            finalEmail = userEmail
        }
        
        let data: [String: Any] = [
            "userName": userName,
            "userEmail": finalEmail,
            "deviceId": deviceID,
            "deviceTime": ISO8601DateFormatter().string(from: Date())
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: data)
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
                        // 更新最后更新时间
                        UserDefaults.standard.set(Date(), forKey: "user_name_last_updated_\(recordObjectId)")
                        completion(true)
                    } else if httpResponse.statusCode == 404 {
                        // 404错误表示记录不存在，尝试创建新记录
                        let userName = UserDefaultsManager.getCurrentUserName()
                        self.createUserNameRecord(objectId: objectId, loginType: loginType, userName: userName, userEmail: userEmail) { success in
                            if success {
                                completion(true)
                            } else {
                                completion(false)
                            }
                        }
                    } else {
                        if data != nil {
                        }
                        completion(false)
                    }
                } else {
                    completion(false)
                }
            }
        }.resume()
    }
    
    // 🎯 新增：更新双头像模式解锁状态
    func updateDualAvatarUnlockedStatus(objectId: String, loginType: String, isUnlocked: Bool, completion: @escaping (Bool) -> Void) {
        // 首先获取现有的recordObjectId
        let objectIdKey = "user_name_object_id_\(objectId)_\(loginType)"
        guard let recordObjectId = UserDefaults.standard.string(forKey: objectIdKey) else {
            // 如果找不到recordObjectId，尝试通过查询获取
            let query = LCQuery(className: "UserNameRecord")
            query.whereKey("userId", .equalTo(objectId))
            query.whereKey("loginType", .equalTo(loginType))
            query.whereKey("createdAt", .descending)
            query.limit = 1
            
            query.find { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let records):
                        if let firstRecord = records.first,
                           let recordObjectId = firstRecord.objectId?.stringValue {
                            // 保存 recordObjectId
                            UserDefaults.standard.set(recordObjectId, forKey: objectIdKey)
                            // 递归调用更新方法
                            self.updateDualAvatarUnlockedStatus(objectId: objectId, loginType: loginType, isUnlocked: isUnlocked, completion: completion)
                        } else {
                            completion(false)
                        }
                    case .failure:
                        completion(false)
                    }
                }
            }
            return
        }
        
        let urlString = "\(serverUrl)/1.1/classes/UserNameRecord/\(recordObjectId)"
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        let data: [String: Any] = [
            "dualAvatarUnlocked": isUnlocked
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: data)
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
                        if data != nil {
                        }
                        completion(false)
                    }
                } else {
                    completion(false)
                }
            }
        }.resume()
    }
    
    // 🎯 新增：更新彩色模式开关状态
    func updateColorfulModeEnabled(objectId: String, loginType: String, isEnabled: Bool, completion: @escaping (Bool) -> Void) {
        // 首先获取现有的recordObjectId
        let objectIdKey = "user_name_object_id_\(objectId)_\(loginType)"
        guard let recordObjectId = UserDefaults.standard.string(forKey: objectIdKey) else {
            // 如果找不到recordObjectId，尝试通过查询获取
            let query = LCQuery(className: "UserNameRecord")
            query.whereKey("userId", .equalTo(objectId))
            query.whereKey("loginType", .equalTo(loginType))
            query.whereKey("createdAt", .descending)
            query.limit = 1
            
            query.find { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let records):
                        if let firstRecord = records.first,
                           let recordObjectId = firstRecord.objectId?.stringValue {
                            // 保存 recordObjectId
                            UserDefaults.standard.set(recordObjectId, forKey: objectIdKey)
                            // 递归调用更新方法
                            self.updateColorfulModeEnabled(objectId: objectId, loginType: loginType, isEnabled: isEnabled, completion: completion)
                        } else {
                            completion(false)
                        }
                    case .failure:
                        completion(false)
                    }
                }
            }
            return
        }
        
        let urlString = "\(serverUrl)/1.1/classes/UserNameRecord/\(recordObjectId)"
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        let data: [String: Any] = [
            "colorfulModeEnabled": isEnabled
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: data)
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
                        if data != nil {
                        }
                        completion(false)
                    }
                } else {
                    completion(false)
                }
            }
        }.resume()
    }
}
