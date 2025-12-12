//
//  LeanCloudService+UserNameCreate.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation
import UIKit
import LeanCloud

// MARK: - 用户名创建功能
extension LeanCloudService {
    
    // 获取默认邮箱（根据登录类型）
    private func getDefaultEmail(userName: String, loginType: String) -> String {
        switch loginType {
        // "internal" case 已删除
        case "apple":
            return "\(userName)@apple.com"
        case "guest":
            return "\(userName)@guest.com"
        default:
            return ""
        }
    }
    
    // 创建用户名记录
    func createUserNameRecord(objectId: String, loginType: String, userName: String, userEmail: String? = nil, completion: @escaping (Bool) -> Void) {
        
        // 验证objectId格式：对于Apple用户，objectId应该是Apple ID标识符（类似 000737.xxx），不应该是objectId格式（纯字母数字，24字符）
        if loginType == "apple" {
            if objectId.count == 24 && objectId.allSatisfy({ $0.isLetter || $0.isNumber }) {
            }
        }
        
        
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
        
        // 获取设备ID
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
        
        // 获取邮箱：优先使用传入的参数，其次从UserDefaults读取，最后使用默认邮箱格式
        let finalEmail: String
        if let email = userEmail, !email.isEmpty {
            finalEmail = email
        } else {
            let userDefaultsEmail = UserDefaults.standard.string(forKey: "current_user_email") ?? ""
            if userDefaultsEmail.isEmpty {
                // 如果 UserDefaults 中也没有，使用默认邮箱格式
                finalEmail = getDefaultEmail(userName: userName, loginType: loginType)
            } else {
                finalEmail = userDefaultsEmail
            }
        }
        
        let data: [String: Any] = [
            "userId": objectId,
            "loginType": loginType,
            "userName": userName,
            "userEmail": finalEmail,
            "deviceId": deviceID,
            "deviceTime": ISO8601DateFormatter().string(from: Date()),
            "dualAvatarUnlocked": false, // 🎯 新增：双头像模式解锁状态（默认为false）
            "colorfulModeEnabled": false // 🎯 新增：彩色模式开关状态（默认为false）
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
                    
                    if httpResponse.statusCode == 201 {
                        
                        // 保存创建状态到UserDefaults
                        let userDefaultsKey = "user_name_record_created_\(objectId)_\(loginType)"
                        UserDefaults.standard.set(true, forKey: userDefaultsKey)
                        UserDefaults.standard.set(Date(), forKey: "\(userDefaultsKey)_date")
                        
                        // 解析响应数据获取objectId
                        if let data = data {
                            do {
                                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                                if let recordObjectId = json?["objectId"] as? String {
                                    UserDefaults.standard.set(recordObjectId, forKey: "user_name_object_id_\(objectId)_\(loginType)")
                                }
                            } catch {
                            }
                        }
                        
                        completion(true)
                    } else if httpResponse.statusCode == 404 {
                        // 404错误表示表不存在，尝试自动创建表
                        self.createUserNameRecordTable { success in
                            if success {
                                // 表创建成功后，重新尝试创建用户名记录
                                self.createUserNameRecord(objectId: objectId, loginType: loginType, userName: userName, userEmail: userEmail, completion: completion)
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
    
    // MARK: - 改进的上传逻辑
    
    // 智能上传用户名（检查是否存在，不存在则创建，存在则更新）
    func uploadUserNameIfNotExists(objectId: String, loginType: String, userName: String, userEmail: String? = nil, completion: @escaping (Bool, String) -> Void) {
        
        // 防重复调用：检查是否正在为这个用户上传
        let userKey = "\(objectId)_\(loginType)"
        uploadingUserNameLock.lock()
        if uploadingUserNameForUsers.contains(userKey) {
            uploadingUserNameLock.unlock()
            completion(false, "正在上传中，跳过重复调用")
            return
        }
        uploadingUserNameForUsers.insert(userKey)
        uploadingUserNameLock.unlock()
        
        // 确保邮箱不为空：如果邮箱为空，使用默认邮箱格式（根据登录类型）
        var finalEmail = userEmail
        if finalEmail == nil || finalEmail?.isEmpty == true {
            finalEmail = UserDefaults.standard.string(forKey: "current_user_email")
            if finalEmail == nil || finalEmail?.isEmpty == true {
                // 使用默认邮箱格式（根据登录类型）
                finalEmail = getDefaultEmail(userName: userName, loginType: loginType)
            }
        }
        
        // 🎯 修改：使用 fetchUserNameByUserId 检查是否存在记录，不依赖 loginType
        fetchUserNameByUserId(objectId: objectId) { existingUserName, error in
            // 移除防重复调用的标记（无论成功或失败）
            defer {
                self.uploadingUserNameLock.lock()
                self.uploadingUserNameForUsers.remove(userKey)
                self.uploadingUserNameLock.unlock()
            }
            
            if let error = error {
                completion(false, "查询失败: \(error)")
                return
            }
            
            if let existingUserName = existingUserName, !(existingUserName.isEmpty) {
                // 2. 如果存在，更新记录
                self.updateUserNameRecord(objectId: objectId, loginType: loginType, userName: userName, userEmail: finalEmail) { success in
                    if success {
                        completion(true, "用户名记录更新成功")
                    } else {
                        completion(false, "用户名记录更新失败")
                    }
                }
            } else {
                // 3. 如果不存在，创建新记录
                self.createUserNameRecord(objectId: objectId, loginType: loginType, userName: userName, userEmail: finalEmail) { success in
                    if success {
                        completion(true, "用户名记录创建成功")
                    } else {
                        completion(false, "用户名记录创建失败")
                    }
                }
            }
        }
    }
    
    // 检查用户名记录是否存在 - 🎯 统一从 UserNameRecord 表获取
    func checkUserNameRecordExists(objectId: String, loginType: String, completion: @escaping (Bool, String?) -> Void) {
        // 🎯 修改：使用 fetchUserNameByUserId，不依赖 loginType（loginType 参数保留以兼容接口）
        fetchUserNameByUserId(objectId: objectId) { existingUserName, error in
            if let error = error {
                completion(false, error)
                return
            }
            
            let exists = existingUserName != nil && !(existingUserName?.isEmpty ?? true)
            if exists {
            }
            
            completion(exists, existingUserName)
        }
    }
    
    // 🎯 新增：检查用户名是否已被其他用户使用（排除当前用户）
    func checkUserNameUnique(username: String, excludingUserId: String, completion: @escaping (Bool, String?) -> Void) {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(false, "用户名为空")
            return
        }
        
        // 使用 LCQuery 查询 UserNameRecord 表
        let query = LCQuery(className: "UserNameRecord")
        query.whereKey("userName", .equalTo(trimmed))
        query.whereKey("userId", .notEqualTo(excludingUserId))
        query.limit = 1
        
        query.find { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let records):
                    if records.first != nil {
                        // 找到了其他用户使用了这个用户名
                        completion(false, "用户名已被使用")
                    } else {
                        // 没有找到，用户名可用
                        completion(true, nil)
                    }
                case .failure(let error):
                    // 查询失败，为了安全起见，认为用户名不可用
                    completion(false, "验证失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // 🎯 新增：检查邮箱地址是否已被其他用户使用（排除当前用户）
    func checkUserEmailUnique(email: String, excludingUserId: String, completion: @escaping (Bool, String?) -> Void) {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else {
            completion(false, "邮箱地址为空")
            return
        }
        
        // 忽略默认邮箱格式（@internal.com, @apple.com, @guest.com）
        let isDefaultEmail = trimmed.hasSuffix("@internal.com") || 
                            trimmed.hasSuffix("@apple.com") || 
                            trimmed.hasSuffix("@guest.com")
        if isDefaultEmail {
            // 默认邮箱不检查唯一性
            completion(true, nil)
            return
        }
        
        // 使用 LCQuery 查询 UserNameRecord 表
        let query = LCQuery(className: "UserNameRecord")
        query.whereKey("userEmail", .equalTo(trimmed))
        query.whereKey("userId", .notEqualTo(excludingUserId))
        query.limit = 1
        
        query.find { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let records):
                    if records.first != nil {
                        // 找到了其他用户使用了这个邮箱
                        completion(false, "邮箱地址已被使用")
                    } else {
                        // 没有找到，邮箱可用
                        completion(true, nil)
                    }
                case .failure(let error):
                    // 查询失败，为了安全起见，认为邮箱不可用
                    completion(false, "验证失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // 智能上传用户邮箱（检查是否存在记录，不存在则创建，存在则更新）
    func uploadUserEmailIfNotExists(objectId: String, loginType: String, userEmail: String, completion: @escaping (Bool, String) -> Void) {
        
        // 1. 先查询是否存在记录
        fetchUserName(objectId: objectId, loginType: loginType) { existingUserName, error in
            if let error = error {
                completion(false, "查询失败: \(error)")
                return
            }
            
            if existingUserName != nil && !(existingUserName?.isEmpty ?? true) {
                // 2. 如果存在，更新邮箱记录
                self.updateUserEmailRecord(objectId: objectId, loginType: loginType, userEmail: userEmail) { success in
                    if success {
                        completion(true, "邮箱记录更新成功")
                    } else {
                        completion(false, "邮箱记录更新失败")
                    }
                }
            } else {
                // 3. 如果不存在，创建新记录（包含用户名和邮箱）
                let userName = UserDefaults.standard.string(forKey: "current_user_name") ?? "未知用户"
                self.createUserNameRecord(objectId: objectId, loginType: loginType, userName: userName, userEmail: userEmail) { success in
                    if success {
                        completion(true, "邮箱记录创建成功")
                    } else {
                        completion(false, "邮箱记录创建失败")
                    }
                }
            }
        }
    }
    
    // 🎯 新增：生成7位随机大写字母+数字的用户名
    private func generateRandomUsername() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var result = ""
        for _ in 0..<7 {
            if let randomChar = characters.randomElement() {
                result.append(randomChar)
            }
        }
        return result
    }
    
    // 🎯 新增：生成唯一的随机用户名（检查唯一性，如果已被使用则重新生成）
    private func generateUniqueRandomUsername(excludingUserId: String, maxRetries: Int, completion: @escaping (String?) -> Void) {
        var attempts = 0
        
        func tryGenerate() {
            attempts += 1
            let randomUsername = generateRandomUsername()
            
            // 检查用户名是否唯一
            checkUserNameUnique(username: randomUsername, excludingUserId: excludingUserId) { isUnique, errorMessage in
                if isUnique {
                    // 用户名唯一，返回
                    completion(randomUsername)
                } else if attempts < maxRetries {
                    // 用户名已被使用，且还有重试次数，重新生成
                    tryGenerate()
                } else {
                    // 达到最大重试次数，返回nil
                    completion(nil)
                }
            }
        }
        
        tryGenerate()
    }
    
    // 🎯 新增：自动检查并创建当前用户的UserNameRecord（如果不存在）
    func ensureCurrentUserUserNameRecordExists(
        objectId: String,
        loginType: String,
        userName: String? = nil,
        userEmail: String? = nil,
        completion: @escaping (Bool, String) -> Void
    ) {
        // 1. 先查询是否存在记录
        fetchUserNameByUserId(objectId: objectId) { existingUserName, error in
            if let error = error {
                completion(false, "查询失败: \(error)")
                return
            }
            
            if let existingUserName = existingUserName, !existingUserName.isEmpty {
                // 2. 如果已存在记录，直接返回成功
                completion(true, "记录已存在")
                return
            }
            
            // 3. 如果不存在，自动创建新记录
            // 获取用户名：优先使用传入参数，其次生成随机用户名
            if let userName = userName, !userName.isEmpty {
                // 使用传入的用户名（已经在外部验证过唯一性，这里直接使用）
                let finalEmail: String
                if let email = userEmail, !email.isEmpty {
                    finalEmail = email
                } else {
                    let userDefaultsEmail = UserDefaults.standard.string(forKey: "current_user_email") ?? ""
                    if userDefaultsEmail.isEmpty {
                        finalEmail = self.getDefaultEmail(userName: userName, loginType: loginType)
                    } else {
                        finalEmail = userDefaultsEmail
                    }
                }
                
                // 创建新记录
                self.createUserNameRecord(objectId: objectId, loginType: loginType, userName: userName, userEmail: finalEmail) { success in
                    if success {
                        // 更新本地缓存和UserDefaults
                        self.cacheUserName(userName, for: objectId)
                        UserDefaultsManager.setCurrentUserName(userName)
                        
                        // 发送通知更新UI
                        NotificationCenter.default.post(
                            name: NSNotification.Name("UserNameUpdated"),
                            object: nil,
                            userInfo: [
                                "userName": userName,
                                "userId": objectId,
                                "loginType": loginType
                            ]
                        )
                        
                        completion(true, "记录创建成功")
                    } else {
                        completion(false, "记录创建失败")
                    }
                }
            } else {
                // 🎯 生成随机用户名，并检查唯一性
                self.generateUniqueRandomUsername(excludingUserId: objectId, maxRetries: 10) { uniqueUserName in
                    guard let uniqueUserName = uniqueUserName else {
                        completion(false, "无法生成唯一的用户名")
                        return
                    }
                    
                    // 获取邮箱：优先使用传入参数，其次从UserDefaults，最后使用默认邮箱格式
                    let finalEmail: String
                    if let email = userEmail, !email.isEmpty {
                        finalEmail = email
                    } else {
                        let userDefaultsEmail = UserDefaults.standard.string(forKey: "current_user_email") ?? ""
                        if userDefaultsEmail.isEmpty {
                            finalEmail = self.getDefaultEmail(userName: uniqueUserName, loginType: loginType)
                        } else {
                            finalEmail = userDefaultsEmail
                        }
                    }
                    
                    // 创建新记录
                    self.createUserNameRecord(objectId: objectId, loginType: loginType, userName: uniqueUserName, userEmail: finalEmail) { success in
                        if success {
                            // 更新本地缓存和UserDefaults
                            self.cacheUserName(uniqueUserName, for: objectId)
                            UserDefaultsManager.setCurrentUserName(uniqueUserName)
                            
                            // 发送通知更新UI
                            NotificationCenter.default.post(
                                name: NSNotification.Name("UserNameUpdated"),
                                object: nil,
                                userInfo: [
                                    "userName": uniqueUserName,
                                    "userId": objectId,
                                    "loginType": loginType
                                ]
                            )
                            
                            completion(true, "记录创建成功")
                        } else {
                            completion(false, "记录创建失败")
                        }
                    }
                }
            }
        }
    }
    
}
