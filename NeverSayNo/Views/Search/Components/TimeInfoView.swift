import SwiftUI

struct TimeInfoView: View {
    let record: LocationRecord
    let scale: CGFloat
    // 🎯 新增：内存缓存参数（与头像显示逻辑一致，可选）
    let latestTimes: [String: String]?
    
    // 🎯 新增：使用 LoginRecord 表的最近上线时间
    @State private var lastOnlineText: String? = nil
    // 🎯 新增：记录上次的 userId，用于检测用户切换（与头像显示逻辑一致）
    @State private var lastUserId: String? = nil
    // 🎯 新增：上线时间重试次数（最多重试2次，与用户头像一致）
    @State private var lastOnlineRetryCount: Int = 0
    
    // 🎯 改进：初始化方法，latestTimes 为可选参数
    init(record: LocationRecord, scale: CGFloat, latestTimes: [String: String]? = nil) {
        self.record = record
        self.scale = scale
        self.latestTimes = latestTimes
    }
    
    private var displayText: String {
        let uid = record.userId
        
        // 🎯 修改：第一优先级：从服务器实时查询的时间（LoginRecord 表，确保是当前用户的）
        if let serverTime = lastOnlineText, !serverTime.isEmpty {
            if lastUserId == uid {
                return serverTime
            }
        }
        
        // 🎯 修改：第二优先级：从 UserDefaults 获取时间缓存（来自 LoginRecord 表，读取Date后格式化显示）
        if let cachedDate = UserDefaultsManager.getUserLastOnlineTime(userId: uid) {
            // 🎯 修改：从Date缓存格式化显示文本（根据当前时间计算时间差）
            let formattedText = TimeAgoUtils.formatTimeAgo(from: cachedDate)
            return formattedText
        }
        
        // 🎯 修改：第三优先级：使用内存缓存（来自 LoginRecord 表）
        if let latestTimes = latestTimes {
            if let latestTime = latestTimes[uid], !latestTime.isEmpty {
                return latestTime
            }
        }
        
        // 🎯 修改：全部使用 LoginRecord 表，无回退逻辑（与 FriendMatchResultCard 一致）
        // 如果 LoginRecord 表没有数据，返回空字符串
        return ""
    }
    
    var body: some View {
        VStack(spacing: getVerticalSpacing()) {
            Image(systemName: "clock.fill")
                .foregroundColor(.orange)
                .font(.system(size: 24))
            Text(displayText)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.orange)
                .minimumScaleFactor(0.3)
                .lineLimit(1)
                .truncationMode(.tail)
                .id("timeText-\(record.userId)-\(lastOnlineText ?? "nil")") // 🎯 新增：添加 id 以便强制更新
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            // 🎯 修改：初始化时加载数据
            loadUserLastOnlineTime()
        }
        .onChange(of: record.userId) { oldValue, newValue in
            // 🎯 新增：监听 record.userId 变化，解决视图复用时的用户切换问题
            // 🎯 新增：重置重试次数（用户切换时）
            lastOnlineRetryCount = 0
            loadUserLastOnlineTime()
        }
        .task {
            // 🎯 新增：检查查询是否失败，如果失败则重试（与用户头像一致）
            let currentUserId = record.userId
            try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 / 7.0)) // 1/7秒
            // 检查是否查询失败（lastOnlineText 为 nil）且未达到最大重试次数
            let shouldRetry = lastOnlineText == nil && lastOnlineRetryCount < 2 && lastUserId == currentUserId
            if shouldRetry {
                retryLoadUserLastOnlineTime(userId: currentUserId)
            }
        }
    }
    
    // 🎯 新增：提取加载逻辑为独立方法，供 onAppear 和 onChange 共用
    private func loadUserLastOnlineTime() {
        let currentUserId = record.userId
        
        // 🎯 新增：用户切换检测（与头像显示逻辑一致）
        if let lastUserId = lastUserId, lastUserId != currentUserId {
            lastOnlineText = nil // 重置时间状态
            lastOnlineRetryCount = 0 // 🎯 新增：重置重试次数
        }
        lastUserId = currentUserId
        
        // 🔧 修复：fetchUserLastOnlineTime 的第一个参数是 isOnline（是否在线），不是 success（是否成功）
        // 只要有时间数据就算成功，不管用户是否在线
        LeanCloudService.shared.fetchUserLastOnlineTime(userId: currentUserId) { isOnline, lastActive in
            DispatchQueue.main.async {
                // 🔧 修复：只要有时间数据就使用，不管 isOnline 状态
                if let date = lastActive {
                    let formattedText = TimeAgoUtils.formatTimeAgo(from: date)
                    
                    // 🎯 改进：数据同步 - 自动更新 UserDefaults 以保持一致性（存储原始时间Date）
                    let cachedDate = UserDefaultsManager.getUserLastOnlineTime(userId: currentUserId)
                    if let cached = cachedDate {
                        // 检查缓存的时间是否与服务器时间一致（允许小误差）
                        let timeDiff = abs(date.timeIntervalSince(cached))
                        if timeDiff > 1.0 {
                            // 时间不一致，更新缓存
                            UserDefaultsManager.setUserLastOnlineTime(userId: currentUserId, originalTimestamp: date)
                        }
                    } else {
                        UserDefaultsManager.setUserLastOnlineTime(userId: currentUserId, originalTimestamp: date)
                    }
                    
                    self.lastOnlineText = formattedText
                    // 🎯 新增：查询成功，重置重试次数
                    self.lastOnlineRetryCount = 0
                } else {
                    // 🎯 新增：查询失败时，如果 lastOnlineText 仍为 nil 且未达到最大重试次数，触发重试
                    if self.lastOnlineText == nil && self.lastOnlineRetryCount < 2 {
                        self.retryLoadUserLastOnlineTime(userId: currentUserId)
                    }
                }
            }
        }
    }
    
    // 🎯 新增：重试查询上线时间（最多重试2次，与用户头像一致）
    private func retryLoadUserLastOnlineTime(userId: String) {
        guard lastOnlineRetryCount < 2 else {
            return
        }
        lastOnlineRetryCount += 1
        
        // 🎯 修改：根据重试次数决定延迟时间（与用户头像一致）
        // 第一次重试：延迟1/17秒；第二次重试：延迟0.5秒
        let delay: TimeInterval = lastOnlineRetryCount == 1 ? 1.0 / 17.0 : 0.5
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // 检查 lastOnlineText 是否为 nil（查询失败的情况）
            if self.lastOnlineText == nil && self.lastUserId == userId {
                self.loadUserLastOnlineTime()
            }
        }
    }
    
    private func getVerticalSpacing() -> CGFloat {
        if scale < 0.6 {
            if scale < 0.3 { return 0 }
            if scale < 0.4 { return 1 }
            if scale < 0.5 { return 2 }
            return 4
        }
        return 6
    }
    
}
