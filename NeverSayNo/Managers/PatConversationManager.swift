//
//  PatConversationManager.swift
//  NeverSayNo
//
//  Created by AI Assistant on 2024-12-19.
//  Copyright © 2024 NeverSayNo. All rights reserved.
//

import Foundation
import UIKit
import LeanCloud

/**
 * 拍一拍对话管理器
 * 负责创建和管理拍一拍相关的对话
 */
class PatConversationManager: NSObject {
    
    // MARK: - 单例
    static let shared = PatConversationManager()
    
    // MARK: - 属性
    private var conversations: [String: IMConversation] = [:]
    private var imClientManager: LeanCloudIMClientManager {
        return LeanCloudIMClientManager.shared
    }
    
    // MARK: - 事件回调
    var onPatMessageReceived: ((String, String, String) -> Void)? // (fromUserId, toUserId, content)
    var onConversationCreated: ((String) -> Void)? // conversationId
    var onError: ((Error) -> Void)?
    
    // MARK: - 初始化
    private override init() {
        super.init()
        setupIMClientCallbacks()
    }
    
    // MARK: - 公共方法
    
    /**
     * 创建或获取拍一拍对话
     * - Parameters:
     *   - fromUserId: 发送者用户ID
     *   - toUserId: 接收者用户ID
     *   - completion: 完成回调
     */
    func createOrGetPatConversation(fromUserId: String, toUserId: String, completion: @escaping (IMConversation?, String?) -> Void) {
        
        // 检查IM客户端是否连接
        let isConnected = imClientManager.isIMClientConnected()
        guard isConnected else {
            completion(nil, "IM客户端未连接")
            return
        }
        
        // 生成对话ID（确保唯一性）
        let conversationId = generatePatConversationId(fromUserId: fromUserId, toUserId: toUserId)
        
        // 检查是否已有对话
        if let existingConversation = conversations[conversationId] {
            completion(existingConversation, nil)
            return
        }
        
        // 创建新对话
        createPatConversation(conversationId: conversationId, fromUserId: fromUserId, toUserId: toUserId, completion: completion)
    }
    
    /**
     * 发送拍一拍消息
     * - Parameters:
     *   - fromUserId: 发送者用户ID
     *   - toUserId: 接收者用户ID
     *   - fromUserName: 发送者用户名（用于推送通知）
     *   - toUserName: 接收者用户名（用于推送通知）
     *   - content: 消息内容
     *   - completion: 完成回调
     */
    func sendPatMessage(fromUserId: String, toUserId: String, fromUserName: String, toUserName: String, content: String, completion: @escaping (Bool, String?) -> Void) {
        
        // 生成对话ID
        let conversationId = generatePatConversationId(fromUserId: fromUserId, toUserId: toUserId)
        
        // 检查是否已有缓存的对话
        if let cachedConversation = conversations[conversationId] {
            sendMessageToConversation(cachedConversation, fromUserId: fromUserId, toUserId: toUserId, fromUserName: fromUserName, toUserName: toUserName, content: content, completion: completion)
            return
        }
        
        // 创建或获取对话
        createOrGetPatConversation(fromUserId: fromUserId, toUserId: toUserId) { [weak self] conversation, error in
            if let error = error {
                completion(false, error)
                return
            }
            
            guard let conversation = conversation else {
                completion(false, "对话创建失败")
                return
            }
            
            // 发送消息
            self?.sendMessageToConversation(conversation, fromUserId: fromUserId, toUserId: toUserId, fromUserName: fromUserName, toUserName: toUserName, content: content, completion: completion)
        }
    }
    
    /**
     * 获取对话
     * - Parameter conversationId: 对话ID
     * - Returns: 对话对象
     */
    func getConversation(conversationId: String) -> IMConversation? {
        return conversations[conversationId]
    }
    
    /**
     * 清理对话缓存
     */
    func clearConversations() {
        conversations.removeAll()
    }
    
    // MARK: - 好友申请消息
    
