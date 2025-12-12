//
//  LeanCloudService+Message.swift
//  NeverSayNo
//
//  Created by AI Assistant on 2024-12-19.
//

import Foundation
import UIKit
import CoreLocation
import LeanCloud

// MARK: - 消息管理扩展
extension LeanCloudService {
    
    // MARK: - 消息发送
    
    /// 发送拍一拍消息（带位置上传功能）
    func sendPatMessage(fromUserId: String, toUserId: String, fromUserName: String, toUserName: String, locationManager: LocationManager? = nil, userLoginType: String? = nil, userEmail: String? = nil, userAvatar: String? = nil, completion: @escaping (Bool) -> Void) {
        
        
        let messageData: [String: Any] = [
            "senderId": fromUserId,
            "senderName": fromUserName,
            "senderAvatar": "", // 拍一拍消息不需要头像
            "senderLoginType": "pat", // 拍一拍类型
            "receiverId": toUserId,
            "receiverName": toUserName,
            "receiverAvatar": "",
            "receiverLoginType": "pat",
            "content": "\(fromUserName) 拍了拍 \(toUserName)",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "isRead": false,
            "type": "text",
            "messageType": "pat",
            "deviceId": UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            "status": "active"
        ]
        
        for (_, _) in messageData.sorted(by: { $0.key < $1.key }) {
        }
        
        // 发送消息
        sendMessage(messageData: messageData) { messageSuccess, errorMessage in
            
            if !messageSuccess {
            } else {
                // 注意：通知应该在对方收到消息时触发，而不是发送时
            }
            
            // 消息发送成功后，上传位置信息到LocationRecord表
            if messageSuccess {
                
                // 获取当前位置并上传
                self.getCurrentLocationAndUpload(
                    userId: fromUserId,
                    userName: fromUserName,
                    loginType: userLoginType ?? "unknown",
                    userEmail: userEmail,
                    userAvatar: userAvatar
                ) { locationSuccess in
                    // 位置上传成功与否不影响拍一拍消息的发送结果
                    completion(messageSuccess)
                }
            } else {
                completion(messageSuccess)
            }
        }
    }
    
