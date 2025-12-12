import Foundation
import UIKit
@preconcurrency import LeanCloud

// MARK: - 全局操作追踪器和串行队列管理器
private class UpdateDiamondsOperationTracker {
    static let shared = UpdateDiamondsOperationTracker()
    private var operationCounter: Int = 0
    private let counterQueue = DispatchQueue(label: "com.neverSayNo.updateDiamonds.counter")
    private var activeOperations: [String: (operationId: Int, startTime: Date, objectId: String, targetValue: Int, queryValue: Int)] = [:]
    
    // 🔧 新增：为每个用户创建串行队列，确保同一用户的操作按顺序执行
    private var userQueues: [String: DispatchQueue] = [:]
    private let queueCreationQueue = DispatchQueue(label: "com.neverSayNo.updateDiamonds.queueCreation")
    
    // 🔧 新增：为每个用户创建 save 信号量，确保 save 请求完全串行化
    private var saveSemaphores: [String: DispatchSemaphore] = [:]
    private let semaphoreCreationQueue = DispatchQueue(label: "com.neverSayNo.updateDiamonds.semaphoreCreation")
    
    private init() {}
    
    /// 获取用户的串行队列，如果不存在则创建
    func getQueueForUser(objectId: String) -> DispatchQueue {
        return queueCreationQueue.sync {
            if let existingQueue = userQueues[objectId] {
                return existingQueue
            }
            let newQueue = DispatchQueue(label: "com.neverSayNo.updateDiamonds.\(objectId)", qos: .userInitiated)
            userQueues[objectId] = newQueue
            return newQueue
        }
    }
    
    /// 获取用户的 save 信号量，如果不存在则创建
    func getSaveSemaphoreForUser(objectId: String) -> DispatchSemaphore {
        return semaphoreCreationQueue.sync {
            if let existingSemaphore = saveSemaphores[objectId] {
                return existingSemaphore
            }
            let newSemaphore = DispatchSemaphore(value: 1) // 初始值为1，确保同时只有一个 save 在执行
            saveSemaphores[objectId] = newSemaphore
            return newSemaphore
        }
    }
    
    func getNextOperationId() -> Int {
        return counterQueue.sync {
            operationCounter += 1
            return operationCounter
        }
    }
    
    func registerOperation(operationId: Int, objectId: String, targetValue: Int, queryValue: Int) {
        counterQueue.async {
            let key = "\(objectId)_\(operationId)"
            self.activeOperations[key] = (operationId: operationId, startTime: Date(), objectId: objectId, targetValue: targetValue, queryValue: queryValue)
        }
    }
    
    func getActiveOperations(objectId: String) -> [(operationId: Int, startTime: Date, targetValue: Int, queryValue: Int)] {
        return counterQueue.sync {
            return self.activeOperations.values
                .filter { $0.objectId == objectId }
                .sorted { $0.operationId < $1.operationId }
                .map { ($0.operationId, $0.startTime, $0.targetValue, $0.queryValue) }
        }
    }
    
    func unregisterOperation(operationId: Int, objectId: String) {
        counterQueue.async {
            let key = "\(objectId)_\(operationId)"
            self.activeOperations.removeValue(forKey: key)
        }
    }
}

// MARK: - 钻石记录操作扩展
extension LeanCloudService {
    
