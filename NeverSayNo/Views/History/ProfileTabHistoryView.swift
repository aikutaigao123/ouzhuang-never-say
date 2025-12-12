import SwiftUI
import CoreLocation

// ProfileTab专用的历史记录视图
struct ProfileTabHistoryView: View {
    let history: [RandomMatchHistory]
    @State private var currentHistory: [RandomMatchHistory] = []
    let calculateDistance: (CLLocation, Double, Double) -> Double
    let formatDistance: (Double) -> String
    let formatTimestamp: (String, String?) -> String
    let calculateBearing: (CLLocation, Double, Double) -> Double
    let getDirectionText: (Double) -> String
    let calculateTimezoneFromLongitude: (Double) -> String
    let getTimezoneName: (Double) -> String
    let onClearHistory: () -> Void
    let onDeleteHistoryItem: (RandomMatchHistory) -> Void
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
    let onHistoryItemTap: (RandomMatchHistory) -> Void
    let locationManager: LocationManager?
    let onDismiss: () -> Void // 新增：自定义退出处理
    
    @Environment(\.dismiss) private var dismiss
    @State private var showClearAlert = false
    @State private var historyAvatarCache: [String: String] = [:]
    @State private var historyUserNameCache: [String: String] = [:]
    @State private var isRefreshing = false // 🔧 新增：下拉刷新状态
    
    // 🔧 新增：分离匹配卡片和推荐卡片
    private var matchRecords: [RandomMatchHistory] {
        currentHistory.filter { historyItem in
            // 推荐卡片：有placeName或reason字段
            let isRecommendation = (historyItem.record.placeName?.isEmpty == false) || (historyItem.record.reason?.isEmpty == false)
            return !isRecommendation // 匹配卡片：不是推荐卡片
        }
    }
    
