import SwiftUI

struct SearchTopNavigationBar: View {
    @ObservedObject var userManager: UserManager
    @ObservedObject var diamondManager: DiamondManager
    @Binding var unreadMessageCount: Int
    let onProfileTap: () -> Void
    let onRechargeTap: () -> Void
    let onRankingTap: () -> Void
    let onMessageTap: () -> Void
    @ObservedObject private var patMessageUpdateManager = PatMessageUpdateManager.shared
    @State private var userAvatarFromServer: String? = nil
    @State private var showRankingLimitAlert = false
    @State private var rankingLimitMessage = ""
    @State private var isColorfulModeEnabled: Bool = false // 🎯 新增：彩色模式开关状态
    @State private var hasLoadedColorfulMode: Bool = false // 🎯 新增：是否已加载彩色模式状态
    // 🎯 移除：userNameFromServer 不再需要，直接使用 userManager.userNameFromServer（与个人信息界面共享）
    // 🎯 移除：diamondsFromServer 不再需要，使用 diamondManager.diamonds（通过 DiamondStore 自动同步）
    
    private var totalPatBadgeCount: Int {
        guard let currentUserId = userManager.currentUser?.id else { return 0 }
        return patMessageUpdateManager.getTotalUnreadPatCount(forReceiverId: currentUserId)
    }
    
    private var displayedUnreadCount: Int {
        let baseCount = unreadMessageCount
        let patBadge = totalPatBadgeCount
        return baseCount + patBadge
    }
    
    // 🔧 新增：从服务器加载用户数据的方法 - 🎯 统一从 UserAvatarRecord 和 UserNameRecord 表获取
    private func loadUserDataFromServer() {
        // 🔧 统一使用 objectId 作为 userId
        guard let userId = userManager.currentUser?.id else { return }
        
        // 🎯 修改：使用 fetchUserAvatarByUserId，不依赖 loginType，直接从 UserAvatarRecord 表获取
        LeanCloudService.shared.fetchUserAvatarByUserId(objectId: userId) { avatar, _ in
            DispatchQueue.main.async {
                if let avatar = avatar, !avatar.isEmpty {
                    // 🔍 检查 UserDefaults 与服务器数据是否一致，自动同步更新
                    let userDefaultsAvatar = UserDefaultsManager.getCustomAvatar(userId: userId)
                    if let defaultsAvatar = userDefaultsAvatar, !defaultsAvatar.isEmpty {
                        if defaultsAvatar != avatar {
                            // 🔧 自动更新 UserDefaults 以保持一致性
                            UserDefaultsManager.setCustomAvatar(userId: userId, emoji: avatar)
                        }
                    } else {
                        UserDefaultsManager.setCustomAvatar(userId: userId, emoji: avatar)
                    }
                    // 更新头像显示
                    self.userAvatarFromServer = avatar
                }
            }
        }
        // 🎯 移除：不再自己查询用户名，直接使用 UserManager 的共享状态（由个人信息界面负责查询和更新）
        // 🎯 修改：DiamondStore 会在 setCurrentUser 时自动初始化并刷新
        // 这里只需要手动刷新一次（如果需要）
        // 钻石查询已由 DiamondStore 自动处理
    }
    
