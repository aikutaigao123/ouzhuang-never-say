//
//  LeanCloudService+RandomLocationFetch.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//

import Foundation
import CoreLocation
import LeanCloud

// MARK: - Random Location Fetch Extension
extension LeanCloudService {
    
    /// 获取随机位置 - 遵循数据存储开发指南
    /// 使用 LCQuery 进行优化查询，服务器端过滤，避免获取全量数据
    /// 使用分页获取最多 10000 条记录（LeanCloud limit 最大为 1000，需要分页）
    func fetchRandomLocation(currentLocation: CLLocationCoordinate2D?, currentUserId: String?, excludeHistory: [RandomMatchHistory] = [], blacklistedIds: [String] = [], pendingDeletionIds: [String] = [], completion: @escaping (LocationRecord?, String?) -> Void) {
        let fetchRandomLocationStartTime = Date()
        
        // 🎯 优化：如果有当前位置，使用渐进式地理范围查询（类似排行榜）
        if let currentLocation = currentLocation {
            // 将WGS-84转换为GCJ-02（LocationRecord表中的坐标是GCJ-02）
            let (gcjLat, gcjLon) = CoordinateConverter.wgs84ToGcj02(
                latitude: currentLocation.latitude,
                longitude: currentLocation.longitude
            )
            
            // 使用渐进式地理范围查询
            self.fetchRandomLocationWithProgressiveRange(
                currentLatitude: gcjLat,
                currentLongitude: gcjLon,
                currentUserId: currentUserId,
                excludeHistory: excludeHistory,
                blacklistedIds: blacklistedIds,
                pendingDeletionIds: pendingDeletionIds,
                initialRange: 0.03,  // 初始范围±0.03度（约±3.3km）
                maxRange: 1.0,      // 最大范围±1.0度（约111km）
                minCount: 1,        // 至少需要1条记录
                currentRange: 0.03,
                fetchStartTime: fetchRandomLocationStartTime,
                completion: completion
            )
            return
        }
        
        // 没有当前位置时，使用原有的全量查询方式
        let targetLimit = 10000
        let pageSize = 1000 // LeanCloud 单次查询最大 limit
        let totalPages = (targetLimit + pageSize - 1) / pageSize // 计算总页数（向上取整）
        
        // 每次新的查询开始时，重试计数从0开始（每次点击"寻找"按钮时重置）
        
        // 辅助函数：转换 LCObject 为 LocationRecord
        func convertToLocationRecord(_ obj: LCObject) -> LocationRecord? {
            guard let objectId = obj.objectId?.stringValue,
                  let latitude = obj["latitude"]?.doubleValue,
                  let longitude = obj["longitude"]?.doubleValue,
                  let userId = obj["userId"]?.stringValue,
                  let deviceId = obj["deviceId"]?.stringValue else {
                return nil
            }
            
            let accuracy = obj["accuracy"]?.doubleValue ?? 0.0
            
            // 🎯 修复：优先使用 deviceTime，如果没有则使用 createdAt，最后使用当前时间（与 fetchLatestLocationForUser 保持一致）
            let timestamp: String
            if let deviceTime = obj["deviceTime"]?.stringValue, !deviceTime.isEmpty {
                timestamp = deviceTime
            } else if let createdAt = obj.createdAt {
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
        
        // 并行查询所有页面
        // 使用线程安全的数组来收集结果
        let resultsQueue = DispatchQueue(label: "com.neverSayNo.fetchRandomLocation.results")
        var pageResults: [(pageIndex: Int, locations: [LocationRecord], error: LCError?)] = []
        let dispatchGroup = DispatchGroup()
        let apiInterval: TimeInterval = 1.0 / 17.0 // 1/17秒间隔
        
        
        // 并行发起所有页面的查询，但每个API调用之间保持1/17秒间隔
        for pageIndex in 0..<totalPages {
            let skip = pageIndex * pageSize
            let currentLimit = min(pageSize, targetLimit - skip)
            
            dispatchGroup.enter()
            
            // 计算延迟时间：每个API调用之间间隔1/17秒
            let delay = TimeInterval(pageIndex) * apiInterval
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                // 记录查询请求历史
                self.recordLocationRequest(operation: "fetchRandomLocation-query", userId: currentUserId)
                
                // 构建查询条件（使用 LCQuery）
                let query = LCQuery(className: "LocationRecord")
                
                // 排除当前用户
                if let currentUserId = currentUserId {
                    query.whereKey("userId", .notEqualTo(currentUserId))
                }
                
                // 排除游客用户
                query.whereKey("loginType", .notEqualTo("guest"))
                
                // 设置排序和分页
                query.whereKey("createdAt", .descending)
                query.limit = currentLimit
                query.skip = skip
                
                // 执行查询
                _ = query.find { result in
                    switch result {
                    case .success(let objects):
                        let pageLocations = objects.compactMap { convertToLocationRecord($0) }
                        
                        resultsQueue.async {
                            pageResults.append((pageIndex: pageIndex, locations: pageLocations, error: nil))
                            dispatchGroup.leave()
                        }
                        
                    case .failure(let error):
                        let lcError = error
                        
                        resultsQueue.async {
                            pageResults.append((pageIndex: pageIndex, locations: [], error: lcError))
                            dispatchGroup.leave()
                        }
                    }
                }
            }
        }
        
        // 用于存储所有位置记录的变量
        var allLocations: [LocationRecord] = []
        
        // 等待所有查询完成
        dispatchGroup.notify(queue: .main) {
            // 按页面索引排序，合并所有结果
            pageResults.sort { $0.pageIndex < $1.pageIndex }
            var mergedLocations: [LocationRecord] = []
            
            var successPages = 0
            var failedPages = 0
            var totalRecords = 0
            
            for result in pageResults {
                mergedLocations.append(contentsOf: result.locations)
                totalRecords += result.locations.count
                
                if result.error == nil {
                    successPages += 1
                } else {
                    failedPages += 1
                }
                
                // 如果某页返回0条记录，说明没有更多数据了
                if result.locations.isEmpty && result.error == nil {
                    break
                }
                
                // 如果已达到目标数量，停止
                if mergedLocations.count >= targetLimit {
                    break
                }
            }
            
            // 更新allLocations并处理
            allLocations = mergedLocations
            processLocations()
        }
        
        // 处理所有获取到的位置数据
        func processLocations() {
            // 客户端过滤：排除历史记录（因为历史记录是动态的，无法在服务器端提前过滤）
            // 🔧 修复：寻找个人匹配卡片时，应该排除所有历史记录中的userId（包括推荐卡片和个人匹配卡片）
            // 因为已经匹配过该用户了，不应该再匹配该用户的任何卡片
            let excludedUserIds = Set(excludeHistory.map { $0.record.userId })
            
            // 第一步：过滤历史记录
            var excludedByHistoryCount = 0
            var filteredLocations = allLocations.filter { location in
                        let shouldExclude = excludedUserIds.contains(location.userId)
                        if shouldExclude {
                            excludedByHistoryCount += 1
                            // 🔧 修复：查找该userId在历史记录中的类型
                            _ = excludeHistory.first { $0.record.userId == location.userId }
                        }
                        return !shouldExclude
                    }
            
            // 第二步：过滤黑名单用户和设备（与排行榜逻辑一致）
            let blacklistedSet = Set(blacklistedIds)
            let pendingDeletionSet = Set(pendingDeletionIds)
                    
                    
                    var excludedByBlacklistCount = 0
                    var excludedByPendingDeletionCount = 0
                    
                    // 🎯 新增：获取本地黑名单
                    let localBlacklistedUserIds = LocalBlacklistManager.shared.getAllLocalBlacklistedUserIds()
                    
                    filteredLocations = filteredLocations.filter { location in
                        // 🎯 新增：检查本地黑名单
                        if localBlacklistedUserIds.contains(location.userId) {
                            excludedByBlacklistCount += 1
                            return false
                        }
                        
                        // 检查黑名单：同时检查用户ID、用户名和设备ID（与排行榜逻辑一致）
                        let isBlacklisted = blacklistedSet.contains(location.userId) ||
                                           (location.userName != nil && blacklistedSet.contains(location.userName!)) ||
                                           blacklistedSet.contains(location.deviceId)
                        
                        if isBlacklisted {
                            excludedByBlacklistCount += 1
                            return false
                        }
                        
                        // 检查待删除账号：检查用户ID、用户名和设备ID（与排行榜逻辑一致）
                        let isPendingDeletion = pendingDeletionSet.contains(location.userId) ||
                                               (location.userName != nil && pendingDeletionSet.contains(location.userName!)) ||
                                               pendingDeletionSet.contains(location.deviceId)
                        
                        if isPendingDeletion {
                            excludedByPendingDeletionCount += 1
                            return false
                        }
                        
                        return true
                    }
            
            // 根据"谁离我近、谁最近上线"进行优先级排序
                    if filteredLocations.isEmpty {
                        
                        // 详细分析为什么没有找到匹配结果
                        
                        // 分析原始记录的用户分布
                        if !allLocations.isEmpty {
                            
                            
                            // 统计被排除的用户
                            let excludedCount = allLocations.filter { excludedUserIds.contains($0.userId) }.count
                            
                            
                            // 如果所有记录都被排除了，列出前几个被排除的userId
                            if excludedCount == allLocations.count {
                            }
                            
                            // 列出原始记录中的前几个userId（用于对比）
                        } else {
                        }
                        completion(nil, "没有可匹配的用户")
                    } else {
                        let selectedLocation: LocationRecord
                        
                        // 优先使用当前位置和时间进行排序
                        if let currentLocation = currentLocation {
                            // 预构建当前位置 CLLocation
                            let fromLocation = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
                            
                            // 带距离与时间信息的列表
                            let scoredLocations: [(record: LocationRecord, distance: CLLocationDistance, lastActive: Date?)] = filteredLocations.map { record in
                                let toLocation = CLLocation(latitude: record.latitude, longitude: record.longitude)
                                let distance = fromLocation.distance(from: toLocation)
                                
                                // 使用 deviceTime（LocationRecord.timestamp）作为最近活跃时间
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
                            
                            selectedLocation = sorted.first?.record ?? filteredLocations.first!
                        } else {
                            // 没有当前位置时，仅按时间新旧排序
                            let formatter = ISO8601DateFormatter()
                            let sortedByTime = filteredLocations.sorted { a, b in
                                let ad = formatter.date(from: a.timestamp)
                                let bd = formatter.date(from: b.timestamp)
                                switch (ad, bd) {
                                case let (ad?, bd?):
                                    return ad > bd // 时间越新越靠前
                                case (_?, nil):
                                    return true
                                case (nil, _?):
                                    return false
                                default:
                                    return false
                                }
                            }
                            selectedLocation = sortedByTime.first ?? filteredLocations.first!
                        }
                        
                        completion(selectedLocation, nil)
                    }
        }
        
        // 并行查询已在上面的循环中启动，无需额外调用
    }
}

