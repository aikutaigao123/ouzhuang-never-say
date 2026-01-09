import SwiftUI

// 好友列表界面
struct FriendsListView: View {
    let userManager: UserManager
    let onFriendTap: (MatchRecord) -> Void
    let onUnfriend: (MatchRecord) -> Void
    let onNewFriendTap: (MessageItem) -> Void // 新增：新的朋友点击回调
    let isUserFavorited: (String) -> Bool // 新增：检查是否已喜欢
    let isUserFavoritedByMe: (String) -> Bool // 新增：检查是否被喜欢
    let favoriteRecords: [FavoriteRecord] // 新增：喜欢记录数组
    let onToggleFavorite: (String, String?, String?, String?, String?, String?) -> Void // 新增：切换喜欢状态
    let isUserLiked: (String) -> Bool // 新增：检查是否已点赞
    let onToggleLike: (String, String?, String?, String?, String?, String?) -> Void // 新增：切换点赞状态
    @Environment(\.dismiss) var dismiss
    @State var friends: [MatchRecord] = []
    @State var newFriends: [MessageItem] = [] // 新增：新的朋友（好友申请）
    @Binding var patMessages: [MessageItem] // 修改：使用Binding而不是State，确保数据同步
    @State var isNewFriendsExpanded = true // 新增：新的朋友列表是否展开
    @State var isLoading = false
    @State var avatarCache: [String: String] = [:] // 头像缓存
    @State var userNameCache: [String: String] = [:] // 用户名缓存
    @State var onlineStatusCache: [String: (Bool, Date?)] = [:] // 在线状态缓存
    
    // 新增：缓存时间戳管理
    @State var avatarCacheTimestamps: [String: Date] = [:]
    @State var userNameCacheTimestamps: [String: Date] = [:]
    var cacheExpirationInterval: TimeInterval = 3 // 3秒缓存过期（测试用）
    
    // 新增：防重复调用标志
    @State var isRefreshing = false
    
    // 新增：拍一拍操作反馈状态
    @State var showPatFeedback = false
    @State var patFeedbackMessage = ""
    @State var patFeedbackType: PatFeedbackType = .success
    @State var showPatAlert = false
    @State var patAlertMessage = ""
    @State var patButtonPressed: [String: Bool] = [:] // 跟踪每个好友的拍一拍按钮状态
    
    // 新增：拍一拍消息展开状态管理（按好友ID存储）
    @State var patMessagesExpandedStates: [String: Bool] = [:]
    
    // 新增：批量查询相关状态
    @State var hasBatchLoadedOnlineStatus = false
    @State var isBatchLoadingOnlineStatus = false
    
    // 新增：批量查询用户名、头像和用户类型的状态控制
    @State var hasBatchLoadedUserNameAvatar = false
    @State var isBatchLoadingUserNameAvatar = false
    
    // 新增：用户类型本地缓存
    @State var loginTypeCache: [String: String] = [:]
    
    // 🎯 新增：记录是否已经在本次打开中加载过数据
    @State private var hasLoadedInCurrentSession = false
    
    // 🎯 新增：下拉刷新限制提示
    @State var showRefreshLimitAlert = false
    @State var refreshLimitMessage = ""
    
