//
//  RemoteNotificationManager+RemoteNotificationHandling.swift
//  NeverSayNo
//
//  Created by AI Assistant on 2025-10-01.
//

import Foundation
import UIKit

extension RemoteNotificationManager {
    // MARK: - 远程推送通知处理
    
    /// 处理后台收到的远程推送通知
    /// 当应用在后台时收到推送通知，系统会调用此方法
    /// ⚠️ 重要：此方法只有在推送payload包含 "aps": {"content-available": 1} 时才会被调用
    func handleRemoteNotification(_ userInfo: [AnyHashable: Any], completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let currentTime = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.timeZone = TimeZone.current
        let _ = formatter.string(from: currentTime)
        
        
        // 详细检查推送数据格式
        if let aps = userInfo["aps"] as? [AnyHashable: Any] {
            if aps["content-available"] as? Int != nil {
            }
        } else {
        }
        
        // 解析推送数据
        // 优先从自定义字段获取messageType，如果没有则从aps的自定义字段获取
        var messageType: String?
        
        // 方法1：直接从userInfo获取
        if let type = userInfo["messageType"] as? String {
            messageType = type
        }
        
        // 方法2：从aps的自定义字段获取（LeanCloud可能把自定义数据放在aps外面）
        if messageType == nil {
            // 遍历所有非aps的键，查找messageType
            for (key, value) in userInfo {
                if let keyString = key as? String,
                   keyString.lowercased().contains("messagetype") || keyString == "messageType" {
                    messageType = value as? String
                    break
                }
            }
        }
        
        guard let messageType = messageType else {
            for (_, _) in userInfo {
            }
            completionHandler(.noData)
            return
        }
        
        
        // 根据消息类型处理
        switch messageType {
        case "pat":
            // 处理拍一拍消息
            if let senderName = userInfo["senderName"] as? String,
               let receiverName = userInfo["receiverName"] as? String,
               let messageId = userInfo["messageId"] as? String {
                NotificationManager.shared.sendPatMessageNotification(
                    from: senderName,
                    to: receiverName,
                    messageId: messageId
                )
                completionHandler(.newData)
            } else {
                completionHandler(.noData)
            }
            
        case "friend_request", "favorite":
            // 处理好友申请消息
            if let senderName = userInfo["senderName"] as? String,
               let messageId = userInfo["messageId"] as? String {
                NotificationManager.shared.sendFriendRequestNotification(
                    from: senderName,
                    messageId: messageId
                )
                completionHandler(.newData)
            } else {
                completionHandler(.noData)
            }
            
        default:
            completionHandler(.noData)
        }
    }
    
    func appStateString(_ state: UIApplication.State) -> String {
        switch state {
        case .active: return "前台活跃"
        case .inactive: return "前台非活跃"
        case .background: return "后台"
        @unknown default: return "未知"
        }
    }
}

