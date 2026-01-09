import Foundation
import LeanCloud

// MARK: - 排行榜功能扩展
extension LeanCloudService {
    
    // 🎯 修改：获取排行榜数据 - 使用 LCQuery（与推荐榜一致）
    func getRankingList(currentLatitude: Double? = nil, currentLongitude: Double? = nil, completion: @escaping ([UserScore]?, String) -> Void) {

        
        // 🎯 新增：如果提供了当前位置，使用渐进式地理范围查询
        if let lat = currentLatitude, let lon = currentLongitude {

            self.getRankingListWithProgressiveRange(
                currentLatitude: lat,
                currentLongitude: lon,
                initialRange: 0.03,  // 初始范围±0.03度
                maxRange: 1.0,       // 最大范围±1.0度（约111km）
                minCount: 20,       // 最少需要20条
                currentRange: 0.03,
                completion: completion
            )
        } else {

            // 没有当前位置，使用全量查询
            self.performRankingQuery(query: self.createBaseRankingQuery(), completion: completion)
        }
    }
    
    // 🎯 新增：创建基础查询（不带地理范围）
    private func createBaseRankingQuery() -> LCQuery {
        let query = LCQuery(className: "UserScore")
        query.whereKey("totalScore", .descending)
        query.limit = 1000
        return query
    }
    
    // 🎯 新增：渐进式地理范围查询
    private func getRankingListWithProgressiveRange(
        currentLatitude: Double,
        currentLongitude: Double,
        initialRange: Double,
        maxRange: Double,
        minCount: Int,
        currentRange: Double,
        completion: @escaping ([UserScore]?, String) -> Void
    ) {
        let minLat = currentLatitude - currentRange
        let maxLat = currentLatitude + currentRange
        let minLon = currentLongitude - currentRange
        let maxLon = currentLongitude + currentRange
        
        
        // 创建带地理范围的查询
        let query = self.createBaseRankingQuery()
        query.whereKey("latitude", .greaterThanOrEqualTo(minLat))
        query.whereKey("latitude", .lessThanOrEqualTo(maxLat))
        query.whereKey("longitude", .greaterThanOrEqualTo(minLon))
        query.whereKey("longitude", .lessThanOrEqualTo(maxLon))
        
        self.performRankingQuery(query: query) { userScores, error in
            if !error.isEmpty {
                completion(nil, error)
                return
            }
            
            guard let userScores = userScores else {

                completion(nil, "查询结果为空")
                return
            }
            
            // 🎯 新增：客户端验证过滤 - 检查返回的记录是否在查询范围内
            var validUserScores: [UserScore] = []
            var invalidCount = 0
            
            for userScore in userScores {
                guard let latitude = userScore.latitude, let longitude = userScore.longitude else {
                    invalidCount += 1
                    continue
                }
                
                let inLatRange = latitude >= minLat && latitude <= maxLat
                let inLonRange = longitude >= minLon && longitude <= maxLon
                let inRange = inLatRange && inLonRange
                
                if inRange {
                    validUserScores.append(userScore)
                } else {
                    invalidCount += 1
                }
            }
            
            // 🎯 如果有效记录数不足，需要扩大范围继续查询
            if validUserScores.count < minCount && currentRange < maxRange {
                // 扩大范围继续查询
                let nextRange = min(currentRange + 0.03, maxRange)
                self.getRankingListWithProgressiveRange(
                    currentLatitude: currentLatitude,
                    currentLongitude: currentLongitude,
                    initialRange: initialRange,
                    maxRange: maxRange,
                    minCount: minCount,
                    currentRange: nextRange,
                    completion: completion
                )
                return
            }
            
            // 使用过滤后的有效记录
            let filteredUserScores = validUserScores
            
            // 检查是否满足最少数量要求（使用过滤后的记录）
            let hasEnoughRecords = filteredUserScores.count >= minCount
            let reachedMaxRange = currentRange >= maxRange
            
            if hasEnoughRecords || reachedMaxRange {
                // 满足要求或已达到最大范围，返回过滤后的结果
                completion(filteredUserScores, "")
            } else {
                // 不满足要求且未达到最大范围，扩大范围继续查询
                let nextRange = min(currentRange + 0.03, maxRange)  // 每次增加0.03度
                self.getRankingListWithProgressiveRange(
                    currentLatitude: currentLatitude,
                    currentLongitude: currentLongitude,
                    initialRange: initialRange,
                    maxRange: maxRange,
                    minCount: minCount,
                    currentRange: nextRange,
                    completion: completion
                )
            }
        }
    }
    
