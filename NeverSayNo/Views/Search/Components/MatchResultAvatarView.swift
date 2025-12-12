import SwiftUI

struct MatchResultAvatarView: View {
    let record: LocationRecord
    let latestAvatars: [String: String]
    @State private var avatarFromServer: String? = nil
    @State private var lastUserId: String? = nil // 🎯 新增：记录上次的 userId，用于检测切换
    @State private var avatarRetryCount: Int = 0 // 🎯 新增：头像重试次数（最多重试2次）
    
    // 🎯 新增：高手动画状态
    @State private var crownRotation: Double = -180 // 皇冠旋转角度
    @State private var crownScale: CGFloat = 0.5 // 皇冠缩放
    @State private var crownOffset: CGFloat = -50 // 皇冠偏移
    @State private var avatarScale: CGFloat = 0.8 // 头像缩放
    @State private var showCrown: Bool = false // 🎯 新增：控制皇冠显示（紫色皇冠只显示1.5秒）
    
    // 🎯 新增：检查用户是否在排行榜前3名中
    private var isTop3RankingUser: Bool {
        let top3UserIds = UserDefaultsManager.getTop3RankingUserIds()
        return top3UserIds.contains(record.userId)
    }
    
    var body: some View {
        ZStack {
            Group {
                if let avatar = displayAvatar, !avatar.isEmpty {
                    // 与用户头像界面一致：支持SF Symbol和emoji/文本
                    if avatar == "apple_logo" || avatar == "applelogo" {
                        Image(systemName: "applelogo")
                            .foregroundColor(.black)
                    } else if UserAvatarUtils.isSFSymbol(avatar) {
                        // 🔧 修复：检查是否是 SF Symbol，如果是则显示图标而不是文字
                        Image(systemName: avatar)
                            .foregroundColor(avatar == "person.circle.fill" ? .purple : .blue)
                    } else {
                        Text(avatar)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                } else {
                    DefaultAvatarView(loginType: record.loginType)
                }
            }
            .font(.system(size: 48))
            .background(
                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 80, height: 80)
            )
            .scaleEffect(isTop3RankingUser ? avatarScale : 1.0)
            
            // 🎯 新增：前3名用户头像上添加明显的皇冠装饰（带动画）
            if isTop3RankingUser && showCrown {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "crown.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.purple)
                            .shadow(color: .purple.opacity(0.8), radius: 4, x: 0, y: 2)
                            .padding(.top, -8)
                            .padding(.trailing, -8)
                            .rotationEffect(.degrees(crownRotation))
                            .scaleEffect(crownScale)
                            .offset(y: crownOffset)
                    }
                    Spacer()
                }
                .frame(width: 80, height: 80)
            }
        }
        .onAppear {
            // 🎯 修复：切换不同推荐榜时，重置头像状态
            let currentUserId = record.userId
            if let lastUserId = lastUserId, lastUserId != currentUserId {
                avatarFromServer = nil // 重置头像状态
                // 重置动画状态
                if isTop3RankingUser {
                    crownRotation = -180
                    crownScale = 0.5
                    crownOffset = -50
                    avatarScale = 0.8
                    showCrown = false // 🎯 新增：重置皇冠显示状态
                }
            }
            lastUserId = currentUserId
            
            // 🎯 修复：每次出现时重置所有动画状态，确保第二次打开时动画能正常播放
            if isTop3RankingUser {
                // 重置所有动画状态
                crownRotation = -180
                crownScale = 0.5
                crownOffset = -50
                avatarScale = 0.8
                showCrown = false
                // 触发皇冠动画
                startCrownAnimation()
            } else {
                // 非前3名用户，重置头像缩放
                avatarScale = 1.0
            }
            
            // 🎯 修改：推荐榜和排行榜都实时查询服务器头像（与排行榜一致）
            loadAvatarFromServer()
        }
        .task {
            // 🎯 新增：检查查询是否失败，如果失败则重试
            try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 / 7.0)) // 1/7秒
            // 检查是否查询失败（avatarFromServer 为 nil）且未达到最大重试次数
            let shouldRetry = avatarFromServer == nil && avatarRetryCount < 2
            if shouldRetry {
                retryLoadAvatarFromServer()
            }
        }
    }
    
    // 🎯 修改：统一逻辑，推荐榜和排行榜都使用相同的头像显示优先级（与排行榜一致）
    private var displayAvatar: String? {
        let uid = record.userId
        // 第一优先级：从服务器实时查询的头像（与排行榜一致）
        // 🎯 修复：确保 avatarFromServer 是当前用户的头像
        if let serverAvatar = avatarFromServer, !serverAvatar.isEmpty, lastUserId == uid {
            return serverAvatar
        }
        // 第二优先级：从 UserDefaults 获取头像（与排行榜一致）
        if let customAvatar = UserDefaultsManager.getCustomAvatar(userId: uid), !customAvatar.isEmpty {
            return customAvatar
        }
        // 第三优先级：使用本地缓存
        if let latest = latestAvatars[uid], !latest.isEmpty {
            return latest
        }
        // 第四优先级：使用记录中的头像
        return record.userAvatar
    }
    
    // 从服务器加载头像 - 🎯 统一从 UserAvatarRecord 表获取（与排行榜一致）
    private func loadAvatarFromServer() {
        let uid = record.userId
        
        // 🎯 修改：使用 fetchUserAvatarByUserId，不依赖 loginType，直接从 UserAvatarRecord 表获取
        LeanCloudService.shared.fetchUserAvatarByUserId(objectId: uid) { avatar, error in
            DispatchQueue.main.async {
                if error != nil {
                } else if let avatar = avatar, !avatar.isEmpty {
                    // 🔍 检查 UserDefaults 与服务器数据是否一致
                    let userDefaultsAvatar = UserDefaultsManager.getCustomAvatar(userId: uid)
                    if let defaultsAvatar = userDefaultsAvatar, !defaultsAvatar.isEmpty {
                        if defaultsAvatar != avatar {
                            // 🔧 自动更新 UserDefaults 以保持一致性
                            UserDefaultsManager.setCustomAvatar(userId: uid, emoji: avatar)
                        } else {
                        }
                    } else {
                        UserDefaultsManager.setCustomAvatar(userId: uid, emoji: avatar)
                    }
                    self.avatarFromServer = avatar
                } else {
                    // 🎯 修改：查询失败时，如果 avatarFromServer 仍为 nil 且未达到最大重试次数，触发第二次重试
                    if self.avatarFromServer == nil && self.avatarRetryCount < 2 {
                        self.retryLoadAvatarFromServer()
                    }
                }
            }
        }
    }
    
    // 🎯 新增：重试查询头像（最多重试2次）
    private func retryLoadAvatarFromServer() {
        guard avatarRetryCount < 2 else {
            return
        }
        avatarRetryCount += 1
        
        // 🎯 修改：根据重试次数决定延迟时间
        // 第一次重试：延迟1/17秒；第二次重试：延迟0.5秒
        let delay: TimeInterval = avatarRetryCount == 1 ? 1.0 / 17.0 : 0.5
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if self.avatarFromServer == nil {
                self.loadAvatarFromServer()
            }
        }
    }
    
    // 🎯 新增：触发皇冠动画序列
    private func startCrownAnimation() {
        // 第一阶段：头像缩放
        withAnimation(.easeOut(duration: 0.3)) {
            avatarScale = 1.0
        }
        
        // 第二阶段：皇冠从上方旋转飞入（延迟0.3秒）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showCrown = true
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                crownRotation = 0
                crownScale = 1.0
                crownOffset = 0
            }
            
            // 🎯 新增：紫色皇冠只显示3.2秒后隐藏
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
                withAnimation(.easeOut(duration: 0.3)) {
                    self.showCrown = false
                }
            }
        }
        
        // 第三阶段：头像轻微弹跳效果（延迟0.9秒）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                avatarScale = 1.05
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    avatarScale = 1.0
                }
            }
        }
    }
}