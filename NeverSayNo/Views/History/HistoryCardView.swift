import SwiftUI
import CoreLocation

// 历史记录卡片视图
struct HistoryCardView: View {
    let historyItem: RandomMatchHistory
    let calculateDistance: (CLLocation, Double, Double) -> Double
    let formatDistance: (Double) -> String
    let formatTimestamp: (String, String?) -> String
    let calculateTimezoneFromLongitude: (Double) -> String
    let getTimezoneName: (Double) -> String
    let onReportUser: (String, String?, String?, String, String?, String?) -> Void
    let hasReportedUser: (String) -> Bool
    let avatarResolver: (String?, String?, String?) -> String?
    let userNameResolver: (String?, String?) -> String?
    let ensureLatestAvatar: (String?, String?) -> Void
    let isUserFavorited: (String) -> Bool
    let isUserFavoritedByMe: (String) -> Bool
    let onToggleFavorite: (String, String?, String?, String?, String?, String?) -> Void
    let isUserLiked: (String) -> Bool
    let onToggleLike: (String, String?, String?, String?, String?, String?) -> Void
    let locationManager: LocationManager? // 新增：位置管理器，用于动态距离计算
    
    // 计算并解析头像 - 🎯 参考排行榜：只从 UserAvatarRecord 表获取，不从历史记录快照读取
    private var resolvedAvatar: String? {
        // 第一优先级：从服务器实时查询的头像（从 UserAvatarRecord 表获取）
        if let serverAvatar = avatarFromServer, !serverAvatar.isEmpty {
            return serverAvatar
        }
        // 第二优先级：从 UserDefaults 获取头像（缓存的头像）
        if let customAvatar = UserDefaultsManager.getCustomAvatar(userId: historyItem.record.userId), !customAvatar.isEmpty {
            return customAvatar
        }
        // 第三优先级：使用默认头像（由 avatarResolver 提供）
        // 🎯 不再从历史记录快照中读取头像
        let fallbackAvatar = avatarResolver(historyItem.record.userId, historyItem.record.loginType, nil)
        return fallbackAvatar
    }
    
    // 计算并解析用户名 - 🎯 参考排行榜：只从 UserNameRecord 表获取，不从历史记录快照读取
    private var resolvedUserName: String? {
        // 第一优先级：从服务器实时查询的用户名（从 UserNameRecord 表获取）
        if let serverName = userNameFromServer, !serverName.isEmpty {
            return serverName
        }
        // 🎯 不再从历史记录快照中读取用户名
        // 如果服务器查询失败，返回 nil，由显示层处理（显示"未知用户"）
        return nil
    }
    
    // 从服务器加载头像 - 🎯 参考排行榜：统一从 UserAvatarRecord 表获取
    private func loadAvatarFromServer() {
        let uid = historyItem.record.userId
        
        // 🎯 参考排行榜：直接查询服务器，不检查缓存
        LeanCloudService.shared.fetchUserAvatarByUserId(objectId: uid) { avatar, error in
            DispatchQueue.main.async {
                if let avatar = avatar, !avatar.isEmpty {
                    // 🎯 新增：检查是否更新了UI显示（如果获取到新头像，更新状态）
                    let wasShowingDefault = self.isShowingDefaultAvatar
                    self.avatarFromServer = avatar
                    // 如果之前显示默认头像，现在获取到了新头像，UI会自动更新
                    if wasShowingDefault {
                        // 头像已更新，UI会自动刷新
                    }
                } else {
                    // 🎯 修改：查询失败时，如果 avatarFromServer 仍为 nil 且未达到最大重试次数，触发第二次重试
                    if self.avatarFromServer == nil && self.avatarRetryCount < 2 {
                        self.retryLoadAvatarFromServer()
                    }
                }
            }
        }
    }
    
    // 🎯 新增：检查是否显示默认头像
    private var isShowingDefaultAvatar: Bool {
        let avatar = resolvedAvatar
        if let avatar = avatar {
            return avatar == "person.circle.fill" || avatar == "person.circle"
        }
        return true
    }
    
