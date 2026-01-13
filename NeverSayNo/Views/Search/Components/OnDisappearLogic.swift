import SwiftUI
import Foundation

struct OnDisappearLogic: ViewModifier {
    let locationManager: LocationManager
    let stopCountdownTimer: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onDisappear {
                // 离开页面时停止方向更新
                locationManager.stopHeadingUpdates()
                // 停止倒计时定时器
                stopCountdownTimer()
                // 移除通知监听器
                NotificationCenter.default.removeObserver(self, name: NSNotification.Name("ShowLatestMatch"), object: nil)
                NotificationCenter.default.removeObserver(self, name: NSNotification.Name("ShowFriendLocation"), object: nil)
                NotificationCenter.default.removeObserver(self, name: NSNotification.Name("DismissProfileSheet"), object: nil)
                NotificationCenter.default.removeObserver(self, name: NSNotification.Name("PatMessageReceived"), object: nil)
            }
    }
}
