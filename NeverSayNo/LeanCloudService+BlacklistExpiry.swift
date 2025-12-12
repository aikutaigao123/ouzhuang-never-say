//
//  LeanCloudService+BlacklistExpiry.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//  Copyright © 2024. All rights reserved.
//

import Foundation
import LeanCloud

// MARK: - 黑名单过期时间查询功能
extension LeanCloudService {
    
    // 获取指定设备的黑名单过期时间 - 遵循数据存储开发指南，使用 LCQuery
    func fetchDeviceBlacklistExpiryTime(deviceId: String, completion: @escaping (Date?, String?) -> Void) {
        // ✅ 按照开发指南：使用 LCQuery 创建查询
        let query = LCQuery(className: "Blacklist")
        query.whereKey("reported_user_id", .equalTo(deviceId))
        query.whereKey("createdAt", .descending)
        query.limit = 1
        
        query.find { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let records):
                    if let firstRecord = records.first,
                       let expiresAt = firstRecord["expires_at"]?.dateValue {
                        completion(expiresAt, nil)
                    } else {
                        completion(nil, "未找到黑名单记录或过期时间")
                    }
                case .failure(let error):
                    completion(nil, "获取失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // 获取指定用户/设备的黑名单过期时间 - 遵循数据存储开发指南，使用 LCQuery
    func fetchUserBlacklistExpiryTime(userId: String, completion: @escaping (Date?, String?) -> Void) {
        // ✅ 按照开发指南：使用 LCQuery 创建查询
        let query = LCQuery(className: "Blacklist")
        query.whereKey("reported_user_name", .equalTo(userId))
        query.whereKey("createdAt", .descending)
        query.limit = 1
        
        query.find { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let records):
                    if let firstRecord = records.first,
                       let expiresAt = firstRecord["expires_at"]?.dateValue {
                        completion(expiresAt, nil)
                    } else {
                        completion(nil, "未找到黑名单记录或过期时间")
                    }
                case .failure(let error):
                    completion(nil, "获取失败: \(error.localizedDescription)")
                }
            }
        }
    }
}
