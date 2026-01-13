//
//  NotificationManager.swift
//  NeverSayNo
//
//  Created by AI Assistant on 2025-09-30.
//

import Foundation
import UserNotifications
import UIKit

/// 通知管理器 - 处理拍一拍消息的推送通知
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isNotificationEnabled = false
    @Published var notificationCount = 0
    
    private override init() {
        super.init()
        checkNotificationPermission()
    }
    
    // MARK: - 权限管理
    
    /// 检查通知权限状态
    func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isNotificationEnabled = settings.authorizationStatus == .authorized
            }
        }
    }
    
    /// 请求通知权限
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.isNotificationEnabled = granted
                if granted {
                    // 注册远程推送通知
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                } else {
                }
            }
        }
    }
    
    // MARK: - 拍一拍消息推送
    
    /// 发送拍一拍消息通知
    func sendPatMessageNotification(from senderName: String, to receiverName: String, messageId: String) {
        // 如果没有权限，先请求权限
        guard isNotificationEnabled else {
            requestNotificationPermissionWithCompletion { granted in
                if granted {
                    // 权限已授予，继续发送通知
                    self.sendNotification(from: senderName, to: receiverName, messageId: messageId)
                }
            }
            return
        }
        
        sendNotification(from: senderName, to: receiverName, messageId: messageId)
    }
    
    private func appStateString(_ state: UIApplication.State) -> String {
        switch state {
        case .active: return "前台活跃"
        case .inactive: return "前台非活跃"
        case .background: return "后台"
        @unknown default: return "未知"
        }
    }
    
    /// 实际发送通知（私有方法，由 sendPatMessageNotification 调用）
    private func sendNotification(from senderName: String, to receiverName: String, messageId: String) {
        let content = UNMutableNotificationContent()
        content.title = "拍一拍消息"
        // 🎯 修改：系统弹窗通知显示"谁拍了拍你"的格式
        content.body = "\(senderName) 拍了拍你"
        content.sound = UNNotificationSound.default
        // 🎯 修复：拍一拍消息不应该设置 badge，badge 应该由 NewFriendsCountManager 统一管理（只用于好友申请）
        // content.badge 会在通知显示时自动使用当前的应用图标 badge 数字
        
        // 添加自定义数据
        content.userInfo = [
            "messageId": messageId,
            "messageType": "pat",
            "senderName": senderName,
            "receiverName": receiverName
        ]
        
        // 创建通知请求
        let request = UNNotificationRequest(
            identifier: "pat_message_\(messageId)",
            content: content,
            trigger: nil // 立即触发
        )
        
        // 发送通知
        UNUserNotificationCenter.current().add(request) { error in
            if error == nil {
                DispatchQueue.main.async {
                    self.notificationCount += 1
                }
            }
        }
    }
    
    /// 请求通知权限（带完成回调）
    private func requestNotificationPermissionWithCompletion(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.isNotificationEnabled = granted
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
                completion(granted)
            }
        }
    }
    
    /// 发送好友申请通知
    /// 🎯 新增：发送询问联系方式是否真实通知
    /// 🎯 新增：发送联系方式真实回复通知
    func sendContactInquiryReplyNotification(from senderName: String, messageId: String) {
        
        guard isNotificationEnabled else {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "收到回复"
        content.body = "\(senderName) 回复：我的联系方式是真实的"
        content.sound = UNNotificationSound.default
        
        content.userInfo = [
            "messageId": messageId,
            "messageType": "contact_inquiry_reply",
            "senderName": senderName,
            "senderId": "" // 🎯 新增：发送者ID（本地通知可能没有，需要通过 messageId 查询）
        ]
        
        let request = UNNotificationRequest(
            identifier: "contact_inquiry_reply_\(messageId)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if error != nil {
            } else {
            }
        }
    }
    
    func sendContactInquiryNotification(from senderName: String, messageId: String) {
        
        guard isNotificationEnabled else {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "收到询问"
        content.body = "\(senderName) 询问你的联系方式是否真实"
        content.sound = UNNotificationSound.default
        // 🎯 修复：不在这里设置 badge，badge 应该由统一管理
        
        content.userInfo = [
            "messageId": messageId,
            "messageType": "contact_inquiry",
            "senderName": senderName,
            "senderId": "" // 🎯 新增：发送者ID（本地通知可能没有，需要通过 messageId 查询）
        ]
        
        let request = UNNotificationRequest(
            identifier: "contact_inquiry_\(messageId)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if error != nil {
            } else {
            }
        }
    }
    
    func sendFriendRequestNotification(from senderName: String, messageId: String) {
        
        guard isNotificationEnabled else {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "好友申请"
        content.body = "\(senderName) 对你发送了好友申请"
        content.sound = UNNotificationSound.default
        // 🎯 修复：不在这里设置 badge，badge 应该由 NewFriendsCountManager 统一管理
        // content.badge 会在通知显示时自动使用当前的应用图标 badge 数字
        
        content.userInfo = [
            "messageId": messageId,
            "messageType": "friend_request",
            "senderName": senderName,
            "senderId": "" // 🎯 新增：发送者ID（本地通知可能没有，需要通过 messageId 查询）
        ]
        
        let request = UNNotificationRequest(
            identifier: "friend_request_\(messageId)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if error != nil {
            } else {
                DispatchQueue.main.async {
                    self.notificationCount += 1
                    // 🎯 方案2：发送好友申请通知时，同步增加 NewFriendsCountManager 的 count
                    // 这样推送的 badge: "Increment" 和本地 count 保持一致
                    NewFriendsCountManager.shared.incrementCount()
                }
            }
        }
    }
    
    // MARK: - 通知管理
    
    /// 清除所有通知
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        
        DispatchQueue.main.async {
            self.notificationCount = 0
            // 🎯 修复：不在这里清除 badge，badge 应该由 NewFriendsCountManager 统一管理
            // 发送通知让 NewFriendsCountManager 清除 badge
            NotificationCenter.default.post(name: NSNotification.Name("ClearAllNotifications"), object: nil)
        }
        
    }
    
    /// 清除特定类型的通知
    func clearNotifications(ofType messageType: String) {
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            let identifiersToRemove = notifications.compactMap { (notification: UNNotification) -> String? in
                guard let type = notification.request.content.userInfo["messageType"] as? String,
                      type == messageType else { return nil }
                return notification.request.identifier
            }
            
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiersToRemove)
        }
    }
    
    /// 更新应用角标数量
    func updateBadgeCount(_ count: Int) {
        DispatchQueue.main.async {
            if #available(iOS 17.0, *) {
                UNUserNotificationCenter.current().setBadgeCount(count)
            } else {
                UIApplication.shared.applicationIconBadgeNumber = count
            }
            self.notificationCount = count
        }
    }
    
    // MARK: - 远程推送通知处理
    
    /// 处理远程推送通知的设备令牌
    func handleRemoteNotificationToken(_ deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        
        
        // 这里应该将设备令牌发送到服务器（LeanCloud）
        // 以便服务器能够向此设备发送推送通知
        sendDeviceTokenToServer(token)
    }
    
    /// 处理远程推送通知失败
    func handleRemoteNotificationFailure(_ error: Error) {
    }
    
    /// 将设备令牌发送到服务器
    private func sendDeviceTokenToServer(_ token: String) {
        // TODO: 实现将设备令牌发送到LeanCloud服务器的逻辑
        // 这样服务器就能向此设备发送推送通知了
    }
    
    // MARK: - 后台处理
    
    /// 处理后台接收到的消息
    func handleBackgroundMessage(_ messageData: [String: Any]) {
        guard let messageType = messageData["messageType"] as? String else { return }
        
        switch messageType {
        case "pat":
            if let senderName = messageData["senderName"] as? String,
               let receiverName = messageData["receiverName"] as? String,
               let messageId = messageData["messageId"] as? String {
                sendPatMessageNotification(from: senderName, to: receiverName, messageId: messageId)
            }
            
        case "friend_request":
            if let senderName = messageData["senderName"] as? String,
               let messageId = messageData["messageId"] as? String {
                sendFriendRequestNotification(from: senderName, messageId: messageId)
            }
            
        case "contact_inquiry":
            if let senderName = messageData["senderName"] as? String,
               let messageId = messageData["messageId"] as? String {
                sendContactInquiryNotification(from: senderName, messageId: messageId)
            }
            
        case "contact_inquiry_reply":
            if let senderName = messageData["senderName"] as? String,
               let messageId = messageData["messageId"] as? String {
                sendContactInquiryReplyNotification(from: senderName, messageId: messageId)
            }
            
        default:
            break
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    
    /// 应用在前台时收到通知
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // 即使应用在前台也显示通知
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .badge, .sound])
        } else {
            completionHandler([.alert, .badge, .sound])
        }
    }
    
    /// 用户点击通知时的处理
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        // 处理不同类型的通知点击
        if let messageType = userInfo["messageType"] as? String {
            switch messageType {
            case "pat":
                handlePatMessageNotificationTap(userInfo)
            case "friend_request":
                handleFriendRequestNotificationTap(userInfo)
            case "contact_inquiry":
                handleContactInquiryNotificationTap(userInfo)
            case "contact_inquiry_reply":
                handleContactInquiryReplyNotificationTap(userInfo)
            default:
                break
            }
        }
        
        completionHandler()
    }
    
    /// 处理拍一拍消息通知点击
    private func handlePatMessageNotificationTap(_ userInfo: [AnyHashable: Any]) {
        // 这里可以添加跳转到消息界面的逻辑
        // 例如：切换到消息标签页，显示拍一拍消息列表
    }
    
    /// 🎯 新增：处理联系方式真实回复通知点击
    private func handleContactInquiryReplyNotificationTap(_ userInfo: [AnyHashable: Any]) {
        
        // 从 userInfo 中提取发送者信息
        let senderName = userInfo["senderName"] as? String ?? "未知用户"
        let senderId = userInfo["senderId"] as? String ?? ""
        
        // 🎯 新增：发送通知到 ContentView，显示弹窗
        NotificationCenter.default.post(
            name: NSNotification.Name("ShowContactInquiryReplyAlertFromNotification"),
            object: nil,
            userInfo: ["senderName": senderName, "senderId": senderId]
        )
        
        // 🎯 新增：关闭所有窗口并导航到主页面
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // 关闭所有 sheet 和 modal
            NotificationCenter.default.post(name: NSNotification.Name("CloseAllSheets"), object: nil)
            
            // 导航到主页面
            NotificationCenter.default.post(name: NSNotification.Name("NavigateToMainTab"), object: nil)
        }
    }
    
    /// 处理询问联系方式是否真实通知点击
    private func handleContactInquiryNotificationTap(_ userInfo: [AnyHashable: Any]) {
        
        // 从 userInfo 中提取发送者信息
        let senderName = userInfo["senderName"] as? String ?? "未知用户"
        let senderId = userInfo["senderId"] as? String ?? ""
        
        // 🎯 新增：发送通知到 ContentView，显示弹窗
        NotificationCenter.default.post(
            name: NSNotification.Name("ShowContactInquiryAlertFromNotification"),
            object: nil,
            userInfo: ["senderName": senderName, "senderId": senderId]
        )
        
        // 🎯 新增：关闭所有窗口并导航到主页面
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // 关闭所有 sheet 和 modal
            NotificationCenter.default.post(name: NSNotification.Name("CloseAllSheets"), object: nil)
            
            // 导航到主页面
            NotificationCenter.default.post(name: NSNotification.Name("NavigateToMainTab"), object: nil)
        }
    }
    
    /// 处理好友申请通知点击
    private func handleFriendRequestNotificationTap(_ userInfo: [AnyHashable: Any]) {
        
        // 从 userInfo 中提取发送者信息
        let senderName = userInfo["senderName"] as? String ?? "未知用户"
        let senderId = userInfo["senderId"] as? String ?? ""
        let messageId = userInfo["messageId"] as? String ?? ""
        
        
        // 🎯 新增：发送通知到 ContentView，显示弹窗
        // 如果 senderId 为空，尝试从 messageId 或其他方式获取
        if senderId.isEmpty && !messageId.isEmpty {
            // 可以通过 messageId 查询对应的好友申请，获取 senderId
            FriendshipManager.shared.fetchFriendshipRequests { requests, _ in
                DispatchQueue.main.async {
                    if let requests = requests,
                       let request = requests.first(where: { $0.objectId == messageId }) {
                        let actualSenderId = request.user.id
                        let actualSenderName = request.user.fullName.isEmpty ? senderName : request.user.fullName
                        
                        // 发送通知显示弹窗
                        NotificationCenter.default.post(
                            name: NSNotification.Name("ShowFriendRequestAlertFromNotification"),
                            object: nil,
                            userInfo: ["senderName": actualSenderName, "senderId": actualSenderId]
                        )
                    } else {
                        // 即使找不到，也尝试显示弹窗
                        NotificationCenter.default.post(
                            name: NSNotification.Name("ShowFriendRequestAlertFromNotification"),
                            object: nil,
                            userInfo: ["senderName": senderName, "senderId": ""]
                        )
                    }
                }
            }
        } else {
            // 直接发送通知显示弹窗
            NotificationCenter.default.post(
                name: NSNotification.Name("ShowFriendRequestAlertFromNotification"),
                object: nil,
                userInfo: ["senderName": senderName, "senderId": senderId]
            )
        }
        
        // 🎯 新增：关闭所有窗口并导航到主页面
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // 关闭所有 sheet 和 modal
            NotificationCenter.default.post(name: NSNotification.Name("CloseAllSheetsAndNavigateToMain"), object: nil)
        }
        
    }
    
    // MARK: - 远程推送通知代理方法
    
    // 注意：userNotificationCenter(_:didReceive:withCompletionHandler:) 方法已在上面定义
}
