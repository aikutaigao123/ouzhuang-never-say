//
//  PatMessageService.swift
//  NeverSayNo
//
//  Created by AI Assistant on 2024-12-19.
//  Copyright © 2024 NeverSayNo. All rights reserved.
//

import Foundation
import LeanCloud

/**
 * 拍一拍消息服务
 * 使用新的Conversation管理重构拍一拍发送逻辑
 */
class PatMessageService: NSObject {
    
    // MARK: - 单例
    static let shared = PatMessageService()
    
    // MARK: - 属性
    private var patConversationManager: PatConversationManager {
        return PatConversationManager.shared
    }
    
    private var imClientManager: LeanCloudIMClientManager {
        return LeanCloudIMClientManager.shared
    }
    
    // MARK: - 事件回调
    var onPatMessageSent: ((String, String) -> Void)? // (fromUserId, toUserId)
    var onPatMessageReceived: ((String, String, String) -> Void)? // (fromUserId, toUserId, content)
    var onError: ((Error) -> Void)?
    
    // MARK: - 初始化
    private override init() {
        super.init()
        setupCallbacks()
    }
    
    // MARK: - 公共方法
    
    /**
     * 发送拍一拍消息
     * - Parameters:
     *   - fromUserId: 发送者用户ID
     *   - toUserId: 接收者用户ID
     *   - fromUserName: 发送者用户名
     *   - toUserName: 接收者用户名
     *   - completion: 完成回调
     */
    func sendPatMessage(fromUserId: String, toUserId: String, fromUserName: String, toUserName: String, completion: @escaping (Bool, String?) -> Void) {
        
        // 检查IM客户端是否连接
        let isConnected = imClientManager.isIMClientConnected()
        
        guard isConnected else {
            
            // 尝试登录IM客户端
            imClientManager.loginIMClient(userId: fromUserId) { [weak self] success, error in
                if success {
                    // 登录成功，重试发送
                    self?.sendPatMessage(fromUserId: fromUserId, toUserId: toUserId, fromUserName: fromUserName, toUserName: toUserName, completion: completion)
                } else {
                    completion(false, error)
                }
            }
            return
        }
        
        // 创建拍一拍消息内容
        let patContent = "\(fromUserName) 拍了拍 \(toUserName)"
        
        // 使用PatConversationManager发送消息（传递用户名用于推送通知）
        patConversationManager.sendPatMessage(
            fromUserId: fromUserId,
            toUserId: toUserId,
            fromUserName: fromUserName,
            toUserName: toUserName,
            content: patContent
        ) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.onPatMessageSent?(fromUserId, toUserId)
                    completion(true, nil)
                } else {
                    self?.onError?(NSError(domain: "PatMessageService", code: -1, userInfo: [NSLocalizedDescriptionKey: error ?? "未知错误"]))
                    completion(false, error)
                }
            }
        }
    }
    
    /**
     * 发送拍一拍消息（兼容旧接口）
     * - Parameters:
     *   - fromUserId: 发送者用户ID
     *   - toUserId: 接收者用户ID
     *   - fromUserName: 发送者用户名
     *   - toUserName: 接收者用户名
     *   - locationManager: 位置管理器（忽略）
     *   - userLoginType: 用户登录类型（忽略）
     *   - userEmail: 用户邮箱（忽略）
     *   - userAvatar: 用户头像（忽略）
     *   - completion: 完成回调
     */
    func sendPatMessage(fromUserId: String, toUserId: String, fromUserName: String, toUserName: String, locationManager: Any? = nil, userLoginType: String? = nil, userEmail: String? = nil, userAvatar: String? = nil, completion: @escaping (Bool) -> Void) {
        
        sendPatMessage(fromUserId: fromUserId, toUserId: toUserId, fromUserName: fromUserName, toUserName: toUserName) { success, error in
            completion(success)
        }
    }
    
    /**
     * 初始化IM客户端
     * - Parameters:
     *   - userId: 用户ID
     *   - userName: 用户名
     *   - completion: 完成回调
     */
    func initializeIMClient(userId: String, userName: String, completion: @escaping (Bool, String?) -> Void) {
        
        imClientManager.loginIMClient(userId: userId) { success, error in
            DispatchQueue.main.async {
                if success {
                    completion(true, nil)
                } else {
                    completion(false, error)
                }
            }
        }
    }
    
    /**
     * 断开IM客户端
     */
    func disconnectIMClient(completion: @escaping (Bool) -> Void) {
        
        imClientManager.logoutIMClient { success in
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }
    
    /**
     * 检查IM客户端连接状态
     */
    func isIMClientConnected() -> Bool {
        return imClientManager.isIMClientConnected()
    }
    
    // MARK: - 私有方法
    
    /**
     * 设置回调
     */
    private func setupCallbacks() {
        patConversationManager.onPatMessageReceived = { [weak self] fromUserId, toUserId, content in
            self?.onPatMessageReceived?(fromUserId, toUserId, content)
        }
        
        patConversationManager.onError = { [weak self] error in
            self?.onError?(error)
        }
    }
}
