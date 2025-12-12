//
//  LeanCloudService+MatchRecord.swift
//  NeverSayNo
//
//  Created by AI Assistant on 2024-12-19.
//

import Foundation
import CoreLocation
import UIKit
import LeanCloud

// MARK: - 匹配记录表管理功能
extension LeanCloudService {
    
    // createMatchRecordTable method moved to LeanCloudService+MatchRecordTable.swift
    
    // deleteMatchRecordTestRecord method moved to LeanCloudService+MatchRecordTable.swift
    private func updateOrCreateMatchRecords(_ matchRecords: [MatchRecord], completion: @escaping (Bool) -> Void) {
        guard !matchRecords.isEmpty else {
            completion(true)
            return
        }
        
        
        let group = DispatchGroup()
        var allSuccess = true
        
        for matchRecord in matchRecords {
            group.enter()
            
            
            // 首先尝试查找并更新现有的cancelled记录
            self.findAndUpdateCancelledMatchRecord(matchRecord) { success in
                if success {
                    // 成功更新了cancelled记录
                    group.leave()
                } else {
                    // 没有找到cancelled记录，检查是否已存在active记录
                    self.checkExistingActiveMatchRecord(matchRecord) { exists in
                        if exists {
                            group.leave()
                        } else {
                            // 不存在active记录，创建新记录
                            self.uploadMatchRecord(
                                user1Id: matchRecord.user1Id,
                                user1Name: matchRecord.user1Name,
                                user1Avatar: matchRecord.user1Avatar,
                                user1LoginType: matchRecord.user1LoginType,
                                user2Id: matchRecord.user2Id,
                                user2Name: matchRecord.user2Name,
                                user2Avatar: matchRecord.user2Avatar,
                                user2LoginType: matchRecord.user2LoginType,
                                matchTime: matchRecord.matchTime,
                                matchLocation: CLLocation(latitude: matchRecord.matchLocationLat, longitude: matchRecord.matchLocationLng)
                            ) { success, error in
                                if !success {
                                    allSuccess = false
                                }
                                group.leave()
                            }
                        }
                    }
                }
            }
        }
        
        group.notify(queue: .main) {
            completion(allSuccess)
        }
    }
    
