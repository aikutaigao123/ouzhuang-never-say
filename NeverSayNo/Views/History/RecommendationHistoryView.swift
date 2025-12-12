import SwiftUI
import CoreLocation

// 推荐卡片历史视图（左侧，对应排行榜的推荐榜）
struct RecommendationHistoryView: View {
    let history: [RandomMatchHistory]
    let calculateDistance: (CLLocation, Double, Double) -> Double
    let formatDistance: (Double) -> String
    let formatTimestamp: (String, String?) -> String
    let calculateBearing: (CLLocation, Double, Double) -> Double
    let getDirectionText: (Double) -> String
    let calculateTimezoneFromLongitude: (Double) -> String
    let getTimezoneName: (Double) -> String
    let onDeleteHistoryItem: (RandomMatchHistory) -> Void
    let onReportUser: (String, String?, String?, String, String?, String?) -> Void
    let hasReportedUser: (String) -> Bool
    let avatarResolver: (String?, String?, String?) -> String?
    let userNameResolver: (String?, String?) -> String?
    let ensureLatestAvatar: (String?, String?) -> Void
    let isUserFavorited: (String) -> Bool
    let isUserFavoritedByMe: (String) -> Bool
    let onToggleFavorite: (String, String?, String?, String?, String?, String?) -> Void
    let isUserLiked: (String) -> Bool
    let onToggleLike: (String, String?, String?, String?, String?, String?) -> Void
    let onHistoryItemTap: (RandomMatchHistory) -> Void
    let locationManager: LocationManager?
    let selectedItemId: UUID?
    
    @State private var currentHistory: [RandomMatchHistory]
    @State private var historyAvatarCache: [String: String] = [:]
    @State private var historyUserNameCache: [String: String] = [:]
    @State private var highlightedItemId: UUID? = nil
    @State private var isRefreshing = false
    
    // 🔧 新增：距离缓存（参考推荐榜）
    @State private var distanceCache: [UUID: Double] = [:]
    @State private var hasPreloadedDistances = false
    @State private var isPreloadingDistances = false
    
    @Environment(\.dismiss) private var dismiss
    
    // 过滤推荐卡片
    private var recommendationRecords: [RandomMatchHistory] {
        currentHistory.filter { historyItem in
            let isRecommendation = (historyItem.record.placeName?.isEmpty == false) || (historyItem.record.reason?.isEmpty == false)
            return isRecommendation
        }
    }
    
    init(
        history: [RandomMatchHistory],
        calculateDistance: @escaping (CLLocation, Double, Double) -> Double,
        formatDistance: @escaping (Double) -> String,
        formatTimestamp: @escaping (String, String?) -> String,
        calculateBearing: @escaping (CLLocation, Double, Double) -> Double,
        getDirectionText: @escaping (Double) -> String,
        calculateTimezoneFromLongitude: @escaping (Double) -> String,
        getTimezoneName: @escaping (Double) -> String,
        onDeleteHistoryItem: @escaping (RandomMatchHistory) -> Void,
        onReportUser: @escaping (String, String?, String?, String, String?, String?) -> Void,
        hasReportedUser: @escaping (String) -> Bool,
        avatarResolver: @escaping (String?, String?, String?) -> String?,
        userNameResolver: @escaping (String?, String?) -> String?,
        ensureLatestAvatar: @escaping (String?, String?) -> Void,
        isUserFavorited: @escaping (String) -> Bool,
        isUserFavoritedByMe: @escaping (String) -> Bool,
        onToggleFavorite: @escaping (String, String?, String?, String?, String?, String?) -> Void,
        isUserLiked: @escaping (String) -> Bool,
        onToggleLike: @escaping (String, String?, String?, String?, String?, String?) -> Void,
        onHistoryItemTap: @escaping (RandomMatchHistory) -> Void,
        locationManager: LocationManager?,
        selectedItemId: UUID? = nil
    ) {
        self.history = history
        self.calculateDistance = calculateDistance
        self.formatDistance = formatDistance
        self.formatTimestamp = formatTimestamp
        self.calculateBearing = calculateBearing
        self.getDirectionText = getDirectionText
        self.calculateTimezoneFromLongitude = calculateTimezoneFromLongitude
        self.getTimezoneName = getTimezoneName
        self.onDeleteHistoryItem = onDeleteHistoryItem
        self.onReportUser = onReportUser
        self.hasReportedUser = hasReportedUser
        self.avatarResolver = avatarResolver
        self.userNameResolver = userNameResolver
        self.ensureLatestAvatar = ensureLatestAvatar
        self.isUserFavorited = isUserFavorited
        self.isUserFavoritedByMe = isUserFavoritedByMe
        self.onToggleFavorite = onToggleFavorite
        self.isUserLiked = isUserLiked
        self.onToggleLike = onToggleLike
        self.onHistoryItemTap = onHistoryItemTap
        self.locationManager = locationManager
        self.selectedItemId = selectedItemId
        _currentHistory = State(initialValue: history)
    }
    