    // body 视图已移动到 FriendsListView+Body.swift
    /*
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("加载好友列表...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if friends.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("暂无好友")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                        
                        Text("当您与其他人互相喜欢时，\n他们就会出现在这里")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        // 新的朋友部分
                        
                        if !newFriends.isEmpty {
                            Section(header: newFriendsSectionHeader) {
                                if isNewFriendsExpanded {
                                    
                                    ForEach(newFriends, id: \.id) { newFriend in
                                        NewFriendRowView(
                                            message: newFriend,
                                            avatarCache: $avatarCache,
                                            userNameCache: $userNameCache,
                                            onAccept: { requestId in
                                                // 🎯 符合好友关系开发指南：接受好友申请
                                                // 通过 requestId 查询 FriendshipRequest，然后调用 acceptFriendshipRequest
                                                FriendshipManager.shared.fetchFriendshipRequests { requests, error in
                                                    DispatchQueue.main.async {
                                                        if error != nil {
                                                            return
                                                        }
                                                        guard let requests = requests,
                                                              let request = requests.first(where: { $0.objectId == requestId }) else {
                                                            return
                                                        }
                                                        
                                                        // 获取对方用户信息（发送申请的用户）
                                                        let otherUserId = request.user.id
                                                        let otherUserName = request.user.fullName
                                                        let otherUserEmail = request.user.email
                                                        let otherUserLoginType = request.user.loginType.toString()
                                                        
                                                        FriendshipManager.shared.acceptFriendshipRequest(request, attributes: nil) { success, errorMessage in
                                                            DispatchQueue.main.async {
                                                                if success {
                                                                    
                                                                    // 🎯 新增：点击同意按钮应视为点亮爱心按钮
                                                                    // 获取对方头像（从缓存或默认值）
                                                                    let otherUserAvatar = avatarCache[otherUserId] ?? ""
                                                                    
                                                                    // 调用 onToggleFavorite 点亮爱心按钮
                                                                    onToggleFavorite(
                                                                        otherUserId,
                                                                        otherUserName,
                                                                        otherUserEmail,
                                                                        otherUserLoginType,
                                                                        otherUserAvatar,
                                                                        nil // recordObjectId 可以为 nil
                                                                    )
                                                                    
                                                                    NotificationCenter.default.post(name: NSNotification.Name("RefreshNewFriends"), object: nil)
                                                                    NotificationCenter.default.post(name: NSNotification.Name("FriendshipRequestUpdated"), object: nil)
                                                                } else {
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            },
                                            onReject: { requestId in
                                                // 🎯 符合好友关系开发指南：拒绝好友申请
                                                // 通过 requestId 查询 FriendshipRequest，然后调用 declineFriendshipRequest
                                                FriendshipManager.shared.fetchFriendshipRequests { requests, error in
                                                    DispatchQueue.main.async {
                                                        if error != nil {
                                                            return
                                                        }
                                                        guard let requests = requests,
                                                              let request = requests.first(where: { $0.objectId == requestId }) else {
                                                            return
                                                        }
                                                        FriendshipManager.shared.declineFriendshipRequest(request) { success, errorMessage in
                                                            DispatchQueue.main.async {
                                                                if success {
                                                                    NotificationCenter.default.post(name: NSNotification.Name("RefreshNewFriends"), object: nil)
                                                                    NotificationCenter.default.post(name: NSNotification.Name("FriendshipRequestUpdated"), object: nil)
                                                                } else {
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            },
                                            onTap: {
                                                onNewFriendTap(newFriend)
                                                dismiss()
                                            }
                                        )
                                        .onAppear {
                                            // 🔍 新增：详细检查新朋友列表中的消息类型
                                            
                                            // 特别检查拍一拍消息
                                            if newFriend.messageType == "pat" || newFriend.content.contains("拍了拍") {
                                            }
                                            
                                            // 检查撤销消息
                                            if newFriend.content.contains("撤销了好友申请") {
                                            }
                                        }
                                    }
                                }
                            }
                            .onAppear {
                            }
                        } else {
                            Color.clear
                                .frame(height: 0)
                                .onAppear {
                                }
                        }
                        
                        
                        // 现有好友部分
                        if !friends.isEmpty {
                            Section(header: Text("我的好友").font(.headline).foregroundColor(.primary)) {
                                // UI层面：在ForEach前添加一个隐藏视图来触发打印
                                if friends.first != nil {
                                    Color.clear
                                        .frame(height: 0)
                                        .onAppear {
                                        }
                                }
                                ForEach(friends) { friend in
                                    FriendRowView(
                                        friend: friend,
                                        currentUserId: userManager.currentUser?.userId ?? "",  // 🔧 修复：使用真实的 userId 而不是 objectId
                                        avatarCache: $avatarCache,
                                        userNameCache: $userNameCache,
                                        onlineStatusCache: $onlineStatusCache,
                                        loginTypeCache: $loginTypeCache, // 🎯 新增：传递用户类型缓存
                                        patMessages: $patMessages,
                                        patMessagesExpandedStates: $patMessagesExpandedStates,
                                        onTap: {
                                            onFriendTap(friend)
                                            dismiss()
                                        },
                                        onPat: {
                                            // 🔍 关键调试：检查匹配逻辑
                                            let currentUserId = userManager.currentUser?.id ?? ""
                                            let currentUserUserId = userManager.currentUser?.userId ?? ""
                                            
                                            // 尝试用 id 匹配
                                            var friendName: String
                                            var friendId: String
                                            
                                            if friend.user1Id == currentUserId {
                                                friendName = friend.user2Name
                                                friendId = friend.user2Id
                                            } else if friend.user1Id == currentUserUserId {
                                                friendName = friend.user2Name
                                                friendId = friend.user2Id
                                            } else if friend.user2Id == currentUserId {
                                                friendName = friend.user1Name
                                                friendId = friend.user1Id
                                            } else if friend.user2Id == currentUserUserId {
                                                friendName = friend.user1Name
                                                friendId = friend.user1Id
                                            } else {
                                                // 默认逻辑
                                                friendName = friend.user1Id == currentUserId ? friend.user2Name : friend.user1Name
                                                friendId = friend.user1Id == currentUserId ? friend.user2Id : friend.user1Id
                                            }
                                            
                                            // 立即显示弹窗反馈
                                            patAlertMessage = "正在向 \(friendName) 发送拍一拍..."
                                            showPatAlert = true
                                            
                                            // 调用handlePatFriend
                                            handlePatFriend(friend)
                                        },
                                        patButtonPressed: $patButtonPressed,
                                        onViewLocation: { friendId in
                                            // 🎯 修改：与查看详情按钮完全一致，调用 onTap() 逻辑
                                            onFriendTap(friend)
                                            dismiss()
                                        },
                                        onUnfriend: {
                                            // 🎯 macOS 右键菜单：解除好友关系
                                            onUnfriend(friend)
                                        }
                                    )
                                    #if os(iOS)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            // 解除好友关系
                                            let currentUserId = userManager.currentUser?.userId ?? "nil"
                                            onUnfriend(friend)
                                        } label: {
                                            Label("解除关系", systemImage: "person.crop.circle.badge.minus")
                                        }
                                    }
                                    #endif
                                }
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
        }
        .overlay(patFeedbackOverlay)
        .onAppear {
            
            // 🔍 新增：打印UI显示和行数信息
            
            if friends.isEmpty {
            } else {
                for (_, friend) in friends.enumerated() {
                }
            }
            
            if newFriends.isEmpty {
            } else {
                for (_, _) in newFriends.enumerated() {
                }
            }
            
            // 🎯 修改：立即从 UserDefaults 恢复缓存数据，让 UI 秒开
            if let currentUser = userManager.currentUser {
                let cached = UserDefaultsManager.getFriendsList(userId: currentUser.userId)
                if !cached.isEmpty && friends.isEmpty {
                    // 立即更新 UI，不等待网络请求
                    self.friends = cached
                }
            }
            
            // 首先从持久化缓存恢复数据，避免应用后台恢复时缓存丢失
            restoreCacheFromPersistence()
            
            // 🎯 修改：只在首次加载时才触发网络请求，后台刷新
            if !hasLoadedInCurrentSession {
                loadFriends(showLoading: false) // 有缓存时不显示全屏 loading
                loadNewFriends()
                hasLoadedInCurrentSession = true
            }
            
            // 与用户头像界面一致：不再使用批量查询，改为各个组件onAppear时实时查询
            // batchLoadUserNameAndAvatar() // 已删除：不再使用批量查询
            
        // 监听好友列表刷新通知
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RefreshFriendsList"),
            object: nil,
            queue: .main
        ) { _ in
            loadFriends()
            loadNewFriends()
        }
            
            // 监听匹配状态刷新通知
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("RefreshMatchStatus"),
                object: nil,
                queue: .main
            ) { _ in
                let refreshStartTime = Date()
                loadNewFriends()
                let refreshTime = Date().timeIntervalSince(refreshStartTime)
                if refreshTime > 0.1 {
                }
            }
            
            // 监听新的朋友刷新通知
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("RefreshNewFriends"),
                object: nil,
                queue: .main
            ) { _ in
                loadNewFriends()
            }
            
            // 🎯 新增：监听新好友申请通知（IM实时推送）
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("NewFriendshipRequest"),
                object: nil,
                queue: .main
            ) { _ in
                loadNewFriends()
            }
            
            // 🎯 新增：监听好友申请状态更新通知
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("FriendshipRequestUpdated"),
                object: nil,
                queue: .main
            ) { _ in
                loadNewFriends()
            }
            
            // 监听应用恢复前台通知，重新恢复缓存
            NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { _ in
                // 应用恢复前台时，重新恢复缓存
                restoreCacheFromPersistence()
            }
            
        }
        .onDisappear {
            // 移除通知监听器
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("RefreshFriendsList"), object: nil)
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("RefreshMatchStatus"), object: nil)
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("RefreshNewFriends"), object: nil)
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("RefreshPatMessages"), object: nil)
        }
        .refreshable {
            // 支持下拉刷新
            loadFriends()
            loadNewFriends()
        }
        .alert("拍一拍", isPresented: $showPatAlert) {
            Button("确定") { }
        } message: {
            Text(patAlertMessage)
        }
    }
    */
    
