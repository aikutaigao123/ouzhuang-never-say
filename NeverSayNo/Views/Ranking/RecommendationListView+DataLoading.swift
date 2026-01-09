import SwiftUI
import CoreLocation

// MARK: - RecommendationListView Data Loading Extension
extension RecommendationListView {
    
    func loadRecommendationData() {
        // 🎯 修改：与排行榜一致，先设置加载状态，再获取黑名单与待删除账号用户ID，再进行过滤
        // 🎯 修改：使用后台加载标志（有缓存时不显示全屏 loading）
        isLoadingInBackground = true
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
                            self.isLoadingInBackground = false
                            // 🎯 新增：加载失败时触发重试
                            self.checkAndRetryLoadRecommendation()
                            return
                        }
                        
                        guard let records = locationRecords else {
                            self.isLoadingInBackground = false
                            // 🎯 新增：数据为空时触发重试
                            self.checkAndRetryLoadRecommendation()
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
                        
                        // 🎯 新增：批量查询用户钻石数
                        let userIds = validRecords.map { $0.userId }
                        RankingDataManager.shared.batchFetchUserDiamonds(userIds: userIds) { diamondsDict in
                            // 🎯 使用综合点赞数排序：点赞数 + (钻石数 × 0.01)
                            let allSortedRecords = validRecords.sorted { record1, record2 in
                                let likeCount1 = record1.likeCount ?? 0
                                let likeCount2 = record2.likeCount ?? 0
                                let diamonds1 = diamondsDict[record1.userId] ?? 0
                                let diamonds2 = diamondsDict[record2.userId] ?? 0
                                
                                // 🎯 综合点赞数 = 点赞数 + (钻石数 × 0.01)
                                let effectiveCount1 = Double(likeCount1) + (Double(diamonds1) * 0.01)
                                let effectiveCount2 = Double(likeCount2) + (Double(diamonds2) * 0.01)
                                
                                if effectiveCount1 != effectiveCount2 {
                                    return effectiveCount1 > effectiveCount2
                                }
                                // 综合点赞数相同，按时间戳降序排序（最新的在前）
                                return record1.timestamp > record2.timestamp
                            }
                            
                            // 🎯 新增：打印所有排序后的记录（包括前20条之外的）
                            for (_, record) in allSortedRecords.enumerated() {
                                // 检查是否是用户要找的那条记录
                                if record.objectId == "6920e33305564e3126332a34" {
                                }
                            }
                            
                            let sortedRecords = Array(allSortedRecords.prefix(20))
                            
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
                                        let targetDiamonds = diamondsDict[targetRecord.userId] ?? 0
                                        let targetEffectiveCount = Double(targetLikeCount) + (Double(targetDiamonds) * 0.01)
                                        
                                        let minEffectiveCountInTop20 = sortedRecords.map { record in
                                            let likes = record.likeCount ?? 0
                                            let diamonds = diamondsDict[record.userId] ?? 0
                                            return Double(likes) + (Double(diamonds) * 0.01)
                                        }.min() ?? 0.0
                                        
                                        if let rankIndex = allSortedRecords.firstIndex(where: { $0.objectId == targetId }) {
                                            let rank = rankIndex + 1
                                            self.showOutOfTopRankingHint(
                                                rank: rank,
                                                total: allSortedRecords.count,
                                                likeCount: Int(targetEffectiveCount),
                                                minTopLikeCount: Int(minEffectiveCountInTop20)
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
                                
                                let userDiamonds = diamondsDict[record.userId] ?? 0
                                
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
                                    userDiamonds: userDiamonds, // 🎯 新增：传入钻石数
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
                                        let userDiamonds = diamondsDict[targetRecord.userId] ?? 0
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
                                            userDiamonds: userDiamonds, // 🎯 新增：传入钻石数
                                            rank: rankIndex + 1
                                        )
                                        recommendationItems.append(targetItem)
                                    }
                                }
                            }
                            
                            // 🎯 修改：直接更新本地推荐数据（20条），并清空距离以便后续重新计算
                            self.recommendationItems = recommendationItems.map { item in
                                RecommendationItem(
                                    id: item.id,
                                    userId: item.userId,
                                    userName: item.userName,
                                    userAvatar: item.userAvatar,
                                    loginType: item.loginType,
                                    userEmail: item.userEmail,
                                    placeName: item.placeName,
                                    reason: item.reason,
                                    matchRate: item.matchRate,
                                    latitude: item.latitude,
                                    longitude: item.longitude,
                                    distance: nil,
                                    likeCount: item.likeCount,
                                    userDiamonds: item.userDiamonds,
                                    rank: item.rank
                                )
                            }
                            
