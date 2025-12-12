//
//  ChatView+BestPractices.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//  基于LeanCloud官方Demo的聊天界面最佳实践
//

import SwiftUI
import LeanCloud

/**
 * 消息界面最佳实践扩展
 * 基于LeanCloud官方Demo的UI最佳实践
 */
extension MessageView {
    
    /**
     * 发送文本消息
     * 基于官方Demo的消息发送最佳实践
     */
    func sendTextMessage(_ text: String, to friendId: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let bestPractices = LeanCloudBestPractices.shared
        
        bestPractices.sendTextMessage(to: friendId, text: text) { success, error in
            DispatchQueue.main.async {
                if success {
                    // 消息发送成功，更新UI
                    self.addMessageToChat(text: text, friendId: friendId, isFromCurrentUser: true)
                } else {
                    // 消息发送失败，显示错误
                    self.showErrorMessage(error ?? "发送失败")
                }
            }
        }
    }
    
    /**
     * 发送图片消息
     * 基于官方Demo的富媒体消息处理
     */
    func sendImageMessage(_ imageData: Data, to friendId: String) {
        let bestPractices = LeanCloudBestPractices.shared
        
        bestPractices.sendImageMessage(to: friendId, imageData: imageData) { success, error in
            DispatchQueue.main.async {
                if success {
                    // 图片消息发送成功
                    self.addImageMessageToChat(imageData: imageData, friendId: friendId, isFromCurrentUser: true)
                } else {
                    // 图片消息发送失败
                    self.showErrorMessage(error ?? "图片发送失败")
                }
            }
        }
    }
    
    /**
     * 发送位置消息
     * 基于官方Demo的位置消息处理
     */
    func sendLocationMessage(latitude: Double, longitude: Double, address: String, to friendId: String) {
        let bestPractices = LeanCloudBestPractices.shared
        
        bestPractices.sendLocationMessage(to: friendId, latitude: latitude, longitude: longitude, address: address) { success, error in
            DispatchQueue.main.async {
                if success {
                    // 位置消息发送成功
                    self.addLocationMessageToChat(latitude: latitude, longitude: longitude, address: address, friendId: friendId, isFromCurrentUser: true)
                } else {
                    // 位置消息发送失败
                    self.showErrorMessage(error ?? "位置发送失败")
                }
            }
        }
    }
    
    /**
     * 创建群聊
     * 基于官方Demo的群聊创建
     */
    func createGroupChat(members: [String], name: String) {
        let bestPractices = LeanCloudBestPractices.shared
        
        bestPractices.createGroupChat(members: members, name: name) { conversationId, error in
            DispatchQueue.main.async {
                if let conversationId = conversationId {
                    // 群聊创建成功
                    self.showSuccessMessage("群聊创建成功: \(conversationId)")
                } else {
                    // 群聊创建失败
                    self.showErrorMessage(error ?? "群聊创建失败")
                }
            }
        }
    }
    
    /**
     * 加入群聊
     * 基于官方Demo的群聊管理
     */
    func joinGroupChat(conversationId: String) {
        let bestPractices = LeanCloudBestPractices.shared
        
        bestPractices.joinGroupChat(conversationId: conversationId) { success, error in
            DispatchQueue.main.async {
                if success {
                    // 加入群聊成功
                    self.showSuccessMessage("加入群聊成功")
                } else {
                    // 加入群聊失败
                    self.showErrorMessage(error ?? "加入群聊失败")
                }
            }
        }
    }
    
    /**
     * 加入开放聊天室
     * 基于官方Demo的开放聊天室功能
     */
    func joinOpenChatRoom(roomId: String) {
        let bestPractices = LeanCloudBestPractices.shared
        
        bestPractices.joinOpenChatRoom(roomId: roomId) { success, error in
            DispatchQueue.main.async {
                if success {
                    // 加入开放聊天室成功
                    self.showSuccessMessage("加入开放聊天室成功")
                } else {
                    // 加入开放聊天室失败
                    self.showErrorMessage(error ?? "加入开放聊天室失败")
                }
            }
        }
    }
    
