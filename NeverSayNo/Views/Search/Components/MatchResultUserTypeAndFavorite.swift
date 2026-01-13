import SwiftUI

struct MatchResultUserTypeAndFavorite: View {
    let record: LocationRecord
    let isUserFavorited: (String) -> Bool
    let onToggleFavorite: (String, String?, String?, String?, String?, String?) -> Void
    let isLocationRecordLiked: (String) -> Bool // 🎯 新增：检查是否已点赞
    let onToggleLike: (String, String) -> Void // 🎯 新增：切换点赞状态
    @State private var favoriteStatusFromServer: Bool? = nil // 🎯 新增：从服务器实时查询的 favorite 状态
    @State private var likeStatusFromServer: Bool? = nil // 🎯 新增：从服务器实时查询的点赞状态
    @State private var loginTypeFromServer: String? = nil // 🎯 新增：从服务器实时查询的用户类型（参考头像界面方式）
    @State private var isLiked: Bool = false // 🎯 新增：点赞状态（本地缓存）
    @State private var showChampionLabel: Bool = false // 🎯 新增：高手标签显示状态
    @State private var showRankingText: Bool = false // 🎯 新增：排名文字显示状态（跟随紫色皇冠）
    
    // 🎯 新增：判断是否来自推荐榜
    private var isFromRecommendation: Bool {
        let hasPlaceName = (record.placeName?.isEmpty == false)
        let hasReason = (record.reason?.isEmpty == false)
        return hasPlaceName || hasReason
    }
    
    // 🎯 新增：检查用户是否在排行榜前3名中
    private var isTop3RankingUser: Bool {
        guard let currentUserId = UserDefaultsManager.getCurrentUserId() else {
            return false
        }
        let top3UserIds = UserDefaultsManager.getTop3RankingUserIds(userId: currentUserId)
        return top3UserIds.contains(record.userId)
    }
    
    // 🎯 新增：获取用户在排行榜中的排名（返回1-3，如果不在前3名则返回nil）
    private var rankingPosition: Int? {
        guard let currentUserId = UserDefaultsManager.getCurrentUserId() else {
            return nil
        }
        return UserDefaultsManager.getRankingPosition(userId: record.userId, currentUserId: currentUserId)
    }
    
    // 🎯 新增：计算显示的 favorite 状态
    private var displayedFavoriteStatus: Bool {
        // 优先使用服务器实时查询的状态
        if let serverStatus = favoriteStatusFromServer {
            return serverStatus
        }
        // 如果没有服务器状态，使用本地缓存状态
        return isUserFavorited(record.userId)
    }
    
