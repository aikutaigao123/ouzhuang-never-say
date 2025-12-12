import Foundation

/**
 * 好友申请数据模型
 */
struct FriendshipRequest {
    let objectId: String
    let user: UserInfo
    let friend: UserInfo
    let status: String // pending, accepted, declined
    let createdAt: Date
    let updatedAt: Date
    
    init?(from data: [String: Any]) {
        guard let objectId = data["objectId"] as? String,
              let status = data["status"] as? String else {
            return nil
        }
        
        self.objectId = objectId
        self.status = status
        
        // 🎯 新增：详细日志，查看服务器返回的原始时间数据
        
        // 解析时间 - 支持多种格式
        var createdAt: Date?
        var updatedAt: Date?
        
        // 尝试解析 createdAt
        if let createdAtString = data["createdAt"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            createdAt = formatter.date(from: createdAtString)
            if createdAt == nil {
                let formatterWithoutFractional = ISO8601DateFormatter()
                formatterWithoutFractional.formatOptions = [.withInternetDateTime]
                createdAt = formatterWithoutFractional.date(from: createdAtString)
            }
            if createdAt == nil {
                createdAt = Date()
            } else {
            }
        } else if let createdAtDict = data["createdAt"] as? [String: Any],
                  let createdAtString = createdAtDict["iso"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            createdAt = formatter.date(from: createdAtString)
            if createdAt == nil {
                let formatterWithoutFractional = ISO8601DateFormatter()
                formatterWithoutFractional.formatOptions = [.withInternetDateTime]
                createdAt = formatterWithoutFractional.date(from: createdAtString)
            }
            if createdAt == nil {
                createdAt = Date()
            } else {
            }
        } else {
            createdAt = Date()
        }
        
        // 尝试解析 updatedAt
        if let updatedAtString = data["updatedAt"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            updatedAt = formatter.date(from: updatedAtString)
            if updatedAt == nil {
                let formatterWithoutFractional = ISO8601DateFormatter()
                formatterWithoutFractional.formatOptions = [.withInternetDateTime]
                updatedAt = formatterWithoutFractional.date(from: updatedAtString)
            }
            if updatedAt == nil {
                updatedAt = Date()
            } else {
            }
        } else if let updatedAtDict = data["updatedAt"] as? [String: Any],
                  let updatedAtString = updatedAtDict["iso"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            updatedAt = formatter.date(from: updatedAtString)
            if updatedAt == nil {
                let formatterWithoutFractional = ISO8601DateFormatter()
                formatterWithoutFractional.formatOptions = [.withInternetDateTime]
                updatedAt = formatterWithoutFractional.date(from: updatedAtString)
            }
            if updatedAt == nil {
                updatedAt = Date()
            } else {
            }
        } else {
            updatedAt = Date()
        }
        
        self.createdAt = createdAt ?? Date()
        self.updatedAt = updatedAt ?? Date()
        
        // 解析用户信息
        if let userData = data["user"] as? [String: Any] {
            let userObjectId = userData["objectId"] as? String ?? ""
            let username = userData["username"] as? String ?? ""
            // 🎯 修改：不再使用 _FriendshipRequest 表的 user.displayName，使用空字符串作为占位符
            // 真实的用户名应该从 UserNameRecord 表获取，而不是从 _FriendshipRequest 表的 user.displayName
            let inferredLoginType: UserInfo.LoginType
            if username.hasPrefix("guest_") {
                inferredLoginType = .guest
            } else if userData["_authData_apple"] != nil {
                inferredLoginType = .apple
            } else {
                inferredLoginType = .guest
            }
            self.user = UserInfo(
                id: userObjectId,
                userId: userObjectId.isEmpty ? username : userObjectId,
                fullName: "",  // 🎯 修改：使用空字符串，不从 _FriendshipRequest 表的 user.displayName 获取
                email: userData["email"] as? String,
                loginType: inferredLoginType
            )
        } else {
            return nil
        }
        
        if let friendData = data["friend"] as? [String: Any] {
            let friendObjectId = friendData["objectId"] as? String ?? ""
            let friendUsername = friendData["username"] as? String ?? ""
            // 🎯 修改：不再使用 _FriendshipRequest 表的 friend.displayName，使用空字符串作为占位符
            // 真实的用户名应该从 UserNameRecord 表获取，而不是从 _FriendshipRequest 表的 friend.displayName
            let inferredLoginType: UserInfo.LoginType
            if friendUsername.hasPrefix("guest_") {
                inferredLoginType = .guest
            } else if friendData["_authData_apple"] != nil {
                inferredLoginType = .apple
            } else {
                inferredLoginType = .guest
            }
            self.friend = UserInfo(
                id: friendObjectId,
                userId: friendObjectId.isEmpty ? friendUsername : friendObjectId,
                fullName: "",  // 🎯 修改：使用空字符串，不从 _FriendshipRequest 表的 friend.displayName 获取
                email: friendData["email"] as? String,
                loginType: inferredLoginType
            )
        } else {
            return nil
        }
    }
}

