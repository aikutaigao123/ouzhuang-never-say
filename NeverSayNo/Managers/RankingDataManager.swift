import SwiftUI
import Combine

/// 排行榜数据管理器 - 在 App 生命周期内保持数据
/// 每次打开排行榜时优先显示缓存数据，同时后台刷新
class RankingDataManager: ObservableObject {
    static let shared = RankingDataManager()
    
    // MARK: - 推荐榜数据
    @Published var recommendationData: [RecommendationItem] = []
    @Published var myRecommendations: [RecommendationItem] = []
    @Published var recommendationAvatarCache: [String: String] = [:]
    @Published var recommendationUserNameCache: [String: String] = [:]
    @Published var recommendationDistanceCache: [String: Double] = [:]
    @Published var allRecommendationData: [RecommendationItem] = []
    
    // MARK: - 排行榜数据
    @Published var rankingData: [UserScore] = []
    @Published var myRankingRecords: [UserScore] = []
    @Published var rankingDistanceCache: [String: Double] = [:]
    @Published var allRankingData: [UserScore] = []
    
    private init() {}
    
    // MARK: - 更新推荐榜数据
    func updateRecommendationData(
        _ data: [RecommendationItem],
        myRecommendations: [RecommendationItem]? = nil,
        avatarCache: [String: String]? = nil,
        userNameCache: [String: String]? = nil,
        distanceCache: [String: Double]? = nil,
        allData: [RecommendationItem]? = nil
    ) {
        DispatchQueue.main.async {
            self.recommendationData = data
            
            if let myRecommendations = myRecommendations {
                self.myRecommendations = myRecommendations
            }
            if let avatarCache = avatarCache {
                self.recommendationAvatarCache.merge(avatarCache) { _, new in new }
            }
            if let userNameCache = userNameCache {
                self.recommendationUserNameCache.merge(userNameCache) { _, new in new }
            }
            if let distanceCache = distanceCache {
                self.recommendationDistanceCache.merge(distanceCache) { _, new in new }
            }
            if let allData = allData {
                self.allRecommendationData = allData
            }
        }
    }
    
    // MARK: - 更新排行榜数据
    func updateRankingData(
        _ data: [UserScore],
        myRankingRecords: [UserScore]? = nil,
        distanceCache: [String: Double]? = nil,
        allData: [UserScore]? = nil
    ) {
        DispatchQueue.main.async {
            self.rankingData = data
            
            if let myRankingRecords = myRankingRecords {
                self.myRankingRecords = myRankingRecords
            }
            if let distanceCache = distanceCache {
                self.rankingDistanceCache.merge(distanceCache) { _, new in new }
            }
            if let allData = allData {
                self.allRankingData = allData
            }
        }
    }
    
    // MARK: - 检查是否有缓存数据
    var hasRecommendationCache: Bool {
        !recommendationData.isEmpty
    }
    
    var hasRankingCache: Bool {
        !rankingData.isEmpty
    }
    
    // MARK: - 预加载方法（用于登录后后台加载数据到缓存）
    /// 预加载排行榜和推荐榜数据（后台静默加载，不影响用户操作）
    func preloadAllData(locationManager: LocationManager, userManager: UserManager) {
        
        // 在后台线程执行，避免阻塞主线程
        DispatchQueue.global(qos: .utility).async {
            
            // 优先从本地 UserDefaults 读取上次缓存的前20条数据，用于秒开
            if let currentUser = userManager.currentUser {
                let userId = currentUser.userId
                
                let cachedRecommendations = UserDefaultsManager.getTop20Recommendations(userId: userId)
                if !cachedRecommendations.isEmpty {
                    self.updateRecommendationData(cachedRecommendations, allData: cachedRecommendations)
                }
                
                let cachedRanking = UserDefaultsManager.getTop20RankingUserScores(userId: userId)
                if !cachedRanking.isEmpty {
                    self.updateRankingData(cachedRanking, allData: cachedRanking)
                }
            }
            
            // 预加载推荐榜
            self.preloadRecommendationData(locationManager: locationManager, userManager: userManager)
            
            // 预加载排行榜
            self.preloadRankingData(locationManager: locationManager, userManager: userManager)
        }
    }
    
