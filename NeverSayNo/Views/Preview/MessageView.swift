import SwiftUI
import Combine

// 消息界面
struct MessageView: View {
    @Binding var unreadCount: Int
    @ObservedObject var newFriendsCountManager: NewFriendsCountManager
    let userManager: UserManager
    let stateManager: StateManager
    let onMessageTap: (MessageItem) -> Void
    let onUserSearchTap: ((UserInfo) -> Void)? // 新增：处理搜索用户点击回调
    let isUserFavorited: (String) -> Bool
    let onToggleFavorite: (String, String?, String?, String?, String?, String?) -> Void
    let onRemoveFavorite: (String) -> Void // 新增：直接移除喜欢记录的回调
    let isUserLiked: (String) -> Bool
    let onToggleLike: (String, String?, String?, String?, String?, String?) -> Void
    let isUserFavoritedByMe: (String) -> Bool // 新增：检测对方是否也喜欢了当前用户
    @Binding var favoriteRecords: [FavoriteRecord] // 新增：喜欢记录数组
    let onMessagesUpdated: () -> Void // 新增：消息更新后的回调
    let onPat: (String) -> Void // 新增：拍一拍回调
    let onUnfriend: (MatchRecord) -> Void // 新增：解除好友关系回调
    let showBottomTabBar: Bool // 新增：控制是否显示底部按钮
    let showFriendsList: Bool // 新增：控制是否显示我的好友列表
    @Environment(\.dismiss) private var dismiss
    
    // 修改为接收现有数据作为参数
    @Binding var existingMessages: [MessageItem] // 现有消息数据
    @Binding var existingFriends: [MatchRecord] // 现有好友数据
    @Binding var existingPatMessages: [MessageItem] // 现有拍一拍消息数据
    
    // 新增：头像和用户名缓存绑定
    @Binding var existingAvatarCache: [String: String] // 现有头像缓存
    @Binding var existingUserNameCache: [String: String] // 现有用户名缓存
    
    @State internal var isLoading = false
    @State internal var isSilentLoading = false // 新增：静默加载状态
    // 移除不再需要的本地缓存变量，简化为2层架构
    @State internal var onlineStatusCache: [String: (Bool, Date?)] = [:] // 在线状态缓存
    @State internal var loginTypeCache: [String: String] = [:] // 🎯 新增：用户类型缓存
    @State internal var patButtonPressed: [String: Bool] = [:] // 跟踪每个好友的拍一拍按钮状态
    
    // 新增：拍一拍消息展开状态管理（按好友ID存储）
    @State internal var patMessagesExpandedStates: [String: Bool] = [:]
    
    // 新增：缓存刷新定时器
    @State internal var cacheRefreshTimer: Timer?
    
    // 移除缓存时间戳管理，与历史记录按钮保持一致
    
    // 移除本地缓存变量，使用绑定参数
    
    // 移除复杂缓存系统，与历史记录按钮保持一致
    
    // 新增：点击次数追踪（使用静态变量避免重置）
    @State internal var messageButtonClickCount = 0
    internal static var globalClickCount = 0
    
    // 移除缓存时间戳，与历史记录按钮保持一致
    
    // 新增：防重复调用标志
    @State private var isRefreshing = false
    
    // 新增：好友列表刷新标志
    @State internal var isFriendsRefreshing = false
    
    // 新增：Combine 订阅管理
    @State internal var cancellables = Set<AnyCancellable>()
    
    // 搜索用户弹窗相关状态
    @State internal var showingAddFriendSheet = false
    @State internal var addFriendSearchText: String = ""
    @State internal var addFriendSearchResults: [UserInfo] = []
    @State internal var isSearchingFriend = false
    @State internal var addFriendErrorMessage: String?
    
    // 新增：消息折叠状态
    @State internal var isMessagesExpanded: Bool = false  // 默认折叠消息列表
    
    // 新增：新的朋友列表显示状态
    @State internal var isNewFriendsVisible: Bool = false {  // 默认隐藏新的朋友列表
        didSet {
            // 新朋友列表显示状态变化
        }
    }
    
    // 移除消息实时刷新定时器，与历史记录按钮保持一致
    
    // 移除后台缓存更新定时器，与历史记录按钮保持一致
    
    // 新增：已显示弹窗的消息ID集合，避免重复显示
    @State private var shownPatMessageIds: Set<UUID> = []
    
    // handleMessageTap方法已移动到MessageView+HelperMethods.swift扩展中
    
    // detectMatchStatus方法已移动到MessageView+MatchStatus.swift扩展中
    
    // 移除缓存状态检查，与历史记录按钮保持一致
    
    
    // refreshMatchStatus方法已移动到MessageView+MatchStatus.swift扩展中
    
    // 工具和调试方法已移动到 MessageView+Utilities.swift 扩展中
    
    // autoDetectAndUploadMatchRecords方法已移动到MessageView+MatchStatus.swift扩展中
    
    // calculateUnreadCount方法已移动到MessageView+MessageHandling.swift扩展中
    
    // handleMarkAsRead方法已移动到MessageView+HelperMethods.swift扩展中
    
