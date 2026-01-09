import SwiftUI

struct MatchResultCard: View {
    let record: LocationRecord
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var userManager: UserManager
    let latestAvatars: [String: String]
    let latestUserNames: [String: String]
    let isUserFavorited: (String) -> Bool
    let isUserFavoritedByMe: (String) -> Bool
    let isLocationRecordLiked: (String) -> Bool
    let addFavoriteRecord: (String, String?, String?, String, String?, String?) -> Void
    let removeFavoriteRecord: (String) -> Void
    let addLikeRecord: (String, String?, String?, String, String?, String?, Bool) -> Void
    let removeLikeRecord: (String, String?, Bool) -> Void
    let showMapSelectionForLocation: (LocationRecord) -> Void
    let showRankingSheet: () -> Void
    let showFriendRequestModal: () -> Void
    let selectedTab: Int
    @State var copySuccessMessage: String
    @State var showCopySuccess: Bool
    let setCopySuccessMessage: (String) -> Void
    let setShowCopySuccess: (Bool) -> Void
    let ensureFavoriteState: () -> Void
    let onDeleteRecommendation: (() -> Void)? // 🎯 新增：删除推荐榜记录回调（可选）
    
    // 🎯 新增：高手动画状态
    @State private var showChampionAnimation: Bool = false
    @State private var cardOpacity: Double = 0 // 卡片透明度
    @State private var cardScale: CGFloat = 0.9 // 卡片缩放

    // 🎯 新增：判断是否来自推荐榜
    private var isFromRecommendation: Bool {
        let hasPlaceName = (record.placeName?.isEmpty == false)
        let hasReason = (record.reason?.isEmpty == false)
        return hasPlaceName || hasReason
    }
    
    // 🎯 新增：检查用户是否在排行榜前3名中
    private var isTop3RankingUser: Bool {
        guard let currentUserId = userManager.currentUser?.userId else {
            return false
        }
        let top3UserIds = UserDefaultsManager.getTop3RankingUserIds(userId: currentUserId)
        return top3UserIds.contains(record.userId)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            MatchResultHeaderSection(
                record: record,
                latestAvatars: latestAvatars,
                latestUserNames: latestUserNames,
                isUserFavorited: isUserFavorited,
                isUserFavoritedByMe: isUserFavoritedByMe,
                onToggleFavorite: { userId, userName, userEmail, loginType, avatar, objectId in
                    if isUserFavorited(userId) {
                        removeFavoriteRecord(userId)
                    } else {
                        addFavoriteRecord(userId, userName, userEmail, loginType ?? "guest", avatar, objectId)
                    }
                },
                onAvatarTap: {
                    // 🎯 修改：推荐榜和排行榜都显示加好友弹窗（与排行榜一致）
                    showFriendRequestModal()
                },
                onCopyUserName: {
                    let textToCopy = record.placeName?.isEmpty == false ? 
                        record.placeName! : 
                        (latestUserNames[record.userId] ?? record.userName ?? "未知用户")
                    UIPasteboard.general.string = textToCopy
                    setCopySuccessMessage(record.placeName?.isEmpty == false ? "地名已复制" : "用户名已复制")
                    setShowCopySuccess(true)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        setShowCopySuccess(false)
                    }
                },
                isLocationRecordLiked: isLocationRecordLiked, // 🎯 新增：传递点赞检查
                onToggleLike: { userId, objectId in // 🎯 新增：传递点赞切换（推荐榜专用）
                    
                    if isFromRecommendation {
                        // 🔧 修复：推荐榜也使用统一的点赞逻辑，确保状态一致
                        if isLocationRecordLiked(objectId) {
                            // 取消点赞
                            removeLikeRecord(userId, objectId, true)
                            
                            // 更新Recommendation表的likeCount（减少）
                            LeanCloudService.shared.updateRecommendationLikeCount(
                                objectId: objectId,
                                increment: false
                            ) { success, error in
                                if success {
                                    // 发送通知刷新推荐榜列表
                                    NotificationCenter.default.post(name: NSNotification.Name("RefreshRecommendationList"), object: nil)
                                }
                            }
                        } else {
                            // 点赞
                            addLikeRecord(userId, record.userName, record.userEmail, record.loginType ?? "guest", record.userAvatar, objectId, true)
                            
                            // 更新Recommendation表的likeCount（增加）
                            LeanCloudService.shared.updateRecommendationLikeCount(
                                objectId: objectId,
                                increment: true
                            ) { success, error in
                                if success {
                                    // 发送通知刷新推荐榜列表
                                    NotificationCenter.default.post(name: NSNotification.Name("RefreshRecommendationList"), object: nil)
                                }
                            }
                        }
                    } else {
                        // 非推荐榜：使用原有的点赞逻辑
                        if isLocationRecordLiked(objectId) {
                            removeLikeRecord(userId, objectId, false)
                        } else {
                            addLikeRecord(userId, record.userName, record.userEmail, record.loginType ?? "guest", nil, objectId, false)
                        }
                    }
                },
                onDeleteRecommendation: onDeleteRecommendation != nil ? {
                    onDeleteRecommendation?()
                } : nil // 🎯 修复：只有当 onDeleteRecommendation 不为 nil 时才传递闭包
            )
            .onAppear {
            }
            
