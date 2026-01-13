import SwiftUI

// MARK: - UI Components
extension AvatarZoomView {
    
    // 头像显示视图
    struct AvatarDisplayView: View {
        let displayAvatar: String?
        let userManager: UserManager
        let onAvatarTap: () -> Void // 新增：头像点击回调
        @State private var avatarFromServer: String? = nil
        @State private var avatarRetryCount: Int = 0 // 🎯 新增：头像重试次数（最多重试2次）
        
        var body: some View {
            Button(action: onAvatarTap) {
                // 🔧 修复：优先显示本地更新的头像（displayAvatar），确保随机解锁时立即更新
                // 如果 displayAvatar 有值且不为空，优先使用它（这是用户刚刚更新的头像）
                if let localAvatar = displayAvatar, !localAvatar.isEmpty {
                    if localAvatar == "applelogo" || localAvatar == "apple_logo" {
                        Image(systemName: "applelogo")
                            .font(UIStyleManager.Fonts.custom(size: 120))
                            .foregroundColor(.black)
                            .onAppear {
                            }
                    } else if localAvatar == "person.circle.fill" {
                        Image(systemName: localAvatar)
                            .font(.system(size: 120))
                            // 🔧 修复：Apple账号与内部账号使用相同的颜色（紫色）
                            .foregroundColor((userManager.currentUser?.loginType == .apple) ? .purple : .blue)
                            .onAppear {
                            }
                    } else {
                        Text(localAvatar)
                            .font(.system(size: 120))
                            .fixedSize(horizontal: true, vertical: false)
                            .onAppear {
                            }
                    }
                } else if let serverAvatar = avatarFromServer, !serverAvatar.isEmpty {
                    if serverAvatar == "apple_logo" || serverAvatar == "applelogo" {
                        Image(systemName: "applelogo")
                            .font(UIStyleManager.Fonts.custom(size: 120))
                            .foregroundColor(.black)
                            .onAppear {
                            }
                    } else if UserAvatarUtils.isSFSymbol(serverAvatar) {
                        // 🔧 修复：检查是否是 SF Symbol，如果是则显示图标而不是文字
                        Image(systemName: serverAvatar)
                            .font(.system(size: 120))
                            .foregroundColor((userManager.currentUser?.loginType == .apple) ? .purple : .blue)
                            .onAppear {
                            }
                    } else {
                        Text(serverAvatar)
                            .font(.system(size: 120))
                            .fixedSize(horizontal: true, vertical: false)
                            .onAppear {
                            }
                    }
                } else if let loginType = userManager.currentUser?.loginType {
                    // 显示默认头像 - Apple账号与内部账号使用相同的默认头像
                    if loginType == .apple {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.purple)
                            .font(.system(size: 120))
                            .onAppear {
                            }
                    } else {
                        Image(systemName: "person.circle")
                            .foregroundColor(.blue)
                            .font(.system(size: 120))
                            .onAppear {
                            }
                    }
                }
            }
            .buttonStyle(.plain) // 保持原有样式
            // 🔧 修复：监听 displayAvatar 的变化，当本地头像更新时同步更新 avatarFromServer
            .onChange(of: displayAvatar) { oldValue, newValue in
                if let newAvatar = newValue, !newAvatar.isEmpty {
                    // 当本地头像更新时（如随机解锁），立即更新 avatarFromServer 以确保显示正确
                    avatarFromServer = newAvatar
                }
            }
            .onAppear {
                // 🔧 统一使用 objectId 作为 userId
                guard let userId = userManager.currentUser?.id else { return }
                
                // 🎯 修改：使用 fetchUserAvatarByUserId，不依赖 loginType，直接从 UserAvatarRecord 表获取
                LeanCloudService.shared.fetchUserAvatarByUserId(objectId: userId) { avatar, _ in
                    DispatchQueue.main.async {
                        if let avatar = avatar, !avatar.isEmpty {
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
                            self.avatarFromServer = avatar
                        } else {
                        }
                    }
                }
            }
            .task {
                // 🎯 新增：检查查询是否失败，如果失败则重试
                guard let userId = userManager.currentUser?.id else { return }
                try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 / 7.0)) // 1/7秒
                // 检查是否查询失败（avatarFromServer 为 nil）且未达到最大重试次数
                let shouldRetry = avatarFromServer == nil && avatarRetryCount < 2
                if shouldRetry {
                    retryLoadAvatarFromServer(userId: userId)
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
                                UserDefaultsManager.setCustomAvatar(userId: userId, emoji: avatar)
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
    }
    
    // 用户信息视图
    struct UserInfoView: View {
        let userManager: UserManager
        @State private var userNameFromServer: String? = nil
        @State private var emailFromServer: String? = nil
        @State private var userNameRetryCount: Int = 0 // 🎯 新增：用户名重试次数（最多重试2次）
        
        var body: some View {
            VStack(spacing: 10) {
                ColorfulUserNameText(
                    userName: userNameFromServer ?? (userManager.currentUser?.fullName ?? "未知用户"),
                    userId: userManager.currentUser?.id ?? "",
                    loginType: userManager.currentUser?.loginType == .apple ? "apple" : "guest",
                    font: .title,
                    fontWeight: .bold,
                    lineLimit: 1,
                    truncationMode: .tail
                )
                
                if let loginType = userManager.currentUser?.loginType {
                    let loginTypeText = loginType == .apple ? "Apple账户" : "游客模式"
                    Text(loginTypeText)
                        .font(.headline)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                
                // 统一使用UserNameRecord表：只使用从服务器查询的邮箱
                // 🎯 新增：不显示默认邮箱
                let isDefaultEmail = emailFromServer?.hasSuffix("@internal.com") == true || 
                                   emailFromServer?.hasSuffix("@apple.com") == true || 
                                   emailFromServer?.hasSuffix("@guest.com") == true
                if let email = emailFromServer, !email.isEmpty, !isDefaultEmail {
                    Text(email)
                        .font(.body)
                        .foregroundColor(.blue)
                }
            }
            .onAppear {
                // 🔧 统一使用 objectId 作为 userId
                guard let userId = userManager.currentUser?.id else { return }
                
                // 🎯 修改：使用 fetchUserNameByUserId，不依赖 loginType，直接从 UserNameRecord 表获取
                LeanCloudService.shared.fetchUserNameByUserId(objectId: userId) { name, _ in
                    DispatchQueue.main.async {
                        if let name = name, !name.isEmpty {
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
                        }
                    }
                }
                
                // 查询邮箱 - 🎯 统一从 UserNameRecord 表获取，不依赖 loginType
                LeanCloudService.shared.fetchUserEmailByUserId(objectId: userId) { email, _ in
                    DispatchQueue.main.async {
                        if let email = email, !email.isEmpty { self.emailFromServer = email }
                    }
                }
            }
            .task {
                // 🎯 新增：检查查询是否失败，如果失败则重试
                guard let userId = userManager.currentUser?.id else { return }
                try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 / 7.0)) // 1/7秒
                // 检查是否查询失败（userNameFromServer 为 nil）且未达到最大重试次数
                let shouldRetry = userNameFromServer == nil && userNameRetryCount < 2
                if shouldRetry {
                    retryLoadUserNameFromServer(userId: userId)
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
                                UserDefaultsManager.setCurrentUserName(name)
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
    }
}
