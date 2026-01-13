//
//  PatMessageUpdateManager.swift
//  NeverSayNo
//
//  Created by AI Assistant on 2024-12-19.
//  Copyright © 2024 NeverSayNo. All rights reserved.
//

import Foundation
import Combine

/**
 * 拍一拍消息更新管理器
 * 负责实时更新拍一拍消息列表，优化消息显示
 */
class PatMessageUpdateManager: ObservableObject {
    
    // MARK: - 单例
    static let shared = PatMessageUpdateManager()
    
    // MARK: - 属性
    @Published var patMessages: [MessageItem] = []
    @Published var isUpdating = false
    
    private var cancellables = Set<AnyCancellable>()
    private var patMessageService: PatMessageService {
        return PatMessageService.shared
    }
    
    // 🎯 新增：未读数量缓存（按用户隔离）
    private var unreadCountCache: [String: (count: Int, timestamp: Date)] = [:]
    private let cacheExpirationInterval: TimeInterval = 1.0 // 缓存1秒，避免频繁计算
    private let cacheLock = NSLock()
    
    // MARK: - 初始化
    private init() {
        setupCallbacks()
    }
    
    // MARK: - 公共方法
    
    /**
     * 添加拍一拍消息
     * - Parameter message: 拍一拍消息
     */
    func addPatMessage(_ message: MessageItem) {
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { 
                return 
            }
            
            
            // 检查是否已存在相同消息（避免重复）
            let existingMessage = self.patMessages.first { existingMessage in
                let isSameSender = existingMessage.senderId == message.senderId
                let isSameReceiver = existingMessage.receiverId == message.receiverId
                let isSameContent = existingMessage.content == message.content
                let isSameTime = abs(existingMessage.timestamp.timeIntervalSince(message.timestamp)) < 1.0
                
                
                return isSameSender && isSameReceiver && isSameContent && isSameTime
            }
            
            if existingMessage == nil {
                // 添加到列表开头
                self.patMessages.insert(message, at: 0)
                
                // 🎯 优化：清除接收者的未读数量缓存
                self.clearUnreadCountCache(for: message.receiverId)
                
                // 发送通知
                NotificationCenter.default.post(
                    name: NSNotification.Name("PatMessageAdded"),
                    object: nil,
                    userInfo: ["message": message]
                )
            } else {
            }
        }
    }
    
    /**
     * 移除拍一拍消息
     * - Parameter messageId: 消息ID
     */
    func removePatMessage(messageId: UUID) {
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 🎯 优化：在移除前获取接收者ID，用于清除缓存
            if let message = self.patMessages.first(where: { $0.id == messageId }) {
                self.patMessages.removeAll { $0.id == messageId }
                // 清除接收者的未读数量缓存
                self.clearUnreadCountCache(for: message.receiverId)
            } else {
                self.patMessages.removeAll { $0.id == messageId }
            }
        }
    }
    
    /**
     * 更新拍一拍消息
     * - Parameter message: 更新后的消息
     */
    func updatePatMessage(_ message: MessageItem) {
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let index = self.patMessages.firstIndex(where: { $0.id == message.id }) {
                self.patMessages[index] = message
                // 🎯 优化：清除接收者的未读数量缓存
                self.clearUnreadCountCache(for: message.receiverId)
            } else {
            }
        }
    }
    
    /**
     * 清空拍一拍消息列表
     */
    func clearPatMessages() {
        
        DispatchQueue.main.async { [weak self] in
            self?.patMessages.removeAll()
            // 🎯 优化：清除所有未读数量缓存
            self?.clearUnreadCountCache()
        }
    }
    
    /**
     * 🎯 新增：清空指定用户的拍一拍消息
     * - Parameter userId: 用户ID
     */
    func clearPatMessagesForUser(_ userId: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // 移除发送者或接收者是该用户的消息
            self.patMessages.removeAll { message in
                return message.senderId == userId || message.receiverId == userId
            }
            // 🎯 优化：清除该用户的未读数量缓存
            self.clearUnreadCountCache(for: userId)
        }
    }
    
    /**
     * 获取指定用户的拍一拍消息
     * - Parameter userId: 用户ID
     * - Returns: 该用户的拍一拍消息列表
     */
    func getPatMessagesForUser(_ userId: String) -> [MessageItem] {
        return patMessages.filter { message in
            message.senderId == userId || message.receiverId == userId
        }
    }
    
    /**
     * 获取拍一拍消息数量
     * - Parameter userId: 用户ID（可选）
     * - Returns: 消息数量
     */
    func getPatMessageCount(for userId: String? = nil) -> Int {
        if let userId = userId {
            return getPatMessagesForUser(userId).count
        } else {
            return patMessages.count
        }
    }
    
    /**
     * 获取未读拍一拍消息数量
     * - Parameter userId: 用户ID
     * - Returns: 未读消息数量
     */
    func getUnreadPatMessageCount(for userId: String) -> Int {
        return patMessages.filter { message in
            message.receiverId == userId && !message.isRead
        }.count
    }
    
    /**
     * 获取指定接收者的未读拍一拍总数（合并本地缓存与内存数据）
     * - Parameter receiverId: 当前用户ID
     * - Returns: 未读拍一拍总数
     */
    func getTotalUnreadPatCount(forReceiverId receiverId: String) -> Int {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        // 🎯 优化：检查缓存是否有效
        let currentTime = Date()
        if let cached = unreadCountCache[receiverId],
           currentTime.timeIntervalSince(cached.timestamp) < cacheExpirationInterval {
            // 缓存有效，直接返回
            return cached.count
        }
        
        // 缓存无效或不存在，重新计算
        var combinedMessages: [MessageItem] = patMessages
        
        let localMessages = UserDefaultsManager.getPatMessages(userId: receiverId)
        
        if !localMessages.isEmpty {
            combinedMessages.append(contentsOf: localMessages)
        }
        
        var seenMessageIds = Set<String>()
        var totalCount = 0
        
        for message in combinedMessages {
            guard message.receiverId == receiverId, !message.isRead else { 
                continue 
            }
            
            let identifier = message.objectId ?? message.id.uuidString
            if !seenMessageIds.contains(identifier) {
                seenMessageIds.insert(identifier)
                totalCount += 1
            }
        }
        
        // 更新缓存
        unreadCountCache[receiverId] = (count: totalCount, timestamp: currentTime)
        
        return totalCount
    }
    
    /**
     * 🎯 新增：清除指定用户的未读数量缓存
     * - Parameter receiverId: 用户ID（nil 表示清除所有缓存）
     */
    func clearUnreadCountCache(for receiverId: String? = nil) {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        
        if let receiverId = receiverId {
            unreadCountCache.removeValue(forKey: receiverId)
        } else {
            unreadCountCache.removeAll()
        }
    }
    
    /**
     * 标记拍一拍消息为已读
     * - Parameter messageId: 消息ID
     */
    func markPatMessageAsRead(_ messageId: UUID) {
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let index = self.patMessages.firstIndex(where: { $0.id == messageId }) {
                let receiverId = self.patMessages[index].receiverId
                self.patMessages[index].isRead = true
                // 🎯 优化：清除接收者的未读数量缓存
                self.clearUnreadCountCache(for: receiverId)
            }
        }
    }
    
    /**
     * 标记所有拍一拍消息为已读
     * - Parameter userId: 用户ID
     */
    func markAllPatMessagesAsRead(for userId: String) {
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            for index in 0..<self.patMessages.count {
                if self.patMessages[index].receiverId == userId {
                    self.patMessages[index].isRead = true
                }
            }
            // 🎯 优化：清除该用户的未读数量缓存
            self.clearUnreadCountCache(for: userId)
        }
    }
    
    // MARK: - 私有方法
    
    /**
     * 发送拍一拍消息通知
     */
    private func sendPatMessageNotification(fromUserId: String, toUserId: String, content: String) {
        
        // 🎯 修改：使用 fetchUserNameAndLoginType 获取用户名，如果失败则使用"未知用户"而不是 userId
        LeanCloudService.shared.fetchUserNameAndLoginType(objectId: fromUserId) { senderName, _, _ in
            // 如果无法获取用户名，使用"未知用户"而不是 userId
            let resolvedSenderName: String
            if let name = senderName, !name.isEmpty {
                resolvedSenderName = name
            } else {
                resolvedSenderName = "未知用户"
            }
            
            // 生成消息ID
            let messageId = UUID().uuidString
            
            // 🎯 修改：系统弹窗通知显示"谁拍了拍你"的格式，receiverName 参数不再使用（通知中只显示"谁拍了拍你"）
            // 发送本地通知
            NotificationManager.shared.sendPatMessageNotification(
                from: resolvedSenderName,
                to: "", // 🎯 不再使用 receiverName，通知中只显示"谁拍了拍你"
                messageId: messageId
            )
        }
    }
    
    /**
     * 设置回调
     */
    private func setupCallbacks() {
        
        // 🎯 优化：监听拍一拍消息保存通知，清除缓存
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PatMessagesSaved"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let userId = notification.userInfo?["userId"] as? String {
                self?.clearUnreadCountCache(for: userId)
            }
        }
        
        // 监听拍一拍消息接收
        patMessageService.onPatMessageReceived = { [weak self] fromUserId, toUserId, content in
            
            // 🎯 新增：检查发送方是否在我的好友列表中
            let isFriend = FriendshipManager.shared.isFriend(fromUserId)
            if !isFriend {
                // 发送方不在好友列表中，不处理这个消息
                return
            }
            
            // 创建新的拍一拍消息
            let newMessage = MessageItem(
                senderId: fromUserId,
                senderName: "用户", // 需要从用户信息获取
                senderAvatar: "",
                senderLoginType: nil,
                receiverId: toUserId,
                receiverName: "你",
                receiverAvatar: "",
                receiverLoginType: nil,
                content: content,
                timestamp: Date(),
                isRead: false,
                type: .text,
                messageType: "pat",
                isMatch: false
            )
            
            
            // 添加到消息列表
            self?.addPatMessage(newMessage)
            
            // 发送本地通知
            self?.sendPatMessageNotification(fromUserId: fromUserId, toUserId: toUserId, content: content)
        }
        
        // 监听拍一拍消息发送
        patMessageService.onPatMessageSent = { fromUserId, toUserId in
            // 这里可以添加发送成功的处理逻辑
        }
        
        // 监听错误
        patMessageService.onError = { error in
            // 这里可以添加错误处理逻辑
        }
        
    }
}

