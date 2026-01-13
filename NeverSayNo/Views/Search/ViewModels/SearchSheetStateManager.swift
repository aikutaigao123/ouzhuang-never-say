import SwiftUI

// 统一的搜索界面 Sheet 状态管理
class SearchSheetStateManager: ObservableObject {
    @Published var showRechargeSheet = false
    @Published var showMessageSheet = false
    @Published var showProfileSheet = false
    @Published var showAvatarZoom = false
    @Published var unreadMessageCount = 0
    
    private let userManager: UserManager
    private let diamondManager: DiamondManager
    
    init(userManager: UserManager, diamondManager: DiamondManager) {
        self.userManager = userManager
        self.diamondManager = diamondManager
    }
    
    // 显示充值界面
    func showRecharge() {
        showRechargeSheet = true
    }
    
    // 显示消息界面
    func showMessages() {
        showMessageSheet = true
    }
    
    // 显示个人资料界面
    func showProfile() {
        showProfileSheet = true
    }
    
    // 显示头像缩放界面
    func showAvatarZoomView() {
        showAvatarZoom = true
    }
    
    // 检查钻石并显示充值界面（如果需要）
    func checkDiamondsAndShowRechargeIfNeeded(_ amount: Int) -> Bool {
        if diamondManager.checkDiamondsWithDebug(amount) {
            return true
        } else {
            showRechargeSheet = true
            return false
        }
    }
    
    // 充值界面
    var rechargeSheet: some View {
        RechargeView(diamondManager: diamondManager)
    }
    
    // 消息界面
    var messageSheet: some View {
        MessageView(
            unreadCount: .constant(unreadMessageCount), 
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
                // 空实现，SearchSheetStateManager中不需要匹配状态检测
            },
            onPat: { _ in
                // 空实现，SearchSheetStateManager中不需要拍一拍功能
            },
            onUnfriend: { _ in
                // 空实现，SearchSheetStateManager中不需要解除好友功能
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
    
    // 个人资料界面
    var profileSheet: some View {
        ProfileView(
            userManager: userManager,
            diamondManager: diamondManager,
            showLogoutAlert: .constant(false),
            showRechargeSheet: .constant(showRechargeSheet),
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
