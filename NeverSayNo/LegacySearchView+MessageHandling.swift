//
//  LegacySearchView+MessageHandling.swift
//  NeverSayNo
//
//  Created by Die chen on 2025/7/1.
//

import SwiftUI
import Foundation
import LeanCloud

extension LegacySearchView {
    // MARK: - Message Handling Methods
    
    /**
     * 标记相关消息为已读（匹配成功时调用）
     */
    func markRelatedMessagesAsRead(for message: MessageItem) {
        // 🔧 修复：确保在主线程执行，避免线程安全问题
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                self.markRelatedMessagesAsRead(for: message)
            }
            return
        }
        
        // 🔧 修复：添加参数验证，确保message参数有效
        guard !message.senderId.isEmpty, !message.receiverId.isEmpty else {
            return
        }
        
        // 🔧 修复：使用消息ID来查找和更新，而不是使用索引，避免索引失效问题
        let messagesToCheck = Array(messageViewMessages)
        var messageIdsToUpdate: [UUID] = []
        var objectIdsToUpdate: [String] = []
        
        // 标记与当前用户相关的所有未读消息为已读
        for currentMessage in messagesToCheck {
            // 检查是否为相关消息（发送者或接收者是当前用户，且消息类型为好友申请）
            let isRelevantMessage = (currentMessage.senderId == message.senderId || 
                                   currentMessage.receiverId == message.senderId ||
                                   currentMessage.senderId == message.receiverId || 
                                   currentMessage.receiverId == message.receiverId) &&
                                   (currentMessage.messageType == "favorite" || 
                                    currentMessage.messageType == "like" ||
                                    currentMessage.content.contains("对你发送了好友申请") ||
                                    currentMessage.content.contains("已同意") ||
                                    currentMessage.content.contains("已拒绝"))
            
            // 如果消息未读且相关，则标记为已读
            if !currentMessage.isRead && isRelevantMessage {
                messageIdsToUpdate.append(currentMessage.id)
                if let objectId = currentMessage.objectId {
                    objectIdsToUpdate.append(objectId)
                }
            }
        }
        
        // 🔧 修复：使用消息ID查找并更新，避免索引问题
        var markedCount = 0
        for messageId in messageIdsToUpdate {
            if let index = messageViewMessages.firstIndex(where: { $0.id == messageId }) {
                messageViewMessages[index].isRead = true
                markedCount += 1
            }
        }
        
        // 异步更新服务器状态
        for objectId in objectIdsToUpdate {
            LeanCloudService.shared.markMessageAsRead(messageId: objectId) { success in
                if success {
                } else {
                }
            }
        }
        
        // 更新未读消息计数
        _ = messageViewMessages.filter { !$0.isRead }.count
        
        // 🚀 新增：更新新朋友申请数量
        let newFriendsCount = messageViewMessages.filter { message in
            let isRelevantMessage = message.content.contains("对你发送了好友申请") ||
                                   message.content.contains("已同意") ||
                                   message.content.contains("已拒绝") ||
                                   message.content.contains("撤销好友申请")
            
            let isNotPatMessage = !message.content.contains("拍了拍你") && 
                                 message.messageType != "pat"
            
            let isUnread = !message.isRead
            return isRelevantMessage && isNotPatMessage && isUnread
        }.count
        
        // 更新新朋友计数管理器
        newFriendsCountManager.updateCount(newFriendsCount)
        
        
        // 🚀 新增：打印标记后的所有未读消息
        let remainingUnreadMessages = messageViewMessages.filter { !$0.isRead }
        for (_, _) in remainingUnreadMessages.enumerated() {
        }
    }
    
    // 从LeanCloud同步好友申请数据（已移除 Message 表查询）
    func syncMessagesFromLeanCloud() {

        // 获取调用栈，找出是谁调用的
        Thread.callStackSymbols.forEach { symbol in
            if symbol.contains("NeverSayNo") && !symbol.contains("syncMessagesFromLeanCloud") {
            }
        }

        guard let currentUser = userManager.currentUser else {
            return
        }
        
        // 先用缓存（只统计别人发送的申请）
        let allCached = FriendshipManager.shared.friendshipRequests

        let markAllAsReadKey = "MarkAllAsReadTimestamp_\(currentUser.id)"
        let markAllAsReadTimestamp = UserDefaults.standard.object(forKey: markAllAsReadKey) as? Date

        if markAllAsReadTimestamp != nil {
        } else {
        }

        let cachedPending = allCached.filter { request in
            request.status == "pending" && request.user.id != currentUser.id
        }

        let unreadCachedCount = calculateUnreadPendingCount(
            from: cachedPending,
            markAllAsReadTimestamp: markAllAsReadTimestamp
        )

        self.newFriendsCountManager.updateCount(unreadCachedCount)
        self.unreadMessageCount = self.newFriendsCountManager.count
        // 再拉取
        FriendshipManager.shared.fetchFriendshipRequestsWithRetry { requests, error in
            DispatchQueue.main.async {
                if error != nil {
                    return
                }

                let allRequests = requests ?? []

                // 打印所有请求的状态
                for (_, _) in allRequests.enumerated() {
                }

                let pending = allRequests.filter { request in
                    request.status == "pending" && request.user.id != currentUser.id
                }

                let unreadPendingCount = calculateUnreadPendingCount(
                    from: pending,
                    markAllAsReadTimestamp: markAllAsReadTimestamp
                )

                self.newFriendsCountManager.updateCount(unreadPendingCount)
                self.unreadMessageCount = self.newFriendsCountManager.count
            }
        }
        
        // 注释掉这行代码，因为它会覆盖异步获取消息后设置的正确数量
        // self.unreadMessageCount = 0
    }
    
    /// 计算未读的好友申请数量
    func calculateUnreadPendingCount(
        from requests: [FriendshipRequest],
        markAllAsReadTimestamp: Date?
    ) -> Int {
        requests.filter { request in
            guard let markAllTime = markAllAsReadTimestamp else {
                // 没有一键已读时间戳，全部视为未读
                return true
            }
            
            let timeDifference = request.createdAt.timeIntervalSince(markAllTime)
            let isUnread = timeDifference > 1.0
            
            
            return isUnread
        }.count
    }
}



