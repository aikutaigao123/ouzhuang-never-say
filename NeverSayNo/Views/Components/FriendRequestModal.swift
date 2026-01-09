import SwiftUI

// 加好友弹窗组件
struct FriendRequestModal: View {
    let record: LocationRecord
    let latestUserNames: [String: String]
    let onDismiss: () -> Void
    let onAddFavorite: ((String, String?, String?, String?, String?, String?) -> Void)? // 新增：发送好友请求成功后点亮爱心按钮的回调
    let onReportUser: ((String, String?, String?, String, String?, String?) -> Void)? // 新增：举报用户回调
    let hasReportedUser: ((String) -> Bool)? // 新增：检查是否已举报用户回调
    
    @State private var avatarFromServer: String? = nil
    @State private var userNameFromServer: String? = nil
    @State private var errorMessage: String? = nil
    @State private var avatarRetryCount: Int = 0 // 🎯 新增：头像重试次数（最多重试2次）
    @State private var userNameRetryCount: Int = 0 // 🎯 新增：用户名重试次数（最多重试2次）
    @State private var canSendFriendRequest: Bool = true
    @State private var showLimitAlert = false
    @State private var limitAlertMessage = ""
    @State private var showDuplicateAlert = false // 新增：显示重复发送提示
    @State private var showReportSheet = false // 新增：显示举报弹窗
    @State private var showReportLimitAlert = false // 🎯 新增：举报按钮限制提示
    @State private var reportLimitMessage = "" // 🎯 新增：举报按钮限制提示信息
    @State private var isUserBlocked = false // 🎯 新增：用户是否已被拉黑
    @State private var showBlockAlert = false // 🎯 新增：显示拉黑确认弹窗
    
    // 检查是否可以发送好友申请
    private func checkCanSendFriendRequest() {
        let (canSend, _) = UserDefaultsManager.canSendFriendRequest()
        canSendFriendRequest = canSend
    }
    
    // 计算用户名 - 与用户头像界面一致：实时查询服务器
    private var userName: String {
        let uid = record.userId
        // 第一优先级：从服务器实时查询的用户名
        if let serverName = userNameFromServer, !serverName.isEmpty {
            return serverName
        }
        // 第二优先级：本地缓存
        if let latest = latestUserNames[uid], !latest.isEmpty {
            return latest
        }
        // 第三优先级：record中的userName
        return record.userName ?? "未知用户"
    }
    
