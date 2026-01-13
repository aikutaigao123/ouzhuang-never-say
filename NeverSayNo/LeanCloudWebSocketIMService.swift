//
//  LeanCloudWebSocketIMService.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//  LeanCloud WebSocket IM 集成服务
//

import Foundation
import LeanCloud
import UIKit
import Combine

/**
 * LeanCloud WebSocket IM 集成服务
 * 负责将WebSocket IM与现有业务逻辑集成
 */
class LeanCloudWebSocketIMService: ObservableObject {
    static let shared = LeanCloudWebSocketIMService()
    
    // MARK: - 属性
    private let webSocketIM = LeanCloudWebSocketIM.shared
    private var cancellables = Set<AnyCancellable>()
    
    // 消息缓存
    @Published var messages: [MessageItem] = []
    @Published var conversations: [IMConversation] = []
    @Published var isConnected = false
    
    private init() {
        setupWebSocketIMListener()
    }
    
    // MARK: - 公共接口
    
    /**
     * 初始化WebSocket IM服务
     * 🚀 修复：确保在 background QoS 线程上执行，避免线程优先级反转
     */
    func initializeService(userId: String, userName: String) {
        // 🚀 修复：确保在 background QoS 线程上执行，避免线程优先级反转
        let currentQoS = Thread.current.qualityOfService
        if currentQoS == .userInteractive || currentQoS == .userInitiated {
            DispatchQueue.global(qos: .background).async { [weak self] in
                // 初始化WebSocket IM
                self?.webSocketIM.initializeIM(userId: userId, userName: userName)
                
                // 启动LiveQuery订阅（好友申请实时通知）
                FriendshipLiveQueryManager.shared.startSubscription(currentUserId: userId)
            }
        } else {
            // 初始化WebSocket IM
            webSocketIM.initializeIM(userId: userId, userName: userName)
            
            // 启动LiveQuery订阅（好友申请实时通知）
            FriendshipLiveQueryManager.shared.startSubscription(currentUserId: userId)
        }
        
        // 🎯 新增：启动询问联系方式是否真实LiveQuery订阅
        ContactInquiryLiveQueryManager.shared.startSubscription(currentUserId: userId)
        
        // 监听连接状态
        observeConnectionStatus()
        
        // 加载对话列表
        loadConversations()
    }
    
    /**
     * 断开服务
     */
    func disconnectService() {
        webSocketIM.disconnect()
        cancellables.removeAll()
        
        // 🎯 新增：停止LiveQuery订阅
        FriendshipLiveQueryManager.shared.stopSubscription()
        ContactInquiryLiveQueryManager.shared.stopSubscription()
    }
    
    /**
     * 发送消息
     */
    func sendMessage(to conversationId: String, content: String, completion: @escaping (Bool, String) -> Void) {
        webSocketIM.sendMessage(to: conversationId, content: content) { success, error in
            DispatchQueue.main.async {
                if success {
                    completion(true, "消息发送成功")
                } else {
                    completion(false, error?.localizedDescription ?? "发送失败")
                }
            }
        }
    }
    
    /**
     * 获取对话历史消息
     */
    func getConversationHistory(conversationId: String, completion: @escaping ([MessageItem]?, String?) -> Void) {
        webSocketIM.getConversationHistory(conversationId: conversationId) { imMessages, error in
            DispatchQueue.main.async {
                if let imMessages = imMessages {
                    let messageItems = self.convertIMMessagesToMessageItems(imMessages)
                    completion(messageItems, nil)
                } else {
                    completion(nil, error?.localizedDescription ?? "获取历史消息失败")
                }
            }
        }
    }
    
    /**
     * 创建对话
     */
    func createConversation(members: [String], name: String? = nil, completion: @escaping (String?, String?) -> Void) {
        webSocketIM.createConversation(members: members, name: name) { conversation, error in
            DispatchQueue.main.async {
                if let conversation = conversation {
                    completion(conversation.ID, nil)
                } else {
                    completion(nil, error?.localizedDescription ?? "创建对话失败")
                }
            }
        }
    }
    
    /**
     * 加入对话
     */
    func joinConversation(conversationId: String, completion: @escaping (Bool, String) -> Void) {
        webSocketIM.joinConversation(conversationId: conversationId) { success, error in
            DispatchQueue.main.async {
                if success {
                    completion(true, "加入对话成功")
                } else {
                    completion(false, error?.localizedDescription ?? "加入对话失败")
                }
            }
        }
    }
    
    /**
     * 离开对话
     */
    func leaveConversation(conversationId: String, completion: @escaping (Bool, String) -> Void) {
        webSocketIM.leaveConversation(conversationId: conversationId) { success, error in
            DispatchQueue.main.async {
                if success {
                    completion(true, "离开对话成功")
                } else {
                    completion(false, error?.localizedDescription ?? "离开对话失败")
                }
            }
        }
    }
    
