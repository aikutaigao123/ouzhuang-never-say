//
//  LegacySearchView+FavoriteSync.swift
//  NeverSayNo
//
//  Created by Die chen on 2025/7/1.
//

import SwiftUI
import Foundation
import LeanCloud

extension LegacySearchView {
    // MARK: - Favorite Records Sync Methods
    
    /// 从双向喜欢创建匹配记录
    func createMatchRecordsFromDualLike(matchedUsers: [String], usersWhoLikedMeToUse: [FavoriteRecord]) -> [MatchRecord] {
        guard let currentUser = userManager.currentUser else { return [] }
        
        var friendsFromMatchedUsers: [MatchRecord] = []
        
        // 调试：打印当前usersWhoLikedMe数组的详细内容
        for (_, _) in usersWhoLikedMeToUse.enumerated() {
        }
        
        for (_, userId) in matchedUsers.enumerated() {
            
            // 从favoriteRecords中获取正确的用户信息（当前用户喜欢的目标用户信息）
            let favoriteRecord = favoriteRecords.first { $0.favoriteUserId == userId }
            
            
            if favoriteRecord != nil {
            }
            
            let userName = favoriteRecord?.favoriteUserName ?? "未知用户"
            
            // 🔧 修复：从UserAvatarRecord表获取正确的用户头像，而不是从FavoriteRecord
            let userAvatar = getCorrectUserAvatar(userId: userId, fallbackAvatar: favoriteRecord?.favoriteUserAvatar ?? "😀")
            
            // 🔧 修复：应该使用userLoginType而不是favoriteUserLoginType
            // userLoginType是喜欢者的登录类型，favoriteUserLoginType是被喜欢者的登录类型
            let userLoginType = UserTypeUtils.getLoginTypeFromUserId(userId)
            
            
            // 🔍 调试信息：当前登录用户信息
            
            // 🔍 调试信息：目标用户信息
            
            // 🔍 调试信息：MatchRecord创建参数
            let user1LoginTypeString = currentUser.loginType == .apple ? "apple" : "guest"
            
            let matchRecord = MatchRecord(
                user1Id: currentUser.userId,
                user2Id: userId,
                user1Name: currentUser.fullName,
                user2Name: userName,
                user1Avatar: "😀",
                user2Avatar: userAvatar,
                user1LoginType: user1LoginTypeString,
                user2LoginType: userLoginType,
                matchTime: Date(),
                matchLocation: nil,
                deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
                timezone: TimeZone.current.identifier,
                deviceTime: Date()
            )
            
            // 🔍 调试信息：创建的MatchRecord详情
            
            // 🔍 头像调试信息
            if favoriteRecord != nil {
            }
            
            friendsFromMatchedUsers.append(matchRecord)
        }
        
        return friendsFromMatchedUsers
    }
    
