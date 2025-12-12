//
//  AppDelegate.swift
//  NeverSayNo
//
//  Created by AI Assistant on 2025-11-05.
//

import UIKit
import UserNotifications

/// AppDelegate 用于处理推送通知回调
/// 在 SwiftUI App 中，需要使用 @UIApplicationDelegateAdaptor 来注册
class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ application: UIApplication, 
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }
    
    /// 处理远程推送通知的设备令牌
    /// 这是系统回调，必须通过 UIApplicationDelegate 实现
    func application(_ application: UIApplication, 
                    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        let _ = Date()
        
        // 验证设备令牌格式
        if deviceToken.count == 32 {
        } else {
        }
        
        if tokenString.count == 64 {
        } else {
        }
        
        // 检查是否在后台
        if application.applicationState == .background {
        }
        
        RemoteNotificationManager.shared.handleDeviceToken(deviceToken)
    }
    
    /// 处理远程推送通知注册失败
    /// 这是系统回调，必须通过 UIApplicationDelegate 实现
    func application(_ application: UIApplication, 
                    didFailToRegisterForRemoteNotificationsWithError error: Error) {
        let _ = Date()
        
        // 检查错误类型
        if let nsError = error as NSError? {
            
            // 常见错误码分析
            switch nsError.code {
            case 3010:
                break
            case 3000:
                break
            case 3001:
                break
            case 3002:
                break
            case 3003:
                break
            default:
                break
            }
        }
        
        // 检查是否在模拟器上运行
        #if targetEnvironment(simulator)
        #else
        #endif
        
        RemoteNotificationManager.shared.handleRegistrationFailure(error)
    }
    
    /// 处理后台收到的远程推送通知
    /// 当应用在后台时收到推送通知，系统会调用此方法
    /// ⚠️ 重要：此方法只有在推送payload包含 "aps": {"content-available": 1} 时才会被调用
    func application(_ application: UIApplication, 
                    didReceiveRemoteNotification userInfo: [AnyHashable: Any], 
                    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let _ = application.applicationState
        
        
        // 详细打印推送数据
        if userInfo["aps"] as? [AnyHashable: Any] != nil {
        } else {
        }
        
        // 打印自定义数据
        for (key, _) in userInfo {
            if key as? String != "aps" {
            }
        }
        
        // 检查是否有content-available字段
        if let aps = userInfo["aps"] as? [AnyHashable: Any],
           let contentAvailable = aps["content-available"] as? Int,
           contentAvailable == 1 {
        } else {
        }
        
        RemoteNotificationManager.shared.handleRemoteNotification(userInfo, completionHandler: completionHandler)
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

