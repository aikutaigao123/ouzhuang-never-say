import Foundation
import SwiftUI
import UIKit
import UserNotifications

// 专门管理新朋友申请数量的管理器
class NewFriendsCountManager: ObservableObject {
    @Published var count: Int {
        didSet {
            // 🎯 修复：按userId隔离
            if let userId = UserDefaultsManager.getCurrentUserId() {
                UserDefaults.standard.set(count, forKey: "newFriendsCount_\(userId)")
            } else {
                UserDefaults.standard.set(count, forKey: "newFriendsCount")
            }
            
            // 🎯 新增：同步更新应用图标 badge 数字
            DispatchQueue.main.async {
                if #available(iOS 17.0, *) {
                    UNUserNotificationCenter.current().setBadgeCount(self.count)
                } else {
                    UIApplication.shared.applicationIconBadgeNumber = self.count
                }
            }
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
