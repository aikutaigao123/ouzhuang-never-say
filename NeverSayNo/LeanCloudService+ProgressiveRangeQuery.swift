//
//  LeanCloudService+ProgressiveRangeQuery.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//

import Foundation
import CoreLocation
import LeanCloud

// MARK: - Progressive Range Query Extension
extension LeanCloudService {
    
    // 🎯 新增：渐进式地理范围查询（类似排行榜）
    func fetchRandomLocationWithProgressiveRange(
        currentLatitude: Double,
        currentLongitude: Double,
        currentUserId: String?,
        excludeHistory: [RandomMatchHistory],
        blacklistedIds: [String],
        pendingDeletionIds: [String],
        initialRange: Double,
        maxRange: Double,
        minCount: Int,
        currentRange: Double,
        fetchStartTime: Date,
        completion: @escaping (LocationRecord?, String?) -> Void
    ) {
        let minLat = currentLatitude - currentRange
        let maxLat = currentLatitude + currentRange
        let minLon = currentLongitude - currentRange
        let maxLon = currentLongitude + currentRange
        
        
        // 创建带地理范围的查询
        let query = LCQuery(className: "LocationRecord")
        
        // 排除当前用户
        if let currentUserId = currentUserId {
            query.whereKey("userId", .notEqualTo(currentUserId))
        }
        
        // 排除游客用户
        query.whereKey("loginType", .notEqualTo("guest"))
        
        // 添加地理范围查询条件
        query.whereKey("latitude", .greaterThanOrEqualTo(minLat))
        query.whereKey("latitude", .lessThanOrEqualTo(maxLat))
        query.whereKey("longitude", .greaterThanOrEqualTo(minLon))
        query.whereKey("longitude", .lessThanOrEqualTo(maxLon))
        
        // 设置排序和限制
        query.whereKey("createdAt", .descending)
        query.limit = 1000  // 单次查询最多1000条
        
        // 记录查询请求历史
        self.recordLocationRequest(operation: "fetchRandomLocation-progressiveRange", userId: currentUserId)
        
        // 执行查询
        _ = query.find { result in
            switch result {
            case .success(let objects):
                // 转换结果
                let locations = objects.compactMap { obj -> LocationRecord? in
                    guard let objectId = obj.objectId?.stringValue,
                          let latitude = obj["latitude"]?.doubleValue,
                          let longitude = obj["longitude"]?.doubleValue,
                          let userId = obj["userId"]?.stringValue,
                          let deviceId = obj["deviceId"]?.stringValue else {
                        return nil
                    }
                    
                    let accuracy = obj["accuracy"]?.doubleValue ?? 0.0
                    let timestamp = obj["deviceTime"]?.stringValue ?? ""
                    
                    return LocationRecord(
                        id: objectId.hash,
                        objectId: objectId,
                        timestamp: timestamp,
                        latitude: latitude,
                        longitude: longitude,
                        accuracy: accuracy,
                        userId: userId,
                        userName: obj["userName"]?.stringValue,
                        loginType: obj["loginType"]?.stringValue,
                        userEmail: nil, // 🎯 不再从LocationRecord表读取userEmail，统一从UserNameRecord表读取
                        // 🎯 不再从LocationRecord表读取userAvatar，统一从UserAvatarRecord表读取
                        userAvatar: nil,
                        deviceId: deviceId,
                        clientTimestamp: nil,
                        timezone: obj["timezone"]?.stringValue,
                        status: obj["status"]?.stringValue,
                        recordCount: obj["recordCount"]?.intValue,
                        likeCount: obj["likeCount"]?.intValue
                    )
                }
                
                
                
                // 过滤历史记录、黑名单、待删除账号
                // 🔧 修复：寻找个人匹配卡片时，应该排除所有历史记录中的userId（包括推荐卡片和个人匹配卡片）
                // 因为已经匹配过该用户了，不应该再匹配该用户的任何卡片
                let excludedUserIds = Set(excludeHistory.map { $0.record.userId })
                let blacklistedSet = Set(blacklistedIds)
                let pendingDeletionSet = Set(pendingDeletionIds)
                
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
                
                
                // 🔧 新增：打印查询到的位置数据详情（前5条）
                for (_, _) in locations.prefix(5).enumerated() {
                }
                
                var excludedByHistoryCount = 0
                var excludedByBlacklistCount = 0
                var excludedByPendingDeletionCount = 0
                
                let filteredLocations = locations.filter { location in
                    // 排除历史记录
                    if excludedUserIds.contains(location.userId) {
                        excludedByHistoryCount += 1
                        // 🔧 修复：查找该userId在历史记录中的类型
                        _ = excludeHistory.first { $0.record.userId == location.userId }
                        return false
                    } else {
                    }
                    
                    // 排除黑名单
                    let isBlacklisted = blacklistedSet.contains(location.userId) ||
                                       (location.userName != nil && blacklistedSet.contains(location.userName!)) ||
                                       blacklistedSet.contains(location.deviceId)
                    if isBlacklisted {
                        excludedByBlacklistCount += 1
                        return false
                    }
                    
                    // 排除待删除账号
                    let isPendingDeletion = pendingDeletionSet.contains(location.userId) ||
                                           (location.userName != nil && pendingDeletionSet.contains(location.userName!)) ||
                                           pendingDeletionSet.contains(location.deviceId)
                    if isPendingDeletion {
                        excludedByPendingDeletionCount += 1
                        return false
                    }
                    
                    return true
                }
                
                
                // 检查是否满足最少数量要求
                if filteredLocations.count >= minCount || currentRange >= maxRange {
                    // 满足要求或已达到最大范围，选择最佳记录
                    if filteredLocations.isEmpty {
                        if currentRange >= maxRange {
                        }
                        completion(nil, "没有可匹配的用户")
                    } else {
                        if filteredLocations.first != nil {
                        }
                        
                        // 选择距离最近且最近活跃的记录
                        let currentLocationCoord = CLLocationCoordinate2D(latitude: currentLatitude, longitude: currentLongitude)
                        let fromLocation = CLLocation(latitude: currentLocationCoord.latitude, longitude: currentLocationCoord.longitude)
                        
                        let scoredLocations: [(record: LocationRecord, distance: CLLocationDistance, lastActive: Date?)] = filteredLocations.map { record in
                            let toLocation = CLLocation(latitude: record.latitude, longitude: record.longitude)
                            let distance = fromLocation.distance(from: toLocation)
                            
                            let lastActive: Date?
                            if let date = ISO8601DateFormatter().date(from: record.timestamp) {
                                lastActive = date
                            } else {
                                lastActive = nil
                            }
                            
                            return (record, distance, lastActive)
                        }
                        
                        // 🎯 修改：±0.03度（约3330米）内的记录视为同一距离，优先选择最近活跃的用户
                        let distanceThreshold: Double = 3330.0  // 0.03度 ≈ 3.33km ≈ 3330米
                        
                        // 🎯 新增：统计最近活跃的用户数量（用于调试）
                        let now = Date()
                        let oneDayAgo = now.addingTimeInterval(-86400)  // 1天前
                        let sevenDaysAgo = now.addingTimeInterval(-604800)  // 7天前
                        
                        var usersActiveIn1Day = 0
                        var usersActiveIn7Days = 0
                        var oldestTimestamp: Date? = nil
                        var newestTimestamp: Date? = nil
                        
                        for scoredLocation in scoredLocations {
                            if let lastActive = scoredLocation.lastActive {
                                if lastActive > oneDayAgo {
                                    usersActiveIn1Day += 1
                                }
                                if lastActive > sevenDaysAgo {
                                    usersActiveIn7Days += 1
                                }
                                if oldestTimestamp == nil || lastActive < oldestTimestamp! {
                                    oldestTimestamp = lastActive
                                }
                                if newestTimestamp == nil || lastActive > newestTimestamp! {
                                    newestTimestamp = lastActive
                                }
                            }
                        }
                        
                        if oldestTimestamp != nil {
                        }
                        if newestTimestamp != nil {
                        }
                        
                        let sorted = scoredLocations.sorted { a, b in
                            // 计算距离差
                            let distanceDiff = abs(a.distance - b.distance)
                            
                            // 如果距离差在阈值内，视为同一距离，按时间排序
                            if distanceDiff <= distanceThreshold {
                                // 距离视为相同，优先选择最近活跃的用户
                                switch (a.lastActive, b.lastActive) {
                                case let (ad?, bd?):
                                    return ad > bd  // 时间更新的排在前面
                                case (_?, nil):
                                    return true     // a有时间，b没有：a排在前面
                                case (nil, _?):
                                    return false    // a没有时间，b有时间：b排在前面
                                default:
                                    return false    // 两者都没有时间：保持原顺序
                                }
                            } else {
                                // 距离差超过阈值，按距离排序
                                return a.distance < b.distance
                            }
                        }
                        
                        
                        let selectedLocation = sorted.first?.record ?? filteredLocations.first!
                        
                        
                        
                        completion(selectedLocation, nil)
                    }
                } else {
                    // 不满足要求且未达到最大范围，扩大范围继续查询
                    let nextRange = min(currentRange + 0.03, maxRange)  // 每次增加0.03度
                    self.fetchRandomLocationWithProgressiveRange(
                        currentLatitude: currentLatitude,
                        currentLongitude: currentLongitude,
                        currentUserId: currentUserId,
                        excludeHistory: excludeHistory,
                        blacklistedIds: blacklistedIds,
                        pendingDeletionIds: pendingDeletionIds,
                        initialRange: initialRange,
                        maxRange: maxRange,
                        minCount: minCount,
                        currentRange: nextRange,
                        fetchStartTime: fetchStartTime,
                        completion: completion
                    )
                }
                
            case .failure(let error):
                completion(nil, "查询失败: \(error.localizedDescription)")
            }
        }
    }
}

