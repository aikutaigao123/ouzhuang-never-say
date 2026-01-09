//
//  ContentView+HistoryHandling.swift
//  NeverSayNo
//
//  Created by Auto on 2025/11/11.
//

import SwiftUI
import LeanCloud

extension LegacySearchView {
    // MARK: - 历史记录点击处理
    func handleHistoryItemTap(historyItem: RandomMatchHistory) {
        isLoadingRandomRecord = true
        randomRecord = nil
        
        // 🎯 新增：设置选中的历史记录项目ID，用于返回时高亮显示
        selectedHistoryId = historyItem.id
        
        // 🎯 新增：发送刷新通知，让历史记录列表高亮显示该项目
        NotificationCenter.default.post(
            name: NSNotification.Name("RefreshHistoryList"),
            object: nil,
            userInfo: ["selectedHistoryId": historyItem.id]
        )

        let record = historyItem.record
        
        // 🔧 修复：判断是否为推荐卡片（通过placeName或reason字段判断）
        let hasPlaceName = (record.placeName?.isEmpty == false)
        let hasReason = (record.reason?.isEmpty == false)
        let isRecommendation = hasPlaceName || hasReason
        
        // 🔧 修复：如果是推荐卡片，直接使用历史记录中的LocationRecord（参考handleRecommendationItemTap）
        // 因为推荐卡片应该显示推荐榜匹配卡片，使用Recommendation表中的经纬度，不查询服务器
        if isRecommendation {
            // 直接使用历史记录中的LocationRecord，显示推荐榜匹配卡片
            self.showHistoricalMatch(record: record)
        } else {
            // 个人匹配卡片：查询最新位置
            LeanCloudService.shared.fetchLatestLocationForUser(userId: historyItem.record.userId) { locationRecord, error in
                DispatchQueue.main.async {
                    if error != nil {
                        let record = historyItem.record
                        self.showHistoricalMatch(record: record)
                    } else if let locationRecord = locationRecord {
                        self.showHistoricalMatch(record: locationRecord)
                    } else {
                        let record = historyItem.record
                        self.showHistoricalMatch(record: record)
                    }
                }
            }
        }
    }

    func handleUserSearchTap(user: UserInfo) {
        showMessageSheet = false
        isLoadingRandomRecord = true
        randomRecord = nil

        LeanCloudService.shared.fetchLatestLocationForUser(userId: user.id) { locationRecord, error in
            DispatchQueue.main.async {
                if error != nil || locationRecord == nil {
                    let fallbackRecord = LocationRecord(
                        id: 0,
                        objectId: user.id,
                        timestamp: ISO8601DateFormatter().string(from: Date()),
                        latitude: 0.0,
                        longitude: 0.0,
                        accuracy: 0.0,
                        userId: user.id,
                        userName: user.fullName,
                        loginType: user.loginType == .apple ? "apple" : "guest",
                        userEmail: user.email,
                        userAvatar: nil,
                        deviceId: "",
                        clientTimestamp: nil,
                        timezone: nil,
                        status: "active",
                        recordCount: nil,
                        likeCount: nil,
                        placeName: nil,
                        reason: nil
                    )
                    self.showHistoricalMatch(record: fallbackRecord)
                } else if let locationRecord = locationRecord {
                    self.showHistoricalMatch(record: locationRecord)
                }
            }
        }
    }

    // MARK: - 推荐榜与排行榜点击处理
    func handleRankingItemTap(rankingItem: UserScore) {
        isLoadingRandomRecord = true
        randomRecord = nil
        showRankingSheet = false
        
        // 🎯 新增：设置选中的排行榜项目ID，用于返回时高亮显示
        selectedRankingId = rankingItem.id
        
        // 🎯 新增：设置选中的标签页为排行榜（tab 1），确保返回时显示排行榜界面
        selectedTab = 1
        
        // 🎯 新增：发送刷新通知，让排行榜高亮显示该项目
        NotificationCenter.default.post(
            name: NSNotification.Name("RefreshRankingList"),
            object: nil,
            userInfo: ["selectedRankingId": rankingItem.id]
        )

        LeanCloudService.shared.fetchLatestLocationForUser(userId: rankingItem.id) { locationRecord, error in
            DispatchQueue.main.async {
                if error != nil || locationRecord == nil {
                    if let latitude = rankingItem.latitude, let longitude = rankingItem.longitude {
                        let fallbackRecord = LocationRecord(
                            id: 0,
                            objectId: rankingItem.id,
                            timestamp: ISO8601DateFormatter().string(from: Date()),
                            latitude: latitude,
                            longitude: longitude,
                            accuracy: 0.0,
                            userId: rankingItem.id,
                            userName: rankingItem.userName,
                            loginType: rankingItem.loginType,
                            userEmail: rankingItem.userEmail,
                            userAvatar: rankingItem.userAvatar,
                            deviceId: "",
                            clientTimestamp: nil,
                            timezone: nil,
                            status: "active",
                            recordCount: nil,
                            likeCount: rankingItem.likeCount,
                            placeName: nil,
                            reason: nil
                        )
                        self.showHistoricalMatch(record: fallbackRecord)
                    } else {
                        self.isLoadingRandomRecord = false
                    }
                } else if let locationRecord = locationRecord {
                    self.showHistoricalMatch(record: locationRecord)
                }
            }
        }
    }