    // 🎯 新增：计算显示的点赞状态（与爱心按钮一致：优先服务器，回退本地）
    private var displayedLikeStatus: Bool {
        // 优先使用服务器实时查询的状态
        if let serverStatus = likeStatusFromServer {
            return serverStatus
        }
        // 如果没有服务器状态，使用本地缓存状态
        let localStatus = isLocationRecordLiked(record.objectId)
        return localStatus
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // 🎯 修改：前3名用户显示"高手"标识替代原用户类型标识
            if isTop3RankingUser, let rank = rankingPosition {
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 11))
                    HStack(spacing: 0) {
                        Text("高手")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                        // 🎯 新增：排名文字只在紫色皇冠显示时显示
                        if showRankingText {
                            Text("（排行榜第\(rank)名）")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                                .transition(.opacity)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color.orange.opacity(0.15))
                )
                .opacity(showChampionLabel ? 1.0 : 0.0)
                .scaleEffect(showChampionLabel ? 1.0 : 0.5)
            } else {
                // 🎯 参考头像界面方式：优先使用实时查询的用户类型，然后使用记录中的用户类型
                let finalLoginType = loginTypeFromServer ?? record.loginType
                UserTypeLabelView(loginType: finalLoginType)
            }
            
            // 🎯 修改：如果是推荐榜，显示点赞按钮；否则显示爱心按钮
            if isFromRecommendation {
                // 推荐榜：显示点赞按钮（与爱心按钮一致：实时查询服务器）
                Button(action: {
                    
                    // 🔧 修复：根据当前状态决定是取消还是添加
                    let currentStatus = displayedLikeStatus
                    
                    // 🎯 乐观更新：立即更新服务器状态（与爱心按钮一致）
                    // 如果是取消点赞，立即将服务器状态设置为 false
                    if currentStatus {
                        likeStatusFromServer = false
                    } else {
                        likeStatusFromServer = true
                    }
                    
                    // 切换点赞状态（本地状态）
                    isLiked.toggle()
                    
                    // 调用外部回调处理点赞逻辑（包括更新Recommendation表的likeCount）
                    onToggleLike(record.userId, record.objectId)
                    
                    // 🎯 新增：操作后延迟查询服务器状态确认（与爱心按钮一致）
                    // 🔧 修复：延迟时间增加到 1.0 秒，给服务器更多时间完成批量更新
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        loadLikeStatusFromServer()
                    }
                }) {
                    Image(systemName: displayedLikeStatus ? "hand.thumbsup.fill" : "hand.thumbsup")
                        .foregroundColor(displayedLikeStatus ? .blue : .gray)
                        .font(.system(size: 16))
                        .scaleEffect(displayedLikeStatus ? 1.26 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: displayedLikeStatus)
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel(displayedLikeStatus ? "已点赞" : "点赞")
                .accessibilityHint(displayedLikeStatus ? "点击取消点赞" : "点击点赞此用户")
                .onAppear {
                    
                    // 🔧 修复：在查询服务器状态之前，先重置 likeStatusFromServer，避免视图重用时显示错误的状态
                    likeStatusFromServer = nil
                    
                    // 🎯 改进：在点赞按钮出现时实时查询服务器状态（与爱心按钮一致）
                    loadLikeStatusFromServer()
                    
                    // 同时设置本地状态作为回退
                    isLiked = isLocationRecordLiked(record.objectId)
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshRecommendationList"))) { _ in
                    
                    // 🔧 修复：在重新查询服务器状态之前，不清空 likeStatusFromServer（保留当前状态，等待服务器确认）
                    // 注意：这里不清空，因为可能是其他记录的刷新通知，不应该影响当前记录的状态
                    
                    // 🎯 改进：当推荐榜刷新时，重新查询服务器状态（与爱心按钮一致）
                    loadLikeStatusFromServer()
                    
                    // 同时更新本地状态作为回退
                    isLiked = isLocationRecordLiked(record.objectId)
                }
            } else {
                // 非推荐榜：显示爱心按钮
                FavoriteButton(
                    userId: record.userId,
                    isFavorited: displayedFavoriteStatus,
                    onToggle: {
                        onToggleFavorite(
                            record.userId,
                            record.userName,
                            record.userEmail,
                            record.loginType,
                            nil, // avatar will be resolved in parent
                            record.objectId
                        )
                        // 🎯 新增：操作后重新查询服务器状态
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            loadFavoriteStatusFromServer()
                        }
                    }
                )
                .onAppear {
                    // 🎯 新增：在爱心按钮出现时实时查询服务器状态
                    loadFavoriteStatusFromServer()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshMatchStatus"))) { _ in
                    let refreshStartTime = Date()
                    // 🎯 新增：当收到匹配状态刷新通知时，重新查询服务器状态
                    loadFavoriteStatusFromServer()
                    let refreshTime = Date().timeIntervalSince(refreshStartTime)
                    if refreshTime > 0.05 {
                    }
                }
            }
        }
        .onAppear {
            // 🎯 新增：实时查询用户类型（参考头像界面方式）
            loadLoginTypeFromServer()
            
            // 🎯 修复：每次出现时重置状态，确保第二次打开时动画能正常播放
            if isTop3RankingUser {
                // 重置状态
                showChampionLabel = false
                showRankingText = false
                
                // 🎯 新增：如果是前3名用户，触发高手标签动画
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        showChampionLabel = true
                    }
                }
                
                // 🎯 新增：排名文字显示逻辑（紫色皇冠在0.3秒后显示，3.2秒后消失；排名文字在0.3秒后显示，4.7秒后消失）
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation {
                        showRankingText = true
                    }
                    // 4.7秒后隐藏排名文字（比紫色皇冠多显示1.5秒）
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.7) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showRankingText = false
                        }
                    }
                }
            }
        }
        .onChange(of: record.objectId) { oldValue, newValue in
            
            // 🔧 修复：当 record.objectId 变化时，重置所有服务器状态，避免视图重用时显示错误的状态
            likeStatusFromServer = nil
            favoriteStatusFromServer = nil
            loginTypeFromServer = nil
            isLiked = false
            showChampionLabel = false
            showRankingText = false
            
            
            // 重新查询服务器状态
            if isFromRecommendation {
                loadLikeStatusFromServer()
            } else {
                loadFavoriteStatusFromServer()
            }
            loadLoginTypeFromServer()
        }
    }
    
    // 🎯 新增：实时查询 favorite 状态 - 与用户名显示一致：实时查询服务器
    // 🔧 关键区别：爱心按钮对应的是用户（userId），查询基于 userId + favoriteUserId
    private func loadFavoriteStatusFromServer() {
        guard let currentUserId = UserDefaultsManager.getCurrentUserId() else {
            return
        }
        
        let favoriteUserId = record.userId
        
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
    
    // 🎯 新增：实时查询点赞状态（与爱心按钮一致：实时查询服务器）
    // 🔧 关键区别：爱心按钮对应的是用户（userId），点赞按钮对应的是推荐榜中的一条记录（recordObjectId）
    // 🔧 关键字段：recordObjectId 对应 Recommendation 表的 objectId 字段（主键）
    private func loadLikeStatusFromServer() {
        guard let currentUserId = UserDefaultsManager.getCurrentUserId() else {
            return
        }
        
        let recordObjectId = record.objectId
        
        // 实时查询服务器状态
        let optimisticStatus = likeStatusFromServer // 保存乐观更新的状态
        LeanCloudService.shared.fetchLikeStatus(userId: currentUserId, recordObjectId: recordObjectId) { isLiked, error in
            DispatchQueue.main.async {
                if error != nil {
                    // 查询失败时，使用本地缓存状态
                    // 🔧 修复：查询失败时，如果之前有乐观更新，保持乐观更新状态
                    if optimisticStatus == nil {
                        self.likeStatusFromServer = nil
                    } else {
                    }
                } else {
                    // 更新服务器状态
                    
                    // 🔧 修复：如果服务器状态与乐观更新不一致，说明批量更新可能未完全成功
                    if let optimistic = optimisticStatus, optimistic != isLiked {
                        if optimistic == false && isLiked == true {
                        } else if optimistic == true && isLiked == false {
                        }
                    }
                    
                    // 使用服务器状态（覆盖乐观更新）
                    self.likeStatusFromServer = isLiked
                }
            }
        }
    }
    
    // 🎯 新增：从服务器加载用户类型 - 参考头像界面的实时查询方式
    private func loadLoginTypeFromServer() {
        let uid = record.userId
        
        // 🎯 参考头像界面方式：使用 fetchUserNameAndLoginType 实时查询用户类型
        LeanCloudService.shared.fetchUserNameAndLoginType(objectId: uid) { _, loginType, _ in
            DispatchQueue.main.async {
                if let loginType = loginType, !loginType.isEmpty, loginType != "unknown" {
                    self.loginTypeFromServer = loginType
                }
            }
        }
    }
}