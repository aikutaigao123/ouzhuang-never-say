import SwiftUI

struct SearchViewNew: View {
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var userManager: UserManager
    @Binding var unreadMessageCount: Int
    @StateObject private var diamondManager: DiamondManager
    @StateObject private var searchStateManager: SearchStateManager
    @ObservedObject private var patMessageUpdateManager = PatMessageUpdateManager.shared
    
    var onBack: () -> Void = {}
    @State private var isLoading = false
    @State private var showRankingSheet = false
    @State private var showRankingLimitAlert = false
    @State private var rankingLimitMessage = ""
    
    init(locationManager: LocationManager, userManager: UserManager, unreadMessageCount: Binding<Int>) {
        self.locationManager = locationManager
        self.userManager = userManager
        self._unreadMessageCount = unreadMessageCount
        let sharedDiamondManager = DiamondManager.shared
        self._diamondManager = StateObject(wrappedValue: sharedDiamondManager)
        
        // 初始化 SearchStateManager
        self._searchStateManager = StateObject(wrappedValue: SearchStateManager(userManager: userManager))
    }
    @State private var randomRecord: LocationRecord?
    @State private var showRechargeSheet = false
    // 🎯 移除：diamondsFromServer 不再需要，使用 diamondManager.diamonds（通过 DiamondStore 自动同步）
    @State private var userNameFromServer: String? = nil // 从 UserNameRecord 表读取的用户名
    @State private var userNameRetryCount: Int = 0 // 🎯 新增：用户名重试次数（最多重试2次）
    
    // 优先使用 UserNameRecord 表中的用户名，否则使用 UserManager 中的用户名
    private var displayedUserName: String {
        let result: String
        if let serverName = userNameFromServer, !serverName.isEmpty {
            result = serverName
        } else {
            result = userManager.currentUser?.fullName ?? "未知用户"
        }
        return result
    }
    
    private var totalPatBadgeCount: Int {
        guard let currentUserId = userManager.currentUser?.id else { return 0 }
        return patMessageUpdateManager.getTotalUnreadPatCount(forReceiverId: currentUserId)
    }
    
    private var displayedMessageBadgeCount: Int {
        unreadMessageCount + totalPatBadgeCount
    }
    
    var body: some View {
        VStack {
            // 顶部导航栏 - 简化版
            HStack {
                // 用户头像
                Button(action: {}) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }
                
                // 用户名称
                ColorfulUserNameText(
                    userName: displayedUserName,
                    userId: userManager.currentUser?.id ?? "",
                    loginType: userManager.currentUser?.loginType == .apple ? "apple" : "guest",
                    font: .headline,
                    fontWeight: .semibold,
                    lineLimit: 1,
                    truncationMode: .tail
                )
                .onAppear {
                    // 与用户头像界面一致：在onAppear时实时查询服务器用户名
                    loadUserNameFromServer()
                }
                .task {
                    // 🎯 新增：检查查询是否失败，如果失败则重试
                    try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 / 7.0)) // 1/7秒
                    // 检查是否查询失败（userNameFromServer 为 nil）且未达到最大重试次数
                    let shouldRetry = userNameFromServer == nil && userNameRetryCount < 2
                    if shouldRetry {
                        retryLoadUserNameFromServer()
                    }
                }
                
                Spacer()
                
