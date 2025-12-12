import Foundation

// 消息数据模型
struct MessageItem: Identifiable, Codable {
    let id: UUID
    let objectId: String? // LeanCloud的objectId
    let senderId: String
    let senderName: String
    let senderAvatar: String
    let senderLoginType: String? // 新增：发送者登录类型
    let receiverId: String
    let receiverName: String
    let receiverAvatar: String
    let receiverLoginType: String? // 新增：接收者登录类型
    let content: String
    let timestamp: Date
    var isRead: Bool
    let type: MessageType
    let deviceId: String? // 设备ID
    let messageType: String? // 消息类型字段（favorite/like等）
    var isMatch: Bool // 新增：是否为匹配成功的消息
    
    enum MessageType: String, Codable, CaseIterable {
        case text = "text"
        case image = "image"
        case location = "location"
    }
    
    // 自定义初始化方法，支持从LeanCloud数据创建
    init(id: UUID = UUID(), objectId: String? = nil, senderId: String, senderName: String, senderAvatar: String, senderLoginType: String? = nil, receiverId: String, receiverName: String, receiverAvatar: String, receiverLoginType: String? = nil, content: String, timestamp: Date, isRead: Bool, type: MessageType, deviceId: String? = nil, messageType: String? = nil, isMatch: Bool = false) {
        self.id = id
        self.objectId = objectId
        self.senderId = senderId
        self.senderName = senderName
        self.senderAvatar = senderAvatar
        self.senderLoginType = senderLoginType
        self.receiverId = receiverId
        self.receiverName = receiverName
        self.receiverAvatar = receiverAvatar
        self.receiverLoginType = receiverLoginType
        self.content = content
        self.timestamp = timestamp
        self.isRead = isRead
        self.type = type
        self.deviceId = deviceId
        self.messageType = messageType
        self.isMatch = isMatch
    }
    
    // 从LeanCloud数据创建消息的便利初始化方法
    init?(fromLeanCloudData data: [String: Any]) {
        
        // 检查必需字段
        guard let senderId = data["senderId"] as? String else {
            return nil
        }
        guard let senderName = data["senderName"] as? String else {
            return nil
        }
        // 🔧 修复：senderAvatar可以为空字符串或nil，提供默认值
        let senderAvatar = data["senderAvatar"] as? String ?? ""
        guard let receiverId = data["receiverId"] as? String else {
            return nil
        }
        // 🔧 修复：receiverName可以为空字符串或nil，提供默认值
        let receiverName = data["receiverName"] as? String ?? ""
        // 🔧 修复：receiverAvatar可以为空字符串或nil，提供默认值
        let receiverAvatar = data["receiverAvatar"] as? String ?? ""
        guard let content = data["content"] as? String else {
            return nil
        }
        guard let timestampString = data["timestamp"] as? String else {
            return nil
        }
        // 🔧 修复：isRead可以为nil，提供默认值false
        let isRead = data["isRead"] as? Bool ?? false
        
        // type字段是可选的，如果没有则默认为text
        let typeString = data["type"] as? String ?? "text"
        
        // 获取LeanCloud的objectId
        let objectId = data["objectId"] as? String
        
        // 获取登录类型（新增字段，可选）
        let senderLoginType = data["senderLoginType"] as? String
        let receiverLoginType = data["receiverLoginType"] as? String
        
        // 获取设备ID和消息类型字段
        let deviceId = data["deviceId"] as? String
        let messageType = data["messageType"] as? String
        
        // 解析时间戳
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.date(from: timestampString) ?? Date()
        
        // 解析消息类型
        let type: MessageType
        switch typeString {
        case "text":
            type = .text
        case "image":
            type = .image
        case "location":
            type = .location
        default:
            type = .text
        }
        
        // 🔧 修复：使用objectId作为消息ID，如果没有objectId则生成UUID
        if let objectId = objectId {
            // 将objectId转换为UUID格式，确保唯一性
            self.id = UUID(uuidString: objectId) ?? UUID()
        } else {
            self.id = UUID()
        }
        self.objectId = objectId
        self.senderId = senderId
        self.senderName = senderName
        self.senderAvatar = senderAvatar
        self.senderLoginType = senderLoginType
        self.receiverId = receiverId
        self.receiverName = receiverName
        self.receiverAvatar = receiverAvatar
        self.receiverLoginType = receiverLoginType
        self.content = content
        self.timestamp = timestamp
        self.isRead = isRead
        self.type = type
        self.deviceId = deviceId
        self.messageType = messageType
        self.isMatch = false // 默认不是匹配消息，需要在消息加载时检测
        
    }
}
