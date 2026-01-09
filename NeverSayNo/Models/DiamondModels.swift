import Foundation

// 钻石记录结构体
struct DiamondRecord: Codable, Identifiable {
    let id: Int
    let objectId: String // LeanCloud 的 objectId
    let userId: String
    let user_name: String? // 用户名字段
    let userAvatar: String? // 头像emoji
    let userEmail: String? // 新增邮箱字段
    let login_type: String // "guest" 或 "apple"
    let deviceId: String? // 设备ID字段
    let diamonds: Int
    let created_at: String
    let updated_at: String
}