    /// 发送拍一拍时的位置信息
    /// - 重要法律说明：
    ///   根据《中华人民共和国测绘法》第四十二条规定：
    ///   "互联网地图服务提供者应当使用经依法审核批准的地理信息，不得使用未经审核批准的地理信息。"
    ///   因此，本方法必须将 GPS 原始坐标（WGS-84）转换为国家标准坐标系（GCJ-02）后再进行存储和传输。
    ///
    /// - 技术说明：
    ///   1. iOS CoreLocation 返回的坐标是 WGS-84 坐标系（国际标准）
    ///   2. 中国法律要求使用 GCJ-02 坐标系（国测局坐标系/火星坐标系）
    ///   3. 直接存储或显示 WGS-84 坐标在中国境内违法
    ///   4. 必须通过 CoordinateConverter 进行坐标转换
    ///
    /// - Parameters:
    ///   - location: 包含 WGS-84 坐标的 CLLocation 对象
    ///   - userId: 用户ID
    ///   - userName: 用户名
    ///   - loginType: 登录类型
    ///   - userEmail: 用户邮箱（可选）
    ///   - userAvatar: 用户头像（可选）
    ///   - completion: 完成回调
    private func sendPatLocation(location: CLLocation, userId: String, userName: String, loginType: String, userEmail: String?, userAvatar: String?, completion: @escaping (Bool) -> Void) {
        
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        let tzID = TimeZone.current.identifier
        let deviceTime = ISO8601DateFormatter().string(from: Date())
        
        // ⚖️ 法律合规：将 WGS-84 坐标转换为 GCJ-02 坐标
        // 根据《测绘法》要求，不得直接使用 location.coordinate.latitude/longitude（WGS-84）
        // 必须转换为 GCJ-02 坐标系后才能存储到服务器
        let (gcjLat, gcjLon) = CoordinateConverter.wgs84ToGcj02(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        
        // 使用与寻找按钮一致的头像处理逻辑
        if let avatar = userAvatar, !avatar.isEmpty {
            // 有头像，直接使用
            // ⚖️ 法律合规：使用转换后的 GCJ-02 坐标（gcjLat, gcjLon）
            // ❌ 禁止使用：location.coordinate.latitude, location.coordinate.longitude（WGS-84）
            let locationData: [String: Any] = [
                "latitude": gcjLat,
                "longitude": gcjLon,
                "accuracy": location.horizontalAccuracy,
                "userId": userId,
                "userName": userName,
                "loginType": loginType,
                "userEmail": userEmail ?? "",
                "userAvatar": avatar,
                "deviceId": deviceID,
                "timezone": tzID,
                "deviceTime": deviceTime,
                "likeCount": 0
            ]
            
            for (_, _) in locationData.sorted(by: { $0.key < $1.key }) {
            }
            
            sendLocation(locationData: locationData) { success, _ in
                if success {
                } else {
                }
                completion(success)
            }
        } else {
            // 没有头像，使用默认头像（取消UserAvatarRecord表上传）
            let defaultAvatar = UserAvatarUtils.defaultAvatar(for: loginType)
            // ⚖️ 法律合规：使用转换后的 GCJ-02 坐标（gcjLat, gcjLon）
            // ❌ 禁止使用：location.coordinate.latitude, location.coordinate.longitude（WGS-84）
            let locationData: [String: Any] = [
                "latitude": gcjLat,
                "longitude": gcjLon,
                "accuracy": location.horizontalAccuracy,
                "userId": userId,
                "userName": userName,
                "loginType": loginType,
                "userEmail": userEmail ?? "",
                "userAvatar": defaultAvatar,
                "deviceId": deviceID,
                "timezone": tzID,
                "deviceTime": deviceTime,
                "likeCount": 0
            ]
            
            self.sendLocation(locationData: locationData) { success, _ in
                if success {
                } else {
                }
                completion(success)
            }
        }
    }
    
    /// 发送消息到LeanCloud（带重复检查）
    func sendMessage(messageData: [String: Any], completion: @escaping (Bool, String) -> Void) {
        
        // 添加消息发送调试信息
        for (_, _) in messageData {
        }
        
        // 检查是否已存在相同的消息（防重复）
        checkDuplicateMessage(messageData: messageData) { isDuplicate in
            if isDuplicate {
                completion(false, "消息已存在，跳过发送")
                return
            }
            
            // 发送消息
            self.uploadMessageToLeanCloud(messageData: messageData, completion: completion)
        }
    }
    
    /// 检查是否存在重复消息 - 遵循数据存储开发指南，使用 LCQuery
    private func checkDuplicateMessage(messageData: [String: Any], completion: @escaping (Bool) -> Void) {
        guard let senderId = messageData["senderId"] as? String,
              let receiverId = messageData["receiverId"] as? String,
              let messageType = messageData["messageType"] as? String else {
            completion(false)
            return
        }
        
        // ✅ 按照开发指南：使用 LCQuery 创建查询
        let query = LCQuery(className: "Message")
        query.whereKey("senderId", .equalTo(senderId))
        query.whereKey("receiverId", .equalTo(receiverId))
        query.whereKey("messageType", .equalTo(messageType))
        query.whereKey("status", .equalTo("active"))
        
        // 检查最近5分钟内是否有相同的消息
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        query.whereKey("createdAt", .greaterThanOrEqualTo(fiveMinutesAgo))
        
        query.limit = 1
        
        query.find { result in
            switch result {
            case .success(let records):
                let isDuplicate = !records.isEmpty
                completion(isDuplicate)
            case .failure:
                completion(false)
            }
        }
    }
    
    /// 上传消息到LeanCloud
    private func uploadMessageToLeanCloud(messageData: [String: Any], completion: @escaping (Bool, String) -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/Message"
        guard let url = URL(string: urlString) else {
            completion(false, "无效的URL")
            return
        }
        
        for (_, _) in messageData {
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 5.0 // 减少超时时间，提高响应速度
        
        // 添加ACL权限
        let messageDataWithACL = addACLToData(messageData)
        for (_, _) in messageDataWithACL {
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: messageDataWithACL)
            request.httpBody = jsonData
            
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    // 网络错误
                    completion(false, "网络错误: \(error.localizedDescription)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false, "无效的响应")
                    return
                }
                
                
                if httpResponse.statusCode == 201 {
                    // 消息发送成功
                    completion(true, "消息发送成功")
                } else {
                    // 服务器错误
                    let errorMessage = "服务器错误: \(httpResponse.statusCode)"
                    completion(false, errorMessage)
                }
            }.resume()
            
        } catch {
            // JSON序列化错误
            completion(false, "数据格式错误")
        }
    }
    
