import SwiftUI

struct MatchResultUserInfo: View {
    let record: LocationRecord
    let latestUserNames: [String: String]
    let isUserFavorited: (String) -> Bool
    let onToggleFavorite: (String, String?, String?, String?, String?, String?) -> Void
    let onCopyUserName: () -> Void
    let isLocationRecordLiked: (String) -> Bool // 🎯 新增：检查是否已点赞
    let onToggleLike: (String, String) -> Void // 🎯 新增：切换点赞状态
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MatchResultUserName(
                userName: record.userName,
                latestUserNames: latestUserNames,
                userId: record.userId,
                loginType: record.loginType, // 传递loginType
                placeName: record.placeName, // 🎯 新增：传递推荐榜地名
                reason: record.reason, // 🎯 新增：传递推荐理由
                onCopy: onCopyUserName
            )
            
            MatchResultUserTypeAndFavorite(
                record: record,
                isUserFavorited: isUserFavorited,
                onToggleFavorite: onToggleFavorite,
                isLocationRecordLiked: isLocationRecordLiked, // 🎯 新增：传递点赞检查
                onToggleLike: onToggleLike // 🎯 新增：传递点赞切换
            )
        }
    }
}