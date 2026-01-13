import SwiftUI
import Foundation

struct DataHelpers {
    // 检查用户是否被当前用户喜欢
    static func isUserFavorited(userId: String, favoriteRecords: [FavoriteRecord]) -> Bool {
        let result = favoriteRecords.contains { $0.favoriteUserId == userId && ($0.status == "active" || $0.status == nil) }
        return result
    }
    
    // 检查用户是否喜欢当前用户
    static func isUserFavoritedByMe(userId: String, usersWhoLikedMe: [FavoriteRecord]) -> Bool {
        let allowedStatuses: Set<String> = ["active", "friend", "accepted", "pending", "approved"]
        return usersWhoLikedMe.contains { record in
            guard record.userId == userId else { return false }
            guard let status = record.status?.lowercased() else {
                return true
            }
            if status == "cancelled" || status == "declined" || status == "rejected" {
                return false
            }
            return allowedStatuses.contains(status)
        }
    }
    
    // 检查用户是否被当前用户点赞
    static func isUserLiked(userId: String, likeRecords: [LikeRecord]) -> Bool {
        return likeRecords.contains { $0.likedUserId == userId && ($0.status == "active" || $0.status == nil) }
    }
    
    // 检查LocationRecord是否已被点赞（基于objectId）
    static func isLocationRecordLiked(objectId: String, currentUser: UserInfo?) -> Bool {
        guard let currentUser = currentUser else { return false }
        let likedRecordsKey = StorageKeyUtils.getLikedLocationRecordsKey(for: currentUser)
        return UserDefaultsManager.isLocationRecordLiked(objectId, forKey: likedRecordsKey)
    }
}
