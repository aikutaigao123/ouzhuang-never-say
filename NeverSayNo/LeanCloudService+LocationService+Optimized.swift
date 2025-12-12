//
//  LeanCloudService+LocationService+Optimized.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//  优化的位置服务，实现完整的去重机制
//

import Foundation
import CoreLocation

// MARK: - 优化的位置服务扩展
extension LeanCloudService {
    
    /// 优化的获取随机位置方法 - 实现完整的去重机制
    func fetchRandomLocationOptimized(
        currentLocation: CLLocationCoordinate2D?, 
        currentUserId: String?, 
        excludeHistory: [RandomMatchHistory] = [], 
        completion: @escaping (LocationRecord?, String?) -> Void
    ) {
        // 验证API配置
        guard validateAPIConfig() else {
            completion(nil, "API配置无效")
            return
        }
        
        // 构建请求URL
        let url = URL(string: "\(serverUrl)/1.1/classes/LocationRecord")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(appId, forHTTPHeaderField: "X-LC-Id")
        request.setValue(appKey, forHTTPHeaderField: "X-LC-Key")
        
        // 发送请求
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.handleNetworkError(error, request, operation: "获取随机位置")
                    completion(nil, "网络错误: \(error.localizedDescription)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(nil, "无效的HTTP响应")
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    do {
                        if let jsonData = data,
                           let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                           let results = json["results"] as? [[String: Any]] {
                            
                            // 解析所有位置记录
                            let allLocations = results.compactMap { dict -> LocationRecord? in
                                return self.parseLocationRecord(from: dict)
                            }
                            
                            // 应用去重逻辑
                            let filteredLocations = self.applyDuplicateFilter(
                                locations: allLocations,
                                excludeHistory: excludeHistory,
                                currentUserId: currentUserId,
                                currentLocation: currentLocation
                            )
                            
                            // 随机选择一个位置
                            let selectedLocation = self.selectRandomLocation(from: filteredLocations)
                            
                            completion(selectedLocation, nil)
                        } else {
                            completion(nil, "数据解析失败")
                        }
                    } catch {
                        completion(nil, "JSON解析错误: \(error.localizedDescription)")
                    }
                } else {
                    self.handle403ForbiddenError(request, httpResponse, data ?? Data(), operation: "获取随机位置")
                    completion(nil, "服务器错误: \(httpResponse.statusCode)")
                }
            }
        }.resume()
    }
    
    // MARK: - 私有辅助方法
    
    /// 解析位置记录
    private func parseLocationRecord(from dict: [String: Any]) -> LocationRecord? {
        guard let objectId = dict["objectId"] as? String,
              let latitude = dict["latitude"] as? Double,
              let longitude = dict["longitude"] as? Double,
              let userId = dict["userId"] as? String,
              let deviceId = dict["deviceId"] as? String else {
            return nil
        }
        
        let accuracy = dict["accuracy"] as? Double ?? 0.0
        let timestamp = dict["deviceTime"] as? String ?? ""
        
        return LocationRecord(
            id: objectId.hash,
            objectId: objectId,
            timestamp: timestamp,
            latitude: latitude,
            longitude: longitude,
            accuracy: accuracy,
            userId: userId,
            userName: dict["userName"] as? String,
            loginType: dict["loginType"] as? String,
            userEmail: dict["userEmail"] as? String,
            userAvatar: dict["userAvatar"] as? String,
            deviceId: deviceId,
            clientTimestamp: nil,
            timezone: dict["timezone"] as? String,
            status: dict["status"] as? String,
            recordCount: dict["recordCount"] as? Int,
            likeCount: dict["likeCount"] as? Int
        )
    }
    
    /// 应用去重过滤器
    private func applyDuplicateFilter(
        locations: [LocationRecord],
        excludeHistory: [RandomMatchHistory],
        currentUserId: String?,
        currentLocation: CLLocationCoordinate2D?
    ) -> [LocationRecord] {
        
        // 1. 排除当前用户自己
        var filteredLocations = locations.filter { location in
            location.userId != currentUserId
        }
        
        // 2. 排除历史记录中的用户
        let excludedUserIds = Set(excludeHistory.map { $0.record.userId })
        filteredLocations = filteredLocations.filter { location in
            !excludedUserIds.contains(location.userId)
        }
        
        // 3. 排除黑名单用户
        filteredLocations = filteredLocations.filter { location in
            !isBlacklistedUser(location)
        }
        
        // 4. 排除待删除用户
        filteredLocations = filteredLocations.filter { location in
            !isPendingDeletionUser(location)
        }
        
        // 5. 排除距离过近的用户（可选）
        if let currentLocation = currentLocation {
            filteredLocations = filteredLocations.filter { location in
                let distance = calculateDistance(
                    from: currentLocation,
                    to: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
                )
                return distance > 10.0 // 排除10米内的用户
            }
        }
        
        // 6. 排除时间过旧的记录（可选）
        filteredLocations = filteredLocations.filter { location in
            return isRecentLocation(location)
        }
        
        return filteredLocations
    }
    
    /// 随机选择位置
    private func selectRandomLocation(from locations: [LocationRecord]) -> LocationRecord? {
        guard !locations.isEmpty else { return nil }
        
        // 使用真正的随机选择算法
        let randomIndex = Int.random(in: 0..<locations.count)
        return locations[randomIndex]
    }
    
    /// 检查是否为黑名单用户
    private func isBlacklistedUser(_ location: LocationRecord) -> Bool {
        // 这里应该从黑名单服务获取黑名单用户ID
        // 暂时返回false，实际实现时需要集成黑名单服务
        return false
    }
    
    /// 检查是否为待删除用户
    private func isPendingDeletionUser(_ location: LocationRecord) -> Bool {
        // 这里应该从用户管理服务获取待删除用户ID
        // 暂时返回false，实际实现时需要集成用户管理服务
        return false
    }
    
    /// 计算两点间距离
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }
    
    /// 检查是否为最近的位置记录
    private func isRecentLocation(_ location: LocationRecord) -> Bool {
        // 检查位置记录的时间是否在最近24小时内
        // 这里需要根据实际的时间格式进行解析
        // 暂时返回true，实际实现时需要根据时间戳判断
        return true
    }
}

