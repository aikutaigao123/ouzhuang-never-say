import SwiftUI

// 抽出组件：匹配到的对象头部（头像 + 名称 + 类型），支持点击放大头像
struct MatchedUserHeaderView: View {
    let record: LocationRecord
    let latestAvatars: [String: String]
    let onTapAvatar: (_ avatar: String?, _ loginType: String?, _ userName: String?) -> Void
    let onCopyUserName: () -> Void
    @State private var avatarFromServer: String? = nil
    @State private var userNameFromServer: String? = nil
    @State private var avatarRetryCount: Int = 0 // 🎯 新增：头像重试次数（最多重试2次）
    @State private var userNameRetryCount: Int = 0 // 🎯 新增：用户名重试次数（最多重试2次）

    var body: some View {
        VStack(spacing: 16) {
            // 头像区域 - 居中显示，更大更突出
            Button(action: {
                let finalAvatar: String?
                if let avatar = displayAvatar, !avatar.isEmpty {
                    finalAvatar = (avatar == "apple_logo") ? "applelogo" : avatar
                } else {
                    if record.loginType == "apple" { finalAvatar = "person.circle.fill" } // 与用户头像界面一致：Apple账号使用默认头像
                    else { finalAvatar = latestAvatars[record.userId] ?? "person.circle" } // 与用户头像界面一致：游客用户使用person.circle
                }
                onTapAvatar(finalAvatar, record.loginType, record.userName)
            }) {
                Group {
                    if let avatar = displayAvatar, !avatar.isEmpty {
                        if avatar == "apple_logo" || avatar == "applelogo" {
                            Image(systemName: "applelogo").foregroundColor(.black)
                        } else if UserAvatarUtils.isSFSymbol(avatar) {
                            // 🔧 修复：检查是否是 SF Symbol，如果是则显示图标而不是文字
                            Image(systemName: avatar)
                                .foregroundColor(avatar == "person.circle.fill" ? .purple : .blue)
                        } else {
                            Text(avatar)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    } else {
                        if record.loginType == "apple" {
                            Image(systemName: "applelogo").foregroundColor(.black)
                        } else {
                            // 游客用户 - 与用户头像界面一致：使用person.circle（蓝色）
                            Image(systemName: "person.circle").foregroundColor(.blue)
                        }
                    }
                }
                .font(.system(size: 48))
                .background(
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 80, height: 80)
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                )
            }
            .buttonStyle(.plain)
            .onAppear {
                // 与用户头像界面一致：在onAppear时实时查询服务器头像和用户名
                loadAvatarFromServer()
                loadUserNameFromServer()
            }
            .task {
                // 🎯 新增：检查查询是否失败，如果失败则重试
                try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 / 7.0)) // 1/7秒
                // 检查是否查询失败且未达到最大重试次数
                let shouldRetryAvatar = avatarFromServer == nil && avatarRetryCount < 2
                let shouldRetryUserName = userNameFromServer == nil && userNameRetryCount < 2
                if shouldRetryAvatar {
                    retryLoadAvatarFromServer()
                }
                if shouldRetryUserName {
                    retryLoadUserNameFromServer()
                }
            }

            // 用户信息区域 - 居中显示
            VStack(spacing: 8) {
                // 用户名 - 更大更突出（优先使用 UserNameRecord）
                ColorfulUserNameText(
                    userName: displayedUserName,
                    userId: record.userId,
                    loginType: record.loginType,
                    font: .title,
                    fontWeight: .bold,
                    lineLimit: 1,
                    truncationMode: .tail
                )
                .multilineTextAlignment(.center)
                .onLongPressGesture { onCopyUserName() }

                // 用户类型标签 - 使用卡片样式
                HStack(spacing: 6) {
                    if record.loginType == "apple" {
                        Image(systemName: "applelogo")
                            .foregroundColor(.black)
                            .font(.system(size: 16))
                        Text("Apple用户")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.black)
                    } else {
                        // 游客用户 - 与用户头像界面一致：使用person.circle（蓝色）
                        Image(systemName: "person.circle")
                            .foregroundColor(.blue)
                            .font(.system(size: 16))
                        Text("游客用户")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            record.loginType == "apple" ? Color.black.opacity(0.1) :
                            Color.blue.opacity(0.1)
                        )
                )
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // 计算displayAvatar的辅助函数 - 与用户头像界面一致：实时查询服务器
    private var displayAvatar: String? {
        let uid = record.userId
        // 第一优先级：从服务器实时查询的头像（与用户头像界面一致）
        if let serverAvatar = avatarFromServer, !serverAvatar.isEmpty {
            return serverAvatar
        }
        // 第二优先级：从 UserDefaults 获取头像（与用户头像界面一致：使用 displayAvatar，对应 UserDefaults）
        if let customAvatar = UserDefaultsManager.getCustomAvatar(userId: uid), !customAvatar.isEmpty {
            return customAvatar
        }
        // 第三优先级：latestAvatars字典
        if let latest = latestAvatars[uid], !latest.isEmpty { return latest }
        // 第四优先级：record中的userAvatar
        return record.userAvatar
    }
    
    // 从服务器加载头像 - 🎯 统一从 UserAvatarRecord 表获取
    private func loadAvatarFromServer() {
        let uid = record.userId
        
        // 🎯 修改：使用 fetchUserAvatarByUserId，不依赖 loginType，直接从 UserAvatarRecord 表获取
        LeanCloudService.shared.fetchUserAvatarByUserId(objectId: uid) { avatar, _ in
            DispatchQueue.main.async {
                if let avatar = avatar, !avatar.isEmpty {
                    // 🔍 检查 UserDefaults 与服务器数据是否一致
                    let userDefaultsAvatar = UserDefaultsManager.getCustomAvatar(userId: uid)
                    if let defaultsAvatar = userDefaultsAvatar, !defaultsAvatar.isEmpty {
                        if defaultsAvatar != avatar {
                            // 🔧 自动更新 UserDefaults 以保持一致性
                            UserDefaultsManager.setCustomAvatar(userId: uid, emoji: avatar)
                        } else {
                        }
                    } else {
                        UserDefaultsManager.setCustomAvatar(userId: uid, emoji: avatar)
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
    
    // 获取显示的用户名 - 与用户头像界面一致：实时查询服务器
    private var displayedUserName: String {
        // 第一优先级：从服务器实时查询的用户名
        if let serverName = userNameFromServer, !serverName.isEmpty {
            return serverName
        }
        // 第二优先级：本地缓存（如果有的话，这里暂时没有传入latestUserNames，所以跳过）
        // 第三优先级：record中的userName
        return record.userName ?? "未知用户"
    }
    
    // 从服务器加载用户名 - 🎯 统一从 UserNameRecord 表获取
    private func loadUserNameFromServer() {
        let uid = record.userId
        
        // 🎯 修改：使用 fetchUserNameByUserId，不依赖 loginType，直接从 UserNameRecord 表获取
        LeanCloudService.shared.fetchUserNameByUserId(objectId: uid) { name, _ in
            DispatchQueue.main.async {
                if let name = name, !name.isEmpty {
                    self.userNameFromServer = name
                    
                    // 🎯 新增：更新 UserDefaults 中的用户名缓存（用于其他用户的信息）
                    let userDefaultsUserName = UserDefaultsManager.getFriendUserName(userId: uid)
                    if userDefaultsUserName != name {
                        UserDefaultsManager.setFriendUserName(userId: uid, userName: name)
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
            if self.userNameFromServer == nil {
                self.loadUserNameFromServer()
            }
        }
    }
}
