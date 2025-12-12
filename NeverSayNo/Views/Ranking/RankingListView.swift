import SwiftUI
import CoreLocation

// 排行榜列表视图
struct RankingListView: View {
    @State private var rankingData: [UserScore] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var userManager: UserManager // 🎯 新增：用于获取当前用户ID
    let onRankingItemTap: (UserScore) -> Void
    let selectedItemId: String? // 🎯 新增：当前选中的排行榜项目ID
    
    // 🎯 新增：当前账号在排行榜中的记录
    @State private var myRankingRecords: [UserScore] = []
    @State private var isLoadingMyRanking = false
    
    // 不再需要头像和用户名缓存，直接使用UserScore表中的数据
    
    // 新增距离缓存 - 避免重复计算和网络请求
    @State private var distanceCache: [String: Double] = [:]
    @State private var isCalculatingDistances = false
    
    // 新增预加载状态
    @State private var hasPreloadedDistances = false
    @State private var isPreloadingDistances = false
    
    // 🎯 新增：保存所有原始排行榜数据（距离过滤之前）
    @State private var allRankingData: [UserScore] = []
    
    // 🎯 新增：高亮显示的项目ID
    @State private var highlightedItemId: String? = nil
    
    // 🎯 新增：下拉刷新限制提示
    @State private var showRefreshLimitAlert = false
    @State private var refreshLimitMessage = ""
    

    
    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("正在加载排行榜...")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = errorMessage {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.orange.opacity(0.6))
                    Text("加载失败")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(.gray.opacity(0.8))
                        .multilineTextAlignment(.center)
                    
