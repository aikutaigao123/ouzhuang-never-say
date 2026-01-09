import Foundation
import LeanCloud

// MARK: - 通知数据模型
struct NotificationItem {
    let message: String
    let isBlacklist: Bool
}

// MARK: - 通知管理扩展
extension LeanCloudService {
    
    // 创建Notifications字段 - ✅ 符合开发指南：使用 LCObject
    func createNotificationsFields(completion: @escaping (Bool) -> Void) {
        // ✅ 按照开发指南：使用 LCObject 创建对象（替代 REST API）
        let notificationRecord = LCObject(className: "Notifications")
        
        do {
            try notificationRecord.set("title", value: "Field Initialization")
            try notificationRecord.set("message", value: "") // message 字段为空
            try notificationRecord.set("isActive", value: true)
            try notificationRecord.set("priority", value: 1)
            try notificationRecord.set("userId", value: "") // userId 字段，为空表示全局通知
            try notificationRecord.set("Blacklist", value: false) // Blacklist 字段，为true时点击同意也退出登录
            
            _ = notificationRecord.save { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        completion(true)
                    case .failure:
                        completion(false)
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                completion(false)
            }
        }
    }
    
    /// 从LeanCloud获取通知内容 - 使用 LCQuery
    /// 查询逻辑：获取全局通知（userId为空）或针对当前用户的通知（userId匹配）
    /// - Parameter completion: 完成回调，返回通知项数组（按优先级：全局通知在前，用户特定通知在后）和错误信息
    func fetchNotificationItems(completion: @escaping ([NotificationItem], String?) -> Void) {
        // 获取当前用户ID
        let currentUserId = UserDefaultsManager.getCurrentUserId() ?? ""
        
        // ✅ 按照开发指南：使用并行查询替代复杂的OR查询
        var globalNotifications: [LCObject] = []
        var userNotifications: [LCObject] = []
        let group = DispatchGroup()
        var hasError = false
        var errorCode: Int? = nil
        
        // 查询1: 全局通知（userId为空字符串）
        group.enter()
        let globalQuery = LCQuery(className: "Notifications")
        globalQuery.whereKey("isActive", .equalTo(true))
        globalQuery.whereKey("userId", .equalTo(""))
        globalQuery.whereKey("createdAt", .descending)
        globalQuery.limit = 1
        globalQuery.find { result in
            switch result {
            case .success(let records):
                globalNotifications.append(contentsOf: records)
            case .failure(let error):
                hasError = true
                errorCode = error.code
            }
            group.leave()
        }
        
        // 查询2: 用户特定通知（userId等于当前用户ID）
        if !currentUserId.isEmpty {
            group.enter()
            let userQuery = LCQuery(className: "Notifications")
            userQuery.whereKey("isActive", .equalTo(true))
            userQuery.whereKey("userId", .equalTo(currentUserId))
            userQuery.whereKey("createdAt", .descending)
            userQuery.limit = 1
            userQuery.find { result in
                switch result {
                case .success(let records):
                    userNotifications.append(contentsOf: records)
                case .failure(let error):
                    if !hasError {
                        hasError = true
                        errorCode = error.code
                    }
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if hasError {
                // 检查是否是 404 错误（表不存在）
                if let code = errorCode, code == 404 {
                    self.createNotificationsTable { tableCreated in
                        if tableCreated {
                            // 表创建成功，再次查询（此时应该为空）
                            self.fetchNotificationItems(completion: completion)
                        } else {
                            completion([], "表创建失败")
                        }
                    }
                } else if let code = errorCode, code == 101 {
                    // 错误代码 101: 权限或认证问题
                    self.createNotificationsTable { tableCreated in
                        if tableCreated {
                            self.fetchNotificationItems(completion: completion)
                        } else {
                            completion([], nil)
                        }
                    }
                } else {
                    // 其他错误，不显示通知
                    completion([], nil)
                }
                return
            }
            
            // 提取通知项，按优先级排序：全局通知在前，用户特定通知在后
            var notificationItems: [NotificationItem] = []
            
            // 先添加全局通知（优先级最高）
            if let globalNotification = globalNotifications.first {
                if let message = globalNotification["message"]?.stringValue, !message.isEmpty {
                    let blacklist = globalNotification["Blacklist"]?.boolValue ?? false
                    notificationItems.append(NotificationItem(message: message, isBlacklist: blacklist))
                }
            }
            
            // 再添加用户特定通知
            if let userNotification = userNotifications.first {
                if let message = userNotification["message"]?.stringValue, !message.isEmpty {
                    let blacklist = userNotification["Blacklist"]?.boolValue ?? false
                    notificationItems.append(NotificationItem(message: message, isBlacklist: blacklist))
                }
            }
            
            completion(notificationItems, nil)
        }
    }
    
    /// 从LeanCloud获取通知内容（兼容旧接口，返回通知消息数组）
    /// - Parameter completion: 完成回调，返回通知消息数组和错误信息
    func fetchNotificationMessages(completion: @escaping ([String], String?) -> Void) {
        fetchNotificationItems { items, error in
            if let error = error {
                completion([], error)
            } else {
                let messages = items.map { $0.message }
                completion(messages, nil)
            }
        }
    }
    
    /// 从LeanCloud获取通知内容（兼容旧接口，返回第一条通知）
    /// - Parameter completion: 完成回调，返回通知消息（如果有）和错误信息
    func fetchNotificationMessage(completion: @escaping (String?, String?) -> Void) {
        fetchNotificationMessages { messages, error in
            if let error = error {
                completion(nil, error)
            } else if let firstMessage = messages.first {
                completion(firstMessage, nil)
            } else {
                completion(nil, nil)
            }
        }
    }
}




