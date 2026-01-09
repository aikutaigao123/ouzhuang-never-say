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
        // 🎯 新增：先查询用户的钻石数，然后计算综合点赞数
        guard let userId = data["userId"] as? String,
              let loginType = data["loginType"] as? String else {
            completion(false, "缺少用户信息", nil)
            return
        }
        
        let likeCount = data["likeCount"] as? Int ?? 0
        
        // 查询用户的钻石数（totalScore）
        self.fetchUserScore(userId: userId, loginType: loginType) { userScore in
            let diamonds = userScore?.totalScore ?? 0
            // 🎯 计算综合点赞数 = 点赞数 + (钻石数 × 0.01)
            let effectiveLikeCount = Double(likeCount) + (Double(diamonds) * 0.01)
            
            
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
                try recommendation.set("userId", value: userId)
                if let userName = data["userName"] as? String {
                    try recommendation.set("userName", value: userName)
                }
                try recommendation.set("loginType", value: loginType)
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
                try recommendation.set("likeCount", value: likeCount)
                // 🎯 新增：存储综合点赞数
                try recommendation.set("effectiveLikeCount", value: effectiveLikeCount)
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
    }
    
    // 🎯 新增：查询单个用户的 UserScore
    private func fetchUserScore(userId: String, loginType: String, completion: @escaping (UserScore?) -> Void) {
        
        let whereClause = "{\"userId\":\"\(userId)\",\"loginType\":\"\(loginType)\"}"
        guard let encodedWhere = whereClause.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            completion(nil)
            return
        }
        
        let urlString = "\(serverUrl)/1.1/classes/UserScore?where=\(encodedWhere)&limit=1"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                guard error == nil,
                      let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200,
                      let responseData = data,
                      let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                      let results = json["results"] as? [[String: Any]],
                      let result = results.first else {
                    completion(nil)
                    return
                }
                
                let userName = result["userName"] as? String ?? ""
                let userAvatar = result["userAvatar"] as? String ?? ""
                let userEmail = result["userEmail"] as? String
                let totalScore = result["totalScore"] as? Int ?? 0
                let favoriteCount = result["favoriteCount"] as? Int ?? 0
                let likeCount = result["likeCount"] as? Int ?? 0
                let latitude = result["latitude"] as? Double
                let longitude = result["longitude"] as? Double
                let deviceId = result["deviceId"] as? String
                
                let userScore = UserScore(
                    userId: userId,
                    userName: userName,
                    userAvatar: userAvatar,
                    userEmail: userEmail,
                    loginType: loginType,
                    favoriteCount: favoriteCount,
                    likeCount: likeCount,
                    distance: nil,
                    latitude: latitude,
                    longitude: longitude,
                    deviceId: deviceId,
                    totalScore: totalScore
                )
                completion(userScore)
            }
        }.resume()
    }
    
    /// 获取所有Recommendation记录，按like_count降序排序 - 使用 LCQuery
    // 🎯 新增：添加重试机制（与用户头像查询一致）
    func fetchAllRecommendations(currentLatitude: Double? = nil, currentLongitude: Double? = nil, completion: @escaping ([LocationRecord]?, String?) -> Void) {
        // 🎯 新增：如果提供了当前位置，使用渐进式地理范围查询（带重试）
        if let lat = currentLatitude, let lon = currentLongitude {
            var retryCount = 0
            
            func attemptProgressive() {
                self.fetchRecommendationsWithProgressiveRange(
                    currentLatitude: lat,
                    currentLongitude: lon,
                    initialRange: 0.03,  // 初始范围±0.03度（约±3.3km）
                    maxRange: 1.0,       // 最大范围±1.0度（约111km）
                    minCount: 20,        // 最少需要20条
                    currentRange: 0.03
                ) { records, error in
                    if let error = error, !error.isEmpty {
                        if retryCount < LeanCloudRetryConfig.maxRetries {
                            retryCount += 1
                            let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                attemptProgressive()
                            }
                        } else {
                            completion(nil, error)
                        }
                    } else {
                        completion(records, nil)
                    }
                }
            }
            
            attemptProgressive()
            return
        }
        
        // 没有当前位置时，使用全量查询（带重试）
        var retryCount = 0
        
        func attempt() {
            // ✅ 使用 LCQuery 查询
            let query = LCQuery(className: "Recommendation")
            // 🎯 修改：按综合点赞数排序
            query.whereKey("effectiveLikeCount", .descending)
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
                        // 🎯 修改：查询失败时，如果未达到最大重试次数，触发重试
                        if retryCount < LeanCloudRetryConfig.maxRetries {
                            retryCount += 1
                            let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                attempt()
                            }
                        } else {
                            completion(nil, "查询失败: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
        
        attempt()
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
        
        // 🎯 修改：按综合点赞数排序
        query.whereKey("effectiveLikeCount", .descending)
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
                    
                    
                    // 🎯 打印前5条记录的坐标，检查是否在范围内
                    var validRecords: [LocationRecord] = []
                    var invalidCount = 0
                    
                    for record in records {
                        let inLatRange = record.latitude >= minLat && record.latitude <= maxLat
                        let inLonRange = record.longitude >= minLon && record.longitude <= maxLon
                        let inRange = inLatRange && inLonRange
                        
                        if inRange {
                            validRecords.append(record)
                        } else {
                            invalidCount += 1
                        }
                    }
                    
                    // 🎯 如果有效记录数不足，需要扩大范围继续查询
                    if validRecords.count < minCount && currentRange < maxRange {
                        // 扩大范围继续查询
                        let nextRange = min(currentRange + 0.03, maxRange)
                        self.fetchRecommendationsWithProgressiveRange(
                            currentLatitude: currentLatitude,
                            currentLongitude: currentLongitude,
                            initialRange: initialRange,
                            maxRange: maxRange,
                            minCount: minCount,
                            currentRange: nextRange,
                            completion: completion
                        )
                        return
                    }
                    
                    // 使用过滤后的有效记录
                    let filteredRecords = validRecords
                    
                    // 检查是否满足最少数量要求（使用过滤后的记录）
                    let hasEnoughRecords = filteredRecords.count >= minCount
                    let reachedMaxRange = currentRange >= maxRange
                    
                    if hasEnoughRecords || reachedMaxRange {
                        // 满足要求或已达到最大范围，返回过滤后的结果
                        completion(filteredRecords, nil)
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
        
        // 🎯 修改：按综合点赞数排序
        query.whereKey("effectiveLikeCount", .descending)
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
        // 🎯 新增：先查询 Recommendation 记录，获取 userId 和 loginType，以便查询钻石数
        let queryUrlString = "\(serverUrl)/1.1/classes/Recommendation/\(objectId)"
        guard let queryUrl = URL(string: queryUrlString) else {
            completion(false, "无效的URL")
            return
        }
        
        var queryRequest = URLRequest(url: queryUrl)
        queryRequest.httpMethod = "GET"
        setLeanCloudHeaders(&queryRequest)
        queryRequest.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: queryRequest) { data, response, error in
            guard error == nil,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let responseData = data,
                  let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                  let userId = json["userId"] as? String,
                  let loginType = json["loginType"] as? String,
                  let currentLikeCount = json["likeCount"] as? Int else {
                DispatchQueue.main.async {
                    completion(false, "查询记录失败")
                }
                return
            }
            
            // 🎯 查询用户的钻石数
            self.fetchUserScore(userId: userId, loginType: loginType) { userScore in
                let diamonds = userScore?.totalScore ?? 0
                let newLikeCount = increment ? currentLikeCount + 1 : currentLikeCount - 1
                // 🎯 计算新的综合点赞数
                let newEffectiveLikeCount = Double(newLikeCount) + (Double(diamonds) * 0.01)
                
                
                // 🎯 更新 likeCount 和 effectiveLikeCount
                let urlString = "\(self.serverUrl)/1.1/classes/Recommendation/\(objectId)"
                guard let url = URL(string: urlString) else {
                    DispatchQueue.main.async {
                        completion(false, "无效的URL")
                    }
                    return
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "PUT"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                self.setLeanCloudHeaders(&request)
                request.timeoutInterval = 10.0
                
                // 🎯 修改：同时更新 likeCount 和 effectiveLikeCount
                let updateData: [String: Any] = [
                    "likeCount": increment ? ["__op": "Increment", "amount": 1] : ["__op": "Increment", "amount": -1],
                    "effectiveLikeCount": newEffectiveLikeCount
                ]
                
                do {
                    request.httpBody = try JSONSerialization.data(withJSONObject: updateData)
                } catch {
                    DispatchQueue.main.async {
                        completion(false, "数据编码失败: \(error.localizedDescription)")
                    }
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
        }.resume()
    }
    
    // 🎯 新增：批量更新某个用户的所有推荐记录的综合点赞数
    func updateAllRecommendationsEffectiveLikeCount(userId: String, loginType: String, newDiamonds: Int, completion: @escaping (Bool, String?) -> Void) {
        
        // 1. 查询该用户的所有推荐记录
        let whereClause = "{\"userId\":\"\(userId)\",\"loginType\":\"\(loginType)\"}"
        guard let encodedWhere = whereClause.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            completion(false, "参数编码失败")
            return
        }
        
        let urlString = "\(serverUrl)/1.1/classes/Recommendation?where=\(encodedWhere)&limit=1000"
        guard let url = URL(string: urlString) else {
            completion(false, "无效的URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 15.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let responseData = data,
                  let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
                  let results = json["results"] as? [[String: Any]] else {
                DispatchQueue.main.async {
                    completion(false, "查询推荐记录失败")
                }
                return
            }
            
            
            guard !results.isEmpty else {
                DispatchQueue.main.async {
                    completion(true, "无推荐记录")
                }
                return
            }
            
            // 2. 批量更新每条记录的 effectiveLikeCount
            let dispatchGroup = DispatchGroup()
            var updateResults: [Bool] = []
            var updateErrors: [String] = []
            
            for result in results {
                guard let objectId = result["objectId"] as? String,
                      let likeCount = result["likeCount"] as? Int else {
                    continue
                }
                
                // 🎯 计算新的综合点赞数
                let newEffectiveLikeCount = Double(likeCount) + (Double(newDiamonds) * 0.01)
                
                
                dispatchGroup.enter()
                
                // 更新单条记录
                let updateUrlString = "\(self.serverUrl)/1.1/classes/Recommendation/\(objectId)"
                guard let updateUrl = URL(string: updateUrlString) else {
                    updateResults.append(false)
                    updateErrors.append("无效URL: \(objectId)")
                    dispatchGroup.leave()
                    continue
                }
                
                var updateRequest = URLRequest(url: updateUrl)
                updateRequest.httpMethod = "PUT"
                updateRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                self.setLeanCloudHeaders(&updateRequest)
                updateRequest.timeoutInterval = 10.0
                
                let updateData: [String: Any] = [
                    "effectiveLikeCount": newEffectiveLikeCount
                ]
                
                do {
                    updateRequest.httpBody = try JSONSerialization.data(withJSONObject: updateData)
                } catch {
                    updateResults.append(false)
                    updateErrors.append("编码失败: \(objectId)")
                    dispatchGroup.leave()
                    continue
                }
                
                URLSession.shared.dataTask(with: updateRequest) { _, response, error in
                    defer { dispatchGroup.leave() }
                    
                    if let error = error {
                        updateResults.append(false)
                        updateErrors.append("网络错误: \(error.localizedDescription)")
                        return
                    }
                    
                    guard let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200 else {
                        updateResults.append(false)
                        updateErrors.append("更新失败: \(objectId)")
                        return
                    }
                    
                    updateResults.append(true)
                }.resume()
            }
            
            // 3. 等待所有更新完成
            dispatchGroup.notify(queue: .main) {
                let successCount = updateResults.filter { $0 }.count
                let totalCount = results.count
                
                
                if !updateErrors.isEmpty {
                    for _ in updateErrors.prefix(5) {
                    }
                }
                
                if successCount == totalCount {
                    completion(true, "全部更新成功")
                } else if successCount > 0 {
                    completion(true, "部分更新成功: \(successCount)/\(totalCount)")
                } else {
                    completion(false, "全部更新失败")
                }
            }
        }.resume()
    }
}