    var body: some View {
        Group {
            if recommendationRecords.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "star")
                        .font(.system(size: 60))
                        .foregroundColor(.gray.opacity(0.6))
                    Text("暂无推荐卡片")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                    Text("推荐卡片将显示在这里")
                        .font(.body)
                        .foregroundColor(.gray.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 60)
            } else {
                VStack(spacing: 0) {
                    // 顶部工具栏（学习排行榜设计）
                    HStack {
                        Text("推荐")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if isRefreshing {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
                    
                    ScrollViewReader { proxy in
                        List {
                            ForEach(recommendationRecords, id: \.id) { historyItem in
                                historyItemRow(historyItem: historyItem, proxy: proxy)
                            }
                        }
                        .listStyle(PlainListStyle())
                        .refreshable {
                            isRefreshing = true
                            refreshHistoryAvatars()
                            currentHistory = history
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                isRefreshing = false
                            }
                        }
                        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshHistoryList"))) { notification in
                            if let userInfo = notification.userInfo {
                                if let newItemId = userInfo["selectedHistoryId"] as? UUID {
                                    highlightedItemId = newItemId
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        currentHistory = history
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                            let itemExists = recommendationRecords.contains { $0.id == newItemId }
                                            if itemExists {
                                                withAnimation {
                                                    proxy.scrollTo(newItemId, anchor: .center)
                                                }
                                            }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                                highlightedItemId = nil
                                            }
                                        }
                                    }
                                } else {
                                    currentHistory = history
                                }
                            } else {
                                currentHistory = history
                            }
                        }
                        .onAppear {
                            if let selectedId = selectedItemId {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    let itemExists = recommendationRecords.contains { $0.id == selectedId }
                                    if itemExists {
                                        withAnimation {
                                            proxy.scrollTo(selectedId, anchor: .center)
                                        }
                                    }
                                }
                            }
                            currentHistory = history
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                refreshHistoryAvatars()
                            }
                            // 🔧 新增：开始预加载距离信息（参考推荐榜）
                            startPreloadingDistances()
                        }
                        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HistoryItemDeleted"))) { notification in
                            if let deletedItem = notification.object as? RandomMatchHistory {
                                currentHistory.removeAll { $0.id == deletedItem.id }
                            }
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func historyItemRow(historyItem: RandomMatchHistory, proxy: ScrollViewProxy) -> some View {
        RecommendationHistoryItemView(
            historyItem: historyItem,
            cachedDistance: distanceCache[historyItem.id],
            isHighlighted: selectedItemId == historyItem.id || highlightedItemId == historyItem.id,
            locationManager: locationManager,
            onHistoryItemTap: { item in
                onHistoryItemTap(item)
                dismiss()
                NotificationCenter.default.post(name: NSNotification.Name("DismissProfileSheet"), object: nil)
            },
            onDeleteHistoryItem: onDeleteHistoryItem
        )
        .id(historyItem.id)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                let recordExists = currentHistory.contains { $0.id == historyItem.id }
                guard recordExists else { return }
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                onDeleteHistoryItem(historyItem)
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }
    
    private func refreshHistoryAvatars() {
        guard !currentHistory.isEmpty else {
            historyAvatarCache.removeAll()
            historyUserNameCache.removeAll()
            return
        }
        var userIds = Set<String>()
        for historyItem in currentHistory {
            userIds.insert(historyItem.record.userId)
        }
        filterAndUpdateHistoryUserNameCache(neededUserIds: userIds)
        filterAndUpdateHistoryUserAvatarCache(neededUserIds: userIds)
        DispatchQueue.global(qos: .userInitiated).async {
            LeanCloudService.shared.fetchAllUserNameRecords { records, error in
                DispatchQueue.main.async {
                    if records != nil {
                        self.filterAndUpdateHistoryUserNameCache(neededUserIds: userIds)
                    }
                }
            }
            LeanCloudService.shared.fetchAllUserAvatarRecords { records, error in
                DispatchQueue.main.async {
                    if records != nil {
                        self.filterAndUpdateHistoryUserAvatarCache(neededUserIds: userIds)
                    }
                }
            }
        }
    }
    
    private func filterAndUpdateHistoryUserNameCache(neededUserIds: Set<String>) {
        if let userNameRecords = MessageButtonCacheManager.shared.getCachedUserNameRecords() {
            for record in userNameRecords {
                if let userId = record["userId"] as? String,
                   let userName = record["userName"] as? String,
                   neededUserIds.contains(userId),
                   !userName.isEmpty {
                    historyUserNameCache[userId] = userName
                }
            }
        }
    }
    
    private func filterAndUpdateHistoryUserAvatarCache(neededUserIds: Set<String>) {
        if let userAvatarRecords = MessageButtonCacheManager.shared.getCachedUserAvatarRecords() {
            for record in userAvatarRecords {
                if let userId = record["userId"] as? String,
                   let avatar = record["userAvatar"] as? String,
                   neededUserIds.contains(userId),
                   !avatar.isEmpty {
                    historyAvatarCache[userId] = avatar
                }
            }
        }
    }
    
    private func defaultAvatarForHistory(userId: String?, loginType: String?) -> String {
        if let loginType = loginType, loginType == "apple" {
            return "person.circle.fill"
        }
        return "person.circle"
    }
    
    // 🔧 新增：预加载距离信息（参考推荐榜）
    private func startPreloadingDistances() {
        guard let locationManager = locationManager,
              let currentLocation = locationManager.location,
              !isPreloadingDistances else {
            return
        }
        
        isPreloadingDistances = true
        hasPreloadedDistances = false
        
        DispatchQueue.global(qos: .userInitiated).async {
            var newDistanceCache: [UUID: Double] = [:]
            
            for historyItem in recommendationRecords {
                let distance = calculateDistance(
                    currentLocation,
                    historyItem.record.latitude,
                    historyItem.record.longitude
                )
                newDistanceCache[historyItem.id] = distance
            }
            
            DispatchQueue.main.async {
                self.distanceCache = newDistanceCache
                self.hasPreloadedDistances = true
                self.isPreloadingDistances = false
            }
        }
    }
}

