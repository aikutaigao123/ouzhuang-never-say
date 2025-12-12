import SwiftUI
import CoreLocation

// 我Tab - 个人信息界面
struct ProfileTabView: View {
    @ObservedObject var userManager: UserManager
    @ObservedObject var diamondManager: DiamondManager
    @ObservedObject var newFriendsCountManager: NewFriendsCountManager
    
    // 使用外部传入的历史记录数据，避免重复加载
    @Binding var randomMatchHistory: [RandomMatchHistory]
    @Binding var latestAvatars: [String: String]
    @Binding var latestUserNames: [String: String]
    @ObservedObject var locationManager: LocationManager // 使用外部传入的位置管理器
    
    @State private var showRandomHistory = false
    @State private var showLogoutAlert = false
    @State private var userLoginTypeCache: [String: String] = [:] // 🔧 优化：添加用户类型本地缓存
    
    var body: some View {
        ProfileView(
            userManager: userManager,
            diamondManager: diamondManager,
            showLogoutAlert: $showLogoutAlert,
            showRechargeSheet: .constant(false),
            newUserName: .constant(""),
            isUserBlacklisted: false,
            onClearAllHistory: {
                // 执行清理逻辑
                clearAllHistory()
            },
            onShowHistory: {
                // 🎯 新增：检查历史记录按钮点击次数限制
                guard let userId = userManager.currentUser?.id else {
                    // 如果没有用户ID，直接执行原有逻辑
                    executeShowHistory()
                    return
                }
                
                let (canClick, message) = UserDefaultsManager.canClickHistoryButton(userId: userId)
                if canClick {
                    // 记录点击
                    UserDefaultsManager.recordHistoryButtonClick(userId: userId)
                    // 执行原有逻辑
                    executeShowHistory()
                } else {
                    // 显示限制提示（通过通知或其他方式）
                    // 注意：这里无法直接显示 alert，因为是在闭包中
                    // 可以通过 NotificationCenter 发送通知，让 ProfileView 显示 alert
                    NotificationCenter.default.post(
                        name: NSNotification.Name("HistoryButtonLimitExceeded"),
                        object: nil,
                        userInfo: ["message": message]
                    )
                }
            },
            newFriendsCountManager: newFriendsCountManager,
            onNavigateToTab: { tabIndex in
                // 导航到其他标签页的逻辑
            },
            showBottomTabBar: false
        )
        .sheet(isPresented: $showRandomHistory, onDismiss: {
            // 🔍 调试：我Tab历史记录界面关闭
            let currentTime = Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let _ = formatter.string(from: currentTime)
            
            // 发送通知返回到主界面 - 与个人信息界面保持一致
            NotificationCenter.default.post(name: NSNotification.Name("DismissProfileSheet"), object: nil)
        }) {
            ZStack {
                // 背景点击区域 - 使用全屏背景
                Color.black.opacity(0.001) // 几乎透明但可点击
                    .ignoresSafeArea()
                    .onTapGesture {
                        // 🔍 调试：我Tab历史记录界面背景点击
                        let currentTime = Date()
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                        let _ = formatter.string(from: currentTime)
                        
                        showRandomHistory = false
                        // 发送通知返回到主界面 - 与个人信息界面保持一致
                        NotificationCenter.default.post(name: NSNotification.Name("DismissProfileSheet"), object: nil)
                    }
                    .onAppear {
                        // 🔍 调试：ProfileTabView 中的 RandomMatchHistoryView 调用
                        let currentTime = Date()
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                        let _ = formatter.string(from: currentTime)
                        for (_, _) in randomMatchHistory.enumerated() {
                        }
                    }
                
                // 历史记录内容 - 与个人信息界面保持一致
                RandomMatchHistoryView(
                    history: randomMatchHistory,
                    calculateDistance: DistanceUtils.calculateDistance,
                    formatDistance: DistanceUtils.formatDistance,
                    formatTimestamp: TimestampUtils.formatTimestamp,
                    calculateBearing: BearingUtils.calculateBearing,
                    getDirectionText: BearingUtils.getDirectionText,
                    calculateTimezoneFromLongitude: TimezoneUtils.calculateTimezoneFromLongitude,
                    getTimezoneName: TimezoneUtils.getTimezoneName,
                    onClearHistory: clearRandomMatchHistory,
                    onDeleteHistoryItem: deleteRandomMatchHistoryItem,
                    onReportUser: { userId, userName, userEmail, reason, deviceId, loginType in
                        addReportRecord(reportedUserId: userId, reportedUserName: userName, reportedUserEmail: userEmail, reportReason: reason, reportedDeviceId: deviceId, reportedUserLoginType: loginType)
                    },
                    hasReportedUser: hasReportedUser,
                    avatarResolver: { uid, ltype, snapshot in
                        // 与用户头像界面一致：不使用全局缓存，优先使用本地缓存
                        if let uid = uid, let latest = latestAvatars[uid], !latest.isEmpty { return latest }
                        return snapshot
                    },
                    userNameResolver: { uid, ltype in
                        // 与用户头像界面一致：不使用全局缓存，优先使用本地缓存
                        if let uid = uid, let latest = latestUserNames[uid], !latest.isEmpty { return latest }
                        return nil
                    },
                    ensureLatestAvatar: { uid, ltype in
                        ensureLatestAvatar(userId: uid, loginType: ltype)
                    },
                    isUserFavorited: { userId in
                        // 🔧 修复：使用与ContentView相同的数据源检查爱心状态
                        guard let currentUser = userManager.currentUser else { return false }
                        let favoriteKey = StorageKeyUtils.getFavoriteRecordsKey(for: currentUser)
                        
                        if let data = UserDefaults.standard.data(forKey: favoriteKey),
                           let favoriteRecords = try? JSONDecoder().decode([FavoriteRecord].self, from: data) {
                            return favoriteRecords.contains { $0.favoriteUserId == userId && ($0.status == "active" || $0.status == nil) }
                        }
                        return false
                    },
                    isUserFavoritedByMe: { userId in
                        // 🔧 优化：暂时返回false，后续可以添加类似的通知机制
                        return false
                    },
                    onToggleFavorite: { userId, userName, userEmail, loginType, userAvatar, recordObjectId in
                        // 🔧 优化：暂时使用本地UserDefaults操作，后续可以优化为统一数据源
                        guard let currentUser = userManager.currentUser else { return }
                        let favoriteKey = StorageKeyUtils.getFavoriteRecordsKey(for: currentUser)
                        
                        // 🔍 新增：打印ProfileTabView爱心按钮操作信息
                        let currentTime = Date()
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                        let _ = formatter.string(from: currentTime)
                        
                        // 🔧 修复：使用与ContentView相同的数据源检查爱心状态
                        let _ = if let data = UserDefaults.standard.data(forKey: favoriteKey),
                           let favoriteRecords = try? JSONDecoder().decode([FavoriteRecord].self, from: data) {
                            favoriteRecords.contains { $0.favoriteUserId == userId && ($0.status == "active" || $0.status == nil) }
                        } else {
                            false
                        }
                        
                        
                        // 🔧 修复：使用与ContentView相同的操作逻辑
                        if let favoriteData = UserDefaults.standard.data(forKey: favoriteKey),
                           var favoriteRecords = try? JSONDecoder().decode([FavoriteRecord].self, from: favoriteData) {
                            
                            if favoriteRecords.contains(where: { $0.favoriteUserId == userId && ($0.status == "active" || $0.status == nil) }) {
                                // 移除收藏记录
                                favoriteRecords.removeAll { $0.favoriteUserId == userId }
                            } else {
                                // 添加收藏记录
                                let favoriteRecord = FavoriteRecord(
                                    userId: currentUser.id, // 🔧 统一：使用 objectId（与 UserNameRecord、UserAvatarRecord 一致）
                                    favoriteUserId: userId,
                                    favoriteUserName: userName,
                                    favoriteUserEmail: userEmail,
                                    favoriteUserLoginType: loginType,
                                    favoriteUserAvatar: userAvatar,
                                    recordObjectId: recordObjectId
                                )
                                favoriteRecords.append(favoriteRecord)
                            }
                            
                            // 保存更新后的数据
                            if let updatedData = try? JSONEncoder().encode(favoriteRecords) {
                                UserDefaults.standard.set(updatedData, forKey: favoriteKey)
                            }
                            
                            // 🔍 新增：打印操作后的状态
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                let _ = if let data = UserDefaults.standard.data(forKey: favoriteKey),
                                   let favoriteRecords = try? JSONDecoder().decode([FavoriteRecord].self, from: data) {
                                    favoriteRecords.contains { $0.favoriteUserId == userId && ($0.status == "active" || $0.status == nil) }
                                } else {
                                    false
                                }
                            }
                        }
                    },
                    isUserLiked: isUserLiked,
                    onToggleLike: { userId, userName, userEmail, loginType, userAvatar, recordObjectId in
                        if isUserLiked(userId: userId) {
                            removeLikeRecord(userId: userId)
                        } else {
                            addLikeRecord(
                                userId: userId,
                                userName: userName,
                                userEmail: userEmail,
                                loginType: loginType,
                                userAvatar: userAvatar,
                                recordObjectId: recordObjectId
                            )
                        }
                    },
                    onHistoryItemTap: handleHistoryItemTap,
                    locationManager: locationManager // 传递位置管理器
            )
            .background(Color.clear) // 防止历史记录内容拦截背景点击
            }
        }
        .alert("确认退出", isPresented: $showLogoutAlert) {
            Button("取消", role: .cancel) { }
                   Button("退出", role: .destructive) {
                       
                       // 设置标志，表示是从ProfileTab退出登录
                       UserDefaults.standard.set(true, forKey: "isFromProfileTabLogout")
                       
                       
                       // 执行退出登录
                       userManager.logout()
                       
                       // 重置导航状态，避免 SwiftUI 导航路径类型不匹配
                       DispatchQueue.main.async {
                           // 发送通知重置导航状态
                           NotificationCenter.default.post(name: NSNotification.Name("ResetNavigationState"), object: nil)
                       }
                   }
        } message: {
            Text("确定要退出登录吗？")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SyncRandomMatchHistory"))) { notification in
            // 🔧 新增：接收ContentView的数据同步通知
            if let syncedHistory = notification.object as? [RandomMatchHistory] {
                
                // 同步数据
                randomMatchHistory = syncedHistory
                
            }
        }
    }
    
    // 清除所有历史记录 - 删除账号时调用，完整清除所有本地数据
    func clearAllHistory() {
        guard let currentUser = userManager.currentUser else { 
            return 
        }
        
        NSLog("🗑️ [ProfileTabView] 开始清除所有历史记录")
        
        // 🗑️ 清除所有历史记录和缓存
        UserDefaults.standard.removeObject(forKey: StorageKeyUtils.getHistoryKey(for: currentUser))
        UserDefaults.standard.removeObject(forKey: "locationHistory")
        UserDefaults.standard.removeObject(forKey: "blacklistedUserIds")
        UserDefaults.standard.removeObject(forKey: StorageKeyUtils.getFavoriteRecordsKey(for: currentUser))
        UserDefaults.standard.removeObject(forKey: StorageKeyUtils.getReportRecordsKey(for: currentUser))
        
        // 清除点赞记录
        let likeKey = "likeRecords_\(currentUser.userId)"
        UserDefaults.standard.removeObject(forKey: likeKey)
        
        // 清除消息记录
        let messagesKey = "messages_\(currentUser.userId)"
        UserDefaults.standard.removeObject(forKey: messagesKey)
        
        // 清除用户操作缓存
        UserActionCacheManager.shared.clearUserCache(currentUserId: currentUser.userId)
        
        // 发送历史清除通知
        NotificationCenter.default.post(name: .init("HistoryCleared"), object: nil)
        
        NSLog("✅ [ProfileTabView] 所有历史记录已清除")
    }
    
    // 获取点赞记录键值
    func getLikeRecordsKey() -> String {
        guard let currentUser = userManager.currentUser else { return "likeRecords" }
        return "likeRecords_\(currentUser.userId)"
    }
    
    
    // MARK: - 历史记录相关功能
    
    // 清除随机匹配历史
    func clearRandomMatchHistory() {
        guard let currentUser = userManager.currentUser else { return }
        let historyKey = StorageKeyUtils.getHistoryKey(for: currentUser)
        UserDefaults.standard.removeObject(forKey: historyKey)
        randomMatchHistory.removeAll()
        
        // 🔧 修复：发送历史清除通知，确保ContentView也能同步更新
        NotificationCenter.default.post(name: .init("HistoryCleared"), object: nil)
        
    }
    
    // 删除单个历史记录项
    func deleteRandomMatchHistoryItem(_ historyItem: RandomMatchHistory) {
        let startTime = Date()
        let currentTime = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        let _ = formatter.string(from: currentTime)
        
        
        // 🔍 添加详细的记录状态检查
        let recordExists = randomMatchHistory.contains { $0.id == historyItem.id }
        if recordExists {
            let _ = randomMatchHistory.firstIndex { $0.id == historyItem.id }
        }
        
        guard let currentUser = userManager.currentUser else { 
            return 
        }
        let historyKey = StorageKeyUtils.getHistoryKey(for: currentUser)
        
        // 🔧 优化：立即从UI中移除，提供即时反馈
        let _ = randomMatchHistory.count
        randomMatchHistory.removeAll { $0.id == historyItem.id }
        let _ = randomMatchHistory.count
        
        // 🔍 添加删除后的状态检查
        let _ = randomMatchHistory.contains { $0.id == historyItem.id }
        
        // 🔧 优化：异步保存到UserDefaults，避免阻塞UI
        DispatchQueue.global(qos: .userInitiated).async {
            let saveStartTime = Date()
            
            if let data = try? JSONEncoder().encode(self.randomMatchHistory) {
                UserDefaults.standard.set(data, forKey: historyKey)
                let _ = Date().timeIntervalSince(saveStartTime)
            } else {
            }
        }
        
        // 🔧 优化：减少通知延迟，使用更高效的数据同步
        DispatchQueue.main.async {
            let notificationStartTime = Date()
            
            NotificationCenter.default.post(
                name: .init("HistoryItemDeleted"), 
                object: historyItem
            )
            
            // 🔧 新增：同步删除操作到ContentView
            NotificationCenter.default.post(
                name: .init("ProfileTabHistoryItemDeleted"), 
                object: historyItem
            )
            
            let _ = Date().timeIntervalSince(notificationStartTime)
        }
        
        let _ = Date().timeIntervalSince(startTime)
    }
    
    // 添加举报记录
    func addReportRecord(reportedUserId: String, reportedUserName: String?, reportedUserEmail: String?, reportReason: String, reportedDeviceId: String?, reportedUserLoginType: String?) {
        // 这里需要实现举报功能，暂时留空
    }
    
    // 检查用户是否已被举报
    func hasReportedUser(_ userId: String) -> Bool {
        // 这里需要实现检查举报状态的功能，暂时返回false
        return false
    }
    
    // 确保最新头像
    func ensureLatestAvatar(userId: String?, loginType: String?) {
        // 这里需要实现头像更新功能，暂时留空
    }
    
    // 🔧 优化：移除重复的数据加载逻辑，现在使用ContentView的数据源
    // loadRandomMatchHistory方法已移除，数据通过Binding从ContentView传递
    
    // 🔧 优化：移除重复的爱心按钮状态逻辑，现在使用ContentView的统一数据源
    // 这些方法已移除，通过通知机制使用ContentView的爱心按钮状态
    
    // 检查用户是否被点赞
    func isUserLiked(userId: String) -> Bool {
        guard let currentUser = userManager.currentUser else { return false }
        let likeKey = StorageKeyUtils.getLikedLocationRecordsKey(for: currentUser)
        if let likeData = UserDefaults.standard.array(forKey: likeKey) as? [[String: Any]] {
            return likeData.contains { $0["userId"] as? String == userId }
        }
        return false
    }
    
    // 移除点赞记录
    func removeLikeRecord(userId: String) {
        guard let currentUser = userManager.currentUser else { return }
        let likeKey = StorageKeyUtils.getLikedLocationRecordsKey(for: currentUser)
        if var likeData = UserDefaults.standard.array(forKey: likeKey) as? [[String: Any]] {
            likeData.removeAll { $0["userId"] as? String == userId }
            UserDefaults.standard.set(likeData, forKey: likeKey)
        }
    }
    
    // 添加点赞记录
    func addLikeRecord(userId: String, userName: String?, userEmail: String?, loginType: String?, userAvatar: String?, recordObjectId: String?) {
        guard let currentUser = userManager.currentUser else { return }
        let likeKey = StorageKeyUtils.getLikedLocationRecordsKey(for: currentUser)
        var likeData = UserDefaults.standard.array(forKey: likeKey) as? [[String: Any]] ?? []
        
        let likeRecord: [String: Any] = [
            "userId": userId,
            "userName": userName ?? "",
            "userEmail": userEmail ?? "",
            "loginType": loginType ?? "",
            "userAvatar": userAvatar ?? "",
            "record_object_id": recordObjectId ?? ""
        ]
        
        likeData.append(likeRecord)
        UserDefaults.standard.set(likeData, forKey: likeKey)
    }
    
    // 处理历史记录项点击
    func handleHistoryItemTap(_ historyItem: RandomMatchHistory) {
        // 这里需要实现点击历史记录项的逻辑，暂时留空
    }
    
    // 🎯 新增：执行显示历史记录的逻辑（提取出来以便在限制检查后调用）
    private func executeShowHistory() {
        // 🔧 我界面历史记录按钮点击详细信息
        let currentTime = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let _ = formatter.string(from: currentTime)
        
        
        // 详细打印每个历史记录项
        if randomMatchHistory.isEmpty {
        } else {
            for (_, historyItem) in randomMatchHistory.enumerated() {
                let _ = historyItem.record.userId
                let _ = historyItem.record.userName ?? "nil"
                let _ = historyItem.record.userEmail ?? "nil"
                let _ = historyItem.record.loginType ?? "nil"
                let _ = historyItem.record.deviceId
                let _ = historyItem.record.timestamp
                let _ = historyItem.record.latitude
                let _ = historyItem.record.longitude
                
            }
        }
        
        // 🔍 新增：打印历史记录中每个用户的爱心按钮状态
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        let favoriteKey = StorageKeyUtils.getFavoriteRecordsKey(for: currentUser)
        if let data = UserDefaults.standard.data(forKey: favoriteKey),
           let favoriteRecords = try? JSONDecoder().decode([FavoriteRecord].self, from: data) {
            for (_, historyItem) in randomMatchHistory.enumerated() {
                let _ = historyItem.record.userId
                let _ = historyItem.record.userName ?? "nil"
                let _ = favoriteRecords.contains { $0.favoriteUserId == historyItem.record.userId && ($0.status == "active" || $0.status == nil) }
            }
        } else {
            for (_, historyItem) in randomMatchHistory.enumerated() {
                let _ = historyItem.record.userId
                let _ = historyItem.record.userName ?? "nil"
            }
        }
        
        
        // 🔧 修复：统一数据加载逻辑，确保与个人信息界面一致
        // 始终发送重新加载通知，确保数据是最新的
        NotificationCenter.default.post(name: NSNotification.Name("ReloadRandomMatchHistory"), object: nil)
        
        // 🔧 新增：请求ContentView的数据源
        NotificationCenter.default.post(name: NSNotification.Name("RequestRandomMatchHistory"), object: nil)
        
        // 等待数据加载完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            
            if !self.randomMatchHistory.isEmpty {
                // 重新检查爱心状态
                guard let currentUser = self.userManager.currentUser else {
                    self.showRandomHistory = true
                    return
                }
                
                let favoriteKey = StorageKeyUtils.getFavoriteRecordsKey(for: currentUser)
                if let data = UserDefaults.standard.data(forKey: favoriteKey),
                   let favoriteRecords = try? JSONDecoder().decode([FavoriteRecord].self, from: data) {
                    for (_, historyItem) in self.randomMatchHistory.enumerated() {
                        let _ = historyItem.record.userId
                        let _ = historyItem.record.userName ?? "nil"
                        let _ = favoriteRecords.contains { $0.favoriteUserId == historyItem.record.userId && ($0.status == "active" || $0.status == nil) }
                    }
                }
            } else {
            }
            self.showRandomHistory = true
        }
    }
    
    // 加载历史记录数据
    func loadHistoryData() {
        
        guard let currentUser = userManager.currentUser else { 
            return 
        }
        
        let historyKey = StorageKeyUtils.getHistoryKey(for: currentUser)
        
        if let data = UserDefaults.standard.data(forKey: historyKey) {
            do {
                let history = try JSONDecoder().decode([RandomMatchHistory].self, from: data)
                randomMatchHistory = history
            } catch {
                randomMatchHistory = []
            }
        } else {
            randomMatchHistory = []
        }
        
    }
}

// 编辑资料界面
struct EditProfileView: View {
    @ObservedObject var userManager: UserManager
    @Environment(\.dismiss) private var dismiss
    @State private var newName: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("编辑资料功能")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("这里可以编辑用户资料")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationTitle("编辑资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// 设置界面
struct SettingsView: View {
    @ObservedObject var userManager: UserManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("设置功能")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("这里可以设置应用偏好")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}