    // calculateUnreadNewFriendsCount method moved to FriendsListView+NewFriends.swift
    // markNewFriendsAsRead method moved to FriendsListView+NewFriends.swift
    // handleRefreshPatMessages method moved to FriendsListView+PatMessage.swift
    
    // formatTimeAgo(_ date:) method moved to FriendsListView+Utils.swift
    // printFriendsOnlineStatus method moved to FriendsListView+OnlineStatus.swift
    // checkMatchStatusConsistency method moved to FriendsListView+Actions.swift
    
    // 加载好友列表
    // loadFriends method moved to FriendsListView+DataManagement.swift
    
    // updateFriendsUserInfo method moved to FriendsListView+DataManagement.swift
    
    // 获取缓存的用户头像 - 只从UserAvatarRecord表读取
    // getCachedUserAvatar method moved to FriendsListView+CacheManagement.swift
    
    // printAllLocalOnlineStatusCache method moved to FriendsListView+Actions.swift
    // getCachedUserName method moved to FriendsListView+CacheManagement.swift
    // getCachedUserLoginType method moved to FriendsListView+CacheManagement.swift
    // handleViewLocation method moved to FriendsListView+Actions.swift
    // deleteFriendRequestMessage method moved to FriendsListView+NewFriends.swift
    
    // 防重复加载标记
    @State private var isLoadingNewFriends = false
    
