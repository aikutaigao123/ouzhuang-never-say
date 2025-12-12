import SwiftUI
import Foundation

struct NotificationObservers: ViewModifier {
    @Binding var showProfileSheet: Bool
    @Binding var selectedTab: Int
    let onShowLatestMatch: (LocationRecord) -> Void
    let onShowFriendLocation: (LocationRecord) -> Void
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                setupNotificationObservers()
            }
    }
    
    private func setupNotificationObservers() {
        // 监听关闭个人信息界面的通知
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("DismissProfileSheet"),
            object: nil,
            queue: .main
        ) { _ in
            showProfileSheet = false
            // 同时切换到主界面（首页）
            selectedTab = 0
        }
        
        // 监听显示最新匹配的通知
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ShowLatestMatch"),
            object: nil,
            queue: .main
        ) { notification in
            if let record = notification.object as? LocationRecord {
                onShowLatestMatch(record)
            }
        }
        
        // 监听显示好友位置的通知
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ShowFriendLocation"),
            object: nil,
            queue: .main
        ) { notification in
            if let record = notification.object as? LocationRecord {
                onShowFriendLocation(record)
            }
        }
        
        // 监听导航到主界面的通知
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NavigateToMainTab"),
            object: nil,
            queue: .main
        ) { _ in
            // 切换到主界面（首页）
            selectedTab = 0
        }
    }
}