    // 计算头像 - 与用户头像界面一致：实时查询服务器
    private var resolvedAvatar: String? {
        let uid = record.userId
        // 第一优先级：从服务器实时查询的头像（与用户头像界面一致）
        if let serverAvatar = avatarFromServer, !serverAvatar.isEmpty {
            return serverAvatar
        }
        // 第二优先级：从 UserDefaults 获取头像（与用户头像界面一致：使用 displayAvatar，对应 UserDefaults）
        if let customAvatar = UserDefaultsManager.getCustomAvatar(userId: uid), !customAvatar.isEmpty {
            return customAvatar
        }
        // 第三优先级：record中的userAvatar
        if let recordAvatar = record.userAvatar, !recordAvatar.isEmpty {
            return recordAvatar
        }
        // 第四优先级：返回 nil，由显示层使用默认头像
        return nil
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
    
    var body: some View {
        ZStack {
            // 背景遮罩 - 全屏半透明黑色
            Color.black.opacity(0.4)
                .ignoresSafeArea(.all)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onTapGesture {
                    onDismiss()
                }
            
            // 弹窗内容
            VStack(spacing: 20) {
                // 右上角拉黑和举报按钮
                HStack {
                    Spacer()
                    HStack(spacing: 8) {
                        // 🎯 新增：拉黑按钮（在举报按钮左侧）
                        if isUserBlocked {
                            // 已拉黑状态
                            HStack(spacing: 4) {
                                Image(systemName: "hand.raised.fill")
                                    .foregroundColor(.purple)
                                    .font(.system(size: 12))
                                Text("已拉黑")
                                    .font(.caption)
                                    .foregroundColor(.purple)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(6)
                        } else {
                            // 拉黑按钮
                            Button(action: {
                                showBlockAlert = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "hand.raised")
                                        .foregroundColor(.purple)
                                        .font(.system(size: 12))
                                    Text("拉黑")
                                        .font(.caption)
                                        .foregroundColor(.purple)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // 举报按钮
                        if let hasReportedUser = hasReportedUser, onReportUser != nil {
                            if hasReportedUser(record.userId) {
                                // 已举报状态
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 12))
                                    Text("已举报")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(6)
                            } else {
                                // 举报按钮
                                Button(action: {
                                    // 🎯 新增：检查举报按钮点击次数限制
                                    guard let currentUserId = UserDefaultsManager.getCurrentUserId() else {
                                        showReportSheet = true
                                        return
                                    }
                                    
                                    let (canClick, message) = UserDefaultsManager.canClickReportButton(userId: currentUserId)
                                    if canClick {
                                        showReportSheet = true
                                    } else {
                                        reportLimitMessage = message
                                        showReportLimitAlert = true
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "exclamationmark.triangle")
                                            .foregroundColor(.red)
                                            .font(.system(size: 12))
                                        Text("举报")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(6)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.trailing, 8)
                
                // 用户头像（与用户头像界面一致：实时查询服务器）
                VStack(spacing: 12) {
                    if let avatar = resolvedAvatar, !avatar.isEmpty {
                        if avatar == "apple_logo" || avatar == "applelogo" {
                            Image(systemName: "applelogo")
                                .font(.system(size: 60))
                                .foregroundColor(.black)
                        } else if UserAvatarUtils.isSFSymbol(avatar) {
                            // 🔧 修复：检查是否是 SF Symbol，如果是则显示图标而不是文字
                            Image(systemName: avatar)
                                .font(.system(size: 60))
                                .foregroundColor(avatar == "person.circle.fill" ? .purple : .blue)
                        } else {
                            Text(avatar)
                                .font(.system(size: 60))
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    } else {
                        DefaultAvatarView(loginType: record.loginType)
                            .font(.system(size: 60))
                    }
                }
                .background(
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 100, height: 100)
                )
                .onAppear {
                    // 与用户头像界面一致：在onAppear时实时查询服务器头像和用户名
                    loadAvatarFromServer()
                    loadUserNameFromServer()
                    // 检查是否可以发送好友申请
                    checkCanSendFriendRequest()
                    
                    // 🎯 新增：检查用户是否已被拉黑
                    isUserBlocked = LocalBlacklistManager.shared.isUserInLocalBlacklist(record.userId)
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("LocalBlacklistUpdated"))) { _ in
                    // 🎯 新增：监听本地黑名单更新通知
                    isUserBlocked = LocalBlacklistManager.shared.isUserInLocalBlacklist(record.userId)
                }
                .alert("确认拉黑", isPresented: $showBlockAlert) {
                    Button("取消", role: .cancel) { }
                    Button("确认", role: .destructive) {
                        // 执行拉黑操作（内部已发送LocalBlacklistUpdated通知，无需重复发送）
                        LocalBlacklistManager.shared.addUserToLocalBlacklist(record.userId)
                        
                        // 更新本地状态
                        isUserBlocked = true
                        
                        // 关闭弹窗（异步执行，避免阻塞）
                        DispatchQueue.main.async {
                            onDismiss()
                            
                            // 延迟发送RefreshMatchStatus通知，避免阻塞UI
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                NotificationCenter.default.post(name: NSNotification.Name("RefreshMatchStatus"), object: nil)
                            }
                            
                            // 发送通知回到主页面
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                NotificationCenter.default.post(name: NSNotification.Name("NavigateToMainTab"), object: nil)
                            }
                        }
                    }
                } message: {
                    Text("拉黑后，该用户将无法出现在您的匹配结果和历史记录中。确定要拉黑此用户吗？")
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
                
                // 用户信息
                VStack(spacing: 8) {
                    ColorfulUserNameText(
                        userName: userName,
                        userId: record.userId,
                        loginType: record.loginType,
                        font: .title2,
                        fontWeight: .bold,
                        lineLimit: 1,
                        truncationMode: .tail
                    )
                    
                    Text("想要添加为好友吗？")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    // 错误提示
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top, 4)
                    }
                }
                
                // 操作按钮
                HStack(spacing: 16) {
                    // 取消按钮
                    Button(action: onDismiss) {
                        Text("取消")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    // 发送好友请求按钮（直接点亮爱心按钮，无需弹窗提示）
                    Button(action: {
                        sendFriendRequest()
                    }) {
                        Text("发送好友请求")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .background(canSendFriendRequest ? Color.blue : Color.gray)
                    .cornerRadius(8)
                    // 🎯 移除 .disabled()，让按钮始终可点击，点击时检查限制并显示弹窗
                }
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 32)
            .alert("今日好友申请已超过上限", isPresented: $showLimitAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(limitAlertMessage)
            }
            .alert("请勿重复发送好友请求", isPresented: $showDuplicateAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text("1分钟内已向该用户发送过好友请求，请稍后再试")
            }
            .sheet(isPresented: $showReportSheet) {
                ReportSheetView(
                    userId: record.userId,
                    userName: userName,
                    loginType: record.loginType,
                    userEmail: record.userEmail,
                    onReport: { reason in
                        if let onReportUser = onReportUser {
                            onReportUser(
                                record.userId,
                                userName,
                                record.userEmail,
                                reason,
                                record.deviceId,
                                record.loginType
                            )
                        }
                        showReportSheet = false
                    }
                )
            }
            .alert("举报访问限制", isPresented: $showReportLimitAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(reportLimitMessage)
            }
        }
    }
    
    // 发送好友请求（简化为直接点亮爱心按钮，无需弹窗提示）
    private func sendFriendRequest() {
        
        // 清除之前的错误信息
        errorMessage = nil
        
        // 检查是否登录
        guard let currentUserId = UserDefaultsManager.getCurrentUserId() else {
            return
        }
        
        // 检查是否向自己发送请求
        if record.userId == currentUserId {
            return
        }
        
        // 🎯 检查24小时内好友申请数量限制（在点击时检查，不依赖API结果）
        let (canSend, limitErrorMessage) = UserDefaultsManager.canSendFriendRequest()
        if !canSend {
            // 超过限制，显示弹窗提示
            limitAlertMessage = limitErrorMessage
            showLimitAlert = true
            return
        }
        
        // 🎯 检查是否在1分钟内向同一用户发送过好友请求
        if UserDefaultsManager.hasSentFriendRequestToUserInLastMinute(targetUserId: record.userId) {
            showDuplicateAlert = true
            return
        }
        
        // 🎯 立即记录发送时间（在点击时记录，不依赖API结果）
        UserDefaultsManager.recordFriendRequestSent(to: record.userId)
        UserDefaultsManager.recordFriendRequestSentToUser(targetUserId: record.userId)
        
        // 更新按钮状态
        checkCanSendFriendRequest()
        
        // 🔧 修复：实际发送好友申请到服务器
        let userId = record.userId
        let userNameValue = userName // 使用计算属性获取最新用户名
        let userEmail = record.userEmail
        let loginType = record.loginType ?? "guest"
        let userAvatar = resolvedAvatar ?? record.userAvatar
        let objectId = record.objectId
        
        
        // 获取当前用户信息用于发送
        guard let currentUserId = UserDefaultsManager.getCurrentUserId() else {
            // 如果无法获取当前用户ID，至少更新UI
            if let onAddFavorite = onAddFavorite {
                onAddFavorite(userId, userNameValue, userEmail, loginType, userAvatar, objectId)
            }
            DispatchQueue.main.async {
                self.onDismiss()
            }
            return
        }
        
        // 获取当前用户信息
        let senderName = UserDefaultsManager.getCurrentUserName()
        let senderAvatar = UserDefaultsManager.getCustomAvatar(userId: currentUserId) ?? "person.circle"
        
        // 发送好友申请到服务器
        let finalAvatar = userAvatar ?? "person.circle"
        MessageHelpers.sendFavoriteMessage(
            senderId: currentUserId,
            senderName: senderName.isEmpty ? currentUserId : senderName,
            senderAvatar: senderAvatar,
            receiverId: userId,
            receiverName: userNameValue,
            receiverAvatar: finalAvatar,
            receiverLoginType: loginType,
            currentUser: nil // MessageHelpers 内部会处理，这里可以传nil
        )
        
        // 🎯 直接点亮对应的爱心按钮，无需执行其他操作，无需弹窗提示
        if let onAddFavorite = onAddFavorite {
            // 直接调用回调点亮爱心按钮
            onAddFavorite(userId, userNameValue, userEmail, loginType, userAvatar, objectId)
        }
        
        // 直接关闭弹窗，无需提示
        DispatchQueue.main.async {
            self.onDismiss()
        }
    }
}

#Preview {
    FriendRequestModal(
        record: LocationRecord(
            id: 1,
            objectId: "test_object_id",
            timestamp: "2024-01-01T00:00:00Z",
            latitude: 39.9042,
            longitude: 116.4074,
            accuracy: 10.0,
            userId: "test_user",
            userName: "测试用户",
            loginType: "guest",
            userEmail: "test@example.com",
            userAvatar: "😊",
            deviceId: "test_device",
            clientTimestamp: Date().timeIntervalSince1970,
            timezone: "Asia/Shanghai"
        ),
        latestUserNames: ["test_user": "测试用户"],
        onDismiss: {},
        onAddFavorite: nil,
        onReportUser: nil,
        hasReportedUser: nil
    )
}
