//
//  BackgroundMessageProcessor.swift
//  NeverSayNo
//
//  Created by AI Assistant on 2025-09-30.
//

import Foundation
import UIKit
import UserNotifications

/// 后台消息处理器 - 处理从服务器接收到的消息并发送推送通知
class BackgroundMessageProcessor: ObservableObject {
    static let shared = BackgroundMessageProcessor()
    
    private let notificationManager = NotificationManager.shared
    
    // 用于跟踪已处理的消息，避免重复通知
    private var processedMessageIds: Set<String> = []
    
    private init() {}
    
    // MARK: - 消息处理
    
    /// 处理从服务器接收到的消息
    func processReceivedMessage(_ messageData: [String: Any], currentUserId: String) {
        // 检查消息ID，避免重复处理
        guard let messageId = messageData["objectId"] as? String else {
            return
        }
        
        // 检查是否已经处理过这条消息
        if processedMessageIds.contains(messageId) {
            return
        }
        
        // 标记消息为已处理
        processedMessageIds.insert(messageId)
        
        guard let messageType = messageData["messageType"] as? String else {
            return
        }
        
        switch messageType {
        case "pat":
            processPatMessage(messageData, currentUserId: currentUserId)
        case "favorite":
            processFriendRequestMessage(messageData, currentUserId: currentUserId)
        case "friend_request":  // 🔧 修复：添加 friend_request 类型处理
            processFriendRequestMessage(messageData, currentUserId: currentUserId)
        case "contact_inquiry":  // 🎯 新增：处理询问联系方式是否真实消息
            processContactInquiryMessage(messageData, currentUserId: currentUserId)
        case "contact_inquiry_reply":  // 🎯 新增：处理联系方式真实回复消息
            processContactInquiryReplyMessage(messageData, currentUserId: currentUserId)
        case "accept":
            processAcceptMessage(messageData, currentUserId: currentUserId)
        case "unfavorite":
            processUnfavoriteMessage(messageData, currentUserId: currentUserId)
        default:
            break
        }
    }
    
    private func appStateString(_ state: UIApplication.State) -> String {
        switch state {
        case .active: return "前台活跃"
        case .inactive: return "前台非活跃"
        case .background: return "后台"
        @unknown default: return "未知"
        }
    }
    
    /// 处理拍一拍消息
    private func processPatMessage(_ messageData: [String: Any], currentUserId: String) {
        guard let senderName = messageData["senderName"] as? String,
              let receiverName = messageData["receiverName"] as? String,
              let messageId = messageData["objectId"] as? String else {
            return
        }
        
        // 检查是否是发给当前用户的消息
        guard let receiverId = messageData["receiverId"] as? String else {
            return
        }
        
        guard receiverId == currentUserId else {
            return
        }
        
        // 🎯 新增：检查发送方是否在我的好友列表中
        // 从消息数据中提取发送者ID（需要从其他地方获取，因为messageData可能没有senderId）
        // 注意：这里需要从其他地方获取senderId，比如从消息内容解析或从其他字段获取
        // 如果无法获取senderId，则跳过检查（保持向后兼容）
        if let senderId = messageData["senderId"] as? String {
            let isFriend = FriendshipManager.shared.isFriend(senderId)
            if !isFriend {
                // 发送方不在好友列表中，不处理这个消息
                return
            }
        }
        
        // 🔧 新增：检查消息时间戳，只处理30秒内的消息（与应用内弹窗保持一致）
        let currentTime = Date()
        let recentThreshold: TimeInterval = 30 // 30秒内的消息视为新消息
        
        guard let timestampString = messageData["timestamp"] as? String else {
            return
        }
        
        // 解析时间戳
        let isoFormatter = ISO8601DateFormatter()
        guard let messageTimestamp = isoFormatter.date(from: timestampString) else {
            return
        }
        
        let timeDiff = currentTime.timeIntervalSince(messageTimestamp)
        
        // 只处理30秒内的消息
        guard timeDiff <= recentThreshold && timeDiff >= 0 else {
            return
        }
        
        // 发送推送通知
        notificationManager.sendPatMessageNotification(
            from: senderName,
            to: receiverName,
            messageId: messageId
        )
    }
    
    /// 🎯 新增：处理联系方式真实回复消息
    private func processContactInquiryReplyMessage(_ messageData: [String: Any], currentUserId: String) {
        
        guard let senderName = messageData["senderName"] as? String,
              let messageId = messageData["objectId"] as? String else {
            return
        }
        
        // 检查是否是发给当前用户的消息
        guard let receiverId = messageData["receiverId"] as? String,
              receiverId == currentUserId else {
            return
        }
        
        // 🔧 新增：检查消息时间戳，只处理30秒内的消息
        let currentTime = Date()
        let recentThreshold: TimeInterval = 30 // 30秒内的消息视为新消息
        
        guard let timestampString = messageData["timestamp"] as? String else {
            return
        }
        
        // 解析时间戳
        let isoFormatter = ISO8601DateFormatter()
        guard let messageTimestamp = isoFormatter.date(from: timestampString) else {
            return
        }
        
        let timeDiff = currentTime.timeIntervalSince(messageTimestamp)
        
        // 只处理30秒内的消息
        guard timeDiff <= recentThreshold && timeDiff >= 0 else {
            return
        }
        
        // 发送推送通知
        notificationManager.sendContactInquiryReplyNotification(
            from: senderName,
            messageId: messageId
        )
    }
    
