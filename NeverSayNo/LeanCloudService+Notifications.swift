import Foundation
import LeanCloud

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
    /// - Parameter completion: 完成回调，返回通知消息（如果有）和错误信息
    func fetchNotificationMessage(completion: @escaping (String?, String?) -> Void) {
        // ✅ 使用 LCQuery 查询
        let query = LCQuery(className: "Notifications")
        // 只查询激活状态的通知
        query.whereKey("isActive", .equalTo(true))
        // 按创建时间倒序，获取最新的一条
        query.whereKey("createdAt", .descending)
        query.limit = 1
        
        _ = query.find { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let objects):
                    if let firstObject = objects.first {
                        // 只使用 message 字段，如果 message 为空则不显示
                        let message = firstObject["message"]?.stringValue
                        if let message = message, !message.isEmpty {
                            completion(message, nil)
                        } else {
                            // message 字段为空，不显示通知
                            completion(nil, nil)
                        }
                    } else {
                        // 表中没有通知记录
                        completion(nil, nil)
                    }
                case .failure(let error):
                    // 如果是 404 错误（表不存在），尝试创建表
                    if error.code == 404 {
                        self.createNotificationsTable { tableCreated in
                            if tableCreated {
                                // 表创建成功，再次查询（此时应该为空）
                                self.fetchNotificationMessage(completion: completion)
                            } else {
                                completion(nil, "表创建失败")
                            }
                        }
                    } else if error.code == 101 {
                        // 错误代码 101: 权限或认证问题
                        // 尝试创建表（可能需要先创建表结构）
                        self.createNotificationsTable { tableCreated in
                            if tableCreated {
                                self.fetchNotificationMessage(completion: completion)
                            } else {
                                completion(nil, nil)
                            }
                        }
                    } else {
                        // 其他错误，不显示通知
                        completion(nil, nil)
                    }
                }
            }
        }
    }
}




