import SwiftUI
import LeanCloud

// 用户基本信息显示部分
extension ProfileView {
    // 头像显示组件
    var avatarView: some View {
        Button(action: {
            showAvatarZoom = true
        }) {
            avatarDisplayView
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            // 与用户头像界面一致：在onAppear时加载服务器头像
            loadAvatarFromServer()
        }
        .task {
            // 🎯 新增：检查查询是否失败，如果失败则重试
            try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 / 7.0)) // 1/7秒
            // 检查是否查询失败（userAvatarFromServer 为 nil）且未达到最大重试次数
            let shouldRetry = userAvatarFromServer == nil && avatarRetryCount < 2
            if shouldRetry {
                retryLoadAvatarFromServer()
            }
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
    }
    
    // 头像显示逻辑：与用户头像界面一致 - 优先使用服务器数据，其次使用UserDefaults，最后使用默认图标
    @ViewBuilder
    private var avatarDisplayView: some View {
        
        // 优先使用从服务器读取的头像
        if let avatarFromServer = userAvatarFromServer, !avatarFromServer.isEmpty {
            if avatarFromServer == "apple_logo" || avatarFromServer == "applelogo" {
                Image(systemName: "applelogo")
                    .font(.system(size: 40))
                    .foregroundColor(.black)
                    .onAppear {
                    }
            } else if UserAvatarUtils.isSFSymbol(avatarFromServer) {
                // 🔧 修复：检查是否是 SF Symbol，如果是则显示图标而不是文字
                Image(systemName: avatarFromServer)
                    .font(.system(size: 40))
                    .foregroundColor((userManager.currentUser?.loginType == .apple) ? .purple : .blue)
                    .onAppear {
                    }
            } else {
                Text(avatarFromServer)
                    .font(.system(size: 40))
                    .fixedSize(horizontal: true, vertical: false)
                    .onAppear {
                    }
            }
        } else if let userId = userManager.currentUser?.id,
                  let customAvatar = UserDefaultsManager.getCustomAvatar(userId: userId) {
            // 使用 UserDefaults 中的头像作为后备
            if customAvatar == "applelogo" || customAvatar == "apple_logo" {
                Image(systemName: "applelogo")
                    .font(.system(size: 40))
                    .foregroundColor(.black)
                    .onAppear {
                    }
            } else if UserAvatarUtils.isSFSymbol(customAvatar) {
                // 🔧 修复：检查是否是 SF Symbol，如果是则显示图标而不是文字
                Image(systemName: customAvatar)
                    .font(.system(size: 40))
                    .foregroundColor((userManager.currentUser?.loginType == .apple) ? .purple : .blue)
                    .onAppear {
                    }
            } else {
                Text(customAvatar)
                    .font(.system(size: 40))
                    .fixedSize(horizontal: true, vertical: false)
                    .onAppear {
                    }
            }
        } else {
            // 显示默认头像 - Apple账号使用默认头像
            let loginType = userManager.currentUser?.loginType
            let iconName = (loginType == .apple) ? "person.circle.fill" : "person.circle"
            let iconColor = (loginType == .apple) ? Color.purple : Color.blue
            
            
            Image(systemName: iconName)
                .font(.system(size: 40))
                .foregroundColor(iconColor)
                .onAppear {
                }
        }
    }
    
    // 从服务器加载头像 - 🎯 统一从 UserAvatarRecord 表获取
    private func loadAvatarFromServer() {
        // 🔧 统一使用 objectId 作为 userId
        guard let userId = userManager.currentUser?.id else {
            return
        }
        
        // 🎯 修改：使用 fetchUserAvatarByUserId，不依赖 loginType，直接从 UserAvatarRecord 表获取
        LeanCloudService.shared.fetchUserAvatarByUserId(objectId: userId) { avatar, error in
            DispatchQueue.main.async {
                if error != nil {
                } else if let avatar = avatar, !avatar.isEmpty {
                    // 🔍 检查 UserDefaults 与服务器数据是否一致
                    let userDefaultsAvatar = UserDefaultsManager.getCustomAvatar(userId: userId)
                    if let defaultsAvatar = userDefaultsAvatar, !defaultsAvatar.isEmpty {
                        if defaultsAvatar != avatar {
                            // 🔧 自动更新 UserDefaults 以保持一致性
                            UserDefaultsManager.setCustomAvatar(userId: userId, emoji: avatar)
                        } else {
                        }
                    } else {
                        UserDefaultsManager.setCustomAvatar(userId: userId, emoji: avatar)
                    }
                    // 更新头像显示
                    userAvatarFromServer = avatar
                } else {
                    // 🎯 修改：查询失败时，如果 userAvatarFromServer 仍为 nil 且未达到最大重试次数，触发第二次重试
                    if self.userAvatarFromServer == nil && self.avatarRetryCount < 2 {
                        self.retryLoadAvatarFromServer()
                    }
                }
            }
        }
    }
    
    // 🎯 新增：重试查询头像（最多重试2次）
    private func retryLoadAvatarFromServer() {
        guard avatarRetryCount < 2 else {
            return
        }
        avatarRetryCount += 1
        
        // 🎯 修改：根据重试次数决定延迟时间
        // 第一次重试：延迟1/17秒；第二次重试：延迟0.5秒
        let delay: TimeInterval = avatarRetryCount == 1 ? 1.0 / 17.0 : 0.5
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // 检查 avatarFromServer 是否为 nil（查询失败的情况）
            if self.userAvatarFromServer == nil {
                self.loadAvatarFromServer()
            }
        }
    }
    
    // 打印当前用户的UserAvatarRecord记录
    private func printCurrentUserAvatarRecord(userManager: UserManager) {
        // 🔧 统一使用 objectId 作为 userId
        guard let userId = userManager.currentUser?.id,
              userManager.currentUser?.loginType != nil else {
            return
        }
        
        
        // 🔧 统一使用 objectId 作为 userId
        let displayedAvatar = UserDefaultsManager.getCustomAvatar(userId: userManager.currentUser?.id ?? "") ?? "默认头像"
        
        // 🎯 修改：使用 fetchUserAvatarByUserId，不依赖 loginType，直接从 UserAvatarRecord 表获取
        LeanCloudService.shared.fetchUserAvatarByUserId(objectId: userId) { avatar, error in
            if error != nil {
            } else if let avatar = avatar {
                // 对比显示的头像和数据库记录
                if avatar != displayedAvatar && displayedAvatar != "默认头像" {
                }
            } else {
            }
        }
    }
    
    // 优先使用 UserNameRecord 表中的用户名，否则使用 UserManager 中的用户名
    // 🎯 修改：优先使用 UserManager 的共享状态，确保与主页面同步
    private var displayedUserName: String {
        if let serverName = userManager.userNameFromServer, !serverName.isEmpty {
            return serverName
        } else if let localServerName = userNameFromServer, !localServerName.isEmpty {
            return localServerName
        } else {
            return userManager.currentUser?.fullName ?? "用户"
        }
    }
    
    // 从服务器加载用户名 - 🎯 统一从 UserNameRecord 表获取
    private func loadUserNameFromServer() {
        // 🔧 统一使用 objectId 作为 userId
        guard let userId = userManager.currentUser?.id else {
            return
        }
        
        // 🎯 修改：使用 fetchUserNameByUserId，不依赖 loginType，直接从 UserNameRecord 表获取
        LeanCloudService.shared.fetchUserNameByUserId(objectId: userId) { serverName, error in
            DispatchQueue.main.async {
                if error != nil {
                } else if let serverName = serverName, !serverName.isEmpty {
                    let currentName = userManager.currentUser?.fullName ?? "用户"
                    if serverName != currentName {
                    }
                    // 🎯 修改：同时更新 ProfileView 的本地状态和 UserManager 的共享状态
                    userNameFromServer = serverName
                    userManager.userNameFromServer = serverName
                    
                    // 🎯 新增：检查 UserDefaults 与服务器数据是否一致，自动同步更新（与头像查询逻辑一致）
                    let userDefaultsUserName = UserDefaultsManager.getCurrentUserName()
                    if !userDefaultsUserName.isEmpty {
                        if userDefaultsUserName != serverName {
                            // 🔧 自动更新 UserDefaults 以保持一致性
                            UserDefaultsManager.setCurrentUserName(serverName)
                        }
                    } else {
                        UserDefaultsManager.setCurrentUserName(serverName)
                    }
                } else {
                    // 🎯 修改：查询失败时，如果 userNameFromServer 仍为 nil 且未达到最大重试次数，触发第二次重试
                    if self.userNameFromServer == nil && self.userNameRetryCount < 2 {
                        self.retryLoadUserNameFromServer()
                    }
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
    
    // 用户名显示组件
    var userNameView: some View {
        HStack {
            // 🎯 修复：确保 userId 不为空才使用 ColorfulUserNameText，并添加稳定的标识符
            if let userId = userManager.currentUser?.id, !userId.isEmpty {
                ColorfulUserNameText(
                    userName: displayedUserName,
                    userId: userId,
                    loginType: userManager.currentUser?.loginType == .apple ? "apple" : "guest",
                    font: .title2,
                    fontWeight: .bold,
                    lineLimit: 1,
                    truncationMode: .tail
                )
                .id("userName-\(userId)") // 🎯 添加稳定的标识符，避免重建循环
                .onAppear {
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
                // 🔧 修复：监听用户名更新通知，立即更新显示
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserNameUpdated"))) { notification in
                    if let userInfo = notification.userInfo,
                       let newUserName = userInfo["userName"] as? String,
                       let currentUserId = userManager.currentUser?.id,
                       let updatedUserId = userInfo["userId"] as? String,
                       updatedUserId == currentUserId {
                        // 立即更新用户名显示
                        self.userNameFromServer = newUserName
                        self.userManager.userNameFromServer = newUserName
                        
                        // 清除用户名缓存，确保下次查询时获取最新数据
                        LeanCloudService.shared.clearCacheForUser(currentUserId)
                    }
                }
            } else {
                // 如果 userId 为空，使用普通 Text
                Text(displayedUserName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .onAppear {
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
                    // 🔧 修复：监听用户名更新通知，立即更新显示
                    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserNameUpdated"))) { notification in
                        if let userInfo = notification.userInfo,
                           let newUserName = userInfo["userName"] as? String,
                           let currentUserId = userManager.currentUser?.id,
                           let updatedUserId = userInfo["userId"] as? String,
                           updatedUserId == currentUserId {
                            // 立即更新用户名显示
                            self.userNameFromServer = newUserName
                            self.userManager.userNameFromServer = newUserName
                            
                            // 清除用户名缓存，确保下次查询时获取最新数据
                            LeanCloudService.shared.clearCacheForUser(currentUserId)
                        }
                    }
            }
            
            // 根据用户类型显示不同的编辑按钮
            Button {
                let loginType = userManager.currentUser?.loginType
                if loginType == .guest {
                    // 游客用户显示提示
                    showGuestNameAlert = true
                } else {
                    // Apple ID 用户显示编辑框
                    newUserName = displayedUserName
                    showEditNameAlert = true
                }
            } label: {
                Image(systemName: "pencil.circle")
                    .foregroundColor(.blue)
                    .font(.title3)
            }
        }
    }
    
    // 登录类型显示组件
    var loginTypeView: some View {
        let loginType = userManager.currentUser?.loginType
        let loginTypeText = loginType == .apple ? "Apple账户" : "游客模式"
        
        return Text("🔐 \(loginTypeText)")
            .font(.caption)
            .foregroundColor(.gray)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }
}
