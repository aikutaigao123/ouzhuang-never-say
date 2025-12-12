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
    
    // 🎯 改进：初始化方法，latestTimes 为可选参数
    init(record: LocationRecord, scale: CGFloat, latestTimes: [String: String]? = nil) {
        self.record = record
        self.scale = scale
        self.latestTimes = latestTimes
    }
    
    private var displayText: String {
        let uid = record.userId
        
        // 🎯 改进：第一优先级：从服务器实时查询的时间（确保是当前用户的，与头像显示逻辑一致）
        if let serverTime = lastOnlineText, !serverTime.isEmpty {
            if lastUserId == uid {
                return serverTime
            }
        }
        
        // 🎯 改进：第二优先级：从 UserDefaults 获取时间缓存（读取Date后格式化显示）
        if let cachedDate = UserDefaultsManager.getUserLastOnlineTime(userId: uid) {
            // 🎯 修改：从Date缓存格式化显示文本（根据当前时间计算时间差）
            let formattedText = TimeAgoUtils.formatTimeAgo(from: cachedDate)
            return formattedText
        }
        
        // 🎯 新增：第三优先级：使用内存缓存（与头像显示逻辑一致）
        if let latestTimes = latestTimes {
            if let latestTime = latestTimes[uid], !latestTime.isEmpty {
                return latestTime
            }
        }
        
        // 🎯 新增：第四优先级：使用记录中的时间戳（格式化显示，与头像显示逻辑一致）
        let fallbackTime = TimestampUtils.formatTimestamp(record.timestamp, tzID: record.timezone)
        if !fallbackTime.isEmpty && fallbackTime != record.timestamp {
            return fallbackTime
        }
        
        // 如果都没有数据，显示空字符串
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
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            // 🎯 修改：初始化时加载数据
            loadUserLastOnlineTime()
        }
        .onChange(of: record.userId) { oldValue, newValue in
            // 🎯 新增：监听 record.userId 变化，解决视图复用时的用户切换问题
            loadUserLastOnlineTime()
        }
    }
    
    // 🎯 新增：提取加载逻辑为独立方法，供 onAppear 和 onChange 共用
    private func loadUserLastOnlineTime() {
        let currentUserId = record.userId
        
        // 🎯 新增：用户切换检测（与头像显示逻辑一致）
        if let lastUserId = lastUserId, lastUserId != currentUserId {
            lastOnlineText = nil // 重置时间状态
        }
        lastUserId = currentUserId
        // 🎯 修改：只使用 LoginRecord 表的最近上线时间，无回退逻辑
        // 🎯 改进：统一错误处理方式（与头像显示逻辑一致）
        LeanCloudService.shared.fetchUserLastOnlineTime(userId: currentUserId) { success, lastActive in
            DispatchQueue.main.async {
                if success, let date = lastActive {
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
                }
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