    // MARK: - 预加载推荐榜数据
    private func preloadRecommendationData(locationManager: LocationManager, userManager: UserManager) {
        
        // 获取当前位置（GCJ-02坐标）
        var currentLat: Double? = nil
        var currentLon: Double? = nil
        if let userLocation = locationManager.location {
            let (gcjLat, gcjLon) = CoordinateConverter.wgs84ToGcj02(
                latitude: userLocation.coordinate.latitude,
                longitude: userLocation.coordinate.longitude
            )
            currentLat = gcjLat
            currentLon = gcjLon
        } else {
        }
        
        // 获取黑名单
        LeanCloudService.shared.fetchBlacklist { blacklistedDeviceIds, _ in
            let blacklistedIds = blacklistedDeviceIds ?? []
            
            LeanCloudService.shared.fetchPendingDeletionUserIds { pendingDeletionUserIds, _ in
                let deletionIds = Set(pendingDeletionUserIds ?? [])
                
                // 获取推荐榜数据
                LeanCloudService.shared.fetchAllRecommendations(currentLatitude: currentLat, currentLongitude: currentLon) { locationRecords, error in
                    guard let records = locationRecords, error?.isEmpty ?? true else {
                        return
                    }
                    
                    
                    // 过滤有效记录
                    let localBlacklistedUserIds = LocalBlacklistManager.shared.getAllLocalBlacklistedUserIds()
                    let validRecords = records.filter { record in
                        guard let userName = record.userName, !userName.isEmpty else { return false }
                        guard record.loginType != "guest" else { return false }
                        guard !localBlacklistedUserIds.contains(record.userId) else { return false }
                        guard !blacklistedIds.contains(record.userId) && !blacklistedIds.contains(record.deviceId) else { return false }
                        guard !deletionIds.contains(record.userId) && !deletionIds.contains(record.deviceId) else { return false }
                        return true
                    }
                    
                    // 🎯 新增：批量查询用户钻石数
                    let userIds = validRecords.map { $0.userId }
                    self.batchFetchUserDiamonds(userIds: userIds) { diamondsDict in
                        // 使用综合点赞数排序
                        let sortedRecords = validRecords.sorted { r1, r2 in
                            let likeCount1 = r1.likeCount ?? 0
                            let likeCount2 = r2.likeCount ?? 0
                            let diamonds1 = diamondsDict[r1.userId] ?? 0
                            let diamonds2 = diamondsDict[r2.userId] ?? 0
                            
                            // 🎯 综合点赞数 = 点赞数 + (钻石数 × 0.01)
                            let effectiveCount1 = Double(likeCount1) + (Double(diamonds1) * 0.01)
                            let effectiveCount2 = Double(likeCount2) + (Double(diamonds2) * 0.01)
                            
                            if effectiveCount1 != effectiveCount2 {
                                return effectiveCount1 > effectiveCount2
                            }
                            return r1.timestamp > r2.timestamp
                        }
                        
                        // 取前20条
                        let top20Records = Array(sortedRecords.prefix(20))
                        
                    var recommendationItems: [RecommendationItem] = []
                        for (index, record) in top20Records.enumerated() {
                            let displayReason: String
                            if let reason = record.reason, !reason.trimmingCharacters(in: .whitespaces).isEmpty {
                                displayReason = reason
                            } else {
                                displayReason = "获得 \(record.likeCount ?? 0) 个点赞"
                            }
                            
                            let userDiamonds = diamondsDict[record.userId] ?? 0
                            
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
                                userDiamonds: userDiamonds,  // 🎯 新增：传入钻石数
                                rank: index + 1
                            )
                            recommendationItems.append(item)
                        }
                        
                    // 按当前用户缓存前20条推荐榜数据到 UserDefaults（与历史记录类似）
                    if let currentUser = userManager.currentUser {
                        UserDefaultsManager.setTop20Recommendations(recommendationItems, userId: currentUser.userId)
                    }
                    
                        // 更新到缓存
                        self.updateRecommendationData(recommendationItems, allData: recommendationItems)
                    }
                }
            }
        }
    }
    
    // MARK: - 批量查询用户钻石数
    func batchFetchUserDiamonds(userIds: [String], completion: @escaping ([String: Int]) -> Void) {
        guard !userIds.isEmpty else {
            completion([:])
            return
        }
        
        
        // 从 UserScore 表批量查询钻石数（totalScore 字段）
        LeanCloudService.shared.batchFetchUserScores(userIds: userIds) { userScores in
            var diamondsDict: [String: Int] = [:]
            for userScore in userScores {
                diamondsDict[userScore.id] = userScore.totalScore
            }
            completion(diamondsDict)
        }
    }
    
    // MARK: - 预加载排行榜数据
    private func preloadRankingData(locationManager: LocationManager, userManager: UserManager) {
        
        // 获取当前位置（GCJ-02坐标）
        var currentLat: Double? = nil
        var currentLon: Double? = nil
        if let userLocation = locationManager.location {
            let (gcjLat, gcjLon) = CoordinateConverter.wgs84ToGcj02(
                latitude: userLocation.coordinate.latitude,
                longitude: userLocation.coordinate.longitude
            )
            currentLat = gcjLat
            currentLon = gcjLon
        } else {
        }
        
        // 获取黑名单
        LeanCloudService.shared.fetchBlacklist { blacklistedDeviceIds, _ in
            let blacklistedIds = blacklistedDeviceIds ?? []
            
            LeanCloudService.shared.fetchPendingDeletionUserIds { pendingDeletionUserIds, _ in
                let deletionIds = Set(pendingDeletionUserIds ?? [])
                
                // 获取排行榜数据
                LeanCloudService.shared.getRankingList(currentLatitude: currentLat, currentLongitude: currentLon) { userScores, error in
                    guard let userScores = userScores, error.isEmpty else {
                        return
                    }
                    
                    
                    // 过滤有效记录
                    let localBlacklistedUserIds = LocalBlacklistManager.shared.getAllLocalBlacklistedUserIds()
                    let validUserScores = userScores.filter { userScore in
                        guard !userScore.userName.isEmpty else { return false }
                        guard userScore.loginType != "guest" else { return false }
                        guard !localBlacklistedUserIds.contains(userScore.id) else { return false }
                        guard !blacklistedIds.contains(userScore.id) && !blacklistedIds.contains(userScore.userName) else { return false }
                        guard !deletionIds.contains(userScore.id) && !deletionIds.contains(userScore.userName) else { return false }
                        return true
                    }
                    
                    // 去重并排序
                    let uniqueUserScores = Dictionary(grouping: validUserScores, by: { $0.id })
                        .compactMap { (_, scores) -> UserScore? in
                            return scores.max(by: { $0.lastUpdated < $1.lastUpdated })
                        }
                        .sorted { $0.totalScore > $1.totalScore }
                    
                    let displayData = Array(uniqueUserScores.prefix(20))
                    
                    
                    // 按当前用户缓存前20条排行榜数据到 UserDefaults（与历史记录类似）
                    if let currentUser = userManager.currentUser {
                        UserDefaultsManager.setTop20RankingUserScores(displayData, userId: currentUser.userId)
                    }
                    
                    // 更新到缓存
                    self.updateRankingData(displayData, allData: uniqueUserScores)
                }
            }
        }
    }
}