                    Button("重试") {
                        loadRankingData()
                    }
                    .foregroundColor(.blue)
                    .padding(.top, 10)
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 60)
            } else if rankingData.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "trophy")
                        .font(.system(size: 60))
                        .foregroundColor(.gray.opacity(0.6))
                    Text("暂无排行榜数据")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                    Text("排行榜将显示最活跃的用户")
                        .font(.body)
                        .foregroundColor(.gray.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 60)
                .onAppear {
                }
            } else {
                VStack(spacing: 0) {
                    // 排行榜顶部工具栏
                    HStack {
                        Text("排行榜")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // 显示距离加载状态
                        if !hasPreloadedDistances && distanceCache.count < rankingData.count {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("加载距离中...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
                    
                    ScrollViewReader { proxy in
                        List {
                            ForEach(Array(rankingData.enumerated()), id: \.element.id) { index, item in
                                RankingItemView(
                                    rank: index + 1, 
                                    item: item, 
                                    locationManager: locationManager,
                                    cachedDistance: distanceCache[item.id],
                                    avatarResolver: { userId, loginType, defaultAvatar in
                                        // 与用户头像界面一致：不使用全局缓存，返回默认头像
                                        // 实际头像查询在RankingItemView的onAppear中进行
                                        // 如果defaultAvatar为空，根据loginType返回默认头像
                                        if let defaultAvatar = defaultAvatar, !defaultAvatar.isEmpty {
                                            return defaultAvatar
                                        }
                                        // 与用户头像界面一致：根据loginType返回默认头像 - Apple账号与内部账号使用相同的默认头像
                                        if let loginType = loginType {
                                            if loginType == "apple" {
                                                return "person.circle.fill"
                                            }
                                        }
                                        return "person.circle" // 游客用户或未知类型使用person.circle（蓝色）
                                    },
                                    userNameResolver: { userId, loginType in
                                        // 直接使用UserScore表中的用户名
                                        return nil
                                    }
                                )
                                    .id(item.id) // 🎯 新增：为每个项目设置ID，用于滚动定位
                                    .listRowInsets(EdgeInsets())
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(
                                        // 🎯 新增：高亮显示选中的项目
                                        (selectedItemId == item.id || highlightedItemId == item.id) ? Color.blue.opacity(0.1) : Color.clear
                                    )
                                    .onAppear {
                                    }
                                    .onTapGesture {
                                        onRankingItemTap(item)
                                    }
                            }
                            
                            // 🎯 新增：当前账号在排行榜中的记录
                            if !myRankingRecords.isEmpty {
                                Section(header: Text("我的记录").font(.headline).foregroundColor(.primary)) {
                                    ForEach(Array(myRankingRecords.enumerated()), id: \.element.id) { index, item in
                                        RankingItemView(
                                            rank: 0, // 我的记录不显示排名
                                            item: item,
                                            locationManager: locationManager,
                                            cachedDistance: distanceCache[item.id],
                                            avatarResolver: { userId, loginType, defaultAvatar in
                                                if let defaultAvatar = defaultAvatar, !defaultAvatar.isEmpty {
                                                    return defaultAvatar
                                                }
                                                if let loginType = loginType {
                                                    if loginType == "apple" {
                                                        return "person.circle.fill"
                                                    }
                                                }
                                                return "person.circle"
                                            },
                                            userNameResolver: { userId, loginType in
                                                return nil
                                            }
                                        )
                                            .id(item.id)
                                            .listRowInsets(EdgeInsets())
                                            .listRowSeparator(.hidden)
                                            .listRowBackground(
                                                (selectedItemId == item.id || highlightedItemId == item.id) ? Color.blue.opacity(0.1) : Color.clear
                                            )
                                            .onTapGesture {
                                                onRankingItemTap(item)
                                            }
                                    }
                                }
                            }
                        }
                        .listStyle(PlainListStyle())
                        .refreshable {
                            // 🎯 新增：检查下拉刷新限制（每天最多15次）
                            guard let userId = userManager.currentUser?.id else {
                                return
                            }
                            
                            let (canRefresh, message) = UserDefaultsManager.canRefreshRankingList(userId: userId)
                            if canRefresh {
                                // 记录刷新
                                UserDefaultsManager.recordRankingRefresh(userId: userId)
                                // 执行刷新
                                loadRankingData()
                            } else {
                                // 显示限制提示
                                refreshLimitMessage = message
                                showRefreshLimitAlert = true
                            }
                        }
                        .alert("提示", isPresented: $showRefreshLimitAlert) {
                            Button("确定") { }
                        } message: {
                            Text(refreshLimitMessage)
                        }
                        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshRankingList"))) { notification in
                            // 🎯 新增：监听刷新通知，重新加载排行榜数据
                            // 🎯 新增：如果通知中包含新点击的项目ID，设置高亮
                            if let userInfo = notification.userInfo {
                                if let newItemId = userInfo["selectedRankingId"] as? String {
                                    highlightedItemId = newItemId
                                    // 延迟滚动到新点击的项目
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        loadRankingData()
                                        loadMyRankingRecords() // 🎯 新增：刷新我的记录
                                        // 🎯 修改：增加延迟时间，确保数据加载完成后再滚动
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                            let itemExists = rankingData.contains { $0.id == newItemId } || myRankingRecords.contains { $0.id == newItemId }
                                            if itemExists {
                                                withAnimation {
                                                    proxy.scrollTo(newItemId, anchor: .center)
                                                }
                                            } else {
                                            }
                                            // 3秒后取消高亮
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                                highlightedItemId = nil
                                            }
                                        }
                                    }
                                } else {
                                    loadRankingData()
                                    loadMyRankingRecords() // 🎯 新增：刷新我的记录
                                }
                            } else {
                                loadRankingData()
                                loadMyRankingRecords() // 🎯 新增：刷新我的记录
                            }
                        }
                        .onAppear {
                            // 如果有选中的项目ID，滚动到该项目
                            if let selectedId = selectedItemId {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    let itemExists = rankingData.contains { $0.id == selectedId }
                                    if itemExists {
                                        withAnimation {
                                            proxy.scrollTo(selectedId, anchor: .center)
                                        }
                                    } else {
                                    }
                                }
                            } else {
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            // 🎯 修复：只有在数据为空或首次加载时才重新加载数据，避免每次切换都重新加载
            if rankingData.isEmpty {
                // 🎯 修复：重置预加载状态，确保每次打开界面时都重新加载数据
                hasPreloadedDistances = false
                isPreloadingDistances = false
                
                // 从服务器获取最新数据
                loadRankingData()
                loadMyRankingRecords() // 🎯 新增：加载当前账号的排行榜记录
                // 开始预加载距离信息
                startPreloadingDistances()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserScoreUpdated"))) { _ in
            // 当用户积分更新时，刷新排行榜数据
            loadRankingData()
            loadMyRankingRecords() // 🎯 新增：刷新我的记录
        }
    }
    
    // 开始预加载距离信息
    private func startPreloadingDistances() {
        guard !isPreloadingDistances,
              locationManager.location != nil else {
            return
        }
        
        isPreloadingDistances = true
        
        // 延迟启动，避免与排行榜数据加载冲突
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.preloadDistances()
        }
    }
    
    // 预加载距离信息
    private func preloadDistances() {
        guard let userLocation = locationManager.location else {
            isPreloadingDistances = false
            return
        }
        
        // 🎯 修复：直接使用已经过滤过的allRankingData，不再重新获取未过滤的数据
        // 这样可以确保黑名单过滤始终生效
        guard !allRankingData.isEmpty else {
            // 如果allRankingData为空，说明数据还没有加载完成，等待一下再试
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.preloadDistances()
            }
            return
        }
        
        // 使用已经过滤过的数据预加载距离
        self.preloadDistancesForUsers(self.allRankingData, userLocation: userLocation)
    }
    
    // 为用户预加载距离
    private func preloadDistancesForUsers(_ users: [UserScore], userLocation: CLLocation) {
        var tempDistanceCache: [String: Double] = [:]
        var calculatedCount = 0
        var noLocationCount = 0
        
        for userScore in users {
            // 检查是否有存储的距离（保留此检查以兼容旧数据）
            if let storedDistance = userScore.distance {
                tempDistanceCache[userScore.id] = storedDistance
                calculatedCount += 1
                continue
            }
            
            // 🎯 修改：直接从UserScore表获取经纬度进行计算（不再查询LocationRecord表）
            if let targetLatitude = userScore.latitude, let targetLongitude = userScore.longitude {
                // ⚖️ 坐标系转换：将当前位置（WGS-84）转换为GCJ-02，与UserScore表中的GCJ-02坐标进行计算
                let (gcjLat, gcjLon) = CoordinateConverter.wgs84ToGcj02(
                    latitude: userLocation.coordinate.latitude,
                    longitude: userLocation.coordinate.longitude
                )
                
                // 创建GCJ-02坐标的CLLocation用于计算距离
                let gcjUserLocation = CLLocation(latitude: gcjLat, longitude: gcjLon)
                
                // 成功获取位置，计算距离（使用GCJ-02坐标）
                let distance = DistanceUtils.calculateDistance(
                    from: gcjUserLocation,
                    to: targetLatitude,
                    targetLongitude: targetLongitude
                )
                tempDistanceCache[userScore.id] = distance
                calculatedCount += 1
            } else {
                noLocationCount += 1
            }
        }
        
        DispatchQueue.main.async {
            self.distanceCache = tempDistanceCache
            self.hasPreloadedDistances = true
            self.isPreloadingDistances = false
            
            // 🎯 新增：过滤掉距离大于3km的排行榜项目
            self.filterRankingByDistance(maxDistance: 3000.0) // 3km = 3000米
        }
    }
    

    
    private func loadRankingData() {
        // 🎯 修改：与推荐榜一致，先获取黑名单与待删除账号用户ID，再进行过滤
        isLoading = true
        errorMessage = nil
        
        LeanCloudService.shared.fetchBlacklist { blacklistedDeviceIds, _ in
            let blacklistedIds = blacklistedDeviceIds ?? []
            if !blacklistedIds.isEmpty {
            }
            
            LeanCloudService.shared.fetchPendingDeletionUserIds { pendingDeletionUserIds, _ in
                let deletionIds = Set(pendingDeletionUserIds ?? [])
                if !deletionIds.isEmpty {
                }
                
                // 🎯 获取当前位置（GCJ-02坐标）用于地理范围查询
                var currentLat: Double? = nil
                var currentLon: Double? = nil
                if let userLocation = locationManager.location {
                    // 将WGS-84转换为GCJ-02用于查询（UserScore表中的坐标是GCJ-02）
                    let (gcjLat, gcjLon) = CoordinateConverter.wgs84ToGcj02(
                        latitude: userLocation.coordinate.latitude,
                        longitude: userLocation.coordinate.longitude
                    )
                    currentLat = gcjLat
                    currentLon = gcjLon
                }
                
                LeanCloudService.shared.getRankingList(currentLatitude: currentLat, currentLongitude: currentLon) { userScores, error in
                    DispatchQueue.main.async {
                        self.isLoading = false
                        
                        if !error.isEmpty {
                            self.errorMessage = error
                        } else if let userScores = userScores {
                            // 🎯 调试：打印前10条UserScore的完整内容
                            for (_, _) in userScores.prefix(10).enumerated() {
                            }
                            
                            // 统计过滤原因
                            var userNameEmptyCount = 0
                            var guestCount = 0
                            var blacklistedCount = 0
                            var pendingDeletionCount = 0
                            
                            // 🎯 修改：与推荐榜一致，过滤掉游客用户、黑名单用户和设备、待删除账号、用户名为空
                            // 🎯 新增：获取本地黑名单
                            let localBlacklistedUserIds = LocalBlacklistManager.shared.getAllLocalBlacklistedUserIds()
                            
                            let validUserScores = userScores.filter { userScore in
                                // 过滤掉用户名为空或无效（避免显示"未知用户"）
                                if userScore.userName.isEmpty {
                                    userNameEmptyCount += 1
                                    return false
                                }
                                
                                // 过滤掉游客用户
                                if userScore.loginType == "guest" {
                                    guestCount += 1
                                    return false
                                }
                                
                                // 🎯 新增：检查本地黑名单
                                if localBlacklistedUserIds.contains(userScore.id) {
                                    blacklistedCount += 1
                                    return false
                                }
                                
                                // 🎯 修复：同时检查用户ID、用户名和设备ID（黑名单可能包含这三者中的任意一个）
                                let isBlacklisted = blacklistedIds.contains(userScore.id) ||
                                   blacklistedIds.contains(userScore.userName) ||
                                   (userScore.deviceId != nil && blacklistedIds.contains(userScore.deviceId!))
                                
                                if isBlacklisted {
                                    blacklistedCount += 1
                                    return false
                                }
                                
                                // 过滤掉待删除账号（检查用户ID、用户名、设备ID）
                                let isPendingDeletion = deletionIds.contains(userScore.id) ||
                                    deletionIds.contains(userScore.userName) ||
                                    (userScore.deviceId != nil && deletionIds.contains(userScore.deviceId!))
                                
                                if isPendingDeletion {
                                    pendingDeletionCount += 1
                                    return false
                                }
                                
                                return true
                            }
                            
                            // 对排行榜数据进行去重处理，确保每个用户ID只出现一次
                            let uniqueUserScores = Dictionary(grouping: validUserScores, by: { $0.id })
                                .compactMap { (_, scores) -> UserScore? in
                                    // 如果同一用户有多条记录，选择最后更新时间最新的一条
                                    return scores.max(by: { $0.lastUpdated < $1.lastUpdated })
                                }
                                .sorted { $0.totalScore > $1.totalScore } // 按积分降序排序
                            
                            // 🎯 调试：打印去重和排序后的数据
                            for (_, _) in uniqueUserScores.prefix(10).enumerated() {
                            }
                            
                            
                            // 统计位置信息
                            var hasLocationCount = 0
                            var noLocationCount = 0
                            for score in uniqueUserScores {
                                if score.latitude != nil && score.longitude != nil {
                                    hasLocationCount += 1
                                } else {
                                    noLocationCount += 1
                                }
                            }
                            
                            // 🎯 修改：与推荐榜一致，只显示前20条
                            self.allRankingData = uniqueUserScores // 保存所有原始数据（用于距离过滤）
                            
                            // 临时显示数据（距离过滤前）
                            self.rankingData = Array(uniqueUserScores.prefix(20)) // 只显示前20条
                            
                            // 🎯 新增：缓存前3名的用户ID（距离过滤前）
                            let top3UserIds = Array(uniqueUserScores.prefix(3).map { $0.id })
                            UserDefaultsManager.setTop3RankingUserIds(top3UserIds)
                            
                            // 刷新头像缓存，确保获取最新头像
                            self.refreshRankingAvatars()
                            
                            // 🎯 修改：参考推荐榜，刷新数据后，清除距离缓存并重新计算距离（确保数据正确）
                            // 清除距离缓存，强制重新计算所有项目的距离
                            self.distanceCache.removeAll()
                            self.hasPreloadedDistances = false
                            self.isPreloadingDistances = false
                            // 重新开始批量计算距离
                            self.batchCalculateDistances()
                            
                        } else {
                            self.errorMessage = "无法获取排行榜数据"
                        }
                    }
                }
            }
        }
    }
    

    
    // 批量计算距离 - 渐进式获取策略
    private func batchCalculateDistances() {
        guard let userLocation = locationManager.location else {
            return
        }
        
        // 🎯 打印当前用户经纬度（WGS-84和GCJ-02）
        let wgsLat = userLocation.coordinate.latitude
        let wgsLon = userLocation.coordinate.longitude
        _ = CoordinateConverter.wgs84ToGcj02(
            latitude: wgsLat,
            longitude: wgsLon
        )
        
        // 如果正在计算中，等待完成
        if isCalculatingDistances {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.batchCalculateDistances()
            }
            return
        }
        
        isCalculatingDistances = true
        
        // 🎯 修改：参考推荐榜，如果距离缓存为空，从空缓存开始（强制重新计算所有项目）；否则保留已有数据（增量更新）
        var tempDistanceCache = distanceCache.isEmpty ? [:] : distanceCache
        var calculatedCount = 0
        var skippedCount = 0
        var noLocationCount = 0
        
        // 🎯 修改：使用所有原始数据计算距离（而不是已经过滤过的数据）
        let sourceData = allRankingData.isEmpty ? rankingData : allRankingData
        
        for userScore in sourceData {
            // 🎯 修改：参考推荐榜，如果距离缓存为空，强制重新计算所有项目；否则跳过已有缓存的项目
            if !distanceCache.isEmpty && distanceCache[userScore.id] != nil {
                skippedCount += 1
                continue
            }
            
            // 首先检查是否有存储的距离（保留此检查以兼容旧数据）
            if let storedDistance = userScore.distance {
                tempDistanceCache[userScore.id] = storedDistance
                calculatedCount += 1
                continue
            }
            
            // 🎯 修改：直接从UserScore表获取经纬度进行计算（不再查询LocationRecord表）
            if let targetLatitude = userScore.latitude, let targetLongitude = userScore.longitude {
                // ⚖️ 坐标系转换：将当前位置（WGS-84）转换为GCJ-02，与UserScore表中的GCJ-02坐标进行计算
                let (gcjLat, gcjLon) = CoordinateConverter.wgs84ToGcj02(
                    latitude: userLocation.coordinate.latitude,
                    longitude: userLocation.coordinate.longitude
                )
                
                // 🎯 打印UserScore的完整内容和坐标对比
                
                // 创建GCJ-02坐标的CLLocation用于计算距离
                let gcjUserLocation = CLLocation(latitude: gcjLat, longitude: gcjLon)
                
                // 成功获取位置，计算距离（使用GCJ-02坐标）
                let distance = DistanceUtils.calculateDistance(
                    from: gcjUserLocation,
                    to: targetLatitude,
                    targetLongitude: targetLongitude
                )
                tempDistanceCache[userScore.id] = distance
                calculatedCount += 1
            } else {
                noLocationCount += 1
            }
        }
        
        DispatchQueue.main.async {
            self.distanceCache = tempDistanceCache
            self.isCalculatingDistances = false
            
            
            // 🎯 新增：过滤掉距离大于3km的排行榜项目
            self.filterRankingByDistance(maxDistance: 3000.0) // 3km = 3000米
        }
    }
    
    // 🎯 新增：根据距离过滤排行榜项目，如果数量小于20个，自动调整maxDistance（最多扩展到100km）
    private func filterRankingByDistance(maxDistance: Double) {
        // 🎯 修复：确保只使用已经过滤过的allRankingData，如果为空则不执行过滤
        guard !allRankingData.isEmpty else {
            return
        }
        
        
        let minCount = 20 // 最小显示数量（最多显示20条）
        let maxDistanceLimit = 100000.0 // 最大距离限制（100km）
        let distanceStep = 1000.0 // 每次增加的距离（1km）
        
        var currentMaxDistance = maxDistance
        var filteredItems: [UserScore] = []
        
        // 🎯 修复：只使用已经过滤过的allRankingData（已经包含黑名单过滤）
        let sourceData = allRankingData
        
        // 统计有位置信息和无位置信息的数量
        var hasLocationCount = 0
        var noLocationCount = 0
        for item in sourceData {
            if distanceCache[item.id] != nil {
                hasLocationCount += 1
            } else {
                noLocationCount += 1
            }
        }
        
        // 逐步增加距离，直到数量 >= minCount 或达到最大距离限制
        var iteration = 0
        while filteredItems.count < minCount && currentMaxDistance <= maxDistanceLimit {
            iteration += 1
            
            // 过滤掉距离大于currentMaxDistance的项目，只保留有位置信息的记录
            filteredItems = sourceData.filter { item in
                // 如果距离缓存中有该项目的距离（说明有位置信息）
                if let distance = distanceCache[item.id] {
                    // 只保留距离小于等于currentMaxDistance的项目
                    return distance <= currentMaxDistance
                }
                // 🎯 修改：如果没有距离信息，过滤掉该项目（只显示有位置信息的记录）
                return false
            }
            
            
            // 如果数量仍然不足，增加距离阈值
            if filteredItems.count < minCount {
                currentMaxDistance += distanceStep
            }
        }
        
        // 🎯 修改：与推荐榜一致，只显示前20条
        let top20Items = Array(filteredItems.prefix(20))
        rankingData = top20Items
        
        // 🎯 新增：更新前3名缓存（距离过滤后的前3名）
        let top3UserIds = Array(top20Items.prefix(3).map { $0.id })
        UserDefaultsManager.setTop3RankingUserIds(top3UserIds)
        
        if top20Items.isEmpty {
            if filteredItems.isEmpty {
                if hasLocationCount == 0 {
                } else {
                }
            }
        } else {
            for _ in top20Items {
            }
        }
        
        // 同时清理距离缓存中已过滤项目的缓存
        var filteredDistanceCache: [String: Double] = [:]
        for item in top20Items {
            if let distance = distanceCache[item.id] {
                filteredDistanceCache[item.id] = distance
            }
        }
        distanceCache = filteredDistanceCache
    }
    
    // 刷新排行榜中的头像和用户名（批量获取优化版本）
    private func refreshRankingAvatars() {
        // 收集所有需要更新的用户ID
        var userIds = Set<String>()
        
        // 从排行榜数据中收集用户ID
        for item in rankingData {
            userIds.insert(item.id)
        }
        
        
        // 批量获取所有用户名记录
        LeanCloudService.shared.fetchAllUserNameRecords { records, error in
            DispatchQueue.main.async {
                if records != nil {
                    self.filterAndUpdateRankingUserNameCache(neededUserIds: userIds)
                }
            }
        }
        
        // 批量获取所有用户头像记录
        LeanCloudService.shared.fetchAllUserAvatarRecords { records, error in
            DispatchQueue.main.async {
                if records != nil {
                    self.filterAndUpdateRankingUserAvatarCache(neededUserIds: userIds)
                }
            }
        }
    }
    
    // 过滤并更新排行榜用户名缓存
    private func filterAndUpdateRankingUserNameCache(neededUserIds: Set<String>) {
        // 从全局缓存中获取所有用户名记录
        if let userNameRecords = MessageButtonCacheManager.shared.getCachedUserNameRecords() {
            for record in userNameRecords {
                if let userId = record["userId"] as? String,
                   let userName = record["userName"] as? String,
                   neededUserIds.contains(userId) {
                    // 更新UserScore中的用户名数据
                    if let index = self.rankingData.firstIndex(where: { $0.id == userId }) {
                        self.rankingData[index].userName = userName
                    }
                }
            }
        }
    }
    
    // 过滤并更新排行榜用户头像缓存
    private func filterAndUpdateRankingUserAvatarCache(neededUserIds: Set<String>) {
        // 从全局缓存中获取所有用户头像记录
        if let userAvatarRecords = MessageButtonCacheManager.shared.getCachedUserAvatarRecords() {
            for record in userAvatarRecords {
                if let userId = record["userId"] as? String,
                   let userAvatar = record["userAvatar"] as? String,
                   neededUserIds.contains(userId) {
                    // 更新UserScore中的用户头像数据
                    if let index = self.rankingData.firstIndex(where: { $0.id == userId }) {
                        self.rankingData[index].userAvatar = userAvatar
                    }
                }
            }
        }
    }
    
    // 🎯 新增：加载当前账号在排行榜中的记录
    private func loadMyRankingRecords() {
        guard let currentUserId = userManager.currentUser?.userId else {
            return
        }
        
        isLoadingMyRanking = true
        
        LeanCloudService.shared.getRankingByUserId(userId: currentUserId) { userScores, error in
            DispatchQueue.main.async {
                self.isLoadingMyRanking = false
                
                if !error.isEmpty {
                    return
                }
                
                guard let userScores = userScores else {
                    return
                }
                
                // 对数据进行去重处理，确保每个用户ID只出现一次
                let uniqueUserScores = Dictionary(grouping: userScores, by: { $0.id })
                    .compactMap { (_, scores) -> UserScore? in
                        // 如果同一用户有多条记录，选择最后更新时间最新的一条
                        return scores.max(by: { $0.lastUpdated < $1.lastUpdated })
                    }
                    .sorted { $0.lastUpdated > $1.lastUpdated } // 按最后更新时间降序排序（最新的在前）
                
                self.myRankingRecords = uniqueUserScores
                
                // 为我的记录计算距离
                if let userLocation = locationManager.location {
                    for item in uniqueUserScores {
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

// 排行榜项目视图
struct RankingItemView: View {
    let rank: Int
    let item: UserScore
    @ObservedObject var locationManager: LocationManager
    let cachedDistance: Double? // 使用缓存的距离
    
    // 头像和用户名解析器
    let avatarResolver: (String?, String?, String?) -> String?
    let userNameResolver: (String?, String?) -> String?
    
    @State private var avatarFromServer: String? = nil
    @State private var userNameFromServer: String? = nil
    @State private var avatarRetryCount: Int = 0 // 🎯 修改：记录头像重试次数（最多重试2次）
    @State private var userNameRetryCount: Int = 0 // 🎯 修改：记录用户名重试次数（最多重试2次）
    
    // 计算并解析头像 - 🎯 只从 UserAvatarRecord 表获取，不从 UserScore 表读取
    private var resolvedAvatar: String? {
        // 第一优先级：从服务器实时查询的头像（从 UserAvatarRecord 表获取）
        if let serverAvatar = avatarFromServer, !serverAvatar.isEmpty {
            return serverAvatar
        }
        // 第二优先级：从 UserDefaults 获取头像（缓存的头像）
        if let customAvatar = UserDefaultsManager.getCustomAvatar(userId: item.id), !customAvatar.isEmpty {
            return customAvatar
        }
        // 第三优先级：使用默认头像（由 avatarResolver 提供）
        // 🎯 不再从 UserScore 表中读取头像
        let fallbackAvatar = avatarResolver(item.id, item.loginType, nil)
        return fallbackAvatar
    }
    
    // 计算并解析用户名 - 🎯 只从 UserNameRecord 表获取，不从 UserScore 表读取
    private var resolvedUserName: String? {
        // 第一优先级：从服务器实时查询的用户名（从 UserNameRecord 表获取）
        if let serverName = userNameFromServer, !serverName.isEmpty {
            return serverName
        }
        // 🎯 不再从 UserScore 表中读取用户名
        // 如果服务器查询失败，返回 nil，由显示层处理（显示"未知用户"）
        return nil
    }
    
    // 从服务器加载头像 - 🎯 统一从 UserAvatarRecord 表获取
    private func loadAvatarFromServer() {
        let uid = item.id
        
        // 🎯 修改：使用 fetchUserAvatarByUserId，不依赖 loginType，直接从 UserAvatarRecord 表获取
        LeanCloudService.shared.fetchUserAvatarByUserId(objectId: uid) { avatar, error in
            DispatchQueue.main.async {
                if let avatar = avatar, !avatar.isEmpty {
                    // 🎯 新增：检查是否更新了UI显示（如果获取到新头像，更新状态）
                    let wasShowingDefault = self.isShowingDefaultAvatar
                    self.avatarFromServer = avatar
                    // 如果之前显示默认头像，现在获取到了新头像，UI会自动更新
                    if wasShowingDefault {
                        // 头像已更新，UI会自动刷新
                    }
                } else {
                    // 🎯 修改：查询失败时，如果 avatarFromServer 仍为 nil 且未达到最大重试次数，触发第二次重试
                    if self.avatarFromServer == nil && self.avatarRetryCount < 2 {
                        self.retryLoadAvatarFromServer()
                    }
                }
            }
        }
    }
    
    // 🎯 修改：重试查询头像（最多重试2次）
    // 重试时使用 loadAvatarFromServer()，该方法从 UserAvatarRecord 表查询
    private func retryLoadAvatarFromServer() {
        guard avatarRetryCount < 2 else {
            return
        }
        avatarRetryCount += 1
        
        // 🎯 修改：根据重试次数决定延迟时间
        // 第一次重试：延迟1/17秒；第二次重试：延迟0.5秒
        let delay: TimeInterval = avatarRetryCount == 1 ? 1.0 / 17.0 : 0.5
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // 🎯 修改：检查 avatarFromServer 是否为 nil（查询失败的情况）
            // 如果 avatarFromServer 仍为 nil，说明查询失败，应该重试
            let stillFailed = self.avatarFromServer == nil
            if stillFailed {
                self.loadAvatarFromServer()
            } else {
            }
        }
    }
    
    // 从服务器加载用户名 - 🎯 统一从 UserNameRecord 表获取
    private func loadUserNameFromServer() {
        let uid = item.id
        
        // 🎯 修改：统一使用 fetchUserNameByUserId，不依赖 loginType，直接从 UserNameRecord 表获取
        LeanCloudService.shared.fetchUserNameByUserId(objectId: uid) { name, error in
            DispatchQueue.main.async {
                if let name = name, !name.isEmpty {
                    // 🎯 新增：检查是否更新了UI显示（如果获取到新用户名，更新状态）
                    let wasShowingUnknown = self.isShowingUnknownUser
                    self.userNameFromServer = name
                    
                    // 🎯 新增：更新 UserDefaults 中的用户名缓存（用于其他用户的信息）
                    let userDefaultsUserName = UserDefaultsManager.getFriendUserName(userId: uid)
                    if userDefaultsUserName != name {
                        UserDefaultsManager.setFriendUserName(userId: uid, userName: name)
                    }
                    
                    // 如果之前显示未知用户，现在获取到了新用户名，UI会自动更新
                    if wasShowingUnknown {
                        // 用户名已更新，UI会自动刷新
                    }
                } else {
                    // 🎯 修改：查询失败时，如果 userNameFromServer 仍为 nil 且未达到最大重试次数，触发第二次重试
                    if self.userNameFromServer == nil && self.userNameRetryCount < 2 {
                        self.retryLoadUserNameFromServer()
                    }
                }
            }
        }
    }
    
    // 🎯 修改：重试查询用户名（最多重试2次）
    // 重试时使用 loadUserNameFromServer()，该方法从 UserNameRecord 表查询
    private func retryLoadUserNameFromServer() {
        guard userNameRetryCount < 2 else {
            return
        }
        userNameRetryCount += 1
        
        // 🎯 修改：根据重试次数决定延迟时间
        // 第一次重试：延迟1/17秒；第二次重试：延迟0.5秒
        let delay: TimeInterval = userNameRetryCount == 1 ? 1.0 / 17.0 : 0.5
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // 🎯 修改：检查 userNameFromServer 是否为 nil（查询失败的情况）
            // 只要 userNameFromServer 仍为 nil，就重试以获取最新用户名
            let stillFailed = self.userNameFromServer == nil
            if stillFailed {
                self.loadUserNameFromServer()
            } else {
            }
        }
    }
    
    // 🎯 新增：检查是否显示默认头像
    private var isShowingDefaultAvatar: Bool {
        let avatar = resolvedAvatar
        // 检查是否是默认的 SF Symbol
        if let avatar = avatar {
            return avatar == "person.circle.fill" || avatar == "person.circle"
        }
        return true // 如果 resolvedAvatar 为 nil，也会显示默认头像
    }
    
    // 🎯 新增：检查是否显示未知用户
    private var isShowingUnknownUser: Bool {
        // 🎯 只检查 userNameFromServer 是否为 nil（查询失败的情况）
        // 如果 userNameFromServer 为 nil，说明查询失败，应该显示"未知用户"
        if userNameFromServer == nil {
            return true
        }
        
        // 如果 userNameFromServer 不为 nil，检查 resolvedUserName 是否为 nil 或"未知用户"
        let displayName = resolvedUserName ?? "未知用户"
        return displayName == "未知用户"
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 排名
            VStack {
                if rank <= 3 {
                    Image(systemName: rank == 1 ? "crown.fill" : (rank == 2 ? "medal.fill" : "medal"))
                        .font(.title2)
                        .foregroundColor(rank == 1 ? .yellow : (rank == 2 ? .gray : .orange))
                } else {
                    Text("\(rank)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 40)
            
            // 用户头像 - 🎯 只从 UserAvatarRecord 表获取，不从 UserScore 表读取
            // 与用户头像界面一致：支持SF Symbol和emoji/文本
            if let avatar = resolvedAvatar, !avatar.isEmpty {
                let isSFSymbol = UserAvatarUtils.isSFSymbol(avatar)
                
                // 检查是否是 SF Symbol
                if isSFSymbol {
                    if avatar == "applelogo" || avatar == "apple_logo" {
                        Image(systemName: "applelogo")
                            .font(.system(size: 40))
                            .foregroundColor(.black)
                            .background(Circle().fill(Color.gray.opacity(0.1)).frame(width: 50, height: 50))
                            .onAppear {
                                loadAvatarFromServer()
                                loadUserNameFromServer()
                            }
                            .task {
                                // 🎯 新增：检查查询是否失败，如果失败则重试
                                try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 / 7.0)) // 1/7秒
                                // 检查是否查询失败（avatarFromServer 为 nil）且未重试过
                                let shouldRetry = avatarFromServer == nil && avatarRetryCount < 2
                                if shouldRetry {
                                    retryLoadAvatarFromServer()
                                } else {
                                }
                            }
                    } else {
                        // 🔧 修复：统一处理所有 SF Symbol
                        Image(systemName: avatar)
                            .font(.system(size: 40))
                            .foregroundColor(avatar == "person.circle.fill" ? .purple : .blue)
                            .background(Circle().fill(Color.gray.opacity(0.1)).frame(width: 50, height: 50))
                            .onAppear {
                                loadAvatarFromServer()
                                loadUserNameFromServer()
                            }
                            .task {
                                // 🎯 新增：检查查询是否失败，如果失败则重试
                                try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 / 7.0)) // 1/7秒
                                // 检查是否查询失败（avatarFromServer 为 nil）且未重试过
                                let shouldRetry = avatarFromServer == nil && avatarRetryCount < 2
                                if shouldRetry {
                                    retryLoadAvatarFromServer()
                                } else {
                                }
                            }
                    }
                } else {
                    // Emoji 或文本头像显示
                    Text(avatar)
                        .font(.system(size: 40))
                        .fixedSize(horizontal: true, vertical: false)
                        .background(Circle().fill(Color.gray.opacity(0.1)).frame(width: 50, height: 50))
                        .onAppear {
                            loadAvatarFromServer()
                            loadUserNameFromServer()
                        }
                        .task {
                            // 🎯 新增：检查查询是否失败，如果失败则重试
                            try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 / 7.0)) // 1/7秒
                            // 🎯 修改：检查是否查询失败（avatarFromServer 为 nil）且未达到最大重试次数
                            let shouldRetry = avatarFromServer == nil && avatarRetryCount < 2
                            if shouldRetry {
                                retryLoadAvatarFromServer()
                            } else {
                            }
                        }
                }
            } else {
                // 使用默认头像 - Apple账号与内部账号使用相同的默认头像
                ZStack {
                    Circle().fill(Color.gray.opacity(0.1)).frame(width: 50, height: 50)
                    if item.loginType == "apple" {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.purple)
                            .font(.system(size: 24))
                    } else {
                        // 游客用户 - 与用户头像界面一致：使用person.circle（蓝色）
                        Image(systemName: "person.circle")
                            .foregroundColor(.blue)
                            .font(.system(size: 24))
                    }
                }
                .onAppear {
                    loadAvatarFromServer()
                    loadUserNameFromServer()
                }
                .task {
                    // 🎯 新增：检查查询是否失败，如果失败则重试
                    // 🎯 修改：等待初始查询完成（1/7秒后），如果查询失败（avatarFromServer 为 nil），则重试
                    try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 / 7.0)) // 1/7秒
                    // 🎯 修改：检查是否查询失败（avatarFromServer 为 nil）且未达到最大重试次数
                    let shouldRetry = avatarFromServer == nil && avatarRetryCount < 2
                    if shouldRetry {
                        retryLoadAvatarFromServer()
                    } else {
                    }
                }
            }
            
            // 用户信息
            VStack(alignment: .leading, spacing: 4) {
                // 🎯 只使用 resolvedUserName（从 UserNameRecord 表获取），不从 UserScore 表读取
                let displayName = resolvedUserName ?? "未知用户"
                ColorfulUserNameText(
                    userName: displayName,
                    userId: item.id,
                    loginType: item.loginType,
                    font: .headline,
                    fontWeight: .semibold,
                    lineLimit: 1,
                    truncationMode: .tail
                )
                .onAppear {
                    // 与用户头像界面一致：在onAppear时实时查询服务器用户名
                    loadUserNameFromServer()
                }
                .task {
                    // 🎯 新增：检查查询是否失败，如果失败则重试
                    // 🎯 修改：等待初始查询完成（1/7秒后），如果查询失败（userNameFromServer 为 nil），则重试以获取最新用户名
                    try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 / 7.0)) // 1/7秒
                    // 🎯 修改：只要查询失败（userNameFromServer 为 nil）就重试，不管 UserScore 表中是否有用户名
                    // 这样可以确保获取到最新的用户名，即使 UserScore 表中有旧的用户名
                    let shouldRetry = userNameFromServer == nil && userNameRetryCount < 2
                    if shouldRetry {
                        retryLoadUserNameFromServer()
                    } else {
                    }
                }
                
                // 距离信息 - 使用缓存的距离
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(cachedDistance != nil ? DistanceUtils.formatDistance(cachedDistance!) : "暂无位置")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .onAppear {
                            if cachedDistance == nil {
                            } else {
                            }
                        }
                }
                

            }
            
            Spacer()
            
            // 分数
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(item.totalScore)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                Text("积分")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
        .contentShape(Rectangle()) // 确保整个区域都可以点击
    }
}

#Preview {
    RankingListView(
        locationManager: LocationManager(),
        userManager: UserManager(), // 🎯 新增：添加 userManager 参数
        onRankingItemTap: { _ in },
        selectedItemId: nil
    )
}