    /**
     * 发送好友申请消息（类似拍一拍消息，支持离线推送）
     * - Parameters:
     *   - fromUserId: 发送者用户ID
     *   - toUserId: 接收者用户ID
     *   - fromUserName: 发送者用户名
     *   - toUserName: 接收者用户名
     *   - completion: 完成回调
     */
    func sendFriendRequestMessage(fromUserId: String, toUserId: String, fromUserName: String, toUserName: String, completion: @escaping (Bool, String?) -> Void) {
        // 生成对话ID（使用与拍一拍相同的对话）
        let conversationId = generatePatConversationId(fromUserId: fromUserId, toUserId: toUserId)
        
        // 🔧 修复：如果 fromUserName 为空，从 UserNameRecord 获取或使用"未知用户"
        let safeFromUserName: String
        if fromUserName.isEmpty {
            // 尝试从缓存获取用户名
            safeFromUserName = LeanCloudService.shared.getCachedUserName(for: fromUserId) ?? "未知用户"
        } else {
            safeFromUserName = fromUserName
        }
        
        // 消息内容
        let content = "\(safeFromUserName) 对你发送了好友申请"
        
        // 🔧 修复：检查IM连接状态，如果未连接则尝试连接
        let isConnected = imClientManager.isIMClientConnected()
        
        if !isConnected {
            // 获取当前用户ID（使用发送者ID，因为发送者就是当前用户）
            let currentUserId = fromUserId
            
            // 尝试连接IM客户端
            imClientManager.loginIMClient(userId: currentUserId) { [weak self] success, error in
                if success {
                    // 连接成功后继续发送消息
                    self?.continueSendFriendRequestMessage(
                        conversationId: conversationId,
                        fromUserId: fromUserId,
                        toUserId: toUserId,
                        fromUserName: safeFromUserName,
                        toUserName: toUserName,
                        content: content,
                        completion: completion
                    )
                } else {
                    // 即使IM连接失败，好友申请也已经成功，只是无法发送即时通知
                    completion(false, "IM连接失败，但好友申请已成功: \(error ?? "未知错误")")
                }
            }
            return
        }
        
        // IM已连接，继续发送消息
        continueSendFriendRequestMessage(
            conversationId: conversationId,
            fromUserId: fromUserId,
            toUserId: toUserId,
            fromUserName: safeFromUserName,
            toUserName: toUserName,
            content: content,
            completion: completion
        )
    }
    
    /**
     * 继续发送好友申请消息（辅助方法）
     */
    private func continueSendFriendRequestMessage(
        conversationId: String,
        fromUserId: String,
        toUserId: String,
        fromUserName: String,
        toUserName: String,
        content: String,
        completion: @escaping (Bool, String?) -> Void
    ) {
        // 检查是否已有缓存的对话
        if let cachedConversation = conversations[conversationId] {
            sendFriendRequestMessageToConversation(cachedConversation, fromUserId: fromUserId, toUserId: toUserId, fromUserName: fromUserName, toUserName: toUserName, content: content, completion: completion)
            return
        }
        
        // 创建或获取对话
        createOrGetPatConversation(fromUserId: fromUserId, toUserId: toUserId) { [weak self] conversation, error in
            guard let conversation = conversation else {
                completion(false, error)
                return
            }
            
            // 发送消息
            self?.sendFriendRequestMessageToConversation(conversation, fromUserId: fromUserId, toUserId: toUserId, fromUserName: fromUserName, toUserName: toUserName, content: content, completion: completion)
        }
    }
    
