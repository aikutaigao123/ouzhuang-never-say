import SwiftUI
import CoreLocation

// 推荐榜列表视图
struct RecommendationListView: View {
    // 🎯 修改：改为本地状态 + UserDefaults 持久化，不再依赖 RankingDataManager 作为数据源
    @State var recommendationItems: [RecommendationItem] = []
    @State var myRecommendationsLocal: [RecommendationItem] = []
    
    // 🎯 修改：改为局部加载状态（用于显示后台刷新指示器）
    @State var isLoadingInBackground = false
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var userManager: UserManager // 🎯 新增：用于获取当前用户ID
    let onRecommendationItemTap: (RecommendationItem) -> Void
    let selectedItemId: String?
    @State var highlightedItemId: String? = nil // 🎯 新增：用于高亮显示新上传的项目
    
    // 🎯 新增：控制是否应该加载数据的标志
    @Binding var shouldLoad: Bool
    
    // 🎯 修改：局部状态保持不变
    @State var isLoadingMyRecommendations = false
    @State var latestAvatars: [String: String] = [:]
    @State var latestUserNames: [String: String] = [:]
    @State var isCalculatingDistances = false
    @State var hasPreloadedDistances = false
    @State var isPreloadingDistances = false
    @State var showOutOfTopHint = false
    @State var outOfTopHintMessage = ""
    @State private var showRefreshLimitAlert = false // 🎯 新增：下拉刷新限制提示
    @State private var refreshLimitMessage = "" // 🎯 新增：刷新限制提示消息
    
    // 🎯 新增：记录是否已经在本次打开中加载过数据
    @State private var hasLoadedInCurrentSession = false
    
    // 🎯 新增：重试机制相关状态
    @State var retryCount = 0
    @State var myRecommendationRetryCount = 0
    
    // 🎯 新增：时间测量相关状态
    @State private var cacheLoadTime: Date?
    @State private var networkLoadCompleteTime: Date?
    
