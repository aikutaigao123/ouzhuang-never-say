//
//  LeanCloudIMClientManager.swift
//  NeverSayNo
//
//  Created by AI Assistant on 2024-12-19.
//  Copyright © 2024 NeverSayNo. All rights reserved.
//

import Foundation
import UIKit
import LeanCloud

/**
 * LeanCloud IM客户端管理器
 * 负责IMClient的登录、连接管理和事件处理
 */
class LeanCloudIMClientManager: NSObject {
    
    // MARK: - 单例
    static let shared = LeanCloudIMClientManager()
    
    // MARK: - 属性
    private var imClient: IMClient?
    private var isConnected = false
    private var currentUserId: String?
    
    // MARK: - 事件回调
    var onMessageReceived: ((IMMessage) -> Void)?
    var onConnectionStatusChanged: ((Bool) -> Void)?
    var onError: ((Error) -> Void)?
    
    // MARK: - 初始化
    private override init() {
        super.init()
        
        // 🔧 尝试清理可能存在的已注册连接
        // 注意：这只是一个尝试，可能无法清理所有情况
        // 真正的清理应该在应用启动时或登出时进行
        cleanUpExistingConnections()
    }
    
    /**
     * 清理已存在的连接（辅助方法）
     */
    private func cleanUpExistingConnections() {
        // 注意：LeanCloud SDK 可能没有公开的方法来清理所有已注册的连接
        // 这个方法主要是为了记录和调试
    }
    
    // MARK: - 公共方法
    
    /**
     * 登录IM客户端
     */
    func loginIMClient(userId: String, completion: @escaping (Bool, String?) -> Void) {
        let startTime = Date()
        
        // 检查是否已经登录
        if let _ = imClient, isConnected, currentUserId == userId {
            completion(true, nil)
            return
        }
        
        // 🔧 修复：如果存在旧客户端（无论是否连接），先强制清理
        
        if let oldClient = imClient {
            
            // 先清理内部状态
            imClient = nil
            isConnected = false
            currentUserId = nil
            
            // 关闭旧客户端
            oldClient.close { [weak self] result in
                // 等待一段时间确保资源释放
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self?.createAndLoginClient(userId: userId, startTime: startTime, completion: completion)
                }
            }
            return
        }
        
