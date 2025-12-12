import SwiftUI
import CoreLocation

// 推荐榜列表视图
struct RecommendationListView: View {
    @State var recommendationData: [RecommendationItem] = []
    @State var isLoading = true
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var userManager: UserManager // 🎯 新增：用于获取当前用户ID
    let onRecommendationItemTap: (RecommendationItem) -> Void
    let selectedItemId: String?
    @State var highlightedItemId: String? = nil // 🎯 新增：用于高亮显示新上传的项目
    
    // 🎯 新增：当前账号发送过的所有推荐
    @State var myRecommendations: [RecommendationItem] = []
    @State var isLoadingMyRecommendations = false
    
    // 新增头像缓存 - 学习历史按钮的专用缓存策略
    @State var latestAvatars: [String: String] = [:]
    @State var latestUserNames: [String: String] = [:]
    
    // 新增推荐榜专用的头像缓存 - 类似历史按钮的historyAvatarCache
    @State var recommendationAvatarCache: [String: String] = [:]
    @State var recommendationUserNameCache: [String: String] = [:]
    
    // 距离缓存
    @State var distanceCache: [String: Double] = [:]
    @State var isCalculatingDistances = false // 🎯 新增：是否正在计算距离
    
    // 🎯 新增：预加载状态（与排行榜一致）
    @State var hasPreloadedDistances = false
    @State var isPreloadingDistances = false
    
    // 🎯 新增：保存所有原始推荐数据（距离过滤之前）
    @State var allRecommendationData: [RecommendationItem] = []
    
    // 🎯 新增：当上传的推荐尚未进入前20时的提示
    @State var showOutOfTopHint = false
    @State var outOfTopHintMessage = ""
    
    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("正在加载推荐...")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if recommendationData.isEmpty {
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
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
                    .onAppear {
                        if !recommendationData.isEmpty {
                        }
                    }
                    
                    // 🎯 新增：显示距离加载状态（与排行榜一致）
                    HStack {
                        Spacer()
                        if !hasPreloadedDistances && distanceCache.count < recommendationData.count {
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
                            ForEach(recommendationData, id: \.id) { item in
                                RecommendationItemView(
                                    item: item,
                                    cachedDistance: distanceCache[item.id],
                                    isHighlighted: selectedItemId == item.id || highlightedItemId == item.id, // 🎯 新增：支持新上传项目的高亮
                                    avatarCache: $recommendationAvatarCache, // 🎯 新增：传递头像缓存
                                    userNameCache: $recommendationUserNameCache // 🎯 新增：传递用户名缓存
                                )
                                    .listRowInsets(EdgeInsets())
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .id(item.id)
                                    .onTapGesture {
                                        onRecommendationItemTap(item)
                                    }
                            }
                            
                            // 🎯 新增：当前账号发送过的所有推荐
                            if !myRecommendations.isEmpty {
                                Section(header: Text("我的推荐").font(.headline).foregroundColor(.primary)) {
                                    ForEach(myRecommendations, id: \.id) { item in
                                        RecommendationItemView(
                                            item: item,
                                            cachedDistance: distanceCache[item.id],
                                            isHighlighted: selectedItemId == item.id || highlightedItemId == item.id,
                                            avatarCache: $recommendationAvatarCache,
                                            userNameCache: $recommendationUserNameCache
                                        )
                                            .listRowInsets(EdgeInsets())
                                            .listRowSeparator(.hidden)
                                            .listRowBackground(Color.clear)
                                            .id(item.id)
                                            .onTapGesture {
                                                onRecommendationItemTap(item)
                                            }
                                    }
                                }
                            }
                        }
                        .onAppear {
                            if !recommendationData.isEmpty {
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
                                        loadMyRecommendations() // 🎯 新增：刷新我的推荐
                                        // 🎯 修改：增加延迟时间，确保数据加载完成后再滚动
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                            let itemExists = recommendationData.contains { $0.id == newObjectId } || myRecommendations.contains { $0.id == newObjectId }
                                            if itemExists {
                                                withAnimation {
                                                    proxy.scrollTo(newObjectId, anchor: .center)
                                                }
                                            } else {
                                                // 🎯 新增：如果项目不存在，再延迟0.5秒后重试一次（可能是临时添加的项目还未完成）
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                                    let retryExists = recommendationData.contains { $0.id == newObjectId } || myRecommendations.contains { $0.id == newObjectId }
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
                                    loadMyRecommendations() // 🎯 新增：刷新我的推荐
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
                                    let itemExists = recommendationData.contains { $0.id == selectedId }
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
                    .listStyle(PlainListStyle())
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
            // 🎯 修复：只有在数据为空或首次加载时才重新加载数据，避免每次切换都重新加载
            if recommendationData.isEmpty {
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
        }
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
        selectedItemId: nil
    )
}