    // 查找并更新现有的cancelled记录 - 遵循数据存储开发指南，使用 LCQuery
    private func findAndUpdateCancelledMatchRecord(_ matchRecord: MatchRecord, completion: @escaping (Bool) -> Void) {
        // ✅ 按照开发指南：使用并行查询替代复杂的OR查询
        var allRecords: [LCObject] = []
        let group = DispatchGroup()
        
        // 查询1: user1_id 和 user2_id 匹配
        group.enter()
        let query1 = LCQuery(className: "MatchRecord")
        query1.whereKey("user1Id", .equalTo(matchRecord.user1Id))
        query1.whereKey("user2Id", .equalTo(matchRecord.user2Id))
        query1.whereKey("status", .equalTo("cancelled"))
        query1.limit = 1
        query1.find { result in
            switch result {
            case .success(let records):
                allRecords.append(contentsOf: records)
            case .failure:
                break
            }
            group.leave()
        }
        
        // 查询2: 反向匹配
        group.enter()
        let query2 = LCQuery(className: "MatchRecord")
        query2.whereKey("user1Id", .equalTo(matchRecord.user2Id))
        query2.whereKey("user2Id", .equalTo(matchRecord.user1Id))
        query2.whereKey("status", .equalTo("cancelled"))
        query2.limit = 1
        query2.find { result in
            switch result {
            case .success(let records):
                allRecords.append(contentsOf: records)
            case .failure:
                break
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            if let firstRecord = allRecords.first,
               let objectId = firstRecord.objectId?.stringValue {
                // 找到cancelled记录，更新为active
                self.updateMatchRecordStatus(objectId: objectId, status: "active") { success, error in
                    completion(success)
                }
            } else {
                // 没有找到cancelled记录
                completion(false)
            }
        }
    }

    // 上传匹配记录到LeanCloud
    // uploadMatchRecord method moved to LeanCloudService+MatchRecordUpload.swift
    // autoDetectAndUploadMatchRecords method moved to LeanCloudService+MatchRecordUpload.swift
    func analyzeMessagesForCurrentUser(_ currentUserId: String, _ messages: [[String: Any]]) -> [MatchRecord] {
        var matchRecords: [MatchRecord] = []
        
        // 开始分析消息
        
        // 按用户对分组消息
        var userPairMessages: [String: [[String: Any]]] = [:]
        
        
        for (index, message) in messages.enumerated() {
            guard let senderId = message["senderId"] as? String,
                  let receiverId = message["receiverId"] as? String else {
                if index < 5 {
                }
                continue
            }
            
            // 只处理包含当前用户的消息
            guard senderId == currentUserId || receiverId == currentUserId else {
                if index < 5 {
                }
                continue
            }
            
            // 创建用户对键（确保顺序一致）
            let userPairKey = senderId < receiverId ? "\(senderId)|\(receiverId)" : "\(receiverId)|\(senderId)"
            
            if userPairMessages[userPairKey] == nil {
                userPairMessages[userPairKey] = []
            }
            userPairMessages[userPairKey]?.append(message)
            
        }
        
        // 分析每个用户对的消息
        for (userPairKey, messages) in userPairMessages {
            if let matchRecord = analyzeUserPairMessages(userPairKey, messages) {
                // 检查是否已经上传过这个匹配记录
                if !hasMatchRecordBeenUploaded(matchRecord) {
                    matchRecords.append(matchRecord)
                }
            }
        }
        
        return matchRecords
    }
    
    // 检查匹配记录是否已经上传过
    private func hasMatchRecordBeenUploaded(_ matchRecord: MatchRecord) -> Bool {
        let matchKey = "\(matchRecord.user1Id)_\(matchRecord.user2Id)"
        let alternateMatchKey = "\(matchRecord.user2Id)_\(matchRecord.user1Id)"
        
        // 检查两种可能的键格式
        let hasBeenUploaded1 = UserDefaults.standard.bool(forKey: "MatchRecord_\(matchKey)")
        let hasBeenUploaded2 = UserDefaults.standard.bool(forKey: "MatchRecord_\(alternateMatchKey)")
        
        let hasBeenUploaded = hasBeenUploaded1 || hasBeenUploaded2
        
        
        return hasBeenUploaded
    }
    
    // 清除所有MatchRecord上传标记（用于调试）
    // clearAllMatchRecordUploadFlags method moved to LeanCloudService+MatchRecordUpload.swift
    // clearMatchRecordUploadFlag method moved to LeanCloudService+MatchRecordUpload.swift
    // uploadMatchRecords method moved to LeanCloudService+MatchRecordUpload.swift
    // uploadMatchRecordToLeanCloud method moved to LeanCloudService+MatchRecordUpload.swift
    // generateMatchRecordsFromMessages - 使用 LCQuery
    func generateMatchRecordsFromMessages(completion: @escaping ([MatchRecord]?) -> Void) {
        // ✅ 使用 LCQuery 查询 Message
        let query = LCQuery(className: "Message")
        query.whereKey("createdAt", .descending)
        query.limit = 1000
        
        _ = query.find { result in
            switch result {
            case .success(let objects):
                // 转换为字典数组以便复用已有逻辑
                let results = objects.compactMap { object -> [String: Any]? in
                    guard let objectId = object.objectId?.value else { return nil }
                    
                    var dict: [String: Any] = ["objectId": objectId]
                    
                    if let from = object["from"]?.stringValue {
                        dict["from"] = from
                    }
                    if let to = object["to"]?.stringValue {
                        dict["to"] = to
                    }
                    if let createdAt = object.createdAt?.value {
                        dict["createdAt"] = ISO8601DateFormatter().string(from: createdAt)
                    }
                    
                    return dict
                }
                
                // 分析消息，找出匹配成功的用户对
                let matchRecords = self.analyzeMessagesForMatches(results)
                completion(matchRecords)
                
            case .failure:
                completion(nil)
            }
        }
    }
    
    // 分析消息数据，找出匹配成功的用户对
    private func analyzeMessagesForMatches(_ messages: [[String: Any]]) -> [MatchRecord] {
        var matchRecords: [MatchRecord] = []
        var userPairs: Set<String> = [] // 用于去重
        
        // 按用户对分组消息
        var userPairMessages: [String: [[String: Any]]] = [:]
        
        for message in messages {
            guard let senderId = message["senderId"] as? String,
                  let receiverId = message["receiverId"] as? String else {
                continue
            }
            
            // 创建用户对键（确保顺序一致）
            let userPairKey = senderId < receiverId ? "\(senderId)|\(receiverId)" : "\(receiverId)|\(senderId)"
            
            if userPairMessages[userPairKey] == nil {
                userPairMessages[userPairKey] = []
            }
            userPairMessages[userPairKey]?.append(message)
        }
        
        // 分析每个用户对的消息
        for (userPairKey, messages) in userPairMessages {
            if let matchRecord = analyzeUserPairMessages(userPairKey, messages) {
                matchRecords.append(matchRecord)
                userPairs.insert(userPairKey)
            }
        }
        
        return matchRecords
    }
    
    // 分析特定用户对的消息，判断是否匹配成功
    private func analyzeUserPairMessages(_ userPairKey: String, _ messages: [[String: Any]]) -> MatchRecord? {
        
        let userIds = userPairKey.split(separator: "|").map(String.init)
        guard userIds.count == 2 else { 
            return nil 
        }
        
        let user1Id = userIds[0]
        let user2Id = userIds[1]
        
        
        for (_, message) in messages.enumerated() {
            if message["senderId"] as? String != nil,
               message["receiverId"] as? String != nil,
               message["messageType"] as? String != nil,
               message["content"] as? String != nil,
               message["timestamp"] as? String != nil {
            }
        }
        
        var user1ToUser2Active = false
        var user2ToUser1Active = false
        var latestLikeTime: Date?
        
        // 简化逻辑：直接按时间顺序处理消息，最后一条消息决定最终状态
        let sortedMessages = messages.sorted(by: { 
            let date1 = parseDate($0["timestamp"] as? String ?? "") ?? Date.distantPast
            let date2 = parseDate($1["timestamp"] as? String ?? "") ?? Date.distantPast
            return date1 > date2  // 改为降序排列，最新的消息在前
        })
        
        // 简化日志：只打印用户对和消息数量
        
        // 重新初始化状态变量
        user1ToUser2Active = false
        user2ToUser1Active = false
        
        for (index, message) in sortedMessages.enumerated() {
            
            guard let senderId = message["senderId"] as? String,
                  let receiverId = message["receiverId"] as? String,
                  let messageType = message["messageType"] as? String,
                  let timestamp = message["timestamp"] as? String,
                  let messageDate = parseDate(timestamp) else {
                if index < 3 {
                }
                continue
            }
            
            // 根据消息内容判断消息类型
            let content = message["content"] as? String ?? ""
            var actualMessageType = messageType
            
            // 打印前3条消息的详细信息
            if index < 3 {
            }
            
            // 修改匹配逻辑：好友申请也视为"喜欢"消息
            if content.contains("喜欢了你") {
                actualMessageType = "favorite"
                if index < 3 {
                }
            } else if content.contains("取消喜欢了你") {
                actualMessageType = "unfavorite"
                if index < 3 {
                }
            } else if content.contains("点赞了你") {
                actualMessageType = "like"
                if index < 3 {
                }
            } else if content.contains("取消点赞了你") {
                actualMessageType = "unlike"
                if index < 3 {
                }
            } else if content.contains("对你发送了好友申请") {
                // 🔧 修复：好友申请也视为"喜欢"消息
                actualMessageType = "favorite"
                if index < 3 {
                }
            } else if content.contains("撤销了好友申请") {
                // 🔧 修复：撤销好友申请也视为"取消喜欢"消息
                actualMessageType = "unfavorite"
                if index < 3 {
                }
            } else {
                if index < 3 {
                }
            }
            
            // 直接根据最新消息更新状态
            if senderId == user1Id && receiverId == user2Id {
                if actualMessageType == "favorite" || actualMessageType == "like" {
                    user1ToUser2Active = true
                    latestLikeTime = messageDate
                    if index < 3 {
                    }
                } else if actualMessageType == "unfavorite" || actualMessageType == "unlike" {
                    user1ToUser2Active = false
                    if index < 3 {
                    }
                }
            } else if senderId == user2Id && receiverId == user1Id {
                if actualMessageType == "favorite" || actualMessageType == "like" {
                    user2ToUser1Active = true
                    latestLikeTime = messageDate
                    if index < 3 {
                    }
                } else if actualMessageType == "unfavorite" || actualMessageType == "unlike" {
                    user2ToUser1Active = false
                    if index < 3 {
                    }
                }
            }
            
            if actualMessageType == "favorite" || actualMessageType == "like" {
                if latestLikeTime == nil || messageDate > latestLikeTime! {
                    latestLikeTime = messageDate
                }
            }
        }
        
        // 只有双向有效喜欢才算匹配成功
        
        guard user1ToUser2Active && user2ToUser1Active else {
            
            for (_, message) in messages.enumerated() {
                if message["senderId"] as? String != nil,
                   message["receiverId"] as? String != nil,
                   message["messageType"] as? String != nil,
                   message["content"] as? String != nil,
                   message["timestamp"] as? String != nil {
                }
            }
            
            // 特别调试：检查为什么没有双向喜欢
            
            for message in messages {
                if let senderId = message["senderId"] as? String,
                   let receiverId = message["receiverId"] as? String,
                   let content = message["content"] as? String {
                    
                    if senderId == user1Id && receiverId == user2Id {
                        if content.contains("喜欢了你") || content.contains("点赞了你") {
                            // 找到用户1到用户2的喜欢
                        }
                    } else if senderId == user2Id && receiverId == user1Id {
                        if content.contains("喜欢了你") || content.contains("点赞了你") {
                            // 找到用户2到用户1的喜欢
                        }
                    }
                }
            }
            
            return nil
        }
        
        
        // 获取用户信息
        let user1Info = getUserInfoFromMessages(user1Id, messages)
        let user2Info = getUserInfoFromMessages(user2Id, messages)
        
        
        // 创建MatchRecord
        let matchRecord = MatchRecord(
            user1Id: user1Id,
            user2Id: user2Id,
            user1Name: user1Info.name,
            user2Name: user2Info.name,
            user1Avatar: user1Info.avatar,
            user2Avatar: user2Info.avatar,
            user1LoginType: user1Info.loginType,
            user2LoginType: user2Info.loginType,
            matchTime: latestLikeTime ?? Date(),
            matchLocation: CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0),
            status: "active",
            deviceId: "unknown",
            timezone: TimeZone.current.identifier,
            deviceTime: latestLikeTime ?? Date()
        )
        
        return matchRecord
    }
    