        // 创建新的IM客户端
        createAndLoginClient(userId: userId, startTime: startTime, completion: completion)
    }
    
    /**
     * 创建并登录IM客户端（内部方法）
     * @param retryCount 重试次数，默认0
     */
    private func createAndLoginClient(userId: String, startTime: Date, completion: @escaping (Bool, String?) -> Void, retryCount: Int = 0) {
        // 使用weak self避免循环引用
        
        do {
            
            // 🔧 尝试创建 IMClient - 参考 Sign in with Apple 的设计
            // 先尝试使用 LCUser 创建（如果用户已登录），这样可以省掉登录签名操作
            let client: IMClient
            
            if retryCount == 0 {
                // 第一次尝试：先尝试使用 LCUser 创建，如果失败则使用 clientId
                
                // 🔧 重要：游客用户必须使用 userId 创建 IMClient，不能使用 LCUser
                // 因为多个游客用户可能共享同一个 LCUser，使用 userId 可以确保 IM 客户端唯一性
                client = try IMClient(ID: userId)
            } else {
                // 重试时：仍然尝试创建，依赖服务器端的自动清理
                client = try IMClient(ID: userId)
            }
            
            // 设置代理
            client.delegate = self
            
            // 🚀 修复：确保在 background QoS 线程上调用 client.open()，避免线程优先级反转
            let openCallQoS = Thread.current.qualityOfService
            if openCallQoS == .userInteractive || openCallQoS == .userInitiated {
                DispatchQueue.global(qos: .background).async { [weak self] in
                    client.open { [weak self] result in
                        DispatchQueue.main.async {
                            switch result {
                            case .success:
                                // 🔧 根据即时通讯文档：SDK会自动关联clientId和设备数据（Installation表）
                                // 关联方式是通过让目标设备订阅名为clientId的Channel
                                
                                self?.imClient = client
                                self?.isConnected = true
                                self?.currentUserId = userId
                                self?.onConnectionStatusChanged?(true)
                                
                                // 🔧 确保设备令牌已关联到当前用户（如果设备令牌已存在）
                                // 注意：SDK会自动关联，但我们可以手动确保关联正确
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                    RemoteNotificationManager.shared.refreshDeviceTokenAfterLogin()
                                }
                                
                                completion(true, nil)
                                
                            case .failure(let error):
                                self?.isConnected = false
                                self?.onConnectionStatusChanged?(false)
                                self?.onError?(error)
                                completion(false, error.localizedDescription)
                            }
                        }
                    }
                }
            } else {
                // 打开连接
                client.open { [weak self] result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success:
                            // 🔧 根据即时通讯文档：SDK会自动关联clientId和设备数据（Installation表）
                            // 关联方式是通过让目标设备订阅名为clientId的Channel
                            
                            self?.imClient = client
                            self?.isConnected = true
                            self?.currentUserId = userId
                            self?.onConnectionStatusChanged?(true)
                            
                            // 🔧 确保设备令牌已关联到当前用户（如果设备令牌已存在）
                            // 注意：SDK会自动关联，但我们可以手动确保关联正确
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                RemoteNotificationManager.shared.refreshDeviceTokenAfterLogin()
                            }
                            
                            completion(true, nil)
                            
                        case .failure(let error):
                            self?.isConnected = false
                            self?.onConnectionStatusChanged?(false)
                            self?.onError?(error)
                            completion(false, error.localizedDescription)
                        }
                    }
                }
            }
            
        } catch {
            
            // 🔧 修复：如果是重复注册错误且还没有重试过，等待更长时间后重试
            if let lcError = error as? LCError, lcError.code == 9976, retryCount == 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
                    guard let self = self else { 
                        return 
                    }
                    self.createAndLoginClient(userId: userId, startTime: startTime, completion: completion, retryCount: 1)
                }
                return
            }
            
            completion(false, error.localizedDescription)
        }
    }
    
    /**
     * 登出IM客户端
     */
    func logoutIMClient(completion: @escaping (Bool) -> Void) {
        
        guard imClient != nil else {
            completion(true)
            return
        }
        
        // 🔧 修复：先清理状态，再关闭连接
        let tempClient = imClient
        imClient = nil
        isConnected = false
        currentUserId = nil
        onConnectionStatusChanged?(false)
        
        tempClient?.close { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    completion(true)
                    
                case .failure:
                    // 即使关闭失败，状态也已清理
                    completion(false)
                }
            }
        }
    }
    
    /**
     * 获取当前IM客户端
     */
    func getCurrentIMClient() -> IMClient? {
        return imClient
    }
    
    /**
     * 检查连接状态
     */
    func isIMClientConnected() -> Bool {
        return isConnected && imClient != nil
    }
    
    /**
     * 获取当前用户ID
     */
    func getCurrentUserId() -> String? {
        return currentUserId
    }
}

// MARK: - IMClientDelegate
extension LeanCloudIMClientManager: IMClientDelegate {
    
    func client(_ client: IMClient, event: IMClientEvent) {
        
        switch event {
        case .sessionDidOpen:
            isConnected = true
            onConnectionStatusChanged?(true)
            
        case .sessionDidClose(let error):
            
            // 处理特定的错误类型
            let lcError = error
                // 忽略 "Conversation not found" 错误，这是正常的
            if lcError.code == 9100 && lcError.reason == "Conversation not found" {
                return
            }
            
            isConnected = false
            onConnectionStatusChanged?(false)
            onError?(error)
            
        case .sessionDidPause:
            isConnected = false
            onConnectionStatusChanged?(false)
            
        case .sessionDidResume:
            isConnected = true
            onConnectionStatusChanged?(true)
            
        }
    }
    
    func client(_ client: IMClient, conversation: IMConversation, event: IMConversationEvent) {
        // 🔍 尝试从 lastMessageUpdated 事件中获取消息
        if case .lastMessageUpdated(newMessage: let isNewMessage) = event {
            
            // 尝试获取最后一条消息
            if let lastMessage = conversation.lastMessage {
                
                // 获取消息时间戳
                let messageTimestamp = lastMessage.sentDate ?? Date()
                let currentTime = Date()
                let timeDiff = currentTime.timeIntervalSince(messageTimestamp)
                
                // 如果这是新消息，触发消息接收回调
                if isNewMessage {
                    
                    // 🔧 新增：检查消息时间戳，只处理30秒内的消息
                    let recentThreshold: TimeInterval = 30
                    if timeDiff <= recentThreshold && timeDiff >= 0 {
                        if let callback = onMessageReceived {
                            callback(lastMessage)
                        }
                    }
                }
            }
        }
        
        switch event {
        case .message(event: let messageEvent):
            switch messageEvent {
            case .received(let message):
                if let callback = onMessageReceived {
                    callback(message)
                }
            default:
                break
            }
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
}
