import SwiftUI
import CoreLocation

// MARK: - RecommendationListView Distance Management Extension
extension RecommendationListView {
    
    // 🎯 修改：开始预加载距离信息（与排行榜一致）
    func startPreloadingDistances() {
        guard !isPreloadingDistances,
              locationManager.location != nil else {
            return
        }
        
        isPreloadingDistances = true
        
        // 延迟启动，避免与推荐数据加载冲突
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.preloadDistances()
        }
    }
    
    // 🎯 新增：预加载距离信息（与排行榜一致）
    func preloadDistances() {
        guard let userLocation = locationManager.location else {
            isPreloadingDistances = false
            return
        }
        
        // 如果数据还未加载完成，等待数据加载
        if recommendationItems.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.preloadDistances()
            }
            return
        }
        
        // 使用当前推荐列表预加载距离
        let sourceData = recommendationItems
        preloadDistancesForRecommendations(sourceData, userLocation: userLocation)
    }
    
    // 🎯 修改：为推荐榜项目预加载距离 - 使用Recommendation表中的经纬度
    func preloadDistancesForRecommendations(_ items: [RecommendationItem], userLocation: CLLocation) {
        var updatedItems: [RecommendationItem] = []
        
        for item in items {
            var newDistance: Double? = item.distance
            
            // 如果已有存储的距离，直接使用
            if newDistance == nil {
                if let latitude = item.latitude, let longitude = item.longitude {
                    // ⚖️ 坐标系转换：将当前位置（WGS-84）转换为GCJ-02，与Recommendation表中的GCJ-02坐标进行计算
                    let (gcjLat, gcjLon) = CoordinateConverter.wgs84ToGcj02(
                        latitude: userLocation.coordinate.latitude,
                        longitude: userLocation.coordinate.longitude
                    )
                    
                    // 创建GCJ-02坐标的CLLocation用于计算距离
                    let gcjUserLocation = CLLocation(latitude: gcjLat, longitude: gcjLon)
                    
                    // 成功获取位置，计算距离（使用GCJ-02坐标）
                    let distance = DistanceUtils.calculateDistance(
                        from: gcjUserLocation,
                        to: latitude,
                        targetLongitude: longitude
                    )
                    newDistance = distance
                }
            }
            
            let updatedItem = RecommendationItem(
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
                distance: newDistance,
                likeCount: item.likeCount,
                userDiamonds: item.userDiamonds,
                rank: item.rank
            )
            updatedItems.append(updatedItem)
        }
        
        DispatchQueue.main.async {
            // 更新本地推荐数据
            self.recommendationItems = updatedItems
            self.hasPreloadedDistances = true
            self.isPreloadingDistances = false
            
            // 🎯 新增：过滤掉距离大于3km的推荐项目
            self.filterRecommendationsByDistance(maxDistance: 3000.0) // 3km = 3000米
        }
    }
    
    // 🎯 新增：根据距离过滤推荐项目，如果数量小于20个，自动调整maxDistance（最多扩展到100km）
    func filterRecommendationsByDistance(maxDistance: Double) {
        let minCount = 20 // 最小显示数量（最多显示20条）
        let maxDistanceLimit = 100000.0 // 最大距离限制（100km）
        let distanceStep = 1000.0 // 每次增加的距离（1km）
        
        var currentMaxDistance = maxDistance
        var filteredItems: [RecommendationItem] = []
        
        // 使用当前推荐数据进行过滤
        let sourceData = recommendationItems
        
        // 逐步增加距离，直到数量 >= minCount 或达到最大距离限制
        while filteredItems.count < minCount && currentMaxDistance <= maxDistanceLimit {
            // 过滤掉距离大于currentMaxDistance的项目
            filteredItems = sourceData.filter { item in
                if let distance = item.distance {
                    return distance <= currentMaxDistance
                }
                // 没有距离信息的项目不参与过滤
                return false
            }
            
            // 如果数量仍然不足，增加距离阈值
            if filteredItems.count < minCount {
                currentMaxDistance += distanceStep
            }
        }
        
        // 🎯 修改：最多显示前20条
        let top20Items = Array(filteredItems.prefix(20))
        
        // 更新本地推荐数据
        self.recommendationItems = top20Items
    }
    
    // 🎯 修改：批量计算距离 - 使用Recommendation表中的经纬度
    func batchCalculateDistances() {
        // 复用预加载逻辑进行距离计算
        preloadDistances()
    }
}

