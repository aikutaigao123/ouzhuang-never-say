import SwiftUI

// 搜索界面共享的 UI 组件
struct SearchUIComponents {
    
    // 消耗钻石说明
    static func diamondCostHint() -> some View {
        Text("💡 寻找消耗 2 钻石")
            .font(.caption2)
            .foregroundColor(.gray)
            .padding(.top, 5)
    }
    
    // 位置状态提示
    static func locationStatusHint() -> some View {
        HStack {
            Image(systemName: "location.slash")
                .foregroundColor(.orange)
                .font(.caption)
            Text("正在获取位置信息...")
                .font(.caption)
                .foregroundColor(.orange)
        }
        .padding(.top, 8)
    }
    
    // 倒计时显示
    static func timeRemainingHint(_ timeRemaining: String) -> some View {
        HStack {
            Image(systemName: "clock")
                .foregroundColor(.orange)
            Text("剩余时间: \(timeRemaining)")
                .font(.caption)
                .foregroundColor(.orange)
                .fontWeight(.medium)
        }
        .padding(.top, 8)
    }
}

// 搜索界面共享的 Sheet 展示逻辑
struct SearchSheetManager {
    @Binding var showRechargeSheet: Bool
    @Binding var showMessageSheet: Bool
    @Binding var showProfileSheet: Bool
    @Binding var showAvatarZoom: Bool
    @Binding var unreadMessageCount: Int
    let userManager: UserManager
    let diamondManager: DiamondManager
    
    var rechargeSheet: some View {
        RechargeView(diamondManager: diamondManager)
    }
    
    var messageSheet: some View {
        MessageView(
            unreadCount: $unreadMessageCount, 
            newFriendsCountManager: NewFriendsCountManager(),
            userManager: userManager,
            stateManager: StateManager.shared,
            onMessageTap: { message in
                // 消息处理逻辑
            },
            isUserFavorited: { _ in false }, // 默认未收藏
            onToggleFavorite: { _, _, _, _, _, _ in }, // 空实现
            onRemoveFavorite: { _ in }, // 空实现
            isUserLiked: { _ in false }, // 默认未点赞
            onToggleLike: { _, _, _, _, _, _ in }, // 空实现
            isUserFavoritedByMe: { _ in false }, // 默认未匹配
            favoriteRecords: .constant([]), // 空数组
            onMessagesUpdated: {
                // 空实现，SearchUIComponents中不需要匹配状态检测
            },
            onPat: { _ in
                // 空实现，SearchUIComponents中不需要拍一拍功能
            },
            onUnfriend: { _ in
                // 空实现，SearchUIComponents中不需要解除好友功能
            },
            showBottomTabBar: true, // 从搜索界面进入，显示底部按钮
            showFriendsList: true, // 搜索界面显示我的好友列表
            existingMessages: .constant([]), // 空消息数组
            existingFriends: .constant([]), // 空好友数组
            existingPatMessages: .constant([]), // 空拍一拍消息数组
            existingAvatarCache: .constant([:]), // 空头像缓存
            existingUserNameCache: .constant([:]) // 空用户名缓存
        )
    }
    
    var profileSheet: some View {
        ProfileView(
            userManager: userManager,
            diamondManager: diamondManager,
            showLogoutAlert: .constant(false),
            showRechargeSheet: $showRechargeSheet,
            newUserName: .constant(""),
            isUserBlacklisted: false,
            onClearAllHistory: {},
            onShowHistory: {},
            newFriendsCountManager: NewFriendsCountManager(),
            onNavigateToTab: { _ in },
            showBottomTabBar: true
        )
    }
}
