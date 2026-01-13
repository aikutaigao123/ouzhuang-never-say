import SwiftUI
import LeanCloud

// 消息项视图
struct MessageItemView: View {
    @Binding var message: MessageItem
    let onMessageTap: (MessageItem) -> Void
    let onMarkAsRead: (MessageItem) -> Void
    let isUserFavorited: (String) -> Bool
    let onToggleFavorite: (String, String?, String?, String?, String?, String?) -> Void
    let isUserLiked: (String) -> Bool
    let onToggleLike: (String, String?, String?, String?, String?, String?) -> Void
    @Binding var avatarCache: [String: String]
    @Binding var userNameCache: [String: String]
    @Binding var loginTypeCache: [String: String] // 🎯 新增：用户类型缓存绑定
    @State private var latestSenderAvatar: String = ""
    @State private var latestReceiverAvatar: String = ""
    @State private var latestSenderName: String = ""
    @State private var senderNameFromServer: String? = nil
    @State private var favoriteStatusFromServer: Bool? = nil // 🎯 新增：从服务器实时查询的 favorite 状态
    @State private var userLoginType: String? = nil // 🎯 新增：从服务器获取的用户类型（参考好友列表的实现）
    @State private var hasLoadedLoginType: Bool = false // 🎯 新增：是否已加载用户类型
    
    // 🎯 新增：计算显示的 favorite 状态
    private var displayedFavoriteStatus: Bool {
        // 优先使用服务器实时查询的状态
        if let serverStatus = favoriteStatusFromServer {
            return serverStatus
        }
        // 如果没有服务器状态，使用本地缓存状态
        // 🔧 修复：使用捕获的值，避免访问可能已失效的binding
        let currentMessage = message
        let localStatus = isUserFavorited(currentMessage.senderId)
        return localStatus
    }
    
