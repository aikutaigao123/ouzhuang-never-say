import SwiftUI
import Foundation
import UIKit

struct DeviceHelpers {
    // 获取设备ID
    static func getDeviceId() -> String {
        return UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
    }
    
    // 获取短设备ID（前8位）
    static func getShortDeviceId() -> String {
        let deviceId = getDeviceId()
        return String(deviceId.prefix(8))
    }
    
    // 获取设备型号
    static func getDeviceModel() -> String {
        return UIDevice.current.model
    }
    
    // 获取设备名称
    static func getDeviceName() -> String {
        return UIDevice.current.name
    }
    
    // 获取系统版本
    static func getSystemVersion() -> String {
        return UIDevice.current.systemVersion
    }
    
    // 检查是否为iPad
    static func isiPad() -> Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
    
    // 检查是否为iPhone
    static func isiPhone() -> Bool {
        return UIDevice.current.userInterfaceIdiom == .phone
    }
    
    // 检查是否为Mac（通过Catalyst）
    static func isMac() -> Bool {
        return UIDevice.current.userInterfaceIdiom == .mac
    }
    
    // 获取屏幕尺寸
    static func getScreenSize() -> CGSize {
        return UIScreen.main.bounds.size
    }
    
    // 获取屏幕比例
    static func getScreenScale() -> CGFloat {
        return UIScreen.main.scale
    }
    
    // 检查是否为Retina屏幕
    static func isRetinaScreen() -> Bool {
        return UIScreen.main.scale > 1.0
    }
    
    // 获取设备方向
    static func getDeviceOrientation() -> UIDeviceOrientation {
        return UIDevice.current.orientation
    }
    
    // 检查是否为竖屏
    static func isPortrait() -> Bool {
        return UIDevice.current.orientation.isPortrait
    }
    
    // 检查是否为横屏
    static func isLandscape() -> Bool {
        return UIDevice.current.orientation.isLandscape
    }
    
    // 获取电池电量
    static func getBatteryLevel() -> Float {
        UIDevice.current.isBatteryMonitoringEnabled = true
        return UIDevice.current.batteryLevel
    }
    
    // 检查是否正在充电
    static func isCharging() -> Bool {
        UIDevice.current.isBatteryMonitoringEnabled = true
        return UIDevice.current.batteryState == .charging
    }
    
    // 获取设备语言
    static func getDeviceLanguage() -> String {
        if #available(iOS 16.0, *) {
            return Locale.current.language.languageCode?.identifier ?? "en"
        } else {
            return Locale.current.languageCode ?? "en"
        }
    }
    
    // 获取设备地区
    static func getDeviceRegion() -> String {
        if #available(iOS 16.0, *) {
            return Locale.current.region?.identifier ?? "US"
        } else {
            return Locale.current.regionCode ?? "US"
        }
    }
    
    // 检查是否为低电量模式
    static func isLowPowerMode() -> Bool {
        return ProcessInfo.processInfo.isLowPowerModeEnabled
    }
}