            MatchResultInfoSection(
                record: record,
                locationManager: locationManager,
                isUserFavoritedByMe: isUserFavoritedByMe,
            ensureFavoriteState: ensureFavoriteState,
                onCopyEmail: {
                    // MatchResultEmailView 已经复制了实际显示的邮箱（优先使用服务器查询的邮箱）
                    // 这里只需要显示复制成功的提示
                    setCopySuccessMessage("邮箱已复制")
                    setShowCopySuccess(true)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        setShowCopySuccess(false)
                    }
                }
            )
        }
        .background(MatchResultCardBackground())
        .padding(.horizontal, 16)
        .padding(.top, 5)
        .opacity(cardOpacity)
        .scaleEffect(cardScale)
        .id(record.objectId) // 🎯 修复：使用 record.objectId 作为视图的唯一标识符，强制视图在 record 变化时重新创建
        .onAppear {
            // 🎯 新增：清除点击寻找按钮的时间记录
            if let userId = UserDefaultsManager.getCurrentUserId() {
                let key = "SearchButtonClickTime_\(userId)"
                if UserDefaults.standard.object(forKey: key) != nil {
                    // 清除 UserDefaults 中的时间记录，避免下次误用
                    UserDefaults.standard.removeObject(forKey: key)
                }
            }
            
            // 🎯 修复：每次 onAppear 都重置并重新触发动画，确保第二次打开时动画能正常播放
            resetAnimationStates()
            
            // 🎯 新增：如果是前3名用户，触发帅气动画
            if isTop3RankingUser {
                // 延迟一小段时间确保状态重置完成，然后触发动画
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    startChampionAnimation()
                }
            } else {
                // 非前3名用户，正常显示
                withAnimation(.easeOut(duration: 0.3)) {
                    cardOpacity = 1.0
                    cardScale = 1.0
                }
            }
        }
        .onDisappear {
            // 🎯 修复：视图消失时重置所有动画状态，确保下次出现时能重新触发
            resetAnimationStates()
        }
        .onChange(of: record.objectId) { oldValue, newValue in
            // 🎯 修复：当 record 变化时，重置状态并重新触发动画
            resetAnimationStates()
            
            // 如果是前3名用户，重新触发动画
            if isTop3RankingUser {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    startChampionAnimation()
                }
            } else {
                withAnimation(.easeOut(duration: 0.3)) {
                    cardOpacity = 1.0
                    cardScale = 1.0
                }
            }
        }
    }
    
    // 🎯 新增：重置所有动画状态到初始值
    private func resetAnimationStates() {
        showChampionAnimation = false
        cardOpacity = 0
        cardScale = 0.9
    }
    
    // 🎯 新增：触发高手动画序列
    private func startChampionAnimation() {
        
        // 第一阶段：卡片淡入和缩放
        withAnimation(.easeOut(duration: 0.3)) {
            cardOpacity = 1.0
            cardScale = 1.0
        }
        
        // 第二阶段：显示"高手"标签（延迟0.3秒）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showChampionAnimation = true
            }
        }
        
        // 第三阶段：卡片轻微弹跳效果（延迟0.6秒）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                cardScale = 1.02
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    cardScale = 1.0
                }
            }
        }
    }
}