    // 从消息中提取用户信息
    // getUserInfoFromMessages method moved to LeanCloudService+MatchRecordFetch.swift
    
    /// 从消息中获取用户信息
    func getUserInfoFromMessages(_ userId: String, _ messages: [[String: Any]]) -> (name: String, avatar: String, loginType: String) {
        // 查找用户信息
        for message in messages {
            if let senderId = message["sender_id"] as? String, senderId == userId {
                let name = message["sender_name"] as? String ?? "未知用户"
                let loginType = message["sender_login_type"] as? String ?? "unknown"
                let avatar = message["sender_avatar"] as? String ?? UserAvatarUtils.defaultAvatar(for: loginType)
                return (name, avatar, loginType)
            }
        }
        
        return ("未知用户", UserAvatarUtils.defaultAvatar(for: "guest"), "unknown")
    }
    
    /// 检查并修正已取消的匹配记录
    func checkAndCorrectCancelledMatchRecords(userId: String, allMatchRecords: [[String: Any]], completion: @escaping ([MatchRecord], String?) -> Void) {
        // 过滤出cancelled状态的记录
        let cancelledRecords = allMatchRecords.filter { record in
            if let status = record["status"] as? String {
                return status == "cancelled"
            }
            return false
        }
        
        if cancelledRecords.isEmpty {
            // 没有cancelled记录，直接返回所有记录
            let matchRecords = allMatchRecords.compactMap { MatchRecord.fromLeanCloudData($0) }
            completion(matchRecords, nil)
                    return
                }
                
        // 检查FavoriteRecord以确定是否应该恢复
        self.checkFavoriteRecordForMatchCorrection(userId: userId, cancelledMatchRecords: cancelledRecords.compactMap { MatchRecord.fromLeanCloudData($0) }) { correctedRecords, error in
                if let error = error {
                completion([], error)
                    return
                }
                
            // 合并修正后的记录和原始记录
            let allMatchRecords = allMatchRecords.compactMap { MatchRecord.fromLeanCloudData($0) }
            let finalRecords = allMatchRecords + correctedRecords
            completion(finalRecords, nil)
        }
    }
    