                            // 🎯 新增：写入 UserDefaults

                            
                            if let currentUser = self.userManager.currentUser {

                                UserDefaultsManager.setTop20Recommendations(recommendationItems, userId: currentUser.userId)

                                // 🎯 验证：立即读取验证
                                let verifyData = UserDefaultsManager.getTop20Recommendations(userId: currentUser.userId)
                                if verifyData.count != recommendationItems.count {
                                } else {

                                }
                            } else {

                            }
                            
                            // 🎯 新增：记录网络数据加载完成时间并计算总耗时（按用户隔离）
                            let _ = Date()
                            if let userId = userManager.currentUser?.userId {
                                let key = "ranking_button_click_time_\(userId)"
                                if let startTime = UserDefaults.standard.object(forKey: key) as? Date {
                                    let _ = Date().timeIntervalSince(startTime)
                                    // 清理时间戳
                                    UserDefaults.standard.removeObject(forKey: key)
                                }
                            }
                            
                            self.isLoadingInBackground = false
                            
                            // 更新推荐数据后双重刷新头像缓存
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                self.refreshRecommendationAvatars()
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                self.refreshRecommendationSpecificAvatars()
                            }
                            
                            // 🎯 修改：清除距离缓存并重新计算
                            self.hasPreloadedDistances = false
                            self.isPreloadingDistances = false
                            // 重新开始批量计算距离
                            self.batchCalculateDistances()
                        } // 🎯 batchFetchUserDiamonds 闭包结束
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
                    // 🎯 新增：加载失败时触发重试
                    self.checkAndRetryLoadMyRecommendation()
                    return
                }
                
                guard let records = records else {
                    // 🎯 新增：数据为空时触发重试
                    self.checkAndRetryLoadMyRecommendation()
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
                        userDiamonds: 0, // 🎯 TODO: 需要查询用户钻石数
                        rank: 0 // 我的推荐不显示排名
                    )
                    myItems.append(item)
                }
                
                // 🎯 为我的推荐计算距离并直接更新本地状态
                if let userLocation = self.locationManager.location {
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
                            // 用带距离的新结构替换
                            if let index = myItems.firstIndex(where: { $0.id == item.id }) {
                                myItems[index] = RecommendationItem(
                                    id: item.id,
                                    userId: item.userId,
                                    userName: item.userName,
                                    userAvatar: item.userAvatar,
                                    loginType: item.loginType,
                                    userEmail: item.userEmail,
                                    placeName: item.placeName,
                                    reason: item.reason,
                                    matchRate: item.matchRate,
                                    latitude: item.latitude,
                                    longitude: item.longitude,
                                    distance: distance,
                                    likeCount: item.likeCount,
                                    userDiamonds: item.userDiamonds,
                                    rank: item.rank
                                )
                            }
                        }
                    }
                }
                
                // 更新到本地“我的推荐”状态
                self.myRecommendationsLocal = myItems
            }
        }
    }
    
    // 🎯 新增：检查并重试加载推荐榜数据（最多重试2次）
    func checkAndRetryLoadRecommendation() {
        guard retryCount < 2 else {
            return
        }
        retryCount += 1
        
        // 第一次重试：延迟1/17秒；第二次重试：延迟0.5秒
        let delay: TimeInterval = retryCount == 1 ? 1.0 / 17.0 : 0.5
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if self.recommendationItems.isEmpty {
                self.loadRecommendationData()
            }
        }
    }
    
    // 🎯 新增：检查并重试加载我的推荐数据（最多重试2次）
    func checkAndRetryLoadMyRecommendation() {
        guard myRecommendationRetryCount < 2 else {
            return
        }
        myRecommendationRetryCount += 1
        
        // 第一次重试：延迟1/17秒；第二次重试：延迟0.5秒
        let delay: TimeInterval = myRecommendationRetryCount == 1 ? 1.0 / 17.0 : 0.5
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.loadMyRecommendations()
        }
    }
}

