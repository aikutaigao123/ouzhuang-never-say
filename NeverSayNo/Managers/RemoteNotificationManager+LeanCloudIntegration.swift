//
//  RemoteNotificationManager+LeanCloudIntegration.swift
//  NeverSayNo
//
//  Created by AI Assistant on 2025-10-01.
//

import Foundation
import LeanCloud

extension RemoteNotificationManager {
    // MARK: - LeanCloud集成
    
    /// 将设备令牌发送到LeanCloud服务器
    /// 🔧 重要：根据iOS推送指南，必须使用默认Installation对象
    /// SDK即时通讯模块会使用默认Installation对象的device token
    /// 🔧 根据即时通讯指南第2245行：SDK会自动关联clientId和设备数据
    /// 关联方式是通过让目标设备订阅名为clientId的Channel
    func sendDeviceTokenToLeanCloud(deviceToken: Data, tokenString: String) {
        let installation = LCApplication.default.currentInstallation
        let currentUserId = UserDefaultsManager.getCurrentUserId()
        let teamId = "9K87XT45CQ"
        
        // 检查 LeanCloud 配置
        let config = Configuration.shared
        
        // 检查 LCApplication 的配置
        if let appId = LCApplication.default.id {
            if appId == config.leanCloudAppId {
            } else {
            }
        } else {
        }
        
        
        
        // 设置deviceToken和apnsTeamId（iOS推送指南第116-129行）
        installation.set(deviceToken: deviceToken, apnsTeamId: teamId)
        
        // 🔧 如果用户已登录，订阅名为clientId的频道（即时通讯指南第2245行）
        // 这样当IM消息发送时，云端才能根据clientId找到对应的设备进行推送
        if let userId = currentUserId {
            // 🔧 关键调试：检查当前 channels 状态
            if let arrayValue = installation.channels?.arrayValue {
                let _ = arrayValue.compactMap { ($0 as? LCString)?.stringValue }
            }
            
            do {
                try installation.append("channels", element: userId, unique: true)
                
                // 🔧 检查 append 后状态
                if let arrayValue = installation.channels?.arrayValue {
                    let _ = arrayValue.compactMap { ($0 as? LCString)?.stringValue }
                }
            } catch {
                // 🔧 如果 append 失败，尝试使用 set 方法
                do {
                    try installation.set("channels", value: LCArray([LCString(userId)]))
                } catch {
                    // 继续保存，即使频道订阅失败
                }
            }
        } else {
        }
        
        // 🔧 如果正在保存，延迟执行以避免并发保存
        if isSavingInstallation {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.sendDeviceTokenToLeanCloud(deviceToken: deviceToken, tokenString: tokenString)
            }
            return
        }
        
        // 标记正在保存
        isSavingInstallation = true
        
        // 保存Installation（iOS推送指南第121行）
        installation.save { [weak self] result in
            guard let self = self else { return }
            self.isSavingInstallation = false
            
            switch result {
            case .success:
                // 打印Installation信息
                if installation.channels?.value as? [String] != nil {
                }
                if installation.deviceType?.value != nil {
                }
            case .failure(let error):
                let _ = error.localizedDescription
                // 如果是 429 错误（请求过多），延迟后重试
                let lcError = error
                if lcError.code == 429 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                        self?.sendDeviceTokenToLeanCloud(deviceToken: deviceToken, tokenString: tokenString)
                    }
                }
            }
        }
    }
}

