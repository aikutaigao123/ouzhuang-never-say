//
//  LeanCloudService+LoginRecord.swift
//  NeverSayNo
//
//  Created by AI Assistant on 2024-12-19.
//

import Foundation
import LeanCloud

// MARK: - 登录记录表管理功能
extension LeanCloudService {
    
    // 🎯 新增：防抖机制，避免短时间内重复更新 LoginRecord
    private static var lastLoginRecordUpdateTime: [String: Date] = [:]
    private static let loginRecordUpdateLock = NSLock()
    private static let loginRecordUpdateInterval: TimeInterval = 5.0 // 5秒内只更新一次
    
    // 🎯 新增：检查是否可以更新 LoginRecord（防抖）
    private func canUpdateLoginRecord(userId: String) -> Bool {
        LeanCloudService.loginRecordUpdateLock.lock()
        defer { LeanCloudService.loginRecordUpdateLock.unlock() }
        
        if let lastUpdateTime = LeanCloudService.lastLoginRecordUpdateTime[userId] {
            let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdateTime)
            if timeSinceLastUpdate < LeanCloudService.loginRecordUpdateInterval {
                return false
            }
        }
        
        // 更新最后更新时间
        LeanCloudService.lastLoginRecordUpdateTime[userId] = Date()
        return true
    }
    
    // MARK: - 创建LoginRecord表
    func createLoginRecordTable(completion: @escaping (Bool) -> Void) {
        
        // 通过插入一条测试记录来创建表
        let testData: [String: Any] = [
            "userId": "test_user",
            "userName": "测试用户",
            "userEmail": "test@example.com",
            "loginType": "guest",
            "deviceId": "test_device",
            "loginTime": ISO8601DateFormatter().string(from: Date()),
            "ipAddress": "127.0.0.1",
            "userAgent": "NeverSayNo/1.0",
            "status": "active"
        ]
        
        let urlString = "\(serverUrl)/1.1/classes/LoginRecord"
        
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
                
                let statusCode = httpResponse.statusCode
                
                if statusCode == 201 {
                    completion(true)
                } else {
                    completion(false)
                }
            }.resume()
            
        } catch {
            completion(false)
        }
    }
    
    // MARK: - 记录登录信息
    func recordLogin(userId: String, userName: String, userEmail: String?, loginType: String, deviceId: String, completion: @escaping (Bool) -> Void) {
        
        // 🎯 新增：防抖检查
        guard canUpdateLoginRecord(userId: userId) else {
            completion(false)
            return
        }
        
        // 首先检查表是否存在，如果不存在则创建
        checkLoginRecordTableExists { [weak self] tableExists in
            if !tableExists {
                self?.createLoginRecordTable { tableCreated in
                    if tableCreated {
                        self?.upsertLoginRecord(userId: userId, userName: userName, userEmail: userEmail, loginType: loginType, deviceId: deviceId, completion: completion)
                    } else {
                        completion(false)
                    }
                }
            } else {
                self?.upsertLoginRecord(userId: userId, userName: userName, userEmail: userEmail, loginType: loginType, deviceId: deviceId, completion: completion)
            }
        }
    }
    
    // MARK: - 记录Apple登录信息（包含authData）
    func recordAppleLoginWithAuthData(userId: String, userName: String, userEmail: String?, authData: [String: Any], deviceId: String, completion: @escaping (Bool) -> Void) {
        
        // 🎯 新增：防抖检查
        guard canUpdateLoginRecord(userId: userId) else {
            completion(false)
            return
        }
        
        // 首先检查表是否存在，如果不存在则创建
        checkLoginRecordTableExists { [weak self] tableExists in
            if !tableExists {
                self?.createLoginRecordTable { tableCreated in
                    if tableCreated {
                        self?.upsertAppleLoginRecord(userId: userId, userName: userName, userEmail: userEmail, authData: authData, deviceId: deviceId, completion: completion)
                    } else {
                        completion(false)
                    }
                }
            } else {
                self?.upsertAppleLoginRecord(userId: userId, userName: userName, userEmail: userEmail, authData: authData, deviceId: deviceId, completion: completion)
            }
        }
    }
    
    // MARK: - 插入或更新Apple登录记录（确保每个用户只有一条记录）
    private func upsertAppleLoginRecord(userId: String, userName: String, userEmail: String?, authData: [String: Any], deviceId: String, completion: @escaping (Bool) -> Void) {
        
        
        // 🎯 先查询该用户是否已有记录
        let query = LCQuery(className: "LoginRecord")
        query.whereKey("userId", .equalTo(userId))
        query.limit = 1
        
        query.find { [weak self] result in
            switch result {
            case .success(let records):
                if let existingRecord = records.first {
                    // 🎯 如果已有记录，更新现有记录
                    self?.updateAppleLoginRecord(existingRecord: existingRecord, userId: userId, userName: userName, userEmail: userEmail, authData: authData, deviceId: deviceId, completion: completion)
                } else {
                    // 🎯 如果没有记录，创建新记录
                    self?.insertAppleLoginRecord(userId: userId, userName: userName, userEmail: userEmail, authData: authData, deviceId: deviceId, completion: completion)
                }
            case .failure(_):
                // 查询失败时，尝试创建新记录
                self?.insertAppleLoginRecord(userId: userId, userName: userName, userEmail: userEmail, authData: authData, deviceId: deviceId, completion: completion)
            }
        }
    }
    
    // MARK: - 更新现有Apple登录记录
    private func updateAppleLoginRecord(existingRecord: LCObject, userId: String, userName: String, userEmail: String?, authData: [String: Any], deviceId: String, completion: @escaping (Bool) -> Void) {
        
        do {
            let loginTime = ISO8601DateFormatter().string(from: Date())
            
            // ✅ 按照开发指南：更新属性值
            try existingRecord.set("userName", value: userName)
            try existingRecord.set("userEmail", value: userEmail ?? "")
            try existingRecord.set("loginType", value: "apple")
            try existingRecord.set("deviceId", value: deviceId)
            try existingRecord.set("loginTime", value: loginTime)
            try existingRecord.set("ipAddress", value: getCurrentIPAddress())
            try existingRecord.set("userAgent", value: "NeverSayNo/1.0")
            try existingRecord.set("status", value: "active")
            
            // 🎯 更新 authData（扁平化处理）
            var flattenedAuthData: [String: Any] = [:]
            
            for (key, value) in authData {
                if let nestedDict = value as? [String: Any] {
                    for (nestedKey, nestedValue) in nestedDict {
                        let flattenedKey = "\(key)_\(nestedKey)"
                        flattenedAuthData[flattenedKey] = nestedValue
                    }
                } else {
                    flattenedAuthData[key] = value
                }
            }
            
            // 更新扁平化的 authData 字段
            for (key, value) in flattenedAuthData {
                let prefixedKey = "apple_auth_data_\(key)"
                
                if let stringValue = value as? String {
                    try? existingRecord.set(prefixedKey, value: stringValue)
                } else if let intValue = value as? Int {
                    try? existingRecord.set(prefixedKey, value: intValue)
                } else if let doubleValue = value as? Double {
                    try? existingRecord.set(prefixedKey, value: doubleValue)
                } else if let boolValue = value as? Bool {
                    try? existingRecord.set(prefixedKey, value: boolValue)
                }
            }
            
            // ✅ 按照开发指南：将对象保存到云端
            _ = existingRecord.save { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        completion(true)
                    case .failure(_):
                        // 🎯 新增：如果保存失败，清除防抖记录，允许重试
                        LeanCloudService.loginRecordUpdateLock.lock()
                        LeanCloudService.lastLoginRecordUpdateTime.removeValue(forKey: userId)
                        LeanCloudService.loginRecordUpdateLock.unlock()
                        completion(false)
                    }
                }
            }
        } catch {
            completion(false)
        }
    }
    
    // MARK: - 插入Apple登录记录（包含authData）- 仅在用户没有记录时调用
    private func insertAppleLoginRecord(userId: String, userName: String, userEmail: String?, authData: [String: Any], deviceId: String, completion: @escaping (Bool) -> Void) {
        
        // ✅ 按照开发指南：使用 LCObject 创建对象
        let loginRecord = LCObject(className: "LoginRecord")
        
        do {
            let loginTime = ISO8601DateFormatter().string(from: Date())
            
            // ✅ 按照开发指南：设置属性值
            try loginRecord.set("userId", value: userId)
            try loginRecord.set("userName", value: userName)
            try loginRecord.set("userEmail", value: userEmail ?? "")
            try loginRecord.set("loginType", value: "apple")
            try loginRecord.set("deviceId", value: deviceId)
            try loginRecord.set("loginTime", value: loginTime)
            try loginRecord.set("ipAddress", value: getCurrentIPAddress())
            try loginRecord.set("userAgent", value: "NeverSayNo/1.0")
            try loginRecord.set("status", value: "active")
            
            // 🎯 修复：authData 应该作为对象存储，而不是字符串
            // LeanCloud 期望 apple_auth_data 是 Object 类型
            // 方案：使用字典的键值对直接设置，避免嵌套 LCObject（会导致 $ref 问题）
            
            // 🎯 方案：创建一个新的字典，将嵌套字典扁平化
            // 例如：{ "lc_apple": { "uid": "..." } } -> { "lc_apple_uid": "..." }
            var flattenedAuthData: [String: Any] = [:]
            
            for (key, value) in authData {
                if let nestedDict = value as? [String: Any] {
                    // 处理嵌套字典（如 lc_apple: { uid: "..." }）
                    // 将嵌套字典的键值对扁平化：lc_apple_uid = "..."
                    for (nestedKey, nestedValue) in nestedDict {
                        let flattenedKey = "\(key)_\(nestedKey)"
                        flattenedAuthData[flattenedKey] = nestedValue
                    }
                } else {
                    // 处理简单值，直接添加
                    flattenedAuthData[key] = value
                }
            }
            
            
            // 🎯 修复：不使用嵌套的 LCObject（会导致 $ref 问题）
            // 方案：直接将扁平化的键值对设置到 loginRecord 上，使用 apple_auth_data_ 前缀
            // 这样可以将 authData 的信息存储在 loginRecord 中，而不需要嵌套对象
            
            for (key, value) in flattenedAuthData {
                let prefixedKey = "apple_auth_data_\(key)"
                
                if let stringValue = value as? String {
                    try? loginRecord.set(prefixedKey, value: stringValue)
                } else if let intValue = value as? Int {
                    try? loginRecord.set(prefixedKey, value: intValue)
                } else if let doubleValue = value as? Double {
                    try? loginRecord.set(prefixedKey, value: doubleValue)
                } else if let boolValue = value as? Bool {
                    try? loginRecord.set(prefixedKey, value: boolValue)
                } else {
                }
            }
            
            
            // ✅ 按照开发指南：将对象保存到云端
            _ = loginRecord.save { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        completion(true)
                    case .failure(_):
                        // 🎯 新增：如果保存失败，清除防抖记录，允许重试
                        LeanCloudService.loginRecordUpdateLock.lock()
                        LeanCloudService.lastLoginRecordUpdateTime.removeValue(forKey: userId)
                        LeanCloudService.loginRecordUpdateLock.unlock()
                        completion(false)
                    }
                }
            }
        } catch {
            completion(false)
        }
    }
    
    // MARK: - 插入或更新登录记录（确保每个用户只有一条记录）
    private func upsertLoginRecord(userId: String, userName: String, userEmail: String?, loginType: String, deviceId: String, completion: @escaping (Bool) -> Void) {
        
        
        // 🎯 先查询该用户是否已有记录
        let query = LCQuery(className: "LoginRecord")
        query.whereKey("userId", .equalTo(userId))
        query.limit = 1
        
        query.find { [weak self] result in
            switch result {
            case .success(let records):
                if let existingRecord = records.first {
                    // 🎯 如果已有记录，更新现有记录
                    self?.updateLoginRecord(existingRecord: existingRecord, userId: userId, userName: userName, userEmail: userEmail, loginType: loginType, deviceId: deviceId, completion: completion)
                } else {
                    // 🎯 如果没有记录，创建新记录
                    self?.insertLoginRecord(userId: userId, userName: userName, userEmail: userEmail, loginType: loginType, deviceId: deviceId, completion: completion)
                }
            case .failure(_):
                // 查询失败时，尝试创建新记录
                self?.insertLoginRecord(userId: userId, userName: userName, userEmail: userEmail, loginType: loginType, deviceId: deviceId, completion: completion)
            }
        }
    }
    
    // MARK: - 更新现有登录记录
    private func updateLoginRecord(existingRecord: LCObject, userId: String, userName: String, userEmail: String?, loginType: String, deviceId: String, completion: @escaping (Bool) -> Void) {
        
        do {
            let loginTime = ISO8601DateFormatter().string(from: Date())
            
            // ✅ 按照开发指南：更新属性值
            try existingRecord.set("userName", value: userName)
            try existingRecord.set("userEmail", value: userEmail ?? "")
            try existingRecord.set("loginType", value: loginType)
            try existingRecord.set("deviceId", value: deviceId)
            try existingRecord.set("loginTime", value: loginTime)
            try existingRecord.set("ipAddress", value: getCurrentIPAddress())
            try existingRecord.set("userAgent", value: "NeverSayNo/1.0")
            try existingRecord.set("status", value: "active")
            
            // ✅ 按照开发指南：将对象保存到云端
            _ = existingRecord.save { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        completion(true)
                    case .failure(_):
                        // 🎯 新增：如果保存失败，清除防抖记录，允许重试
                        LeanCloudService.loginRecordUpdateLock.lock()
                        LeanCloudService.lastLoginRecordUpdateTime.removeValue(forKey: userId)
                        LeanCloudService.loginRecordUpdateLock.unlock()
                        completion(false)
                    }
                }
            }
        } catch {
            completion(false)
        }
    }
    
    // MARK: - 插入登录记录（仅在用户没有记录时调用）
    private func insertLoginRecord(userId: String, userName: String, userEmail: String?, loginType: String, deviceId: String, completion: @escaping (Bool) -> Void) {
        
        // ✅ 按照开发指南：使用 LCObject 创建对象
        let loginRecord = LCObject(className: "LoginRecord")
        
        do {
            let loginTime = ISO8601DateFormatter().string(from: Date())
            
            // ✅ 按照开发指南：设置属性值
            try loginRecord.set("userId", value: userId)
            try loginRecord.set("userName", value: userName)
            try loginRecord.set("userEmail", value: userEmail ?? "")
            try loginRecord.set("loginType", value: loginType)
            try loginRecord.set("deviceId", value: deviceId)
            try loginRecord.set("loginTime", value: loginTime)
            try loginRecord.set("ipAddress", value: getCurrentIPAddress())
            try loginRecord.set("userAgent", value: "NeverSayNo/1.0")
            try loginRecord.set("status", value: "active")
            
            // ✅ 按照开发指南：将对象保存到云端
            _ = loginRecord.save { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        completion(true)
                    case .failure(_):
                        // 🎯 新增：如果保存失败，清除防抖记录，允许重试
                        LeanCloudService.loginRecordUpdateLock.lock()
                        LeanCloudService.lastLoginRecordUpdateTime.removeValue(forKey: userId)
                        LeanCloudService.loginRecordUpdateLock.unlock()
                        completion(false)
                    }
                }
            }
        } catch {
            completion(false)
        }
    }
    
    // MARK: - 检查LoginRecord表是否存在
    private func checkLoginRecordTableExists(completion: @escaping (Bool) -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/LoginRecord?limit=1"
        
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                completion(false)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false)
                return
            }
            
            let statusCode = httpResponse.statusCode
            
            // 如果状态码是200，说明表存在
            // 如果状态码是404，说明表不存在
            let tableExists = statusCode == 200
            completion(tableExists)
        }.resume()
    }
    
    // MARK: - 获取用户登录记录 - 遵循数据存储开发指南，使用 LCQuery
    func fetchUserLoginRecords(userId: String, completion: @escaping ([LoginRecord]?) -> Void) {
        // ✅ 按照开发指南：使用 LCQuery 创建查询
        let query = LCQuery(className: "LoginRecord")
        query.whereKey("userId", .equalTo(userId))
        query.whereKey("loginTime", .descending)
        query.limit = 100
        
        query.find { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let records):
                    let loginRecords = records.compactMap { record -> LoginRecord? in
                        var dict: [String: Any] = [:]
                        dict["objectId"] = record.objectId?.stringValue ?? ""
                        dict["userId"] = record["userId"]?.stringValue ?? ""
                        dict["userName"] = record["userName"]?.stringValue ?? ""
                        dict["userEmail"] = nil // 🎯 不再从LoginRecord表读取userEmail，统一从UserNameRecord表读取
                        dict["loginType"] = record["loginType"]?.stringValue ?? ""
                        dict["deviceId"] = record["deviceId"]?.stringValue ?? ""
                        dict["loginTime"] = record["loginTime"]?.stringValue ?? ""
                        dict["ipAddress"] = record["ipAddress"]?.stringValue ?? ""
                        dict["userAgent"] = record["userAgent"]?.stringValue ?? ""
                        dict["status"] = record["status"]?.stringValue ?? ""
                        return LoginRecord.fromDictionary(dict)
                    }
                    completion(loginRecords)
                case .failure:
                    completion(nil)
                }
            }
        }
    }
    
    // MARK: - 获取用户最新登录记录（带缓存和重试机制）
    func fetchLatestLoginRecord(userId: String, completion: @escaping (LoginRecord?) -> Void) {
        
        // 首先检查缓存
        cacheLock.lock()
        if let cachedData = loginRecordCache[userId] {
            let cacheAge = Date().timeIntervalSince(cachedData.timestamp)
            if cacheAge < loginRecordCacheExpirationInterval {
                cacheLock.unlock()
                completion(cachedData.record)
                return
            }
        }
        cacheLock.unlock()
        
        // ✅ 按照开发指南：使用 LCQuery 创建查询（与 fetchUserAvatar 一致）
        let query = LCQuery(className: "LoginRecord")
        query.whereKey("userId", .equalTo(userId))
        query.whereKey("updatedAt", .descending) // 🔧 统一：使用 updatedAt（与用户头像查询一致）
        query.limit = 1
        
        query.find { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let records):
                    if let record = records.first {
                        var dict: [String: Any] = [:]
                        dict["objectId"] = record.objectId?.stringValue ?? ""
                        dict["userId"] = record["userId"]?.stringValue ?? ""
                        dict["userName"] = record["userName"]?.stringValue ?? ""
                        dict["userEmail"] = nil // 🎯 不再从LoginRecord表读取userEmail，统一从UserNameRecord表读取
                        dict["loginType"] = record["loginType"]?.stringValue ?? ""
                        dict["deviceId"] = record["deviceId"]?.stringValue ?? ""
                        dict["loginTime"] = record["loginTime"]?.stringValue ?? ""
                        dict["ipAddress"] = record["ipAddress"]?.stringValue ?? ""
                        dict["userAgent"] = record["userAgent"]?.stringValue ?? ""
                        dict["status"] = record["status"]?.stringValue ?? ""
                        
                        if let loginRecord = LoginRecord.fromDictionary(dict) {
                            // 更新缓存
                            self.cacheLock.lock()
                            self.loginRecordCache[userId] = (loginRecord, Date())
                            self.cacheLock.unlock()
                            completion(loginRecord)
                        } else {
                            completion(nil)
                        }
                    } else {
                        completion(nil)
                    }
                case .failure:
                    completion(nil)
                }
            }
        }
    }
    
    // MARK: - 执行登录记录请求（支持重试）
    private func performLoginRecordRequest(userId: String, urlString: String, retryCount: Int, completion: @escaping (LoginRecord?) -> Void) {
        
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
            
            // 打印HTTP响应信息
            if let httpResponse = response as? HTTPURLResponse {
                
                // 处理429错误（频率限制）
                if httpResponse.statusCode == 429 && retryCount < 3 {
                    let retryDelay = pow(2.0, Double(retryCount)) // 指数退避：1s, 2s, 4s
                    
                    DispatchQueue.global().asyncAfter(deadline: .now() + retryDelay) {
                        self.performLoginRecordRequest(userId: userId, urlString: urlString, retryCount: retryCount + 1, completion: completion)
                    }
                    return
                }
            }
            
            guard let data = data else {
                completion(nil)
                return
            }
            
            // 打印原始响应数据
            
            do {
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                
                let results = json?["results"] as? [[String: Any]] ?? []
                
                
                if results.count > 0 {
                }
                
                let loginRecord: LoginRecord?
                if let firstResult = results.first {
                    loginRecord = LoginRecord.fromDictionary(firstResult)
                    if loginRecord != nil {
                    } else {
                    }
                } else {
                    loginRecord = nil
                }
                
                // 缓存结果
                self.cacheLock.lock()
                self.loginRecordCache[userId] = (record: loginRecord, timestamp: Date())
                self.cacheLock.unlock()
                
                completion(loginRecord)
            } catch {
                completion(nil)
            }
        }.resume()
    }
    
    // MARK: - 内部登录记录相关方法已删除
    
    // MARK: - 获取所有LoginRecord记录（分页获取完整内容）
    // 🎯 新增：为每页查询添加重试机制（与用户头像查询一致）
    func fetchAllLoginRecords(completion: @escaping ([LoginRecord]?) -> Void) {
        
        var allRecords: [LoginRecord] = []
        let pageSize = 1000 // 每页获取1000条记录
        var skip = 0
        var hasMore = true
        
        let dispatchGroup = DispatchGroup()
        
        func fetchPage() {
            guard hasMore else {
                dispatchGroup.leave()
                return
            }
            
            var retryCount = 0
            
            func attemptPage() {
                let urlString = "\(serverUrl)/1.1/classes/LoginRecord?order=-login_time&limit=\(pageSize)&skip=\(skip)"
                
                guard let url = URL(string: urlString) else {
                    if retryCount < LeanCloudRetryConfig.maxRetries {
                        retryCount += 1
                        let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            attemptPage()
                        }
                    } else {
                        completion(nil)
                        dispatchGroup.leave()
                    }
                    return
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                setLeanCloudHeaders(&request)
                request.timeoutInterval = 30.0
                
                URLSession.shared.dataTask(with: request) { data, response, error in
                    if error != nil {
                        // 🎯 修改：查询失败时，如果未达到最大重试次数，触发重试
                        if retryCount < LeanCloudRetryConfig.maxRetries {
                            retryCount += 1
                            let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                attemptPage()
                            }
                        } else {
                            completion(nil)
                            dispatchGroup.leave()
                        }
                        return
                    }
                    
                    guard let data = data else {
                        // 🎯 修改：查询失败时，如果未达到最大重试次数，触发重试
                        if retryCount < LeanCloudRetryConfig.maxRetries {
                            retryCount += 1
                            let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                attemptPage()
                            }
                        } else {
                            completion(nil)
                            dispatchGroup.leave()
                        }
                        return
                    }
                    
                    do {
                        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                        let results = json?["results"] as? [[String: Any]] ?? []
                        
                        
                        let loginRecords = results.compactMap { LoginRecord.fromDictionary($0) }
                        allRecords.append(contentsOf: loginRecords)
                        
                        // 检查是否还有更多数据
                        if results.count < pageSize {
                            hasMore = false
                        } else {
                            skip += pageSize
                        }
                        
                        fetchPage() // 继续获取下一页
                    } catch {
                        // 🎯 修改：查询失败时，如果未达到最大重试次数，触发重试
                        if retryCount < LeanCloudRetryConfig.maxRetries {
                            retryCount += 1
                            let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                attemptPage()
                            }
                        } else {
                            completion(nil)
                            dispatchGroup.leave()
                        }
                    }
                }.resume()
            }
            
            attemptPage()
        }
        
        dispatchGroup.enter()
        fetchPage()
        
        dispatchGroup.notify(queue: .main) {
            completion(allRecords)
        }
    }
    
    // MARK: - 获取所有InternalLoginRecord记录（分页获取完整内容）- 遵循数据存储开发指南，使用 LCQuery
    // 🎯 新增：为每页查询添加重试机制（与用户头像查询一致）
    func fetchAllInternalLoginRecords(completion: @escaping ([InternalLoginRecord]?) -> Void) {
        
        var allRecords: [InternalLoginRecord] = []
        let pageSize = 1000 // 每页获取1000条记录
        var skip = 0
        var hasMore = true
        
        let dispatchGroup = DispatchGroup()
        
        func fetchPage() {
            guard hasMore else {
                dispatchGroup.leave()
                return
            }
            
            var retryCount = 0
            
            func attemptPage() {
                // ✅ 按照开发指南：使用 LCQuery 创建查询
                let query = LCQuery(className: "InternalLoginRecord")
                query.whereKey("loginTime", .descending)
                query.limit = pageSize
                query.skip = skip
                
                query.find { result in
                    switch result {
                    case .success(let records):
                        let internalRecords = records.compactMap { record -> InternalLoginRecord? in
                            var dict: [String: Any] = [:]
                            dict["objectId"] = record.objectId?.stringValue ?? ""
                            dict["userId"] = record["userId"]?.stringValue ?? ""
                            dict["username"] = record["username"]?.stringValue ?? ""
                            // 🎯 不再从LoginRecord表读取userAvatar，统一从UserAvatarRecord表读取
                            dict["userAvatar"] = nil
                            dict["loginType"] = record["loginType"]?.stringValue ?? ""
                            dict["loginTime"] = record["loginTime"]?.stringValue ?? ""
                            dict["deviceId"] = record["deviceId"]?.stringValue ?? ""
                            dict["createdAt"] = record.createdAt?.stringValue ?? ""
                            dict["updatedAt"] = record.updatedAt?.stringValue ?? ""
                            return InternalLoginRecord.fromDictionary(dict)
                        }
                        allRecords.append(contentsOf: internalRecords)
                        
                        // 检查是否还有更多数据
                        if internalRecords.count < pageSize {
                            hasMore = false
                        } else {
                            skip += pageSize
                        }
                        
                        fetchPage() // 继续获取下一页
                    case .failure:
                        // 🎯 修改：查询失败时，如果未达到最大重试次数，触发重试
                        if retryCount < LeanCloudRetryConfig.maxRetries {
                            retryCount += 1
                            let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                attemptPage()
                            }
                        } else {
                            completion(nil)
                            dispatchGroup.leave()
                        }
                    }
                }
            }
            
            attemptPage()
        }
        
        dispatchGroup.enter()
        fetchPage()
        
        dispatchGroup.notify(queue: .main) {
            completion(allRecords)
        }
    }
    
    // MARK: - 获取当前IP地址（简化版本）
    private func getCurrentIPAddress() -> String {
        // 这里可以集成真实的IP获取逻辑
        // 目前返回一个占位符
        return "unknown"
    }
}