    // MARK: - 私有方法
    
    /**
     * 设置WebSocket IM监听器
     */
    private func setupWebSocketIMListener() {
        // 监听消息接收通知
        NotificationCenter.default.publisher(for: .imMessageReceived)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleReceivedMessage(notification)
            }
            .store(in: &cancellables)
        
        // 监听连接状态通知
        NotificationCenter.default.publisher(for: .imWebSocketConnected)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.isConnected = true
            }
            .store(in: &cancellables)
    }
    
    /**
     * 监听连接状态
     */
    private func observeConnectionStatus() {
        // 定期检查连接状态
        Timer.publish(every: 5.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.isConnected = self?.webSocketIM.isIMConnected ?? false
            }
            .store(in: &cancellables)
    }
    
    /**
     * 加载对话列表
     */
    private func loadConversations() {
        webSocketIM.getConversations { [weak self] conversations, error in
            DispatchQueue.main.async {
                if let conversations = conversations {
                    self?.conversations = conversations
                } else {
                }
            }
        }
    }
    
    /**
     * 处理接收到的消息
     */
    private func handleReceivedMessage(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let message = userInfo["message"] as? IMMessage,
              let conversation = userInfo["conversation"] as? IMConversation else {
            return
        }
        
        // 转换为MessageItem
        let messageItem = convertIMMessageToMessageItem(message, conversation: conversation)
        
        // 添加到消息列表
        DispatchQueue.main.async {
            self.messages.append(messageItem)
        }
        
        // 发送消息接收通知（保持与现有系统的兼容性）
        NotificationCenter.default.post(name: .imMessageReceived, object: nil)
    }
    
    /**
     * 转换IMMessage为MessageItem
     */
    private func convertIMMessageToMessageItem(_ message: IMMessage, conversation: IMConversation) -> MessageItem {
        let content = message.content?.string ?? ""
        let senderId = message.fromClientID ?? ""
        let receiverId = conversation.members?.first ?? ""
        
        return MessageItem(
            id: UUID(),
            objectId: message.ID,
            senderId: senderId,
            senderName: senderId, // 这里可以后续优化为真实姓名
            senderAvatar: "",
            senderLoginType: "unknown",
            receiverId: receiverId,
            receiverName: receiverId,
            receiverAvatar: "",
            receiverLoginType: "unknown",
            content: content,
            timestamp: Date(timeIntervalSince1970: TimeInterval(message.sentTimestamp ?? 0)),
            isRead: false,
            type: .text,
            deviceId: nil,
            messageType: "text",
            isMatch: false
        )
    }
    
    /**
     * 转换IMMessage数组为MessageItem数组
     */
    private func convertIMMessagesToMessageItems(_ imMessages: [IMMessage]) -> [MessageItem] {
        return imMessages.map { message in
            // 这里需要根据实际情况创建MessageItem
            // 暂时使用默认值
            return MessageItem(
                id: UUID(),
                objectId: message.ID,
                senderId: message.fromClientID ?? "",
                senderName: message.fromClientID ?? "",
                senderAvatar: "",
                senderLoginType: "unknown",
                receiverId: "",
                receiverName: "",
                receiverAvatar: "",
                receiverLoginType: "unknown",
                content: message.content?.string ?? "",
                timestamp: Date(timeIntervalSince1970: TimeInterval(message.sentTimestamp ?? 0)),
                isRead: false,
                type: .text,
                deviceId: nil,
                messageType: "text",
                isMatch: false
            )
        }
    }
    
    /**
     * 获取连接统计信息
     */
    func getConnectionStats() -> (isConnected: Bool, userId: String?, reconnectAttempts: Int, error: Error?) {
        return webSocketIM.getConnectionStats()
    }
}

// MARK: - 消息类型扩展
// MessageItem.MessageType.text 已经存在，无需重复定义

// MARK: - 与现有系统的兼容性

extension LeanCloudWebSocketIMService {
    
    /**
     * 兼容现有的消息获取接口
     */
    func fetchMessages(userId: String, completion: @escaping ([MessageItem]?, Error?) -> Void) {
        // 使用WebSocket IM获取消息
        loadConversations()
        
        // 暂时返回空数组，后续可以优化为从WebSocket IM获取
        DispatchQueue.main.async {
            completion(self.messages, nil)
        }
    }
    
    /**
     * 兼容现有的消息发送接口
     */
    func sendMessage(message: MessageItem, completion: @escaping (Bool, String) -> Void) {
        // 这里需要根据MessageItem找到对应的conversationId
        // 暂时使用默认实现
        sendMessage(to: "default", content: message.content) { success, errorMessage in
            completion(success, errorMessage)
        }
    }
}
