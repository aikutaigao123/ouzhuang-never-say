import Foundation

// 喜欢记录结构体
struct FavoriteRecord: Codable, Identifiable {
    let id: UUID
    let userId: String // 当前用户ID
    let favoriteUserId: String // 被喜欢的用户ID
    let favoriteUserName: String? // 被喜欢的用户名
    let favoriteUserEmail: String? // 被喜欢的用户邮箱
    let favoriteUserLoginType: String? // 被喜欢的用户登录类型
    let favoriteUserAvatar: String? // 被喜欢的用户头像
    let favoriteTime: Date // 喜欢时间
    let recordObjectId: String? // 关联的位置记录objectId
    let status: String? // 状态字段，如"active"或"cancelled"
    
    init(userId: String, favoriteUserId: String, favoriteUserName: String?, favoriteUserEmail: String?, favoriteUserLoginType: String?, favoriteUserAvatar: String?, recordObjectId: String?, status: String? = "active") {
        self.id = UUID()
        self.userId = userId
        self.favoriteUserId = favoriteUserId
        self.favoriteUserName = favoriteUserName
        self.favoriteUserEmail = favoriteUserEmail
        self.favoriteUserLoginType = favoriteUserLoginType
        self.favoriteUserAvatar = favoriteUserAvatar
        self.favoriteTime = Date()
        self.recordObjectId = recordObjectId
        self.status = status
    }
    
    // 从字典初始化
    init?(dictionary: [String: Any]) {
        guard let userId = dictionary["userId"] as? String,
              let favoriteUserId = dictionary["favoriteUserId"] as? String else {
            return nil
        }
        
        self.id = UUID()
        self.userId = userId
        self.favoriteUserId = favoriteUserId
        self.favoriteUserName = dictionary["favoriteUserName"] as? String
        self.favoriteUserEmail = dictionary["favoriteUserEmail"] as? String
        self.favoriteUserLoginType = dictionary["favoriteUserLoginType"] as? String
        self.favoriteUserAvatar = dictionary["favoriteUserAvatar"] as? String
        self.recordObjectId = dictionary["recordObjectId"] as? String
        self.status = dictionary["status"] as? String
        
        // 处理时间字段
        if let favoriteTimeString = dictionary["favoriteTime"] as? String {
            let formatter = ISO8601DateFormatter()
            self.favoriteTime = formatter.date(from: favoriteTimeString) ?? Date()
        } else {
            self.favoriteTime = Date()
        }
    }
    
    func debugSummary() -> String {
        return "[favoriteUserId: \(favoriteUserId), status: \(status ?? "nil"), name: \(favoriteUserName ?? "nil")]"
    }
}

extension FavoriteRecord {
    func debugPairKey() -> String {
        return "\(userId)|\(favoriteUserId)"
    }
    
    func debugStatusSummary(prefix: String) -> String {
        return "\(prefix): pair=\(debugPairKey()), status=\(status ?? "nil")"
    }
}

// 点赞记录结构体
struct LikeRecord: Codable, Identifiable {
    let id: UUID
    let userId: String // 当前用户ID
    let likedUserId: String // 被点赞的用户ID
    let likedUserName: String? // 被点赞的用户名
    let likedUserEmail: String? // 被点赞的用户邮箱
    let likedUserLoginType: String? // 被点赞的用户登录类型
    let likedUserAvatar: String? // 被点赞的用户头像
    let likeTime: Date // 点赞时间
    let recordObjectId: String? // 关联的位置记录objectId
    let status: String? // 状态字段，如"active"或"cancelled"
    
    init(userId: String, likedUserId: String, likedUserName: String?, likedUserEmail: String?, likedUserLoginType: String?, likedUserAvatar: String?, recordObjectId: String?, status: String? = "active") {
        self.id = UUID()
        self.userId = userId
        self.likedUserId = likedUserId
        self.likedUserName = likedUserName
        self.likedUserEmail = likedUserEmail
        self.likedUserLoginType = likedUserLoginType
        self.likedUserAvatar = likedUserAvatar
        self.likeTime = Date()
        self.recordObjectId = recordObjectId
        self.status = status
    }
}