    var body: some View {
        Group {
            // 🎯 修改：只有在首次加载且本地没有数据时才显示 loading
            if isLoadingInBackground && recommendationItems.isEmpty {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("正在加载推荐...")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if recommendationItems.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "star")
                        .font(.system(size: 60))
                        .foregroundColor(.gray.opacity(0.6))
                    Text("暂无推荐数据")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                    Text("推荐榜将显示个性化推荐")
                        .font(.body)
                        .foregroundColor(.gray.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 60)
            } else {
                VStack(spacing: 0) {
                    // 推荐榜顶部工具栏
                    HStack {
                        Text("推荐榜")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        
                        Spacer()
                        
                        // 🎯 新增：后台刷新指示器（本地已有数据时显示“更新中”）
                        if isLoadingInBackground && !recommendationItems.isEmpty {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.7)
                                Text("更新中")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
                    
                    // 🎯 新增：显示距离加载状态（与排行榜一致）
                    HStack {
                        Spacer()
                        if !hasPreloadedDistances && recommendationItems.contains(where: { $0.distance == nil }) {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("加载距离中...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    
                    ScrollViewReader { proxy in
                        List {
                            ForEach(recommendationItems, id: \.id) { item in
                                RecommendationItemView(
                                    item: item,
                                    cachedDistance: item.distance, // 作为回退值
                                    isHighlighted: selectedItemId == item.id || highlightedItemId == item.id, // 🎯 新增：支持新上传项目的高亮
                                    locationManager: locationManager, // 🎯 新增：传递 locationManager 用于实时计算距离
                                    avatarCache: .constant([:]), // 本地状态下不再依赖全局头像缓存
                                    userNameCache: .constant([:]) // 本地状态下不再依赖全局用户名缓存
                                )
                                    .listRowInsets(EdgeInsets())
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .id(item.id)
                                    .onTapGesture {
                                        onRecommendationItemTap(item)
                                    }
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                                        removal: .opacity.combined(with: .move(edge: .leading))
                                    ))
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: recommendationItems.map { $0.id })
                            }
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: recommendationItems.map { $0.id })
                            
                            // 🎯 新增：当前账号发送过的所有推荐
                            if !myRecommendationsLocal.isEmpty {
                                Section(header: Text("我的推荐").font(.headline).foregroundColor(.primary)) {
                                    ForEach(myRecommendationsLocal, id: \.id) { item in
                                        RecommendationItemView(
                                            item: item,
                                            cachedDistance: item.distance, // 作为回退值
                                            isHighlighted: selectedItemId == item.id || highlightedItemId == item.id,
                                            locationManager: locationManager, // 🎯 新增：传递 locationManager 用于实时计算距离
                                            avatarCache: .constant([:]),
                                            userNameCache: .constant([:])
                                        )
                                            .listRowInsets(EdgeInsets())
                                            .listRowSeparator(.hidden)
                                            .listRowBackground(Color.clear)
                                            .id(item.id)
                                            .onTapGesture {
                                                onRecommendationItemTap(item)
                                            }
                                            .transition(.asymmetric(
                                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                                removal: .opacity.combined(with: .move(edge: .leading))
                                            ))
                                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: myRecommendationsLocal.map { $0.id })
                                    }
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: myRecommendationsLocal.map { $0.id })
                                }
                            }
                        }
                        .listStyle(PlainListStyle())
                        .refreshable {
                            // 🎯 新增：检查下拉刷新限制（每天最多15次）
                            guard let userId = userManager.currentUser?.id else {
                                return
                            }
                            
                            let (canRefresh, message) = UserDefaultsManager.canRefreshRecommendationList(userId: userId)
                            if canRefresh {
                                // 记录刷新
                                UserDefaultsManager.recordRecommendationRefresh(userId: userId)
                                // 执行刷新
                                loadRecommendationData()
                                loadMyRecommendations()
                            } else {
                                // 显示限制提示
                                refreshLimitMessage = message
                                showRefreshLimitAlert = true
                            }
                        }
                        .alert("提示", isPresented: $showRefreshLimitAlert) {
                            Button("确定") { }
                        } message: {
                            Text(refreshLimitMessage)
                        }
                        .onAppear {
                            if !recommendationItems.isEmpty {
                            }
                        }
                        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshRecommendationList"))) { notification in
                            // 🎯 新增：监听刷新通知，重新加载推荐榜数据
                            // 🎯 新增：如果通知中包含新上传的项目ID，设置高亮
                            if let userInfo = notification.userInfo {
                                if let newObjectId = userInfo["selectedRecommendationId"] as? String {
                                    highlightedItemId = newObjectId
                                    // 延迟滚动到新上传的项目
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        loadRecommendationData()
                                        loadMyRecommendations() // 🎯 新增：刷新我的推荐（更新到 myRecommendationsLocal）
                                        // 🎯 修改：增加延迟时间，确保数据加载完成后再滚动
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                            let itemExists = recommendationItems.contains { $0.id == newObjectId } || myRecommendationsLocal.contains { $0.id == newObjectId }
                                            if itemExists {
                                                withAnimation {
                                                    proxy.scrollTo(newObjectId, anchor: .center)
                                                }
                                            } else {
                                                // 🎯 新增：如果项目不存在，再延迟0.5秒后重试一次（可能是临时添加的项目还未完成）
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                                        let retryExists = recommendationItems.contains { $0.id == newObjectId } || myRecommendationsLocal.contains { $0.id == newObjectId }
                                                    if retryExists {
                                                        withAnimation {
                                                            proxy.scrollTo(newObjectId, anchor: .center)
                                                        }
                                                    }
                                                }
                                            }
                                            // 🎯 修改：7秒后取消高亮（与紫色提示卡片显示时间一致）
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) {
                                                highlightedItemId = nil
                                            }
                                        }
                                    }
                                } else {
                                    loadRecommendationData()
                                    loadMyRecommendations() // 🎯 新增：刷新我的推荐（更新到 myRecommendationsLocal）
                                }
                            } else {
                                loadRecommendationData()
                                loadMyRecommendations() // 🎯 新增：刷新我的推荐
                            }
                        }
                        .onAppear {
                            // 如果有选中的项目ID，滚动到该项目
                            if let selectedId = selectedItemId {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    let itemExists = recommendationItems.contains { $0.id == selectedId }
                                    if itemExists {
                                        withAnimation {
                                            proxy.scrollTo(selectedId, anchor: .center)
                                        }
                                    } else {
                                    }
                                }
                            } else {
                            }
                        }
                    }
                }
            }
        }
        .overlay(alignment: .top) {
            if showOutOfTopHint {
                VStack {
                    HStack(spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .semibold))
                        Text(outOfTopHintMessage)
                            .foregroundColor(.white)
                            .font(.system(size: 14, weight: .semibold))
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.purple.opacity(0.9), Color.blue.opacity(0.85)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    )
                    Spacer()
                }
                .padding(.top, 18)
                .padding(.horizontal, 24)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.4), value: showOutOfTopHint)
        .onAppear {
            // 🎯 修改：立即从 UserDefaults 恢复缓存数据，让 UI 秒开
            if let currentUser = userManager.currentUser {
                let cached = UserDefaultsManager.getTop20Recommendations(userId: currentUser.userId)
                if !cached.isEmpty && recommendationItems.isEmpty {
                    // 立即更新 UI，不等待网络请求
                    self.recommendationItems = cached
                    // 🎯 新增：记录缓存加载完成时间（按用户隔离）
                    cacheLoadTime = Date()
                    if let userId = userManager.currentUser?.userId {
                        let key = "ranking_button_click_time_\(userId)"
                        if let startTime = UserDefaults.standard.object(forKey: key) as? Date {
                            let _ = Date().timeIntervalSince(startTime)
                        }
                    }
                }
            }
            
            // 🎯 修改：只在首次加载时才触发网络请求，后台刷新
            if !hasLoadedInCurrentSession {
                loadRecommendationDataIfNeeded()
                hasLoadedInCurrentSession = true
            }
        }
        // 🎯 新增：延迟检查数据加载是否失败，自动重试
        .task {
            // 等待初始加载完成（1/7秒后）
            try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 / 7.0))
            // 检查数据是否加载失败（数据为空且未达到最大重试次数）
            let shouldRetry = recommendationItems.isEmpty && retryCount < 2 && hasLoadedInCurrentSession
            if shouldRetry {
                checkAndRetryLoadRecommendation()
            }
        }
        // 🎯 新增：监听 shouldLoad 变化，实现从父视图触发加载
        .onChange(of: shouldLoad) { oldValue, newValue in
            if newValue && !hasLoadedInCurrentSession {
                loadRecommendationDataIfNeeded()
                hasLoadedInCurrentSession = true
            }
        }
    }
    
    // 🎯 新增：封装加载逻辑，便于在多处调用
    private func loadRecommendationDataIfNeeded() {
        loadRecommendationData()
        loadMyRecommendations() // 🎯 新增：加载当前账号的推荐
        // 双重刷新头像缓存，确保获取最新头像 - 学习历史按钮的策略
        refreshRecommendationAvatars()
        // 延迟刷新推荐榜专用的头像缓存
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.refreshRecommendationSpecificAvatars()
        }
        // 🎯 修改：开始预加载距离信息（与排行榜一致）
        startPreloadingDistances()
    }
    
    func showOutOfTopRankingHint(rank: Int, total: Int, likeCount: Int, minTopLikeCount: Int) {
        let diff = max(0, minTopLikeCount - likeCount)
        let gapMessage = diff > 0 ? "再获得 \(diff) 个点赞即可上榜" : "继续保持活跃即可上榜"
        outOfTopHintMessage = "当前排名第\(rank)/\(total)，暂未进入前20（第20名点赞数：\(minTopLikeCount)）。\(gapMessage)"
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            showOutOfTopHint = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                showOutOfTopHint = false
            }
            // 🎯 新增：7秒后重新加载数据，移除临时添加的项目，恢复只显示前20名
            self.loadRecommendationData()
        }
    }
    
}

#Preview {
    RecommendationListView(
        locationManager: LocationManager(),
        userManager: UserManager(), // 🎯 新增：添加 userManager 参数
        onRecommendationItemTap: { _ in },
        selectedItemId: nil,
        shouldLoad: .constant(true)  // 🎯 新增：Preview 中直接设置为 true
    )
}

