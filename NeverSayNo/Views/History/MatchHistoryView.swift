import SwiftUI
import CoreLocation

// 匹配卡片历史视图（右侧，对应排行榜的排行榜）
struct MatchHistoryView: View {
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
    
    @Environment(\.dismiss) private var dismiss
    
    // 过滤匹配卡片
    private var matchRecords: [RandomMatchHistory] {
        currentHistory.filter { historyItem in
            let isRecommendation = (historyItem.record.placeName?.isEmpty == false) || (historyItem.record.reason?.isEmpty == false)
            return !isRecommendation // 匹配卡片：不是推荐卡片
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
            if matchRecords.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "person.2")
                        .font(.system(size: 60))
                        .foregroundColor(.gray.opacity(0.6))
                    Text("暂无匹配卡片")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                    Text("匹配卡片将显示在这里")
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
                        Text("个人")
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
                            ForEach(matchRecords, id: \.id) { historyItem in
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
                                            let itemExists = matchRecords.contains { $0.id == newItemId }
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
                                    let itemExists = matchRecords.contains { $0.id == selectedId }
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
        HistoryCardView(
            historyItem: historyItem,
            calculateDistance: calculateDistance,
            formatDistance: formatDistance,
            formatTimestamp: formatTimestamp,
            calculateTimezoneFromLongitude: calculateTimezoneFromLongitude,
            getTimezoneName: getTimezoneName,
            onReportUser: onReportUser,
            hasReportedUser: hasReportedUser,
            avatarResolver: { uid, ltype, snapshot in
                guard let uid = uid else {
                    return defaultAvatarForHistory(userId: nil, loginType: ltype)
                }
                if let customAvatar = UserDefaultsManager.getCustomAvatar(userId: uid), !customAvatar.isEmpty {
                    return customAvatar
                }
                if let cached = historyAvatarCache[uid], !cached.isEmpty {
                    return cached
                }
                if let resolved = avatarResolver(uid, ltype, snapshot), !resolved.isEmpty {
                    return resolved
                }
                if let snapshot = snapshot, !snapshot.isEmpty {
                    return snapshot
                }
                return defaultAvatarForHistory(userId: uid, loginType: ltype)
            },
            userNameResolver: { uid, ltype in
                if let uid = uid, let latest = historyUserNameCache[uid], !latest.isEmpty {
                    return latest
                }
                return userNameResolver(uid, ltype)
            },
            ensureLatestAvatar: ensureLatestAvatar,
            isUserFavorited: isUserFavorited,
            isUserFavoritedByMe: isUserFavoritedByMe,
            onToggleFavorite: onToggleFavorite,
            isUserLiked: isUserLiked,
            onToggleLike: onToggleLike,
            locationManager: locationManager
        )
        .id(historyItem.id)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(
            (selectedItemId == historyItem.id || highlightedItemId == historyItem.id) ? Color.blue.opacity(0.1) : Color.clear
        )
        .onTapGesture {
            onHistoryItemTap(historyItem)
            dismiss()
            NotificationCenter.default.post(name: NSNotification.Name("DismissProfileSheet"), object: nil)
        }
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
}

