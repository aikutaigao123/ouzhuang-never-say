import Foundation
import UIKit
import CoreLocation
import LeanCloud

// LeanCloud服务类
class LeanCloudService: ObservableObject {
    // LeanCloud配置 - 使用配置管理类
    internal let appId: String
    internal let appKey: String
    let serverUrl: String
    
    // MARK: - 全局缓存管理
    internal var userAvatarCache: [String: (avatar: String, timestamp: Date)] = [:]
    internal var userNameCache: [String: (name: String, timestamp: Date)] = [:]
    internal var userEmailCache: [String: (email: String, timestamp: Date)] = [:]
    internal var userDiamondsCache: [String: (diamonds: Int, timestamp: Date)] = [:] // 🔧 新增：钻石缓存
    internal var loginRecordCache: [String: (record: LoginRecord?, timestamp: Date)] = [:]
    // internalLoginRecordCache 已删除（内部用户登录已移除）
    internal var onlineStatusCache: [String: (isOnline: Bool, lastActiveTime: Date?, timestamp: Date)] = [:]
    internal var blacklistCache: [String: (blacklist: [String], timestamp: Date)] = [:] // 🎯 黑名单缓存（按用户隔离）
    internal let cacheExpirationInterval: TimeInterval = 3 // 3秒缓存过期（测试用）
    internal let loginRecordCacheExpirationInterval: TimeInterval = 60 // 1分钟缓存过期（登录记录变化频繁）
    internal let onlineStatusCacheExpirationInterval: TimeInterval = 30 // 30秒缓存过期（在线状态变化频繁）
    internal let blacklistCacheExpirationInterval: TimeInterval = 300 // 5分钟缓存过期（黑名单变化不频繁）
    internal let cacheLock = NSLock()
    
    // MARK: - 防重复调用管理
    internal var isAutoDetectingMatchRecords = false
    internal var uploadingUserNameForUsers: Set<String> = [] // 正在上传用户名的用户ID集合
    internal let uploadingUserNameLock = NSLock() // 保护 uploadingUserNameForUsers 的锁
    internal var isUploadingLocation = false // 🎯 新增：防止重复上传LocationRecord
    internal let uploadingLocationLock = NSLock() // 保护 isUploadingLocation 的锁
    
    // 单例模式
    static let shared = LeanCloudService()
    
    private init() {
        // 从配置管理类获取API密钥
        let config = Configuration.shared
        
        // 使用配置（即使无效也会设置默认值，避免编译错误）
        // 应用将在运行时检测到配置问题并提示用户
        self.appId = config.leanCloudAppId
        self.appKey = config.leanCloudAppKey
        self.serverUrl = config.leanCloudServerUrl
        
        // 验证配置有效性（仅在DEBUG模式下检查）
        #if DEBUG
        if !config.isValid {
        }
        #endif
        
        // 注释掉自动缓存清理定时器，改为在更新时手动清理
        // startCacheCleanupTimer()
    }
    
    // MARK: - IM 即时通讯触发器管理
    /**
     * IM 触发器管理
     */
    private var imTrigger: LeanCloudIMTrigger {
        return LeanCloudIMTrigger.shared
    }
    
    /**
     * 初始化 IM 服务
     */
    // IM service methods moved to LeanCloudService+IMService.swift
    
    // 计算考虑时区的实际时间差（分钟）
    private func calculateTimeDifferenceWithTimezone(
        recordTime: Date,
        recordLongitude: Double,
        currentLongitude: Double,
        currentTime: Date
    ) -> Double {
        // 计算两个位置的时区偏移量（小时）
        let recordTimezoneOffset = Int(round(recordLongitude / 15.0))
        let currentTimezoneOffset = Int(round(currentLongitude / 15.0))
        
        // 限制在合理范围内
        let clampedRecordOffset = max(-12, min(14, recordTimezoneOffset))
        let clampedCurrentOffset = max(-12, min(14, currentTimezoneOffset))
        
        // 计算时区差（小时）
        let timezoneDifference = Double(clampedRecordOffset - clampedCurrentOffset)
        
        // 将记录时间转换为当前用户时区的时间
        let adjustedRecordTime = recordTime.addingTimeInterval(timezoneDifference * 3600)
        
        // 计算实际时间差（分钟）
        let actualTimeDifference = abs(currentTime.timeIntervalSince(adjustedRecordTime)) / 60
        
        return actualTimeDifference
    }
    