    /// 检查FavoriteRecord以确定是否应该恢复匹配记录
    func checkFavoriteRecordForMatchCorrection(userId: String, cancelledMatchRecords: [MatchRecord], completion: @escaping ([MatchRecord], String?) -> Void) {
        // 获取FavoriteRecord
        fetchAllRecordsForClass(className: "FavoriteRecord") { [weak self] favoriteRecords, error in
            guard let self = self else {
                completion([], "服务不可用")
                                    return
                                }
                                
            if let error = error {
                completion([], error)
                return
            }
            
            guard let favoriteRecords = favoriteRecords else {
                completion([], "无法获取FavoriteRecord")
            return
        }
        
            // 分析FavoriteRecord以确定应该恢复的匹配记录
            let correctedRecords = self.analyzeFavoriteRecordsForCurrentUser(userId, favoriteRecords)
            completion(correctedRecords, nil)
        }
    }
    
    /// 分析FavoriteRecord以确定应该恢复的匹配记录
    func analyzeFavoriteRecordsForCurrentUser(_ currentUserId: String, _ favoriteRecords: [[String: Any]]) -> [MatchRecord] {
        var matchRecords: [MatchRecord] = []
        
        // 清理重复的FavoriteRecord
        let cleanedFavoriteRecords = cleanupDuplicateFavoriteRecords(favoriteRecords)
        
        // 分析每个FavoriteRecord
        for favoriteRecord in cleanedFavoriteRecords {
            if let user1Id = favoriteRecord["user1Id"] as? String,
               let user2Id = favoriteRecord["user2Id"] as? String,
               let user1Name = favoriteRecord["user1Name"] as? String,
               let user2Name = favoriteRecord["user2Name"] as? String,
               let user1Avatar = favoriteRecord["user1Avatar"] as? String,
               let user2Avatar = favoriteRecord["user2Avatar"] as? String,
               let user1LoginType = favoriteRecord["user1LoginType"] as? String,
               let user2LoginType = favoriteRecord["user2LoginType"] as? String,
               let favoriteTime = favoriteRecord["favorite_time"] as? String,
               let favoriteDate = parseDate(favoriteTime) {
                
                // 检查是否应该恢复匹配记录
                if (user1Id == currentUserId || user2Id == currentUserId) {
                    let matchRecord = MatchRecord(
                        user1Id: user1Id,
                        user2Id: user2Id,
                        user1Name: user1Name,
                        user2Name: user2Name,
                        user1Avatar: user1Avatar,
                        user2Avatar: user2Avatar,
                        user1LoginType: user1LoginType,
                        user2LoginType: user2LoginType,
                        matchTime: favoriteDate,
                        matchLocation: nil,
                                    status: "active",
                        deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "",
                        timezone: TimeZone.current.identifier,
                        deviceTime: Date()
                    )
                    matchRecords.append(matchRecord)
                }
            }
        }
        
        return matchRecords
    }
    