                // 钻石显示
                Button(action: { showRechargeSheet = true }) {
                    HStack(spacing: 5) {
                        Text("💎")
                            .font(.caption)
                        // 🎯 优化：始终显示数字，使用动画过渡，避免加载状态闪烁
                        Text("\(diamondManager.diamonds)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.purple)
                            .id(diamondManager.diamonds) // 使用 id 触发平滑过渡
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(8)
                    .animation(.easeInOut(duration: 0.3), value: diamondManager.diamonds) // 平滑过渡
                }
                .onAppear {
                    // 🎯 优化：后台刷新（不显示加载状态）
                    diamondManager.diamondStore?.refreshBalanceInBackground()
                }
                .task {
                    // 🔧 新增：检查钻石数是否为0，如果是则重试（类似用户名重试机制）
                    try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 / 7.0)) // 1/7秒
                    // 检查钻石数是否为0且未达到最大重试次数
                    let shouldRetry = diamondManager.isShowingZeroDiamonds && diamondManager.diamondRetryCount < 2
                    if shouldRetry {
                        diamondManager.retryLoadDiamondsFromServer()
                    }
                }
                
                
                                    // 排行榜按钮
                    Button(action: {
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
                    }) {
                    Text("排行榜")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .fixedSize()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange)
                        .cornerRadius(8)
                }
                .alert("排行榜访问限制", isPresented: $showRankingLimitAlert) {
                    Button("确定", role: .cancel) { }
                } message: {
                    Text(rankingLimitMessage)
                }
                
                // 消息按钮
                Button(action: {}) {
                    ZStack(alignment: .topTrailing) {
                        Text("消息")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .cornerRadius(8)
                        
                        if displayedMessageBadgeCount > 0 {
                            Text("\(displayedMessageBadgeCount)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .clipShape(Circle())
                                .offset(x: 6, y: -6)
                                .onAppear {
                                }
                        }
                    }
                }
            }
            .padding(.horizontal)
            
            // 指南针容器
            SearchCompassContainer(
                locationManager: locationManager,
                randomRecord: randomRecord
            )
            
            // 寻找按钮
            SearchButton(
                locationManager: locationManager,
                diamondManager: diamondManager,
                isLoading: $isLoading,
                isUserBlacklisted: $searchStateManager.isUserBlacklisted,
                onSearch: {
                    // 简化的搜索逻辑
                    isLoading = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isLoading = false
                        // 这里可以添加实际的搜索逻辑
                    }
                },
                onRecharge: {
                    showRechargeSheet = true
                }
            )
            .padding(.top, 20)
            
            // 消耗钻石说明
            if !isLoading && !searchStateManager.isUserBlacklisted {
                SearchUIComponents.diamondCostHint()
            }
            
            // 位置状态提示
            if locationManager.location == nil && !isLoading && !searchStateManager.isUserBlacklisted {
                SearchUIComponents.locationStatusHint()
            }
            
            // 倒计时显示
            if searchStateManager.isUserBlacklisted && !searchStateManager.timeRemaining.isEmpty {
                SearchUIComponents.timeRemainingHint(searchStateManager.timeRemaining)
            }
            
            // 匹配结果卡片 - 简化版
            if let record = randomRecord {
                MatchResultCard(
                    record: record,
                    locationManager: locationManager,
                    userManager: userManager,
                    latestAvatars: [:],
                    latestUserNames: [:],
                    isUserFavorited: { _ in false },
                    isUserFavoritedByMe: { _ in false },
                    isLocationRecordLiked: { _ in false },
                    addFavoriteRecord: { _, _, _, _, _, _ in },
                    removeFavoriteRecord: { _ in },
                    addLikeRecord: { _, _, _, _, _, _, _ in },
                    removeLikeRecord: { _, _, _ in },
                    showMapSelectionForLocation: { _ in },
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
                    showFriendRequestModal: {},
                    selectedTab: 0,
                    copySuccessMessage: "",
                    showCopySuccess: false,
                    setCopySuccessMessage: { _ in },
                    setShowCopySuccess: { _ in },
                    ensureFavoriteState: {
                        FriendshipManager.shared.fetchFriendsList { _, _ in }
                    },
                    onDeleteRecommendation: nil // 🎯 新增：SearchViewNew中暂不支持删除
                )
            } else {
                // 无匹配结果时的占位符
                VStack(spacing: 8) {
                    Text("--")
                        .font(.body)
                        .foregroundColor(.gray)
                        .fontWeight(.medium)
                }
                .padding(.top, 16)
            }
            
            // 复制成功提示
            if searchStateManager.showCopySuccess {
                VStack {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 18))
                        Text(searchStateManager.copySuccessMessage)
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
                .animation(.easeInOut(duration: 0.3), value: searchStateManager.showCopySuccess)
                .zIndex(1000)
            }
        }
        .padding()
        .onAppear {
            configureDiamondManager()
            // 连接钻石管理器与用户管理器
            userManager.diamondManager = diamondManager
            
            // 进入页面时再次请求位置
            locationManager.requestLocation()
            // 启动方向更新
            locationManager.startHeadingUpdates()
            // 加载黑名单
            searchStateManager.loadBlacklist()
        }
        .onDisappear {
            // 离开页面时停止方向更新
            locationManager.stopHeadingUpdates()
            // 停止倒计时定时器
            searchStateManager.stopCountdownTimer()
        }
        .sheet(isPresented: $showRechargeSheet) {
            RechargeView(diamondManager: diamondManager)
        }
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
    
    // 从服务器加载用户名
    private func loadUserNameFromServer() {
        guard let userId = userManager.currentUser?.id else {
            return
        }
        
        // 🎯 修改：使用 fetchUserNameByUserId，不依赖 loginType，直接从 UserNameRecord 表获取
        LeanCloudService.shared.fetchUserNameByUserId(objectId: userId) { name, error in
            DispatchQueue.main.async {
                if error != nil {
                    // 加载失败
                } else if let name = name, !name.isEmpty {
                    self.userNameFromServer = name
                    
                    // 🎯 新增：检查 UserDefaults 与服务器数据是否一致，自动同步更新（与个人信息界面一致）
                    let userDefaultsUserName = UserDefaultsManager.getCurrentUserName()
                    if !userDefaultsUserName.isEmpty {
                        if userDefaultsUserName != name {
                            // 🔧 自动更新 UserDefaults 以保持一致性
                            UserDefaultsManager.setCurrentUserName(name)
                        }
                    } else {
                        UserDefaultsManager.setCurrentUserName(name)
                    }
                } else {
                    // 服务器返回的用户名为空
                }
            }
        }
    }
    
    // 🎯 新增：重试查询用户名（最多重试2次）
    private func retryLoadUserNameFromServer() {
        guard userNameRetryCount < 2 else {
            return
        }
        userNameRetryCount += 1
        
        // 🎯 修改：根据重试次数决定延迟时间
        // 第一次重试：延迟1/17秒；第二次重试：延迟0.5秒
        let delay: TimeInterval = userNameRetryCount == 1 ? 1.0 / 17.0 : 0.5
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // 检查 userNameFromServer 是否为 nil（查询失败的情况）
            if self.userNameFromServer == nil {
                self.loadUserNameFromServer()
            }
        }
    }
}
