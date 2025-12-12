import Foundation
import LeanCloud

// MARK: - 喜欢记录管理扩展
extension LeanCloudService {
    
    // 取消点赞记录 - 遵循数据存储开发指南，使用 LCQuery（基于 likedUserId）
    func cancelLikeRecord(userId: String, likedUserId: String, completion: @escaping (Bool, String) -> Void) {
        
        // ✅ 按照开发指南：使用 LCQuery 创建查询
        // 🔧 修复：移除 limit = 1，更新所有匹配的记录（可能存在重复记录）
        let query = LCQuery(className: "LikeRecord")
        query.whereKey("userId", .equalTo(userId))
        query.whereKey("likedUserId", .equalTo(likedUserId))
        query.whereKey("status", .equalTo("active"))
        query.limit = 1000 // 🔧 修复：允许查询多条记录，确保更新所有匹配的记录
        
        query.find { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let records):
                    let totalCount = records.count
                    var completedCount = 0
                    var successCount = 0
                    var failedObjectIds: [String] = []
                    var lastError: String? = nil
                    let lockQueue = DispatchQueue(label: "cancelLikeRecordLock")
                    
                    if totalCount == 0 {
                        completion(false, "未找到要取消的记录")
                        return
                    }
                    
                    // 🔧 修复：更新所有匹配的记录，而不是只更新第一条
                    for _ in records {
                    }
                    
                    // 🔧 修复：添加延迟以避免速率限制（429 Too many requests）
                    // LeanCloud 有速率限制，批量更新时需要添加延迟
                    for (index, record) in records.enumerated() {
                        guard let objectId = record.objectId?.stringValue else {
                            lockQueue.async {
                                completedCount += 1
                                if completedCount == totalCount {
                                    if successCount > 0 {
                                        if !failedObjectIds.isEmpty {
                                        }
                                        completion(true, "")
                                    } else {
                                        completion(false, lastError ?? "更新失败")
                                    }
                                }
                            }
                            continue
                        }
                        
                        // 🔧 修复：添加延迟以避免速率限制（每 100ms 更新一条）
                        let delay = Double(index) * 0.1
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            self.updateLikeRecordStatus(objectId: objectId, status: "cancelled") { success, error in
                                lockQueue.async {
                                    completedCount += 1
                                    if success {
                                        successCount += 1
                                    } else {
                                        failedObjectIds.append(objectId)
                                        lastError = error
                                        if error.contains("429") || error.contains("Too many requests") {
                                        }
                                    }
                                    
                                    // 所有记录更新完成后调用 completion
                                    if completedCount == totalCount {
                                        if !failedObjectIds.isEmpty {
                                        }
                                        
                                        if successCount > 0 {
                                            if !failedObjectIds.isEmpty {
                                            }
                                            completion(true, "")
                                        } else {
                                            completion(false, lastError ?? "更新失败")
                                        }
                                    }
                                }
                            }
                        }
                    }
                case .failure(let error):
                    completion(false, "查询失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // 🎯 新增：取消点赞记录（基于 recordObjectId，用于推荐榜）
    // 🔧 关键区别：点赞按钮对应的是推荐榜中的一条记录（recordObjectId），不是用户（userId）
    // 🔧 关键字段：recordObjectId 对应 Recommendation 表的 objectId 字段（主键）
    func cancelLikeRecordByObjectId(userId: String, recordObjectId: String, completion: @escaping (Bool, String) -> Void) {
        
        // ✅ 按照开发指南：使用 LCQuery 创建查询
        // 🔧 修复：移除 limit = 1，更新所有匹配的记录（可能存在重复记录）
        let query = LCQuery(className: "LikeRecord")
        query.whereKey("userId", .equalTo(userId))
        query.whereKey("recordObjectId", .equalTo(recordObjectId))
        query.whereKey("status", .equalTo("active"))
        query.limit = 1000 // 🔧 修复：允许查询多条记录，确保更新所有匹配的记录
        
        query.find { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let records):
                    if records.isEmpty {
                        completion(false, "未找到要取消的记录")
                        return
                    }
                    
                    // 🔧 修复：更新所有匹配的记录，而不是只更新第一条
                    for _ in records {
                    }
                    
                    let totalCount = records.count
                    var completedCount = 0
                    var successCount = 0
                    var failedObjectIds: [String] = []
                    var lastError: String? = nil
                    let lockQueue = DispatchQueue(label: "cancelLikeRecordLock")
                    
                    if totalCount == 0 {
                        completion(false, "未找到要取消的记录")
                        return
                    }
                    
                    // 🔧 修复：添加延迟以避免速率限制（429 Too many requests）
                    // LeanCloud 有速率限制，批量更新时需要添加延迟
                    for (index, record) in records.enumerated() {
                        guard let objectId = record.objectId?.stringValue else {
                            lockQueue.async {
                                completedCount += 1
                                if completedCount == totalCount {
                                    if successCount > 0 {
                                        if !failedObjectIds.isEmpty {
                                        }
                                        completion(true, "")
                                    } else {
                                        completion(false, lastError ?? "更新失败")
                                    }
                                }
                            }
                            continue
                        }
                        
                        // 🔧 修复：添加延迟以避免速率限制（每 100ms 更新一条）
                        let delay = Double(index) * 0.1
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            self.updateLikeRecordStatus(objectId: objectId, status: "cancelled") { success, error in
                                lockQueue.async {
                                    completedCount += 1
                                    if success {
                                        successCount += 1
                                    } else {
                                        failedObjectIds.append(objectId)
                                        lastError = error
                                        if error.contains("429") || error.contains("Too many requests") {
                                        }
                                    }
                                    
                                    // 所有记录更新完成后调用 completion
                                    if completedCount == totalCount {
                                        if !failedObjectIds.isEmpty {
                                        }
                                        
                                        if successCount > 0 {
                                            if !failedObjectIds.isEmpty {
                                            }
                                            completion(true, "")
                                        } else {
                                            completion(false, lastError ?? "更新失败")
                                        }
                                    }
                                }
                            }
                        }
                    }
                case .failure(let error):
                    completion(false, "查询失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // 更新点赞记录状态
    private func updateLikeRecordStatus(objectId: String, status: String, completion: @escaping (Bool, String) -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/LikeRecord/\(objectId)"
        guard let url = URL(string: urlString) else {
            completion(false, "无效的URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        let updateData = ["status": status]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: updateData)
        } catch {
            completion(false, "数据编码失败: \(error.localizedDescription)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, "更新失败: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    
                    if httpResponse.statusCode == 200 {
                        completion(true, "")
                    } else if httpResponse.statusCode == 429 {
                        if let data = data {
                            do {
                                let errorJson = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                                if let error = errorJson?["error"] as? String {
                                    completion(false, "LeanCloud错误: \(error)")
                                } else {
                                    completion(false, "LeanCloud错误: Too many requests.")
                                }
                            } catch {
                                completion(false, "LeanCloud错误: Too many requests.")
                            }
                        } else {
                            completion(false, "LeanCloud错误: Too many requests.")
                        }
                    } else {
                        var errorMessage = "更新失败: \(httpResponse.statusCode)"
                        if let data = data {
                            do {
                                let errorJson = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                                if let error = errorJson?["error"] as? String {
                                    errorMessage = "LeanCloud错误: \(error)"
                                } else {
                                }
                            } catch {
                            }
                        }
                        completion(false, errorMessage)
                    }
                } else {
                    completion(false, "无效的服务器响应")
                }
            }
        }.resume()
    }
    
    // 上传喜欢记录到LeanCloud
    func uploadLikeRecord(likeData: [String: Any], completion: @escaping (Bool, String) -> Void) {
        
        let urlString = "\(serverUrl)/1.1/classes/LikeRecord"
        guard let url = URL(string: urlString) else {
            completion(false, "无效的URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        // 为喜欢数据添加ACL权限
        let likeDataWithACL = addACLToData(likeData)
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: likeDataWithACL)
        } catch {
            completion(false, "数据编码失败: \(error.localizedDescription)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, "上传失败: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    
                    if httpResponse.statusCode == 201 {
                        // 成功创建喜欢记录
                        if let data = data {
                            do {
                                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                                if json?["objectId"] as? String != nil {
                                }
                                completion(true, "")
                            } catch {
                                completion(true, "")
                            }
                        } else {
                            completion(true, "")
                        }
                    } else if httpResponse.statusCode == 404 {
                        // 404错误表示表不存在，尝试自动创建表
                        // 表不存在，尝试自动创建表
                        self.createLikeRecordTable { tableCreated in
                            if tableCreated {
                                // 表创建成功，重新尝试上传喜欢记录
                                // 表创建成功后，重新尝试上传喜欢记录
                                self.uploadLikeRecord(likeData: likeData, completion: completion)
                            } else {
                                // 表创建失败
                                completion(false, "表创建失败")
                            }
                        }
                        return
                    } else {
                        var errorMessage = "上传失败: \(httpResponse.statusCode)"
                        if let data = data {
                            do {
                                let errorJson = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                                if let error = errorJson?["error"] as? String {
                                    errorMessage = "LeanCloud错误: \(error)"
                                }
                            } catch {
                                errorMessage = "上传失败: \(httpResponse.statusCode)"
                            }
                        }
                        completion(false, errorMessage)
                    }
                } else {
                    completion(false, "无效的服务器响应")
                }
            }
        }.resume()
    }
    
    // 创建LikeRecord表
    private func createLikeRecordTable(completion: @escaping (Bool) -> Void) {
        let testData: [String: Any] = [
            "userId": "test_user",
            "likedUserId": "test_liked_user",
            "status": "active",
            "deviceId": "test_device",
            "timezone": "UTC",
            "deviceTime": ISO8601DateFormatter().string(from: Date())
        ]
        
        let urlString = "\(serverUrl)/1.1/classes/LikeRecord"
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        setLeanCloudHeaders(&request, contentType: "application/json")
        request.timeoutInterval = 10.0
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: testData)
        } catch {
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if error != nil {
                    completion(false)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 201 {
                        // 成功创建表，删除测试记录
                        if let data = data {
                            do {
                                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                                if let objectId = json?["objectId"] as? String {
                                    self.deleteLikeTestRecord(objectId: objectId) {
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
                } else {
                    completion(false)
                }
            }
        }.resume()
    }
    
    // 🎯 新增：实时查询单个位置记录的点赞状态（基于 recordObjectId）- 遵循数据存储开发指南，使用 LCQuery
    // 🔧 关键区别：点赞按钮对应的是推荐榜中的一条记录（recordObjectId），不是用户（userId）
    // 🔧 关键字段：recordObjectId 对应 Recommendation 表的 objectId 字段（主键）
    func fetchLikeStatus(userId: String, recordObjectId: String, completion: @escaping (Bool, String?) -> Void) {
        // ✅ 按照开发指南：使用 LCQuery 创建查询
        // 🔧 修复：查询所有 active 记录，以便显示所有匹配的记录
        let query = LCQuery(className: "LikeRecord")
        query.whereKey("userId", .equalTo(userId))
        query.whereKey("recordObjectId", .equalTo(recordObjectId))
        query.whereKey("status", .equalTo("active"))
        query.limit = 1000 // 🔧 修复：查询所有匹配的记录，以便调试
        
        query.find { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let records):
                    // 如果找到 status = "active" 的记录，返回 true
                    let isLiked = records.first != nil
                    
                    if records.isEmpty {
                    } else {
                        _ = records
                    }
                    
                    completion(isLiked, nil)
                case .failure(let error):
                    completion(false, "查询失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // 🎯 新增：实时查询单个用户的点赞状态（基于 likedUserId）- 遵循数据存储开发指南，使用 LCQuery
    func fetchLikeStatusByUserId(userId: String, likedUserId: String, completion: @escaping (Bool, String?) -> Void) {
        // ✅ 按照开发指南：使用 LCQuery 创建查询
        let query = LCQuery(className: "LikeRecord")
        query.whereKey("userId", .equalTo(userId))
        query.whereKey("likedUserId", .equalTo(likedUserId))
        query.whereKey("status", .equalTo("active"))
        query.limit = 1
        
        query.find { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let records):
                    // 如果找到 status = "active" 的记录，返回 true
                    completion(records.first != nil, nil)
                case .failure(let error):
                    completion(false, "查询失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // 获取活跃的点赞记录 - 遵循数据存储开发指南，使用 LCQuery
    func fetchActiveLikeRecords(userId: String, completion: @escaping ([[String: Any]]?, String?) -> Void) {
        // ✅ 按照开发指南：使用 LCQuery 创建查询
        let query = LCQuery(className: "LikeRecord")
        query.whereKey("userId", .equalTo(userId))
        query.whereKey("status", .equalTo("active"))
        query.whereKey("createdAt", .descending)
        query.limit = 1000
        
        query.find { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let records):
                    let results = records.map { record -> [String: Any] in
                        var dict: [String: Any] = [:]
                        dict["objectId"] = record.objectId?.stringValue ?? ""
                        dict["userId"] = record["userId"]?.stringValue ?? ""
                        dict["likedUserId"] = record["likedUserId"]?.stringValue ?? ""
                        dict["status"] = record["status"]?.stringValue ?? ""
                        return dict
                    }
                    completion(results, nil)
                case .failure(let error):
                    completion(nil, "获取失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // 删除LikeRecord测试记录
    private func deleteLikeTestRecord(objectId: String, completion: @escaping () -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/LikeRecord/\(objectId)"
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
}