    // 加载新的朋友（好友申请）
    // loadNewFriends method moved to FriendsListView+DataManagement.swift
    
    // 从持久化存储恢复缓存数据
    // restoreCacheFromPersistence method moved to FriendsListView+CacheManagement.swift
    
    // cleanupExpiredCache method moved to FriendsListView+CacheManagement.swift
    
    // cleanupCacheAfterUpdate method moved to FriendsListView+CacheManagement.swift
    
    // 批量获取好友数据
    // batchFetchFriendData method moved to FriendsListView+DataManagement.swift
    
    // batchFetchNewFriendsData method moved to FriendsListView+DataManagement.swift
    
    // MARK: - 批量查询用户名和头像
    // batchLoadUserNameAndAvatar method moved to FriendsListView+BatchLoading.swift
    
    // MARK: - 批量查询在线状态
    // batchLoadOnlineStatus method moved to FriendsListView+OnlineStatus.swift
    // formatTimeAgo(_ timeInterval:) method moved to FriendsListView+OnlineStatus.swift
}

// 好友行视图
// FriendRowView moved to FriendRowView.swift
// NewFriendRowView moved to FriendsListView+NewFriendRow.swift
/*
struct NewFriendRowView: View {
    let message: MessageItem
    @Binding var avatarCache: [String: String]
    @Binding var userNameCache: [String: String]
    let onAccept: (String) -> Void // 🎯 修改：接受回调，参数为 FriendshipRequest 的 objectId
    let onReject: (String) -> Void // 🎯 修改：拒绝回调，参数为 FriendshipRequest 的 objectId
    let onTap: () -> Void
    
    // 🎯 修改：完全按照好友列表的逻辑，添加相同的状态变量
    @State private var avatarFromServer: String? = nil // 从服务器实时查询的头像
    @State private var userNameFromServer: String? = nil // 从服务器实时查询的用户名
    @State private var hasLoadedFromServer: Bool = false // 是否已从服务器加载
    @State private var userLoginType: String? = nil // 从服务器获取的用户类型
    @State private var hasLoadedLoginType: Bool = false // 是否已加载用户类型
    
    // 🎯 新增：获取发送者信息（完全按照好友列表的 friendInfo 逻辑）
    private var senderInfo: (id: String, name: String, avatar: String, loginType: String) {
        let senderId = message.senderId
        let defaultLoginType = message.senderLoginType ?? UserTypeUtils.getLoginTypeFromUserId(senderId)
        
        // 优先使用缓存的头像和用户名，如果没有则使用 MessageItem 中的默认值
        let defaultAvatar = message.senderAvatar
        let defaultName = message.senderName
        
        // 🔧 修复：头像优先级：UserAvatarRecord表 > MessageItem中的头像 > 默认头像
        let cachedAvatar = avatarCache[senderId]
        let cachedName = userNameCache[senderId]
        
        let finalAvatar: String
        // 不使用全局缓存：优先使用 MessageItem 中的默认值，其次使用本地缓存
        if !defaultAvatar.isEmpty && defaultAvatar != "😀" {
            // MessageItem 中有有效的头像，使用
            finalAvatar = defaultAvatar
        } else if let cached = cachedAvatar, !cached.isEmpty && cached != "😀" {
            // 缓存中有有效的头像
            finalAvatar = cached
        } else {
            // 使用默认头像 - 与用户头像界面一致：根据 loginType 决定 - Apple账号与内部账号使用相同的默认头像
            let loginType = userLoginType ?? defaultLoginType
            if loginType == "apple" {
                finalAvatar = "person.circle.fill"
            } else {
                finalAvatar = "person.circle" // 游客用户或未知类型使用 person.circle（蓝色）
            }
        }
        
        // 登录类型不使用全局缓存：优先使用状态中解析到的，其次使用 MessageItem 中的默认值
        let finalLoginType = userLoginType ?? defaultLoginType
        
        // 用户名不使用全局缓存：优先本地缓存，其次 MessageItem 中的默认值
        let finalName: String
        if let cached = cachedName, !cached.isEmpty {
            finalName = cached
        } else {
            finalName = defaultName
        }
        
        return (senderId, finalName, finalAvatar, finalLoginType)
    }
    
    // 🎯 新增：获取显示的头像（完全按照好友列表的 displayedAvatar 逻辑）
    private var displayedAvatar: String {
        let senderId = message.senderId
        
        // 第一优先级：从服务器实时查询的头像（与用户头像界面一致）
        if let serverAvatar = avatarFromServer, !serverAvatar.isEmpty {
            return serverAvatar
        }
        // 第二优先级：从 UserDefaults 获取头像（与用户头像界面一致：使用 displayAvatar，对应 UserDefaults）
        if let customAvatar = UserDefaultsManager.getCustomAvatar(userId: senderId), !customAvatar.isEmpty {
            // 🔍 检查 UserDefaults 与服务器数据是否一致
            if let serverAvatar = avatarFromServer, !serverAvatar.isEmpty {
                if serverAvatar != customAvatar {
                } else {
                }
            } else {
            }
            
            return customAvatar
        }
        // 第三优先级：senderInfo 中的头像（可能来自本地缓存或 MessageItem）
        if !senderInfo.avatar.isEmpty && senderInfo.avatar != "😊" {
            if avatarCache[senderId] != nil {
            } else {
            }
            return senderInfo.avatar
        }
        // 返回空字符串表示使用默认头像
        return ""
    }
    
    // 🎯 新增：获取显示的用户名（完全按照好友列表的 displayedName 逻辑）
    private var displayedName: String {
        let senderId = message.senderId
        let defaultName = message.senderName
        
        // 第一优先级：实时查询的结果（来自 UserNameRecord 表）
        if let serverName = userNameFromServer, !serverName.isEmpty {
            return serverName
        }
        
        // 第二优先级：senderInfo 中的用户名（可能来自本地缓存或 MessageItem 默认值）
        let infoName = senderInfo.name
        if let cachedName = userNameCache[senderId], !cachedName.isEmpty, cachedName == infoName {
        } else if infoName == defaultName {
        } else {
        }
        return infoName
    }
    
    // 🎯 新增：获取登录类型显示名称（完全按照好友列表的逻辑）
    private func loginTypeDisplayName(_ loginType: String) -> String {
        return UserTypeUtils.getUserTypeText(loginType)
    }
    
    // 🎯 新增：获取登录类型颜色（完全按照好友列表的逻辑）
    private func loginTypeColor(_ loginType: String) -> Color {
        return UserTypeUtils.getUserTypeColor(loginType)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 🎯 修改：完全按照好友列表的头像显示逻辑
            ZStack(alignment: .topTrailing) {
                let avatar = displayedAvatar
                let isSFSymbol = UserAvatarUtils.isSFSymbol(avatar)
                
                if !avatar.isEmpty {
                    // 检查是否是 SF Symbol
                    if isSFSymbol {
                        // SF Symbol 头像显示
                        if avatar == "applelogo" || avatar == "apple_logo" {
                            // Apple Logo 特殊处理
                            Image(systemName: "applelogo")
                                .font(.system(size: 40))
                                .foregroundColor(.black)
                                .background(Circle().fill(Color.gray.opacity(0.1)).frame(width: 50, height: 50))
                        } else {
                            // 🔧 修复：统一处理所有 SF Symbol
                            Image(systemName: avatar)
                                .font(.system(size: 40))
                                .foregroundColor(avatar == "person.circle.fill" ? .purple : .blue)
                                .background(Circle().fill(Color.gray.opacity(0.1)).frame(width: 50, height: 50))
                        }
                    } else {
                        // Emoji 或文本头像显示 - 根据 emoji 数量调整字体大小
                        let emojiCount = avatar.count
                        let fontSize: CGFloat = emojiCount > 1 ? 24 : 40
                        
                        Text(avatar)
                            .font(.system(size: fontSize))
                            .fixedSize(horizontal: true, vertical: false)
                            .background(Circle().fill(Color.gray.opacity(0.1)).frame(width: 50, height: 50))
                    }
                } else {
                    // 使用默认头像（基于 loginType）- 与用户头像界面一致：Apple账号与内部账号使用相同的默认头像
                    ZStack {
                        Circle().fill(Color.gray.opacity(0.1)).frame(width: 50, height: 50)
                        if senderInfo.loginType == "apple" {
                            // Apple账号使用默认头像
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.purple)
                                .font(.system(size: 24))
                        } else {
                            // 游客用户 - 与用户头像界面一致：使用 person.circle（蓝色）
                            Image(systemName: "person.circle")
                                .foregroundColor(.blue)
                                .font(.system(size: 24))
                        }
                    }
                }
            }
            .frame(width: 50, height: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                // 🎯 修改：新的朋友列表显示消息内容，确保显示发送者用户名
                // 消息内容 - 动态替换"未知用户"或添加用户名
                let displayContent: String = {
                    // 🎯 修复：如果消息内容包含"对你发送了好友申请"，确保前面有用户名
                    if message.content.contains("对你发送了好友申请") {
                        // 检查内容是否以空格或直接以"对你发送了好友申请"开头（说明缺少用户名）
                        let trimmedContent = message.content.trimmingCharacters(in: .whitespaces)
                        if trimmedContent.hasPrefix("对你发送了好友申请") || message.content.trimmingCharacters(in: .whitespaces).isEmpty {
                            // 🔧 增强修复：如果内容没有用户名，从多个来源获取用户名
                            var finalSenderName: String = ""
                            
                            // 优先级1：使用 displayedName（可能来自服务器查询或缓存）
                            if !displayedName.isEmpty && displayedName != "未知用户" {
                                finalSenderName = displayedName
                            }
                            // 优先级2：使用 message.senderName（来自 MessageItem）
                            else if !message.senderName.isEmpty && message.senderName != "未知用户" {
                                finalSenderName = message.senderName
                            }
                            // 优先级3：从缓存获取
                            else if let cachedName = userNameCache[message.senderId], !cachedName.isEmpty && cachedName != "未知用户" {
                                finalSenderName = cachedName
                            }
                            // 优先级4：使用默认值
                            else {
                                finalSenderName = "未知用户"
                            }
                            
                            return "\(finalSenderName) 对你发送了好友申请"
                        } else {
                            // 内容中已有用户名，但可能是"未知用户"或旧的用户名，尝试替换
                            if !displayedName.isEmpty && displayedName != "未知用户" {
                                // 替换"未知用户"
                                if message.content.contains("未知用户") {
                                    return message.content.replacingOccurrences(of: "未知用户", with: displayedName)
                                }
                                // 替换旧的 senderName（如果不同）
                                if !message.senderName.isEmpty && message.senderName != displayedName && message.content.contains(message.senderName) {
                                    return message.content.replacingOccurrences(of: message.senderName, with: displayedName)
                                }
                            }
                            // 🔧 增强：如果内容是" 对你发送了好友申请"（只有空格），也尝试修复
                            let trimmed = message.content.trimmingCharacters(in: .whitespaces)
                            if trimmed == "对你发送了好友申请" {
                                var finalSenderName: String = ""
                                if !displayedName.isEmpty && displayedName != "未知用户" {
                                    finalSenderName = displayedName
                                } else if !message.senderName.isEmpty && message.senderName != "未知用户" {
                                    finalSenderName = message.senderName
                                } else if let cachedName = userNameCache[message.senderId], !cachedName.isEmpty && cachedName != "未知用户" {
                                    finalSenderName = cachedName
                                } else {
                                    finalSenderName = "未知用户"
                                }
                                return "\(finalSenderName) 对你发送了好友申请"
                            }
                            return message.content
                        }
                    }
                    
                    // 🎯 其他类型的消息：替换"未知用户"或旧的用户名
                    if !displayedName.isEmpty && displayedName != "未知用户" && message.content.contains("未知用户") {
                        return message.content.replacingOccurrences(of: "未知用户", with: displayedName)
                    }
                    // 如果 displayedName 不为空且与 message.senderName 不同，也尝试替换
                    if !displayedName.isEmpty && displayedName != message.senderName && message.content.contains(message.senderName) {
                        return message.content.replacingOccurrences(of: message.senderName, with: displayedName)
                    }
                    return message.content
                }()
                // 🎯 修改：新的朋友列表显示消息内容（与好友列表不同，好友列表显示用户名）
                // 消息内容已经通过 displayContent 动态替换了用户名
                Text(displayContent)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .onAppear {
                        let senderId = message.senderId
                        let defaultName = message.senderName
                        let _: String
                        if let serverName = userNameFromServer, !serverName.isEmpty, serverName == displayedName {
                        }
                    }
                
                // 🎯 修改：完全按照好友列表的登录类型标签显示逻辑
                // 登录类型标签
                HStack {
                    Text(loginTypeDisplayName(senderInfo.loginType))
                        .font(.caption)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(loginTypeColor(senderInfo.loginType))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                    
                    // 未读标记 - 显示在用户类型标签右侧
                    if !message.isRead {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 8, height: 8)
                            Text("未读")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Spacer()
                }
                
                // 操作按钮 - 右下角
                HStack {
                    Spacer()
                    
                    // 🎯 符合好友关系开发指南：同意和拒绝按钮（只对 pending 状态的好友申请显示）
                    // 显示条件：messageType 为 friend_request 或 favorite，且 content 包含"对你发送了好友申请"（表示是别人向当前用户发送的申请）
                    let isFriendRequest = (message.messageType == "friend_request" || message.messageType == "favorite") && message.content.contains("对你发送了好友申请")
                    
                    if isFriendRequest {
                        // 检查是否是 pending 状态（通过 content 判断，pending 状态的内容是"xxx对你发送了好友申请"）
                        let isPending = !message.content.contains("已接受") && !message.content.contains("已拒绝")
                        
                        if isPending {
                            HStack(spacing: 8) {
                                // 同意按钮
                                Button(action: {
                                    guard let requestId = message.objectId else {
                                        return
                                    }
                                    onAccept(requestId)
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.system(size: 14))
                                        Text("同意")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                // 拒绝按钮
                                Button(action: {
                                    guard let requestId = message.objectId else {
                                        return
                                    }
                                    onReject(requestId)
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                            .font(.system(size: 14))
                                        Text("拒绝")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .onAppear {
                            }
                        } else {
                            // 🔍 调试：打印为什么按钮不显示（非pending状态）
                            EmptyView()
                                .onAppear {
                                }
                        }
                    } else {
                        // 🔍 调试：打印为什么按钮不显示（不满足显示条件）
                        EmptyView()
                            .onAppear {
                            }
                    }
                }
            }
            
            Spacer()
            
            // 箭头图标
            Image(systemName: "chevron.down")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle()) // 确保整个区域都可以点击
        .onTapGesture {
            onTap()
        }
        .onAppear {
            let senderId = message.senderId
            // 🎯 修改：完全按照好友列表的 onAppear 逻辑
            // 与用户头像界面一致：不使用全局缓存，直接使用行内的 loginType
            let _: String = senderInfo.loginType
            
            // 🔧 新增：实时查询头像和用户名（与用户头像界面逻辑一致）
            if !hasLoadedFromServer && (avatarFromServer == nil || userNameFromServer == nil) {
                hasLoadedFromServer = true
                
                // 🎯 修改：使用 fetchUserAvatarByUserId，不依赖 loginType，直接从 UserAvatarRecord 表获取
                LeanCloudService.shared.fetchUserAvatarByUserId(objectId: senderId) { avatar, error in
                    DispatchQueue.main.async {
                        if error != nil {
                        } else if let avatar = avatar, !avatar.isEmpty {
                            // 🔍 检查 UserDefaults 与服务器数据是否一致
                            let userDefaultsAvatar = UserDefaultsManager.getCustomAvatar(userId: senderId)
                            if let defaultsAvatar = userDefaultsAvatar, !defaultsAvatar.isEmpty {
                                if defaultsAvatar != avatar {
                                    // 🔧 自动更新 UserDefaults 以保持一致性
                                    UserDefaultsManager.setCustomAvatar(userId: senderId, emoji: avatar)
                                } else {
                                }
                            } else {
                                UserDefaultsManager.setCustomAvatar(userId: senderId, emoji: avatar)
                            }
                            
                            self.avatarFromServer = avatar
                            // 命中后写入本地缓存，减少后续查询
                            self.avatarCache[senderId] = avatar
                        } else {
                        }
                    }
                }
                
                // 🎯 修改：使用 fetchUserNameByUserId，不依赖 loginType，直接从 UserNameRecord 表获取
                let defaultName = message.senderName
                LeanCloudService.shared.fetchUserNameByUserId(objectId: senderId) { name, error in
                    DispatchQueue.main.async {
                        if error != nil {
                        } else if let name = name, !name.isEmpty {
                            self.userNameFromServer = name
                            // 命中后写入本地缓存，减少后续查询
                            self.userNameCache[senderId] = name
                            if defaultName != name {
                            }
                        } else {
                        }
                    }
                }
            } else {
            }
            
            // 异步获取用户类型
            if !hasLoadedLoginType {
                hasLoadedLoginType = true
                LeanCloudService.shared.fetchUserLoginType(objectId: senderInfo.id) { loginType in
                    if let loginType = loginType {
                        userLoginType = loginType
                    }
                }
            }
        }
    }
}
*/

#Preview {
    FriendsListView(
        userManager: UserManager(),
        onFriendTap: { _ in },
        onUnfriend: { _ in },
        onNewFriendTap: { _ in },
        isUserFavorited: { _ in false },
        isUserFavoritedByMe: { _ in false },
        favoriteRecords: [],
        onToggleFavorite: { _, _, _, _, _, _ in },
        isUserLiked: { _ in false },
        onToggleLike: { _, _, _, _, _, _ in },
        patMessages: .constant([]) // 添加patMessages参数
    )
}

