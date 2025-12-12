//
//  LegacySearchView+MatchStatus.swift
//  NeverSayNo
//
//  Created by Die chen on 2025/7/1.
//

import SwiftUI
import Foundation
import CoreLocation
import LeanCloud

extension LegacySearchView {
    // MARK: - Match Status Detection and Handling
    
    /// 检测并打印匹配成功状态
    func detectAndPrintMatchSuccessStatus() {
        // 调试函数已删除
    }
    
    /// 检测并更新消息的匹配状态
    func detectAndUpdateMatchStatus() {
        
        // 检查favoriteRecords内容
        
        guard let currentUserId = userManager.currentUser?.id else {
            return
        }
        
        
        // 检测每条消息的匹配状态
        for (index, message) in messageViewMessages.enumerated() {
            
            // 只有喜欢或点赞类型的消息才可能匹配成功
            guard message.messageType == "favorite" || message.messageType == "like" else {
                continue
            }
            
            let senderId = message.senderId
            
            // 检查favoriteRecords中是否有对方喜欢当前用户的记录
            let isLikedBySender = favoriteRecords.contains { favoriteRecord in
                favoriteRecord.userId == senderId && favoriteRecord.favoriteUserId == currentUserId
            }
            
            
            // 如果favoriteRecords中没有找到，检查当前用户是否也喜欢对方
            var isLikedBySenderFromLeanCloud = false
            if !isLikedBySender {
                let currentUserLikesSender = favoriteRecords.contains { favoriteRecord in
                    favoriteRecord.userId == currentUserId && favoriteRecord.favoriteUserId == senderId
                }
                
                // 如果双方都喜欢对方，则认为匹配成功
                if currentUserLikesSender {
                    isLikedBySenderFromLeanCloud = true
                }
            }
            
            // 计算最终匹配结果
            let isMatch = isLikedBySender || isLikedBySenderFromLeanCloud
            
            // 更新消息的匹配状态
            if isMatch != message.isMatch {
                messageViewMessages[index].isMatch = isMatch
                
                // 🚀 新增：如果匹配成功，调用handleMatchSuccess方法
                if isMatch {
                    handleMatchSuccess(for: messageViewMessages[index])
                }
            }
        }
    }
    
