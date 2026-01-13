import SwiftUI
import Foundation

struct UIHelpers {
    // 获取系统主题颜色
    static func getSystemThemeColor() -> Color {
        return Color.primary
    }
    
    // 获取安全区域边距
    static func getSafeAreaInsets() -> EdgeInsets {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            let insets = window.safeAreaInsets
            return EdgeInsets(top: insets.top, leading: insets.left, bottom: insets.bottom, trailing: insets.right)
        }
        return EdgeInsets()
    }
    
    // 检查是否为深色模式
    static func isDarkMode() -> Bool {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return window.traitCollection.userInterfaceStyle == .dark
        }
        return false
    }
    
    // 获取屏幕尺寸
    static func getScreenSize() -> CGSize {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return window.bounds.size
        }
        return UIScreen.main.bounds.size
    }
    
    // 检查是否为iPad
    static func isiPad() -> Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
    
    // 检查是否为iPhone
    static func isiPhone() -> Bool {
        return UIDevice.current.userInterfaceIdiom == .phone
    }
    
    // 获取设备型号
    static func getDeviceModel() -> String {
        return UIDevice.current.model
    }
    
    // 获取系统版本
    static func getSystemVersion() -> String {
        return UIDevice.current.systemVersion
    }
    
    // 检查是否支持触控ID
    static func isTouchIDSupported() -> Bool {
        return false // 简化实现，避免复杂的生物识别API
    }
    
    // 检查是否支持面容ID
    static func isFaceIDSupported() -> Bool {
        return false // 简化实现，避免复杂的生物识别API
    }
    
    // 获取状态栏高度
    static func getStatusBarHeight() -> CGFloat {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return window.safeAreaInsets.top
        }
        return 0
    }
    
    // 获取导航栏高度
    static func getNavigationBarHeight() -> CGFloat {
        return 44.0 // 标准导航栏高度
    }
    
    // 获取标签栏高度
    static func getTabBarHeight() -> CGFloat {
        return 49.0 // 标准标签栏高度
    }
}