    /// 🎯 新增：处理询问联系方式是否真实消息
    private func processContactInquiryMessage(_ messageData: [String: Any], currentUserId: String) {
        
        guard let senderName = messageData["senderName"] as? String,
              let messageId = messageData["objectId"] as? String else {
            return
        }
        
        // 检查是否是发给当前用户的消息
        guard let receiverId = messageData["receiverId"] as? String,
              receiverId == currentUserId else {
            return
        }
        
        // 🔧 新增：检查消息时间戳，只处理30秒内的消息
        let currentTime = Date()
        let recentThreshold: TimeInterval = 30 // 30秒内的消息视为新消息
        
        guard let timestampString = messageData["timestamp"] as? String else {
            return
        }
        
        // 解析时间戳
        let isoFormatter = ISO8601DateFormatter()
        guard let messageTimestamp = isoFormatter.date(from: timestampString) else {
            return
        }
        
        let timeDiff = currentTime.timeIntervalSince(messageTimestamp)
        
        // 只处理30秒内的消息
        guard timeDiff <= recentThreshold && timeDiff >= 0 else {
            return
        }
        
        // 发送推送通知
        notificationManager.sendContactInquiryNotification(
            from: senderName,
            messageId: messageId
        )
    }
    
    /// 处理好友申请消息
    private func processFriendRequestMessage(_ messageData: [String: Any], currentUserId: String) {
        
        guard let senderName = messageData["senderName"] as? String,
              let messageId = messageData["objectId"] as? String else {
            return
        }
        
        
        // 检查是否是发给当前用户的消息
        guard let receiverId = messageData["receiverId"] as? String,
              receiverId == currentUserId else {
            return
        }
        
        
        // 🔧 新增：检查消息时间戳，只处理30秒内的消息（与拍一拍消息保持一致）
        let currentTime = Date()
        let recentThreshold: TimeInterval = 30 // 30秒内的消息视为新消息（修复：从2秒改为30秒，与拍一拍一致）
        
        guard let timestampString = messageData["timestamp"] as? String else {
            return
        }
        
        // 解析时间戳
        let formatter = ISO8601DateFormatter()
        guard let messageTimestamp = formatter.date(from: timestampString) else {
            return
        }
        
        let timeDiff = currentTime.timeIntervalSince(messageTimestamp)
        
        // 只处理30秒内的消息
        guard timeDiff <= recentThreshold && timeDiff >= 0 else {
            return
        }
        
        
        // 发送推送通知
        notificationManager.sendFriendRequestNotification(
            from: senderName,
            messageId: messageId
        )
        
        // 🎯 方案2：收到 friend_request 推送时，同步增加 NewFriendsCountManager 的 count
        // 这样推送的 badge: "Increment" 和本地 count 保持一致
        DispatchQueue.main.async {
            NewFriendsCountManager.shared.incrementCount()
        }
    }
    
    /// 处理同意好友申请消息
    private func processAcceptMessage(_ messageData: [String: Any], currentUserId: String) {
        guard let senderName = messageData["senderName"] as? String,
              let messageId = messageData["objectId"] as? String else {
            return
        }
        
        // 检查是否是发给当前用户的消息
        guard let receiverId = messageData["receiverId"] as? String,
              receiverId == currentUserId else {
            return
        }
        
        // 发送自定义的同意通知
        sendAcceptNotification(from: senderName, messageId: messageId)
        
    }
    
    /// 处理撤销好友申请消息
    private func processUnfavoriteMessage(_ messageData: [String: Any], currentUserId: String) {
        guard let senderName = messageData["senderName"] as? String,
              let messageId = messageData["objectId"] as? String else {
            return
        }
        
        // 检查是否是发给当前用户的消息
        guard let receiverId = messageData["receiverId"] as? String,
              receiverId == currentUserId else {
            return
        }
        
        // 发送自定义的撤销通知
        sendUnfavoriteNotification(from: senderName, messageId: messageId)
        
    }
    
    // MARK: - 自定义通知
    
    /// 发送同意好友申请通知
    private func sendAcceptNotification(from senderName: String, messageId: String) {
        guard notificationManager.isNotificationEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "好友申请已同意"
        content.body = "\(senderName) 已同意了你的好友申请"
        content.sound = UNNotificationSound.default
        // 🎯 修复：不在这里设置 badge，badge 应该由 NewFriendsCountManager 统一管理（只用于好友申请）
        // content.badge 会在通知显示时自动使用当前的应用图标 badge 数字
        
        content.userInfo = [
            "messageId": messageId,
            "messageType": "accept",
            "senderName": senderName
        ]
        
        let request = UNNotificationRequest(
            identifier: "accept_\(messageId)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if error != nil {
            } else {
            }
        }
    }
    
    /// 发送撤销好友申请通知
    private func sendUnfavoriteNotification(from senderName: String, messageId: String) {
        guard notificationManager.isNotificationEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "好友申请已撤销"
        content.body = "\(senderName) 撤销了好友申请"
        content.sound = UNNotificationSound.default
        // 🎯 修复：不在这里设置 badge，badge 应该由 NewFriendsCountManager 统一管理（只用于好友申请）
        // content.badge 会在通知显示时自动使用当前的应用图标 badge 数字
        
        content.userInfo = [
            "messageId": messageId,
            "messageType": "unfavorite",
            "senderName": senderName
        ]
        
        let request = UNNotificationRequest(
            identifier: "unfavorite_\(messageId)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if error != nil {
            } else {
            }
        }
    }
    
    // MARK: - 批量处理
    
    /// 批量处理消息列表
    func processMessageList(_ messages: [[String: Any]], currentUserId: String) {
        
        for messageData in messages {
            processReceivedMessage(messageData, currentUserId: currentUserId)
        }
        
    }
    
    /// 处理新消息检测结果
    func processNewMessages(_ newMessages: [[String: Any]], currentUserId: String) {
        guard !newMessages.isEmpty else {
            return
        }
        
        
        for messageData in newMessages {
            processReceivedMessage(messageData, currentUserId: currentUserId)
        }
    }
}