    var body: some View {
        // 🔧 修复：在body开始时捕获message的值，避免在闭包中访问可能已失效的binding
        let currentMessage = message
        let senderId = currentMessage.senderId
        let senderName = currentMessage.senderName
        
        
        
        return HStack(spacing: 12) {
            // 发送者头像 - 优化显示逻辑，避免闪烁
            if !latestSenderAvatar.isEmpty {
                // 使用从缓存获取的最新头像 - 与用户头像界面一致：支持SF Symbol和emoji/文本
                if latestSenderAvatar == "apple_logo" || latestSenderAvatar == "applelogo" {
                    // Apple Logo 特殊处理
                    Image(systemName: "applelogo")
                        .font(.system(size: 30))
                        .foregroundColor(.black)
                        .background(Circle().fill(Color.gray.opacity(0.1)).frame(width: 50, height: 50))
                        .onAppear {
                            printUserAvatarRecord(userId: senderId, message: currentMessage)
                        }
                } else if UserAvatarUtils.isSFSymbol(latestSenderAvatar) {
                    // 🔧 修复：检查是否是 SF Symbol，如果是则显示图标而不是文字
                    Image(systemName: latestSenderAvatar)
                        .font(.system(size: 30))
                        .foregroundColor(latestSenderAvatar == "person.circle.fill" ? .purple : .blue)
                        .background(Circle().fill(Color.gray.opacity(0.1)).frame(width: 50, height: 50))
                        .onAppear {
                            printUserAvatarRecord(userId: senderId, message: currentMessage)
                        }
                } else {
                    Text(latestSenderAvatar)
                        .font(.system(size: 30))
                        .fixedSize(horizontal: true, vertical: false)
                        .background(Circle().fill(Color.gray.opacity(0.1)).frame(width: 50, height: 50))
                        .onAppear {
                            printUserAvatarRecord(userId: senderId, message: currentMessage)
                        }
                }
        } else {
            // 默认头像 - 与用户头像界面一致：Apple账号与内部账号使用相同的默认头像
            let loginType = currentMessage.senderLoginType ?? getLoginTypeFromUserId(senderId, message: currentMessage)
            if loginType == "apple" {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.purple)
                    .background(Circle().fill(Color.gray.opacity(0.1)).frame(width: 50, height: 50))
                    .onAppear {
                        printUserAvatarRecord(userId: senderId, message: currentMessage)
                        // 强制重新获取头像
                        Task {
                            await refreshAvatarImmediately()
                        }
                    }
            } else {
                Image(systemName: "person.circle")
                    .font(.system(size: 30))
                    .foregroundColor(.blue)
                    .background(Circle().fill(Color.gray.opacity(0.1)).frame(width: 50, height: 50))
                    .onAppear {
                        printUserAvatarRecord(userId: senderId, message: currentMessage)
                        // 强制重新获取头像
                        Task {
                            await refreshAvatarImmediately()
                        }
                    }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // 消息内容 - 🎯 修复：动态替换"未知用户"为实际用户名
                let displayContent: String = {
                    // 如果获取到了正确的用户名，且content中包含"未知用户"，则替换
                    if let serverName = senderNameFromServer, !serverName.isEmpty && serverName != "未知用户" && currentMessage.content.contains("未知用户") {
                        return currentMessage.content.replacingOccurrences(of: "未知用户", with: serverName)
                    }
                    // 如果latestSenderName不为空且与senderName不同，也尝试替换
                    if !latestSenderName.isEmpty && latestSenderName != senderName && latestSenderName != "未知用户" && currentMessage.content.contains(senderName) {
                        return currentMessage.content.replacingOccurrences(of: senderName, with: latestSenderName)
                    }
                    return currentMessage.content
                }()
                Text(displayContent)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // 用户类型标签和未读标记 - 确保始终显示（与好友列表样式一致）
                // 优先级：从服务器获取的 userLoginType > message.senderLoginType > 从userId推断
                let loginType = userLoginType ?? currentMessage.senderLoginType ?? getLoginTypeFromUserId(currentMessage.senderId, message: currentMessage)
                let loginTypeText = UserTypeUtils.getUserTypeText(loginType)
                let loginTypeColor = UserTypeUtils.getUserTypeColor(loginType)
                
                // 如果消息未读且爱心未点亮且未匹配成功，则显示未读标记
                let shouldShowUnread = !currentMessage.isRead && !displayedFavoriteStatus && !currentMessage.isMatch
                
                HStack(spacing: 8) {
                    Text(loginTypeText)
                        .font(.caption)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(loginTypeColor)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                    
                    // 未读标记 - 显示在用户类型标签右侧
                    if shouldShowUnread {
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
                .onAppear {
                }
                .onChange(of: userLoginType) { _, newLoginType in
                    if newLoginType != nil {
                    }
                }
                
                // 匹配成功标识
                if currentMessage.isMatch {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 14, weight: .medium))
                            Text("匹配成功")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                        
                        Spacer()
                    }
                }
                
                // 操作按钮 - 右下角
                HStack {
                    Spacer()
                    
                    // 🎯 符合好友关系开发指南：同意和拒绝按钮（只对 pending 状态的好友申请显示）
                    // 显示条件：messageType 为 friend_request 或 favorite，且 content 包含"对你发送了好友申请"（表示是别人向当前用户发送的申请）
                    let isFriendRequest = (currentMessage.messageType == "friend_request" || currentMessage.messageType == "favorite") && currentMessage.content.contains("对你发送了好友申请")
                    let isPending = isFriendRequest && !currentMessage.content.contains("已接受") && !currentMessage.content.contains("已拒绝")
                    if isPending {
                        // 同意按钮
                        Button(action: {
                            guard let requestId = currentMessage.objectId else {
                                return
                            }
                            
                            // 🎯 调用辅助函数处理同意好友申请并点亮爱心按钮
                            handleAcceptFriendRequest(requestId: requestId)
                        }) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 16))
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // 拒绝按钮
                        Button(action: {
                            guard let requestId = currentMessage.objectId else {
                                return
                            }
                            
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
                                                
                                                // 🚀 修复：等待 FriendshipManager 的缓存更新完成后再刷新
                                                // declineFriendshipRequest 内部会调用 fetchFriendshipRequests 更新缓存
                                                // 等待一小段时间确保缓存已更新
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                    NotificationCenter.default.post(name: NSNotification.Name("RefreshNewFriends"), object: nil)
                                                    NotificationCenter.default.post(name: NSNotification.Name("FriendshipRequestUpdated"), object: nil)
                                                    
                                                    // 🚀 修复：延迟一点时间后再次刷新，确保服务器数据已更新
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                                        NotificationCenter.default.post(name: NSNotification.Name("RefreshNewFriends"), object: nil)
                                                        NotificationCenter.default.post(name: NSNotification.Name("FriendshipRequestUpdated"), object: nil)
                                                    }
                                                }
                                            } else {
                                            }
                                        }
                                    }
                                }
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.system(size: 16))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // 爱心按钮 - 🎯 新增：实时查询服务器状态
                    Button(action: {
                        
                        // 🎯 参考头像界面方式：优先使用实时查询的用户类型，然后使用Message中的，最后推断
                        let resolvedLoginType = userLoginType ?? currentMessage.senderLoginType ?? getLoginTypeFromUserId(senderId, message: currentMessage)
                        
                        onToggleFavorite(
                            senderId,
                            senderName,
                            nil, // userEmail
                            resolvedLoginType, // loginType 传入解析结果
                            currentMessage.senderAvatar,
                            currentMessage.objectId  // recordObjectId（如有）
                        )
                        
                        // 标记消息为已读
                        onMarkAsRead(currentMessage)

                        // 🔍 新增：打印爱心状态变化（点击后，异步读取）
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            
                            // 重新查询服务器状态
                            self.loadFavoriteStatusFromServer()
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                let finalStatus = self.displayedFavoriteStatus
                                
                                if finalStatus {
                                    self.acceptPendingFriendRequestIfNeeded()
                                } else {
                                }
                            }
                        }
                    }) {
                        Image(systemName: displayedFavoriteStatus ? "heart.fill" : "heart")
                            .foregroundColor(displayedFavoriteStatus ? .red : .gray)
                            .font(.system(size: 16))
                            .scaleEffect(displayedFavoriteStatus ? 1.26 : 1.0)
                            .animation(.easeInOut(duration: 0.2), value: displayedFavoriteStatus)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onAppear {
                        // 🎯 新增：在爱心按钮出现时实时查询服务器状态
                        loadFavoriteStatusFromServer()
                    }
                }
            }
        }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(currentMessage.isMatch ? Color.blue.opacity(0.05) : Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: currentMessage.isMatch ? Color.blue.opacity(0.1) : Color.black.opacity(0.05), radius: currentMessage.isMatch ? 10 : 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(currentMessage.isMatch ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1), lineWidth: currentMessage.isMatch ? 1.5 : 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .onTapGesture {
            // 点击消息
            
            // 如果消息未读且爱心未点亮，先标记为已读
            if !currentMessage.isRead && !displayedFavoriteStatus {
                onMarkAsRead(currentMessage)
            }
            
            // 触发消息点击回调（会异步获取位置并显示匹配结果）
            onMessageTap(currentMessage)
            
            // 🎯 修改：不立即发送关闭通知，让 handleMessageTap 完成后自动关闭
            // 通知会在 handleMessageTap 完成后发送
        }
        .onAppear {
            // 🔧 修复：提前捕获message的值，避免在闭包中访问可能已失效的binding
            let currentMessage = message
            let senderId = currentMessage.senderId
            
            // 🎯 新增：实时查询用户类型（参考头像界面方式）
            if !hasLoadedLoginType {
                loadUserLoginTypeFromServer()
            }
            
            // 🎯 修复：先从 UserDefaults 加载头像（如果存在），确保有回退机制
            if latestSenderAvatar.isEmpty {
                if let userDefaultsAvatar = UserDefaultsManager.getCustomAvatar(userId: senderId), !userDefaultsAvatar.isEmpty {
                    latestSenderAvatar = userDefaultsAvatar
                }
            }
            
            // 获取发送者的最新头像和用户名
            fetchLatestSenderAvatar()
            fetchLatestSenderName()
            // 🎯 新增：实时查询 favorite 状态
            loadFavoriteStatusFromServer()
            
            // 🎯 用户类型查询已在上面完成（使用 loadUserLoginTypeFromServer）
            
            // 如果已点亮爱心，则视为同意，尝试接受好友申请（使用本地缓存状态作为初始判断）
            if isUserFavorited(senderId) {
                acceptPendingFriendRequestIfNeeded()
            }
        }
        .onChange(of: favoriteStatusFromServer) { _, _ in
            // 🎯 新增：当服务器状态更新时，如果已点亮爱心，则视为同意，尝试接受好友申请
            if let serverStatus = favoriteStatusFromServer, serverStatus {
                acceptPendingFriendRequestIfNeeded()
            }
        }
        .task {
            // 使用.task确保异步操作完成后UI会更新
            await fetchAvatarAsync()
        }
        .onChange(of: avatarCache) { oldValue, newValue in
            // 当头像缓存更新时，重新获取头像
            if newValue[senderId] != nil {
            } else {
            }
            fetchLatestSenderAvatar()
        }
        .onChange(of: userNameCache) { oldValue, newValue in
            // 当用户名缓存更新时，重新获取用户名
            if newValue[senderId] != nil {
            } else {
            }
            fetchLatestSenderName()
        }
        .onChange(of: latestSenderAvatar) { oldValue, newValue in
        }
        .onChange(of: senderNameFromServer) { oldValue, newValue in
        }
    }
    
    // 接受对应的好友申请（若存在pending）
    private func acceptPendingFriendRequestIfNeeded() {
        let currentMessage = message
        let senderId = currentMessage.senderId
        
        // 🎯 符合好友关系开发指南：查询条件是 friend 指向当前用户，status 为 pending
        // fetchFriendshipRequests 已经过滤了 friend 为当前用户的记录
        // 所以只需要匹配 user（发送者）和 status
        guard let currentUserId = UserDefaultsManager.getCurrentUserId() else {
            return
        }
        
        FriendshipManager.shared.fetchFriendshipRequests { requests, error in
            DispatchQueue.main.async {
                if error != nil {
                    return
                }
                guard let requests = requests else {
                    return
                }
                
                // 🎯 符合指南：查找 user=senderId（发送者），friend=currentUserId（当前用户），status=pending 的申请
                // 注意：fetchFriendshipRequests 已经过滤了 friend 为当前用户，所以 r.friend.id 应该是 currentUserId
                let target = requests.first { r in
                    r.user.id == senderId && r.friend.id == currentUserId && r.status == "pending"
                }
                
                guard let request = target else {
                    return
                }
                
                FriendshipManager.shared.acceptFriendshipRequest(request, attributes: ["source": "new_friends_heart"]) { success, errMsg in
                    if success {
                        // 🎯 接受成功后，发送通知刷新列表
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshNewFriends"), object: nil)
                        NotificationCenter.default.post(name: NSNotification.Name("FriendshipRequestUpdated"), object: nil)
                    } else {
                    }
                }
            }
        }
    }
    
    // 获取发送者的最新头像 - 🎯 统一从 UserAvatarRecord 表获取
    private func fetchLatestSenderAvatar() {
        // 🔧 修复：提前捕获message的值，避免在异步回调中访问可能已失效的binding
        let currentMessage = message
        let userId = currentMessage.senderId
        
        // 🎯 修改：直接使用 fetchUserAvatarByUserId，不依赖 loginType
        fetchUserAvatarWithoutLoginType(userId: userId)
    }
    
    // 🎯 修改：使用 fetchUserAvatarByUserId，不依赖 loginType，直接从 UserAvatarRecord 表获取
    private func fetchUserAvatarWithLoginType(userId: String, loginType: String) {
        // 🎯 修改：直接使用 fetchUserAvatarByUserId，不再依赖 loginType 参数
        LeanCloudService.shared.fetchUserAvatarByUserId(objectId: userId) { avatar, error in
            DispatchQueue.main.async { [self] in
                if avatar != nil {
                }
                if error != nil {
                }
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
                    self.latestSenderAvatar = avatar
                } else {
                    // 🎯 修复：如果服务器没有数据，先尝试从 UserDefaults 获取头像（回退机制）
                    if let userDefaultsAvatar = UserDefaultsManager.getCustomAvatar(userId: userId), !userDefaultsAvatar.isEmpty {
                        self.latestSenderAvatar = userDefaultsAvatar
                    } else {
                        // 如果 UserDefaults 也没有，使用默认头像（使用传入的 loginType 参数）
                        let defaultAvatar: String
                        if loginType == "apple" {
                            defaultAvatar = "person.circle.fill"
                        } else {
                            defaultAvatar = "person.circle" // 游客用户使用person.circle（蓝色）
                        }
                        self.latestSenderAvatar = defaultAvatar
                    }
                }
            }
        }
    }
    
    // 🎯 修改：使用 fetchUserAvatarByUserId，不依赖 loginType，直接从 UserAvatarRecord 表获取
    private func fetchUserAvatarWithoutLoginType(userId: String) {
        // 🎯 修改：使用 LeanCloudService 提供的 fetchUserAvatarByUserId 方法
        LeanCloudService.shared.fetchUserAvatarByUserId(objectId: userId) { avatar, error in
            DispatchQueue.main.async { [self] in
                if let avatar = avatar, !avatar.isEmpty {
                    // 同步到 UserDefaults
                    UserDefaultsManager.setCustomAvatar(userId: userId, emoji: avatar)
                    self.latestSenderAvatar = avatar
                } else {
                    // 回退到 UserDefaults 或默认头像
                    if let userDefaultsAvatar = UserDefaultsManager.getCustomAvatar(userId: userId), !userDefaultsAvatar.isEmpty {
                        self.latestSenderAvatar = userDefaultsAvatar
                    } else {
                        self.latestSenderAvatar = "person.circle.fill"
                    }
                }
            }
        }
    }
    
    // 异步获取头像 - 确保UI更新
    private func fetchAvatarAsync() async {
        // 🔧 修复：提前捕获message的值，避免在异步回调中访问可能已失效的binding
        let currentMessage = message
        let userId = currentMessage.senderId
        
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { [self] in
                // 🔧 修复：使用捕获的值，而不是访问binding
                self.fetchLatestSenderAvatarWithUserId(userId, message: currentMessage)
                continuation.resume()
            }
        }
    }
    
    // 获取发送者的最新头像 - 🎯 统一从 UserAvatarRecord 表获取（已简化）
    private func fetchLatestSenderAvatarWithUserId(_ userId: String, message: MessageItem) {
        // 🎯 修改：直接使用 fetchUserAvatarByUserId，不依赖 loginType
        fetchUserAvatarWithoutLoginType(userId: userId)
    }
    
    // 🚀 新增：立即刷新头像 - 与用户头像界面一致：实时查询服务器
    private func refreshAvatarImmediately() async {
        // 🔧 修复：提前捕获message的值，避免在异步回调中访问可能已失效的binding
        let currentMessage = message
        let userId = currentMessage.senderId
        let loginType = currentMessage.senderLoginType ?? getLoginTypeFromUserId(userId, message: currentMessage)
        
        // 🎯 修改：使用 fetchUserAvatarByUserId，不依赖 loginType，直接从 UserAvatarRecord 表获取
        await withCheckedContinuation { continuation in
            LeanCloudService.shared.fetchUserAvatarByUserId(objectId: userId) { avatar, _ in
                DispatchQueue.main.async { [self] in
                    if let avatar = avatar, !avatar.isEmpty {
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
                        self.latestSenderAvatar = avatar
                    } else {
                        // 🎯 修复：如果服务器没有数据，先尝试从 UserDefaults 获取头像（回退机制）
                        if let userDefaultsAvatar = UserDefaultsManager.getCustomAvatar(userId: userId), !userDefaultsAvatar.isEmpty {
                            self.latestSenderAvatar = userDefaultsAvatar
                        } else {
                            // 如果 UserDefaults 也没有，使用默认头像
                            if loginType == "apple" {
                                self.latestSenderAvatar = "person.circle.fill"
                            } else {
                                self.latestSenderAvatar = "person.circle" // 游客用户使用person.circle（蓝色）
                            }
                        }
                    }
                    continuation.resume()
                }
            }
        }
    }
    
    // 获取发送者的最新用户名 - 与用户头像界面一致：从 UserNameRecord 表读取
    private func fetchLatestSenderName() {
        // 🔧 修复：提前捕获message的值，避免在异步回调中访问可能已失效的binding
        let currentMessage = message
        let userId = currentMessage.senderId
        var loginType = currentMessage.senderLoginType ?? getLoginTypeFromUserId(userId, message: currentMessage)
        
        
        // 🎯 与用户头像界面一致：从 UserNameRecord 表读取用户名
        // 如果 loginType 是 unknown，先尝试从 UserNameRecord 获取实际的 loginType
        if loginType == "unknown" {
            LeanCloudService.shared.fetchUserLoginType(objectId: userId) { fetchedLoginType in
                if let fetchedLoginType = fetchedLoginType, fetchedLoginType != "unknown" {
                    loginType = fetchedLoginType
                    // 使用获取到的 loginType 重新查询用户名
                    self.fetchUserNameWithLoginType(userId: userId, loginType: loginType, fallbackName: currentMessage.senderName)
                } else {
                    // 如果无法获取 loginType，尝试不限制 loginType 查询（从 UserNameRecord 表）
                    self.fetchUserNameWithoutLoginType(userId: userId, fallbackName: currentMessage.senderName)
                }
            }
        } else {
            // loginType 有效，直接查询
            fetchUserNameWithLoginType(userId: userId, loginType: loginType, fallbackName: currentMessage.senderName)
        }
    }
    
    // 🎯 修改：使用 fetchUserNameByUserId，不依赖 loginType，直接从 UserNameRecord 表获取
    private func fetchUserNameWithLoginType(userId: String, loginType: String, fallbackName: String) {
        // 🎯 修改：直接使用 fetchUserNameByUserId，不再依赖 loginType 参数
        LeanCloudService.shared.fetchUserNameByUserId(objectId: userId) { name, error in
            DispatchQueue.main.async { [self] in
                if name != nil {
                }
                if error != nil {
                }
                if let name = name, !name.isEmpty {
                    self.senderNameFromServer = name
                    self.latestSenderName = name
                    
                    // 🎯 新增：更新 UserDefaults 中的用户名缓存（用于其他用户的信息）
                    let userDefaultsUserName = UserDefaultsManager.getFriendUserName(userId: userId)
                    if userDefaultsUserName != name {
                        UserDefaultsManager.setFriendUserName(userId: userId, userName: name)
                    }
                } else {
                    // 🎯 与用户头像界面一致：如果服务器没有数据，使用消息中的用户名或"未知用户"
                    let finalName = fallbackName.isEmpty ? "未知用户" : fallbackName
                    self.senderNameFromServer = nil
                    self.latestSenderName = finalName
                }
            }
        }
    }
    
    // 🎯 新增：不限制 loginType 查询用户名（从 UserNameRecord 表）
    private func fetchUserNameWithoutLoginType(userId: String, fallbackName: String) {
        LeanCloudService.shared.fetchUserNameByUserId(objectId: userId) { name, error in
            DispatchQueue.main.async { [self] in
                if error != nil {
                }
                if let name = name, !name.isEmpty {
                    self.senderNameFromServer = name
                    self.latestSenderName = name
                    
                    // 🎯 新增：更新 UserDefaults 中的用户名缓存（用于其他用户的信息）
                    let userDefaultsUserName = UserDefaultsManager.getFriendUserName(userId: userId)
                    if userDefaultsUserName != name {
                        UserDefaultsManager.setFriendUserName(userId: userId, userName: name)
                    }
                } else {
                    let finalName = fallbackName.isEmpty ? "未知用户" : fallbackName
                    self.senderNameFromServer = nil
                    self.latestSenderName = finalName
                }
            }
        }
    }
    
    // 🎯 新增：从服务器加载用户类型 - 参考头像界面的实时查询方式
    // 🔧 修复：先从缓存读取，如果没有缓存再查询服务器（与头像逻辑一致）
    private func loadUserLoginTypeFromServer() {
        let userId = message.senderId
        
        // 先尝试从本地缓存读取
        if let cachedLoginType = loginTypeCache[userId], !cachedLoginType.isEmpty, cachedLoginType != "unknown" {
            // 有缓存，直接使用
            self.userLoginType = cachedLoginType
            self.hasLoadedLoginType = true
        } else {
            // 没有缓存，查询服务器
            // 🎯 参考头像界面方式：使用 fetchUserNameAndLoginType 实时查询用户类型
            LeanCloudService.shared.fetchUserNameAndLoginType(objectId: userId) { _, loginType, _ in
                DispatchQueue.main.async {
                    if let loginType = loginType, !loginType.isEmpty, loginType != "unknown" {
                        self.userLoginType = loginType
                        // 🎯 更新缓存（与头像查询一致）
                        self.loginTypeCache[userId] = loginType
                        self.hasLoadedLoginType = true
                    } else {
                        // 🔧 修复：查询失败时，使用推断逻辑作为兜底（与最近上线时间逻辑一致）
                        let inferredType = UserTypeUtils.getLoginTypeFromUserId(userId)
                        if inferredType != "unknown" {
                            self.userLoginType = inferredType
                            // 更新缓存（使用推断的类型）
                            self.loginTypeCache[userId] = inferredType
                        }
                        self.hasLoadedLoginType = true
                    }
                }
            }
        }
    }
    
    // 从用户ID推断登录类型
    private func getLoginTypeFromUserId(_ userId: String, message: MessageItem) -> String {
        // 优先使用实时查询的用户类型（参考头像界面方式）
        if let queriedLoginType = userLoginType, !queriedLoginType.isEmpty, queriedLoginType != "unknown" {
            return queriedLoginType
        }
        
        // 其次使用Message中的登录类型信息（但排除 unknown）
        if userId == message.senderId, let senderLoginType = message.senderLoginType, senderLoginType != "unknown" {
            return senderLoginType
        }
        
        // 如果没有登录类型信息，则通过用户ID前缀推断（向后兼容旧格式）
        // ⚠️ 注意：新版本中所有登录类型的 userId 都统一使用 objectId，无法通过前缀判断
        if userId.hasPrefix("apple_") {
            return "apple"
        } else if userId.hasPrefix("guest_") {
            // 🎯 注意：新版本的游客账号 userId 也是 objectId，不再使用此格式
            return "guest"
        } else if userId.hasPrefix("internal_") {
            return "guest"
        } else {
            // 🎯 修改：对于 objectId 格式的 userId（24位十六进制字符串），默认返回 guest
            // 因为无法通过 objectId 判断具体类型，需要依赖其他信息（如 loginType 字段）
            return "guest"
        }
    }
    
    // 打印UserAvatarRecord表中的对应记录
    private func printUserAvatarRecord(userId: String, message: MessageItem) {
        // 🎯 修改：使用 fetchUserAvatarByUserId，不依赖 loginType
        LeanCloudService.shared.fetchUserAvatarByUserId(objectId: userId) { avatar, error in
            DispatchQueue.main.async { [self] in
                if error != nil {
                } else if let avatar = avatar {
                    // 对比显示的头像和数据库记录
                    if avatar != self.latestSenderAvatar && !self.latestSenderAvatar.isEmpty {
                    }
                } else {
                }
            }
        }
    }
    
    // 🎯 新增：处理同意好友申请并点亮爱心按钮
    private func handleAcceptFriendRequest(requestId: String) {
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
                
                // 提前获取头像（避免在闭包中访问 binding）
                let currentMessage = message
                let cachedAvatar = avatarCache[otherUserId] ?? currentMessage.senderAvatar
                
                FriendshipManager.shared.acceptFriendshipRequest(request, attributes: nil) { success, errorMessage in
                    DispatchQueue.main.async {
                        if success {
                            
                            // 🎯 新增：点击同意按钮应视为点亮爱心按钮
                            // 调用 onToggleFavorite 点亮爱心按钮
                            onToggleFavorite(
                                otherUserId,
                                otherUserName,
                                otherUserEmail,
                                otherUserLoginType,
                                cachedAvatar,
                                nil // recordObjectId 可以为 nil
                            )
                            
                            
                            // 🚀 修复：等待 FriendshipManager 的缓存更新完成后再刷新
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                NotificationCenter.default.post(name: NSNotification.Name("RefreshNewFriends"), object: nil)
                                NotificationCenter.default.post(name: NSNotification.Name("FriendshipRequestUpdated"), object: nil)
                                
                                // 🚀 修复：延迟一点时间后再次刷新，确保服务器数据已更新
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    NotificationCenter.default.post(name: NSNotification.Name("RefreshNewFriends"), object: nil)
                                    NotificationCenter.default.post(name: NSNotification.Name("FriendshipRequestUpdated"), object: nil)
                                }
                            }
                        } else {
                        }
                    }
                }
            }
        }
    }
    
    // 🎯 新增：实时查询 favorite 状态 - 与用户名显示一致：实时查询服务器
    private func loadFavoriteStatusFromServer() {
        guard let currentUserId = UserDefaultsManager.getCurrentUserId() else {
            return
        }
        
        // 🔧 修复：提前捕获message的值，避免在异步回调中访问可能已失效的binding
        let currentMessage = message
        let favoriteUserId = currentMessage.senderId
        
        
        // 实时查询服务器状态
        LeanCloudService.shared.fetchFavoriteStatus(userId: currentUserId, favoriteUserId: favoriteUserId) { isFavorited, error in
            DispatchQueue.main.async { [self] in
                if error != nil {
                    // 查询失败时，使用本地缓存状态
                    self.favoriteStatusFromServer = nil
                } else {
                    // 更新服务器状态
                    self.favoriteStatusFromServer = isFavorited
                }
            }
        }
    }
}
