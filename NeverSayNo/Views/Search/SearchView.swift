import SwiftUI

struct SearchView: View {
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var userManager: UserManager
    @Binding var unreadMessageCount: Int
    @StateObject private var diamondManager: DiamondManager
    @StateObject private var searchViewModel: SearchViewModel
    @StateObject private var searchStateManager: SearchStateManager
    
    var onBack: () -> Void = {}
    @Environment(\.dismiss) private var dismiss
    
    init(locationManager: LocationManager, userManager: UserManager, unreadMessageCount: Binding<Int>, onBack: @escaping () -> Void = {}) {
        self.locationManager = locationManager
        self.userManager = userManager
        self._unreadMessageCount = unreadMessageCount
        self.onBack = onBack
        let sharedDiamondManager = DiamondManager.shared
        self._diamondManager = StateObject(wrappedValue: sharedDiamondManager)
        self._searchViewModel = StateObject(wrappedValue: SearchViewModel(
            locationManager: locationManager,
            userManager: userManager,
            diamondManager: sharedDiamondManager
        ))
        self._searchStateManager = StateObject(wrappedValue: SearchStateManager(userManager: userManager))
    }
    @State private var showRechargeSheet = false
    @State private var showProfileSheet = false
    @State private var showAvatarZoom = false
    @State private var showMessageSheet = false
    @State private var showRankingSheet = false
    @State private var latestAvatars: [String: String] = [:]
    @State private var latestUserNames: [String: String] = [:]
    @State private var showCopySuccess = false
    @State private var copySuccessMessage = ""
    @State private var showFriendRequestModal = false
    // 新增：消息界面所需的状态（用于顶部导航入口）
    @State private var sheetExistingMessages: [MessageItem] = []
    @State private var sheetExistingFriends: [MatchRecord] = []
    @State private var sheetExistingPatMessages: [MessageItem] = []
    @State private var sheetExistingAvatarCache: [String: String] = [:]
    @State private var sheetExistingUserNameCache: [String: String] = [:]
    // 新增：喜欢记录管理（用于点亮爱心按钮）
    @State private var favoriteRecords: [FavoriteRecord] = []
    @State private var usersWhoLikedMe: [FavoriteRecord] = []
    @State var reportRecords: [ReportRecord] = [] // 新增：举报记录（internal 以便扩展访问）
    @State private var showRankingLimitAlert = false
    @State private var rankingLimitMessage = ""
    