    private var recommendationRecords: [RandomMatchHistory] {
        currentHistory.filter { historyItem in
            // 推荐卡片：有placeName或reason字段
            let isRecommendation = (historyItem.record.placeName?.isEmpty == false) || (historyItem.record.reason?.isEmpty == false)
            return isRecommendation
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if currentHistory.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 80))
                            .foregroundColor(.gray.opacity(0.6))
                        Text("暂无随机匹配历史")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                        Text("进行随机匹配后这里会显示历史")
                            .font(.body)
                            .foregroundColor(.gray.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 40)
                    .padding(.vertical, 60)
                    .onAppear {
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    }
                } else {
                    VStack(spacing: 0) {
                        // 🔧 新增：历史记录顶部工具栏（学习排行榜设计）
                        HStack {
                            Text("历史记录")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            // 显示统计信息
                            HStack(spacing: 8) {
                                if !matchRecords.isEmpty {
                                    Text("匹配: \(matchRecords.count)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                if !recommendationRecords.isEmpty {
                                    Text("推荐: \(recommendationRecords.count)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                if isRefreshing {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemBackground))
                        
                        List {
                            // 🔧 新增：匹配卡片列表
                            if !matchRecords.isEmpty {
                                Section(header: Text("匹配卡片 (\(matchRecords.count))")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .padding(.vertical, 8)) {
                                    ForEach(matchRecords, id: \.id) { historyItem in
                                        historyItemRow(historyItem: historyItem)
                                    }
                                }
                            }
                            
                            // 🔧 新增：推荐卡片列表
                            if !recommendationRecords.isEmpty {
                                Section(header: Text("推荐卡片 (\(recommendationRecords.count))")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .padding(.vertical, 8)) {
                                    ForEach(recommendationRecords, id: \.id) { historyItem in
                                        historyItemRow(historyItem: historyItem)
                                    }
                                }
                            }
                        }
                        .listStyle(PlainListStyle())
                        .refreshable {
                            // 🔧 新增：下拉刷新功能（学习排行榜设计）
                            isRefreshing = true
                            // 刷新头像和用户名缓存
                            refreshHistoryAvatars()
                            // 重新加载历史记录数据
                            currentHistory = history
                            // 延迟重置刷新状态
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                isRefreshing = false
                            }
                        }
                        .onAppear {
                            let formatter = DateFormatter()
                            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                            for (_, _) in currentHistory.enumerated() {
                            }
                        }
                    }
                }
            }
            .navigationTitle("随机匹配历史")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !currentHistory.isEmpty {
                        Button("清除") {
                            showClearAlert = true
                        }
                        .foregroundColor(.red)
                        .fontWeight(.medium)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        // 退出历史记录界面，发送通知返回到主界面
                        dismiss()
                        onDismiss()
                    }
                    .fontWeight(.medium)
                }
            }
            .alert("确认清除", isPresented: $showClearAlert) {
                Button("取消", role: .cancel) { }
                Button("清除", role: .destructive) {
                    // 直接清空本地数据
                    currentHistory.removeAll()
                    historyAvatarCache.removeAll()
                    historyUserNameCache.removeAll()
                    
                    // 调用清除方法
                    onClearHistory()
                    
                    // 关闭对话框
                    showClearAlert = false
                }
            } message: {
                Text("确定要清除所有随机匹配历史吗？")
            }
            .onAppear {
                // 打印历史记录加载信息
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                
                // 立即同步历史记录数据，确保界面快速显示
                currentHistory = history
                
                for (_, _) in currentHistory.enumerated() {
                }
                
                // 与用户头像界面一致：界面打开时立即查询所有历史记录的头像和用户名
                // 延迟刷新头像缓存，避免阻塞UI
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.refreshHistoryAvatars()
                }
            }
        }
    }
    
    // 🔧 新增：历史记录项视图（提取公共代码）
    @ViewBuilder
    private func historyItemRow(historyItem: RandomMatchHistory) -> some View {
        HistoryCardView(
            historyItem: historyItem,
            calculateDistance: DistanceUtils.calculateDistance,
            formatDistance: DistanceUtils.formatDistance,
            formatTimestamp: TimestampUtils.formatTimestamp,
            calculateTimezoneFromLongitude: TimezoneUtils.calculateTimezoneFromLongitude,
            getTimezoneName: TimezoneUtils.getTimezoneName,
            onReportUser: { userId, userName, userEmail, reason, deviceId, loginType in
                onReportUser(userId, userName, userEmail, reason, deviceId, loginType)
            },
            hasReportedUser: hasReportedUser,
            avatarResolver: { uid, ltype, snapshot in
                // 优先使用历史界面的头像缓存
                if let uid = uid, let latest = historyAvatarCache[uid], !latest.isEmpty { return latest }
                // 如果没有缓存，使用传入的avatarResolver
                return avatarResolver(uid, ltype, snapshot)
            },
            userNameResolver: { uid, ltype in
                // 优先使用历史界面的用户名缓存
                if let uid = uid, let latest = historyUserNameCache[uid], !latest.isEmpty { return latest }
                // 如果没有缓存，使用传入的userNameResolver
                return userNameResolver(uid, ltype)
            },
            ensureLatestAvatar: ensureLatestAvatar,
            isUserFavorited: isUserFavorited,
            isUserFavoritedByMe: isUserFavoritedByMe,
            onToggleFavorite: onToggleFavorite,
            isUserLiked: isUserLiked,
            onToggleLike: onToggleLike,
            locationManager: locationManager
        )
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .onTapGesture {
            onHistoryItemTap(historyItem)
            // 退出历史记录界面，发送通知返回到主界面
            dismiss()
            onDismiss()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            // 🎯 新增：拉黑按钮
            Button(role: .destructive) {
                // 执行拉黑操作
                LocalBlacklistManager.shared.addUserToLocalBlacklist(historyItem.record.userId)
                
                // 从历史记录中移除该用户
                onDeleteHistoryItem(historyItem)
                
                // 发送通知刷新界面（通知所有相关组件刷新）
                NotificationCenter.default.post(name: NSNotification.Name("LocalBlacklistUpdated"), object: nil)
                NotificationCenter.default.post(name: NSNotification.Name("RefreshMatchStatus"), object: nil)
            } label: {
                Label("拉黑", systemImage: "hand.raised")
            }
            .tint(.purple)
            
            // 删除按钮
            Button(role: .destructive) {
                _ = Date()
                
                // 🔧 修复：添加防重复删除检查
                let recordExists = currentHistory.contains { $0.id == historyItem.id }
                
                // 🔧 修复：如果记录不存在，直接返回，避免重复删除
                guard recordExists else {
                    return
                }
                
                // 🔧 优化：添加触觉反馈，提供即时响应
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                // 删除单个历史记录
                onDeleteHistoryItem(historyItem)
                
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }
    
    // MARK: - 刷新历史记录中的头像和用户名
    private func deleteHistoryItem(_ historyItem: RandomMatchHistory) {
        onDeleteHistoryItem(historyItem)
    }
    
    // 刷新历史记录中的头像和用户名
    private func refreshHistoryAvatars() {
        
        // 如果历史记录为空，直接返回
        guard !currentHistory.isEmpty else {
            historyAvatarCache.removeAll()
            historyUserNameCache.removeAll()
            return
        }
        
        // 收集所有需要更新的用户ID
        var userIds = Set<String>()
        for historyItem in currentHistory {
            userIds.insert(historyItem.record.userId)
        }
        
        // 先尝试从本地缓存获取数据，提高响应速度
        filterAndUpdateHistoryUserNameCache(neededUserIds: userIds)
        filterAndUpdateHistoryUserAvatarCache(neededUserIds: userIds)
        
        // 然后异步获取最新数据
        DispatchQueue.global(qos: .userInitiated).async {
            // 批量获取所有用户名记录
            LeanCloudService.shared.fetchAllUserNameRecords { records, error in
                DispatchQueue.main.async {
                    if records != nil {
                        self.filterAndUpdateHistoryUserNameCache(neededUserIds: userIds)
                    } else {
                    }
                }
            }
            
            // 批量获取所有用户头像记录
            LeanCloudService.shared.fetchAllUserAvatarRecords { records, error in
                DispatchQueue.main.async {
                    if records != nil {
                        self.filterAndUpdateHistoryUserAvatarCache(neededUserIds: userIds)
                    } else {
                    }
                }
            }
        }
    }
    
    // 过滤并更新历史记录用户名缓存 - 与用户头像界面一致：实时查询服务器
    private func filterAndUpdateHistoryUserNameCache(neededUserIds: Set<String>) {
        // 🎯 修改：使用 fetchUserNameByUserId，不依赖 loginType，直接从 UserNameRecord 表获取
        for userId in neededUserIds {
            LeanCloudService.shared.fetchUserNameByUserId(objectId: userId) { name, _ in
                DispatchQueue.main.async {
                    if let name = name, !name.isEmpty {
                        self.historyUserNameCache[userId] = name
                    }
                }
            }
        }
    }
    
    // 过滤并更新历史记录用户头像缓存 - 🎯 统一从 UserAvatarRecord 表获取
    private func filterAndUpdateHistoryUserAvatarCache(neededUserIds: Set<String>) {
        // 🎯 修改：使用 fetchUserAvatarByUserId，不依赖 loginType，直接从 UserAvatarRecord 表获取
        for userId in neededUserIds {
            LeanCloudService.shared.fetchUserAvatarByUserId(objectId: userId) { avatar, _ in
                DispatchQueue.main.async {
                    if let avatar = avatar, !avatar.isEmpty {
                        self.historyAvatarCache[userId] = avatar
                    }
                }
            }
        }
    }
}
