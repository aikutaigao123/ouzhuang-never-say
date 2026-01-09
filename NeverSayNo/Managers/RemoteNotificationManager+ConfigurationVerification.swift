//
//  RemoteNotificationManager+ConfigurationVerification.swift
//  NeverSayNo
//
//  Created by AI Assistant on 2025-10-01.
//

import Foundation
import UIKit
import UserNotifications

extension RemoteNotificationManager {
    // MARK: - 配置验证
    
    /// 验证配置
    func verifyConfiguration() {
        
        // 1. 检查 Bundle ID
        if let bundleId = Bundle.main.bundleIdentifier {
            if bundleId != "com.yonderspace-cd.NeverSayNo.app" {
            }
        } else {
        }
        
        // 2. 检查 Entitlements 文件（源码文件）
        let entitlementsFile = Bundle.main.path(forResource: "NeverSayNo", ofType: "entitlements")
        if let entitlementsPath = entitlementsFile,
           let entitlementsData = NSDictionary(contentsOfFile: entitlementsPath) {
            if entitlementsData["aps-environment"] as? String != nil {
            }
        } else {
            // 检查源码文件
            if Bundle.main.path(forResource: "NeverSayNo", ofType: "entitlements", inDirectory: nil, forLocalization: nil) != nil {
            }
        }
        
        // 3. 检查代码签名中的 Entitlements（运行时验证）
        checkCodeSigningEntitlements()
        
        // 4. 检查通知权限
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let status = settings.authorizationStatus
            switch status {
            case .authorized:
                break
            case .denied:
                break
            case .notDetermined:
                break
            case .provisional:
                break
            case .ephemeral:
                break
            @unknown default:
                break
            }
        }
        
        // 5. 检查 Xcode 项目配置
        
