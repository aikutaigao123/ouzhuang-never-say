import SwiftUI

// 首页Tab - 原来的搜索界面
struct HomeTabView: View {
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var userManager: UserManager
    @ObservedObject var stateManager: StateManager
    @Binding var unreadMessageCount: Int
    @ObservedObject var newFriendsCountManager: NewFriendsCountManager
    
    var body: some View {
        LegacySearchView(
            locationManager: locationManager,
            userManager: userManager,
            stateManager: stateManager,
            unreadMessageCount: $unreadMessageCount,
            newFriendsCountManager: newFriendsCountManager,
            onBack: {
                // 在TabView中不需要退出功能
            }
        )
    }
}
