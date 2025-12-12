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
        if recommendationData.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.preloadDistances()
            }
            return
        }
        
        // 🎯 修改：使用所有原始数据预加载距离（而不是已经过滤过的数据）
        let sourceData = allRecommendationData.isEmpty ? recommendationData : allRecommendationData
        preloadDistancesForRecommendations(sourceData, userLocation: userLocation)
    }
    
    // 🎯 修改：为推荐榜项目预加载距离 - 使用Recommendation表中的经纬度
    func preloadDistancesForRecommendations(_ items: [RecommendationItem], userLocation: CLLocation) {
        var tempDistanceCache: [String: Double] = [:]
        var calculatedCount = 0
        var noLocationCount = 0
        
        for item in items {
            // 检查是否有存储的距离（保留此检查以兼容旧数据）
            if let storedDistance = item.distance {
                tempDistanceCache[item.id] = storedDistance
                calculatedCount += 1
                continue
            }
            
            // 🎯 修改：直接使用Recommendation表中的经纬度（不再查询LocationRecord表）
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
                tempDistanceCache[item.id] = distance
                calculatedCount += 1
            } else {
                // 🔧 修复：如果没有经纬度，回退到使用之前的缓存
                if let cachedDistance = self.distanceCache[item.id] {
                    tempDistanceCache[item.id] = cachedDistance
                }
                noLocationCount += 1
            }
        }
        
        DispatchQueue.main.async {
            self.distanceCache = tempDistanceCache
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
        
        // 使用所有原始数据进行过滤（而不是已经过滤过的数据）
        let sourceData = allRecommendationData.isEmpty ? recommendationData : allRecommendationData
        
        // 逐步增加距离，直到数量 >= minCount 或达到最大距离限制
        while filteredItems.count < minCount && currentMaxDistance <= maxDistanceLimit {
            // 过滤掉距离大于currentMaxDistance的项目
            filteredItems = sourceData.filter { item in
                // 如果距离缓存中有该项目的距离
                if let distance = distanceCache[item.id] {
                    // 只保留距离小于等于currentMaxDistance的项目
                    return distance <= currentMaxDistance
                }
                // 如果没有距离信息，保留该项目（可能是位置信息缺失，但不应因此过滤掉）
                return true
            }
            
            // 如果数量仍然不足，增加距离阈值
            if filteredItems.count < minCount {
                currentMaxDistance += distanceStep
            }
        }
        
        // 🎯 修改：最多显示前20条
        let top20Items = Array(filteredItems.prefix(20))
        recommendationData = top20Items
        
        // 同时清理距离缓存中已过滤项目的缓存（只保留前20条的缓存）
        var filteredDistanceCache: [String: Double] = [:]
        for item in top20Items {
            if let distance = distanceCache[item.id] {
                filteredDistanceCache[item.id] = distance
            }
        }
        distanceCache = filteredDistanceCache
    }
    
    // 🎯 修改：批量计算距离 - 使用Recommendation表中的经纬度
    func batchCalculateDistances() {
        guard let userLocation = locationManager.location else {
            return
        }
        
        // 如果正在计算中，等待完成
        if isCalculatingDistances {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.batchCalculateDistances()
            }
            return
        }
        
        isCalculatingDistances = true
        
        // 🎯 修改：如果距离缓存为空，从空缓存开始（强制重新计算所有项目）；否则保留已有数据（增量更新）
        var tempDistanceCache = distanceCache.isEmpty ? [:] : distanceCache
        var calculatedCount = 0
        var skippedCount = 0
        var noLocationCount = 0
        
        // 🎯 修改：使用所有原始数据计算距离（而不是已经过滤过的数据）
        let sourceData = allRecommendationData.isEmpty ? recommendationData : allRecommendationData
        
        for item in sourceData {
            // 🎯 修改：如果距离缓存为空，强制重新计算所有项目；否则跳过已有缓存的项目
            if !distanceCache.isEmpty && distanceCache[item.id] != nil {
                skippedCount += 1
                continue
            }
            
            // 首先检查是否有存储的距离（保留此检查以兼容旧数据）
            if let storedDistance = item.distance {
                tempDistanceCache[item.id] = storedDistance
                calculatedCount += 1
                continue
            }
            
            // 🎯 修改：直接使用Recommendation表中的经纬度（不再查询LocationRecord表）
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
                tempDistanceCache[item.id] = distance
                calculatedCount += 1
            } else {
                // 🔧 修复：如果没有经纬度，回退到使用之前的缓存
                if let cachedDistance = self.distanceCache[item.id] {
                    tempDistanceCache[item.id] = cachedDistance
                }
                noLocationCount += 1
            }
        }
        
        DispatchQueue.main.async {
            self.distanceCache = tempDistanceCache
            self.isCalculatingDistances = false
            
            // 🎯 新增：过滤掉距离大于3km的推荐项目
            self.filterRecommendationsByDistance(maxDistance: 3000.0) // 3km = 3000米
        }
    }
}

