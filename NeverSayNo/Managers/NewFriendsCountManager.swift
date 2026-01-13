import Foundation
import SwiftUI
import UIKit
import UserNotifications

// 专门管理新朋友申请数量的管理器
class NewFriendsCountManager: ObservableObject {
    // 🎯 新增：全局单例，用于在收到推送时同步更新 count
    static let shared = NewFriendsCountManager()
    
    @Published var count: Int {
        didSet {
            // 🎯 修复：按userId隔离
            if let userId = UserDefaultsManager.getCurrentUserId() {
                UserDefaults.standard.set(count, forKey: "newFriendsCount_\(userId)")
            } else {
                UserDefaults.standard.set(count, forKey: "newFriendsCount")
            }
            
            // 🎯 微信逻辑：NewFriendsCountManager.count 只用于应用内的角标数字（如消息按钮右上角）
            // App 图标右上角的系统 badge 在进入应用时会被清零（在 NeverSayNoApp.handleAppDidBecomeActive 中）
            // 这样：
            // - App 图标角标：进入应用后清零（表示用户已经"看到"了应用）
            // - 应用内角标：需要用户实际查看好友申请后才清零（表示用户已经"处理"了消息）
            
            // 🎯 注意：这里不再自动同步更新 App 图标的系统 badge
            // App 图标的系统 badge 会在进入应用时被清零（微信逻辑）
            // 应用内的角标数字（如消息按钮右上角）会继续使用这个 count
            // 如果需要更新 App 图标 badge，应该在特定场景下调用（如收到新推送时）
        }
    }
    
    init() {
        // 🎯 修复：按userId隔离
        if let userId = UserDefaultsManager.getCurrentUserId() {
            self.count = UserDefaults.standard.integer(forKey: "newFriendsCount_\(userId)")
        } else {
            self.count = UserDefaults.standard.integer(forKey: "newFriendsCount")
        }
    }
    
    func updateCount(_ newCount: Int) {
        self.count = newCount
    }
    
    // 🎯 新增：增加 count（用于收到推送时同步增加）
    func incrementCount() {
        self.count = self.count + 1
    }

    private func getCallerInfo() -> String {
        let symbols = Thread.callStackSymbols
        for symbol in symbols {
            if symbol.contains("NeverSayNo") && !symbol.contains("NewFriendsCountManager") {
                // 解析符号获取文件名和行号
                let components = symbol.split(separator: " ")
                if components.count >= 4 {
                    let functionInfo = String(components[3])
                    if functionInfo.contains(".") {
                        let parts = functionInfo.split(separator: ".")
                        if parts.count >= 2 {
                            let fileAndLine = parts[0].split(separator: ":")
                            if fileAndLine.count >= 2 {
                                return "\(fileAndLine[0]):\(fileAndLine[1])"
                            }
                        }
                    }
                }
                return String(symbol.split(separator: " ")[3])
            }
        }
        return "未知"
    }
}
