//
//  LeanCloudService+RecommendationTable.swift
//  NeverSayNo
//
//  Created by AI Assistant.
//

import Foundation
import LeanCloud

// MARK: - Recommendation表管理扩展
extension LeanCloudService {
    
    /// 创建Recommendation表
    func createRecommendationTable(completion: @escaping (Bool) -> Void) {
        // 通过插入一条测试记录来创建表
        let testData: [String: Any] = [
            "latitude": 0.0,
            "longitude": 0.0,
            "accuracy": 0.0,
            "userId": "test_user",
            "userName": "测试用户",
            "loginType": "test",
            "userEmail": "test@example.com",
            "userAvatar": "person.circle",
            "deviceId": "test_device",
            "deviceTime": ISO8601DateFormatter().string(from: Date()),
            "timezone": "Asia/Shanghai",
            "status": "active",
            "likeCount": 0,
            "address": "",
            "placeName": "测试地名",
            "reason": "测试推荐理由"
        ]
        
        let urlString = "\(serverUrl)/1.1/classes/Recommendation"
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
                if let _ = error {
                    completion(false)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false)
                    return
                }
                
                if httpResponse.statusCode == 201 {
                    // 成功创建表，删除测试记录
                    if let data = data {
                        do {
                            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                            if let objectId = json?["objectId"] as? String {
                                self.deleteRecommendationTestRecord(objectId: objectId) {
                                    completion(true)
                                }
                            } else {
                                completion(true)
                            }
                        } catch {
                            completion(true)
                        }
                    } else {
                        completion(true)
                    }
                } else {
                    completion(false)
                }
            }.resume()
            
        } catch {
            completion(false)
        }
    }
    
    // 删除Recommendation测试记录
    private func deleteRecommendationTestRecord(objectId: String, completion: @escaping () -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/Recommendation/\(objectId)"
        guard let url = URL(string: urlString) else {
            completion()
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { _, _, _ in
            DispatchQueue.main.async {
                completion()
            }
        }.resume()
    }
    
    /// 删除Recommendation记录 - 使用 LCObject
    func deleteRecommendation(objectId: String, completion: @escaping (Bool, String?) -> Void) {
        // ✅ 使用 LCObject 删除对象
        let recommendation = LCObject(className: "Recommendation", objectId: objectId)
        _ = recommendation.delete { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    completion(true, nil)
                case .failure(let error):
                    completion(false, "删除失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// 上传推荐记录到Recommendation表 - 使用 LCObject
    func uploadRecommendation(data: [String: Any], completion: @escaping (Bool, String, String?) -> Void) {
        // ✅ 使用 LCObject 创建对象
        let recommendation = LCObject(className: "Recommendation")
        
        do {
            // 设置所有字段
            if let latitude = data["latitude"] as? Double {
                try recommendation.set("latitude", value: latitude)
            }
            if let longitude = data["longitude"] as? Double {
                try recommendation.set("longitude", value: longitude)
            }
            if let accuracy = data["accuracy"] as? Double {
                try recommendation.set("accuracy", value: accuracy)
            }
            if let userId = data["userId"] as? String {
                try recommendation.set("userId", value: userId)
            }
            if let userName = data["userName"] as? String {
                try recommendation.set("userName", value: userName)
            }
            if let loginType = data["loginType"] as? String {
                try recommendation.set("loginType", value: loginType)
            }
            if let userEmail = data["userEmail"] as? String {
                try recommendation.set("userEmail", value: userEmail)
            } else {
            }
            if let userAvatar = data["userAvatar"] as? String {
                try recommendation.set("userAvatar", value: userAvatar)
            }
            if let deviceId = data["deviceId"] as? String {
                try recommendation.set("deviceId", value: deviceId)
            }
            if let deviceTime = data["deviceTime"] as? String {
                try recommendation.set("deviceTime", value: deviceTime)
            }
            if let timezone = data["timezone"] as? String {
                try recommendation.set("timezone", value: timezone)
            }
            if let status = data["status"] as? String {
                try recommendation.set("status", value: status)
            }
            if let likeCount = data["likeCount"] as? Int {
                try recommendation.set("likeCount", value: likeCount)
            }
            if let address = data["address"] as? String {
                try recommendation.set("address", value: address)
            }
            if let placeName = data["placeName"] as? String {
                try recommendation.set("placeName", value: placeName)
            }
            if let reason = data["reason"] as? String {
                try recommendation.set("reason", value: reason)
            }
            
            _ = recommendation.save { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        // 🎯 新增：返回新创建的推荐项的 objectId
                        let objectId = recommendation.objectId?.stringValue
                        completion(true, "推荐上传成功", objectId)
                    case .failure(let error):
                        if error.code == 404 {
                            // 表不存在，尝试自动创建表
                            self.createRecommendationTable { success in
                                if success {
                                    self.uploadRecommendation(data: data, completion: completion)
                                } else {
                                    completion(false, "创建Recommendation表失败", nil)
                                }
                            }
                        } else {
                            completion(false, "上传失败: \(error.localizedDescription)", nil)
                        }
                    }
                }
            }
        } catch {
            completion(false, "属性设置失败: \(error.localizedDescription)", nil)
        }
    }
    
    /// 获取所有Recommendation记录，按like_count降序排序 - 使用 LCQuery
    func fetchAllRecommendations(currentLatitude: Double? = nil, currentLongitude: Double? = nil, completion: @escaping ([LocationRecord]?, String?) -> Void) {
        // 🎯 新增：如果提供了当前位置，使用渐进式地理范围查询
        if let lat = currentLatitude, let lon = currentLongitude {
            self.fetchRecommendationsWithProgressiveRange(
                currentLatitude: lat,
                currentLongitude: lon,
                initialRange: 0.03,  // 初始范围±0.03度（约±3.3km）
                maxRange: 1.0,       // 最大范围±1.0度（约111km）
                minCount: 20,        // 最少需要20条
                currentRange: 0.03,
                completion: completion
            )
            return
        }
        
        // 没有当前位置时，使用全量查询
        
        // ✅ 使用 LCQuery 查询
        let query = LCQuery(className: "Recommendation")
        query.whereKey("likeCount", .descending)
        query.limit = 1000
        
        let queryStartTime = Date()
        _ = query.find { result in
            let queryEndTime = Date()
            let _ = queryEndTime.timeIntervalSince(queryStartTime)
            
            DispatchQueue.main.async {
                switch result {
                case .success(let objects):
                    
                    // 解析为LocationRecord对象（复用LocationRecord结构）
                    var records: [LocationRecord] = []
                    for (index, object) in objects.enumerated() {
                        let objectId = object.objectId?.value ?? ""
                        let latitude = object["latitude"]?.doubleValue ?? 0.0
                        let longitude = object["longitude"]?.doubleValue ?? 0.0
                        let accuracy = object["accuracy"]?.doubleValue ?? 0.0
                        let user_id = object["userId"]?.stringValue ?? ""
                        let user_name = object["userName"]?.stringValue
                        let user_email = object["userEmail"]?.stringValue
                        // 🎯 不再读取userAvatar字段
                        let user_avatar: String? = nil
                        let login_type = object["loginType"]?.stringValue
                        let device_id = object["deviceId"]?.stringValue ?? ""
                        let status = object["status"]?.stringValue
                        let like_count = object["likeCount"]?.intValue
                        let timezone = object["timezone"]?.stringValue
                        let place_name = object["placeName"]?.stringValue
                        let reason = object["reason"]?.stringValue // 🎯 新增：读取 reason 字段
                        
                        // 解析时间戳
                        var timestampString: String
                        if let deviceTimeStr = object["deviceTime"]?.stringValue {
                            timestampString = deviceTimeStr
                        } else if let createdAt = object.createdAt?.value {
                            timestampString = ISO8601DateFormatter().string(from: createdAt)
                        } else {
                            timestampString = ISO8601DateFormatter().string(from: Date())
                        }
                        
                        let record = LocationRecord(
                            id: index,
                            objectId: objectId,
                            timestamp: timestampString,
                            latitude: latitude,
                            longitude: longitude,
                            accuracy: accuracy,
                            userId: user_id,
                            userName: user_name,
                            loginType: login_type,
                            userEmail: user_email,
                            userAvatar: user_avatar,
                            deviceId: device_id,
                            clientTimestamp: nil,
                            timezone: timezone,
                            status: status,
                            recordCount: nil,
                            likeCount: like_count,
                            placeName: place_name,
                            reason: reason // 🎯 新增：传递 reason 字段
                        )
                        records.append(record)
                        
                        // 打印前5条记录的详细信息
                        if index < 5 {
                        }
                    }
                    completion(records, nil)
                    
                case .failure(let error):
                    completion(nil, "查询失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // 🎯 新增：渐进式地理范围查询（类似排行榜）
    private func fetchRecommendationsWithProgressiveRange(
        currentLatitude: Double,
        currentLongitude: Double,
        initialRange: Double,
        maxRange: Double,
        minCount: Int,
        currentRange: Double,
        completion: @escaping ([LocationRecord]?, String?) -> Void
    ) {
        let queryStartTime = Date()
        let minLat = currentLatitude - currentRange
        let maxLat = currentLatitude + currentRange
        let minLon = currentLongitude - currentRange
        let maxLon = currentLongitude + currentRange
        
        
        // 创建带地理范围的查询
        let query = LCQuery(className: "Recommendation")
        
        // 添加地理范围查询条件
        query.whereKey("latitude", .greaterThanOrEqualTo(minLat))
        query.whereKey("latitude", .lessThanOrEqualTo(maxLat))
        query.whereKey("longitude", .greaterThanOrEqualTo(minLon))
        query.whereKey("longitude", .lessThanOrEqualTo(maxLon))
        
        // 设置排序和限制
        query.whereKey("likeCount", .descending)
        query.limit = 1000  // 单次查询最多1000条
        
        // 执行查询
        _ = query.find { result in
            let queryEndTime = Date()
            let _ = queryEndTime.timeIntervalSince(queryStartTime)
            
            DispatchQueue.main.async {
                switch result {
                case .success(let objects):
                    // 解析为LocationRecord对象
                    var records: [LocationRecord] = []
                    for (index, object) in objects.enumerated() {
                        let objectId = object.objectId?.value ?? ""
                        let latitude = object["latitude"]?.doubleValue ?? 0.0
                        let longitude = object["longitude"]?.doubleValue ?? 0.0
                        let accuracy = object["accuracy"]?.doubleValue ?? 0.0
                        let user_id = object["userId"]?.stringValue ?? ""
                        let user_name = object["userName"]?.stringValue
                        let user_email = object["userEmail"]?.stringValue
                        // 🎯 不再读取userAvatar字段
                        let user_avatar: String? = nil
                        let login_type = object["loginType"]?.stringValue
                        let device_id = object["deviceId"]?.stringValue ?? ""
                        let status = object["status"]?.stringValue
                        let like_count = object["likeCount"]?.intValue
                        let timezone = object["timezone"]?.stringValue
                        let place_name = object["placeName"]?.stringValue
                        let reason = object["reason"]?.stringValue
                        
                        // 解析时间戳
                        var timestampString: String
                        if let deviceTimeStr = object["deviceTime"]?.stringValue {
                            timestampString = deviceTimeStr
                        } else if let createdAt = object.createdAt?.value {
                            timestampString = ISO8601DateFormatter().string(from: createdAt)
                        } else {
                            timestampString = ISO8601DateFormatter().string(from: Date())
                        }
                        
                        let record = LocationRecord(
                            id: index,
                            objectId: objectId,
                            timestamp: timestampString,
                            latitude: latitude,
                            longitude: longitude,
                            accuracy: accuracy,
                            userId: user_id,
                            userName: user_name,
                            loginType: login_type,
                            userEmail: user_email,
                            userAvatar: user_avatar,
                            deviceId: device_id,
                            clientTimestamp: nil,
                            timezone: timezone,
                            status: status,
                            recordCount: nil,
                            likeCount: like_count,
                            placeName: place_name,
                            reason: reason
                        )
                        records.append(record)
                    }
                    
                    
                    // 检查是否满足最少数量要求
                    if records.count >= minCount || currentRange >= maxRange {
                        // 满足要求或已达到最大范围，返回结果
                        completion(records, nil)
                    } else {
                        // 不满足要求且未达到最大范围，扩大范围继续查询
                        let nextRange = min(currentRange + 0.03, maxRange)  // 每次增加0.03度
                        self.fetchRecommendationsWithProgressiveRange(
                            currentLatitude: currentLatitude,
                            currentLongitude: currentLongitude,
                            initialRange: initialRange,
                            maxRange: maxRange,
                            minCount: minCount,
                            currentRange: nextRange,
                            completion: completion
                        )
                    }
                    
                case .failure(let error):
                    let _ = Date().timeIntervalSince(queryStartTime)
                    completion(nil, "查询失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// 🎯 新增：固定范围查询推荐榜（用于第二次点击寻找按钮）
    func fetchRecommendationsWithFixedRange(
        currentLatitude: Double,
        currentLongitude: Double,
        range: Double,
        completion: @escaping ([LocationRecord]?, String?) -> Void
    ) {
        let queryStartTime = Date()
        let minLat = currentLatitude - range
        let maxLat = currentLatitude + range
        let minLon = currentLongitude - range
        let maxLon = currentLongitude + range
        
        
        // 创建带地理范围的查询
        let query = LCQuery(className: "Recommendation")
        
        // 添加地理范围查询条件
        query.whereKey("latitude", .greaterThanOrEqualTo(minLat))
        query.whereKey("latitude", .lessThanOrEqualTo(maxLat))
        query.whereKey("longitude", .greaterThanOrEqualTo(minLon))
        query.whereKey("longitude", .lessThanOrEqualTo(maxLon))
        
        // 设置排序和限制
        query.whereKey("likeCount", .descending)
        query.limit = 1000  // 单次查询最多1000条
        
        // 执行查询
        _ = query.find { result in
            let queryEndTime = Date()
            let _ = queryEndTime.timeIntervalSince(queryStartTime)
            
            DispatchQueue.main.async {
                switch result {
                case .success(let objects):
                    
                    // 解析为LocationRecord对象
                    var records: [LocationRecord] = []
                    for (index, object) in objects.enumerated() {
                        let objectId = object.objectId?.value ?? ""
                        let latitude = object["latitude"]?.doubleValue ?? 0.0
                        let longitude = object["longitude"]?.doubleValue ?? 0.0
                        let accuracy = object["accuracy"]?.doubleValue ?? 0.0
                        let user_id = object["userId"]?.stringValue ?? ""
                        let user_name = object["userName"]?.stringValue
                        let user_email = object["userEmail"]?.stringValue
                        // 🎯 不再读取userAvatar字段
                        let user_avatar: String? = nil
                        let login_type = object["loginType"]?.stringValue
                        let device_id = object["deviceId"]?.stringValue ?? ""
                        let status = object["status"]?.stringValue
                        let like_count = object["likeCount"]?.intValue
                        let timezone = object["timezone"]?.stringValue
                        let place_name = object["placeName"]?.stringValue
                        let reason = object["reason"]?.stringValue
                        
                        // 解析时间戳
                        var timestampString: String
                        if let deviceTimeStr = object["deviceTime"]?.stringValue {
                            timestampString = deviceTimeStr
                        } else if let createdAt = object.createdAt?.value {
                            timestampString = ISO8601DateFormatter().string(from: createdAt)
                        } else {
                            timestampString = ISO8601DateFormatter().string(from: Date())
                        }
                        
                        let record = LocationRecord(
                            id: index,
                            objectId: objectId,
                            timestamp: timestampString,
                            latitude: latitude,
                            longitude: longitude,
                            accuracy: accuracy,
                            userId: user_id,
                            userName: user_name,
                            loginType: login_type,
                            userEmail: user_email,
                            userAvatar: user_avatar,
                            deviceId: device_id,
                            clientTimestamp: nil,
                            timezone: timezone,
                            status: status,
                            recordCount: nil,
                            likeCount: like_count,
                            placeName: place_name,
                            reason: reason
                        )
                        records.append(record)
                        
                        // 打印前5条记录的详细信息
                        if index < 5 {
                        }
                    }
                    
                    completion(records, nil)
                    
                case .failure(let error):
                    let _ = Date().timeIntervalSince(queryStartTime)
                    completion(nil, "查询失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// 更新Recommendation表的点赞数
    /// 根据用户ID查询该用户发送过的所有推荐记录
    func fetchRecommendationsByUserId(userId: String, completion: @escaping ([LocationRecord]?, String?) -> Void) {
        let query = LCQuery(className: "Recommendation")
        query.whereKey("userId", .equalTo(userId))
        query.whereKey("deviceTime", .descending) // 按时间降序排序（最新的在前）
        query.limit = 1000
        
        _ = query.find { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let objects):
                    var records: [LocationRecord] = []
                    for (index, object) in objects.enumerated() {
                        let objectId = object.objectId?.value ?? ""
                        let latitude = object["latitude"]?.doubleValue ?? 0.0
                        let longitude = object["longitude"]?.doubleValue ?? 0.0
                        let accuracy = object["accuracy"]?.doubleValue ?? 0.0
                        let user_id = object["userId"]?.stringValue ?? ""
                        let user_name = object["userName"]?.stringValue
                        let user_email = object["userEmail"]?.stringValue
                        // 🎯 不再读取userAvatar字段
                        let user_avatar: String? = nil
                        let login_type = object["loginType"]?.stringValue
                        let device_id = object["deviceId"]?.stringValue ?? ""
                        let status = object["status"]?.stringValue
                        let like_count = object["likeCount"]?.intValue
                        let timezone = object["timezone"]?.stringValue
                        let place_name = object["placeName"]?.stringValue
                        let reason = object["reason"]?.stringValue
                        
                        // 解析时间戳
                        var timestampString: String
                        if let deviceTimeStr = object["deviceTime"]?.stringValue {
                            timestampString = deviceTimeStr
                        } else if let createdAt = object.createdAt?.value {
                            timestampString = ISO8601DateFormatter().string(from: createdAt)
                        } else {
                            timestampString = ISO8601DateFormatter().string(from: Date())
                        }
                        
                        let record = LocationRecord(
                            id: index,
                            objectId: objectId,
                            timestamp: timestampString,
                            latitude: latitude,
                            longitude: longitude,
                            accuracy: accuracy,
                            userId: user_id,
                            userName: user_name,
                            loginType: login_type,
                            userEmail: user_email,
                            userAvatar: user_avatar,
                            deviceId: device_id,
                            clientTimestamp: nil,
                            timezone: timezone,
                            status: status,
                            recordCount: nil,
                            likeCount: like_count,
                            placeName: place_name,
                            reason: reason
                        )
                        records.append(record)
                    }
                    completion(records, nil)
                    
                case .failure(let error):
                    completion(nil, "查询失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func updateRecommendationLikeCount(objectId: String, increment: Bool = true, completion: @escaping (Bool, String?) -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/Recommendation/\(objectId)"
        guard let url = URL(string: urlString) else {
            completion(false, "无效的URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        // 构建更新数据 - 使用LeanCloud的Increment操作
        let updateData: [String: Any] = [
            "likeCount": increment ? ["__op": "Increment", "amount": 1] : ["__op": "Increment", "amount": -1]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: updateData)
        } catch {
            completion(false, "数据编码失败: \(error.localizedDescription)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, "网络错误: \(error.localizedDescription)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false, "无效的响应")
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    completion(true, nil)
                } else {
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = json["error"] as? String {
                        completion(false, errorMessage)
                    } else {
                        completion(false, "更新失败，状态码: \(httpResponse.statusCode)")
                    }
                }
            }
        }.resume()
    }
}

