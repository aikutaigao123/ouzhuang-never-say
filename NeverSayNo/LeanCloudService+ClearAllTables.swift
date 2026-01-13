//
//  LeanCloudService+ClearAllTables.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//
//  LeanCloud数据清空功能（将Python脚本功能转换为Swift）
//  当读取到 "Hello World ！" 通知时触发执行

import Foundation
import LeanCloud

// MARK: - 清空所有表功能
extension LeanCloudService {
    
    /// 要清空的表列表（仅清空指定的6个表）
    /// 注意：Notifications 表不在此列表中，不会被清空
    private static let tablesToClear: [String] = [
        "Picturedata",        // 1. 存储图片数据（仅上传图三，美团截图）
        "UserNameRecord",      // 2. 存储用户名、地点、推荐理由等
        "UserAvatarRecord",    // 3. 存储用户头像（emoji）
        "LoginRecord",         // 4. 存储登录记录信息
        "LocationRecord",      // 5. 存储位置信息（经纬度）
        "Recommendation"       // 6. 存储推荐列表数据，包含点赞数等
    ]
    
    // 配置
    private static let pageSize = 1000
    private static let maxRetries = 3
    private static let retryDelay: TimeInterval = 2.0
    private static let batchSize = 1000
    
    /// 清空所有表（当读取到 "Hello World ！" 通知时触发）
    /// - Parameter completion: 完成回调，返回是否成功和错误信息
    func clearAllTables(completion: @escaping (Bool, String?) -> Void) {
        var clearSuccess = true
        var completedTables = 0
        let group = DispatchGroup()
        let lock = NSLock()
        
        for tableName in Self.tablesToClear {
            group.enter()
            
            clearTable(tableName: tableName) { success in
                lock.lock()
                defer { lock.unlock() }
                
                completedTables += 1
                if !success {
                    clearSuccess = false
                }
                
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if clearSuccess {
                completion(true, nil)
            } else {
                completion(false, "部分表清空失败")
            }
        }
    }
    
    /// 清空指定表的所有记录
    /// - Parameters:
    ///   - tableName: 表名
    ///   - completion: 完成回调，返回是否成功
    private func clearTable(tableName: String, completion: @escaping (Bool) -> Void) {
        // 获取所有 objectId
        fetchAllObjectIds(tableName: tableName) { objectIds in
            if objectIds.isEmpty {
                completion(true)
                return
            }
            
            // 批量删除
            self.deleteObjectIds(tableName: tableName, objectIds: objectIds) { success in
                completion(success)
            }
        }
    }
    
    /// 获取指定表的所有记录的 objectId
    /// - Parameters:
    ///   - tableName: 表名
    ///   - completion: 完成回调，返回 objectId 数组
    private func fetchAllObjectIds(tableName: String, completion: @escaping ([String]) -> Void) {
        var objectIds: [String] = []
        var skip = 0
        
        func fetchNextBatch() {
            let urlString = "\(serverUrl)/1.1/classes/\(tableName)?keys=objectId&limit=\(Self.pageSize)&skip=\(skip)"
            guard let url = URL(string: urlString) else {
                completion(objectIds)
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            setLeanCloudHeaders(&request)
            request.timeoutInterval = 30.0
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if error != nil {
                    completion(objectIds)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(objectIds)
                    return
                }
                
                if httpResponse.statusCode == 200, let data = data {
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let results = json["results"] as? [[String: Any]] {
                            
                            if results.isEmpty {
                                completion(objectIds)
                                return
                            }
                            
                            for record in results {
                                if let objectId = record["objectId"] as? String {
                                    objectIds.append(objectId)
                                }
                            }
                            
                            if results.count < Self.pageSize {
                                completion(objectIds)
                                return
                            }
                            
                            skip += Self.pageSize
                            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                                fetchNextBatch()
                            }
                        } else {
                            completion(objectIds)
                        }
                    } catch {
                        completion(objectIds)
                    }
                } else if httpResponse.statusCode == 429 {
                    DispatchQueue.global().asyncAfter(deadline: .now() + Self.retryDelay) {
                        fetchNextBatch()
                    }
                } else {
                    completion(objectIds)
                }
            }.resume()
        }
        