    /// 处理匹配成功事件
    func handleMatchSuccess(for message: MessageItem) {
        // 🚀 立即触发UI更新，确保匹配成功提示立即显示
        
        // 触发真正的UI更新 - 更新消息的匹配状态
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.2)) {
                // 找到对应的消息并更新其匹配状态
                if let index = self.messageViewMessages.firstIndex(where: { $0.id == message.id }) {
                    self.messageViewMessages[index].isMatch = true
                }
            }
        }
        
        // 🚀 新增：匹配成功时自动标记相关消息为已读
        markRelatedMessagesAsRead(for: message)
        
        // 🎯 修复：根据 LeanCloud 好友关系开发指南，匹配成功时应自动接受好友申请
        // 查找对方发送的好友申请（status 为 pending）
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        let senderId = message.senderId
        let receiverId = message.receiverId
        
        // 确定对方ID（不是当前用户的那个）
        let otherUserId = (senderId == currentUser.id) ? receiverId : senderId
        
        // 查询对方发送的好友申请
        FriendshipManager.shared.fetchFriendshipRequests(status: "pending") { requests, error in
            DispatchQueue.main.async {
                if error != nil {
                    return
                }
                
                guard let requests = requests else {
                    return
                }
                
                // 查找对方发送给当前用户的好友申请
                if let request = requests.first(where: { request in
                    request.user.id == otherUserId && request.friend.id == currentUser.id && request.status == "pending"
                }) {
                    // 🎯 符合开发指南：接受好友申请，会自动更新 _FriendshipRequest 的 status 为 accepted，并在 _Followee 表建立双向好友关系
                    FriendshipManager.shared.acceptFriendshipRequest(request, attributes: nil) { success, errorMessage in
                        DispatchQueue.main.async {
                            if success {
                                // 刷新好友列表和新朋友列表
                                NotificationCenter.default.post(name: NSNotification.Name("RefreshFriendsList"), object: nil)
                                NotificationCenter.default.post(name: NSNotification.Name("RefreshNewFriends"), object: nil)
                            } else {
                            }
                        }
                    }
                } else {
                }
            }
        }
        
        // 🚀 立即触发好友列表刷新，确保好友列表立即增加
        NotificationCenter.default.post(name: NSNotification.Name("RefreshFriendsList"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("RefreshNewFriends"), object: nil)
        
        // 触发匹配成功通知
        NotificationCenter.default.post(
            name: NSNotification.Name("MatchSuccess"),
            object: nil,
            userInfo: ["message": message]
        )
        
    }
    
    /// 更新指定用户相关消息的匹配状态
    func updateMessageMatchStatusForUser(userId: String, isMatch: Bool) {
        // 🔧 修复：确保在主线程执行
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.updateMessageMatchStatusForUser(userId: userId, isMatch: isMatch)
            }
            return
        }
        
        // 🔧 修复：使用消息ID而不是索引，避免在遍历时修改数组导致的问题
        let messagesToCheck = Array(messageViewMessages)
        var messageIdsToUpdate: [(id: UUID, oldStatus: Bool)] = []
        
        // 收集需要更新的消息
        for message in messagesToCheck {
            if message.senderId == userId {
                messageIdsToUpdate.append((id: message.id, oldStatus: message.isMatch))
            }
        }
        
        // 批量更新消息状态
        var updatedCount = 0
        for (messageId, oldStatus) in messageIdsToUpdate {
            // 🔧 修复：使用消息ID查找，而不是索引
            if let index = messageViewMessages.firstIndex(where: { $0.id == messageId }) {
                messageViewMessages[index].isMatch = isMatch
                updatedCount += 1
                
                // 如果匹配成功，调用handleMatchSuccess
                if isMatch && !oldStatus {
                    // 🔧 修复：使用当前数组中的消息，确保数据是最新的
                    handleMatchSuccess(for: messageViewMessages[index])
                } else if !isMatch && oldStatus {
                }
            }
        }
        
        // 🚀 修复：强制触发UI更新，使用动画确保立即显示
        if !messageIdsToUpdate.isEmpty {
            withAnimation(.easeInOut(duration: 0.1)) {
                // UI更新已在上面完成
            }
        }
    }
    
    /// 检查匹配成功UI显示与好友数量的一致性
    func checkMatchStatusConsistency() {
        // 计算实际的好友数量（基于双向喜欢关系）
        var actualFriendCount = 0
        for favoriteRecord in favoriteRecords {
            let targetUserId = favoriteRecord.favoriteUserId
            let currentUserLikesTarget = isUserFavorited(userId: targetUserId)
            let targetLikesCurrentUser = isUserFavoritedByMe(userId: targetUserId)
            
            if currentUserLikesTarget && targetLikesCurrentUser {
                actualFriendCount += 1
            }
        }
        
        // 发送通知让消息界面检查一致性
        NotificationCenter.default.post(name: NSNotification.Name("CheckMatchStatusConsistency"), object: actualFriendCount)
    }
    
    /// 设置匹配结果
    func setMatchResult(record: LocationRecord) {
        SearchUtils.setMatchResult(
            record: record,
            diamondManager: diamondManager,
            randomRecord: $randomRecord,
            randomRecordNumber: $randomRecordNumber
        )
        
        // 异步刷新对方头像为最新
        ensureLatestAvatar(userId: record.userId, loginType: record.loginType)
        
        // 添加到历史记录
        addRandomMatchToHistory(record: record, recordNumber: randomRecordNumber)
        
        // 注意：不再本地上传MatchRecord，改为从Message表生成
        // 历史匹配
    }
    
    /// 显示历史记录中的匹配结果（不扣除钻石，但添加到历史记录）
    func showHistoricalMatch(record: LocationRecord) {
        
        // 进入加载状态
        isLoadingRandomRecord = true
        
        // 清空所有好友匹配结果数组，确保只显示单个匹配卡片（与历史记录按钮行为一致）
        allFriendsMatchResults = []
        
        let targetUserId = record.userId
        
        // 🎯 新增：判断是否来自推荐榜（通过placeName或reason字段判断）
        let hasPlaceName = (record.placeName?.isEmpty == false)
        let hasReason = (record.reason?.isEmpty == false)
        let isFromRecommendation = hasPlaceName || hasReason
        
        // 🎯 修改：如果来自推荐榜，直接使用Recommendation表中的经纬度，不查询服务器
        if isFromRecommendation {
            
            // 停止加载动画
            self.isLoadingRandomRecord = false
            
            // 尝试补全 loginType
            let resolvedLoginType = record.loginType ?? UserTypeUtils.getLoginTypeFromUserId(record.userId)
            
            // 直接使用推荐榜的LocationRecord，确保使用Recommendation表中的经纬度
            let adjustedRecord = LocationRecord(
                id: record.id,
                objectId: record.objectId,
                timestamp: record.timestamp,
                latitude: record.latitude, // 🎯 使用Recommendation表中的经纬度
                longitude: record.longitude, // 🎯 使用Recommendation表中的经纬度
                accuracy: record.accuracy,
                userId: record.userId,
                userName: record.userName,
                loginType: resolvedLoginType,
                userEmail: record.userEmail,
                userAvatar: record.userAvatar,
                deviceId: record.deviceId,
                clientTimestamp: record.clientTimestamp,
                timezone: record.timezone,
                status: record.status,
                recordCount: record.recordCount,
                likeCount: record.likeCount,
                placeName: record.placeName, // 🎯 保留推荐榜的地名
                reason: record.reason // 🎯 保留推荐榜的理由
            )
            
            // 显示匹配结果
            SearchUtils.showHistoricalMatch(
                record: adjustedRecord,
                randomRecord: self.$randomRecord,
                randomRecordNumber: self.$randomRecordNumber
            )
            
            // 异步刷新对方头像为最新
            self.ensureLatestAvatar(userId: adjustedRecord.userId, loginType: adjustedRecord.loginType)
            
            // 添加到历史记录（从消息或好友点击跳转过来的匹配）
            self.addRandomMatchToHistory(record: adjustedRecord, recordNumber: self.randomRecordNumber)
        } else {
            // 🎯 非推荐榜来源，从服务器获取最新位置记录
            
            let applyRecord: (LocationRecord) -> Void = { latestRecord in
                
                // 停止加载动画
                self.isLoadingRandomRecord = false
            
                // 尝试补全 loginType
                let resolvedLoginType = latestRecord.loginType ?? UserTypeUtils.getLoginTypeFromUserId(latestRecord.userId)
                let adjustedRecord = LocationRecord(
                    id: latestRecord.id,
                    objectId: latestRecord.objectId,
                    timestamp: latestRecord.timestamp,
                    latitude: latestRecord.latitude,
                    longitude: latestRecord.longitude,
                    accuracy: latestRecord.accuracy,
                    userId: latestRecord.userId,
                    userName: latestRecord.userName,
                    loginType: resolvedLoginType,
                    userEmail: latestRecord.userEmail,
                    userAvatar: latestRecord.userAvatar,
                    deviceId: latestRecord.deviceId,
                    clientTimestamp: latestRecord.clientTimestamp,
                    timezone: latestRecord.timezone,
                    status: latestRecord.status,
                    recordCount: latestRecord.recordCount,
                    likeCount: latestRecord.likeCount,
                    placeName: latestRecord.placeName,
                    reason: latestRecord.reason
                )
                
                // 显示匹配结果
                SearchUtils.showHistoricalMatch(
                    record: adjustedRecord,
                    randomRecord: self.$randomRecord,
                    randomRecordNumber: self.$randomRecordNumber
                )
                
                // 异步刷新对方头像为最新
                self.ensureLatestAvatar(userId: adjustedRecord.userId, loginType: adjustedRecord.loginType)
                
                // 添加到历史记录（从消息或好友点击跳转过来的匹配）
                self.addRandomMatchToHistory(record: adjustedRecord, recordNumber: self.randomRecordNumber)
            }
            
            // 从服务器获取最新位置记录
            LeanCloudService.shared.fetchLatestLocationForUser(userId: targetUserId) { latestRecord, error in
                DispatchQueue.main.async {
                    if let latestRecord = latestRecord {
                        applyRecord(latestRecord)
                    } else {
                        applyRecord(record)
                    }
                }
            }
        }
    }
    
    /// 将匹配结果添加到所有好友匹配结果数组中
    func addToAllFriendsMatchResults(record: LocationRecord) {
        SearchUtils.addToAllFriendsMatchResults(
            record: record,
            allFriendsMatchResults: $allFriendsMatchResults
        )
        
    }
    
    /// 计算好友申请相关消息数量（同步时使用，与MessageView逻辑一致）
    func calculateFriendRequestCount(from messages: [MessageItem]) -> Int {
        
        return ReportHelpers.calculateFriendRequestCount(from: messages, isUserFavorited: isUserFavorited)
    }
}



