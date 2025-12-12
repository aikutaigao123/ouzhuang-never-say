//
//  LeanCloudService+AccountDeletion.swift
//  NeverSayNo
//
//  Created by AI Assistant on 2024-12-19.
//

import Foundation
import LeanCloud

// MARK: - 账号删除相关方法
extension LeanCloudService {
    
    // 检查用户是否有待删除的账号请求
    func checkPendingDeletionRequest(userId: String, completion: @escaping (Bool, String?) -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/AccountDeletionRequest?where={\"user_id\":\"\(userId)\",\"status\":\"pending\"}&limit=1&order=-createdAt"
        
        guard let url = URL(string: urlString) else {
            completion(false, nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        setLeanCloudHeaders(&request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if error != nil {
                    completion(false, nil)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                   let data = data {
                    do {
                        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                        if let results = json?["results"] as? [[String: Any]], !results.isEmpty {
                            let request = results[0]
                            let deletionDate = request["deletion_date"] as? String ?? ""
                            completion(true, deletionDate)
                        } else {
                            completion(false, nil)
                        }
                    } catch {
                        completion(false, nil)
                    }
                } else {
                    completion(false, nil)
                }
            }
        }.resume()
    }
    
    // 取消账号删除请求
    func cancelAccountDeletion(userId: String, completion: @escaping (Bool) -> Void) {
        // 先查找待删除的请求
        let urlString = "\(serverUrl)/1.1/classes/AccountDeletionRequest?where={\"user_id\":\"\(userId)\",\"status\":\"pending\"}&limit=1"
        
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        setLeanCloudHeaders(&request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                completion(false)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
               let data = data {
                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    if let results = json?["results"] as? [[String: Any]], !results.isEmpty {
                        let requestId = results[0]["objectId"] as? String
                        if let requestId = requestId {
                            // 更新请求状态为cancelled
                            self.updateDeletionRequestStatus(requestId: requestId, completion: completion)
                        } else {
                            completion(false)
                        }
                    } else {
                        completion(false)
                    }
                } catch {
                    completion(false)
                }
            } else {
                completion(false)
            }
        }.resume()
    }
    
    // 删除账号删除请求记录
    func deleteAccountDeletionRequest(userId: String, userName: String?, deviceId: String, completion: @escaping (Bool) -> Void) {
        // 构建查询条件：检查 userId、userName 和 deviceId
        var whereConditions: [String] = []
        whereConditions.append("\"status\":\"pending\"")
        
        // 添加 userId 条件
        whereConditions.append("\"userId\":\"\(userId)\"")
        
        // 如果有 userName，也添加 userName 条件
        if let userName = userName, !userName.isEmpty {
            whereConditions.append("\"userName\":\"\(userName)\"")
        }
        
        // 添加 deviceId 条件
        whereConditions.append("\"deviceId\":\"\(deviceId)\"")
        
        // 构建 where 条件：使用 $or 来匹配任意一个条件
        let whereString = "{\"$or\":[{\"userId\":\"\(userId)\"},{\"userName\":\"\(userName ?? "")\"},{\"deviceId\":\"\(deviceId)\"}],\"status\":\"pending\"}"
        
        let urlString = "\(serverUrl)/1.1/classes/AccountDeletionRequest?where=\(whereString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&limit=1"
        
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        setLeanCloudHeaders(&request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                completion(false)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
               let data = data {
                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    if let results = json?["results"] as? [[String: Any]], !results.isEmpty {
                        let requestId = results[0]["objectId"] as? String
                        if let requestId = requestId {
                            // 删除记录
                            self.deleteAccountDeletionRequestRecord(objectId: requestId, completion: completion)
                        } else {
                            completion(false)
                        }
                    } else {
                        completion(false)
                    }
                } catch {
                    completion(false)
                }
            } else {
                completion(false)
            }
        }.resume()
    }
    
    // 删除 AccountDeletionRequest 记录
    private func deleteAccountDeletionRequestRecord(objectId: String, completion: @escaping (Bool) -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/AccountDeletionRequest/\(objectId)"
        
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 30.0
        
        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if error != nil {
                    completion(false)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        completion(true)
                    } else {
                        completion(false)
                    }
                } else {
                    completion(false)
                }
            }
        }.resume()
    }
    
    // 更新删除请求状态
    private func updateDeletionRequestStatus(requestId: String, completion: @escaping (Bool) -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/AccountDeletionRequest/\(requestId)"
        
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        
        // 准备更新数据
        let updateData: [String: Any] = [
            "status": "cancelled",
            "cancelledTime": ISO8601DateFormatter().string(from: Date())
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        setLeanCloudHeaders(&request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: updateData)
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
                    if httpResponse.statusCode == 200 {
                        completion(true)
                    } else {
                        completion(false)
                    }
                } else {
                    completion(false)
                }
            }
        }.resume()
    }
    
    // 发送账号删除请求 - 使用 LCObject
    func requestAccountDeletion(userId: String, userName: String?, deviceId: String, completion: @escaping (Bool) -> Void) {
        // ✅ 使用 LCObject 创建对象
        let deletionRequest = LCObject(className: "AccountDeletionRequest")
        
        // 确保包含头像
        let loginType = UserDefaults.standard.string(forKey: "loginType") ?? "guest"
        let deletionUserAvatar = UserDefaults.standard.string(forKey: "custom_avatar_\(userId)") ?? UserAvatarUtils.defaultAvatar(for: loginType)
        
        do {
            try deletionRequest.set("userId", value: userId)
            try deletionRequest.set("userName", value: userName ?? "未知用户")
            try deletionRequest.set("userAvatar", value: deletionUserAvatar)
            try deletionRequest.set("deviceId", value: deviceId)
            try deletionRequest.set("request_time", value: ISO8601DateFormatter().string(from: Date()))
            try deletionRequest.set("status", value: "pending")
            try deletionRequest.set("deletion_date", value: ISO8601DateFormatter().string(from: Date().addingTimeInterval(7 * 24 * 3600)))
            
            _ = deletionRequest.save { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        completion(true)
                    case .failure(let error):
                        // 如果是 404 错误（表不存在），尝试创建表
                        if error.code == 404 {
                            self.createAccountDeletionRequestTable { tableCreated in
                                if tableCreated {
                                    // 表创建成功后，重新尝试请求账户删除
                                    self.requestAccountDeletion(userId: userId, userName: userName, deviceId: deviceId, completion: completion)
                                } else {
                                    completion(false)
                                }
                            }
                        } else {
                            completion(false)
                        }
                    }
                }
            }
        } catch {
            completion(false)
        }
    }
    
    // MARK: - 立即删除用户所有数据
    
    /// 删除用户在所有表中的数据
    /// - Parameters:
    ///   - userId: 用户ID
    ///   - progressCallback: 进度回调 (currentTable: 当前正在删除的表, completedTables: 已完成的表数, totalTables: 总表数, deletedCount: 当前表已删除的记录数)
    ///   - completion: 完成回调 (success: 是否至少一个表删除成功, deletedCounts: 每个表删除的记录数, errors: 错误信息)
    func deleteAllUserDataFromTables(
        userId: String,
        progressCallback: ((String, Int, Int, Int) -> Void)? = nil,
        completion: @escaping (Bool, [String: Int], [String: String]) -> Void
    ) {
        var deletedCounts: [String: Int] = [:]
        var errors: [String: String] = [:]
        let group = DispatchGroup()
        let lock = NSLock() // 保护共享数据
        
        // 在主线程和后台线程都输出日志，确保能看到
        DispatchQueue.main.async {
            NSLog("🗑️ [AccountDeletion] 开始删除用户数据: %@", userId)
        }
        NSLog("🗑️ [AccountDeletion] 开始删除用户数据: %@", userId)
        
        // 单字段查询表配置
        let singleFieldTables: [(tableName: String, fieldName: String)] = [
            ("LoginRecord", "userId"),
            ("UserScore", "userId"),
            ("UserAvatarRecord", "userId"),
            ("UserNameRecord", "userId"),
            ("LocationRecord", "userId"),
            ("Recommendation", "userId"),
            ("DiamondRecord", "userId"),
            ("OwnedAvatarsRecord", "userId"),
            ("Blacklist", "reported_user_id")
        ]
        
        // 多字段查询表配置
        let multiFieldTables: [(tableName: String, fields: [String])] = [
            ("MatchRecord", ["user1Id", "user2Id"]),
            ("Message", ["senderId", "receiverId"]),
            ("FavoriteRecord", ["userId", "favoriteUserId"]),
            ("LikeRecord", ["userId", "likedUserId"]),
            ("ReportRecord", ["reported_user_id", "reporter_user_id"]),
            ("localBlacklist", ["reported_user_id", "current_user_id"])
        ]
        
        // 计算总表数
        let totalTables = singleFieldTables.count + multiFieldTables.count + 1 // +1 for ProcessedReportRecord
        var completedTables = 0
        
        // 删除单字段表（添加延迟，避免429错误）
        for (index, tableConfig) in singleFieldTables.enumerated() {
            group.enter()
            
            // 🎯 添加延迟：每个表间隔 1/17 秒（约 0.0588 秒），避免并发请求过多
            let delay = Double(index) / 17.0
            
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + delay) {
                // 通知进度：开始删除该表
                DispatchQueue.main.async {
                    progressCallback?(tableConfig.tableName, completedTables, totalTables, 0)
                }
                
                self.deleteRecordsFromSingleFieldTable(
                tableName: tableConfig.tableName,
                fieldName: tableConfig.fieldName,
                userId: userId,
                progressCallback: { deletedCount in
                    // 更新当前表的删除数量
                    DispatchQueue.main.async {
                        progressCallback?(tableConfig.tableName, completedTables, totalTables, deletedCount)
                    }
                }
            ) { success, count, error in
                lock.lock()
                defer { lock.unlock() }
                
                completedTables += 1
                
                if success {
                    deletedCounts[tableConfig.tableName] = count
                } else {
                    errors[tableConfig.tableName] = error ?? "删除失败"
                }
                
                // 通知进度：该表删除完成
                DispatchQueue.main.async {
                    progressCallback?(tableConfig.tableName, completedTables, totalTables, count)
                }
                
                    group.leave()
                }
            }
        }
        
        // 删除多字段表（添加延迟，避免429错误）
        let singleFieldCount = singleFieldTables.count
        for (index, tableConfig) in multiFieldTables.enumerated() {
            group.enter()
            
            // 🎯 添加延迟：在单字段表之后继续延迟，每个表间隔 1/17 秒
            let delay = Double(singleFieldCount + index) / 17.0
            
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + delay) {
                // 通知进度：开始删除该表
                DispatchQueue.main.async {
                    progressCallback?(tableConfig.tableName, completedTables, totalTables, 0)
                }
                
                self.deleteRecordsFromMultiFieldTable(
                tableName: tableConfig.tableName,
                fields: tableConfig.fields,
                userId: userId,
                progressCallback: { deletedCount in
                    DispatchQueue.main.async {
                        progressCallback?(tableConfig.tableName, completedTables, totalTables, deletedCount)
                    }
                }
            ) { success, count, error in
                lock.lock()
                defer { lock.unlock() }
                
                completedTables += 1
                
                if success {
                    deletedCounts[tableConfig.tableName] = count
                } else {
                    errors[tableConfig.tableName] = error ?? "删除失败"
                }
                
                // 通知进度：该表删除完成
                DispatchQueue.main.async {
                    progressCallback?(tableConfig.tableName, completedTables, totalTables, count)
                }
                
                    group.leave()
                }
            }
        }
        
        // 特殊处理：ProcessedReportRecord（两个字段都需要删除，最后执行）
        group.enter()
        
        // 🎯 延迟：最后一个表，间隔 1/17 秒
        let processedDelay = Double(singleFieldTables.count + multiFieldTables.count) / 17.0
        
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + processedDelay) {
            // 通知进度：开始删除该表
            DispatchQueue.main.async {
                progressCallback?("ProcessedReportRecord", completedTables, totalTables, 0)
            }
            
            self.deleteRecordsFromMultiFieldTable(
            tableName: "ProcessedReportRecord",
            fields: ["original_reported_user_id", "processor_user_id"],
            userId: userId,
            progressCallback: { deletedCount in
                DispatchQueue.main.async {
                    progressCallback?("ProcessedReportRecord", completedTables, totalTables, deletedCount)
                }
            }
        ) { success, count, error in
            lock.lock()
            defer { lock.unlock() }
            
            completedTables += 1
            
            if success {
                deletedCounts["ProcessedReportRecord"] = count
            } else {
                errors["ProcessedReportRecord"] = error ?? "删除失败"
            }
            
            // 通知进度：该表删除完成
            DispatchQueue.main.async {
                progressCallback?("ProcessedReportRecord", completedTables, totalTables, count)
            }
            
            group.leave()
            }
        }
        
        // 等待所有删除完成
        group.notify(queue: .main) {
            // 只要有一个表删除成功，就认为整体成功
            let overallSuccess = !deletedCounts.isEmpty
            completion(overallSuccess, deletedCounts, errors)
        }
    }
    
    /// 删除单字段表中的所有记录（使用分批删除策略，避免SDK崩溃）
    private func deleteRecordsFromSingleFieldTable(
        tableName: String,
        fieldName: String,
        userId: String,
        progressCallback: ((Int) -> Void)? = nil,
        completion: @escaping (Bool, Int, String?) -> Void
    ) {
        // 分批查询和删除，避免一次性处理太多对象
        self.deleteRecordsFromTableWithPagination(
            tableName: tableName,
            fieldName: fieldName,
            userId: userId,
            skip: 0,
            limit: 50, // 每批最多50个
            totalDeleted: 0,
            retryCount: 0,
            maxRetries: 3,
            progressCallback: progressCallback,
            completion: completion
        )
    }
    
    /// 分页删除记录（递归调用，直到所有记录删除完成，带429重试机制）
    private func deleteRecordsFromTableWithPagination(
        tableName: String,
        fieldName: String,
        userId: String,
        skip: Int,
        limit: Int,
        totalDeleted: Int,
        retryCount: Int = 0,
        maxRetries: Int = 3,
        progressCallback: ((Int) -> Void)? = nil,
        completion: @escaping (Bool, Int, String?) -> Void
    ) {
        let query = LCQuery(className: tableName)
        query.whereKey(fieldName, .equalTo(userId))
        query.limit = limit
        query.skip = skip
        
        // 查询当前批次的记录
        let logMessage = "🔍 [AccountDeletion] \(tableName): 开始查询 (field=\(fieldName), userId=\(userId), skip=\(skip), limit=\(limit))"
        NSLog("%@", logMessage)
        _ = query.find { result in
            switch result {
            case .success(objects: let objects):
                if objects.isEmpty {
                    // 没有更多记录，完成删除
                    completion(true, totalDeleted, nil)
                    return
                }
                
                // 打印查询到的记录信息（用于调试）
                let foundMsg = "🔍 [AccountDeletion] \(tableName): 查询到 \(objects.count) 条记录 (skip=\(skip), limit=\(limit), userId=\(userId))"
                NSLog("%@", foundMsg)
                for (index, obj) in objects.prefix(3).enumerated() {
                    let objId = obj.objectId?.stringValue ?? "unknown"
                    let userIdValue = obj[fieldName]?.stringValue ?? "unknown"
                    let detailMsg = "   [\(index+1)] objectId=\(objId), \(fieldName)=\(userIdValue)"
                    NSLog("%@", detailMsg)
                }
                
                // 小批量删除，避免SDK崩溃（如果只有1个对象，直接删除；否则分批删除）
                if objects.count == 1 {
                    // 单个对象直接删除
                    let objId = objects[0].objectId?.stringValue ?? "unknown"
                    let deleteStartMsg = "🗑️ [AccountDeletion] \(tableName): 尝试删除单个对象 objectId=\(objId)"
                    NSLog("%@", deleteStartMsg)
                    objects[0].delete { deleteResult in
                        switch deleteResult {
                        case .success:
                            let newTotalDeleted = totalDeleted + 1
                            let deleteSuccessMsg = "✅ [AccountDeletion] \(tableName): 成功删除对象 objectId=\(objId)"
                            NSLog("%@", deleteSuccessMsg)
                            // 通知进度
                            progressCallback?(newTotalDeleted)
                            // 继续查询下一批
                            self.deleteRecordsFromTableWithPagination(
                                tableName: tableName,
                                fieldName: fieldName,
                                userId: userId,
                                skip: skip + limit,
                                limit: limit,
                                totalDeleted: newTotalDeleted,
                                retryCount: 0,
                                maxRetries: maxRetries,
                                progressCallback: progressCallback,
                                completion: completion
                            )
                        case .failure(let error):
                            // 🎯 429错误重试机制：延迟后重试
                            if error.code == 429 && retryCount < maxRetries {
                                let retryDelay = Double(retryCount + 1) * 2.0 // 2秒、4秒、6秒
                                let retryMsg = "⏳ [AccountDeletion] \(tableName): 删除遇到429错误，\(retryDelay)秒后重试 (第\(retryCount + 1)次/共\(maxRetries)次)"
                                NSLog("%@", retryMsg)
                                
                                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + retryDelay) {
                                    self.deleteRecordsFromTableWithPagination(
                                        tableName: tableName,
                                        fieldName: fieldName,
                                        userId: userId,
                                        skip: skip,
                                        limit: limit,
                                        totalDeleted: totalDeleted,
                                        retryCount: retryCount + 1,
                                        maxRetries: maxRetries,
                                        progressCallback: progressCallback,
                                        completion: completion
                                    )
                                }
                            } else {
                                let deleteFailMsg = "❌ [AccountDeletion] \(tableName): 删除失败 objectId=\(objId), error=\(error.localizedDescription), code=\(error.code)"
                                NSLog("%@", deleteFailMsg)
                                // 即使删除失败，也继续删除下一批
                                progressCallback?(totalDeleted)
                                self.deleteRecordsFromTableWithPagination(
                                    tableName: tableName,
                                    fieldName: fieldName,
                                    userId: userId,
                                    skip: skip + limit,
                                    limit: limit,
                                    totalDeleted: totalDeleted,
                                    retryCount: 0,
                                    maxRetries: maxRetries,
                                    progressCallback: progressCallback,
                                    completion: completion
                                )
                            }
                        }
                    }
                } else {
                    // 多个对象，分批删除（每批最多20个，避免SDK崩溃）
                    let batchSize = 20
                    let deleteGroup = DispatchGroup()
                    var batchDeleted = 0
                    var batchError: String? = nil
                    
                    for i in stride(from: 0, to: objects.count, by: batchSize) {
                        let endIndex = min(i + batchSize, objects.count)
                        let batch = Array(objects[i..<endIndex])
                        _ = batch.compactMap { $0.objectId?.stringValue }
                        
                        deleteGroup.enter()
                        _ = LCObject.delete(batch) { deleteResult in
                            switch deleteResult {
                            case .success:
                                batchDeleted += batch.count
                            case .failure(let error):
                                // 🎯 429错误：记录但不立即失败，等待重试
                                if error.code == 429 {
                                    let retryMsg = "⏳ [AccountDeletion] \(tableName): 批量删除遇到429错误 (第 \(i/batchSize + 1) 批)，将在后续重试"
                                    NSLog("%@", retryMsg)
                                }
                                if batchError == nil {
                                    batchError = error.localizedDescription
                                }
                            }
                            deleteGroup.leave()
                        }
                    }
                    
                    deleteGroup.notify(queue: .main) {
                        let newTotalDeleted = totalDeleted + batchDeleted
                        // 通知进度
                        progressCallback?(newTotalDeleted)
                        // 继续查询下一批
                        self.deleteRecordsFromTableWithPagination(
                            tableName: tableName,
                            fieldName: fieldName,
                            userId: userId,
                            skip: skip + limit,
                            limit: limit,
                            totalDeleted: newTotalDeleted,
                            retryCount: 0,
                            maxRetries: 3,
                            progressCallback: progressCallback,
                            completion: completion
                        )
                    }
                }
                
            case .failure(let error):
                // 🎯 429错误重试机制：延迟后重试查询
                if error.code == 429 && retryCount < maxRetries {
                    let retryDelay = Double(retryCount + 1) * 2.0 // 2秒、4秒、6秒
                    let retryMsg = "⏳ [AccountDeletion] \(tableName): 查询遇到429错误，\(retryDelay)秒后重试 (第\(retryCount + 1)次/共\(maxRetries)次)"
                    NSLog("%@", retryMsg)
                    
                    DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + retryDelay) {
                        self.deleteRecordsFromTableWithPagination(
                            tableName: tableName,
                            fieldName: fieldName,
                            userId: userId,
                            skip: skip,
                            limit: limit,
                            totalDeleted: totalDeleted,
                            retryCount: retryCount + 1,
                            maxRetries: maxRetries,
                            progressCallback: progressCallback,
                            completion: completion
                        )
                    }
                    return
                }
                
                // 404表示表不存在，视为成功（没有数据可删）
                if error.code == 404 {
                    completion(true, totalDeleted, nil)
                } else {
                    completion(false, totalDeleted, error.localizedDescription)
                }
            }
        }
    }
    
    /// 删除多字段表中的所有记录（使用并行查询 + 分页，确保彻底删除）
    private func deleteRecordsFromMultiFieldTable(
        tableName: String,
        fields: [String],
        userId: String,
        progressCallback: ((Int) -> Void)? = nil,
        completion: @escaping (Bool, Int, String?) -> Void
    ) {
        guard !fields.isEmpty else {
            completion(false, 0, "字段列表为空")
            return
        }
        
        // 为每个字段使用分页查询，确保所有数据都被删除
        var totalDeleted = 0
        var errors: [String] = []
        let fieldDeleteGroup = DispatchGroup()
        let lock = NSLock()
        
        // 为每个字段执行分页删除
        for field in fields {
            fieldDeleteGroup.enter()
            
            // 对该字段进行分页删除
            self.deleteRecordsFromTableWithPagination(
                tableName: tableName,
                fieldName: field,
                userId: userId,
                skip: 0,
                limit: 50,
                totalDeleted: 0,
                progressCallback: progressCallback
            ) { success, count, error in
                lock.lock()
                defer { lock.unlock() }
                
                if success {
                    totalDeleted += count
                } else if let error = error {
                    errors.append("\(field): \(error)")
                }
                fieldDeleteGroup.leave()
            }
        }
        
        // 等待所有字段的删除完成
        fieldDeleteGroup.notify(queue: .main) {
            // 由于不同字段可能查询到相同的记录，实际删除数可能小于 totalDeleted
            // 但这是正常的，因为LeanCloud会自动去重
            if totalDeleted > 0 || errors.isEmpty {
                completion(true, totalDeleted, errors.isEmpty ? nil : errors.joined(separator: "; "))
            } else {
                completion(false, 0, errors.joined(separator: "; "))
            }
        }
    }
}