        fetchNextBatch()
    }
    
    /// 批量删除 objectId
    /// - Parameters:
    ///   - tableName: 表名
    ///   - objectIds: objectId 数组
    ///   - completion: 完成回调，返回是否成功
    private func deleteObjectIds(tableName: String, objectIds: [String], completion: @escaping (Bool) -> Void) {
        var deletedCount = 0
        var failedCount = 0
        
        let group = DispatchGroup()
        let lock = NSLock()
        
        // 🔧 修复：使用串行队列限制并发，避免线程安全问题
        // 创建一个串行队列用于删除操作，避免过多并发导致 LeanCloud SDK 内部字典访问冲突
        let deleteQueue = DispatchQueue(label: "com.neverSayNo.clearTables.delete", qos: .userInitiated)
        
        // 🔧 修复：限制同时进行的删除操作数量，避免线程池耗尽
        let maxConcurrentDeletes = 10 // 最多同时进行 10 个删除操作
        var currentConcurrentDeletes = 0
        let concurrentLock = NSLock()
        var currentIndex = 0
        
        func processNextBatch() {
            concurrentLock.lock()
            defer { concurrentLock.unlock() }
            
            // 🔧 修复：在锁内获取 currentIndex 的值，避免并发访问警告
            let localCurrentIndex = currentIndex
            let localCurrentConcurrentDeletes = currentConcurrentDeletes
            
            // 如果所有操作都已完成，等待所有任务完成
            guard localCurrentIndex < objectIds.count || localCurrentConcurrentDeletes > 0 else {
                return
            }
            
            // 如果还有待处理的 objectId 且当前并发数未达到上限
            var processedInThisBatch = 0
            while localCurrentIndex + processedInThisBatch < objectIds.count && localCurrentConcurrentDeletes + processedInThisBatch < maxConcurrentDeletes {
                let indexToProcess = localCurrentIndex + processedInThisBatch
                let objectId = objectIds[indexToProcess]
                
                // 更新共享变量（在锁内）
                currentIndex = indexToProcess + 1
                currentConcurrentDeletes = localCurrentConcurrentDeletes + processedInThisBatch + 1
                
                group.enter()
                
                // 🔧 修复：使用串行队列执行删除操作，避免并发冲突
                deleteQueue.async {
                    self.deleteObjectId(tableName: tableName, objectId: objectId) { success in
                        concurrentLock.lock()
                        defer { concurrentLock.unlock() }
                        
                        currentConcurrentDeletes -= 1
                        
                        lock.lock()
                        defer { lock.unlock() }
                        
                        if success {
                            deletedCount += 1
                        } else {
                            failedCount += 1
                        }
                        
                        group.leave()
                        
                        // 处理下一批
                        processNextBatch()
                    }
                }
                
                processedInThisBatch += 1
                
                // 🔧 修复：使用 DispatchQueue.asyncAfter 替代 Thread.sleep，避免阻塞线程
                // 添加小延迟，避免请求过快（每 50ms 处理一个）
                if indexToProcess + 1 < objectIds.count {
                    deleteQueue.asyncAfter(deadline: .now() + 0.05) {
                        processNextBatch()
                    }
                }
            }
        }
        
        // 开始处理
        processNextBatch()
        
        group.notify(queue: .main) {
            completion(failedCount == 0)
        }
    }
    
    /// 删除单个 objectId
    /// - Parameters:
    ///   - tableName: 表名
    ///   - objectId: objectId
    ///   - completion: 完成回调，返回是否成功
    private func deleteObjectId(tableName: String, objectId: String, completion: @escaping (Bool) -> Void) {
        let urlString = "\(serverUrl)/1.1/classes/\(tableName)/\(objectId)"
        guard let url = URL(string: urlString) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        setLeanCloudHeaders(&request)
        request.timeoutInterval = 15.0
        
        var retryCount = 0
        
        func attemptDelete() {
            URLSession.shared.dataTask(with: request) { data, response, error in
                if error != nil {
                    if retryCount < Self.maxRetries {
                        retryCount += 1
                        DispatchQueue.global().asyncAfter(deadline: .now() + Self.retryDelay * Double(retryCount)) {
                            attemptDelete()
                        }
                    } else {
                        completion(false)
                    }
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    if retryCount < Self.maxRetries {
                        retryCount += 1
                        DispatchQueue.global().asyncAfter(deadline: .now() + Self.retryDelay * Double(retryCount)) {
                            attemptDelete()
                        }
                    } else {
                        completion(false)
                    }
                    return
                }
                
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 404 {
                    completion(true)
                } else if httpResponse.statusCode == 429 {
                    if retryCount < Self.maxRetries {
                        retryCount += 1
                        DispatchQueue.global().asyncAfter(deadline: .now() + Self.retryDelay * Double(retryCount)) {
                            attemptDelete()
                        }
                    } else {
                        completion(false)
                    }
                } else {
                    if retryCount < Self.maxRetries {
                        retryCount += 1
                        DispatchQueue.global().asyncAfter(deadline: .now() + Self.retryDelay * Double(retryCount)) {
                            attemptDelete()
                        }
                    } else {
                        completion(false)
                    }
                }
            }.resume()
        }
        
        attemptDelete()
    }
}
