//
//  LeanCloudService+OwnedAvatarsPerform.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation
import LeanCloud

// MARK: - 头像列表执行更新功能
extension LeanCloudService {
    
    // 执行实际的头像列表更新
    func performUpdateOwnedAvatars(userId: String, loginType: String, ownedAvatars: [String], completion: @escaping (Bool) -> Void) {
        
        // 参数验证
        guard !userId.isEmpty else {
            completion(false)
            return
        }
        
        guard !loginType.isEmpty else {
            completion(false)
            return
        }
        
        guard !ownedAvatars.isEmpty else {
            completion(true)
            return
        }
        
        // ✅ 按照开发指南：使用 LCQuery 创建查询 - 首先检查是否已存在记录
        let query = LCQuery(className: "OwnedAvatarsRecord")
        query.whereKey("userId", .equalTo(userId))
        query.whereKey("loginType", .equalTo(loginType))
        query.limit = 1
        
        query.find { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let records):
                    if let firstRecord = records.first,
                       let objectId = firstRecord.objectId?.stringValue {
                        // 记录已存在，更新它
                        self.updateExistingOwnedAvatarsRecord(objectId: objectId, ownedAvatars: ownedAvatars, completion: completion)
                    } else {
                        // 记录不存在，创建新记录
                        self.createOwnedAvatarsRecord(userId: userId, loginType: loginType, ownedAvatars: ownedAvatars, completion: completion)
                    }
                case .failure:
                    // 查询失败，尝试创建新记录
                    self.createOwnedAvatarsRecord(userId: userId, loginType: loginType, ownedAvatars: ownedAvatars, completion: completion)
                }
            }
        }
    }
}
