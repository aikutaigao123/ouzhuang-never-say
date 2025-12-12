import SwiftUI

// 推荐榜数据模型
struct RecommendationItem: Identifiable {
    let id: String
    let userId: String  // 新增：实际的用户ID
    let userName: String
    let userAvatar: String
    let loginType: String? // 新增：登录类型
    let userEmail: String? // 🎯 新增：用户邮箱
    let placeName: String
    let reason: String
    let matchRate: Int
    let latitude: Double?
    let longitude: Double?
    let distance: Double?
    let likeCount: Int // 新增：点赞数量
    let rank: Int // 新增：排名
}

// 辅助函数：将RecommendationItem转换为LocationRecord
extension RecommendationItem {
    func toLocationRecord() -> LocationRecord {

        let locationRecord = LocationRecord(
            id: 0,
            objectId: self.id,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            latitude: self.latitude ?? 0.0,
            longitude: self.longitude ?? 0.0,
            accuracy: 0.0,
            userId: self.userId,
            userName: self.userName,
            loginType: self.loginType, // 🎯 修改：传递loginType
            userEmail: self.userEmail, // 🎯 修改：传递userEmail
            userAvatar: self.userAvatar,
            deviceId: "",
            clientTimestamp: nil,
            timezone: nil,
            status: "active",
            recordCount: nil,
            likeCount: self.likeCount,
            placeName: self.placeName,
            reason: self.reason
        )

        return locationRecord
    }
}