    /// 清理重复的FavoriteRecord
    func cleanupDuplicateFavoriteRecords(_ favoriteRecords: [[String: Any]]) -> [[String: Any]] {
        var uniqueRecords: [[String: Any]] = []
        var seenPairs: Set<String> = []
        
        for record in favoriteRecords {
            if let user1Id = record["user1Id"] as? String,
               let user2Id = record["user2Id"] as? String {
                let pairKey1 = "\(user1Id)_\(user2Id)"
                let pairKey2 = "\(user2Id)_\(user1Id)"
                
                if !seenPairs.contains(pairKey1) && !seenPairs.contains(pairKey2) {
                    uniqueRecords.append(record)
                    seenPairs.insert(pairKey1)
                    seenPairs.insert(pairKey2)
                }
            }
        }
        
        return uniqueRecords
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }
    
    // 查询MatchRecord表中的所有记录
    // fetchMatchRecords method moved to LeanCloudService+MatchRecordFetch.swift
    // fetchMatchRecords(userId:) method moved to LeanCloudService+MatchRecordFetch.swift
        
    // deleteActiveMatchRecordsForUsers method moved to LeanCloudService+MatchRecordDelete.swift
    // deleteMatchRecord(objectId:completion:) method moved to LeanCloudService+MatchRecordDelete.swift
    // updateMatchRecordStatus method moved to LeanCloudService+MatchRecordDelete.swift
        
