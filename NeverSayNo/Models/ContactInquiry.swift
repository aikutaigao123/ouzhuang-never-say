import Foundation

/**
 * 询问联系方式是否真实数据模型
 */
struct ContactInquiry {
    let objectId: String
    let inquirer: UserInfo  // 询问者（发送询问的用户）
    let targetUser: UserInfo  // 被询问者（接收询问的用户）
    let status: String // pending, replied
    let createdAt: Date
    let updatedAt: Date
    
    init?(from data: [String: Any]) {
        guard let objectId = data["objectId"] as? String,
              let status = data["status"] as? String else {
            return nil
        }
        
        self.objectId = objectId
        self.status = status
        
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
            }
        } else {
            updatedAt = Date()
        }
        
        self.createdAt = createdAt ?? Date()
        self.updatedAt = updatedAt ?? Date()
        
        // 解析询问者信息
        if let inquirerData = data["inquirer"] as? [String: Any] {
            let inquirerObjectId = inquirerData["objectId"] as? String ?? ""
            let inquirerUsername = inquirerData["username"] as? String ?? ""
            let inferredLoginType: UserInfo.LoginType
            if inquirerUsername.hasPrefix("guest_") {
                inferredLoginType = .guest
            } else if inquirerData["_authData_apple"] != nil {
                inferredLoginType = .apple
            } else {
                inferredLoginType = .guest
            }
            self.inquirer = UserInfo(
                id: inquirerObjectId,
                userId: inquirerObjectId.isEmpty ? inquirerUsername : inquirerObjectId,
                fullName: "",
                email: inquirerData["email"] as? String,
                loginType: inferredLoginType
            )
        } else {
            return nil
        }
        
        // 解析被询问者信息
        if let targetUserData = data["targetUser"] as? [String: Any] {
            let targetUserObjectId = targetUserData["objectId"] as? String ?? ""
            let targetUserUsername = targetUserData["username"] as? String ?? ""
            let inferredLoginType: UserInfo.LoginType
            if targetUserUsername.hasPrefix("guest_") {
                inferredLoginType = .guest
            } else if targetUserData["_authData_apple"] != nil {
                inferredLoginType = .apple
            } else {
                inferredLoginType = .guest
            }
            self.targetUser = UserInfo(
                id: targetUserObjectId,
                userId: targetUserObjectId.isEmpty ? targetUserUsername : targetUserObjectId,
                fullName: "",
                email: targetUserData["email"] as? String,
                loginType: inferredLoginType
            )
        } else {
            return nil
        }
    }
}