// MARK: - LoginRecord数据模型
struct LoginRecord: Codable, Identifiable {
    let id: String
    let objectId: String
    let userId: String
    let userName: String
    let userEmail: String?
    let loginType: String
    let deviceId: String
    let loginTime: String
    let ipAddress: String
    let userAgent: String
    let status: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case objectId = "objectId"
        case userId = "userId"
        case userName = "userName"
        case userEmail = "userEmail"
        case loginType = "loginType"
        case deviceId = "deviceId"
        case loginTime = "loginTime"
        case ipAddress = "ipAddress"
        case userAgent = "userAgent"
        case status
    }
    
    static func fromDictionary(_ dict: [String: Any]) -> LoginRecord? {
        guard let objectId = dict["objectId"] as? String,
              let userId = dict["userId"] as? String,
              let userName = dict["userName"] as? String,
              let loginType = dict["loginType"] as? String,
              let deviceId = dict["deviceId"] as? String,
              let loginTime = dict["loginTime"] as? String,
              let ipAddress = dict["ipAddress"] as? String,
              let userAgent = dict["userAgent"] as? String,
              let status = dict["status"] as? String else {
            return nil
        }
        
        let userEmail = dict["userEmail"] as? String
        
        return LoginRecord(
            id: objectId,
            objectId: objectId,
            userId: userId,
            userName: userName,
            userEmail: userEmail,
            loginType: loginType,
            deviceId: deviceId,
            loginTime: loginTime,
            ipAddress: ipAddress,
            userAgent: userAgent,
            status: status
        )
    }
}

