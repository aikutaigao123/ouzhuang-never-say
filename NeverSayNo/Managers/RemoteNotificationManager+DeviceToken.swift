//
//  RemoteNotificationManager+DeviceToken.swift
//  NeverSayNo
//
//  Created by AI Assistant on 2025-10-01.
//

import Foundation
import UIKit
import UserNotifications
import LeanCloud

extension RemoteNotificationManager {
    // MARK: - 设备令牌处理
    
    /// 处理远程推送通知的设备令牌
    /// 🔧 根据iOS推送指南：保存deviceToken到默认Installation对象
    func handleDeviceToken(_ deviceToken: Data) {
        // 停止超时检查
        stopRegistrationTimeoutCheck()
        
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        
        
        // 🔧 防止重复处理相同的设备令牌
        if let lastToken = lastProcessedToken, lastToken == token {
            return
        }
        
        // 记录已处理的令牌
        lastProcessedToken = token
        
        if registrationStartTime != nil { }
        
        DispatchQueue.main.async {
            self.deviceToken = token
            self.isRegisteredForRemoteNotifications = true
            
            // 🔧 如果用户已登录，延迟刷新设备令牌关联（避免与 sendDeviceTokenToLeanCloud 同时保存）
            // sendDeviceTokenToLeanCloud 会保存 Installation，refreshDeviceTokenAfterLogin 也会保存
            // 延迟执行可以避免同时保存导致 429 错误
            if UserDefaultsManager.getCurrentUserId() != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.refreshDeviceTokenAfterLogin()
                }
            }
        }
        
        // 🔧 根据iOS推送指南：使用默认Installation对象保存deviceToken
        // 传递原始Data格式，以便使用set(deviceToken:apnsTeamId:)方法
        sendDeviceTokenToLeanCloud(deviceToken: deviceToken, tokenString: token)
    }
    
    /// 在用户登录后重新发送设备令牌（确保关联到正确的用户）
    /// 🔧 根据即时通讯指南第2245行：SDK会自动关联clientId和设备数据
    /// 关联方式是通过让目标设备订阅名为clientId的Channel
    func refreshDeviceTokenAfterLogin() {
        guard let currentUserId = UserDefaultsManager.getCurrentUserId() else {
            return
        }
        
        // 🔧 如果正在保存 Installation，延迟执行以避免并发保存
        if isSavingInstallation {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.refreshDeviceTokenAfterLogin()
            }
            return
        }
        
        // 🔧 如果设备令牌为空，延迟重试（设备令牌可能还在获取中）
        guard deviceToken != nil else {
            if refreshRetryCount < maxRefreshRetries {
                refreshRetryCount += 1
                // 延迟重试，等待设备令牌获取
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.refreshDeviceTokenAfterLogin()
                }
            } else {
                refreshRetryCount = 0 // 重置计数器
            }
            return
        }
        
        // 设备令牌已获取，重置重试计数器
        refreshRetryCount = 0
        
        
        // 🔧 根据即时通讯指南：确保Installation订阅的频道名与IM客户端的clientId一致
        // 这样云端才能根据clientId找到对应的关联设备进行推送
        let installation = LCApplication.default.currentInstallation
        
        // 🔧 关键调试：先检查当前 channels 状态（统一使用 arrayValue）
        if let arrayValue = installation.channels?.arrayValue {
            let _ = arrayValue.compactMap { ($0 as? LCString)?.stringValue }
        }
        
        do {
            // 订阅名为clientId的频道（即时通讯指南第2245行）
            try installation.append("channels", element: currentUserId, unique: true)
            
            // 🔧 关键调试：检查 append 后 channels 状态（统一使用 arrayValue）
            if let arrayValue = installation.channels?.arrayValue {
                let _ = arrayValue.compactMap { ($0 as? LCString)?.stringValue }
            } else {
                // 尝试使用 set 方法直接设置 channels
                try? installation.set("channels", value: LCArray([LCString(currentUserId)]))
            }
            
            // 标记正在保存
            isSavingInstallation = true
            
            // 保存Installation（确保频道订阅生效）
            installation.save { [weak self] result in
                guard let self = self else { return }
                self.isSavingInstallation = false
                
                switch result {
                case .success:
                    
                    // 🔧 关键：保存成功后，立即从云端刷新Installation状态，验证channels是否真的保存成功
                    installation.fetch { fetchResult in
                        switch fetchResult {
                        case .success:
                            
                            // 🔧 支持多种类型：[String]、[LCValue]、LCArray
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
                                if channels.contains(currentUserId) {
                                    // 验证成功，重置计数器
                                    self.channelSubscriptionRetryCount = 0
                                } else {
                                    // 重新订阅
                                    self.channelSubscriptionRetryCount += 1
                                    if self.channelSubscriptionRetryCount <= self.maxChannelSubscriptionRetries {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                            self.refreshDeviceTokenAfterLogin()
                                        }
                                    } else {
                                        self.channelSubscriptionRetryCount = 0
                                    }
                                }
                            } else {
                                if installation.channels?.value != nil {
                                }
                                
                                // 🔧 防止无限循环：限制重试次数
                                self.channelSubscriptionRetryCount += 1
                                if self.channelSubscriptionRetryCount <= self.maxChannelSubscriptionRetries {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                        self.refreshDeviceTokenAfterLogin()
                                    }
                                } else {
                                    self.channelSubscriptionRetryCount = 0 // 重置计数器
                                }
                            }
                        case .failure:
                            // 即使刷新失败，也打印本地状态
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
                            if channelsArray != nil {
                            }
                        }
                    }
                    
                    // 打印本地状态（保存后立即打印）
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
                    if localChannelsArray != nil {
                    }
                    
                    // 打印设备令牌信息
                    if installation.deviceType?.value != nil {
                    }
                case .failure(let error):
                    let _ = error.localizedDescription
                    // 如果是 429 错误（请求过多），延迟后重试
                    let lcError = error
                    if lcError.code == 429 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                            self?.refreshDeviceTokenAfterLogin()
                        }
                    }
                }
            }
        } catch {
            isSavingInstallation = false
        }
    }
    
    /// 处理远程推送通知失败
    func handleRegistrationFailure(_ error: Error) {
        // 停止超时检查
        stopRegistrationTimeoutCheck()
        
        
        if registrationStartTime != nil { }
        
        DispatchQueue.main.async {
            self.isRegisteredForRemoteNotifications = false
        }
    }
}

