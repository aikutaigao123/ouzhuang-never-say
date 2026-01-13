import SwiftUI

// 用户搜索结果行组件
struct UserResultRow: View {
    let user: UserInfo
    let onSelect: () -> Void
    @State private var avatarFromServer: String? = nil // 🎯 新增：从服务器获取的头像
    @State private var avatarRetryCount: Int = 0 // 🎯 新增：头像重试次数（最多重试2次）
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // 🎯 新增：头像显示
                Group {
                    if let avatar = displayAvatar, !avatar.isEmpty {
                        if avatar == "apple_logo" || avatar == "applelogo" {
                            Image(systemName: "applelogo")
                                .font(.system(size: 32))
                                .foregroundColor(.black)
                        } else if UserAvatarUtils.isSFSymbol(avatar) {
                            Image(systemName: avatar)
                                .font(.system(size: 32))
                                .foregroundColor(avatar == "person.circle.fill" ? .purple : .blue)
                        } else {
                            Text(avatar)
                                .font(.system(size: 32))
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    } else {
                        DefaultAvatarView(loginType: user.loginType.toString())
                    }
                }
                .frame(width: 50, height: 50)
                .background(Circle().fill(Color.gray.opacity(0.1)))
                
                VStack(alignment: .leading, spacing: 4) {
                    ColorfulUserNameText(
                        userName: user.fullName,
                        userId: user.userId,
                        loginType: user.loginType.toString(),
                        font: .headline,
                        fontWeight: .regular,
                        lineLimit: 1,
                        truncationMode: .tail
                    )
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(8)
        }
        .onAppear {
            // 🎯 新增：加载用户头像
            loadAvatarFromServer()
        }
        .task {
            // 🎯 新增：检查查询是否失败，如果失败则重试
            try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 / 7.0)) // 1/7秒
            // 检查是否查询失败（avatarFromServer 为 nil）且未达到最大重试次数
            let shouldRetry = avatarFromServer == nil && avatarRetryCount < 2
            if shouldRetry {
                retryLoadAvatarFromServer()
            }
        }
    }
    
    // 🎯 新增：计算显示的头像（优先服务器，其次UserDefaults，最后使用user.userAvatar）
    private var displayAvatar: String? {
        // 第一优先级：从服务器实时查询的头像
        if let serverAvatar = avatarFromServer, !serverAvatar.isEmpty {
            return serverAvatar
        }
        // 第二优先级：从 UserDefaults 获取头像
        if let customAvatar = UserDefaultsManager.getCustomAvatar(userId: user.userId), !customAvatar.isEmpty {
            return customAvatar
        }
        // 第三优先级：使用默认头像（UserInfo 没有 userAvatar 属性）
        return nil
    }
    
    // 🎯 新增：从服务器加载头像
    private func loadAvatarFromServer() {
        let userId = user.userId
        
        LeanCloudService.shared.fetchUserAvatarByUserId(objectId: userId) { avatar, error in
            DispatchQueue.main.async {
                if error != nil {
                    // 加载失败，使用默认值
                } else if let avatar = avatar, !avatar.isEmpty {
                    // 🔍 检查 UserDefaults 与服务器数据是否一致
                    let userDefaultsAvatar = UserDefaultsManager.getCustomAvatar(userId: userId)
                    if let defaultsAvatar = userDefaultsAvatar, !defaultsAvatar.isEmpty {
                        if defaultsAvatar != avatar {
                            // 🔧 自动更新 UserDefaults 以保持一致性
                            UserDefaultsManager.setCustomAvatar(userId: userId, emoji: avatar)
                        }
                    } else {
                        UserDefaultsManager.setCustomAvatar(userId: userId, emoji: avatar)
                    }
                    self.avatarFromServer = avatar
                } else {
                    // 🎯 修改：查询失败时，如果 avatarFromServer 仍为 nil 且未达到最大重试次数，触发第二次重试
                    if self.avatarFromServer == nil && self.avatarRetryCount < 2 {
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
            if self.avatarFromServer == nil {
                self.loadAvatarFromServer()
            }
        }
    }
}