    // ACL权限管理
    // ACL权限管理已移至 LeanCloudService+Headers.swift
    
    // 设置LeanCloud请求头
    // 请求头设置已移至 LeanCloudService+Headers.swift
    
    // 位置记录操作
    // 位置记录操作已移至 LeanCloudService+Location.swift
    
    // 处理403 Forbidden错误 - 详细的错误诊断
    func handle403ForbiddenError(_ request: URLRequest, _ httpResponse: HTTPURLResponse, _ data: Data, operation: String) {
        #if DEBUG
        for (_, _) in request.allHTTPHeaderFields ?? [:] {
        }
        for (_, _) in httpResponse.allHeaderFields {
        }
        
        if String(data: data, encoding: .utf8) != nil {
            if data.count < 1000 {
            }
        }
        
        #endif
    }
    
    // 处理403错误（别名函数，保持向后兼容）
    private func handle403Error(_ httpResponse: HTTPURLResponse, _ data: Data?, _ request: URLRequest, _ operation: String) {
        if let data = data {
            handle403ForbiddenError(request, httpResponse, data, operation: operation)
        }
    }
    
    // 处理网络错误 - 详细的错误诊断
    func handleNetworkError(_ error: Error, _ request: URLRequest, operation: String) {
        #if DEBUG
        
        if let nsError = error as NSError? {
            
            if nsError.userInfo[NSUnderlyingErrorKey] as? NSError != nil {
            }
        }
        
        #endif
    }
    
    // 验证API配置
    func validateAPIConfig() -> Bool {
        if appId.isEmpty {
            return false
        }
        
        if appKey.isEmpty {
            return false
        }
        
        if serverUrl.isEmpty {
            return false
        }
        
        if !serverUrl.hasPrefix("https://") {
            return false
        }
        
        return true
    }
    
    // 验证API密钥（别名函数，保持向后兼容）
    private func validateApiCredentials() -> Bool {
        return validateAPIConfig()
    }
    
    // 测试API配置
    // testAPIConfig method moved to LeanCloudService+ConnectionTesting.swift
    
    // 发送位置数据到LeanCloud
    // sendLocation method moved to LeanCloudService+LocationService.swift
    
    // fetchLocations method moved to LeanCloudService+LocationService.swift
    
    // fetchRandomLocation method moved to LeanCloudService+LocationService.swift
    