// MARK: - InternalLoginRecord数据模型
struct InternalLoginRecord: Codable, Identifiable {
    let id: String
    let objectId: String
    let userId: String
    let username: String
    let userAvatar: String?
    let loginType: String
    let loginTime: String
    let deviceId: String
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case objectId = "objectId"
        case userId = "userId"
        case username
        case userAvatar = "userAvatar"
        case loginType = "loginType"
        case loginTime = "loginTime"
        case deviceId = "deviceId"
        case createdAt = "createdAt"
        case updatedAt = "updatedAt"
    }
    
    static func fromDictionary(_ dict: [String: Any]) -> InternalLoginRecord? {
        guard let objectId = dict["objectId"] as? String,
              let userId = dict["userId"] as? String,
              let username = dict["username"] as? String,
              let loginType = dict["loginType"] as? String,
              let loginTime = dict["loginTime"] as? String,
              let deviceId = dict["deviceId"] as? String,
              let createdAt = dict["createdAt"] as? String,
              let updatedAt = dict["updatedAt"] as? String else {
            return nil
        }
        
        let userAvatar = dict["userAvatar"] as? String
        
        return InternalLoginRecord(
            id: objectId,
            objectId: objectId,
            userId: userId,
            username: username,
            userAvatar: userAvatar,
            loginType: loginType,
            loginTime: loginTime,
            deviceId: deviceId,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