    func handleRecommendationItemTap(item: RecommendationItem) {
        isLoadingRandomRecord = true
        randomRecord = nil
        selectedRecommendationId = item.id
        showRankingSheet = false
        
        // 🎯 新增：设置选中的标签页为推荐榜（tab 0），确保返回时显示推荐榜界面
        selectedTab = 0

        let locationRecord = item.toLocationRecord()
        self.showHistoricalMatch(record: locationRecord)
    }

    func handleMessageTap(message: MessageItem) {
        isLoadingRandomRecord = true
        randomRecord = nil

        let isFriendRequestMessage = message.messageType == "friend_request"
        let isFriendListTap = message.messageType == "match" && message.isMatch == true
        let shouldAddToAllFriendsMatchResults = !isFriendRequestMessage && !isFriendListTap
        let targetUserId = isFriendListTap ? message.receiverId : message.senderId

        LeanCloudService.shared.fetchUserNameAndLoginType(objectId: targetUserId) { _, loginType, _ in
            let inferredLoginTypeForSender = loginType ?? message.senderLoginType ?? UserTypeUtils.getLoginTypeFromUserId(targetUserId)

            let adjustRecordLoginType: (LocationRecord) -> LocationRecord = { record in
                if record.loginType == nil || record.loginType == "unknown" {
                    return LocationRecord(
                        id: record.id,
                        objectId: record.objectId,
                        timestamp: record.timestamp,
                        latitude: record.latitude,
                        longitude: record.longitude,
                        accuracy: record.accuracy,
                        userId: record.userId,
                        userName: record.userName,
                        loginType: inferredLoginTypeForSender,
                        userEmail: record.userEmail,
                        userAvatar: record.userAvatar,
                        deviceId: record.deviceId,
                        clientTimestamp: record.clientTimestamp,
                        timezone: record.timezone,
                        status: record.status,
                        recordCount: record.recordCount,
                        likeCount: record.likeCount,
                        placeName: record.placeName,
                        reason: record.reason
                    )
                }
                return record
            }

            LeanCloudService.shared.fetchLatestLocationForUser(userId: targetUserId) { locationRecord, error in
                DispatchQueue.main.async {
                    if let locationRecord = locationRecord {
                        self.isLoadingRandomRecord = false
                        let adjustedRecord = adjustRecordLoginType(locationRecord)
                        if shouldAddToAllFriendsMatchResults {
                            self.addToAllFriendsMatchResults(record: adjustedRecord)
                        }
                        self.showHistoricalMatch(record: adjustedRecord)
                        self.showMessageSheet = false
                    } else {
                        self.isLoadingRandomRecord = false
                        self.showMessageSheet = false
                    }
                }
            }
        }
    }

    // MARK: - 历史记录删除
    func deleteRandomMatchHistoryItem(_ historyItem: RandomMatchHistory) {

        guard let currentUser = userManager.currentUser else {
            return
        }
        let historyKey = StorageKeyUtils.getHistoryKey(for: currentUser)

        randomMatchHistory.removeAll { $0.id == historyItem.id }

        DispatchQueue.global(qos: .userInitiated).async {
            if let data = try? JSONEncoder().encode(self.randomMatchHistory) {
                UserDefaults.standard.set(data, forKey: historyKey)
            } else {
            }
        }

        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .init("HistoryItemDeleted"),
                object: historyItem
            )
        }
    }
}