    var body: some View {
        VStack {
            // 顶部导航栏
            SearchTopNavigationBar(
                userManager: userManager,
                diamondManager: diamondManager,
                unreadMessageCount: $unreadMessageCount,
                onProfileTap: { showProfileSheet = true },
                onRechargeTap: { showRechargeSheet = true },
                                    onRankingTap: {
                                        // 🎯 新增：检查排行榜点击次数限制
                                        guard let userId = userManager.currentUser?.id else {
                                            showRankingSheet = true
                                            return
                                        }
                                        
                                        let (canClick, message) = UserDefaultsManager.canClickRankingButton(userId: userId)
                                        if canClick {
                                            // 记录点击
                                            UserDefaultsManager.recordRankingButtonClick(userId: userId)
                                            // 打开排行榜
                                            showRankingSheet = true
                                        } else {
                                            // 显示限制提示
                                            rankingLimitMessage = message
                                            showRankingLimitAlert = true
                                        }
                                    },
                onMessageTap: { showMessageSheet = true }
            )
            
            // 指南针容器
            SearchCompassContainer(
                locationManager: locationManager,
                randomRecord: searchViewModel.randomRecord
            )
            
            // 寻找按钮
            SearchButton(
                locationManager: locationManager,
                diamondManager: diamondManager,
                isLoading: $searchViewModel.isLoading,
                isUserBlacklisted: $searchStateManager.isUserBlacklisted,
                onSearch: {
                    searchViewModel.sendLocationToServer()
                },
                onRecharge: {
                    showRechargeSheet = true
                }
            )
            .padding(.top, 20)
            
            // 消耗钻石说明
            if !searchViewModel.isLoading && !searchStateManager.isUserBlacklisted {
                SearchUIComponents.diamondCostHint()
            }
            
            // 位置状态提示
            if locationManager.location == nil && !searchViewModel.isLoading && !searchStateManager.isUserBlacklisted {
                SearchUIComponents.locationStatusHint()
            }
            
            // 倒计时显示
            if searchStateManager.isUserBlacklisted && !searchStateManager.timeRemaining.isEmpty {
                SearchUIComponents.timeRemainingHint(searchStateManager.timeRemaining)
            }
            
            // 匹配结果卡片
            if let record = searchViewModel.randomRecord {
                MatchResultCard(
                    record: record,
                    locationManager: locationManager,
                    userManager: userManager,
                    latestAvatars: latestAvatars,
                    latestUserNames: latestUserNames,
                    isUserFavorited: { userId in
                        guard let currentUser = userManager.currentUser else { return false }
                        let key = StorageKeyUtils.getFavoriteRecordsKey(for: currentUser)
                        var records = favoriteRecords
                        if let data = UserDefaults.standard.data(forKey: key),
                           let cachedRecords = try? JSONDecoder().decode([FavoriteRecord].self, from: data) {
                            records = cachedRecords
                        }
                        let result = DataHelpers.isUserFavorited(userId: userId, favoriteRecords: records)
                        return result
                    },
                    isUserFavoritedByMe: { userId in
                        let result = DataHelpers.isUserFavoritedByMe(userId: userId, usersWhoLikedMe: usersWhoLikedMe)
                        return result
                    },
                    isLocationRecordLiked: { recordId in
                        // 实现点赞检查逻辑
                        return false
                    },
                    addFavoriteRecord: { userId, userName, userEmail, loginType, userAvatar, recordObjectId in
                        // 🎯 实现添加喜欢记录逻辑
                        addFavoriteRecord(userId: userId, userName: userName, userEmail: userEmail, loginType: loginType, userAvatar: userAvatar, recordObjectId: recordObjectId)
                    },
                    removeFavoriteRecord: { userId in
                        // 🎯 实现移除喜欢记录逻辑
                        removeFavoriteRecord(userId: userId)
                    },
                    addLikeRecord: { userId, userName, userEmail, loginType, userAvatar, recordObjectId, isRecommendation in
                        // 实现添加点赞记录逻辑
                    },
                    removeLikeRecord: { userId, recordId, isRecommendation in
                        // 实现移除点赞记录逻辑
                    },
                    showMapSelectionForLocation: { record in
                        // 实现地图选择逻辑
                    },
                    showRankingSheet: {
                        // 🎯 新增：检查排行榜点击次数限制
                        guard let userId = userManager.currentUser?.id else {
                            showRankingSheet = true
                            return
                        }
                        
                        let (canClick, message) = UserDefaultsManager.canClickRankingButton(userId: userId)
                        if canClick {
                            // 记录点击
                            UserDefaultsManager.recordRankingButtonClick(userId: userId)
                            // 打开排行榜
                            showRankingSheet = true
                        } else {
                            // 显示限制提示
                            rankingLimitMessage = message
                            showRankingLimitAlert = true
                        }
                    },
                    showFriendRequestModal: {
                        showFriendRequestModal = true
                    },
                    selectedTab: 0,
                    copySuccessMessage: copySuccessMessage,
                    showCopySuccess: showCopySuccess,
                    setCopySuccessMessage: { message in
                        copySuccessMessage = message
                    },
                    setShowCopySuccess: { show in
                        showCopySuccess = show
                    },
                    ensureFavoriteState: {
                        loadUsersWhoLikedMe()
                        FriendshipManager.shared.fetchFriendsList { _, _ in }
                    },
                    onDeleteRecommendation: { // 🎯 新增：删除推荐榜记录
                        guard let record = searchViewModel.randomRecord else {
                            return
                        }
                        // 检查是否来自推荐榜
                        let isFromRecommendation = (record.placeName?.isEmpty == false) || 
                                                   (record.reason?.isEmpty == false)
                        if isFromRecommendation && !record.objectId.isEmpty {
                            LeanCloudService.shared.deleteRecommendation(objectId: record.objectId) { success, error in
                                DispatchQueue.main.async {
                                    if success {
                                        // 删除成功，发送通知刷新推荐榜列表
                                        NotificationCenter.default.post(
                                            name: NSNotification.Name("RefreshRecommendationList"),
                                            object: nil
                                        )
                                        // 清除当前显示的记录
                                        searchViewModel.randomRecord = nil
                                    }
                                }
                            }
                        }
                    }
                )
            }
            
            Spacer()
            
            // 复制成功提示
            if showCopySuccess {
                VStack {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 18))
                        Text(copySuccessMessage)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.green)
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    )
                }
                .transition(.opacity.combined(with: .scale))
                .animation(.easeInOut(duration: 0.3), value: showCopySuccess)
                .zIndex(1000)
            }
        }
        .onAppear {
            configureDiamondManager()
            if userManager.currentUser != nil {
            } else {
            }
            // 进入搜索界面时开始持续位置更新
            locationManager.startUpdatingLocation()
            // 刷新用户名缓存
            refreshUserNames()
            // 加载喜欢记录
            loadFavoriteRecords()
            // 加载喜欢我的用户
            loadUsersWhoLikedMe()
        }
        .onDisappear {
            // 离开搜索界面时停止持续位置更新
            locationManager.stopUpdatingLocation()
        }
        .sheet(isPresented: $showRechargeSheet) {
            RechargeView(diamondManager: diamondManager)
        }
        .sheet(isPresented: $showProfileSheet) {
            ProfileView(
                userManager: userManager,
                diamondManager: diamondManager,
                showLogoutAlert: .constant(false),
                showRechargeSheet: .constant(false),
                newUserName: .constant(""),
                isUserBlacklisted: false,
                onClearAllHistory: {},
                onShowHistory: {},
                newFriendsCountManager: NewFriendsCountManager(),
                onNavigateToTab: { _ in },
                showBottomTabBar: true
            )
        }
        .sheet(isPresented: $showAvatarZoom) {
            if let _ = searchViewModel.randomRecord {
                AvatarZoomView(
                    userManager: userManager,
                    showRandomButton: true
                )
            }
        }
        .sheet(isPresented: $showMessageSheet) {
            // 🔍 MessageView 即将展示（SearchView入口）：打印关键状态
            Group { EmptyView() }
                .onAppear {
                    let currentUserId = userManager.currentUser?.id ?? "nil"
                    if let first = sheetExistingFriends.first {
                        let _ = first.user1Id == currentUserId ? first.user2Id : first.user1Id
                    } else {
                    }
                }
                .onChange(of: sheetExistingFriends.count) { _, _ in
                }

            MessageView(
                unreadCount: $unreadMessageCount,
                newFriendsCountManager: NewFriendsCountManager(),
                userManager: userManager,
                stateManager: StateManager.shared,
                onMessageTap: { message in
                    // 处理消息点击
                },
                isUserFavorited: { _ in false }, // 默认未收藏
                onToggleFavorite: { _, _, _, _, _, _ in }, // 空实现
                onRemoveFavorite: { _ in }, // 空实现
                isUserLiked: { _ in false }, // 默认未点赞
                onToggleLike: { _, _, _, _, _, _ in }, // 空实现
                isUserFavoritedByMe: { _ in false }, // 默认未匹配
                favoriteRecords: .constant([]), // 空数组
                onMessagesUpdated: {
                    // 空实现，SearchView中不需要匹配状态检测
                },
                onPat: { _ in
                    // 空实现，SearchView中不需要拍一拍功能
                },
                onUnfriend: { _ in
                    // 空实现，SearchView中不需要解除好友功能
                },
                showBottomTabBar: true, // 从搜索界面进入，显示底部按钮
                showFriendsList: true, // 搜索界面显示我的好友列表
                existingMessages: $sheetExistingMessages,
                existingFriends: $sheetExistingFriends,
                existingPatMessages: $sheetExistingPatMessages,
                existingAvatarCache: $sheetExistingAvatarCache,
                existingUserNameCache: $sheetExistingUserNameCache
            )
            .onAppear {
            }
        }
                              .sheet(isPresented: $showRankingSheet) {
                          RankingView(
                              locationManager: locationManager,
                              userManager: userManager,
                              onRankingItemTap: handleRankingItemTap,
                              onRecommendationItemTap: handleRecommendationItemTap,
                              initialTab: 0,
                              selectedRecommendationId: nil
                          )
                      }
        .overlay(
            // 加好友弹窗
            Group {
                if showFriendRequestModal, let record = searchViewModel.randomRecord {
                    FriendRequestModal(
                        record: record,
                        latestUserNames: latestUserNames,
                        onDismiss: {
                            showFriendRequestModal = false
                        },
                        onAddFavorite: { userId, userName, userEmail, loginType, userAvatar, recordObjectId in
                            // 🎯 发送好友请求成功后，自动点亮对应的爱心按钮
                            addFavoriteRecord(
                                userId: userId,
                                userName: userName,
                                userEmail: userEmail,
                                loginType: loginType,
                                userAvatar: userAvatar,
                                recordObjectId: recordObjectId
                            )
                        },
                        onReportUser: { userId, userName, userEmail, reportReason, deviceId, loginType in
                            addReportRecord(
                                reportedUserId: userId,
                                reportedUserName: userName,
                                reportedUserEmail: userEmail,
                                reportReason: reportReason,
                                reportedDeviceId: deviceId,
                                reportedUserLoginType: loginType
                            )
                        },
                        hasReportedUser: { userId in
                            hasReportedUser(userId)
                        }
                    )
                }
            }
        )
    }
    
    // 刷新用户名缓存
    private func refreshUserNames() {
        // 清理用户名缓存，确保获取最新数据
        latestUserNames.removeAll()
        
        // 为当前匹配的用户获取最新用户名
        if let record = searchViewModel.randomRecord {
            let userId = record.userId
            
            // 🎯 修改：使用 fetchUserNameByUserId，不依赖 loginType，直接从 UserNameRecord 表获取
            LeanCloudService.shared.fetchUserNameByUserId(objectId: userId) { userName, error in
                DispatchQueue.main.async {
                    if let userName = userName, !userName.isEmpty {
                        self.latestUserNames[userId] = userName
                    } else {
                    }
                }
            }
        }
    }
    
    // 处理排行榜项目点击，直接匹配该用户（不消耗钻石）
    private func handleRankingItemTap(rankingItem: UserScore) {
        // 关闭排行榜界面
        showRankingSheet = false
        
        // 从LeanCloud获取该用户的最新位置记录
        LeanCloudService.shared.fetchLatestLocationForUser(userId: rankingItem.id) { locationRecord, error in
            DispatchQueue.main.async {
                if error != nil {
                    // 如果获取失败，不显示匹配结果
                    return
                } else if let locationRecord = locationRecord {
                    // 设置匹配结果（不消耗钻石）
                    searchViewModel.randomRecord = locationRecord
                    searchViewModel.isLoading = false
                }
            }
        }
    }
    
    private func handleRecommendationItemTap(item: RecommendationItem) {
        
        // 关闭排行榜界面
        showRankingSheet = false
        
        // 直接使用Recommendation表中的位置信息构造LocationRecord
        let locationRecord = item.toLocationRecord()
        
        
        // 设置匹配结果（使用Recommendation表的位置）
        searchViewModel.randomRecord = locationRecord
        searchViewModel.isLoading = false
        
    }
    
    // 🎯 新增：加载喜欢记录
    private func loadFavoriteRecords() {
        guard let currentUser = userManager.currentUser else { return }
        let key = StorageKeyUtils.getFavoriteRecordsKey(for: currentUser)
        if let data = UserDefaults.standard.data(forKey: key),
           let records = try? JSONDecoder().decode([FavoriteRecord].self, from: data) {
            favoriteRecords = records
        } else {
            favoriteRecords = []
        }
        let _ = favoriteRecords.filter { $0.status == "active" || $0.status == nil }.map { $0.favoriteUserId }
    }
    
    private func loadUsersWhoLikedMe() {
        guard let currentUser = userManager.currentUser else { return }
        LeanCloudService.shared.fetchActiveFavoriteRecords(favoriteUserId: currentUser.id) { favoriteRecordsData, error in
            DispatchQueue.main.async {
                if let favoriteRecordsData = favoriteRecordsData {
                    let records = favoriteRecordsData.compactMap { FavoriteRecord(dictionary: $0) }
                    self.usersWhoLikedMe = records
                    records.forEach { record in
                    }
                } else {
                    self.usersWhoLikedMe = []
                }
                let _ = self.usersWhoLikedMe.filter { $0.status == "active" || $0.status == nil }.map { $0.userId }
            }
        }
    }
    
    // 🎯 新增：添加喜欢记录（点亮爱心按钮）
    private func addFavoriteRecord(userId: String, userName: String?, userEmail: String?, loginType: String?, userAvatar: String?, recordObjectId: String?) {
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        // 🎯 检查24小时内好友申请数量限制（在点击时检查，不依赖API结果）
        let (canSend, errorMessage) = UserDefaultsManager.canSendFriendRequest()
        if !canSend {
            // 超过限制，显示弹窗提示，不执行任何操作
            // 注意：SearchView 中没有 stateManager，需要通过 NotificationCenter 发送通知
            NotificationCenter.default.post(
                name: NSNotification.Name("FriendRequestLimitExceeded"),
                object: nil,
                userInfo: ["message": errorMessage, "showAlert": true]
            )
            return
        }
        
        // 🎯 立即记录发送时间（在点击时记录，不依赖API结果）
        let _ = UserDefaultsManager.getFriendRequestCountInLast24Hours()
        UserDefaultsManager.recordFriendRequestSent(to: userId)
        
        // 检查是否已经喜欢过
        if favoriteRecords.contains(where: { $0.favoriteUserId == userId && ($0.status == "active" || $0.status == nil) }) {
            return
        }
        
        // 创建新的喜欢记录
        let favoriteRecord = FavoriteRecord(
            userId: currentUser.id, // 🔧 统一：使用 objectId（与 UserNameRecord、UserAvatarRecord 一致）
            favoriteUserId: userId,
            favoriteUserName: userName,
            favoriteUserEmail: userEmail,
            favoriteUserLoginType: loginType,
            favoriteUserAvatar: userAvatar,
            recordObjectId: recordObjectId,
            status: "active"
        )
        
        // 添加到数组
        favoriteRecords.append(favoriteRecord)
        
        // 保存到 UserDefaults
        saveFavoriteRecords()
        
        // 发送通知，更新UI
        NotificationCenter.default.post(name: NSNotification.Name("RefreshMatchStatus"), object: nil)
    }
    
    // 🎯 新增：移除喜欢记录（取消点亮爱心按钮）
    private func removeFavoriteRecord(userId: String) {
        guard userManager.currentUser != nil else { return }
        
        // 移除喜欢记录
        favoriteRecords.removeAll { $0.favoriteUserId == userId }
        
        // 保存到 UserDefaults
        saveFavoriteRecords()
        
        // 发送通知，更新UI
        NotificationCenter.default.post(name: NSNotification.Name("RefreshMatchStatus"), object: nil)
    }
    
    // 🎯 新增：保存喜欢记录到 UserDefaults
    private func saveFavoriteRecords() {
        guard let currentUser = userManager.currentUser else { return }
        let key = StorageKeyUtils.getFavoriteRecordsKey(for: currentUser)
        if let data = try? JSONEncoder().encode(favoriteRecords) {
            UserDefaults.standard.set(data, forKey: key)
        } else {
        }
    }
    
    // MARK: - Report Management Methods
    
    /// 保存举报记录到本地
    func saveReportRecords() {
        if let data = try? JSONEncoder().encode(reportRecords) {
            UserDefaults.standard.set(data, forKey: StorageKeyUtils.getReportRecordsKey(for: userManager.currentUser))
        }
    }
    
    /// 从本地加载举报记录
    func loadReportRecords() {
        reportRecords.removeAll()
        if let data = UserDefaults.standard.data(forKey: StorageKeyUtils.getReportRecordsKey(for: userManager.currentUser)),
           let records = try? JSONDecoder().decode([ReportRecord].self, from: data) {
            reportRecords = records
        }
    }
    
    /// 添加举报记录
    func addReportRecord(reportedUserId: String, reportedUserName: String?, reportedUserEmail: String?, reportReason: String, reportedDeviceId: String? = nil, reportedUserLoginType: String? = nil) {
        
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        let newReport = ReportRecord(
            reportedUserId: reportedUserId,
            reportedUserName: reportedUserName,
            reportedUserEmail: reportedUserEmail,
            reportReason: reportReason,
            reporterUserId: currentUser.id,
            reporterUserName: currentUser.fullName
        )
        
        // 保存到本地
        reportRecords.append(newReport)
        saveReportRecords()
        
        // 获取举报者头像信息 - 基于用户类型设置默认头像
        // 统一使用随机或已分配的自定义emoji头像
        let reporterAvatar: String = {
            if let saved = UserDefaultsManager.getCustomAvatar(userId: currentUser.id) {
                return saved
            }
            let rand = EmojiList.allEmojis.randomElement() ?? "🙂"
            UserDefaultsManager.setCustomAvatar(userId: currentUser.id, emoji: rand)
            return rand
        }()
        
        // 🎯 修改：使用 fetchUserAvatarByUserId，不依赖 loginType，直接从 UserAvatarRecord 表获取
        let tryFetchReportedAvatar = !reportedUserId.isEmpty
        if tryFetchReportedAvatar {
            LeanCloudService.shared.fetchUserAvatarByUserId(objectId: reportedUserId) { fetchedAvatar, _ in
                let loginType = reportedUserLoginType ?? "guest"
                let finalReportedAvatar = (fetchedAvatar?.isEmpty == false) ? fetchedAvatar! : UserAvatarUtils.defaultAvatar(for: loginType)

                let reportData: [String: Any] = [
                    "reported_user_id": reportedUserId, // 🎯 修改：使用 reportedUserId 而不是 reportedDeviceId
                    "reported_user_name": reportedUserName ?? "",
                    "reported_user_email": reportedUserEmail ?? "",
                    "reported_user_login_type": reportedUserLoginType ?? "unknown",
                    "reported_user_avatar": finalReportedAvatar,
                    "report_reason": reportReason,
                    "report_time": ISO8601DateFormatter().string(from: Date()),
                    "reporter_user_id": currentUser.id,
                    "reporter_user_name": currentUser.fullName,
                    "reporter_user_avatar": reporterAvatar
                ]

                LeanCloudService.shared.uploadReportRecord(reportData: reportData) { success, message in
                    DispatchQueue.main.async {
                        if success {
                            // 举报记录上传成功
                        } else {
                            // 举报记录上传失败
                        }
                    }
                }
            }
        } else {
            // 无法查询真实头像时，使用通用头像占位
            let reportData: [String: Any] = [
                "reported_user_id": reportedUserId, // 🎯 修改：使用 reportedUserId 而不是 reportedDeviceId
                "reported_user_name": reportedUserName ?? "",
                "reported_user_email": reportedUserEmail ?? "",
                "reported_user_login_type": reportedUserLoginType ?? "unknown",
                "reported_user_avatar": UserAvatarUtils.defaultAvatar(for: reportedUserLoginType ?? "guest"),
                "report_reason": reportReason,
                "report_time": ISO8601DateFormatter().string(from: Date()),
                "reporter_user_id": currentUser.id,
                "reporter_user_name": currentUser.fullName,
                "reporter_user_avatar": reporterAvatar
            ]

            LeanCloudService.shared.uploadReportRecord(reportData: reportData) { success, message in
                DispatchQueue.main.async {
                    if success {
                        // 举报记录上传成功
                    } else {
                        // 举报记录上传失败
                    }
                }
            }
        }
    }
    
    /// 检查是否已举报过该用户
    func hasReportedUser(_ userId: String) -> Bool {
        return ReportHelpers.hasReportedUser(userId, reportRecords: reportRecords)
    }
    
    private func configureDiamondManager() {
        guard let currentUser = userManager.currentUser else { return }
        let loginTypeString: String
        switch currentUser.loginType {
        case .apple: loginTypeString = "apple"
        case .guest: loginTypeString = "guest"
        }
        diamondManager.setCurrentUser(
            userId: currentUser.id,
            loginType: loginTypeString,
            userName: currentUser.fullName,
            userEmail: currentUser.email
        )
    }
}