    // 🎯 新增：执行查询并解析结果
    private func performRankingQuery(query: LCQuery, completion: @escaping ([UserScore]?, String) -> Void) {
        _ = query.find { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let objects):
                    // 解析为 UserScore 对象
                    var userScores: [UserScore] = []
                    var skippedCount = 0
                    var skippedReasons: [String: Int] = [:]
                    
                    for object in objects {
                        guard let userId = object["userId"]?.stringValue,
                              let loginType = object["loginType"]?.stringValue else {
                            skippedCount += 1
                            skippedReasons["缺少userId或loginType", default: 0] += 1
                            continue
                        }
                        
                        // 如果 userName 为空或无效，跳过这条记录（避免显示"未知用户"）
                        guard let userName = object["userName"]?.stringValue, !userName.isEmpty else {
                            skippedCount += 1
                            skippedReasons["userName为空", default: 0] += 1
                            continue
                        }
                        
                        let userEmail: String? = nil // 🎯 不再从UserScore表读取userEmail，统一从UserNameRecord表读取
                        let totalScoreFromServer = object["totalScore"]?.intValue ?? 0
                        let favoriteCount = object["favoriteCount"]?.intValue ?? 0
                        let likeCount = object["likeCount"]?.intValue ?? 0
                        let distance = object["distance"]?.doubleValue
                        let latitude = object["latitude"]?.doubleValue
                        let longitude = object["longitude"]?.doubleValue
                        let deviceId = object["deviceId"]?.stringValue // 🎯 新增：读取设备ID用于黑名单过滤
                        
                        
                        // 解析 lastUpdated
                        let lastUpdatedDate: Date
                        if let lastUpdatedString = object["lastUpdated"]?.stringValue,
                           let date = ISO8601DateFormatter().date(from: lastUpdatedString) {
                            lastUpdatedDate = date
                        } else if let createdAt = object.createdAt?.value {
                            lastUpdatedDate = createdAt
                        } else {
                            lastUpdatedDate = Date()
                        }
                        
                        // 🎯 不再从UserScore表读取userAvatar，统一从UserAvatarRecord表读取
                        // 使用默认头像作为占位符，实际显示时会从UserAvatarRecord表实时查询
                        let userAvatar = UserAvatarUtils.defaultAvatar(for: loginType)
                        
                        let userScore = UserScore(
                            userId: userId,
                            userName: userName,
                            userAvatar: userAvatar,
                            userEmail: userEmail,
                            loginType: loginType,
                            favoriteCount: favoriteCount,
                            likeCount: likeCount,
                            distance: distance,
                            latitude: latitude,
                            longitude: longitude,
                            lastUpdated: lastUpdatedDate,
                            deviceId: deviceId, // 🎯 新增：传递设备ID
                            totalScore: totalScoreFromServer // 🎯 修复：传入从服务器读取的totalScore
                        )
                        
                        userScores.append(userScore)
                    }
                    
                    if !skippedReasons.isEmpty {
                    }
                    
                    // 🎯 修改：不在查询方法内进行过滤和去重，移到视图层（与推荐榜一致）
                    // 只进行基本的数据解析和排序（先按 totalScore 降序，再按 lastUpdated 降序）
                    let sortedUserScores = userScores.sorted { first, second in
                        if first.totalScore != second.totalScore {
                            return first.totalScore > second.totalScore
                        }
                        return first.lastUpdated > second.lastUpdated
                    }
                    
                    if sortedUserScores.isEmpty {

                    }
                    
                    if !sortedUserScores.isEmpty {
                    }
                    if sortedUserScores.count >= 2 {
                    }
                    if sortedUserScores.count >= 3 {
                    }
                    
                    completion(sortedUserScores, "")
                    
                case .failure(let error):
                    if error.code == 404 {

                        // 404错误表示表不存在，尝试自动创建表
                        self.createUserScoreTable { tableCreated in
                            if tableCreated {

                                // 表创建成功后，重新尝试获取排行榜数据
                                self.getRankingList(currentLatitude: nil, currentLongitude: nil, completion: completion)
                            } else {

                                completion(nil, "表创建失败")
                            }
                        }
                    } else {
                        completion(nil, "查询失败: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    /// 根据用户ID查询该用户在排行榜中的记录
    func getRankingByUserId(userId: String, completion: @escaping ([UserScore]?, String) -> Void) {
        let query = LCQuery(className: "UserScore")
        query.whereKey("userId", .equalTo(userId))
        query.whereKey("lastUpdated", .descending) // 按最后更新时间降序排序（最新的在前）
        query.limit = 1000
        
        self.performRankingQuery(query: query, completion: completion)
    }
}
