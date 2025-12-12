import SwiftUI
import CoreLocation

// MARK: - RecommendationListView Data Loading Extension
extension RecommendationListView {
    
    func loadRecommendationData() {
        // 🎯 修改：与排行榜一致，先设置加载状态，再获取黑名单与待删除账号用户ID，再进行过滤
        isLoading = true
        LeanCloudService.shared.fetchBlacklist { blacklistedDeviceIds, _ in
            let blacklistedIds = blacklistedDeviceIds ?? []
            
            LeanCloudService.shared.fetchPendingDeletionUserIds { pendingDeletionUserIds, _ in
                let deletionIds = Set(pendingDeletionUserIds ?? [])
                
                // 🎯 获取当前位置（GCJ-02坐标）用于地理范围查询
                var currentLat: Double? = nil
                var currentLon: Double? = nil
                if let userLocation = locationManager.location {
                    // 将WGS-84转换为GCJ-02用于查询（Recommendation表中的坐标是GCJ-02）
                    let (gcjLat, gcjLon) = CoordinateConverter.wgs84ToGcj02(
                        latitude: userLocation.coordinate.latitude,
                        longitude: userLocation.coordinate.longitude
                    )
                    currentLat = gcjLat
                    currentLon = gcjLon
                }
                
                // 🎯 新增：定义用户要找的记录ID
                let targetObjectId = "6920e33305564e3126332a34"
                
                // 从Recommendation表获取数据，根据like_count排序
                LeanCloudService.shared.fetchAllRecommendations(currentLatitude: currentLat, currentLongitude: currentLon) { locationRecords, error in
                    DispatchQueue.main.async {
                        if let error = error, !error.isEmpty {
                            self.isLoading = false
                            return
                        }
                        
                        guard let records = locationRecords else {
                            self.isLoading = false
                            return
                        }
                        
                        // 🎯 新增：检查用户要找的记录是否在查询结果中
                        if records.first(where: { $0.objectId == targetObjectId }) != nil {
                        } else {
                        }
                        
                        
                        // 🎯 新增：检查新上传的项目是否在原始数据中
                        if let targetId = highlightedItemId {
                            let foundInRaw = records.contains { $0.objectId == targetId }
                            if foundInRaw {
                                if records.first(where: { $0.objectId == targetId }) != nil {
                                }
                            }
                        }
                        
                        // 🎯 修改：与排行榜一致，过滤掉游客用户、黑名单用户和设备、待删除账号、用户名为空
                        let validRecords = records.filter { record in
                            // 🎯 新增：检查是否是用户要找的记录
                            let isTargetRecord = record.objectId == targetObjectId
                            
                            // 过滤掉用户名为空或无效（避免显示"未知用户"）
                            if let userName = record.userName, !userName.isEmpty {
                                // 用户名有效，继续检查
                            } else {
                                if isTargetRecord {
                                }
                                return false
                            }
                            
                            // 过滤掉游客用户
                            if record.loginType == "guest" {
                                if isTargetRecord {
                                }
                                return false
                            }
                            
                            // 🎯 新增：检查本地黑名单
                            let localBlacklistedUserIds = LocalBlacklistManager.shared.getAllLocalBlacklistedUserIds()
                            if localBlacklistedUserIds.contains(record.userId) {
                                if isTargetRecord {
                                }
                                return false
                            }
                            
                            // 🎯 修复：同时检查用户ID、用户名和设备ID（黑名单可能包含这三者中的任意一个）
                            if blacklistedIds.contains(record.userId) ||
                               (record.userName != nil && blacklistedIds.contains(record.userName!)) ||
                               blacklistedIds.contains(record.deviceId) {
                                if isTargetRecord {
                                }
                                return false
                            }
                            
                            // 过滤掉待删除账号（检查用户ID、用户名、设备ID）
                            let isPendingDeletion = deletionIds.contains(record.userId) ||
                                (record.userName != nil && deletionIds.contains(record.userName!)) ||
                                deletionIds.contains(record.deviceId)
                            
                            if isPendingDeletion {
                                if isTargetRecord {
                                }
                                return false
                            }
                            
                            return true
                        }
                        
                        // 🎯 新增：检查用户要找的记录是否在有效记录中
                        if validRecords.first(where: { $0.objectId == targetObjectId }) != nil {
                        } else if records.contains(where: { $0.objectId == targetObjectId }) {
                        }
                        
                        
                        // 🎯 新增：检查新上传的项目是否在有效记录中
                        if let targetId = highlightedItemId {
                            let foundInValid = validRecords.contains { $0.objectId == targetId }
                            if !foundInValid && records.contains(where: { $0.objectId == targetId }) {
                                if records.first(where: { $0.objectId == targetId }) != nil {
                                }
                            }
                        }
                        
                        // 按排名规则排序：点赞数优先，若相同则按时间戳（最新优先）
                        let allSortedRecords = sortRecordsByRanking(validRecords)
                        
                        // 🎯 新增：打印所有排序后的记录（包括前20条之外的）
                        for (_, record) in allSortedRecords.enumerated() {
                            // 检查是否是用户要找的那条记录
                            if record.objectId == "6920e33305564e3126332a34" {
                            }
                        }
                        
                        let sortedRecords = allSortedRecords.prefix(20)
                        
                        for _ in sortedRecords {
                        }
                        
                        // 🎯 新增：检查新上传的项目是否在前20个中
                        var targetRecordForHint: LocationRecord? = nil
                        if let targetId = highlightedItemId {
                            let foundInTop20 = sortedRecords.contains { $0.objectId == targetId }
                            if !foundInTop20 && validRecords.contains(where: { $0.objectId == targetId }) {
                                if let targetRecord = validRecords.first(where: { $0.objectId == targetId }) {
                                    targetRecordForHint = targetRecord
                                    let targetLikeCount = targetRecord.likeCount ?? 0
                                    let minLikeCountInTop20 = sortedRecords.map { $0.likeCount ?? 0 }.min() ?? 0
                                    if let rankIndex = allSortedRecords.firstIndex(where: { $0.objectId == targetId }) {
                                        let rank = rankIndex + 1
                                        self.showOutOfTopRankingHint(
                                            rank: rank,
                                            total: allSortedRecords.count,
                                            likeCount: targetLikeCount,
                                            minTopLikeCount: minLikeCountInTop20
                                        )
                                    }
                                }
                            }
                        }
                        
                        // 转换为RecommendationItem
                        var recommendationItems: [RecommendationItem] = []
                        for (index, record) in sortedRecords.enumerated() {
                            // 🔧 修复：优先显示 reason 字段，如果 reason 为空或为空字符串，才显示"获得 X 个点赞"
                            let displayReason: String
                            if let reason = record.reason, !reason.trimmingCharacters(in: .whitespaces).isEmpty {
                                // 有 reason 且不为空，直接使用
                                displayReason = reason
                            } else {
                                // reason 为空，显示"获得 X 个点赞"
                                displayReason = "获得 \(record.likeCount ?? 0) 个点赞"
                            }
                            
                            let item = RecommendationItem(
                                id: record.objectId,
                                userId: record.userId,  // 保存实际的用户ID
                                userName: record.userName ?? "未知用户",
                                userAvatar: record.userAvatar ?? (record.loginType == "apple" ? "person.circle.fill" : "person.circle"), // 与用户头像界面一致：根据loginType设置默认头像
                                loginType: record.loginType, // 传递loginType
                                userEmail: record.userEmail, // 🎯 新增：传递用户邮箱
                                placeName: record.placeName ?? "",
                                reason: displayReason, // 🎯 修改：优先使用 reason 字段
                                matchRate: min(100, (record.likeCount ?? 0) * 5), // 根据点赞数计算匹配率
                                latitude: record.latitude,
                                longitude: record.longitude,
                                distance: nil,
                                likeCount: record.likeCount ?? 0,
                                rank: index + 1 // 添加排名
                            )
                            recommendationItems.append(item)
                        }
                        
                        // 🎯 新增：如果正在显示紫色提示卡片且目标项目不在前20名中，临时添加到列表末尾
                        if showOutOfTopHint, let targetRecord = targetRecordForHint, let targetId = highlightedItemId {
                            let alreadyInList = recommendationItems.contains { $0.id == targetId }
                            if !alreadyInList {
                                let displayReason: String
                                if let reason = targetRecord.reason, !reason.trimmingCharacters(in: .whitespaces).isEmpty {
                                    displayReason = reason
                                } else {
                                    displayReason = "获得 \(targetRecord.likeCount ?? 0) 个点赞"
                                }
                                
                                if let rankIndex = allSortedRecords.firstIndex(where: { $0.objectId == targetId }) {
                                    let targetItem = RecommendationItem(
                                        id: targetRecord.objectId,
                                        userId: targetRecord.userId,
                                        userName: targetRecord.userName ?? "未知用户",
                                        userAvatar: targetRecord.userAvatar ?? (targetRecord.loginType == "apple" ? "person.circle.fill" : "person.circle"),
                                        loginType: targetRecord.loginType,
                                        userEmail: targetRecord.userEmail,
                                        placeName: targetRecord.placeName ?? "",
                                        reason: displayReason,
                                        matchRate: min(100, (targetRecord.likeCount ?? 0) * 5),
                                        latitude: targetRecord.latitude,
                                        longitude: targetRecord.longitude,
                                        distance: nil,
                                        likeCount: targetRecord.likeCount ?? 0,
                                        rank: rankIndex + 1
                                    )
                                    recommendationItems.append(targetItem)
                                }
                            }
                        }
                
                        
                        self.recommendationData = recommendationItems
                        self.allRecommendationData = recommendationItems // 🎯 新增：保存所有原始数据
                        self.isLoading = false
                        
                        // 🎯 新增：打印推荐榜的所有内容
                        if recommendationItems.isEmpty {
                        } else {
                            for item in recommendationItems {
                                if item.latitude != nil && item.longitude != nil {
                                } else {
                                }
                                if item.distance != nil {
                                } else {
                                }
                            }
                        }
                        
                        
                        // 更新推荐数据后双重刷新头像缓存
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.refreshRecommendationAvatars()
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            self.refreshRecommendationSpecificAvatars()
                        }
                        
                        // 🎯 修改：刷新数据后，清除距离缓存并重新计算距离（确保新上传的项目距离正确）
                        // 清除距离缓存，强制重新计算所有项目的距离
                        self.distanceCache.removeAll()
                        self.hasPreloadedDistances = false
                        self.isPreloadingDistances = false
                        // 重新开始批量计算距离
                        self.batchCalculateDistances()
                    }
                }
            }
        }
    }
    
    func sortRecordsByRanking(_ records: [LocationRecord]) -> [LocationRecord] {
        return records.sorted { record1, record2 in
            let likeCount1 = record1.likeCount ?? 0
            let likeCount2 = record2.likeCount ?? 0
            if likeCount1 != likeCount2 {
                return likeCount1 > likeCount2
            }
            // 点赞数相同，按时间戳降序排序（最新的在前）
            return record1.timestamp > record2.timestamp
        }
    }
    
    // 🎯 新增：加载当前账号发送过的所有推荐
    func loadMyRecommendations() {
        guard let currentUserId = userManager.currentUser?.userId else {
            return
        }
        
        isLoadingMyRecommendations = true
        
        LeanCloudService.shared.fetchRecommendationsByUserId(userId: currentUserId) { records, error in
            DispatchQueue.main.async {
                self.isLoadingMyRecommendations = false
                
                if let error = error, !error.isEmpty {
                    return
                }
                
                guard let records = records else {
                    return
                }
                
                // 转换为RecommendationItem
                var myItems: [RecommendationItem] = []
                for record in records {
                    let displayReason: String
                    if let reason = record.reason, !reason.trimmingCharacters(in: .whitespaces).isEmpty {
                        displayReason = reason
                    } else {
                        displayReason = "获得 \(record.likeCount ?? 0) 个点赞"
                    }
                    
                    let item = RecommendationItem(
                        id: record.objectId,
                        userId: record.userId,
                        userName: record.userName ?? "未知用户",
                        userAvatar: record.userAvatar ?? (record.loginType == "apple" ? "person.circle.fill" : "person.circle"),
                        loginType: record.loginType,
                        userEmail: record.userEmail,
                        placeName: record.placeName ?? "",
                        reason: displayReason,
                        matchRate: min(100, (record.likeCount ?? 0) * 5),
                        latitude: record.latitude,
                        longitude: record.longitude,
                        distance: nil,
                        likeCount: record.likeCount ?? 0,
                        rank: 0 // 我的推荐不显示排名
                    )
                    myItems.append(item)
                }
                
                self.myRecommendations = myItems
                
                // 为我的推荐计算距离
                if let userLocation = locationManager.location {
                    for item in myItems {
                        if let latitude = item.latitude, let longitude = item.longitude {
                            let (gcjLat, gcjLon) = CoordinateConverter.wgs84ToGcj02(
                                latitude: userLocation.coordinate.latitude,
                                longitude: userLocation.coordinate.longitude
                            )
                            let gcjUserLocation = CLLocation(latitude: gcjLat, longitude: gcjLon)
                            let distance = DistanceUtils.calculateDistance(
                                from: gcjUserLocation,
                                to: latitude,
                                targetLongitude: longitude
                            )
                            self.distanceCache[item.id] = distance
                        }
                    }
                }
            }
        }
    }
}

