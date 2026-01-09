//
//  LeanCloudWebSocketPushNotification.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//  LeanCloud WebSocket IM 离线推送通知配置
//

import Foundation
import UIKit
import UserNotifications
import LeanCloud

/**
 * LeanCloud WebSocket IM 离线推送通知管理器
 * 负责配置和管理离线推送通知
 */
class LeanCloudWebSocketPushNotification: NSObject, ObservableObject {
    static let shared = LeanCloudWebSocketPushNotification()
    
    // MARK: - 属性
    private var isPushEnabled = false
    private var deviceToken: String?
    
    override init() {
        super.init()
        setupPushNotification()
    }
    
    // MARK: - 公共接口
    
    /**
     * 配置离线推送通知
     */
    func configureOfflinePushNotification() {
        
        // 1. 请求推送权限
        requestPushPermission()
        
        // 2. 配置LeanCloud推送
        configureLeanCloudPush()
        
        // 3. 注册设备Token
        registerDeviceToken()
    }
    
    /**
     * 发送离线推送通知
     */
    func sendOfflinePushNotification(
        to userId: String,
        title: String,
        body: String,
        data: [String: Any] = [:],
        completion: @escaping (Bool, String?) -> Void
    ) {
        guard isPushEnabled else {
            completion(false, "推送通知未启用")
            return
        }
        
        // 构建推送数据
        let pushData: [String: Any] = [
            "title": title,
            "body": body,
            "data": data,
            "sound": "default",
            "badge": 1
        ]
        
        // 使用LeanCloud推送服务发送
        sendLeanCloudPush(userId: userId, data: pushData, completion: completion)
    }
    
    /**
     * 处理推送通知点击
     */
    func handlePushNotificationClick(userInfo: [AnyHashable: Any]) {
        
        // 解析推送数据
        if let messageId = userInfo["messageId"] as? String {
            // 跳转到消息详情
            handleMessageNotificationClick(messageId: messageId)
        } else if let conversationId = userInfo["conversationId"] as? String {
            // 跳转到对话
            handleConversationNotificationClick(conversationId: conversationId)
        }
    }
    
    /**
     * 获取推送状态
     */
    func getPushStatus() -> (isEnabled: Bool, deviceToken: String?) {
        return (isEnabled: isPushEnabled, deviceToken: deviceToken)
    }
    
    // MARK: - 私有方法
    
    /**
     * 设置推送通知
     */
    private func setupPushNotification() {
        // 设置UNUserNotificationCenter代理
        UNUserNotificationCenter.current().delegate = self
        
        // 监听应用状态变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    /**
     * 请求推送权限
     */
    private func requestPushPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, error in
            DispatchQueue.main.async {
                if granted {
                    self?.isPushEnabled = true
                } else {
                    self?.isPushEnabled = false
                }
            }
        }
    }
    
    /**
     * 配置LeanCloud推送
     */
    private func configureLeanCloudPush() {
        // 配置LeanCloud推送设置
        let _: [String: Any] = [
            "enable": true,
            "sound": "default",
            "badge": true,
            "alert": true
        ]
        
        // 这里可以调用LeanCloud的推送配置API
    }
    
    /**
     * 注册设备Token
     */
    private func registerDeviceToken() {
        // 获取设备Token
        UIApplication.shared.registerForRemoteNotifications()
    }
    
    /**
     * 设置设备Token
     */
    func setDeviceToken(_ deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.deviceToken = tokenString
        
        
        // 将Token发送到LeanCloud
        sendDeviceTokenToLeanCloud(token: tokenString)
    }
    
    /**
     * 发送LeanCloud推送
     */
    private func sendLeanCloudPush(
        userId: String,
        data: [String: Any],
        completion: @escaping (Bool, String?) -> Void
    ) {
        // 构建推送请求
        let _: [String: Any] = [
            "where": [
                "userId": userId
            ],
            "data": data
        ]
        
        // 这里应该调用LeanCloud的推送API
        // 暂时模拟成功
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(true, nil)
        }
        
    }
    
    /**
     * 处理消息通知点击
     */
    private func handleMessageNotificationClick(messageId: String) {
        
        // 发送通知到UI层
        NotificationCenter.default.post(
            name: .pushNotificationMessageClick,
            object: nil,
            userInfo: ["messageId": messageId]
        )
    }
    
    /**
     * 处理对话通知点击
     */
    private func handleConversationNotificationClick(conversationId: String) {
        
        // 发送通知到UI层
        NotificationCenter.default.post(
            name: .pushNotificationConversationClick,
            object: nil,
            userInfo: ["conversationId": conversationId]
        )
    }
    
    // MARK: - 应用状态监听
    
    @objc private func applicationDidBecomeActive() {
        // 🎯 修复：不在这里清除 badge，badge 应该由 NewFriendsCountManager 统一管理
        // 清除推送徽章的逻辑已移除，因为：
        // 1. NewFriendsCountManager 会从 UserDefaults 恢复 count
        // 2. NewFriendsCountManager 的 didSet 会自动同步更新 badge
        // 3. 如果有未读的好友申请，badge 应该显示正确的数字
    }
    
    @objc private func applicationDidEnterBackground() {
        // 可以在这里处理后台推送逻辑
    }
    
    /**
     * 发送设备Token到LeanCloud
     */
    private func sendDeviceTokenToLeanCloud(token: String) {
        // 这里应该调用LeanCloud的API注册设备Token
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension LeanCloudWebSocketPushNotification: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // 应用在前台时显示通知
        completionHandler([.banner, .badge, .sound])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // 处理通知点击
        let userInfo = response.notification.request.content.userInfo
        handlePushNotificationClick(userInfo: userInfo)
        
        completionHandler()
    }
}

// MARK: - 通知名称扩展

extension Notification.Name {
    static let pushNotificationMessageClick = Notification.Name("pushNotificationMessageClick")
    static let pushNotificationConversationClick = Notification.Name("pushNotificationConversationClick")
}
