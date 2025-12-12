import SwiftUI
import CoreLocation

// 随机匹配历史视图（包装器，使用新的HistoryView）
struct RandomMatchHistoryView: View {
    let history: [RandomMatchHistory]
    let calculateDistance: (CLLocation, Double, Double) -> Double
    let formatDistance: (Double) -> String
    let formatTimestamp: (String, String?) -> String
    let calculateBearing: (CLLocation, Double, Double) -> Double
    let getDirectionText: (Double) -> String
    let calculateTimezoneFromLongitude: (Double) -> String
    let getTimezoneName: (Double) -> String
    let onClearHistory: () -> Void
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
    
    // 初始化方法
    init(
        history: [RandomMatchHistory],
        calculateDistance: @escaping (CLLocation, Double, Double) -> Double,
        formatDistance: @escaping (Double) -> String,
        formatTimestamp: @escaping (String, String?) -> String,
        calculateBearing: @escaping (CLLocation, Double, Double) -> Double,
        getDirectionText: @escaping (Double) -> String,
        calculateTimezoneFromLongitude: @escaping (Double) -> String,
        getTimezoneName: @escaping (Double) -> String,
        onClearHistory: @escaping () -> Void,
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
        self.onClearHistory = onClearHistory
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
    }
    
    var body: some View {
        HistoryView(
            history: history,
            calculateDistance: calculateDistance,
            formatDistance: formatDistance,
            formatTimestamp: formatTimestamp,
            calculateBearing: calculateBearing,
            getDirectionText: getDirectionText,
            calculateTimezoneFromLongitude: calculateTimezoneFromLongitude,
            getTimezoneName: getTimezoneName,
            onClearHistory: onClearHistory,
            onDeleteHistoryItem: onDeleteHistoryItem,
            onReportUser: onReportUser,
            hasReportedUser: hasReportedUser,
            avatarResolver: avatarResolver,
            userNameResolver: userNameResolver,
            ensureLatestAvatar: ensureLatestAvatar,
            isUserFavorited: isUserFavorited,
            isUserFavoritedByMe: isUserFavoritedByMe,
            onToggleFavorite: onToggleFavorite,
            isUserLiked: isUserLiked,
            onToggleLike: onToggleLike,
            onHistoryItemTap: onHistoryItemTap,
            locationManager: locationManager,
            selectedItemId: selectedItemId,
            initialTab: 0
        )
    }
}