    // 创建DiamondRecord字段 - ✅ 符合开发指南：使用 LCObject
    func createDiamondRecordFields(completion: @escaping (Bool) -> Void) {
        // ✅ 按照开发指南：使用 LCObject 创建对象（替代 REST API）
        let diamondRecord = LCObject(className: "DiamondRecord")
        
        do {
            try diamondRecord.set("userId", value: "field_init")
            try diamondRecord.set("userName", value: "Field Initialization")
            try diamondRecord.set("loginType", value: "guest")
            try diamondRecord.set("userEmail", value: "")
            try diamondRecord.set("userAvatar", value: "person.circle")
            try diamondRecord.set("deviceId", value: "field_init_device")
            try diamondRecord.set("diamondAmount", value: 0)
            try diamondRecord.set("operation_type", value: "field_init")
            try diamondRecord.set("description", value: "Field initialization")
            try diamondRecord.set("timezone", value: "UTC")
            try diamondRecord.set("deviceTime", value: ISO8601DateFormatter().string(from: Date()))
            
            _ = diamondRecord.save { result in
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
    
    // 发送钻石记录 - 使用 LCObject
    func sendDiamondRecord(diamondData: [String: Any], completion: @escaping (Bool, String) -> Void) {
        // ✅ 使用 LCObject 创建对象
        let diamondRecord = LCObject(className: "DiamondRecord")
        
        do {
            try diamondRecord.set("userId", value: (diamondData["userId"] as? String) ?? "")
            try diamondRecord.set("userName", value: (diamondData["userName"] as? String) ?? "")
            try diamondRecord.set("loginType", value: (diamondData["loginType"] as? String) ?? "")
            try diamondRecord.set("userEmail", value: (diamondData["userEmail"] as? String) ?? "")
            try diamondRecord.set("deviceId", value: (diamondData["deviceId"] as? String) ?? "")
            try diamondRecord.set("diamondAmount", value: (diamondData["diamondAmount"] as? Int) ?? 0)
            try diamondRecord.set("operation_type", value: (diamondData["operation_type"] as? String) ?? "")
            try diamondRecord.set("description", value: (diamondData["description"] as? String) ?? "")
            try diamondRecord.set("timezone", value: (diamondData["timezone"] as? String) ?? "UTC")
            try diamondRecord.set("deviceTime", value: (diamondData["deviceTime"] as? String) ?? ISO8601DateFormatter().string(from: Date()))
            
            _ = diamondRecord.save { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        completion(true, "保存成功")
                    case .failure(let error):
                        completion(false, "保存失败: \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            completion(false, "属性设置失败: \(error.localizedDescription)")
        }
    }
    
    // 更新钻石数量 - 遵循数据存储开发指南，使用 LCObject
    func updateDiamonds(objectId: String, loginType: String, diamonds: Int, completion: @escaping (Bool) -> Void) {

        // 🔍 调试：记录更新请求（带时间戳和操作ID）
        let operationId = UpdateDiamondsOperationTracker.shared.getNextOperationId()
        
        // 🔧 关键修复：使用串行队列确保同一用户的操作按顺序执行，避免并发冲突
        let userQueue = UpdateDiamondsOperationTracker.shared.getQueueForUser(objectId: objectId)
        
        userQueue.async {
            // 🔍 调试：检查是否有其他活跃操作（在队列中，理论上应该没有）
            let activeOps = UpdateDiamondsOperationTracker.shared.getActiveOperations(objectId: objectId)
            
            // ✅ 按照开发指南：首先查询现有的钻石记录
            let query = LCQuery(className: "DiamondRecord")
            query.whereKey("userId", .equalTo(objectId))
            query.whereKey("loginType", .equalTo(loginType))
            query.whereKey("updatedAt", .descending)
            query.limit = 1
            
            query.find { result in
                // 🔧 关键修复：将查询回调也放入串行队列，确保完全串行化
                userQueue.async {
                    switch result {
                case .success(let records):
                    if let latestRecord = records.first,
                       let recordObjectId = latestRecord.objectId?.stringValue {
                        // 找到现有记录，更新它
                        
                        // 🔧 新增：内部函数 - 执行save操作（支持重试）
                        func performSaveWithRetry(record: LCObject, recordObjectId: String, userId: String, loginType: String, targetDiamonds: Int, retryCount: Int = 0) {
                            let maxRetries = 3
                            
                            do {
                                let currentAmount = record["diamondAmount"]?.intValue ?? 0
                                let difference = targetDiamonds - currentAmount
                                
                                // 🔍 调试：记录服务器当前值和计算过程
                                if retryCount == 0 {
                                    // 🔍 调试：注册并发操作
                                    UpdateDiamondsOperationTracker.shared.registerOperation(
                                        operationId: operationId,
                                        objectId: recordObjectId,
                                        targetValue: targetDiamonds,
                                        queryValue: currentAmount
                                    )
                                } else {
                                    // 🔍 更新注册的操作信息
                                    UpdateDiamondsOperationTracker.shared.registerOperation(
                                        operationId: operationId,
                                        objectId: recordObjectId,
                                        targetValue: targetDiamonds,
                                        queryValue: currentAmount
                                    )
                                }
                                
                                // 🔍 调试：检查服务器当前值是否为负数
                                if currentAmount < 0 {
                                }
                                
                                // 🔍 调试：检查差值计算是否正确
                                if difference < 0 {
                                }
                                
                                if difference != 0 {
                                    // 🔍 调试：检查 increase 操作后是否会变成负数
                                    let expectedAfterIncrease = currentAmount + difference
                                    if expectedAfterIncrease < 0 {
                                    }
                                    
                                    // 🔍 调试：再次检查并发操作
                                    let beforeSaveOps = UpdateDiamondsOperationTracker.shared.getActiveOperations(objectId: recordObjectId)
                                    if activeOps.count != beforeSaveOps.count {
                                    }
                                    
                                    // ✅ 按照开发指南：使用原子操作更新计数器
                                    
                                    // 🔍 关键调试：检查是否有其他操作正在 save
                                    let activeOpsBeforeSave = UpdateDiamondsOperationTracker.shared.getActiveOperations(objectId: recordObjectId)
                                    _ = activeOpsBeforeSave.filter { $0.operationId != operationId }
                                    
                                    try record.increase("diamondAmount", by: difference)
                                    
                                    // 🔧 按照开发指南：使用 fetchWhenSave 选项，操作结束后返回最新数据
                                    var saveOptions: [LCObject.SaveOption] = [.fetchWhenSave]
                                    
                                    // 🔧 按照开发指南：如果是要减少钻石，添加条件查询防止变成负数
                                    if difference < 0 {
                                        let minAmount = -difference // 最少需要的余额（确保减少后不会变成负数）
                                        let conditionQuery = LCQuery(className: "DiamondRecord")
                                        conditionQuery.whereKey("diamondAmount", .greaterThanOrEqualTo(minAmount))
                                        saveOptions.append(.query(conditionQuery))
                                    }
                                    
                                    _ = record.save(options: saveOptions) { saveResult in
                                        
                                        // 🔧 关键修复：将save回调也放入串行队列
                                        userQueue.async {
                                            switch saveResult {
                                            case .success:
                                                // ✅ 按照开发指南：使用 fetchWhenSave 后，record 已包含最新数据
                                                
                                                // 🔍 调试：从 record 获取最新值（fetchWhenSave 返回的）
                                                let actualAmount = record["diamondAmount"]?.intValue ?? targetDiamonds
                                                
                                                // 🔍 调试：获取所有并发操作信息
                                                _ = UpdateDiamondsOperationTracker.shared.getActiveOperations(objectId: recordObjectId)
                                                
                                                // 🔍 调试：检查验证值是否为负数
                                                if actualAmount < 0 {
                                                }
                                                
                                                // 🔍 调试：检查验证值是否与期望值一致
                                                if actualAmount != targetDiamonds {
                                                    let diff = actualAmount - targetDiamonds
                                                    if retryCount == 0 {
                                                        if diff < 0 {
                                                        }
                                                    } else {
                                                        if diff < 0 {
                                                        }
                                                    }
                                                    
                                                    // 🔧 修复：当 save 成功但实际值≠期望值时，无论重试次数，只要未达到上限就继续重试
                                                    if retryCount < maxRetries {
                                                        
                                                        // 重新查询最新的服务器值（使用userId和loginType查询）
                                                        let retryQuery = LCQuery(className: "DiamondRecord")
                                                        retryQuery.whereKey("userId", .equalTo(userId))
                                                        retryQuery.whereKey("loginType", .equalTo(loginType))
                                                        retryQuery.whereKey("updatedAt", .descending)
                                                        retryQuery.limit = 1
                                                        
                                                        retryQuery.find { retryQueryResult in
                                                            userQueue.async {
                                                                switch retryQueryResult {
                                                                case .success(let retryRecords):
                                                                    if let retryRecord = retryRecords.first,
                                                                       let retryRecordObjectId = retryRecord.objectId?.stringValue {
                                                                        // 递归调用重试
                                                                        performSaveWithRetry(record: retryRecord, recordObjectId: retryRecordObjectId, userId: userId, loginType: loginType, targetDiamonds: targetDiamonds, retryCount: retryCount + 1)
                                                                    } else {
                                                                        UpdateDiamondsOperationTracker.shared.unregisterOperation(operationId: operationId, objectId: recordObjectId)
                                                                        DispatchQueue.main.async {
                                                                            completion(false)
                                                                        }
                                                                    }
                                                                case .failure:
                                                                    UpdateDiamondsOperationTracker.shared.unregisterOperation(operationId: operationId, objectId: recordObjectId)
                                                                    DispatchQueue.main.async {
                                                                        completion(false)
                                                                    }
                                                                }
                                                            }
                                                        }
                                                        return // 重试中，不执行后续代码
                                                    } else {
                                                    }
                                                }
                                                
                                                // 更新缓存为实际余额
                                                self.cacheUserDiamonds(actualAmount, for: userId)
                                                
                                                // 🔍 调试：注销操作
                                                UpdateDiamondsOperationTracker.shared.unregisterOperation(operationId: operationId, objectId: recordObjectId)
                                                // 确保completion在主线程执行
                                                DispatchQueue.main.async {
                                                    completion(true)
                                                }
                                            case .failure(let error):
                                                // 🔴 检查API限制错误（429或相关错误）
                                                if error.code == 429 || (error.reason?.contains("429") ?? false) || (error.reason?.contains("API") ?? false) || (error.reason?.contains("limit") ?? false) || (error.reason?.contains("限制") ?? false) {
                                                    // API限制错误处理
                                                }
                                                
                                                // 🔧 按照开发指南：检查是否为条件查询不满足（305错误）
                                                if error.code == 305 {
                                                    
                                                    // 🔧 新增：智能重试机制 - 重新查询最新值并重试
                                                    if retryCount < maxRetries {
                                                        
                                                        // 重新查询最新的服务器值（使用userId和loginType查询）
                                                        let retryQuery = LCQuery(className: "DiamondRecord")
                                                        retryQuery.whereKey("userId", .equalTo(userId))
                                                        retryQuery.whereKey("loginType", .equalTo(loginType))
                                                        retryQuery.whereKey("updatedAt", .descending)
                                                        retryQuery.limit = 1
                                                        
                                                        retryQuery.find { retryQueryResult in
                                                            userQueue.async {
                                                                switch retryQueryResult {
                                                                case .success(let retryRecords):
                                                                    if let retryRecord = retryRecords.first,
                                                                       let retryRecordObjectId = retryRecord.objectId?.stringValue {
                                                                        // 递归调用重试
                                                                        performSaveWithRetry(record: retryRecord, recordObjectId: retryRecordObjectId, userId: userId, loginType: loginType, targetDiamonds: targetDiamonds, retryCount: retryCount + 1)
                                                                    } else {
                                                                        UpdateDiamondsOperationTracker.shared.unregisterOperation(operationId: operationId, objectId: recordObjectId)
                                                                        DispatchQueue.main.async {
                                                                            completion(false)
                                                                        }
                                                                    }
                                                                case .failure:
                                                                    UpdateDiamondsOperationTracker.shared.unregisterOperation(operationId: operationId, objectId: recordObjectId)
                                                                    DispatchQueue.main.async {
                                                                        completion(false)
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    } else {
                                                        UpdateDiamondsOperationTracker.shared.unregisterOperation(operationId: operationId, objectId: recordObjectId)
                                                        DispatchQueue.main.async {
                                                            completion(false)
                                                        }
                                                    }
                                                } else {
                                                    UpdateDiamondsOperationTracker.shared.unregisterOperation(operationId: operationId, objectId: recordObjectId)
                                                    DispatchQueue.main.async {
                                                        completion(false)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                } else {
                                    // 差值为0，无需更新
                                    if retryCount == 0 {
                                        UpdateDiamondsOperationTracker.shared.unregisterOperation(operationId: operationId, objectId: recordObjectId)
                                        DispatchQueue.main.async {
                                            completion(true)
                                        }
                                    } else {
                                        // 重试后差值为0，说明已经达到目标值
                                        self.cacheUserDiamonds(currentAmount, for: userId)
                                        UpdateDiamondsOperationTracker.shared.unregisterOperation(operationId: operationId, objectId: recordObjectId)
                                        DispatchQueue.main.async {
                                            completion(true)
                                        }
                                    }
                                }
                            } catch {
                                if retryCount < maxRetries {
                                    // 重新查询并重试（使用userId和loginType查询）
                                    let retryQuery = LCQuery(className: "DiamondRecord")
                                    retryQuery.whereKey("userId", .equalTo(userId))
                                    retryQuery.whereKey("loginType", .equalTo(loginType))
                                    retryQuery.whereKey("updatedAt", .descending)
                                    retryQuery.limit = 1
                                    
                                    retryQuery.find { retryQueryResult in
                                        userQueue.async {
                                            switch retryQueryResult {
                                            case .success(let retryRecords):
                                                if let retryRecord = retryRecords.first,
                                                   let retryRecordObjectId = retryRecord.objectId?.stringValue {
                                                    performSaveWithRetry(record: retryRecord, recordObjectId: retryRecordObjectId, userId: userId, loginType: loginType, targetDiamonds: targetDiamonds, retryCount: retryCount + 1)
                                                } else {
                                                    UpdateDiamondsOperationTracker.shared.unregisterOperation(operationId: operationId, objectId: recordObjectId)
                                                    DispatchQueue.main.async {
                                                        completion(false)
                                                    }
                                                }
                                            case .failure:
                                                UpdateDiamondsOperationTracker.shared.unregisterOperation(operationId: operationId, objectId: recordObjectId)
                                                DispatchQueue.main.async {
                                                    completion(false)
                                                }
                                            }
                                        }
                                    }
                                } else {
                                    UpdateDiamondsOperationTracker.shared.unregisterOperation(operationId: operationId, objectId: recordObjectId)
                                    DispatchQueue.main.async {
                                        completion(false)
                                    }
                                }
                            }
                        }
                        
                        // 首次调用
                        performSaveWithRetry(record: latestRecord, recordObjectId: recordObjectId, userId: objectId, loginType: loginType, targetDiamonds: diamonds, retryCount: 0)
                    } else {
                        // 🎯 修改：没有现有记录时，先再次查询确认（防止并发问题）
                        // 如果确实没有记录，再创建新记录
                        let retryQuery = LCQuery(className: "DiamondRecord")
                        retryQuery.whereKey("userId", .equalTo(objectId))
                        retryQuery.whereKey("loginType", .equalTo(loginType))
                        retryQuery.limit = 1
                        
                        retryQuery.find { retryResult in
                            // 🔧 关键修复：将重试查询回调也放入串行队列
                            userQueue.async {
                                switch retryResult {
                                case .success(let retryRecords):
                                    if let existingRecord = retryRecords.first,
                                       existingRecord.objectId?.stringValue != nil {
                                        // 再次查询时发现记录存在，更新它
                                        do {
                                            let currentAmount = existingRecord["diamondAmount"]?.intValue ?? 0
                                            let difference = diamonds - currentAmount
                                            
                                            // 🔍 调试：记录重试查询的结果
                                            
                                            // 🔍 调试：检查服务器当前值是否为负数
                                            if currentAmount < 0 {
                                            }
                                            
                                            if difference != 0 {
                                                try existingRecord.increase("diamondAmount", by: difference)
                                                
                                                _ = existingRecord.save { saveResult in
                                                    // 🔧 关键修复：将重试save回调也放入串行队列
                                                    userQueue.async {
                                                        switch saveResult {
                                                        case .success:
                                                            self.cacheUserDiamonds(diamonds, for: objectId)
                                                            DispatchQueue.main.async {
                                                                completion(true)
                                                            }
                                                        case .failure:
                                                            DispatchQueue.main.async {
                                                                completion(false)
                                                            }
                                                        }
                                                    }
                                                }
                                            } else {
                                                DispatchQueue.main.async {
                                                    completion(true)
                                                }
                                            }
                                        } catch {
                                            DispatchQueue.main.async {
                                                completion(false)
                                            }
                                        }
                                    } else {
                                        // 确认没有记录，创建新记录
                                        let diamondData: [String: Any] = [
                                            "userId": objectId,
                                            "loginType": loginType,
                                            "diamondAmount": diamonds,
                                            "operation_type": "create",
                                            "description": "首次创建钻石记录"
                                        ]
                                        
                                        self.sendDiamondRecord(diamondData: diamondData) { success, message in
                                            if success {
                                                self.cacheUserDiamonds(diamonds, for: objectId)
                                            } else {
                                            }
                                            DispatchQueue.main.async {
                                                completion(success)
                                            }
                                        }
                                    }
                                case .failure:
                                    // 重试查询也失败，不创建新记录（可能网络问题或记录确实不存在）
                                    DispatchQueue.main.async {
                                        completion(false)
                                    }
                                }
                            }
                        }
                    }
                case .failure(let error):
                    // 🎯 修改：查询失败时，不再创建新记录，直接返回失败
                    // 因为如果记录已存在，不应该因为查询失败就创建重复记录
                    // 🔴 检查API限制错误（140错误码表示API调用限制）
                    let isAPILimitError = error.code == 140 || error.code == 429 || (error.reason?.contains("429") ?? false) || (error.reason?.contains("API") ?? false) || (error.reason?.contains("limit") ?? false) || (error.reason?.contains("限制") ?? false)
                    if isAPILimitError {
                        // 🔧 改进：将API限制错误信息存储到UserDefaults，让调用者可以检查
                        UserDefaults.standard.set("API_LIMIT_\(error.code)", forKey: "lastDiamondUpdateError_\(objectId)")
                        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastDiamondUpdateErrorTime_\(objectId)")
                    } else {
                        // 清除之前的错误标记
                        UserDefaults.standard.removeObject(forKey: "lastDiamondUpdateError_\(objectId)")
                        UserDefaults.standard.removeObject(forKey: "lastDiamondUpdateErrorTime_\(objectId)")
                    }
                    DispatchQueue.main.async {
                        completion(false)
                    }
                }
                    }  // 关闭 DispatchQueue.main.async
                }  // 关闭 query.find
            }  // 关闭 userQueue.async
    }
    
    // 🎯 修改：使用简化数据创建钻石记录（先检查记录是否存在）
    func createDiamondRecordWithSimplifiedData(objectId: String, loginType: String, diamonds: Int, completion: @escaping (Bool) -> Void) {
        // 先查询记录是否已存在
        let query = LCQuery(className: "DiamondRecord")
        query.whereKey("userId", .equalTo(objectId))
        query.whereKey("loginType", .equalTo(loginType))
        query.limit = 1
        
        query.find { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let records):
                    if let existingRecord = records.first, existingRecord.objectId != nil {
                        // 记录已存在，不创建新记录
                        completion(true)
                        return
                    }
                    
                    // 记录不存在，创建新记录
                    let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
                    let userName = UserDefaults.standard.string(forKey: "current_user_name") ?? "未知用户"
                    
                    let diamondRecord = LCObject(className: "DiamondRecord")
                    
                    do {
                        try diamondRecord.set("userId", value: objectId)
                        try diamondRecord.set("userName", value: userName)
                        try diamondRecord.set("loginType", value: loginType)
                        try diamondRecord.set("deviceId", value: deviceID)
                        try diamondRecord.set("diamonds", value: diamonds)
                        
                        _ = diamondRecord.save { saveResult in
                            DispatchQueue.main.async {
                                switch saveResult {
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
                    
                case .failure:
                    // 查询失败，不创建新记录
                    completion(false)
                }
            }
        }
    }
    
    // 获取完整的钻石记录（包括设备ID）- 遵循数据存储开发指南，使用 LCQuery
    func fetchDiamondRecords(objectId: String, loginType: String, skipCache: Bool = false, completion: @escaping ([DiamondRecord]?, String?) -> Void) {
        
        // 🔧 修复：refreshBalanceFromServer 时跳过缓存，强制从服务器查询
        if !skipCache {
            // 🔧 统一：先检查缓存（参考头像查询）
            if let cachedDiamonds = getCachedUserDiamonds(for: objectId) {
                // 构造一个简单的 DiamondRecord 返回
                let cachedRecord = DiamondRecord(
                    id: objectId.hash,
                    objectId: objectId,
                    userId: objectId,
                    user_name: nil,
                    userAvatar: nil,
                    userEmail: nil,
                    login_type: loginType,
                    deviceId: nil,
                    diamonds: cachedDiamonds,
                    created_at: "",
                    updated_at: ""
                )
                completion([cachedRecord], nil)
                return
            }
        } else {
        }
        
        // ✅ 按照开发指南：使用 LCQuery 创建查询
        let query = LCQuery(className: "DiamondRecord")
        query.whereKey("userId", .equalTo(objectId))
        query.whereKey("loginType", .equalTo(loginType))
        query.whereKey("updatedAt", .descending) // 🔧 统一：使用 updatedAt（与头像查询一致）
        query.limit = 1 // 🔧 统一：只返回一条最新记录（与头像查询一致）
        
        query.find { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let records):
                    let diamondRecords = records.compactMap { lcRecord -> DiamondRecord? in
                        guard let objectId = lcRecord.objectId?.stringValue,
                              let userId = lcRecord["userId"]?.stringValue,
                              let loginType = lcRecord["loginType"]?.stringValue else {
                            return nil
                        }
                        
                        
                        // 获取 created_at 和 updated_at，兼容多种字段名
                        let createdAt = lcRecord["createdAt"]?.stringValue ?? lcRecord.createdAt?.stringValue ?? ""
                        let updatedAt = lcRecord["updatedAt"]?.stringValue ?? lcRecord.updatedAt?.stringValue ?? createdAt
                        
                        // 兼容两种字段名：diamonds 和 diamond_amount（优先使用 diamond_amount）
                        let diamonds: Int
                        if let diamondAmountValue = lcRecord["diamondAmount"]?.intValue {
                            diamonds = diamondAmountValue
                        } else if let diamondsValue = lcRecord["diamonds"]?.intValue {
                            diamonds = diamondsValue
                        } else {
                            return nil
                        }
                        
                        // 🔍 调试：检查获取的钻石数是否为负数
                        if diamonds < 0 {
                        }
                        
                        
                        
                        let deviceId = lcRecord["deviceId"]?.stringValue
                        let userName = lcRecord["userName"]?.stringValue
                        let userEmail: String? = nil // 🎯 不再从DiamondRecord表读取userEmail，统一从UserNameRecord表读取
                        
                        let record = DiamondRecord(
                            id: objectId.hash,
                            objectId: objectId,
                            userId: userId,
                            user_name: userName,
                            userAvatar: nil,
                            userEmail: userEmail,
                            login_type: loginType,
                            deviceId: deviceId,
                            diamonds: diamonds,
                            created_at: createdAt,
                            updated_at: updatedAt
                        )
                        
                        return record
                    }
                    
                    if let firstRecord = diamondRecords.first {
                        
                        // 🔍 调试：检查是否为负数
                        if firstRecord.diamonds < 0 {
                        }
                        
                        // 🔧 统一：缓存查询结果（参考头像查询）
                        self.cacheUserDiamonds(firstRecord.diamonds, for: objectId)
                        
                        // 🎯 新增：与用户头像界面一致，写入 UserDefaults 持久化缓存，供全局复用
                        UserDefaultsManager.setCustomDiamonds(userId: objectId, diamonds: firstRecord.diamonds)
                    } else {
                    }
                    completion(diamondRecords, nil)
                    
                case .failure(let error):
                    completion(nil, "获取失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
}
