//
//  LeanCloudService+OwnedAvatarsFetch.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation
import LeanCloud

// MARK: - 头像列表获取功能
extension LeanCloudService {
    
    // 获取用户拥有的头像列表
    func fetchOwnedAvatars(userId: String, loginType: String, completion: @escaping ([String]?, String?) -> Void) {
        // 参数验证
        guard !userId.isEmpty else {
            completion(nil, "用户ID为空")
            return
        }
        
        guard !loginType.isEmpty else {
            completion(nil, "登录类型为空")
            return
        }
        
        // ✅ 按照开发指南：使用 LCQuery 创建查询
        // 🔧 修复：使用 updatedAt 排序，确保获取最新的记录（而不是按创建时间）
        let query = LCQuery(className: "OwnedAvatarsRecord")
        query.whereKey("userId", .equalTo(userId))
        query.whereKey("loginType", .equalTo(loginType))
        query.whereKey("updatedAt", .descending) // 🔧 修复：使用 updatedAt 而不是 createdAt
        query.limit = 1
        
        query.find { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let records):
                    
                    if let firstRecord = records.first {
                        // 🔍 尝试多种方式读取数组数据
                        var ownedAvatars: [String] = []
                        
                        // 方式1: 使用 arrayValue
                        if let arrayValue = firstRecord["owned_avatars"]?.arrayValue as? [String] {
                            ownedAvatars = arrayValue
                        } else {
                            // 方式2: 尝试直接读取LCArray
                            if let lcArray = firstRecord["owned_avatars"] as? LCArray {
                                if let arrayValue = lcArray.arrayValue as? [String] {
                                    ownedAvatars = arrayValue
                                } else {
                                    // 方式3: 尝试逐个读取元素
                                    var manualArray: [String] = []
                                    for i in 0..<lcArray.count {
                                        if let element = lcArray[i] as? LCString,
                                           let stringValue = element.stringValue {
                                            manualArray.append(stringValue)
                                        }
                                    }
                                    if !manualArray.isEmpty {
                                        ownedAvatars = manualArray
                                    }
                                }
                            }
                        }
                        
                        if ownedAvatars.isEmpty {
                            completion([], nil)
                            return
                        }
                        
                        
                        // 检查是否有nil或空值
                        let nilCount = ownedAvatars.filter { $0.isEmpty }.count
                        if nilCount > 0 {
                        }
                        
                        // 过滤掉空字符串，确保数据安全
                        let validAvatars = ownedAvatars.filter { !$0.isEmpty }
                        
                        if validAvatars.count != ownedAvatars.count {
                        }
                        
                        // 检查是否有重复
                        let uniqueAvatars = Array(Set(validAvatars))
                        if uniqueAvatars.count != validAvatars.count {
                        }
                        
                        completion(validAvatars, nil)
                    } else {
                        completion([], nil) // 没有头像记录，返回空数组
                    }
                case .failure(let error):
                    completion(nil, "获取失败: \(error.localizedDescription)")
                }
            }
        }
    }
}
