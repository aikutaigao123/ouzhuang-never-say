import Foundation

// 用户信息结构体
struct UserInfo {
    let id: String
    let userId: String // 用户ID（小驼峰命名）
    var fullName: String
    var email: String?
    let loginType: LoginType
    
    enum LoginType {
        case guest
        case apple
        
        func toString() -> String {
            switch self {
            case .guest:
                return "guest"
            case .apple:
                return "apple"
            }
        }
    }
}

// 用户积分模型
struct UserScore: Codable, Identifiable {
    let id: String // 用户ID
    var userName: String
    var userAvatar: String
    let userEmail: String?
    let loginType: String
    let totalScore: Int // 总积分
    let favoriteCount: Int // 收到的爱心数量
    let likeCount: Int // 收到的点赞数量
    let distance: Double? // 距离（米）
    let latitude: Double? // 用户纬度
    let longitude: Double? // 用户经度
    let lastUpdated: Date
    let deviceId: String? // 设备ID（用于黑名单过滤）
    
    init(userId: String, userName: String, userAvatar: String, userEmail: String?, loginType: String, favoriteCount: Int = 0, likeCount: Int = 0, distance: Double? = nil, latitude: Double? = nil, longitude: Double? = nil, deviceId: String? = nil, totalScore: Int? = nil) {
        self.id = userId
        self.userName = userName
        self.userAvatar = userAvatar
        self.userEmail = userEmail
        self.loginType = loginType
        self.favoriteCount = favoriteCount
        self.likeCount = likeCount
        self.totalScore = totalScore ?? (favoriteCount + likeCount)
        self.distance = distance
        self.latitude = latitude
        self.longitude = longitude
        self.lastUpdated = Date()
        self.deviceId = deviceId
    }
    
    // 支持lastUpdated的构造函数
    init(userId: String, userName: String, userAvatar: String, userEmail: String?, loginType: String, favoriteCount: Int = 0, likeCount: Int = 0, distance: Double? = nil, latitude: Double? = nil, longitude: Double? = nil, lastUpdated: Date, deviceId: String? = nil, totalScore: Int? = nil) {
        self.id = userId
        self.userName = userName
        self.userAvatar = userAvatar
        self.userEmail = userEmail
        self.loginType = loginType
        self.favoriteCount = favoriteCount
        self.likeCount = likeCount
        self.totalScore = totalScore ?? (favoriteCount + likeCount)
        self.distance = distance
        self.latitude = latitude
        self.longitude = longitude
        self.lastUpdated = lastUpdated
        self.deviceId = deviceId
    }
    
    // 更新积分
    func updateScore(favoriteCount: Int, likeCount: Int) -> UserScore {
        return UserScore(
            userId: self.id,
            userName: self.userName,
            userAvatar: self.userAvatar,
            userEmail: self.userEmail,
            loginType: self.loginType,
            favoriteCount: favoriteCount,
            likeCount: likeCount,
            distance: self.distance,
            latitude: self.latitude,
            longitude: self.longitude,
            deviceId: self.deviceId
        )
    }
    
    // 更新位置信息
    func updateLocation(latitude: Double?, longitude: Double?) -> UserScore {
        return UserScore(
            userId: self.id,
            userName: self.userName,
            userAvatar: self.userAvatar,
            userEmail: self.userEmail,
            loginType: self.loginType,
            favoriteCount: self.favoriteCount,
            likeCount: self.likeCount,
            distance: self.distance,
            latitude: latitude,
            longitude: longitude,
            deviceId: self.deviceId
        )
    }
    
    // 格式化距离显示
    func formattedDistance() -> String {
        guard let distance = distance else {
            return "未知"
        }
        
        if distance < 1000 {
            return "\(Int(distance))m"
        } else {
            let km = distance / 1000
            return String(format: "%.1fkm", km)
        }
    }
}
