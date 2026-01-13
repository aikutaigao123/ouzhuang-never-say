//
//  LeanCloudService+OwnedAvatarsCreate.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation
import LeanCloud

// MARK: - 头像列表创建功能
extension LeanCloudService {
    
    // 创建用户拥有的头像列表记录 - ✅ 遵循 Swift 开发指南，使用 LCObject 的 save() 方法
    func createOwnedAvatarsRecord(userId: String, loginType: String, ownedAvatars: [String], completion: @escaping (Bool) -> Void) {
        
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
        
        do {
            // ✅ 按照开发指南：构建 LCObject
            let record = LCObject(className: "OwnedAvatarsRecord")
            
            // ✅ 按照开发指南：为属性赋值（数组需要显式转换为 LCArray）
            try record.set("userId", value: userId)
            try record.set("loginType", value: loginType)
            try record.set("owned_avatars", value: LCArray(ownedAvatars.map { LCString($0) }))
            try record.set("created_at", value: ISO8601DateFormatter().string(from: Date()))
            try record.set("updated_at", value: ISO8601DateFormatter().string(from: Date()))
            
            // ✅ 按照开发指南：将对象保存到云端
            _ = record.save { result in
            DispatchQueue.main.async {
                    switch result {
                    case .success:
                        completion(true)
                    case .failure:
                        completion(false)
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                    completion(false)
                }
            }
    }
}
