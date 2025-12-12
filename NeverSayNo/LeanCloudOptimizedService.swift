//
//  LeanCloudOptimizedService.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//  基于LeanCloud Swift开发指南的优化服务
//

import Foundation
import LeanCloud

/**
 * LeanCloud优化服务类
 * 基于Swift开发指南的最佳实践
 */
class LeanCloudOptimizedService {
    static let shared = LeanCloudOptimizedService()
    
    private init() {}
    
    // MARK: - 优化的对象操作方法
    
    /**
     * 创建用户记录 - 遵循开发指南的最佳实践
     */
    func createUserRecord(userId: String, userName: String, userAvatar: String, completion: @escaping (Bool, String?) -> Void) {
        do {
            // 构建对象 - 使用驼峰式命名法
            let userRecord = LCObject(className: "UserRecord")
            
            // 使用正确的数据类型设置属性
            try userRecord.set("userId", value: userId)
            try userRecord.set("userName", value: userName)
            try userRecord.set("userAvatar", value: userAvatar)
            try userRecord.set("createdAt", value: Date()) // 自动转换为LCDate
            
            // 保存对象
            _ = userRecord.save { result in
                switch result {
                case .success:
                    if userRecord.objectId?.value != nil {
                    }
                    completion(true, nil)
                case .failure(let error):
                    completion(false, error.localizedDescription)
                }
            }
        } catch {
            completion(false, error.localizedDescription)
        }
    }
    
    /**
     * 批量保存对象 - 使用开发指南推荐的批量操作
     */
    func batchSaveUserRecords(_ records: [[String: Any]], completion: @escaping (Bool, String?) -> Void) {
        var objects: [LCObject] = []
        
        do {
            // 批量构建对象
            for record in records {
                let userRecord = LCObject(className: "UserRecord")
                
                try userRecord.set("userId", value: record["userId"] as? String ?? "")
                try userRecord.set("userName", value: record["userName"] as? String ?? "")
                let loginType = record["loginType"] as? String ?? "guest"
                let defaultAvatar = UserAvatarUtils.defaultAvatar(for: loginType)
                try userRecord.set("userAvatar", value: record["userAvatar"] as? String ?? defaultAvatar)
                try userRecord.set("createdAt", value: Date())
                
                objects.append(userRecord)
            }
            
            // 批量保存
            _ = LCObject.save(objects) { result in
                switch result {
                case .success:
                    completion(true, nil)
                case .failure(let error):
                    completion(false, error.localizedDescription)
                }
            }
        } catch {
            completion(false, error.localizedDescription)
        }
    }
    
    /**
     * 原子操作 - 使用开发指南推荐的计数器更新
     */
    func incrementUserScore(userId: String, increment: Int, completion: @escaping (Bool, String?) -> Void) {
        do {
            let userRecord = LCObject(className: "UserRecord")
            
            // 原子增加分数
            try userRecord.increase("score", by: increment)
            
            _ = userRecord.save { result in
                switch result {
                case .success:
                    if userRecord["score"] as? LCNumber != nil {
                    }
                    completion(true, nil)
                case .failure(let error):
                    completion(false, error.localizedDescription)
                }
            }
        } catch {
            completion(false, error.localizedDescription)
        }
    }
    
    /**
     * 数组操作 - 使用开发指南推荐的数组更新方法
     */
    func updateUserTags(userId: String, newTags: [String], completion: @escaping (Bool, String?) -> Void) {
        do {
            let userRecord = LCObject(className: "UserRecord")
            
            // 使用数组操作添加标签
            try userRecord.append("tags", elements: LCArray(newTags), unique: true)
            
            _ = userRecord.save { result in
                switch result {
                case .success:
                    completion(true, nil)
                case .failure(let error):
                    completion(false, error.localizedDescription)
                }
            }
        } catch {
            completion(false, error.localizedDescription)
        }
    }
    
    // MARK: - 优化的查询操作
    
    /**
     * 基础查询 - 遵循开发指南的最佳实践
     */
    func fetchUserRecords(limit: Int = 100, completion: @escaping ([LCObject]?, String?) -> Void) {
        let query = LCQuery(className: "UserRecord")
        
        // 设置查询条件
        query.whereKey("createdAt", .descending) // 按创建时间降序
        query.limit = min(limit, 1000) // 限制最大数量
        
        _ = query.find { result in
            switch result {
            case .success(objects: let objects):
                completion(objects, nil)
            case .failure(let error):
                completion(nil, error.localizedDescription)
            }
        }
    }
    
    /**
     * 统计查询 - 使用开发指南推荐的count方法
     */
    func countUserRecords(completion: @escaping (Int, String?) -> Void) {
        let query = LCQuery(className: "UserRecord")
        
        _ = query.count { result in
            switch result {
            case .success(let count):
                completion(count, nil)
            case .failure(let error):
                completion(0, error.localizedDescription)
            }
        }
    }
}
