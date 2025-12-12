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
    func fetchLocations(completion: @escaping ([LocationRecord]?, String?) -> Void) {
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
                        let timestamp = object["deviceTime"]?.stringValue ?? ""
                        
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
                    completion(nil, "查询失败: \(error.localizedDescription)")
                }
            }
        }
    }
}