    var body: some View {
        HStack {
            // 用户头像 - 可点击放大（优先使用 UserAvatarRecord）
            Button(action: onProfileTap) {
                if let avatar = userAvatarFromServer, !avatar.isEmpty {
                    if avatar == "apple_logo" || avatar == "applelogo" {
                        Image(systemName: "applelogo")
                            .font(.system(size: 24))
                            .foregroundColor(.black)
                    } else if UserAvatarUtils.isSFSymbol(avatar) {
                        // 🔧 修复：检查是否是 SF Symbol，如果是则显示图标而不是文字
                        Image(systemName: avatar)
                            .font(.system(size: 24))
                            .foregroundColor(avatar == "person.circle.fill" ? ((userManager.currentUser?.loginType == .apple) ? .purple : .blue) : .blue)
                    } else {
                        Text(avatar)
                            .font(.system(size: 24))
                            .fixedSize(horizontal: true, vertical: false)
                    }
                } else if let userId = userManager.currentUser?.id,
                          let customAvatar = UserDefaultsManager.getCustomAvatar(userId: userId) {
                    if customAvatar == "applelogo" || customAvatar == "apple_logo" {
                        Image(systemName: "applelogo")
                            .font(.system(size: 24))
                            .foregroundColor(.black)
                    } else if UserAvatarUtils.isSFSymbol(customAvatar) {
                        // 🔧 修复：检查是否是 SF Symbol，如果是则显示图标而不是文字
                        Image(systemName: customAvatar)
                            .font(.system(size: 24))
                            .foregroundColor(customAvatar == "person.circle.fill" ? ((userManager.currentUser?.loginType == .apple) ? .purple : .blue) : .blue)
                    } else {
                        Text(customAvatar)
                            .font(.system(size: 24))
                            .fixedSize(horizontal: true, vertical: false)
                    }
                } else if let loginType = userManager.currentUser?.loginType {
                    // Apple账号与内部账号使用相同的默认头像
                    if loginType == .apple {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.purple)
                            .font(.system(size: 24))
                    } else {
                        Image(systemName: "person.circle")
                            .foregroundColor(.blue)
                            .font(.system(size: 24))
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("用户头像")
            .accessibilityHint("点击查看个人信息")
            
            // 用户名称 - 可点击进入个人信息（优先使用 UserNameRecord）
            Button(action: onProfileTap) {
                VStack(alignment: .leading, spacing: 2) {
                    // 🎯 修改：直接使用 UserManager 的共享状态，与个人信息界面同步
                    let displayedName = userManager.userNameFromServer ?? (userManager.currentUser?.fullName ?? "用户")
                    let userNameText = Text(displayedName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    // 🎯 新增：根据 UserNameRecord 的 colorfulModeEnabled 字段决定是否显示彩色
                    if isColorfulModeEnabled {
                        userNameText.animatedGradientText()
                    } else {
                        userNameText
                    }
                    
                    // 显示用户类型
                    if let loginType = userManager.currentUser?.loginType {
                        let loginTypeText = loginType == .apple ? "Apple账号" : "游客模式"
                        Text(loginTypeText)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("个人信息")
            .accessibilityHint("点击查看和编辑个人信息")
            .onAppear {
                loadUserDataFromServer()
                
                // 🎯 新增：从 UserNameRecord 查询彩色模式状态
                if !hasLoadedColorfulMode {
                    loadColorfulModeFromServer()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserNameUpdated"))) { notification in
                // 🔧 新增：监听用户名更新通知
                if let userInfo = notification.userInfo,
                   let updatedUserId = userInfo["userId"] as? String,
                   let currentUserId = userManager.currentUser?.id,
                   updatedUserId == currentUserId {
                    // 🎯 修改：UserManager 的 userNameFromServer 已经更新，这里只需要清除缓存
                    // 清除用户名缓存，确保下次查询时获取最新数据
                    LeanCloudService.shared.clearCacheForUser(currentUserId)
                }
                // 重新加载用户数据以确保同步（只加载头像，用户名由 UserManager 管理）
                loadUserDataFromServer()
            }
            // 🔧 修复：监听头像更新通知，立即更新显示
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserAvatarUpdated"))) { notification in
                if let userInfo = notification.userInfo,
                   let newAvatar = userInfo["avatar"] as? String,
                   let userId = userInfo["userId"] as? String,
                   let currentUserId = userManager.currentUser?.id,
                   userId == currentUserId {
                    // 立即更新头像显示
                    self.userAvatarFromServer = newAvatar
                }
            }
            // 🎯 新增：监听彩色模式更新通知
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ColorfulModeUpdated"))) { notification in
                if let userInfo = notification.userInfo,
                   let userId = userInfo["userId"] as? String,
                   let enabled = userInfo["enabled"] as? Bool,
                   let currentUserId = userManager.currentUser?.id,
                   userId == currentUserId {
                    // 立即更新彩色模式显示
                    self.isColorfulModeEnabled = enabled
                    // 更新 UserDefaults 缓存
                    UserDefaultsManager.setColorfulModeEnabled(userId: userId, enabled: enabled)
                }
            }
            
            Spacer()
            
            // 钻石显示 - 可点击进入充值界面
            Button(action: onRechargeTap) {
                HStack(spacing: 5) {
                    Text("💎")
                        .font(.caption)
                    // 🎯 优化：始终显示数字，使用动画过渡，避免加载状态闪烁
                    Text("\(diamondManager.diamonds)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                        .lineLimit(1)
                        .id(diamondManager.diamonds) // 使用 id 触发平滑过渡
                }
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)
                .animation(.easeInOut(duration: 0.3), value: diamondManager.diamonds) // 平滑过渡
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("钻石余额：\(diamondManager.diamonds)")
            .accessibilityHint("点击进入充值页面")
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
                    onRankingTap()
                    return
                }
                
                let (canClick, message) = UserDefaultsManager.canClickRankingButton(userId: userId)
                if canClick {
                    // 记录点击
                    UserDefaultsManager.recordRankingButtonClick(userId: userId)
                    // 打开排行榜
                    onRankingTap()
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
            .accessibilityLabel("排行榜")
            .accessibilityHint("点击查看排行榜")
            .alert("排行榜访问限制", isPresented: $showRankingLimitAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(rankingLimitMessage)
            }
            
            // 消息按钮
            Button(action: onMessageTap) {
                ZStack(alignment: .topTrailing) {
                    Text("消息")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .cornerRadius(8)
                    
                    // 未读消息数量徽章
                    if displayedUnreadCount > 0 {
                        Text("\(displayedUnreadCount)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .clipShape(Circle())
                            .offset(x: 6, y: -6)
                            .zIndex(1)
                            .onAppear {
                            }
                    }
                }
            }
            .accessibilityLabel(displayedUnreadCount > 0 ? "消息，有\(displayedUnreadCount)条未读" : "消息")
            .accessibilityHint("点击查看消息列表")
        }
        .padding(.horizontal)
    }
    
    // 🎯 新增：从服务器加载彩色模式状态
    private func loadColorfulModeFromServer() {
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        let userId = currentUser.id
        let loginTypeString = currentUser.loginType == .apple ? "apple" : "guest"
        
        // 首先尝试从 UserDefaults 获取缓存
        if let cachedValue = UserDefaultsManager.getColorfulModeEnabled(userId: userId) {
            DispatchQueue.main.async {
                self.isColorfulModeEnabled = cachedValue
                self.hasLoadedColorfulMode = true
            }
            return
        }
        
        // 如果缓存不存在，从服务器查询
        LeanCloudService.shared.fetchColorfulModeEnabled(
            objectId: userId,
            loginType: loginTypeString
        ) { isEnabled in
            DispatchQueue.main.async {
                if let isEnabled = isEnabled {
                    self.isColorfulModeEnabled = isEnabled
                    // 更新 UserDefaults 缓存
                    UserDefaultsManager.setColorfulModeEnabled(userId: userId, enabled: isEnabled)
                } else {
                    // 如果查询失败或字段不存在，默认为 false
                    self.isColorfulModeEnabled = false
                    UserDefaultsManager.setColorfulModeEnabled(userId: userId, enabled: false)
                }
                self.hasLoadedColorfulMode = true
            }
        }
    }
}