    init(
        unreadCount: Binding<Int>,
        newFriendsCountManager: NewFriendsCountManager,
        userManager: UserManager,
        stateManager: StateManager,
        onMessageTap: @escaping (MessageItem) -> Void,
        onUserSearchTap: ((UserInfo) -> Void)? = nil, // 新增：处理搜索用户点击回调
        isUserFavorited: @escaping (String) -> Bool,
        onToggleFavorite: @escaping (String, String?, String?, String?, String?, String?) -> Void,
        onRemoveFavorite: @escaping (String) -> Void,
        isUserLiked: @escaping (String) -> Bool,
        onToggleLike: @escaping (String, String?, String?, String?, String?, String?) -> Void,
        isUserFavoritedByMe: @escaping (String) -> Bool,
        favoriteRecords: Binding<[FavoriteRecord]>,
        onMessagesUpdated: @escaping () -> Void,
        onPat: @escaping (String) -> Void,
        onUnfriend: @escaping (MatchRecord) -> Void,
        showBottomTabBar: Bool,
        showFriendsList: Bool,
        existingMessages: Binding<[MessageItem]>,
        existingFriends: Binding<[MatchRecord]>,
        existingPatMessages: Binding<[MessageItem]>,
        existingAvatarCache: Binding<[String: String]>,
        existingUserNameCache: Binding<[String: String]>
    ) {
        self._unreadCount = unreadCount
        self.newFriendsCountManager = newFriendsCountManager
        self.userManager = userManager
        self.stateManager = stateManager
        self.onMessageTap = onMessageTap
        self.onUserSearchTap = onUserSearchTap
        self.isUserFavorited = isUserFavorited
        self.onToggleFavorite = onToggleFavorite
        self.onRemoveFavorite = onRemoveFavorite
        self.isUserLiked = isUserLiked
        self.onToggleLike = onToggleLike
        self.isUserFavoritedByMe = isUserFavoritedByMe
        self._favoriteRecords = favoriteRecords
        self.onMessagesUpdated = onMessagesUpdated
        self.onPat = onPat
        self.onUnfriend = onUnfriend
        self.showBottomTabBar = showBottomTabBar
        self.showFriendsList = showFriendsList
        self._existingMessages = existingMessages
        self._existingFriends = existingFriends
        self._existingPatMessages = existingPatMessages
        self._existingAvatarCache = existingAvatarCache
        self._existingUserNameCache = existingUserNameCache
        for (_, _) in existingFriends.wrappedValue.enumerated() {
        }
    }

    // body 属性已移动到 MessageView+Body.swift 扩展中
    
    // messagesTabView已移动到MessageView+UI.swift扩展中
    
    // 缓存刷新定时器方法已移动到 MessageView+CacheTimer.swift 扩展中
    
    // 消息数据刷新方法已移动到 MessageView+DataRefresh.swift 扩展中
    
    
    // handlePatFriend方法已移动到MessageView+PatMessageHandling.swift扩展中
    
    // handleViewLocation方法已移动到MessageView+HelperMethods.swift扩展中
    
    // 好友交互处理方法已移动到 MessageView+FriendInteraction.swift 扩展中
    
    // 工具和调试方法已移动到 MessageView+Utilities.swift 扩展中
    
    // 移除缓存过期清理机制，与历史记录按钮保持一致
    
    // 缓存管理方法已移动到 MessageView+CacheOperations.swift 扩展中
    
    // 移除后台缓存更新，与历史记录按钮保持一致
    
    // 移除后台消息缓存更新，与历史记录按钮保持一致
    
    // 移除后台好友列表缓存更新，与历史记录按钮保持一致
    
    // 移除后台状态缓存更新，与历史记录按钮保持一致
    
    // 移除后台用户信息缓存更新，与历史记录按钮保持一致
    
    
    // 消息处理方法已移动到 MessageView+MessageOperations.swift 扩展中
    
    // markAllAsRead方法已移动到MessageView+MessageHandling.swift扩展中
    
    // deleteMessage方法已移动到MessageView+HelperMethods.swift扩展中
    
    // 移除持久化存储恢复，与历史记录按钮保持一致
    
    // 移除持久化存储，与历史记录按钮保持一致
    
    // 移除持久化存储恢复，与历史记录按钮保持一致
    
    // 缓存管理方法已移动到 MessageView+CacheOperations.swift 扩展中
    
    // loadFriends方法已移动到MessageView+FriendsManagement.swift扩展中
    
    // updateNewFriendsUserInfo方法已移动到MessageView+UserInfoUpdating.swift扩展中
    
    // updateFriendsUserInfo方法已移动到MessageView+UserInfoUpdating.swift扩展中
    
    // getCachedUserAvatar、getCachedUserName、getCachedUserLoginType方法已移动到MessageView+CacheManagement.swift扩展中
    
    // handleAddFriendButtonTap方法已移动到MessageView+HelperMethods.swift扩展中
    
    // 新朋友按钮处理方法已移动到 MessageView+NewFriendsButton.swift 扩展中
    
    // detectNewPatMessages方法已移动到MessageView+PatMessageHandling.swift扩展中
    
    // 工具和调试方法已移动到 MessageView+Utilities.swift 扩展中
    
    // MARK: - 静默加载方法
    
    // loadMessagesSilently方法已移动到MessageView+MessageHandling.swift扩展中
    
    // loadFriendsSilently方法已移动到MessageView+FriendsManagement.swift扩展中
    
    // MARK: - IM 触发器监听和实时更新
    
    // setupIMListener和triggerImmediateMessageUpdate方法已移动到MessageView+IMTriggers.swift扩展中
    
    // MARK: - 移除消息实时刷新定时器管理，与历史记录按钮保持一致
    
    // MARK: - 后台缓存更新定时器管理
    
    // 移除后台缓存更新定时器，与历史记录按钮保持一致
}