    /// 编码查询条件为URL参数
    private func encodeWhereCondition(_ condition: [String: Any]) -> String {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: condition)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            return jsonString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "{}"
        } catch {
            return "{}"
        }
    }
    
    // MARK: - 消息获取
    
    /// 从LeanCloud获取消息（获取所有历史消息）
    func fetchMessages(userId: String, completion: @escaping ([MessageItem]?, String?) -> Void) {
        // 使用分页查询获取所有消息
        fetchAllMessagesWithPagination(userId: userId, completion: completion)
    }
    
    /// 分页查询所有消息 - 使用组合条件（简化版）
    private func fetchAllMessagesWithPagination(userId: String, completion: @escaping ([MessageItem]?, String?) -> Void) {
        // 由于LeanCloud Swift SDK对复杂OR/AND查询支持有限，简化查询逻辑
        // 查询接收者是当前用户的消息
        var allRecords: [LCObject] = []
        let group = DispatchGroup()
        
        // 查询1: 接收者是当前用户
        group.enter()
        let receiverQuery = LCQuery(className: "Message")
        receiverQuery.whereKey("receiverId", .equalTo(userId))
        receiverQuery.whereKey("timestamp", .descending)
        receiverQuery.limit = 1000
        receiverQuery.find { result in
            switch result {
            case .success(let records):
                allRecords.append(contentsOf: records)
            case .failure:
                break
            }
            group.leave()
        }
        
        // 查询2: 发送者是当前用户
        group.enter()
        let senderQuery = LCQuery(className: "Message")
        senderQuery.whereKey("senderId", .equalTo(userId))
        senderQuery.whereKey("timestamp", .descending)
        senderQuery.limit = 1000
        senderQuery.find { result in
            switch result {
            case .success(let records):
                allRecords.append(contentsOf: records)
            case .failure:
                break
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            // 去重并过滤状态
            var uniqueMessages: [MessageItem] = []
            var seenIds = Set<String>()
            
            for record in allRecords {
                guard let objectId = record.objectId?.stringValue,
                      !seenIds.contains(objectId) else {
                    continue
                }
                seenIds.insert(objectId)
                
                // 检查状态
                let status = record["status"]?.stringValue ?? "active"
                if status == "active" || status == "deleted" {
                    // 🔧 修复：手动构建字典，因为LCObject没有dictionaryValue属性
                    var messageData: [String: Any] = [:]
                    messageData["objectId"] = objectId
                    messageData["senderId"] = record["senderId"]?.stringValue ?? ""
                    messageData["senderName"] = record["senderName"]?.stringValue ?? ""
                    messageData["senderAvatar"] = record["senderAvatar"]?.stringValue ?? ""
                    messageData["senderLoginType"] = record["senderLoginType"]?.stringValue
                    messageData["receiverId"] = record["receiverId"]?.stringValue ?? ""
                    messageData["receiverName"] = record["receiverName"]?.stringValue ?? ""
                    messageData["receiverAvatar"] = record["receiverAvatar"]?.stringValue ?? ""
                    messageData["receiverLoginType"] = record["receiverLoginType"]?.stringValue
                    messageData["content"] = record["content"]?.stringValue ?? ""
                    // 🔧 修复：如果timestamp为空，使用createdAt作为后备
                    if let timestamp = record["timestamp"]?.stringValue, !timestamp.isEmpty {
                        messageData["timestamp"] = timestamp
                    } else if let createdAt = record.createdAt?.value {
                        let formatter = ISO8601DateFormatter()
                        messageData["timestamp"] = formatter.string(from: createdAt)
                    } else {
                        messageData["timestamp"] = ISO8601DateFormatter().string(from: Date())
                    }
                    messageData["isRead"] = record["isRead"]?.boolValue ?? false
                    messageData["type"] = record["type"]?.stringValue ?? "text"
                    messageData["deviceId"] = record["deviceId"]?.stringValue
                    messageData["messageType"] = record["messageType"]?.stringValue
                    
                    if let message = self.parseMessageFromData(messageData) {
                        uniqueMessages.append(message)
                    }
                }
            }
            
            
            // 按时间排序
            uniqueMessages.sort { msg1, msg2 in
                msg1.timestamp > msg2.timestamp
            }
            
            completion(uniqueMessages, nil)
        }
    }
    
    /// 解析消息数据
    private func parseMessageFromData(_ data: [String: Any]) -> MessageItem? {
        return MessageItem(fromLeanCloudData: data)
    }
    
    // MARK: - 消息状态管理
    
    /// 标记消息为已读
    func markMessageAsRead(messageId: String, completion: @escaping (Bool) -> Void) {
        
        
        let urlString = "\(serverUrl)/1.1/classes/Message/\(messageId)"
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        setLeanCloudHeaders(&request, contentType: "application/json")
        request.timeoutInterval = 10.0
        
        let updateData = ["isRead": true]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: updateData)
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
                
                
                if httpResponse.statusCode == 200 {
                    completion(true)
                } else {
                    completion(false)
                }
            }.resume()
            
        } catch {
            completion(false)
        }
    }
    
    /// 获取消息的已读状态（用于验证）
    func fetchMessageReadStatus(messageId: String, completion: @escaping (Bool?) -> Void) {
        
        let urlString = "\(serverUrl)/1.1/classes/Message/\(messageId)?keys=isRead,content,senderId,receiverId"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                completion(nil)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(nil)
                return
            }
            
            if httpResponse.statusCode == 200 {
                if let data = data {
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            let isRead = json["isRead"] as? Bool ?? false
                            completion(isRead)
                        } else {
                            completion(nil)
                        }
                    } catch {
                        completion(nil)
                    }
                } else {
                    completion(nil)
                }
            } else {
                completion(nil)
            }
        }.resume()
    }
    
    /// 删除消息（使用状态字段，不删除记录）
    func deleteMessage(messageId: String, completion: @escaping (Bool) -> Void) {
        
        // 直接更新消息状态为deleted
        updateMessageStatus(messageId: messageId, status: "deleted", completion: completion)
    }
    
    /// 删除两个用户之间的所有相关消息 - 遵循数据存储开发指南，使用 LCQuery
    func deleteAllMessagesBetweenUsers(senderId: String, receiverId: String, completion: @escaping (Bool, String?) -> Void) {
        // ✅ 按照开发指南：使用 LCQuery 创建查询
        let query = LCQuery(className: "Message")
        query.whereKey("senderId", .equalTo(senderId))
        query.whereKey("receiverId", .equalTo(receiverId))
        query.whereKey("status", .equalTo("active"))
        query.limit = 1000
        
        query.find { result in
            switch result {
            case .success(let records):
                // 转换结果
                let results = records.compactMap { record -> [String: Any]? in
                    guard let objectId = record.objectId?.stringValue else { return nil }
                    var dict: [String: Any] = [:]
                    dict["objectId"] = objectId
                    dict["senderId"] = record["senderId"]?.stringValue ?? ""
                    dict["receiverId"] = record["receiverId"]?.stringValue ?? ""
                    dict["content"] = record["content"]?.stringValue ?? ""
                    dict["messageType"] = record["messageType"]?.stringValue ?? ""
                    return dict
                }
                
                // 开始删除消息
                if results.isEmpty {
                    completion(true, nil)
                    return
                }
                
                // 打印找到的消息详情
                for (_, _) in results.enumerated() {
                }
                
                // 智能批量删除策略
                let group = DispatchGroup()
                var successCount = 0
                var failureCount = 0
                
                // 如果消息数量较少（<=5条），并行删除；否则使用延迟策略
                let shouldUseDelay = results.count > 5
                
                for (index, messageData) in results.enumerated() {
                    if let messageId = messageData["objectId"] as? String {
                        group.enter()
                        
                        if shouldUseDelay {
                            // 大量消息时使用延迟策略，避免API频率限制
                            let delay = Double(index) * 0.05 // 每个请求间隔50ms
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                self.updateMessageStatus(messageId: messageId, status: "deleted") { success in
                                    if success {
                                        successCount += 1
                                    } else {
                                        failureCount += 1
                                    }
                                    group.leave()
                                }
                            }
                        } else {
                            // 少量消息时并行删除，提高速度
                            self.updateMessageStatus(messageId: messageId, status: "deleted") { success in
                                if success {
                                    successCount += 1
                                } else {
                                    failureCount += 1
                                }
                                group.leave()
                            }
                        }
                    }
                }
                
                group.notify(queue: .main) {
                    completion(successCount > 0, failureCount > 0 ? "部分消息删除失败" : nil)
                }
                
            case .failure(let error):
                completion(false, "查询失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 根据发送者和接收者删除消息
    func deleteMessage(senderId: String, receiverId: String, completion: @escaping (Bool, String?) -> Void) {
        // 先查询消息ID
        let urlString = "\(serverUrl)/1.1/classes/Message"
        guard let url = URL(string: urlString) else {
            completion(false, "无效的URL")
            return
        }
        
        // 构建查询条件
        let query = [
            "senderId": senderId,
            "receiverId": receiverId,
            "status": "active"
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        // 添加查询参数
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        
        // 将查询条件转换为JSON字符串
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: query)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            
            components?.queryItems = [
                URLQueryItem(name: "where", value: jsonString)
            ]
        } catch {
            completion(false, "查询条件序列化失败")
            return
        }
        
        guard let finalURL = components?.url else {
            completion(false, "查询URL构建失败")
            return
        }
        
        request.url = finalURL
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                completion(false, "网络错误")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false, "无效的响应")
                return
            }
            
            if httpResponse.statusCode == 200 {
                do {
                    if let data = data,
                       let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let results = json["results"] as? [[String: Any]] {
                        
                        if let firstMessage = results.first,
                           let messageId = firstMessage["objectId"] as? String {
                            
                            // 找到消息，更新状态为deleted
                            self.updateMessageStatus(messageId: messageId, status: "deleted") { success in
                                completion(success, success ? nil : "状态更新失败")
                            }
                        } else {
                            // 没有找到消息
                            completion(true, nil) // 认为删除成功，因为消息不存在
                        }
                    } else {
                        completion(false, "数据格式错误")
                    }
                } catch {
                    completion(false, "数据解析错误")
                }
            } else {
                completion(false, "服务器错误: \(httpResponse.statusCode)")
            }
        }.resume()
    }
    
    /// 更新消息状态
    private func updateMessageStatus(messageId: String, status: String, completion: @escaping (Bool) -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/Message/\(messageId)"
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        setLeanCloudHeaders(&request, contentType: "application/json")
        request.timeoutInterval = 10.0
        
        let updateData = ["status": status]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: updateData)
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
                
                if httpResponse.statusCode == 200 {
                    completion(true)
                } else {
                    completion(false)
                }
            }.resume()
            
        } catch {
            completion(false)
        }
    }
    
    /// 直接获取当前位置并上传（用于拍一拍按钮）
    private func getCurrentLocationAndUpload(userId: String, userName: String, loginType: String, userEmail: String?, userAvatar: String?, completion: @escaping (Bool) -> Void) {
        // 创建一个临时的位置管理器来获取位置
        let tempLocationManager = CLLocationManager()
        tempLocationManager.requestWhenInUseAuthorization()
        
        // 尝试获取位置
        if let location = tempLocationManager.location {
            // 有位置信息，使用与寻找按钮一致的头像处理逻辑
            if let avatar = userAvatar, !avatar.isEmpty {
                // 有头像，直接上传
                sendPatLocation(
                    location: location,
                    userId: userId,
                    userName: userName,
                    loginType: loginType,
                    userEmail: userEmail,
                    userAvatar: avatar,
                    completion: completion
                )
            } else {
                // 没有头像，使用默认头像（取消UserAvatarRecord表上传）
                let defaultAvatar = UserAvatarUtils.defaultAvatar(for: loginType)
                self.sendPatLocation(
                    location: location,
                    userId: userId,
                    userName: userName,
                    loginType: loginType,
                    userEmail: userEmail,
                    userAvatar: defaultAvatar,
                    completion: completion
                )
            }
        } else {
            // 没有位置信息，直接返回失败
            completion(false)
        }
    }
}
