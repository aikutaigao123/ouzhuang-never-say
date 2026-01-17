import Foundation
import LeanCloud

// MARK: - 通知数据模型
struct NotificationItem {
    let message: String
    let isBlacklist: Bool
}

// MARK: - 版本数据模型
struct VersionItem {
    let version: String           // 版本号，如 "1.0.0"
    let isActive: Bool            // 是否激活
    let minVersion: String?       // 最低支持版本（可选）
    let updateUrl: String?        // 更新链接（可选）
    let updateMessage: String?    // 更新消息（可选）
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
    /// 同时读取Version表
    /// - Parameter completion: 完成回调，返回通知项数组（按优先级：全局通知在前，用户特定通知在后）、版本信息和错误信息
    func fetchNotificationItems(completion: @escaping ([NotificationItem], VersionItem?, String?) -> Void) {
        // 获取当前用户ID
        let currentUserId = UserDefaultsManager.getCurrentUserId() ?? ""
        
        // ✅ 按照开发指南：使用并行查询替代复杂的OR查询
        var globalNotifications: [LCObject] = []
        var userNotifications: [LCObject] = []
        var versionRecords: [LCObject] = []
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
        
        // 查询3: Version表（读取版本信息）
        group.enter()
        let versionQuery = LCQuery(className: "Version")
        versionQuery.whereKey("isActive", .equalTo(true))
        versionQuery.whereKey("createdAt", .descending)
        versionQuery.limit = 1
        versionQuery.find { result in
            switch result {
            case .success(let records):
                versionRecords.append(contentsOf: records)
            case .failure(let error):
                // Version表查询失败不影响通知查询，只记录错误但不设置hasError
                if error.code == 404 {
                    // 表不存在，尝试创建
                    self.createVersionTable { _ in }
                }
            }
            group.leave()
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
                            completion([], nil, "表创建失败")
                        }
                    }
                } else if let code = errorCode, code == 101 {
                    // 错误代码 101: 权限或认证问题
                    self.createNotificationsTable { tableCreated in
                        if tableCreated {
                            self.fetchNotificationItems(completion: completion)
                        } else {
                            completion([], nil, nil)
                        }
                    }
                } else {
                    // 其他错误，不显示通知
                    completion([], nil, nil)
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
            
            // 提取版本信息
            var versionItem: VersionItem? = nil
            if let versionRecord = versionRecords.first {
                let version = versionRecord["version"]?.stringValue ?? ""
                let isActive = versionRecord["isActive"]?.boolValue ?? false
                let minVersion = versionRecord["minVersion"]?.stringValue
                let updateUrl = versionRecord["updateUrl"]?.stringValue
                let updateMessage = versionRecord["updateMessage"]?.stringValue
                
                if !version.isEmpty && isActive {
                    versionItem = VersionItem(
                        version: version,
                        isActive: isActive,
                        minVersion: minVersion,
                        updateUrl: updateUrl,
                        updateMessage: updateMessage
                    )
                }
            }
            
            completion(notificationItems, versionItem, nil)
        }
    }
    
    /// 从LeanCloud获取通知内容（兼容旧接口，返回通知消息数组）
    /// - Parameter completion: 完成回调，返回通知消息数组和错误信息
    func fetchNotificationMessages(completion: @escaping ([String], String?) -> Void) {
        fetchNotificationItems { items, _, error in
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
    
    /// 上传通知到 LeanCloud Notifications 表
    /// - Parameters:
    ///   - message: 通知消息内容，默认为 "Hello World ！"
    ///   - title: 通知标题，默认为 "计时器通知"
    ///   - isActive: 是否激活，默认为 true
    ///   - priority: 优先级，默认为 1
    ///   - userId: 用户ID，空字符串表示全局通知，有值表示针对特定用户的通知
    ///   - blacklist: 黑名单标记，true 表示黑名单通知（点击同意会退出登录），false 表示正常通知
    ///   - completion: 完成回调，返回是否成功、错误消息和 objectId
    func uploadNotification(
        message: String = "Hello World ！",
        title: String = "计时器通知",
        isActive: Bool = true,
        priority: Int = 1,
        userId: String = "",
        blacklist: Bool = false,
        completion: @escaping (Bool, String?, String?) -> Void
    ) {
        let urlString = "\(serverUrl)/1.1/classes/Notifications"
        guard let url = URL(string: urlString) else {
            completion(false, "URL创建失败: \(urlString)", nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 设置 LeanCloud 请求头
        setLeanCloudHeaders(&request, contentType: "application/json")
        
        // 增加超时时间
        request.timeoutInterval = 60.0
        
        // 设置网络服务类型
        request.networkServiceType = .default
        
        // 构建请求数据
        var requestData: [String: Any] = [
            "title": title,
            "message": message,
            "isActive": isActive,
            "priority": priority
        ]
        
        // 添加 userId 字段（可以为空字符串表示全局通知）
        requestData["userId"] = userId
        
        // 添加 Blacklist 字段（布尔值）
        requestData["Blacklist"] = blacklist
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestData)
            request.httpBody = jsonData
            
            // 使用 URLSession 发送请求
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 60.0
            config.timeoutIntervalForResource = 120.0
            config.waitsForConnectivity = true
            config.allowsCellularAccess = true
            config.isDiscretionary = false
            config.networkServiceType = .default
            
            let session = URLSession(configuration: config)
            
            let task = session.dataTask(with: request) { data, response, error in
                if let error = error {
                    DispatchQueue.main.async {
                        completion(false, "网络错误: \(error.localizedDescription)", nil)
                    }
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    DispatchQueue.main.async {
                        completion(false, "无效的响应", nil)
                    }
                    return
                }
                
                if httpResponse.statusCode == 201 || httpResponse.statusCode == 200 {
                    // 解析返回的 objectId
                    var objectId: String? = nil
                    if let responseData = data {
                        do {
                            if let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                               let id = json["objectId"] as? String {
                                objectId = id
                            }
                        } catch {
                        }
                    }
                    DispatchQueue.main.async {
                        completion(true, nil, objectId)
                    }
                } else {
                    var errorMessage = "HTTP错误: \(httpResponse.statusCode)"
                    if let responseData = data,
                       let errorJson = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                       let errorCode = errorJson["code"] as? Int,
                       let errorDesc = errorJson["error"] as? String {
                        errorMessage = "错误代码: \(errorCode), 错误消息: \(errorDesc)"
                    }
                    DispatchQueue.main.async {
                        completion(false, errorMessage, nil)
                    }
                }
            }
            
            task.resume()
        } catch {
            completion(false, "JSON序列化失败: \(error.localizedDescription)", nil)
        }
    }
    
    // MARK: - Version表管理
    
    /// 创建Version表
    func createVersionTable(completion: @escaping (Bool) -> Void) {
        // 通过插入一条测试记录来创建表
        let testData: [String: Any] = [
            "version": "1.0.0",           // 版本号
            "isActive": true,              // 是否激活
            "minVersion": "1.0.0",        // 最低支持版本（可选）
            "updateUrl": "",              // 更新链接（可选）
            "updateMessage": ""           // 更新消息（可选）
        ]
        
        let urlString = "\(serverUrl)/1.1/classes/Version"
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: testData)
            request.httpBody = jsonData
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if error != nil {
                    completion(false)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false)
                    return
                }
                
                if httpResponse.statusCode == 201 {
                    completion(true)
                } else {
                    completion(false)
                }
            }.resume()
            
        } catch {
            completion(false)
        }
    }
    
    /// 创建Version字段 - ✅ 符合开发指南：使用 LCObject
    func createVersionFields(completion: @escaping (Bool) -> Void) {
        // ✅ 按照开发指南：使用 LCObject 创建对象（替代 REST API）
        let versionRecord = LCObject(className: "Version")
        
        do {
            try versionRecord.set("version", value: "1.0.0")
            try versionRecord.set("isActive", value: true)
            try versionRecord.set("minVersion", value: "1.0.0")
            try versionRecord.set("updateUrl", value: "")
            try versionRecord.set("updateMessage", value: "")
            
            _ = versionRecord.save { result in
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
    
    /// 从LeanCloud获取版本信息 - 使用 LCQuery
    /// - Parameter completion: 完成回调，返回版本信息和错误信息
    func fetchVersionItem(completion: @escaping (VersionItem?, String?) -> Void) {
        let versionQuery = LCQuery(className: "Version")
        versionQuery.whereKey("isActive", .equalTo(true))
        versionQuery.whereKey("createdAt", .descending)
        versionQuery.limit = 1
        
        versionQuery.find { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let records):
                    if let versionRecord = records.first {
                        let version = versionRecord["version"]?.stringValue ?? ""
                        let isActive = versionRecord["isActive"]?.boolValue ?? false
                        let minVersion = versionRecord["minVersion"]?.stringValue
                        let updateUrl = versionRecord["updateUrl"]?.stringValue
                        let updateMessage = versionRecord["updateMessage"]?.stringValue
                        
                        if !version.isEmpty && isActive {
                            let versionItem = VersionItem(
                                version: version,
                                isActive: isActive,
                                minVersion: minVersion,
                                updateUrl: updateUrl,
                                updateMessage: updateMessage
                            )
                            completion(versionItem, nil)
                        } else {
                            completion(nil, nil)
                        }
                    } else {
                        completion(nil, nil)
                    }
                case .failure(let error):
                    // 检查是否是 404 错误（表不存在）
                    if error.code == 404 {
                        self.createVersionTable { tableCreated in
                            if tableCreated {
                                // 表创建成功，再次查询（此时应该为空）
                                self.fetchVersionItem(completion: completion)
                            } else {
                                completion(nil, "表创建失败")
                            }
                        }
                    } else if error.code == 101 {
                        // 错误代码 101: 权限或认证问题
                        self.createVersionTable { tableCreated in
                            if tableCreated {
                                self.fetchVersionItem(completion: completion)
                            } else {
                                completion(nil, nil)
                            }
                        }
                    } else {
                        completion(nil, nil)
                    }
                }
            }
        }
    }
    
    /// 上传版本信息到 LeanCloud Version 表
    /// - Parameters:
    ///   - version: 版本号，如 "1.0.0"
    ///   - isActive: 是否激活，默认为 true
    ///   - minVersion: 最低支持版本（可选）
    ///   - updateUrl: 更新链接（可选）
    ///   - updateMessage: 更新消息（可选）
    ///   - completion: 完成回调，返回是否成功、错误消息和 objectId
    func uploadVersion(
        version: String,
        isActive: Bool = true,
        minVersion: String? = nil,
        updateUrl: String? = nil,
        updateMessage: String? = nil,
        completion: @escaping (Bool, String?, String?) -> Void
    ) {
        let urlString = "\(serverUrl)/1.1/classes/Version"
        guard let url = URL(string: urlString) else {
            completion(false, "URL创建失败: \(urlString)", nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 设置 LeanCloud 请求头
        setLeanCloudHeaders(&request, contentType: "application/json")
        
        // 增加超时时间
        request.timeoutInterval = 60.0
        
        // 构建请求数据
        var requestData: [String: Any] = [
            "version": version,
            "isActive": isActive
        ]
        
        // 添加可选字段
        if let minVersion = minVersion {
            requestData["minVersion"] = minVersion
        }
        if let updateUrl = updateUrl {
            requestData["updateUrl"] = updateUrl
        }
        if let updateMessage = updateMessage {
            requestData["updateMessage"] = updateMessage
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestData)
            request.httpBody = jsonData
            
            // 使用 URLSession 发送请求
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 60.0
            config.timeoutIntervalForResource = 120.0
            config.waitsForConnectivity = true
            config.allowsCellularAccess = true
            config.isDiscretionary = false
            config.networkServiceType = .default
            
            let session = URLSession(configuration: config)
            
            let task = session.dataTask(with: request) { data, response, error in
                if let error = error {
                    DispatchQueue.main.async {
                        completion(false, "网络错误: \(error.localizedDescription)", nil)
                    }
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    DispatchQueue.main.async {
                        completion(false, "无效的响应", nil)
                    }
                    return
                }
                
                if httpResponse.statusCode == 201 || httpResponse.statusCode == 200 {
                    // 解析返回的 objectId
                    var objectId: String? = nil
                    if let responseData = data {
                        do {
                            if let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                               let id = json["objectId"] as? String {
                                objectId = id
                            }
                        } catch {
                        }
                    }
                    DispatchQueue.main.async {
                        completion(true, nil, objectId)
                    }
                } else {
                    var errorMessage = "HTTP错误: \(httpResponse.statusCode)"
                    if let responseData = data,
                       let errorJson = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                       let errorCode = errorJson["code"] as? Int,
                       let errorDesc = errorJson["error"] as? String {
                        errorMessage = "错误代码: \(errorCode), 错误消息: \(errorDesc)"
                    }
                    DispatchQueue.main.async {
                        completion(false, errorMessage, nil)
                    }
                }
            }
            
            task.resume()
        } catch {
            completion(false, "JSON序列化失败: \(error.localizedDescription)", nil)
        }
    }
}