    /// 获取待删除用户ID列表
    func fetchPendingDeletionUserIds(completion: @escaping ([String]?, String?) -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/AccountDeletionRequest?where={\"status\":\"pending\"}&keys=user_id,device_id,user_name,userId,deviceId,userName&limit=1000"
        guard let url = URL(string: urlString) else {
            completion(nil, "无效的URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 15.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                DispatchQueue.main.async { completion(nil, error.localizedDescription) }
                return
            }
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                DispatchQueue.main.async { completion(nil, "无效的服务器响应") }
                return
            }
            if httpResponse.statusCode == 200 {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let results = json["results"] as? [[String: Any]] {
                        var identifiers: Set<String> = []
                        
                        for record in results {
                            if let userId = (record["userId"] as? String) ?? (record["user_id"] as? String),
                               !userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                identifiers.insert(userId)
                            }
                            
                            if let userName = (record["userName"] as? String) ?? (record["user_name"] as? String),
                               !userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                identifiers.insert(userName)
                            }
                            
                            if let deviceId = (record["deviceId"] as? String) ?? (record["device_id"] as? String),
                               !deviceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                identifiers.insert(deviceId)
                            }
                        }
                        
                        DispatchQueue.main.async { completion(Array(identifiers), nil) }
                    } else {
                        DispatchQueue.main.async { completion([], nil) }
                    }
                } catch {
                    DispatchQueue.main.async { completion(nil, error.localizedDescription) }
                }
            } else {
                DispatchQueue.main.async { completion(nil, "服务器错误: \(httpResponse.statusCode)") }
            }
        }.resume()
    }
    
    // MARK: - 消息按钮专用优化方法
    
    // batchFetchUserDataForMessages method moved to LeanCloudService+UserDataManagement.swift
    
    // MARK: - 历史按钮专用优化方法
    
    // batchFetchUserDataForHistory method moved to LeanCloudService+UserDataManagement.swift
    // fetchUserLastOnlineTime method moved to LeanCloudService+UserDataManagement.swift
    
    // MARK: - 内部账号登录记录已删除
    
    // MARK: - 通用登录记录上传方法
    func uploadLoginRecord(userId: String, username: String, deviceId: String, loginType: String, completion: @escaping (Bool, String?) -> Void) {
        
        // 使用LeanCloud的创建对象API
        let urlString = "\(serverUrl)/1.1/classes/LoginRecord"
        
        guard let url = URL(string: urlString) else {
            completion(false, "服务器地址无效")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        // 获取用户头像信息（优先从UserAvatarRecord读取最新头像）
        let userDefaults = UserDefaults.standard
        let currentUserId = userDefaults.string(forKey: "current_user_id")
        let loginType = userDefaults.string(forKey: "loginType") ?? "guest"
        var userAvatar = UserAvatarUtils.defaultAvatar(for: loginType) // 默认头像
        
        if let userId = currentUserId {
            // 优先从UserDefaults读取，如果为空则使用默认头像
            userAvatar = userDefaults.string(forKey: "custom_avatar_\(userId)") ?? UserAvatarUtils.defaultAvatar(for: loginType)
        }
        
        // 构建登录记录数据
        let loginTimeString = ISO8601DateFormatter().string(from: Date())
        let loginRecordData: [String: Any] = [
            "userId": userId,
            "username": username,
            "deviceId": deviceId,
            "loginTime": loginTimeString,
            "loginType": loginType, // 使用传入的登录类型
            "userAvatar": userAvatar // 添加用户头像
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: loginRecordData)
        } catch {
            completion(false, "数据格式错误，请重试")
            return
        }
        
            URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if error != nil {
                    completion(false, "网络连接失败，请检查网络设置")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    
                    if httpResponse.statusCode == 201 {
                        if data != nil {
                            do {
                                let json = try JSONSerialization.jsonObject(with: data!) as? [String: Any]
                                if json?["objectId"] as? String != nil {
                                    completion(true, nil)
                                } else {
                                    completion(false, "服务器响应格式异常")
                                }
                            } catch {
                                completion(false, "解析服务器响应失败")
                            }
                        } else {
                            completion(false, "服务器响应为空")
                        }
                    } else {
                        let errorMessage = "服务器错误，状态码: \(httpResponse.statusCode)"
                        completion(false, errorMessage)
                    }
                } else {
                    completion(false, "服务器响应异常，请重试")
                }
            }
        }.resume()
    }
    
    // MARK: - 用户协议和隐私政策相关方法
    // 举报记录相关功能已移至以下扩展文件：
    // - LeanCloudService+ReportRecords.swift (数据模型和获取功能)
    // - LeanCloudService+ReportProcessing.swift (处理功能)
    // 头像列表相关功能已移至以下扩展文件：
    // - LeanCloudService+OwnedAvatarsFetch.swift (获取功能)
    // - LeanCloudService+OwnedAvatarsUpdate.swift (更新功能)
    // - LeanCloudService+OwnedAvatarsTable.swift (表管理功能)
    // - LeanCloudService+OwnedAvatarsPerform.swift (执行更新功能)
    // - LeanCloudService+OwnedAvatarsCreate.swift (创建功能)
    // - LeanCloudService+OwnedAvatarsModify.swift (修改功能)
    // - LeanCloudService+OwnedAvatarsBatch.swift (批量处理功能)
    // 应用内容相关功能已移至以下扩展文件：
    // - LeanCloudService+AppContent.swift (用户协议和隐私政策)
    // - LeanCloudService+FavoriteRecords.swift (喜欢记录管理)
    // - LeanCloudService+Messages.swift (消息管理)
    // - LeanCloudService+TableManagement.swift (表创建和测试记录删除)
    // - LeanCloudService+LikeRecords.swift (喜欢记录管理)
    
    // MARK: - 用户名管理
    // 用户名相关功能已移至以下扩展文件：
    // - LeanCloudService+UserNameCreate.swift (创建用户名记录)
    // - LeanCloudService+UserNameUpdate.swift (更新用户名记录)
    // - LeanCloudService+UserNameFetch.swift (获取用户名和状态管理)
    // - LeanCloudService+UserNameBatch.swift (批量获取用户名)
    
    // 删除FavoriteRecord测试记录
    private func deleteFavoriteTestRecord(objectId: String, completion: @escaping () -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/FavoriteRecord/\(objectId)"
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
    
    // 创建ReportRecord表
    private func createReportRecordTable(completion: @escaping (Bool) -> Void) {
        // 通过插入一条测试记录来创建表
        let testData: [String: Any] = [
            "reported_user_id": "test_user",
            "reported_user_name": "测试用户",
            "reported_user_email": "test@example.com",
            "report_reason": "测试举报",
            "reported_device_id": "test_device",
            "reported_user_login_type": "test",
            "reporter_user_id": "test_reporter",
            "reporter_user_name": "测试举报者",
            "reporter_user_email": "reporter@example.com",
            "reporter_device_id": "test_reporter_device",
            "reporter_login_type": "test",
            "status": "pending"
        ]
        
        let urlString = "\(serverUrl)/1.1/classes/ReportRecord"
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
                        // 删除测试记录
                        if let data = data {
                            do {
                                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                                if let objectId = json?["objectId"] as? String {
                                    self.deleteReportTestRecord(objectId: objectId) {
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
    
    // 删除ReportRecord测试记录
    private func deleteReportTestRecord(objectId: String, completion: @escaping () -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/ReportRecord/\(objectId)"
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
    
    // 创建ProcessedReportRecord表
    
    // 创建Blacklist表
    
    // 创建AccountDeletionRequest表
    // createAccountDeletionRequestTable method moved to LeanCloudService+TableManagement.swift
    
    // 创建Message表
    // createMessageTable method moved to LeanCloudService+TableManagement.swift
    
    /// 创建应用内容表
    func createAppContentTable(completion: @escaping (Bool) -> Void) {
        // 通过插入一条测试记录来创建表
        let testData: [String: Any] = [
            "content_type": "test",
            "content_data": "测试内容",
            "version": "1.0",
            "created_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        let urlString = "\(serverUrl)/1.1/classes/AppContent"
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
                        // 删除测试记录
                        if let data = data {
                            do {
                                _ = try JSONSerialization.data(withJSONObject: data)
                                // 注意：这个转换总是失败，因为 data(withJSONObject:) 返回 Data，不能转换为 [String: Any]
                                // 如果需要 objectId，应该从原始 data 中解析
                                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                                   let objectId = json["objectId"] as? String {
                                    self.deleteAppContentTestRecord(objectId: objectId) {
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
    
    /// 删除应用内容测试记录
    private func deleteAppContentTestRecord(objectId: String, completion: @escaping () -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/AppContent/\(objectId)"
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
    
    // 🎯 新增：添加重试机制（与用户头像查询一致）
    func fetchAllRecordsForClass(className: String, completion: @escaping ([[String: Any]]?, String?) -> Void) {
        var retryCount = 0
        
        func attempt() {
            let urlString = "\(serverUrl)/1.1/classes/\(className)?order=-createdAt&limit=1000"
            guard let url = URL(string: urlString) else {
                if retryCount < LeanCloudRetryConfig.maxRetries {
                    retryCount += 1
                    let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        attempt()
                    }
                } else {
                    completion(nil, "无效的URL")
                }
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue(appId, forHTTPHeaderField: "X-LC-Id")
            
            // 使用app key来访问数据
            request.setValue(appKey, forHTTPHeaderField: "X-LC-Key")
            request.timeoutInterval = 10.0
            
            // 添加缓存控制头，确保每次都获取最新数据
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            request.setValue("no-cache", forHTTPHeaderField: "Pragma")
            
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    // 🎯 修改：查询失败时，如果未达到最大重试次数，触发重试
                    if retryCount < LeanCloudRetryConfig.maxRetries {
                        retryCount += 1
                        let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            attempt()
                        }
                    } else {
                        completion(nil, "获取失败: \(error.localizedDescription)")
                    }
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    
                    if httpResponse.statusCode == 200, let data = data {
                        do {
                            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                            if let results = json?["results"] as? [[String: Any]] {
                                completion(results, nil)
                            } else {
                                // 🎯 修改：查询失败时，如果未达到最大重试次数，触发重试
                                if retryCount < LeanCloudRetryConfig.maxRetries {
                                    retryCount += 1
                                    let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                        attempt()
                                    }
                                } else {
                                    completion(nil, "数据解析失败")
                                }
                            }
                        } catch {
                            // 🎯 修改：查询失败时，如果未达到最大重试次数，触发重试
                            if retryCount < LeanCloudRetryConfig.maxRetries {
                                retryCount += 1
                                let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                    attempt()
                                }
                            } else {
                                completion(nil, "数据解析失败: \(error.localizedDescription)")
                            }
                        }
                    } else {
                        let errorMessage = "HTTP状态码: \(httpResponse.statusCode)"
                        // 🎯 修改：查询失败时，如果未达到最大重试次数，触发重试
                        if retryCount < LeanCloudRetryConfig.maxRetries {
                            retryCount += 1
                            let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                attempt()
                            }
                        } else {
                            completion(nil, errorMessage)
                        }
                    }
                } else {
                    // 🎯 修改：查询失败时，如果未达到最大重试次数，触发重试
                    if retryCount < LeanCloudRetryConfig.maxRetries {
                        retryCount += 1
                        let delay: TimeInterval = retryCount == 1 ? LeanCloudRetryConfig.firstRetryDelay : LeanCloudRetryConfig.secondRetryDelay
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            attempt()
                        }
                    } else {
                        completion(nil, "获取记录失败")
                    }
                }
            }.resume()
        }
        
        attempt()
    }
    
    // 直接获取所有LeanCloud数据，不生成统计报告
    func fetchAllLeanCloudData(completion: @escaping (String?, String?) -> Void) {
        
        // 根据当前LeanCloud中的表更新数据表列表
        let knownClasses = [
            "_Conversation", "_File", "_Followee", "_Follower", "_FriendshipRequest", "_Installation", "_Role", "_User", 
            "AccountDeletionRequest", "AppContent", "Blacklist", "DiamondRecord", "EmailVerification",
            "FavoriteRecord", "LikeRecord", "LocationRecord", "LoginRecord", "MatchRecord", 
            "Message", "OwnedAvatarsRecord", "ProcessedReportRecord", "Recommendation", "ReportRecord",
            "SDKTestObject", "TestConnection",
            "UserAvatarRecord", "UserAvatarUnlockRecord", "UserNameRecord", "UserScore"
        ]
        
        var allDataDetails: [String] = []
        let group = DispatchGroup()
        _ = knownClasses.count
        
        
        // 创建串行队列来控制请求频率
        let requestQueue = DispatchQueue(label: "leancloud.data.queue", qos: .userInitiated)
        var currentIndex = 0
        
        func fetchNext() {
            guard currentIndex < knownClasses.count else {
                // 所有请求完成
                group.notify(queue: .main) {
                    let joinedDetails = allDataDetails.joined(separator: "\n\n")
                    completion(joinedDetails, nil)
                }
                return
            }
            
            let className = knownClasses[currentIndex]
            currentIndex += 1
            
            
            group.enter()
            self.fetchAllRecordsForClass(className: className) { records, error in
                if let error = error {
                    if error.contains("404") {
                        allDataDetails.append("📋 \(className): 数据表不存在")
                    } else {
                        allDataDetails.append("❌ \(className): \(error)")
                    }
                } else if let records = records {
                    if records.isEmpty {
                        allDataDetails.append("📋 \(className): 0 条记录")
                    } else {
                        allDataDetails.append("📋 \(className): \(records.count) 条记录")
                        for (index, record) in records.enumerated() {
                            allDataDetails.append("  记录 \(index + 1): \(record)")
                        }
                    }
                } else {
                    allDataDetails.append("📋 \(className): 无数据")
                }
                
                group.leave()
                
                // 添加延迟避免请求过于频繁
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0/17.0) {
                    fetchNext()
                }
            }
        }
        
        // 开始获取数据
        requestQueue.async {
            fetchNext()
        }
    }
}

