//
//  RemoteNotificationManager.swift
//  NeverSayNo
//
//  Created by AI Assistant on 2025-10-01.
//

import Foundation
import UIKit
import UserNotifications
import LeanCloud

/// 远程推送通知管理器
class RemoteNotificationManager: NSObject, ObservableObject {
    static let shared = RemoteNotificationManager()
    
    @Published var deviceToken: String?
    @Published var isRegisteredForRemoteNotifications = false
    
    // 设备令牌刷新重试次数（避免无限重试）
    var refreshRetryCount = 0
    let maxRefreshRetries = 3
    
    // 设备令牌注册超时检查
    var registrationTimer: Timer?
    var callbackCheckTimer: Timer?
    var registrationStartTime: Date?
    
    // 🔧 防止重复处理设备令牌
    var lastProcessedToken: String?
    var isSavingInstallation = false
    
    // 🔧 防止频道订阅验证失败时的无限循环重试
    var channelSubscriptionRetryCount = 0
    let maxChannelSubscriptionRetries = 2
    
    private override init() {
        super.init()
    }
    
    // 检查是否在模拟器上运行
    var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
}