    // 🎯 修改：重试查询头像（最多重试2次）
    // 重试时使用 loadAvatarFromServer()，该方法从 UserAvatarRecord 表查询
    private func retryLoadAvatarFromServer() {
        guard avatarRetryCount < 2 else {
            return
        }
        avatarRetryCount += 1
        
        // 🎯 修改：根据重试次数决定延迟时间
        // 第一次重试：延迟1/17秒；第二次重试：延迟0.5秒
        let delay: TimeInterval = avatarRetryCount == 1 ? 1.0 / 17.0 : 0.5
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // 🎯 修改：检查 avatarFromServer 是否为 nil（查询失败的情况）
            // 如果 avatarFromServer 仍为 nil，说明查询失败，应该重试
            let stillFailed = self.avatarFromServer == nil
            if stillFailed {
                self.loadAvatarFromServer()
            } else {
            }
        }
    }
    
    // 从服务器加载用户名 - 🎯 参考排行榜：统一从 UserNameRecord 表获取
    private func loadUserNameFromServer() {
        let uid = historyItem.record.userId
        
        // 🎯 参考排行榜：统一使用 fetchUserNameByUserId，不依赖 loginType，直接从 UserNameRecord 表获取
        LeanCloudService.shared.fetchUserNameByUserId(objectId: uid) { name, error in
            DispatchQueue.main.async {
                if let name = name, !name.isEmpty {
                    // 🎯 新增：检查是否更新了UI显示（如果获取到新用户名，更新状态）
                    let wasShowingUnknown = self.isShowingUnknownUser
                    self.userNameFromServer = name
                    
                    // 🎯 新增：更新 UserDefaults 中的用户名缓存（用于其他用户的信息）
                    let userDefaultsUserName = UserDefaultsManager.getFriendUserName(userId: uid)
                    if userDefaultsUserName != name {
                        UserDefaultsManager.setFriendUserName(userId: uid, userName: name)
                    }
                    
                    // 如果之前显示未知用户，现在获取到了新用户名，UI会自动更新
                    if wasShowingUnknown {
                        // 用户名已更新，UI会自动刷新
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
    
    // 🎯 新增：检查是否显示未知用户
    private var isShowingUnknownUser: Bool {
        // 🎯 只检查 userNameFromServer 是否为 nil（查询失败的情况）
        // 如果 userNameFromServer 为 nil，说明查询失败，应该显示"未知用户"
        if userNameFromServer == nil {
            return true
        }
        
        // 如果 userNameFromServer 不为 nil，检查 resolvedUserName 是否为 nil 或"未知用户"
        let displayName = resolvedUserName ?? "未知用户"
        return displayName == "未知用户"
    }
    
    // 🎯 修改：重试查询用户名（最多重试2次）
    // 重试时使用 loadUserNameFromServer()，该方法从 UserNameRecord 表查询
    private func retryLoadUserNameFromServer() {
        guard userNameRetryCount < 2 else {
            return
        }
        userNameRetryCount += 1
        
        // 🎯 修改：根据重试次数决定延迟时间
        // 第一次重试：延迟1/17秒；第二次重试：延迟0.5秒
        let delay: TimeInterval = userNameRetryCount == 1 ? 1.0 / 17.0 : 0.5
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // 🎯 修改：检查 userNameFromServer 是否为 nil（查询失败的情况）
            // 只要 userNameFromServer 仍为 nil，就重试以获取最新用户名
            let stillFailed = self.userNameFromServer == nil
            if stillFailed {
                self.loadUserNameFromServer()
            } else {
            }
        }
    }
    
    // 从服务器加载邮箱 - 与用户名查询逻辑一致
    private func loadEmailFromServer() {
        let uid = historyItem.record.userId
        let loginType = historyItem.record.loginType ?? "guest" // 提供默认值
        
        LeanCloudService.shared.fetchUserEmail(objectId: uid, loginType: loginType) { email, _ in
            DispatchQueue.main.async {
                if let email = email, !email.isEmpty {
                    self.emailFromServer = email
                }
            }
        }
    }

    @State private var showReportSheet = false
    @State private var selectedReportReason = "不当内容"
    @State private var showCopySuccess = false // 新增：显示复制成功提示
    @State private var copySuccessMessage = "" // 新增：复制成功消息
    @State private var showReportLimitAlert = false // 🎯 新增：举报按钮限制提示
    @State private var reportLimitMessage = "" // 🎯 新增：举报按钮限制提示信息
    @State private var calculatedDistance: Double? // 存储计算好的距离
    @State private var avatarFromServer: String? = nil
    @State private var userNameFromServer: String? = nil
    @State private var emailFromServer: String? = nil
    @State private var avatarRetryCount: Int = 0 // 🎯 修改：头像重试次数（最多重试2次）
    @State private var userNameRetryCount: Int = 0 // 🎯 修改：用户名重试次数（最多重试2次）
    @State private var favoriteStatusFromServer: Bool? = nil // 🎯 新增：从服务器实时查询的 favorite 状态
    
    // 获取匹配时距离（静态）
    private var matchTimeDistance: Double? {
        return historyItem.getMatchTimeDistance()
    }
    
    var body: some View {
        // 🔧 修复：参考排行榜的显示方式，使用简洁的布局
        HStack(spacing: 16) {
            // 用户头像 - 🎯 参考排行榜：只从 UserAvatarRecord 表获取，不从历史记录快照读取
            // 与用户头像界面一致：支持SF Symbol和emoji/文本
            if let avatar = resolvedAvatar, !avatar.isEmpty {
                let isSFSymbol = UserAvatarUtils.isSFSymbol(avatar)
                
                // 检查是否是 SF Symbol
                if isSFSymbol {
                    if avatar == "applelogo" || avatar == "apple_logo" {
                        Image(systemName: "applelogo")
                            .font(.system(size: 40))
                            .foregroundColor(.black)
                            .background(Circle().fill(Color.gray.opacity(0.1)).frame(width: 50, height: 50))
                            .onAppear {
                                loadAvatarFromServer()
                                loadUserNameFromServer()
                            }
                            .task {
                                // 🎯 新增：检查查询是否失败，如果失败则重试
                                try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 / 7.0)) // 1/7秒
                                // 检查是否查询失败（avatarFromServer 为 nil）且未重试过
                                let shouldRetry = avatarFromServer == nil && avatarRetryCount < 2
                                if shouldRetry {
                                    retryLoadAvatarFromServer()
                                } else {
                                }
                            }
                    } else {
                        // 🔧 修复：统一处理所有 SF Symbol
                        Image(systemName: avatar)
                            .font(.system(size: 40))
                            .foregroundColor(avatar == "person.circle.fill" ? .purple : .blue)
                            .background(Circle().fill(Color.gray.opacity(0.1)).frame(width: 50, height: 50))
                            .onAppear {
                                loadAvatarFromServer()
                                loadUserNameFromServer()
                            }
                            .task {
                                // 🎯 新增：检查查询是否失败，如果失败则重试
                                try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 / 7.0)) // 1/7秒
                                // 检查是否查询失败（avatarFromServer 为 nil）且未重试过
                                let shouldRetry = avatarFromServer == nil && avatarRetryCount < 2
                                if shouldRetry {
                                    retryLoadAvatarFromServer()
                                } else {
                                }
                            }
                    }
                } else {
                    // Emoji 或文本头像显示
                    Text(avatar)
                        .font(.system(size: 40))
                        .fixedSize(horizontal: true, vertical: false)
                        .background(Circle().fill(Color.gray.opacity(0.1)).frame(width: 50, height: 50))
                        .onAppear {
                            loadAvatarFromServer()
                            loadUserNameFromServer()
                        }
                        .task {
                            // 🎯 新增：检查查询是否失败，如果失败则重试
                            try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 / 7.0)) // 1/7秒
                            // 🎯 修改：检查是否查询失败（avatarFromServer 为 nil）且未达到最大重试次数
                            let shouldRetry = avatarFromServer == nil && avatarRetryCount < 2
                            if shouldRetry {
                                retryLoadAvatarFromServer()
                            } else {
                            }
                        }
                }
            } else {
                // 使用默认头像 - Apple账号与内部账号使用相同的默认头像
                ZStack {
                    Circle().fill(Color.gray.opacity(0.1)).frame(width: 50, height: 50)
                    if historyItem.record.loginType == "apple" {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.purple)
                            .font(.system(size: 24))
                    } else {
                        // 游客用户 - 与用户头像界面一致：使用person.circle（蓝色）
                        Image(systemName: "person.circle")
                            .foregroundColor(.blue)
                            .font(.system(size: 24))
                    }
                }
                .onAppear {
                    loadAvatarFromServer()
                    loadUserNameFromServer()
                }
                .task {
                    // 🎯 新增：检查查询是否失败，如果失败则重试
                    // 🎯 修改：等待初始查询完成（1/7秒后），如果查询失败（avatarFromServer 为 nil），则重试
                    try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 / 7.0)) // 1/7秒
                    // 🎯 修改：检查是否查询失败（avatarFromServer 为 nil）且未达到最大重试次数
                    let shouldRetry = avatarFromServer == nil && avatarRetryCount < 2
                    if shouldRetry {
                        retryLoadAvatarFromServer()
                    } else {
                    }
                }
            }
            
            // 用户信息 - 参考排行榜：用户名 + 距离
            VStack(alignment: .leading, spacing: 4) {
                // 🎯 只使用 resolvedUserName（从 UserNameRecord 表获取），不从历史记录快照读取
                let displayName = resolvedUserName ?? "未知用户"
                ColorfulUserNameText(
                    userName: displayName,
                    userId: historyItem.record.userId,
                    loginType: historyItem.record.loginType,
                    font: .headline,
                    fontWeight: .semibold,
                    lineLimit: 1,
                    truncationMode: .tail
                )
                .onAppear {
                    // 与用户头像界面一致：在onAppear时实时查询服务器用户名
                    loadUserNameFromServer()
                }
                .task {
                    // 🎯 新增：检查查询是否失败，如果失败则重试
                    // 🎯 修改：等待初始查询完成（1/7秒后），如果查询失败（userNameFromServer 为 nil），则重试以获取最新用户名
                    try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 / 7.0)) // 1/7秒
                    // 🎯 修改：只要查询失败（userNameFromServer 为 nil）就重试，不管历史记录中是否有用户名
                    // 这样可以确保获取到最新的用户名，即使历史记录中有旧的用户名
                    let shouldRetry = userNameFromServer == nil && userNameRetryCount < 2
                    if shouldRetry {
                        retryLoadUserNameFromServer()
                    } else {
                    }
                }
                
                // 距离信息 - 参考排行榜：使用缓存的距离
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(calculatedDistance != nil ? DistanceUtils.formatDistance(calculatedDistance!) : "暂无位置")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
        .onAppear {
            // 与排行榜一致：在onAppear时实时查询服务器头像和用户名
            loadAvatarFromServer()
            loadUserNameFromServer()
            
            // 在视图出现时计算一次距离
            if let locationManager = locationManager {
                let distance = historyItem.calculateCurrentDistance(from: locationManager.location)
                // 检查距离是否为有效值
                if let distance = distance, distance.isFinite && distance >= 0 {
                    calculatedDistance = distance
                } else {
                    calculatedDistance = nil
                }
            }
        }
        // 与用户头像界面一致：监听头像更新通知保持同步
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserAvatarUpdated"))) { notification in
            guard let userInfo = notification.userInfo,
                  let updatedUserId = userInfo["userId"] as? String,
                  updatedUserId == historyItem.record.userId,
                  let newAvatar = userInfo["avatar"] as? String else { return }
            avatarFromServer = newAvatar
        }
        // 与用户头像界面一致：监听用户名更新通知
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserNameUpdated"))) { notification in
            guard let userInfo = notification.userInfo,
                  let updatedUserId = userInfo["userId"] as? String,
                  updatedUserId == historyItem.record.userId,
                  let newName = userInfo["userName"] as? String,
                  !newName.isEmpty else { return }
            userNameFromServer = newName
        }
        // 历史记录快照发生变化时同步头像显示
        .onChange(of: historyItem.record.userAvatar) { _, newValue in
            guard let newValue = newValue, !newValue.isEmpty else { return }
            avatarFromServer = newValue
        }
    }
    
    // 🎯 新增：实时查询 favorite 状态 - 与用户名显示一致：实时查询服务器
    private func loadFavoriteStatusFromServer() {
        guard let currentUserId = UserDefaultsManager.getCurrentUserId() else {
            return
        }
        
        let favoriteUserId = historyItem.record.userId
        
        // 实时查询服务器状态
        LeanCloudService.shared.fetchFavoriteStatus(userId: currentUserId, favoriteUserId: favoriteUserId) { isFavorited, error in
            DispatchQueue.main.async {
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
