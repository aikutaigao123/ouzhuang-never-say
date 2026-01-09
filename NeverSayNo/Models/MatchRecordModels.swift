import Foundation
import CoreLocation

// MARK: - DEPRECATED: MatchRecord
// ⚠️ 已废弃：此结构体不符合 LeanCloud 好友关系开发指南
// 
// 根据 LeanCloud 官方好友关系开发指南，好友关系应该存储在：
// - _Followee 表（friendStatus=true）：存储互为好友的关系
// - _FriendshipRequest 表：存储好友申请
//
// 请使用 FriendshipManager 管理好友关系：
// - FriendshipManager.shared.fetchFriendsList() 获取好友列表
// - FriendshipManager.shared.sendFriendshipRequest() 发送好友申请
// - FriendshipManager.shared.acceptFriendshipRequest() 接受好友申请
//
// MatchRecord 仅保留用于向后兼容和数据分析，不建议用于好友关系管理

// 匹配记录数据模型（兼容性与数据分析使用）
struct MatchRecord: Codable, Identifiable {
    let id: UUID
    let objectId: String? // LeanCloud的objectId
    let user1Id: String
    let user2Id: String
    var user1Name: String
    var user2Name: String
    var user1Avatar: String
    var user2Avatar: String
    var user1LoginType: String
    var user2LoginType: String
    let matchTime: Date
    let matchLocationLat: Double
    let matchLocationLng: Double
    let status: String
    let deviceId: String
    let timezone: String
    let deviceTime: Date
    
    init(id: UUID = UUID(), objectId: String? = nil, user1Id: String, user2Id: String, user1Name: String, user2Name: String, user1Avatar: String, user2Avatar: String, user1LoginType: String, user2LoginType: String, matchTime: Date, matchLocation: CLLocationCoordinate2D?, status: String = "active", deviceId: String, timezone: String, deviceTime: Date) {
        self.id = id
        self.objectId = objectId
        self.user1Id = user1Id
        self.user2Id = user2Id
        self.user1Name = user1Name
        self.user2Name = user2Name
        self.user1Avatar = user1Avatar
        self.user2Avatar = user2Avatar
        self.user1LoginType = user1LoginType
        self.user2LoginType = user2LoginType
        self.matchTime = matchTime
        self.matchLocationLat = matchLocation?.latitude ?? 0.0
        self.matchLocationLng = matchLocation?.longitude ?? 0.0
        self.status = status
        self.deviceId = deviceId
        self.timezone = timezone
        self.deviceTime = deviceTime
    }
    
    // 从LeanCloud数据创建匹配记录的便利初始化方法
    init?(fromLeanCloudData data: [String: Any]) {
        guard let user1Id = data["user1Id"] as? String,
              let user2Id = data["user2Id"] as? String,
              let user1Name = data["user1Name"] as? String,
              let user2Name = data["user2Name"] as? String,
              let user1Avatar = data["user1Avatar"] as? String,
              let user2Avatar = data["user2Avatar"] as? String,
              let user1LoginType = data["user1LoginType"] as? String,
              let user2LoginType = data["user2LoginType"] as? String,
              let matchTimeString = data["matchTime"] as? String,
              let status = data["status"] as? String,
              let deviceId = data["deviceId"] as? String,
              let timezone = data["timezone"] as? String,
              let deviceTimeString = data["deviceTime"] as? String else {
            return nil
        }
        
        // 获取LeanCloud的objectId
        let objectId = data["objectId"] as? String
        
        // 获取位置信息
        let matchLocationLat = data["matchLocationLat"] as? Double ?? 0.0
        let matchLocationLng = data["matchLocationLng"] as? Double ?? 0.0
        
        // 解析时间戳
        let formatter = ISO8601DateFormatter()
        let matchTime = formatter.date(from: matchTimeString) ?? Date()
        let deviceTime = formatter.date(from: deviceTimeString) ?? Date()
        
        self.id = UUID()
        self.objectId = objectId
        self.user1Id = user1Id
        self.user2Id = user2Id
        self.user1Name = user1Name
        self.user2Name = user2Name
        self.user1Avatar = user1Avatar
        self.user2Avatar = user2Avatar
        self.user1LoginType = user1LoginType
        self.user2LoginType = user2LoginType
        self.matchTime = matchTime
        self.matchLocationLat = matchLocationLat
        self.matchLocationLng = matchLocationLng
        self.status = status
        self.deviceId = deviceId
        self.timezone = timezone
        self.deviceTime = deviceTime
    }
    
    // 获取匹配位置坐标
    var matchLocation: CLLocationCoordinate2D? {
        guard matchLocationLat != 0.0 || matchLocationLng != 0.0 else { return nil }
        return CLLocationCoordinate2D(latitude: matchLocationLat, longitude: matchLocationLng)
    }
    
    // 获取匹配时间的时间差描述
    var timeAgoDescription: String {
        return TimeAgoUtils.formatTimeAgo(from: matchTime)
    }
    
    // 检查匹配是否有效（状态为active）
    var isValid: Bool {
        let isValid = status == "active"
        return isValid
    }
    
    // 获取好友的在线状态（统一方法，使用user_id查询所有表）
    func getFriendOnlineStatus(currentUserId: String, completion: @escaping (Bool, Date?) -> Void) {
        let friendId = self.user1Id == currentUserId ? self.user2Id : self.user1Id
        
        
        // 使用统一的查询方法
        LeanCloudService.shared.fetchUserLastOnlineTime(userId: friendId) { isOnline, lastActiveTime in
            completion(isOnline, lastActiveTime)
        }
    }
    
    // 静态方法：从LeanCloud数据创建MatchRecord
    static func fromLeanCloudData(_ data: [String: Any]) -> MatchRecord? {
        return MatchRecord(fromLeanCloudData: data)
    }
}
