import SwiftUI

// 新的朋友行视图
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
    @State private var avatarRetryCount: Int = 0 // 🎯 新增：头像重试次数（最多重试2次）
    @State private var userNameRetryCount: Int = 0 // 🎯 新增：用户名重试次数（最多重试2次）
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
    
    // 🎯 新增：获取最终显示的用户名
    private var finalDisplayName: String {
        if !displayedName.isEmpty {
            return displayedName
        } else if !message.senderName.isEmpty {
            return message.senderName
        } else {
            return "未知用户"
        }
    }
    
    var body: some View {
        // 🎯 调试：打印关键信息（使用 let _ = 避免编译错误）
        let _ = {
        }()
        
        // 🎯 修改：完全按照好友列表的布局结构（VStack + HStack）
        return VStack(spacing: 0) {
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
                                // Apple账号与内部账号使用相同的默认头像
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
                .contentShape(Circle()) // 确保整个头像区域都可以点击
                .onTapGesture {
                    onTap()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // 🎯 修改：显示用户名（与好友列表一致），而不是消息内容
                    ColorfulUserNameText(
                        userName: finalDisplayName,
                        userId: message.senderId,
                        loginType: senderInfo.loginType,
                        font: .headline,
                        fontWeight: .regular,
                        lineLimit: 1,
                        truncationMode: .tail
                    )
                    .onAppear {
                    }
                    
                    // 🎯 修改：显示未读标记（如果有）- 与好友列表的在线状态位置一致
                    HStack(spacing: 4) {
                        if !message.isRead {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 8, height: 8)
                            Text("未读")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .onAppear {
                    }
                    
                    // 🎯 修改：登录类型标签（与好友列表一致）
                    let loginTypeText = loginTypeDisplayName(senderInfo.loginType)
                    HStack {
                        Text(loginTypeText)
                            .font(.caption)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(loginTypeColor(senderInfo.loginType))
                            .foregroundColor(.white)
                            .cornerRadius(4)
                            .onAppear {
                            }
                        
                        Spacer()
                    }
                }
                .frame(minWidth: 100) // 🎯 新增：确保 VStack 有最小宽度
                .onAppear {
                }
                
                Spacer()
                
                // 🎯 修改：将拍一拍按钮位置改为同意和拒绝两个按钮
                // 显示条件：messageType 为 friend_request 或 favorite，且 content 包含"对你发送了好友申请"（表示是别人向当前用户发送的申请）
                let isFriendRequest = (message.messageType == "friend_request" || message.messageType == "favorite") && message.content.contains("对你发送了好友申请")
                
                Group {
                    if isFriendRequest {
                        // 检查是否是 pending 状态（通过 content 判断，pending 状态的内容是"xxx对你发送了好友申请"）
                        let isPending = !message.content.contains("已接受") && !message.content.contains("已拒绝")
                        
                        if isPending {
                            HStack(spacing: 8) {
                                // 同意按钮（样式与拍一拍按钮一致）
                                Button(action: {
                                    guard let requestId = message.objectId else {
                                        return
                                    }
                                    onAccept(requestId)
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.caption)
                                        Text("同意")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.green)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                // 拒绝按钮（样式与拍一拍按钮一致）
                                Button(action: {
                                    guard let requestId = message.objectId else {
                                        return
                                    }
                                    onReject(requestId)
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption)
                                        Text("拒绝")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.red)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .onAppear {
                            }
                        } else {
                            EmptyView()
                                .onAppear {
                                }
                        }
                    } else {
                        EmptyView()
                            .onAppear {
                            }
                    }
                }
                .onAppear {
                }
            }
            .padding(.vertical, 8)
            .onAppear {
            }
            .contentShape(Rectangle()) // 确保整个区域都可以点击
            #if os(iOS)
            .onTapGesture {
                onTap()
            }
            #elseif os(macOS)
            .onTapGesture {
                onTap()
            }
            #endif
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
                            // 🎯 修改：查询失败时，如果 avatarFromServer 仍为 nil 且未达到最大重试次数，触发第二次重试
                            if self.avatarFromServer == nil && self.avatarRetryCount < 2 {
                                self.retryLoadAvatarFromServer(senderId: senderId)
                            }
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
                            
                            // 🎯 新增：更新 UserDefaults 中的用户名缓存（用于其他用户的信息）
                            let userDefaultsUserName = UserDefaultsManager.getFriendUserName(userId: senderId)
                            if userDefaultsUserName != name {
                                UserDefaultsManager.setFriendUserName(userId: senderId, userName: name)
                            }
                            
                            if defaultName != name {
                            }
                        } else {
                            // 🎯 修改：查询失败时，如果 userNameFromServer 仍为 nil 且未达到最大重试次数，触发第二次重试
                            if self.userNameFromServer == nil && self.userNameRetryCount < 2 {
                                self.retryLoadUserNameFromServer(senderId: senderId)
                            }
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
                    } else {
                    }
                }
            } else {
            }
        }
        .task {
            // 🎯 新增：检查查询是否失败，如果失败则重试
            let senderId = message.senderId
            try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 / 7.0)) // 1/7秒
            // 检查是否查询失败且未达到最大重试次数
            let shouldRetryAvatar = avatarFromServer == nil && avatarRetryCount < 2
            let shouldRetryUserName = userNameFromServer == nil && userNameRetryCount < 2
            if shouldRetryAvatar {
                retryLoadAvatarFromServer(senderId: senderId)
            }
            if shouldRetryUserName {
                retryLoadUserNameFromServer(senderId: senderId)
            }
        }
    }
    
    // 🎯 新增：重试查询头像（最多重试2次）
    private func retryLoadAvatarFromServer(senderId: String) {
        guard avatarRetryCount < 2 else {
            return
        }
        avatarRetryCount += 1
        
        // 🎯 修改：根据重试次数决定延迟时间
        // 第一次重试：延迟1/17秒；第二次重试：延迟0.5秒
        let delay: TimeInterval = avatarRetryCount == 1 ? 1.0 / 17.0 : 0.5
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if self.avatarFromServer == nil {
                LeanCloudService.shared.fetchUserAvatarByUserId(objectId: senderId) { avatar, error in
                    DispatchQueue.main.async {
                        if error != nil {
                        } else if let avatar = avatar, !avatar.isEmpty {
                            let userDefaultsAvatar = UserDefaultsManager.getCustomAvatar(userId: senderId)
                            if let defaultsAvatar = userDefaultsAvatar, !defaultsAvatar.isEmpty {
                                if defaultsAvatar != avatar {
                                    UserDefaultsManager.setCustomAvatar(userId: senderId, emoji: avatar)
                                }
                            } else {
                                UserDefaultsManager.setCustomAvatar(userId: senderId, emoji: avatar)
                            }
                            self.avatarFromServer = avatar
                            self.avatarCache[senderId] = avatar
                        } else {
                            // 🎯 修改：查询失败时，如果 avatarFromServer 仍为 nil 且未达到最大重试次数，触发第二次重试
                            if self.avatarFromServer == nil && self.avatarRetryCount < 2 {
                                self.retryLoadAvatarFromServer(senderId: senderId)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // 🎯 新增：重试查询用户名（最多重试2次）
    private func retryLoadUserNameFromServer(senderId: String) {
        guard userNameRetryCount < 2 else {
            return
        }
        userNameRetryCount += 1
        
        // 🎯 修改：根据重试次数决定延迟时间
        // 第一次重试：延迟1/17秒；第二次重试：延迟0.5秒
        let delay: TimeInterval = userNameRetryCount == 1 ? 1.0 / 17.0 : 0.5
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if self.userNameFromServer == nil {
                LeanCloudService.shared.fetchUserNameByUserId(objectId: senderId) { name, error in
                    DispatchQueue.main.async {
                        if error != nil {
                        } else if let name = name, !name.isEmpty {
                            self.userNameFromServer = name
                            self.userNameCache[senderId] = name
                            let userDefaultsUserName = UserDefaultsManager.getFriendUserName(userId: senderId)
                            if userDefaultsUserName != name {
                                UserDefaultsManager.setFriendUserName(userId: senderId, userName: name)
                            }
                        } else {
                            // 🎯 修改：查询失败时，如果 userNameFromServer 仍为 nil 且未达到最大重试次数，触发第二次重试
                            if self.userNameFromServer == nil && self.userNameRetryCount < 2 {
                                self.retryLoadUserNameFromServer(senderId: senderId)
                            }
                        }
                    }
                }
            }
        }
    }
}

