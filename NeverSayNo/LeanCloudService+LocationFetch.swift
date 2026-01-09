//
//  LeanCloudService+LocationFetch.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//

import Foundation
import LeanCloud

// MARK: - Location Fetch Extension
extension LeanCloudService {
    
    /// 获取位置记录 - 使用 LCQuery
    // 🎯 新增：添加重试机制（与用户头像查询一致）
    func fetchLocations(completion: @escaping ([LocationRecord]?, String?) -> Void) {
        var retryCount = 0
        
        func attempt() {
            // ✅ 按照开发指南：使用 LCQuery 查询
            let query = LCQuery(className: "LocationRecord")
            query.limit = 1000
            
            _ = query.find { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let objects):
                        
                        let locations = objects.compactMap { object -> LocationRecord? in
                            guard let objectId = object.objectId?.value,
                                  let latitude = object["latitude"]?.doubleValue,
                                  let longitude = object["longitude"]?.doubleValue,
                                  let userId = object["userId"]?.stringValue,
                                  let deviceId = object["deviceId"]?.stringValue else {
                                return nil
                            }
                            
                            let accuracy = object["accuracy"]?.doubleValue ?? 0.0
                            
                            // 🎯 修复：优先使用 deviceTime，如果没有则使用 createdAt，最后使用当前时间（与 fetchLatestLocationForUser 保持一致）
                            let timestamp: String
                            if let deviceTime = object["deviceTime"]?.stringValue, !deviceTime.isEmpty {
                                timestamp = deviceTime
                            } else if let createdAt = object.createdAt {
                                timestamp = ISO8601DateFormatter().string(from: createdAt.value)
                            } else {
                                timestamp = ISO8601DateFormatter().string(from: Date())
                            }
                            
                            return LocationRecord(
                                id: objectId.hash,
                                objectId: objectId,
                                timestamp: timestamp,
                                latitude: latitude,
                                longitude: longitude,
                                accuracy: accuracy,
                                userId: userId,
                                userName: object["userName"]?.stringValue,
                                loginType: object["loginType"]?.stringValue,
                                userEmail: nil, // 🎯 不再从LocationRecord表读取userEmail，统一从UserNameRecord表读取
                                // 🎯 不再从LocationRecord表读取userAvatar，统一从UserAvatarRecord表读取
                                userAvatar: nil,
                                deviceId: deviceId,
                                clientTimestamp: nil,
                                timezone: object["timezone"]?.stringValue,
                                status: object["status"]?.stringValue,
                                recordCount: object["recordCount"]?.intValue,
                                likeCount: object["likeCount"]?.intValue
                            )
                        }
                        completion(locations, nil)
                        
                    case .failure(let error):
                        // 🎯 修改：查询失败时，如果未达到最大重试次数，触发重试
                        if retryCount < LeanCloudRetryConfig.maxRetries {
                            retryCount += 1
                            let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                attempt()
                            }
                        } else {
                            completion(nil, "查询失败: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
        
        attempt()
    }
}

