import Foundation
import CoreLocation

// 位置记录结构体
struct LocationRecord: Codable, Identifiable {
    let id: Int
    let objectId: String // 添加 LeanCloud 的 objectId
    let timestamp: String
    let latitude: Double
    let longitude: Double
    let accuracy: Double
    let userId: String
    let userName: String?
    let loginType: String?
    let userEmail: String? // 新增邮箱字段
    let userAvatar: String? // 新增用户头像字段
    let deviceId: String
    let clientTimestamp: Double?
    let timezone: String?
    let status: String? // 状态字段，如"active"
    // 新增：记录数量（用于合并后的记录）
    let recordCount: Int?
    // 新增：点赞数
    let likeCount: Int?
    // 新增：地名
    let placeName: String?
    // 新增：推荐理由
    let reason: String?
    
    // 自定义初始化器
    init(id: Int, objectId: String, timestamp: String, latitude: Double, longitude: Double, accuracy: Double, userId: String, userName: String?, loginType: String?, userEmail: String?, userAvatar: String?, deviceId: String, clientTimestamp: Double?, timezone: String?, status: String? = nil, recordCount: Int? = nil, likeCount: Int? = nil, placeName: String? = nil, reason: String? = nil) {
        self.id = id
        self.objectId = objectId
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.accuracy = accuracy
        self.userId = userId
        self.userName = userName
        self.loginType = loginType
        self.userEmail = userEmail
        self.userAvatar = userAvatar
        self.deviceId = deviceId
        self.clientTimestamp = clientTimestamp
        self.timezone = timezone
        self.status = status
        self.recordCount = recordCount
        self.likeCount = likeCount
        self.placeName = placeName
        self.reason = reason
    }
}

// 导航目标位置
struct NavigationTarget: Identifiable {
    let id = UUID()
    let userId: String
    let userName: String
    let loginType: String?
    let latitude: Double
    let longitude: Double
}
