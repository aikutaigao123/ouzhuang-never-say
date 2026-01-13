//
//  RemoteNotificationManager+PushConfiguration.swift
//  NeverSayNo
//
//  Created by AI Assistant on 2025-10-01.
//

import Foundation
import UIKit
import UserNotifications

extension RemoteNotificationManager {
    // MARK: - 推送通知配置
    
    /// 配置推送通知
    /// 根据 iOS 推送指南：先检查权限状态，再决定是否注册
    func configurePushNotifications() {
        
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let authStatus = settings.authorizationStatus
            
            switch authStatus {
            case .authorized:
                // 已授权，直接注册远程推送通知
                
                // 检查运行环境
                let isSim = self.isSimulator
                
                if isSim {
                    return
                }
                
                
                DispatchQueue.main.async {
                    // 验证配置
                    self.verifyConfiguration()
                    
                    // 详细检查注册前的状态
                    
                    // 检查是否可以注册
                    let _ = UIApplication.shared.canOpenURL(URL(string: "https://")!)
                    
                    self.registrationStartTime = Date()
                    
                    // 调用注册
                    UIApplication.shared.registerForRemoteNotifications()
                    
                    // 验证调用是否成功
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        
                        // 检查代码签名状态
                        self.checkCodeSigningStatus()
                    }
                    
                    // 保存注册开始时间到局部变量，确保在闭包中能访问
                    let capturedStartTime = self.registrationStartTime ?? Date()
                    if self.registrationStartTime == nil {
                        self.registrationStartTime = capturedStartTime
                    }
                    
                    // 定期检查回调状态（每2秒检查一次，持续30秒）
                    var checkCount = 0
                    let maxChecks = 15
                    self.callbackCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
                        guard let self = self else {
                            timer.invalidate()
                            return
                        }
                        
                        // 🔧 如果设备令牌已经收到，提前停止定时器
                        if self.deviceToken != nil {
                            timer.invalidate()
                            self.callbackCheckTimer = nil
                            return
                        }
                        
                        checkCount += 1
                        
                        // 使用捕获的开始时间或当前实例的开始时间
                        let startTime = self.registrationStartTime ?? capturedStartTime
                        let _ = Date().timeIntervalSince(startTime)
                        
                        // 每5次检查，再次验证配置和状态
                        if checkCount % 5 == 0 {
                            
                            // 检查网络连接
                            self.checkNetworkConnectivity()
                            
                            // 检查设备时间
                            self.checkDeviceTime()
                            
                            // 检查应用生命周期
                            self.checkApplicationLifecycle()
                        }
                        
                        if checkCount >= maxChecks {
                            timer.invalidate()
                            self.callbackCheckTimer = nil
                            // 🔧 再次检查设备令牌，避免在最后时刻收到但还没检查到
                            if self.deviceToken != nil {
                                return
                            }
                            
                            // 最后再次检查配置
                            self.verifyConfiguration()
                            self.checkNetworkConnectivity()
                            self.checkDeviceTime()
                            self.checkApplicationLifecycle()
                        }
                    }
                    
                    // 保存定时器引用，以便在收到回调时取消
                    if let timer = self.callbackCheckTimer {
                        RunLoop.main.add(timer, forMode: .common)
                    }
                    
                    // 启动超时检查（30秒后检查是否收到回调）
                    self.startRegistrationTimeoutCheck()
                }
            case .notDetermined:
                // 未确定，请求权限
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                    if error != nil {
                        return
                    }
                    
                    if granted {
                        
                        // 检查运行环境
                        if self.isSimulator {
                            return
                        }
                        
                        DispatchQueue.main.async {
                            self.registrationStartTime = Date()
                            UIApplication.shared.registerForRemoteNotifications()
                            
                            // 启动超时检查（30秒后检查是否收到回调）
                            self.startRegistrationTimeoutCheck()
                        }
                    } else {
                    }
                }
            case .denied:
                break
            case .provisional:
                if self.isSimulator {
                    return
                }
                DispatchQueue.main.async {
                    self.registrationStartTime = Date()
                    UIApplication.shared.registerForRemoteNotifications()
                    self.startRegistrationTimeoutCheck()
                }
            case .ephemeral:
                if self.isSimulator {
                    return
                }
                DispatchQueue.main.async {
                    self.registrationStartTime = Date()
                    UIApplication.shared.registerForRemoteNotifications()
                    self.startRegistrationTimeoutCheck()
                }
            @unknown default:
                break
            }
        }
    }
    
    func authStatusString(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "未确定"
        case .denied: return "已拒绝"
        case .authorized: return "已授权"
        case .provisional: return "临时授权"
        case .ephemeral: return "临时授权"
        @unknown default: return "未知(\(status.rawValue))"
        }
    }
}

