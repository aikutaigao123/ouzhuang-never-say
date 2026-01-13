//
//  LeanCloudService+UserNameBatch.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation

// MARK: - 批量用户名获取功能
extension LeanCloudService {
    
    // 批量获取用户名 - 🎯 统一从 UserNameRecord 表获取
    func batchFetchUserNames(userIds: [String], loginTypes: [String], completion: @escaping ([String: String]) -> Void) {
        guard !userIds.isEmpty else {
            completion([:])
            return
        }
        
        // 🎯 修改：使用 fetchUserNameByUserId，直接从 UserNameRecord 表获取用户名
        let group = DispatchGroup()
        var userNameDict: [String: String] = [:]
        let lock = NSLock()
        
        for userId in userIds {
            group.enter()
            fetchUserNameByUserId(objectId: userId) { userName, error in
                lock.lock()
                if error != nil {
                    userNameDict[userId] = "未知用户"
                } else if let userName = userName, !userName.isEmpty {
                    userNameDict[userId] = userName
                } else {
                    userNameDict[userId] = "未知用户"
                }
                lock.unlock()
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(userNameDict)
        }
    }
    
    // 🎯 新增：批量获取用户名和用户类型 - 参考头像界面的实时查询方式
    func batchFetchUserNamesAndLoginTypes(userIds: [String], completion: @escaping ([String: String], [String: String]) -> Void) {
        guard !userIds.isEmpty else {
            completion([:], [:])
            return
        }
        
        // 🎯 使用 fetchUserNameAndLoginType，同时获取用户名和用户类型（参考头像界面方式）
        let group = DispatchGroup()
        var userNameDict: [String: String] = [:]
        var loginTypeDict: [String: String] = [:]
        let lock = NSLock()
        
        for userId in userIds {
            group.enter()
            fetchUserNameAndLoginType(objectId: userId) { userName, loginType, error in
                lock.lock()
                if error != nil {
                    userNameDict[userId] = "未知用户"
                } else if let userName = userName, !userName.isEmpty {
                    userNameDict[userId] = userName
                    if let loginType = loginType, !loginType.isEmpty {
                        loginTypeDict[userId] = loginType
                    }
                } else {
                    userNameDict[userId] = "未知用户"
                }
                lock.unlock()
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(userNameDict, loginTypeDict)
        }
    }
}