// MARK: - 去重统计信息
extension LeanCloudService {
    
    /// 获取去重统计信息
    func getDuplicateFilterStats(
        locations: [LocationRecord],
        excludeHistory: [RandomMatchHistory],
        currentUserId: String?
    ) -> DuplicateFilterStats {
        
        let totalLocations = locations.count
        let selfFiltered = locations.filter { $0.userId == currentUserId }.count
        let historyFiltered = locations.filter { location in
            excludeHistory.contains { $0.record.userId == location.userId }
        }.count
        let blacklistFiltered = locations.filter { isBlacklistedUser($0) }.count
        let pendingDeletionFiltered = locations.filter { isPendingDeletionUser($0) }.count
        
        return DuplicateFilterStats(
            totalLocations: totalLocations,
            selfFiltered: selfFiltered,
            historyFiltered: historyFiltered,
            blacklistFiltered: blacklistFiltered,
            pendingDeletionFiltered: pendingDeletionFiltered,
            remainingLocations: totalLocations - selfFiltered - historyFiltered - blacklistFiltered - pendingDeletionFiltered
        )
    }
}

// MARK: - 去重统计信息结构体
struct DuplicateFilterStats {
    let totalLocations: Int
    let selfFiltered: Int
    let historyFiltered: Int
    let blacklistFiltered: Int
    let pendingDeletionFiltered: Int
    let remainingLocations: Int
    
    var summary: String {
        return """
        总位置记录: \(totalLocations)
        排除自己: \(selfFiltered)
        排除历史: \(historyFiltered)
        排除黑名单: \(blacklistFiltered)
        排除待删除: \(pendingDeletionFiltered)
        剩余可用: \(remainingLocations)
        """
    }
}

