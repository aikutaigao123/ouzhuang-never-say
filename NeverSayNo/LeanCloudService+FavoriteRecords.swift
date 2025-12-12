import Foundation
import LeanCloud

// MARK: - 喜欢记录管理扩展
extension LeanCloudService {
    
    // 生成验证token
    private func generateVerificationToken() -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<32).map { _ in letters.randomElement()! })
    }
    
    // 优先更新现有的cancelled记录，如果没有则创建新记录
    func updateOrCreateFavoriteRecord(favoriteData: [String: Any], completion: @escaping (Bool, String) -> Void) {
        guard let userId = favoriteData["userId"] as? String,
              let favoriteUserId = favoriteData["favoriteUserId"] as? String else {
            completion(false, "缺少必要的用户ID信息")
            return
        }
        
        
        // 首先尝试查找并更新现有的cancelled记录
        findAndUpdateCancelledFavoriteRecord(userId: userId, favoriteUserId: favoriteUserId) { success in
            if success {
                // 成功更新了cancelled记录
                completion(true, "")
            } else {
                // 没有找到cancelled记录，创建新记录
                self.uploadFavoriteRecord(favoriteData: favoriteData, completion: completion)
            }
        }
    }
    
    // 查找并更新现有的cancelled记录 - 遵循数据存储开发指南，使用 LCQuery
    private func findAndUpdateCancelledFavoriteRecord(userId: String, favoriteUserId: String, completion: @escaping (Bool) -> Void) {
        // ✅ 按照开发指南：使用 LCQuery 创建查询
        let query = LCQuery(className: "FavoriteRecord")
        query.whereKey("userId", .equalTo(userId))
        query.whereKey("favoriteUserId", .equalTo(favoriteUserId))
        query.whereKey("status", .equalTo("cancelled"))
        query.limit = 1
        
        query.find { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let records):
                    if let firstRecord = records.first,
                       let objectId = firstRecord.objectId?.stringValue {
                        // 找到cancelled记录，更新为active
                        self.updateFavoriteRecordStatus(objectId: objectId, status: "active") { success, error in
                            completion(success)
                        }
                    } else {
                        // 没有找到cancelled记录
                        completion(false)
                    }
                    case .failure:
                    completion(false)
                }
            }
        }
    }
    
    // 更新FavoriteRecord状态
    private func updateFavoriteRecordStatus(objectId: String, status: String, completion: @escaping (Bool, String) -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/FavoriteRecord/\(objectId)"
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
        if status == "cancelled" {
        } else if status == "active" {
        }
        
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
                        if status == "cancelled" {
                        } else if status == "active" {
                        }
                        completion(true, "")
                    } else {
                        completion(false, "更新失败: \(httpResponse.statusCode)")
                    }
                } else {
                    completion(false, "无效的服务器响应")
                }
            }
        }.resume()
    }

    // 上传喜欢记录到LeanCloud（带重试机制）
    func uploadFavoriteRecord(favoriteData: [String: Any], completion: @escaping (Bool, String) -> Void) {
        // 🔧 注释掉重试机制：直接调用，失败时不再重试
        uploadFavoriteRecordWithRetry(favoriteData: favoriteData, attempt: 0, maxAttempts: 1, completion: completion)
    }
    
    // 带重试机制的上传喜欢记录 - 遵循数据存储开发指南，使用 LCObject
    private func uploadFavoriteRecordWithRetry(favoriteData: [String: Any], attempt: Int, maxAttempts: Int, completion: @escaping (Bool, String) -> Void) {
        // ✅ 按照开发指南：使用 LCObject 创建对象
        let favoriteRecord = LCObject(className: "FavoriteRecord")
        
        do {
            // ✅ 按照开发指南：设置属性值
            try favoriteRecord.set("userId", value: favoriteData["userId"] as? String ?? "")
            try favoriteRecord.set("favoriteUserId", value: favoriteData["favoriteUserId"] as? String ?? "")
            try favoriteRecord.set("favoriteUserName", value: favoriteData["favoriteUserName"] as? String ?? "")
            try favoriteRecord.set("favoriteUserEmail", value: favoriteData["favoriteUserEmail"] as? String ?? "")
            try favoriteRecord.set("favoriteUserLoginType", value: favoriteData["favoriteUserLoginType"] as? String ?? "")
            try favoriteRecord.set("favoriteUserAvatar", value: favoriteData["favoriteUserAvatar"] as? String ?? "")
            try favoriteRecord.set("favoriteTime", value: favoriteData["favoriteTime"] as? String ?? ISO8601DateFormatter().string(from: Date()))
            try favoriteRecord.set("status", value: favoriteData["status"] as? String ?? "active")
            try favoriteRecord.set("recordObjectId", value: favoriteData["recordObjectId"] as? String ?? "")
            
            // ✅ 按照开发指南：将对象保存到云端
            
            _ = favoriteRecord.save { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        completion(true, "")
                    case .failure(let error):
                        // 🔧 注释掉重试机制：失败时直接返回，不再重试
                        // if attempt < maxAttempts - 1 {
                        //     DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        //         self.uploadFavoriteRecordWithRetry(favoriteData: favoriteData, attempt: attempt + 1, maxAttempts: maxAttempts, completion: completion)
                        //     }
                        // } else {
                        //     completion(false, error.localizedDescription)
                        // }
                        completion(false, error.localizedDescription)
                    }
                }
            }
        } catch {
            // 🔧 注释掉重试机制：异常时直接返回，不再重试
            // if attempt < maxAttempts - 1 {
            //     DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            //         self.uploadFavoriteRecordWithRetry(favoriteData: favoriteData, attempt: attempt + 1, maxAttempts: maxAttempts, completion: completion)
            //     }
            // } else {
            //     completion(false, error.localizedDescription)
            // }
            completion(false, error.localizedDescription)
        }
    }
    
    // 删除喜欢记录从LeanCloud - 遵循数据存储开发指南，使用 LCQuery
    func deleteFavoriteRecord(userId: String, favoriteUserId: String, completion: @escaping (Bool, String) -> Void) {
        // ✅ 按照开发指南：使用 LCQuery 创建查询
        let query = LCQuery(className: "FavoriteRecord")
        query.whereKey("userId", .equalTo(userId))
        query.whereKey("favoriteUserId", .equalTo(favoriteUserId))
        query.limit = 1
        
        query.find { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let records):
                    if let firstRecord = records.first,
                       let objectId = firstRecord.objectId?.stringValue {
                        // 找到记录，执行删除
                        self.deleteFavoriteRecordByObjectId(objectId: objectId, completion: completion)
                    } else {
                        completion(false, "未找到要删除的记录")
                    }
                case .failure(let error):
                    completion(false, "查询失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // 通过ObjectId删除喜欢记录
    private func deleteFavoriteRecordByObjectId(objectId: String, completion: @escaping (Bool, String) -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/FavoriteRecord/\(objectId)"
        guard let url = URL(string: urlString) else {
            completion(false, "无效的URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, "删除失败: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        completion(true, "")
                    } else {
                        var errorMessage = "删除失败: \(httpResponse.statusCode)"
                        if let data = data {
                            do {
                                let errorJson = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                                if let error = errorJson?["error"] as? String {
                                    errorMessage = "LeanCloud错误: \(error)"
                                }
                            } catch {
                                errorMessage = "删除失败: \(httpResponse.statusCode)"
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
    
    // 取消喜欢记录（标记为已取消）- 带重试机制
    func cancelFavoriteRecord(userId: String, favoriteUserId: String, completion: @escaping (Bool, String) -> Void) {
        // 🔧 注释掉重试机制：直接调用，失败时不再重试
        cancelFavoriteRecordWithRetry(userId: userId, favoriteUserId: favoriteUserId, attempt: 0, maxAttempts: 1, completion: completion)
    }
    
    // 带重试机制的取消喜欢记录 - 遵循数据存储开发指南，使用 LCQuery
    private func cancelFavoriteRecordWithRetry(userId: String, favoriteUserId: String, attempt: Int, maxAttempts: Int, completion: @escaping (Bool, String) -> Void) {
        // ✅ 按照开发指南：使用 LCQuery 创建查询
        let query = LCQuery(className: "FavoriteRecord")
        query.whereKey("userId", .equalTo(userId))
        query.whereKey("favoriteUserId", .equalTo(favoriteUserId))
        query.whereKey("status", .equalTo("active"))
        query.limit = 1
        
        query.find { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let records):
                    if let firstRecord = records.first,
                       let objectId = firstRecord.objectId?.stringValue {
                        // 找到记录，执行状态更新
                        // 🔧 注释掉重试机制：直接调用，失败时不再重试
                        self.updateFavoriteRecordStatusWithRetry(objectId: objectId, attempt: 0, maxAttempts: 1, completion: completion)
                    } else {
                        completion(false, "未找到要取消的记录")
                    }
                case .failure(let error):
                    // 🔧 注释掉重试机制：查询失败时直接返回，不再重试
                    completion(false, "查询失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // 带重试机制的更新喜欢记录状态
    private func updateFavoriteRecordStatusWithRetry(objectId: String, attempt: Int, maxAttempts: Int, completion: @escaping (Bool, String) -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/FavoriteRecord/\(objectId)"
        
        guard let url = URL(string: urlString) else {
            completion(false, "无效的URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        let updateData = ["status": "cancelled"]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: updateData)
        } catch {
            completion(false, "数据编码失败: \(error.localizedDescription)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    // 🔧 注释掉重试机制：网络错误时直接返回，不再重试
                    completion(false, "更新失败: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        completion(true, "")
                    } else {
                        // 🔧 注释掉重试机制：HTTP错误时直接返回，不再重试
                        completion(false, "更新失败: HTTP \(httpResponse.statusCode)")
                    }
                } else {
                    completion(false, "无效的服务器响应")
                }
            }
        }.resume()
    }
    
    // 更新喜欢记录状态（保持向后兼容）
    private func updateFavoriteRecordStatus(objectId: String, completion: @escaping (Bool, String) -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/FavoriteRecord/\(objectId)"
        guard let url = URL(string: urlString) else {
            completion(false, "无效的URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        let updateData = ["status": "cancelled"]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: updateData)
        } catch {
            completion(false, "数据编码失败: \(error.localizedDescription)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    // 更新网络错误
                    completion(false, "更新失败: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        completion(true, "")
                    } else {
                        var errorMessage = "更新失败: \(httpResponse.statusCode)"
                        if let data = data {
                            do {
                                let errorJson = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                                if let error = errorJson?["error"] as? String {
                                    errorMessage = "LeanCloud错误: \(error)"
                                }
                            } catch {
                                errorMessage = "更新失败: \(httpResponse.statusCode)"
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
    
    // 打印FavoriteRecord表中所有内容
    func printAllFavoriteRecords(completion: @escaping (Bool) -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/FavoriteRecord?order=-createdAt&limit=1000"
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 15.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if error != nil {
                    completion(false)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200, let data = data {
                        do {
                            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                            if let results = json?["results"] as? [[String: Any]] {
                                for (_, _) in results.enumerated() {
                                }
                                completion(true)
                            } else {
                                completion(true)
                            }
                        } catch {
                            completion(false)
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
    
    // 获取活跃的喜欢记录 - 遵循数据存储开发指南，使用 LCQuery
    func fetchActiveFavoriteRecords(userId: String, completion: @escaping ([[String: Any]]?, String?) -> Void) {
        // ✅ 按照开发指南：使用 LCQuery 创建查询
        let query = LCQuery(className: "FavoriteRecord")
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
                        dict["favoriteUserId"] = record["favoriteUserId"]?.stringValue ?? ""
                        dict["status"] = record["status"]?.stringValue ?? ""
                        dict["favoriteTime"] = record["favoriteTime"]?.stringValue ?? ""
                        return dict
                    }
                    completion(results, nil)
                case .failure(let error):
                    completion(nil, "获取失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // 获取喜欢指定用户的活跃记录 - 遵循数据存储开发指南，使用 LCQuery
    func fetchActiveFavoriteRecords(favoriteUserId: String, completion: @escaping ([[String: Any]]?, String?) -> Void) {
        // ✅ 按照开发指南：使用 LCQuery 创建查询
        let query = LCQuery(className: "FavoriteRecord")
        query.whereKey("favoriteUserId", .equalTo(favoriteUserId))
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
                        dict["favoriteUserId"] = record["favoriteUserId"]?.stringValue ?? ""
                        dict["status"] = record["status"]?.stringValue ?? ""
                        dict["favoriteTime"] = record["favoriteTime"]?.stringValue ?? ""
                        return dict
                    }
                    completion(results, nil)
                case .failure(let error):
                    completion(nil, "获取失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // 🎯 新增：实时查询单个用户的 favorite 状态 - 遵循数据存储开发指南，使用 LCQuery
    // 🔧 关键区别：爱心按钮对应的是用户（userId），查询基于 userId + favoriteUserId
    func fetchFavoriteStatus(userId: String, favoriteUserId: String, completion: @escaping (Bool, String?) -> Void) {
        
        // ✅ 按照开发指南：使用 LCQuery 创建查询
        let query = LCQuery(className: "FavoriteRecord")
        query.whereKey("userId", .equalTo(userId))
        query.whereKey("favoriteUserId", .equalTo(favoriteUserId))
        query.whereKey("status", .equalTo("active"))
        query.limit = 1
        
        query.find { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let records):
                    let isFavorited = records.first != nil
                    if records.first != nil {
                    }
                    // 如果找到 status = "active" 的记录，返回 true
                    completion(isFavorited, nil)
                case .failure(let error):
                    completion(false, "查询失败: \(error.localizedDescription)")
                }
            }
        }
    }
}
