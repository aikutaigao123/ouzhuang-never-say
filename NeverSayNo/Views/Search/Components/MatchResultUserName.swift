import SwiftUI

struct MatchResultUserName: View {
    let userName: String?
    let latestUserNames: [String: String]
    let userId: String
    let loginType: String? // 新增：登录类型
    let placeName: String? // 🎯 新增：推荐榜地名
    let reason: String? // 🎯 新增：推荐理由
    let onCopy: () -> Void
    @State private var userNameFromServer: String? = nil
    @State private var userNameRetryCount: Int = 0 // 🎯 新增：用户名重试次数（最多重试2次）
    
    // 🎯 新增：判断是否来自推荐榜
    private var isFromRecommendation: Bool {
        let hasPlaceName = (placeName?.isEmpty == false)
        let hasReason = (reason?.isEmpty == false)
        return hasPlaceName || hasReason
    }
    
    // 🎯 修改：推荐榜显示地名，否则显示用户名
    private var displayText: String {
        if isFromRecommendation, let placeName = placeName, !placeName.isEmpty {
            return placeName // 推荐榜：显示地名
        }
        
        // 非推荐榜：显示用户名（与用户头像界面一致的用户名显示优先级）
        // 第一优先级：从服务器实时查询的用户名
        if let serverName = userNameFromServer, !serverName.isEmpty {
            return serverName
        }
        // 第二优先级：使用本地缓存
        if let latest = latestUserNames[userId], !latest.isEmpty {
            return latest
        }
        // 第三优先级：使用记录中的用户名
        return userName ?? "未知用户"
    }
    
    // 🎯 新增：计算文本颜色
    private var displayTextColor: Color {
        if isFromRecommendation {
            return Color.green // 推荐榜：绿色地名
        }
        return Color.primary // 非推荐榜：默认颜色
    }
    
    // 从服务器加载用户名 - 🎯 统一从 UserNameRecord 表获取（仅非推荐榜需要）
    private func loadUserNameFromServer() {
        // 🎯 修改：推荐榜不需要查询用户名
        if isFromRecommendation {
            return
        }
        
        let uid = userId
        
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
    
    // 🎯 新增：重试查询用户名（最多重试2次）
    private func retryLoadUserNameFromServer() {
        guard !isFromRecommendation else { return }
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
    
    var body: some View {
        // 🎯 修改：推荐榜显示地名（根据推荐者的 UserNameRecord 决定是否显示彩色），非推荐榜显示彩色用户名
        if isFromRecommendation, let placeName = placeName, !placeName.isEmpty {
            ColorfulPlaceNameText(
                placeName: placeName,
                userId: userId,
                loginType: loginType,
                font: .title2,
                fontWeight: .bold,
                lineLimit: 1,
                truncationMode: .tail
            )
            .minimumScaleFactor(0.3)
            .onLongPressGesture(perform: onCopy)
        } else {
            ColorfulUserNameText(
                userName: displayText,
                userId: userId,
                loginType: loginType,
                font: .title2,
                fontWeight: .bold,
                lineLimit: 1,
                truncationMode: .tail
            )
            .minimumScaleFactor(0.3)
            .onLongPressGesture(perform: onCopy)
            .onAppear {
                // 🎯 修改：仅非推荐榜时查询服务器用户名
                if !isFromRecommendation {
                    loadUserNameFromServer()
                }
            }
            .task {
                // 🎯 新增：检查查询是否失败，如果失败则重试（仅非推荐榜）
                guard !isFromRecommendation else { return }
                try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 / 7.0)) // 1/7秒
                // 检查是否查询失败（userNameFromServer 为 nil）且未达到最大重试次数
                let shouldRetry = userNameFromServer == nil && userNameRetryCount < 2
                if shouldRetry {
                    retryLoadUserNameFromServer()
                }
            }
        }
    }
}