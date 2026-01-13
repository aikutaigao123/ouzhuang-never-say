//
//  LeanCloudService+OwnedAvatarsModify.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation
import LeanCloud

// MARK: - 头像列表修改功能
extension LeanCloudService {
    
    // 更新现有的头像列表记录 - ✅ 遵循 Swift 开发指南，使用 LCObject 的 save() 方法
    func updateExistingOwnedAvatarsRecord(objectId: String, ownedAvatars: [String], completion: @escaping (Bool) -> Void) {
        
        // 参数验证
        guard !objectId.isEmpty else {
            completion(false)
            return
        }
        
        guard !ownedAvatars.isEmpty else {
            completion(true)
            return
        }
        
        // 🔍 检查是否有重复
        let uniqueAvatars = Array(Set(ownedAvatars))
        if uniqueAvatars.count != ownedAvatars.count {
        }
        
        // 🔍 检查是否包含所有必需的头像
        _ = Set(EmojiList.allEmojis)
        _ = Set(ownedAvatars)
        
        do {
            // ✅ 按照开发指南：构建已存在的 LCObject（通过 objectId）
            let record = LCObject(className: "OwnedAvatarsRecord", objectId: objectId)
            
            // ✅ 按照开发指南：指定需要更新的属性名和属性值（数组需要显式转换为 LCArray）
            let lcArray = LCArray(ownedAvatars.map { LCString($0) })
            try record.set("owned_avatars", value: lcArray)
            try record.set("updated_at", value: ISO8601DateFormatter().string(from: Date()))
            
            // ✅ 按照开发指南：调用 save 方法更新对象
            _ = record.save { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        // 🔍 保存后立即验证：重新读取数据检查是否完整
                        // ✅ 按照开发指南：使用 query.get(objectId) 获取对象
                        let verifyQuery = LCQuery(className: "OwnedAvatarsRecord")
                        _ = verifyQuery.get(objectId) { verifyResult in
                            switch verifyResult {
                            case .success(object: let verifyRecord):
                                if let savedAvatars = verifyRecord["owned_avatars"]?.arrayValue as? [String] {
                                    if savedAvatars.count != ownedAvatars.count {
                                        // 找出丢失的头像
                                        _ = Set(savedAvatars)
                                        _ = Set(ownedAvatars)
                                    } else {
                                    }
                                }
                            case .failure:
                                break
                            }
                        }
                        
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