    /**
     * 创建临时对话
     * 基于官方Demo的临时对话功能
     */
    func createTemporaryConversation(members: [String]) {
        let bestPractices = LeanCloudBestPractices.shared
        
        bestPractices.createTemporaryConversation(members: members) { conversationId, error in
            DispatchQueue.main.async {
                if let conversationId = conversationId {
                    // 临时对话创建成功
                    self.showSuccessMessage("临时对话创建成功: \(conversationId)")
                } else {
                    // 临时对话创建失败
                    self.showErrorMessage(error ?? "临时对话创建失败")
                }
            }
        }
    }
    
    /**
     * 加载消息历史
     * 基于官方Demo的消息历史加载
     */
    func loadMessageHistory(conversationId: String) {
        let bestPractices = LeanCloudBestPractices.shared
        
        bestPractices.getMessageHistory(conversationId: conversationId) { messages, error in
            DispatchQueue.main.async {
                if let messages = messages {
                    // 消息历史加载成功
                    let _ = messages.map { message in
                        self.convertIMMessageToMessageItem(message)
                    }
                    // 这里需要更新UI，暂时打印
                } else {
                    // 消息历史加载失败
                    self.showErrorMessage(error ?? "消息历史加载失败")
                }
            }
        }
    }
    
    // MARK: - 辅助方法
    
    /**
     * 添加消息到聊天界面
     */
    private func addMessageToChat(text: String, friendId: String, isFromCurrentUser: Bool) {
        let _ = MessageItem(
            id: UUID(),
            objectId: nil,
            senderId: isFromCurrentUser ? "current_user" : "other_user",
            senderName: isFromCurrentUser ? "我" : "对方",
            senderAvatar: "",
            senderLoginType: nil,
            receiverId: isFromCurrentUser ? "other_user" : "current_user",
            receiverName: isFromCurrentUser ? "对方" : "我",
            receiverAvatar: "",
            receiverLoginType: nil,
            content: text,
            timestamp: Date(),
            isRead: false,
            type: .text,
            deviceId: nil,
            messageType: nil,
            isMatch: false
        )
        
        // 这里需要更新UI，暂时打印
    }
    
    /**
     * 添加图片消息到聊天界面
     */
    private func addImageMessageToChat(imageData: Data, friendId: String, isFromCurrentUser: Bool) {
        // 这里需要实现图片消息的UI处理
    }
    
    /**
     * 添加位置消息到聊天界面
     */
    private func addLocationMessageToChat(latitude: Double, longitude: Double, address: String, friendId: String, isFromCurrentUser: Bool) {
        // 这里需要实现位置消息的UI处理
    }
    
    /**
     * 转换IMMessage为MessageItem
     */
    private func convertIMMessageToMessageItem(_ immessage: IMMessage) -> MessageItem {
        // 这里需要实现IMMessage到MessageItem的转换
        // 暂时返回默认值
        return MessageItem(
            id: UUID(),
            objectId: immessage.ID,
            senderId: immessage.fromClientID ?? "",
            senderName: immessage.fromClientID ?? "",
            senderAvatar: "",
            senderLoginType: nil,
            receiverId: "",
            receiverName: "",
            receiverAvatar: "",
            receiverLoginType: nil,
            content: immessage.content?.string ?? "",
            timestamp: Date(timeIntervalSince1970: TimeInterval(immessage.sentTimestamp ?? 0)),
            isRead: false,
            type: .text,
            deviceId: nil,
            messageType: nil,
            isMatch: false
        )
    }
    
    /**
     * 清空输入框
     */
    private func clearInputField() {
        // 这里需要实现输入框清空逻辑
    }
    
    /**
     * 显示错误消息
     */
    private func showErrorMessage(_ message: String) {
        // 这里需要实现错误消息显示逻辑
    }
    
    /**
     * 显示成功消息
     */
    private func showSuccessMessage(_ message: String) {
        // 这里需要实现成功消息显示逻辑
    }
}