    /**
     * 向对话发送好友申请消息（带推送配置）
     */
    private func sendFriendRequestMessageToConversation(_ conversation: IMConversation, fromUserId: String, toUserId: String, fromUserName: String, toUserName: String, content: String, completion: @escaping (Bool, String?) -> Void) {
        // 创建文本消息
        let message = IMTextMessage(text: content)

        // 🔧 根据离线消息推送文档：客户端发送消息时指定推送信息
        // 推送内容优先级：服务端动态生成通知 > 客户端发送消息时指定推送信息 > 静态配置提醒消息
        // 关键：必须包含 content-available: 1，否则后台无法触发 didReceiveRemoteNotification
        let pushData: [String: Any] = [
            "alert": "\(fromUserName) 对你发送了好友申请",
            "badge": "Increment",
            "sound": "default",
            "content-available": 1,  // 🔧 关键：必须包含此字段，后台才能处理推送
            "messageType": "friend_request",  // 自定义字段：消息类型
            "senderName": fromUserName,
            "receiverName": toUserName,
            "senderId": fromUserId,
            "receiverId": toUserId
        ]


        // 发送消息（带pushData参数）
        do {
            try conversation.send(message: message, pushData: pushData) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        completion(true, nil)

                    case .failure(let error):
                        completion(false, error.localizedDescription)
                    }
                }
            }
        } catch {
            completion(false, error.localizedDescription)
        }
    }
    
    // MARK: - 私有方法
    
    /**
     * 设置IM客户端回调
     */
    private func setupIMClientCallbacks() {
        imClientManager.onMessageReceived = { [weak self] message in
            self?.handleReceivedMessage(message)
        }
        
        imClientManager.onError = { [weak self] error in
            self?.onError?(error)
        }
    }
    
    /**
     * 生成拍一拍对话ID
     */
    private func generatePatConversationId(fromUserId: String, toUserId: String) -> String {
        // 确保ID的唯一性和一致性（无论谁先创建）
        let sortedIds = [fromUserId, toUserId].sorted()
        let conversationId = "pat_\(sortedIds[0])_\(sortedIds[1])"
        return conversationId
    }
    
    /**
     * 创建拍一拍对话
     */
    private func createPatConversation(conversationId: String, fromUserId: String, toUserId: String, completion: @escaping (IMConversation?, String?) -> Void) {
        
        guard let imClient = imClientManager.getCurrentIMClient() else {
            completion(nil, "IM客户端不可用")
            return
        }
        
        // 创建对话
        do {
            let attributes: [String: Any] = [
                "type": "pat",
                "createdBy": fromUserId,
                "createdAt": Date().timeIntervalSince1970
            ]
            try imClient.createConversation(clientIDs: [fromUserId, toUserId], name: "拍一拍对话", attributes: attributes) { [weak self] result in
                DispatchQueue.main.async {
                    
                    switch result {
                    case .success(let conversation):
                        self?.conversations[conversationId] = conversation
                        self?.onConversationCreated?(conversation.ID)
                        completion(conversation, nil)
                        
                    case .failure(let error):
                        let nsError = error as NSError
                        if !nsError.userInfo.isEmpty {
                        }
                        self?.onError?(error)
                        completion(nil, error.localizedDescription)
                    }
                }
            }
        } catch {
            completion(nil, error.localizedDescription)
        }
    }
    
    /**
     * 向对话发送消息
     * - Parameters:
     *   - conversation: 对话对象
     *   - fromUserId: 发送者用户ID（用于推送通知）
     *   - toUserId: 接收者用户ID（用于推送通知）
     *   - fromUserName: 发送者用户名（用于推送通知）
     *   - toUserName: 接收者用户名（用于推送通知）
     *   - content: 消息内容
     *   - completion: 完成回调
     */
    private func sendMessageToConversation(_ conversation: IMConversation, fromUserId: String, toUserId: String, fromUserName: String, toUserName: String, content: String, completion: @escaping (Bool, String?) -> Void) {
        
        // 检查对话状态
        
        // 创建文本消息
        let message = IMTextMessage(text: content)
        
        // 🔧 根据离线消息推送文档：客户端发送消息时指定推送信息
        // 推送内容优先级：服务端动态生成通知 > 客户端发送消息时指定推送信息 > 静态配置提醒消息
        // 关键：必须包含 content-available: 1，否则后台无法触发 didReceiveRemoteNotification
        // 🎯 修改：系统弹窗通知显示"谁拍了拍你"的格式（推送通知是发给接收者的）
        let pushData: [String: Any] = [
            "alert": "\(fromUserName) 拍了拍你",
            "badge": "Increment",
            "sound": "default",
            "content-available": 1,  // 🔧 关键：必须包含此字段，后台才能处理推送
            "messageType": "pat",    // 自定义字段：消息类型
            "senderName": fromUserName,
            "receiverName": toUserName,
            "senderId": fromUserId,
            "receiverId": toUserId
        ]
        
        
        // 发送消息（带pushData参数）
        do {
            try conversation.send(message: message, pushData: pushData) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        completion(true, nil)
                        
                    case .failure(let error):
                        completion(false, error.localizedDescription)
                    }
                }
            }
        } catch {
            completion(false, error.localizedDescription)
        }
    }
    
    /**
     * 处理接收到的消息
     */
    private func handleReceivedMessage(_ message: IMMessage) {
        
        // 检查是否是拍一拍消息
        guard let textMessage = message as? IMTextMessage,
              let conversationId = message.conversationID else {
            return
        }
        
        // 检查是否是拍一拍消息（通过消息内容判断，而不是对话ID）
        let content = textMessage.text ?? ""
        let fromUserId = message.fromClientID ?? ""
        let currentUserId = imClientManager.getCurrentUserId() ?? ""
        
        
        // 检查是否是拍一拍消息（通过消息内容判断）
        if content.contains("拍了拍") {
            
            // 🔧 从消息内容中解析接收者用户名（用于日志）
            // 消息格式："{fromUserName} 拍了拍 {toUserName}"
            let receiverName = extractReceiverName(from: content, senderName: fromUserId)
            
            // 🎯 新增：检查发送方是否在我的好友列表中
            let isFriend = FriendshipManager.shared.isFriend(fromUserId)
            if !isFriend {
                // 发送方不在好友列表中，不处理这个消息
                return
            }
            
            // 🔧 关键检查：验证消息是否真的是发给当前用户的
            // 方法1：检查对话成员（如果对话包含当前用户且当前用户不是发送者，则消息是发给当前用户的）
            var isMessageForCurrentUser = false
            
            // 🔍 添加详细调试信息
            
            if let conversation = conversations.values.first(where: { $0.ID == conversationId }) {
                let members = conversation.members ?? []
                
                // 🔧 关键修复：LeanCloud IM 在发送消息后会立即回传给发送者
                // 这是正常行为，用于确认消息已发送。但我们需要区分：
                // 1. 发送者收到的回传消息（应该忽略）
                // 2. 接收者收到的消息（应该处理）
                // 
                // 判断方法：如果当前用户是发送者，这是回传消息，应该忽略
                // 如果当前用户不是发送者，这是接收到的消息，应该处理
                if currentUserId == fromUserId {
                    isMessageForCurrentUser = false
                } else if members.contains(currentUserId) && currentUserId != fromUserId {
                    isMessageForCurrentUser = true
                } else {
                }
            } else {
                // 如果找不到对话缓存，默认认为消息是发给当前用户的（因为IM系统只会推送消息给接收者）
                // 但需要额外验证：检查消息内容中的接收者
                
                // 🔧 关键修复：如果当前用户是发送者，即使找不到对话缓存，也应该是回传消息
                if currentUserId == fromUserId {
                    isMessageForCurrentUser = false
                } else {
                    // 从消息内容中提取接收者名称，检查是否是当前用户
                    if receiverName != nil {
                        // 这里需要比较接收者名称，但名称可能不准确，所以主要依赖IM系统的推送机制
                        // 如果IM系统推送了这条消息给当前用户，通常意味着消息是发给当前用户的
                        isMessageForCurrentUser = true
                    }
                }
            }
            
            // 🔧 关键检查：只有当消息是发给当前用户时才触发回调
            if isMessageForCurrentUser {
                // 触发回调
                if let callback = onPatMessageReceived {
                    callback(fromUserId, currentUserId, content)
                }
            } else {
            }
        }
        // 🔧 修复：处理好友申请消息
        else if content.contains("对你发送了好友申请") {
            
            // 检查是否是发给当前用户的消息
            var isMessageForCurrentUser = false
            
            // 尝试从缓存中获取对话
            if let conversation = conversations.values.first(where: { $0.ID == conversationId }) {
                // 检查对话成员
                let members = conversation.members ?? []
                if members.contains(currentUserId) && currentUserId != fromUserId {
                    isMessageForCurrentUser = true
                }
            } else {
                // 如果找不到对话缓存，默认认为消息是发给当前用户的（因为IM系统只会推送消息给接收者）
                if currentUserId != fromUserId {
                    isMessageForCurrentUser = true
                }
            }
            
            if isMessageForCurrentUser {
                
                // 从消息内容中提取发送者用户名
                // 消息格式："{fromUserName} 对你发送了好友申请"
                let senderName = extractSenderNameFromFriendRequest(content: content) ?? fromUserId
                
                // 构造消息数据
                let messageData: [String: Any] = [
                    "objectId": message.ID ?? UUID().uuidString,
                    "messageType": "friend_request",
                    "senderName": senderName,
                    "receiverId": currentUserId,
                    "timestamp": ISO8601DateFormatter().string(from: message.sentDate ?? Date())
                ]
                
                
                // 调用后台消息处理器
                BackgroundMessageProcessor.shared.processReceivedMessage(messageData, currentUserId: currentUserId)
                
                // 🎯 方案1：立即刷新好友申请列表和数量
                // 发送通知触发UI刷新
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshNewFriends"), object: nil)
                    // 🎯 新增：在通知中传递发送者名称和ID，用于弹窗显示
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NewFriendshipRequest"),
                        object: nil,
                        userInfo: ["senderName": senderName, "senderId": fromUserId]
                    )
                    
                    // 立即刷新好友申请列表（不等待LiveQuery）
                    FriendshipManager.shared.fetchFriendshipRequestsWithRetry(maxAttempts: 2) { requests, _ in
                        DispatchQueue.main.async {
                            if requests != nil {
                                _ = requests?.filter { $0.status == "pending" }.count ?? 0
                            }
                        }
                    }
                }
            } else {
            }
        } else {
            // 其他类型的消息
        }
    }
    
    /// 从好友申请消息内容中提取发送者用户名
    private func extractSenderNameFromFriendRequest(content: String) -> String? {
        // 消息格式："{fromUserName} 对你发送了好友申请"
        if let range = content.range(of: " 对你发送了好友申请") {
            let beforeRequest = String(content[..<range.lowerBound])
            return beforeRequest.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
    
    /// 从消息内容中提取接收者用户名
    private func extractReceiverName(from content: String, senderName: String) -> String? {
        // 消息格式："{fromUserName} 拍了拍 {toUserName}"
        if let range = content.range(of: "拍了拍 ") {
            let afterPat = String(content[range.upperBound...])
            return afterPat.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }
    
    private func appStateString(_ state: UIApplication.State) -> String {
        switch state {
        case .active: return "前台活跃"
        case .inactive: return "前台非活跃"
        case .background: return "后台"
        @unknown default: return "未知"
        }
    }
}