        // 6. 检查 Provisioning Profile 信息
        checkProvisioningProfile()
        
    }
    
    /// 检查代码签名中的 Entitlements
    func checkCodeSigningEntitlements() {
        
        // 通过 SecTaskCopySigningIdentifier 或其他方式检查
        // 由于 iOS 安全限制，我们无法直接读取代码签名中的 entitlements
        // 但可以通过尝试注册推送来验证
        
    }
    
    /// 检查 Provisioning Profile 信息
    func checkProvisioningProfile() {
        
        // 检查 Bundle 信息
        if let infoDict = Bundle.main.infoDictionary {
            if let teamId = infoDict["TeamIdentifierPrefix"] as? String {
                if teamId != "9K87XT45CQ" {
                }
            } else {
            }
            
            if infoDict["CFBundleIdentifier"] as? String != nil {
            }
            
            // 检查更多签名相关信息
            if infoDict["CFBundleVersion"] as? String != nil {
            }
            if infoDict["CFBundleShortVersionString"] as? String != nil {
            }
        }
        
        // 检查 Provisioning Profile 路径（如果可访问）
        if let profilePath = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") {
            
            // 尝试读取 Provisioning Profile 内容（如果可能）
            if let profileData = try? Data(contentsOf: URL(fileURLWithPath: profilePath)) {
                // Provisioning Profile 是二进制格式，但我们可以尝试解析
                
                // 尝试多种编码方式解析
                
                // mobileprovision 文件实际上是 PKCS#7 格式，包含一个 plist
                // 尝试查找 XML plist 的开始标记（通常是 <?xml 或 <plist）
                // 检查前1000字节，看是否能找到 XML 标记
                let previewSize = min(1000, profileData.count)
                let previewData = profileData.prefix(previewSize)
                
                if let previewString = String(data: previewData, encoding: .utf8) ?? String(data: previewData, encoding: .ascii) {
                    let _ = previewString.contains("<?xml")
                    let _ = previewString.contains("<plist")
                    
                    // 尝试查找 aps-environment 关键词（即使无法完整解析）
                    let hasApsInPreview = previewString.contains("aps-environment") || previewString.contains("aps") || previewString.lowercased().contains("push")
                    
                    if hasApsInPreview {
                    }
                }
                
                // 尝试在整个文件中查找关键词（即使无法完整解析）
                if let fullString = String(data: profileData, encoding: .utf8) ?? String(data: profileData, encoding: .ascii) {
                    
                    // 检查是否包含 Push Notifications 相关关键词
                    let hasApsEnvironment = fullString.contains("aps-environment")
                    let hasPush = fullString.contains("Push") || fullString.contains("push")
                    let hasAps = fullString.contains("aps")
                    
                    
                    if hasApsEnvironment || hasPush || hasAps {
                        
                        // 尝试提取 aps-environment 的值
                        if let apsRange = fullString.range(of: "aps-environment") {
                            let startIndex = fullString.index(apsRange.upperBound, offsetBy: 0)
                            let endIndex = fullString.index(startIndex, offsetBy: min(200, fullString.distance(from: startIndex, to: fullString.endIndex)))
                            let _ = String(fullString[startIndex..<endIndex])
                        }
                    } else {
                    }
                    
                    // 检查是否包含 App ID
                    let hasCorrectBundleId = fullString.contains("com.yonderspace-cd.NeverSayNo.app")
                    if hasCorrectBundleId {
                    } else {
                    }
                    
                    // 检查是否包含 Team ID
                    let hasCorrectTeamId = fullString.contains("9K87XT45CQ")
                    if hasCorrectTeamId {
                    } else {
                    }
                    
                    // 检查 Provisioning Profile 类型
                    let isDevelopment = fullString.contains("Development") || fullString.contains("development")
                    let _ = fullString.contains("Distribution") || fullString.contains("distribution")
                    let _ = fullString.contains("AdHoc") || fullString.contains("adhoc")
                    let _ = fullString.contains("AppStore") || fullString.contains("appstore")
                    
                    
                    if isDevelopment {
                    }
                } else {
                    
                    // 尝试使用 Security framework 解析（如果可能）
                    
                    // 尝试查找 plist 的开始和结束位置（通过查找 <plist> 和 </plist>）
                    // 由于是 PKCS#7 格式，plist 通常被包裹在签名中
                    // 我们可以尝试查找二进制数据中的特定模式
                    
                    // 检查是否包含常见的 plist 标记（作为二进制数据）
                    let plistStartMarker = Data("<?xml".utf8)
                    let plistPlistMarker = Data("<plist".utf8)
                    
                    if profileData.range(of: plistStartMarker) != nil {
                    }
                    if profileData.range(of: plistPlistMarker) != nil {
                    }
                    
                    // 尝试查找 aps-environment 作为二进制数据
                    let apsEnvironmentMarker = Data("aps-environment".utf8)
                    if profileData.range(of: apsEnvironmentMarker) != nil {
                    } else {
                    }
                    
                    // 尝试查找 Bundle ID
                    let bundleIdMarker = Data("com.yonderspace-cd.NeverSayNo.app".utf8)
                    if profileData.range(of: bundleIdMarker) != nil {
                    } else {
                    }
                    
                    // 尝试查找 Team ID
                    let teamIdMarker = Data("9K87XT45CQ".utf8)
                    if profileData.range(of: teamIdMarker) != nil {
                    } else {
                    }
                    
                }
            } else {
            }
            
        } else {
        }
    }
    
    /// 检查代码签名状态
    func checkCodeSigningStatus() {
        
        // 检查 Bundle 的签名信息
        if Bundle.main.infoDictionary?["CFBundleSignature"] as? String != nil {
        }
        
        // 检查是否可以获取代码签名信息
        if let executablePath = Bundle.main.executablePath {
            
            // 检查文件是否存在
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: executablePath) {
                
                // 获取文件属性
                if let attributes = try? fileManager.attributesOfItem(atPath: executablePath) {
                    if attributes[.size] as? Int64 != nil {
                    }
                }
            } else {
            }
        }
        
        // 检查应用状态
        let appState = UIApplication.shared.applicationState
        switch appState {
        case .active:
            break
        case .inactive:
            break
        case .background:
            break
        @unknown default:
            break
        }
        
    }
}