    /// 验证usersWhoLikedMe与消息历史的一致性
    func validateUsersWhoLikedMeWithMessageHistory(with latestUsersWhoLikedMe: [FavoriteRecord]? = nil) {
        let _ = latestUsersWhoLikedMe ?? self.usersWhoLikedMe
        
        guard let currentUser = userManager.currentUser else { 
            return 
        }
        
        
        // 查询当前用户的所有消息
        let messageUrlString = "\(LeanCloudService.shared.serverUrl)/1.1/classes/Message?where={\"$or\":[{\"senderId\":\"\(currentUser.id)\"},{\"receiverId\":\"\(currentUser.id)\"}]}&order=-createdAt&limit=1000"
        
        guard let messageUrl = URL(string: messageUrlString) else { 
            return 
        }
        
        var messageRequest = URLRequest(url: messageUrl)
        messageRequest.httpMethod = "GET"
        messageRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        messageRequest.setValue(Configuration.shared.leanCloudAppId, forHTTPHeaderField: "X-LC-Id")
        messageRequest.setValue(Configuration.shared.leanCloudAppKey, forHTTPHeaderField: "X-LC-Key")
        messageRequest.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: messageRequest) { data, response, error in
            DispatchQueue.main.async {
                
                if error != nil {
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    
                    if httpResponse.statusCode == 200, let data = data {
                        
                        do {
                            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                            if let results = json?["results"] as? [[String: Any]] {
                        
                        // 分析消息历史，找出真正喜欢当前用户的用户
                        var validLikers = Set<String>()
                        var userPairs = Set<String>()
                        
                        // 收集所有用户对
                        for result in results {
                            if let senderId = result["senderId"] as? String,
                               let receiverId = result["receiverId"] as? String {
                                let pair = [senderId, receiverId].sorted().joined(separator: "|")
                                userPairs.insert(pair)
                            }
                        }
                        
                        // 分析每个用户对的消息历史
                        for pair in userPairs {
                            let userIds = pair.components(separatedBy: "|")
                            guard userIds.count == 2 else { continue }
                            
                            let user1 = userIds[0]
                            let user2 = userIds[1]
                            
                            // 获取这个用户对的所有消息
                            let pairMessages = results.filter { result in
                                let senderId = result["senderId"] as? String ?? ""
                                let receiverId = result["receiverId"] as? String ?? ""
                                return (senderId == user1 && receiverId == user2) || (senderId == user2 && receiverId == user1)
                            }.sorted { (a, b) in
                                let timeA = a["createdAt"] as? String ?? ""
                                let timeB = b["createdAt"] as? String ?? ""
                                return timeA > timeB  // 改为降序排列，最新的消息在前
                            }
                            
                            // 分析消息历史，确定最终状态
                            var user1LikesUser2 = false
                            var user2LikesUser1 = false
                            
                            for message in pairMessages {
                                let senderId = message["senderId"] as? String ?? ""
                                let messageType = message["messageType"] as? String ?? ""
                                
                                if senderId == user1 && messageType == "favorite" {
                                    user1LikesUser2 = true
                                } else if senderId == user1 && messageType == "unfavorite" {
                                    user1LikesUser2 = false
                                } else if senderId == user2 && messageType == "favorite" {
                                    user2LikesUser1 = true
                                } else if senderId == user2 && messageType == "unfavorite" {
                                    user2LikesUser1 = false
                                }
                            }
                            
                            // 检查双向喜欢：只有双方都喜欢对方时，才认为是有效的匹配
                            if user2 == currentUser.userId && user1LikesUser2 && user2LikesUser1 {
                                // user1喜欢当前用户，且当前用户也喜欢user1
                                validLikers.insert(user1)
                            } else if user1 == currentUser.userId && user2LikesUser1 && user1LikesUser2 {
                                // user2喜欢当前用户，且当前用户也喜欢user2
                                validLikers.insert(user2)
                            }
                            
                            // 添加调试信息
                            if user2 == currentUser.userId {
                            } else if user1 == currentUser.userId {
                            }
                        }
                        
                        
                        let _ = self.usersWhoLikedMe.map { record -> String in
                            let status = record.status ?? "nil"
                            return "\(record.userId)(status:\(status))"
                        }.joined(separator: ", ")
                    }
                } catch {
                }
            } else {
            }
        } else {
        }
        }
        }.resume()
    }
    
    /// 强制以服务器数据为准，清理本地不一致数据
    func forceSyncWithServerData() {
        
        // 1. 强制同步FavoriteRecord
        syncFavoriteRecordsFromLeanCloud()
        
        // 2. 强制同步usersWhoLikedMe
        loadUsersWhoLikedMe {
        }
        
        // ⚠️ 已废弃：不再从 MatchRecord 表同步好友数据
        // 好友列表现在由 FriendshipManager 从 _Followee 表获取
        // 发送刷新通知
        NotificationCenter.default.post(name: NSNotification.Name("RefreshFriendsList"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("RefreshNewFriends"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("RefreshMatchStatus"), object: nil)
    }
    
    /// 从LeanCloud同步喜欢记录（同步所有记录，包括cancelled状态）
    func syncFavoriteRecordsFromLeanCloud() {
        guard let currentUser = userManager.currentUser else { 
            // 当前用户为nil，无法同步喜欢记录
            return 
        }
        
        // 开始从LeanCloud同步喜欢记录
        
        // 清理错误的favoriteRecords数据
        self.cleanupInvalidFavoriteRecords()
        
        // 🔧 修复：查询所有记录（包括active和cancelled），确保本地数据与服务器同步
        let urlString = "\(LeanCloudService.shared.serverUrl)/1.1/classes/FavoriteRecord?where={\"userId\":\"\(currentUser.id)\"}&order=-createdAt" // 🔧 统一：使用 objectId
        guard let url = URL(string: urlString) else {
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        LeanCloudService.shared.setLeanCloudHeaders(&request)
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if error != nil {
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let results = json["results"] as? [[String: Any]] {
                        
                        
                        // 清空本地记录，重新同步
                        self.favoriteRecords.removeAll()
                        
                        for (_, result) in results.enumerated() {
                            // 处理记录
                            
                            if let favoriteUserId = result["favoriteUserId"] as? String {
                                let favoriteUserName = result["favoriteUserName"] as? String
                                let favoriteUserEmail = result["favoriteUserEmail"] as? String
                                let favoriteUserLoginType = result["favoriteUserLoginType"] as? String
                                let favoriteUserAvatar = result["favoriteUserAvatar"] as? String
                                let recordObjectId = result["recordObjectId"] as? String
                                let status = result["status"] as? String ?? "active"
                                
                                
                                // 🔧 修复：只保存状态为 "active" 的记录到本地
                                if status == "active" {
                                    // 🔍 调试信息：用户类型推断
                                    let _ = UserTypeUtils.getLoginTypeFromUserId(favoriteUserId)
                                    
                                    let processedFavoriteUserLoginType = favoriteUserLoginType?.isEmpty == true ? nil : favoriteUserLoginType
                                    
                                    let favoriteRecord = FavoriteRecord(
                                        userId: currentUser.userId,
                                        favoriteUserId: favoriteUserId,
                                        favoriteUserName: favoriteUserName?.isEmpty == true ? nil : favoriteUserName,
                                        favoriteUserEmail: favoriteUserEmail?.isEmpty == true ? nil : favoriteUserEmail,
                                        favoriteUserLoginType: processedFavoriteUserLoginType,
                                        favoriteUserAvatar: favoriteUserAvatar?.isEmpty == true ? nil : favoriteUserAvatar,
                                        recordObjectId: recordObjectId?.isEmpty == true ? nil : recordObjectId,
                                        status: status
                                    )
                                    
                                    self.favoriteRecords.append(favoriteRecord)
                                } else {
                                }
                            } else {
                            }
                        }
                        
                        // 检查并去重favoriteRecords中的重复记录
                        let originalCount = self.favoriteRecords.count
                        var uniqueRecords: [FavoriteRecord] = []
                        var seenUserIds: Set<String> = []
                        
                        for record in self.favoriteRecords {
                            if !seenUserIds.contains(record.favoriteUserId) {
                                uniqueRecords.append(record)
                                seenUserIds.insert(record.favoriteUserId)
                            }
                        }
                        
                        if originalCount != uniqueRecords.count {
                            self.favoriteRecords = uniqueRecords
                        }
                        
                        
                        // 再次清理无效数据，因为服务器数据可能仍然不一致
                        self.cleanupInvalidFavoriteRecords()
                        
                        // 保存到本地
                        self.saveFavoriteRecords()
                        
                    } else {
                    }
                } else {
                }
            }
        }.resume()
    }
    
    /// 从LeanCloud同步点赞记录
    func syncLikeRecordsFromLeanCloud() {
        guard let currentUser = userManager.currentUser else { return }
        
        
        LeanCloudService.shared.fetchActiveLikeRecords(userId: currentUser.userId) { results, error in
            DispatchQueue.main.async {
                if error != nil {
                    return
                }
                
                if let results = results {
                    
                    // 清空本地记录，重新同步
                    self.likeRecords.removeAll()
                    
                    for result in results {
                        if let likedUserId = result["likedUserId"] as? String {
                            let likedUserName = result["likedUserName"] as? String
                            let likedUserEmail = result["likedUserEmail"] as? String
                            let likedUserLoginType = result["likedUserLoginType"] as? String
                            let likedUserAvatar = result["likedUserAvatar"] as? String
                            let recordObjectId = result["recordObjectId"] as? String
                            let status = result["status"] as? String
                            
                            let likeRecord = LikeRecord(
                                userId: currentUser.userId,
                                likedUserId: likedUserId,
                                likedUserName: likedUserName?.isEmpty == true ? nil : likedUserName,
                                likedUserEmail: likedUserEmail?.isEmpty == true ? nil : likedUserEmail,
                                likedUserLoginType: likedUserLoginType?.isEmpty == true ? nil : likedUserLoginType,
                                likedUserAvatar: likedUserAvatar?.isEmpty == true ? nil : likedUserAvatar,
                                recordObjectId: recordObjectId?.isEmpty == true ? nil : recordObjectId,
                                status: status?.isEmpty == true ? "active" : status
                            )
                            self.likeRecords.append(likeRecord)
                        }
                    }
                    
                    // 保存到本地
                    self.saveLikeRecords()
                } else {
                }
            }
        }
    }
    
    // 从LeanCloud查询谁喜欢了当前用户
    func loadUsersWhoLikedMe(completion: (() -> Void)? = nil) {
        let loadUsersWhoLikedMeStartTime = Date()
        if let searchStartTime = searchStartTime {
            let _ = loadUsersWhoLikedMeStartTime.timeIntervalSince(searchStartTime)
        }
        
        let _ = Thread.callStackSymbols.prefix(5).joined(separator: "\n    ")
        
        guard let currentUser = userManager.currentUser else { 
            return 
        }
        
        
        // ✅ 按照开发指南：使用 LCQuery 创建查询 - 查询所有记录（包括active和cancelled）
        let query = LCQuery(className: "FavoriteRecord")
        query.whereKey("favoriteUserId", .equalTo(currentUser.userId))
        query.whereKey("favoriteTime", .descending)
        query.limit = 1000
        
        query.find { result in
            let loadUsersWhoLikedMeEndTime = Date()
            let _ = loadUsersWhoLikedMeEndTime.timeIntervalSince(loadUsersWhoLikedMeStartTime)
            DispatchQueue.main.async {
                if let searchStartTime = self.searchStartTime {
                    let _ = loadUsersWhoLikedMeEndTime.timeIntervalSince(searchStartTime)
                }
                
                switch result {
                case .success(let records):
                    // 转换为字典数组
                    let results = records.compactMap { record -> [String: Any]? in
                        var dict: [String: Any] = [:]
                        dict["objectId"] = record.objectId?.stringValue ?? ""
                        dict["userId"] = record["userId"]?.stringValue ?? ""
                        dict["favoriteUserId"] = record["favoriteUserId"]?.stringValue ?? ""
                        dict["favoriteUserName"] = record["favoriteUserName"]?.stringValue ?? ""
                        dict["favoriteUserEmail"] = record["favoriteUserEmail"]?.stringValue ?? ""
                        dict["favoriteUserLoginType"] = record["favoriteUserLoginType"]?.stringValue ?? ""
                        dict["favoriteUserAvatar"] = record["favoriteUserAvatar"]?.stringValue ?? ""
                        dict["recordObjectId"] = record["recordObjectId"]?.stringValue ?? ""
                        dict["status"] = record["status"]?.stringValue ?? "active"
                        dict["favoriteTime"] = record["favoriteTime"]?.stringValue ?? ""
                        return dict
                    }
                    
                    // 继续处理数据
                    let _ = self.usersWhoLikedMe.count
                    let _ = self.usersWhoLikedMe.map { "\($0.userId)(status:\($0.status ?? "nil"))" }.joined(separator: ", ")
                    
                    // 将 LeanCloud 返回的原始 FavoriteRecord 数据与好友列表信息聚合：
                    // - Key 为 userId（即对方的 objectId）
                    // - Value 为我们自定义的 FavoriteRecord（结构更完整，便于 UI 使用）
                    // - 通过状态优先级与字段补齊规则，始终保留对方最新且有效的点赞记录
                    var aggregatedRecords: [String: FavoriteRecord] = [:]
                    var skippedDuplicates = 0
                    
                    for result in results {
                        // 1. 尝试把 LeanCloud 返回的原始字典转换为 FavoriteRecord。
                        //    如果字段缺失（例如 LeanCloud 历史遗留数据）导致初始化失败，则跳过。
                        if var record = FavoriteRecord(dictionary: result) {
                            let newStatus = record.status?.lowercased()
                            let existing = aggregatedRecords[record.userId]
                            let existingStatus = existing?.status?.lowercased()
                            
                            // 2. 补齐 LeanCloud 表中可能缺失的用户姓名 / 邮箱字段。
                            //    老数据往往只有 userId，缺乏 `favoriteUserName` 或 `favoriteUserEmail`，
                            //    此处从原始字典再取一次，避免 UI 中显示"未知用户"。
                            if (record.favoriteUserName == nil || record.favoriteUserName?.isEmpty == true),
                               let rawName = result["favoriteUserName"] as? String, !rawName.isEmpty {
                                record = FavoriteRecord(
                                    userId: record.userId,
                                    favoriteUserId: record.favoriteUserId,
                                    favoriteUserName: rawName,
                                    favoriteUserEmail: record.favoriteUserEmail,
                                    favoriteUserLoginType: record.favoriteUserLoginType,
                                    favoriteUserAvatar: record.favoriteUserAvatar,
                                    recordObjectId: record.recordObjectId,
                                    status: record.status
                                )
                            }
                            if (record.favoriteUserEmail == nil || record.favoriteUserEmail?.isEmpty == true),
                               let rawEmail = result["favoriteUserEmail"] as? String, !rawEmail.isEmpty {
                                record = FavoriteRecord(
                                    userId: record.userId,
                                    favoriteUserId: record.favoriteUserId,
                                    favoriteUserName: record.favoriteUserName,
                                    favoriteUserEmail: rawEmail,
                                    favoriteUserLoginType: record.favoriteUserLoginType,
                                    favoriteUserAvatar: record.favoriteUserAvatar,
                                    recordObjectId: record.recordObjectId,
                                    status: record.status
                                )
                            }
                            
                            // 3. 根据状态优先级决定是否覆盖已有缓存：
                            //    - 若旧状态是 friend，则保留旧记录（表示已经互为好友，可靠性最高）。
                            //    - 若旧状态是 active，新状态不是 friend，则说明新记录并未提供更好的信息，无需替换。
                            //    - 若新状态是 friend，则优先使用新记录，以反映最新的好友关系。
                            //    - 若旧记录是无效状态（如 cancelled / declined / rejected），允许被新的 active/friend 覆盖。
                            //    - 其他情况则视为重复数据，尽量保留已有记录。
                            let shouldReplace: Bool = {
                                guard let existingStatus = existingStatus else {
                                    return true // 当缓存中不存在该用户时，直接写入
                                }
                                if existingStatus == "friend" {
                                    return false
                                }
                                if existingStatus == "active" && newStatus != "friend" {
                                    return false
                                }
                                if newStatus == "friend" {
                                    return true
                                }
                                if newStatus == "active" && existingStatus != "friend" {
                                    return true
                                }
                                if existingStatus == "cancelled" || existingStatus == "declined" || existingStatus == "rejected" {
                                    return true
                                }
                                return existing == nil
                            }()
                            
                            if !shouldReplace && existing != nil {
                                skippedDuplicates += 1
                                continue
                            }
                            
                            aggregatedRecords[record.userId] = record
                        }
                    }
                    
                    func finalizeUsersWhoLikedMe(with header: String) {
                        FriendshipManager.shared.fetchFriendsList { friends, _ in
                            var mergedRecords = aggregatedRecords
                            if let friends = friends {
                                let friendInfos = friends.filter { $0.userId != currentUser.id }
                                for friend in friendInfos {
                                    let existing = mergedRecords[friend.userId]
                                    // 🎯 修改：如果 existing 记录的 status 是 cancelled/declined/rejected，不覆盖为 friend
                                    // 这样可以确保如果用户主动取消了喜欢，即使后来成为好友，也不会显示邮箱
                                    if let existingStatus = existing?.status?.lowercased(),
                                       existingStatus == "cancelled" || existingStatus == "declined" || existingStatus == "rejected" {
                                        continue // 跳过，不覆盖 cancelled 状态的记录
                                    }
                                    let resolvedStatus = "friend"
                                    let updatedRecord = FavoriteRecord(
                                        userId: friend.userId,
                                        favoriteUserId: currentUser.id,
                                        favoriteUserName: existing?.favoriteUserName ?? friend.fullName,
                                        favoriteUserEmail: existing?.favoriteUserEmail ?? friend.email,
                                        favoriteUserLoginType: existing?.favoriteUserLoginType ?? friend.loginType.toString(),
                                        favoriteUserAvatar: existing?.favoriteUserAvatar,
                                        recordObjectId: existing?.recordObjectId,
                                        status: resolvedStatus
                                    )
                                    mergedRecords[friend.userId] = updatedRecord
                                }
                            } else {
                            }
                            
                            let finalList = Array(mergedRecords.values)
                            let _ = finalList.map { "\($0.userId)(status:\($0.status ?? "nil"))" }.joined(separator: ", ")
                            self.usersWhoLikedMe = finalList
                            
                            
                            self.validateUsersWhoLikedMeWithMessageHistory(with: self.usersWhoLikedMe)
                            
                            completion?()
                            NotificationCenter.default.post(name: NSNotification.Name("RefreshMatchStatus"), object: nil)
                        }
                    }
                    
                    if aggregatedRecords.isEmpty {
                        finalizeUsersWhoLikedMe(with: "loadUsersWhoLikedMe 查询成功但无结果")
                    } else {
                        finalizeUsersWhoLikedMe(with: "loadUsersWhoLikedMe 查询成功")
                    }
                    
                case .failure:
                    // 调用完成回调
                    completion?()
                    
                    // 发送UI刷新通知
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshMatchStatus"), object: nil)
                }
            }
        }
    }
    
    // 清理无效的favoriteRecords数据
    func cleanupInvalidFavoriteRecords() {
        
        // 暂时禁用清理功能，因为会清空用户刚刚点亮的爱心
        // TODO: 实现更智能的清理逻辑，只清理与消息历史不一致的数据
        
        
        // 保存当前状态
        self.saveFavoriteRecords()
    }
}

