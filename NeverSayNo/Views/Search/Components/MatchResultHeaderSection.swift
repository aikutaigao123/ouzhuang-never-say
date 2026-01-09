import SwiftUI

struct MatchResultHeaderSection: View {
    let record: LocationRecord
    let latestAvatars: [String: String]
    let latestUserNames: [String: String]
    let isUserFavorited: (String) -> Bool
    let isUserFavoritedByMe: (String) -> Bool
    let onToggleFavorite: (String, String?, String?, String?, String?, String?) -> Void
    let onAvatarTap: () -> Void
    let onCopyUserName: () -> Void
    let isLocationRecordLiked: (String) -> Bool // 🎯 新增：检查是否已点赞
    let onToggleLike: (String, String) -> Void // 🎯 新增：切换点赞状态
    let onDeleteRecommendation: (() -> Void)? // 🎯 新增：删除推荐榜记录回调（可选）
    
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.05)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(height: 120)
        .overlay(
            MatchResultHeaderContent(
                record: record,
                latestAvatars: latestAvatars,
                latestUserNames: latestUserNames,
                isUserFavorited: isUserFavorited,
                isUserFavoritedByMe: isUserFavoritedByMe,
                onToggleFavorite: onToggleFavorite,
                onAvatarTap: onAvatarTap,
                onCopyUserName: onCopyUserName,
                isLocationRecordLiked: isLocationRecordLiked, // 🎯 新增：传递点赞检查
                onToggleLike: onToggleLike, // 🎯 新增：传递点赞切换
                onDeleteRecommendation: onDeleteRecommendation // 🎯 新增：传递删除回调
            )
        )
        .onAppear {
        }
    }
}