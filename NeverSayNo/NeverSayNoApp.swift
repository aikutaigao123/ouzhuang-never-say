//
//  NeverSayNoApp.swift
//  NeverSayNo
//
//  Created by Die chen on 2025/7/1.
//  Copyright © 2025 NeverSayNo. All rights reserved.
//

import SwiftUI
import UserNotifications
import UIKit
import LeanCloud

@main
struct NeverSayNoApp: App {
    // 🔔 注册 AppDelegate 以接收推送通知回调
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var userManager = UserManager()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var diamondManager = DiamondManager.shared
    @StateObject private var iapManager = IAPManager()
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var remoteNotificationManager = RemoteNotificationManager.shared
    
    init() {
        // 🚀 初始化 LeanCloud SDK
        initializeLeanCloud()
        
        
        // 🔔 配置远程推送通知
        configureRemoteNotifications()
        
        // 🛡️ 设置全局异常处理
        setupGlobalErrorHandling()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(userManager)
                .environmentObject(locationManager)
                .environmentObject(diamondManager)
                .environmentObject(iapManager)
                .environmentObject(notificationManager)
                .environmentObject(remoteNotificationManager)
                .onAppear {
                    // 🔔 初始化通知管理器
                    setupNotificationManager()
                    // 监听应用生命周期通知
                    setupAppLifecycleObservers()
                }
        }
    }
    
    /// 设置应用生命周期监听器
    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            handleAppDidEnterBackground()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            handleAppWillEnterForeground()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            handleAppDidBecomeActive()
        }
    }
    
    /// 应用进入后台
    private func handleAppDidEnterBackground() {
        let currentUserId = UserDefaultsManager.getCurrentUserId()
        
        // 🔧 关键修复：在进入后台前，主动刷新Installation状态（从云端获取最新状态）
        // 这样可以确保频道订阅状态是最新的
        let installation = LCApplication.default.currentInstallation
        
        // 先尝试从云端刷新Installation状态
        installation.fetch { result in
            switch result {
            case .success:
                
                // 刷新后检查频道状态（支持多种类型：[String]、[LCValue]、LCArray）
                var channelsArray: [String]?
                if let channels = installation.channels?.value as? [String] {
                    channelsArray = channels
                } else if let channelsLCValueArray = installation.channels?.value as? [LCValue] {
                    // 从 [LCValue] 数组中提取 String 数组
                    channelsArray = channelsLCValueArray.compactMap { element in
                        if let string = element as? LCString {
                            return string.stringValue
                        }
                        return nil
                    }
                } else if let channelsLCArray = installation.channels?.value as? LCArray {
                    // 从 LCArray 中提取 String 数组
                    if let arrayValue = channelsLCArray.arrayValue {
                        channelsArray = arrayValue.compactMap { element in
                            if let string = element as? LCString {
                                return string.stringValue
                            }
                            return nil
                        }
                    }
                }
                
                if let channels = channelsArray {
                    
                    // 🔧 关键检查：如果用户已登录，确保Installation订阅了用户ID对应的频道
                    if let userId = currentUserId, !channels.contains(userId) {
                        
                        // 立即修复：重新订阅用户频道
                        RemoteNotificationManager.shared.refreshDeviceTokenAfterLogin()
                    } else {
                    }
                } else {
                    
                    // 🔧 关键修复：如果用户已登录，立即订阅用户频道
                    if currentUserId != nil {
                        RemoteNotificationManager.shared.refreshDeviceTokenAfterLogin()
                    }
                }
                
            case .failure:
                
                // 如果刷新失败，使用本地状态检查（支持多种类型：[String]、[LCValue]、LCArray）
                var localChannelsArray: [String]?
                if let channels = installation.channels?.value as? [String] {
                    localChannelsArray = channels
                } else if let channelsLCValueArray = installation.channels?.value as? [LCValue] {
                    // 从 [LCValue] 数组中提取 String 数组
                    localChannelsArray = channelsLCValueArray.compactMap { element in
                        if let string = element as? LCString {
                            return string.stringValue
                        }
                        return nil
                    }
                } else if let channelsLCArray = installation.channels?.value as? LCArray {
                    // 从 LCArray 中提取 String 数组
                    if let arrayValue = channelsLCArray.arrayValue {
                        localChannelsArray = arrayValue.compactMap { element in
                            if let string = element as? LCString {
                                return string.stringValue
                            }
                            return nil
                        }
                    }
                }
                
                if let channels = localChannelsArray {
                    
                    if let userId = currentUserId, !channels.contains(userId) {
                        RemoteNotificationManager.shared.refreshDeviceTokenAfterLogin()
                    } else {
                    }
                } else {
                    if currentUserId != nil {
                        RemoteNotificationManager.shared.refreshDeviceTokenAfterLogin()
                    }
                }
            }
        }
        
        
        // 🔧 重要提示：关于后台推送的配置
    }
    
    /// 应用即将进入前台
    private func handleAppWillEnterForeground() {
        // 检查设备令牌状态
        checkDeviceTokenStatus()
    }
    
    /// 应用变为活跃状态
    private func handleAppDidBecomeActive() {
        // 🎯 微信逻辑：进入应用时，清除 App 图标右上角的系统 badge
        // 但保留应用内的角标数字（NewFriendsCountManager.count），需要用户实际查看消息后才清零
        // 这样：
        // - App 图标角标：进入应用后清零（表示用户已经"看到"了应用）
        // - 应用内角标：需要用户实际查看好友申请后才清零（表示用户已经"处理"了消息）
        clearAppIconBadgeOnly()
        
        // 检查设备令牌状态
        checkDeviceTokenStatus()
        
        // 应用重新激活时，重新连接 WebSocket（如果需要）
        if userManager.isLoggedIn {
            // 确保 IM 连接正常
            if !userManager.isIMConnected {
                userManager.initializeIMTrigger()
            }
            
            // 🎯 新增：从后台恢复到前台时，上传登录记录
            userManager.uploadLoginRecordForForeground()
        }
    }
    
    /// 🎯 微信逻辑：只清除 App 图标右上角的系统 badge，不清除应用内的角标数字
    /// 这样 App 图标角标在进入应用后清零，但应用内的角标数字需要用户实际查看消息后才清零
    private func clearAppIconBadgeOnly() {
        // 只清除系统级别的 App 图标 badge
        if #available(iOS 17.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(0) { _ in
            }
        } else {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
        
        // 同步清除 LeanCloud Installation 的 badge
        let installation = LCApplication.default.currentInstallation
        installation.badge = 0
        installation.save { result in
        }
        
        // 🎯 注意：不清除 NewFriendsCountManager.count
        // NewFriendsCountManager.count 会在用户实际查看好友申请后，通过其他逻辑清零
        // 这样应用内的角标数字（如消息按钮右上角）会继续显示，直到用户实际查看消息
    }
    
    /// 清除 Badge（已废弃，badge 由 NewFriendsCountManager 统一管理）
    /// 根据 iOS 推送指南：在打开应用时将 badge 数目清零
    /// 🎯 注意：此方法已不再使用，badge 由 NewFriendsCountManager 统一管理
    private func clearBadge() {
        // 本地清空角标
        if #available(iOS 17.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
        } else {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
        
        // currentInstallation 的角标清零
        let installation = LCApplication.default.currentInstallation
        installation.badge = 0
        installation.save { result in
            switch result {
            case .success:
                break
            case .failure:
                break
            }
        }
    }
    
    /// 检查设备令牌状态
    private func checkDeviceTokenStatus() {
        let hasToken = RemoteNotificationManager.shared.deviceToken != nil
        
        if !hasToken {
            // 延迟重试注册（避免频繁调用）
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } else {
            // 如果设备令牌已存在但用户已登录，确保关联到用户
            if userManager.isLoggedIn {
                RemoteNotificationManager.shared.refreshDeviceTokenAfterLogin()
            }
        }
    }
    
    /// 设置通知管理器
    private func setupNotificationManager() {
        
        // 设置通知中心代理
        UNUserNotificationCenter.current().delegate = notificationManager
        
        // 配置远程推送通知
        remoteNotificationManager.configurePushNotifications()
        
        // 只检查权限状态，不主动请求（避免弹窗）
        // 权限请求将在用户实际使用通知功能时触发
        notificationManager.checkNotificationPermission()
        
    }
    
    /// 配置远程推送通知
    private func configureRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }
    
    /// 初始化 LeanCloud SDK
    private func initializeLeanCloud() {
        do {
            // 获取配置
            let config = Configuration.shared
            
            // 验证配置
            guard config.isValid else {
                return
            }
            
            // 关闭调试日志
            LCApplication.logLevel = .off
            
            // 初始化 LeanCloud SDK
            try LCApplication.default.set(
                id: config.leanCloudAppId,
                key: config.leanCloudAppKey,
                serverURL: config.leanCloudServerUrl
            )
            
            
        } catch {
        }
    }
    
    /// 设置全局异常处理
    private func setupGlobalErrorHandling() {
        // 设置 NSSetUncaughtExceptionHandler
        NSSetUncaughtExceptionHandler { exception in
            for (_, _) in exception.callStackSymbols.enumerated() {
            }
        }
        
        // 设置信号处理
        signal(SIGABRT) { _ in
        }
        
        signal(SIGILL) { _ in
        }
        
        signal(SIGSEGV) { _ in
        }
        
        signal(SIGFPE) { _ in
        }
        
        signal(SIGBUS) { _ in
        }
        
        signal(SIGPIPE) { _ in
        }
    }
}