    // deleteMatchRecord(objectId:completion:with error) method moved to LeanCloudService+MatchRecordDelete.swift
    // updateMatchRecordStatusByUsers method moved to LeanCloudService+MatchRecordDelete.swift
    
    // 检查是否已存在active状态的MatchRecord - 使用 LCQuery
    private func checkExistingActiveMatchRecord(_ matchRecord: MatchRecord, completion: @escaping (Bool) -> Void) {
        // ✅ 使用 LCQuery 查询，使用 parallel 避免复杂 OR 查询
        let group = DispatchGroup()
        var found = false
        
        // 查询1: user1Id -> user2Id
        group.enter()
        let query1 = LCQuery(className: "MatchRecord")
        query1.whereKey("user1Id", .equalTo(matchRecord.user1Id))
        query1.whereKey("user2Id", .equalTo(matchRecord.user2Id))
        query1.whereKey("status", .equalTo("active"))
        query1.limit = 1
        _ = query1.find { result in
            switch result {
            case .success(let objects):
                if !objects.isEmpty {
                    found = true
                }
            case .failure:
                break
            }
            group.leave()
        }
        
        // 查询2: user2Id -> user1Id
        group.enter()
        let query2 = LCQuery(className: "MatchRecord")
        query2.whereKey("user1Id", .equalTo(matchRecord.user2Id))
        query2.whereKey("user2Id", .equalTo(matchRecord.user1Id))
        query2.whereKey("status", .equalTo("active"))
        query2.limit = 1
        _ = query2.find { result in
            switch result {
            case .success(let objects):
                if !objects.isEmpty {
                    found = true
                }
            case .failure:
                break
            }
            group.leave()
        }
        
        group.notify(queue: .main) {
            completion(found)
        }
    }
}
