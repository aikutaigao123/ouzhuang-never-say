import SwiftUI

// MARK: - Preview Card Header Components
extension AvatarZoomView {
    
    // 预览卡片头部
    struct PreviewCardHeaderView: View {
        let displayAvatar: String?
        let userManager: UserManager
        @Binding var isHeartClicked: Bool
        @State private var avatarFromServer: String? = nil
        @State private var userNameFromServer: String? = nil
        @State private var avatarRetryCount: Int = 0 // 🎯 新增：头像重试次数（最多重试2次）
        @State private var userNameRetryCount: Int = 0 // 🎯 新增：用户名重试次数（最多重试2次）
        
        var body: some View {
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.05)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 120)
            .overlay(previewCardUserInfo)
            .onAppear {
                // 🔧 统一使用 objectId 作为 userId
                guard let userId = userManager.currentUser?.id else { return }
                
                // 🎯 修改：使用 fetchUserAvatarByUserId，不依赖 loginType，直接从 UserAvatarRecord 表获取
                LeanCloudService.shared.fetchUserAvatarByUserId(objectId: userId) { avatar, _ in
                    DispatchQueue.main.async {
                        if let avatar = avatar, !avatar.isEmpty {
                            self.avatarFromServer = avatar
                        } else {
                            // 🎯 修改：查询失败时，如果 avatarFromServer 仍为 nil 且未达到最大重试次数，触发第二次重试
                            if self.avatarFromServer == nil && self.avatarRetryCount < 2 {
                                self.retryLoadAvatarFromServer(userId: userId)
                            }
                        }
                    }
                }
                // 🎯 修改：使用 fetchUserNameByUserId，不依赖 loginType，直接从 UserNameRecord 表获取
                LeanCloudService.shared.fetchUserNameByUserId(objectId: userId) { name, _ in
                    DispatchQueue.main.async {
                        if let name = name, !name.isEmpty {
                            self.userNameFromServer = name
                        } else {
                            // 🎯 修改：查询失败时，如果 userNameFromServer 仍为 nil 且未达到最大重试次数，触发第二次重试
                            if self.userNameFromServer == nil && self.userNameRetryCount < 2 {
                                self.retryLoadUserNameFromServer(userId: userId)
                            }
                        }
                    }
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
                    self.avatarFromServer = newAvatar
                }
            }
            // 🔧 修复：监听 displayAvatar 的变化，当本地头像更新时同步更新 avatarFromServer
            .onChange(of: displayAvatar) { _, newAvatar in
                if let newAvatar = newAvatar, !newAvatar.isEmpty {
                    // 当本地头像更新时（如随机解锁），立即更新 avatarFromServer 以确保显示正确
                    avatarFromServer = newAvatar
                }
            }
            .task {
                // 🎯 新增：检查查询是否失败，如果失败则重试
                guard let userId = userManager.currentUser?.id else { return }
                try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 / 7.0)) // 1/7秒
                // 检查是否查询失败且未达到最大重试次数
                let shouldRetryAvatar = avatarFromServer == nil && avatarRetryCount < 2
                let shouldRetryUserName = userNameFromServer == nil && userNameRetryCount < 2
                if shouldRetryAvatar {
                    retryLoadAvatarFromServer(userId: userId)
                }
                if shouldRetryUserName {
                    retryLoadUserNameFromServer(userId: userId)
                }
            }
        }
        
        // 🎯 新增：重试查询头像（最多重试2次）
        private func retryLoadAvatarFromServer(userId: String) {
            guard avatarRetryCount < 2 else {
                return
            }
            avatarRetryCount += 1
            
            // 🎯 修改：根据重试次数决定延迟时间
            // 第一次重试：延迟1/17秒；第二次重试：延迟0.5秒
            let delay: TimeInterval = avatarRetryCount == 1 ? 1.0 / 17.0 : 0.5
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                if self.avatarFromServer == nil {
                    LeanCloudService.shared.fetchUserAvatarByUserId(objectId: userId) { avatar, _ in
                        DispatchQueue.main.async {
                            if let avatar = avatar, !avatar.isEmpty {
                                self.avatarFromServer = avatar
                            } else {
                                // 🎯 修改：查询失败时，如果 avatarFromServer 仍为 nil 且未达到最大重试次数，触发第二次重试
                                if self.avatarFromServer == nil && self.avatarRetryCount < 2 {
                                    self.retryLoadAvatarFromServer(userId: userId)
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // 🎯 新增：重试查询用户名（最多重试2次）
        private func retryLoadUserNameFromServer(userId: String) {
            guard userNameRetryCount < 2 else {
                return
            }
            userNameRetryCount += 1
            
            // 🎯 修改：根据重试次数决定延迟时间
            // 第一次重试：延迟1/17秒；第二次重试：延迟0.5秒
            let delay: TimeInterval = userNameRetryCount == 1 ? 1.0 / 17.0 : 0.5
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                if self.userNameFromServer == nil {
                    LeanCloudService.shared.fetchUserNameByUserId(objectId: userId) { name, _ in
                        DispatchQueue.main.async {
                            if let name = name, !name.isEmpty {
                                self.userNameFromServer = name
                            } else {
                                // 🎯 修改：查询失败时，如果 userNameFromServer 仍为 nil 且未达到最大重试次数，触发第二次重试
                                if self.userNameFromServer == nil && self.userNameRetryCount < 2 {
                                    self.retryLoadUserNameFromServer(userId: userId)
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // 预览卡片用户信息
        private var previewCardUserInfo: some View {
            HStack(spacing: 32) {
                previewCardAvatar
                previewCardUserDetails
            }
        }
        
        // 预览卡片头像（优先使用 UserAvatarRecord）
        private var previewCardAvatar: some View {
            Group {
                if let serverAvatar = avatarFromServer, !serverAvatar.isEmpty {
                    if serverAvatar == "apple_logo" {
                        Image(systemName: "applelogo")
                            .font(.system(size: 48))
                            .foregroundColor(.black)
                            .background(Circle().fill(Color.gray.opacity(0.1)).frame(width: 80, height: 80))
                            .onAppear {
                            }
                    } else if UserAvatarUtils.isSFSymbol(serverAvatar) {
                        // 🔧 修复：检查是否是 SF Symbol，如果是则显示图标而不是文字
                        Image(systemName: serverAvatar)
                            .font(.system(size: 48))
                            .foregroundColor(userManager.currentUser?.loginType == .apple ? .purple : .blue)
                            .background(Circle().fill(Color.gray.opacity(0.1)).frame(width: 80, height: 80))
                            .onAppear {
                            }
                    } else {
                        Text(serverAvatar)
                            .font(.system(size: 48))
                            .fixedSize(horizontal: true, vertical: false)
                            .background(Circle().fill(Color.gray.opacity(0.1)).frame(width: 80, height: 80))
                            .onAppear {
                            }
                    }
                } else if let customAvatar = displayAvatar, !customAvatar.isEmpty {
                    if customAvatar == "applelogo" || customAvatar == "apple_logo" {
                        Image(systemName: "applelogo")
                            .font(.system(size: 48))
                            .foregroundColor(.black)
                            .background(Circle().fill(Color.gray.opacity(0.1)).frame(width: 80, height: 80))
                            .onAppear {
                            }
                    } else if UserAvatarUtils.isSFSymbol(customAvatar) {
                        // 🔧 修复：检查是否是 SF Symbol，如果是则显示图标而不是文字
                        Image(systemName: customAvatar)
                            .font(.system(size: 48))
                            .foregroundColor(userManager.currentUser?.loginType == .apple ? .purple : .blue)
                            .background(Circle().fill(Color.gray.opacity(0.1)).frame(width: 80, height: 80))
                            .onAppear {
                            }
                    } else {
                        Text(customAvatar)
                            .font(.system(size: 48))
                            .fixedSize(horizontal: true, vertical: false)
                            .background(Circle().fill(Color.gray.opacity(0.1)).frame(width: 80, height: 80))
                            .onAppear {
                            }
                    }
                } else if let loginType = userManager.currentUser?.loginType {
                    // Apple账号与内部账号使用相同的默认头像
                    if loginType == .apple {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundColor(.purple)
                            .background(Circle().fill(Color.gray.opacity(0.1)).frame(width: 80, height: 80))
                            .onAppear {
                            }
                    } else {
                        // 游客用户 - 与用户头像界面一致：使用person.circle（蓝色）
                        Image(systemName: "person.circle")
                            .foregroundColor(.blue)
                            .font(.system(size: 36, weight: .medium))
                            .background(Circle().fill(Color.gray.opacity(0.1)).frame(width: 80, height: 80))
                            .onAppear {
                            }
                    }
                }
            }
        }
        
        // 预览卡片用户详情
        private var previewCardUserDetails: some View {
            VStack(alignment: .leading, spacing: 8) {
                ColorfulUserNameText(
                    userName: userNameFromServer ?? (userManager.currentUser?.fullName ?? "未知用户"),
                    userId: userManager.currentUser?.id ?? "",
                    loginType: userManager.currentUser?.loginType == .apple ? "apple" : "guest",
                    font: .title2,
                    fontWeight: .bold,
                    lineLimit: 1,
                    truncationMode: .tail
                )
                .minimumScaleFactor(0.3)
                
                previewCardUserTypeAndHeart
            }
        }
        
        // 预览卡片用户类型和爱心按钮
        private var previewCardUserTypeAndHeart: some View {
            HStack(spacing: 8) {
                previewCardUserTypeLabel
                previewCardHeartButton
            }
        }
        
        // 预览卡片用户类型标签
        private var previewCardUserTypeLabel: some View {
            HStack(spacing: 4) {
                if let loginType = userManager.currentUser?.loginType {
                    if loginType == .apple {
                        Image(systemName: "applelogo")
                            .foregroundColor(.black)
                            .font(.system(size: 11))
                        Text("Apple用户")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.black)
                    } else {
                        Image(systemName: "person.circle")
                            .foregroundColor(.blue)
                            .font(.system(size: 11))
                        Text("游客用户")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(
                        userManager.currentUser?.loginType == .apple ? Color.black.opacity(0.1) :
                        Color.blue.opacity(0.1)
                    )
            )
        }
        
        // 预览卡片爱心按钮
        private var previewCardHeartButton: some View {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHeartClicked.toggle()
                }
            }) {
                Image(systemName: isHeartClicked ? "heart.fill" : "heart")
                    .foregroundColor(isHeartClicked ? .red : .gray)
                    .font(.system(size: 16))
                    .scaleEffect(isHeartClicked ? 1.26 : 1.0)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}
