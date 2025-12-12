import SwiftUI

struct UserMatchCard: View {
    let record: LocationRecord
    let latestAvatars: [String: String]
    let latestUserNames: [String: String]
    let locationManager: LocationManager
    let userManager: UserManager
    let isUserFavorited: (String) -> Bool
    let isLocationRecordLiked: (String) -> Bool
    let addFavoriteRecord: (String, String?, String?, String?, String?, String?) -> Void
    let removeFavoriteRecord: (String) -> Void
    let addLikeRecord: (String, String?, String?, String?, String?, String?) -> Void
    let removeLikeRecord: (String, String) -> Void
    let showMapSelectionForLocation: (LocationRecord) -> Void
    let showRankingSheet: () -> Void
    let showFriendRequestModal: () -> Void
    let selectedTab: Int
    let copySuccessMessage: String
    let showCopySuccess: Bool
    let setCopySuccessMessage: (String) -> Void
    let setShowCopySuccess: (Bool) -> Void
    @State private var avatarFromServer: String? = nil
    @State private var userNameFromServer: String? = nil
    @State private var emailFromServer: String? = nil
    @State private var avatarRetryCount: Int = 0 // 🎯 新增：头像重试次数（最多重试2次）
    @State private var userNameRetryCount: Int = 0 // 🎯 新增：用户名重试次数（最多重试2次）
    @State private var favoriteStatusFromServer: Bool? = nil // 🎯 新增：从服务器实时查询的 favorite 状态
    @State private var loginTypeFromServer: String? = nil // 🎯 新增：从服务器实时查询的用户类型（参考头像界面方式）
    // 🎯 新增：LoginRecord 表的最近上线时间文案
    @State private var lastOnlineText: String? = nil
    // 🎯 新增：高手动画状态
    @State private var showChampionAnimation: Bool = false
    @State private var crownRotation: Double = 0 // 皇冠旋转角度
    @State private var crownScale: CGFloat = 0.3 // 皇冠缩放（从更小开始）
    @State private var crownOffsetX: CGFloat = 0 // 皇冠X偏移（从屏幕中心）
    @State private var crownOffsetY: CGFloat = 0 // 皇冠Y偏移（从屏幕中心）
    @State private var avatarScale: CGFloat = 0.8 // 头像缩放
    @State private var cardOpacity: Double = 0 // 卡片透明度
    @State private var screenCenterX: CGFloat = 0 // 屏幕中心X坐标
    @State private var screenCenterY: CGFloat = 0 // 屏幕中心Y坐标
    @State private var avatarCenterX: CGFloat = 0 // 头像中心X坐标
    @State private var avatarCenterY: CGFloat = 0 // 头像中心Y坐标
    
    // 🎯 方案七：组合特效状态
    @State private var flashScale: CGFloat = 0 // 闪光缩放
    @State private var flashOpacity: Double = 0 // 闪光透明度
    @State private var particles: [Particle] = [] // 粒子数组
    @State private var crownGradientOffset: Double = 0 // 彩虹渐变偏移
    @State private var isCrownPurple: Bool = false // 皇冠是否变为紫色
    @State private var showCrown: Bool = false // 🎯 新增：控制皇冠显示（紫色皇冠只显示3.2秒）
    @State private var showRankingText: Bool = false // 🎯 新增：排名文字显示状态（4.7秒后消失）
    @State private var haloScale: CGFloat = 0 // 光环缩放
    @State private var haloOpacity: Double = 0 // 光环透明度
    @State private var backgroundGlowOpacity: Double = 0 // 背景光效透明度
    @State private var heartBeatScale: CGFloat = 1.0 // 心跳缩放
    @State private var lastRecordId: String? = nil // 🎯 新增：记录上次的 record ID，用于检测变化
    
    // 🎯 粒子结构
    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var opacity: Double
        var scale: CGFloat
        
        // 为了支持动画更新，需要实现Equatable
        static func == (lhs: Particle, rhs: Particle) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 🎯 添加：使用 record.objectId 作为视图的唯一标识符，强制视图在 record 变化时重新创建
            Color.clear
                .frame(width: 0, height: 0)
                .id(record.objectId)
            // 顶部渐变背景
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.05)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 120)
            .opacity(cardOpacity)
            .overlay(
                // 用户头像和用户名信息 - 水平居中布局，等比例缩放
                HStack(spacing: 32) {
                    // 头像
                    Button(action: {
                        // 🎯 修改：推荐榜和排行榜都显示加好友弹窗（与排行榜一致）
                        showFriendRequestModal()
                    }) {
                        ZStack {
                            Group {
                                if let avatar = displayAvatar, !avatar.isEmpty {
                                    if avatar == "apple_logo" || avatar == "applelogo" {
                                        Image(systemName: "applelogo")
                                            .font(.system(size: 48))
                                            .foregroundColor(.black)
                                            .background(Circle().fill(Color.gray.opacity(0.1)).frame(width: 80, height: 80))
                                    } else if UserAvatarUtils.isSFSymbol(avatar) {
                                        // 🔧 修复：检查是否是 SF Symbol，如果是则显示图标而不是文字
                                        Image(systemName: avatar)
                                            .font(.system(size: 48))
                                            .foregroundColor(avatar == "person.circle.fill" ? .purple : .blue)
                                            .background(Circle().fill(Color.gray.opacity(0.1)).frame(width: 80, height: 80))
                                    } else {
                                        Text(avatar)
                                            .font(.system(size: 48))
                                            .fixedSize(horizontal: true, vertical: false)
                                            .background(Circle().fill(Color.gray.opacity(0.1)).frame(width: 80, height: 80))
                                    }
                                } else {
                                    ZStack {
                                        Circle().fill(UserTypeUtils.getUserTypeBackground(record.loginType)).frame(width: 80, height: 80)
                                        if record.loginType == "apple" {
                                            Image(systemName: "applelogo").foregroundColor(.black).font(.system(size: 36, weight: .medium))
                                        } else {
                                            // 游客用户 - 与用户头像界面一致：使用person.circle（蓝色）
                                            Image(systemName: "person.circle").foregroundColor(.blue).font(.system(size: 36, weight: .medium))
                                        }
                                    }
                                }
                            }
                            .scaleEffect(isTop3RankingUser ? avatarScale : 1.0)
                            
                            // 🎯 方案七：组合特效 - 皇冠（彩虹渐变转紫色）
                            if isTop3RankingUser && showCrown {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundStyle(
                                        isCrownPurple ? 
                                        AnyShapeStyle(Color.purple) :
                                        AnyShapeStyle(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color.red,
                                                    Color.orange,
                                                    Color.yellow,
                                                    Color.green,
                                                    Color.blue,
                                                    Color.purple
                                                ]),
                                                startPoint: UnitPoint(x: 0 + crownGradientOffset, y: 0),
                                                endPoint: UnitPoint(x: 1 + crownGradientOffset, y: 1)
                                            )
                                        )
                                    )
                                    .shadow(color: isCrownPurple ? .purple.opacity(0.9) : .yellow.opacity(0.9), radius: 8, x: 0, y: 4)
                                    .rotationEffect(.degrees(crownRotation))
                                    .scaleEffect(crownScale * heartBeatScale)
                                    .offset(x: crownOffsetX, y: crownOffsetY)
                            }
                            
                            // 🎯 方案七：屏幕中心闪光效果
                            if isTop3RankingUser && flashOpacity > 0 {
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            gradient: Gradient(colors: [
                                                Color.white.opacity(0.9),
                                                Color.yellow.opacity(0.6),
                                                Color.clear
                                            ]),
                                            center: .center,
                                            startRadius: 0,
                                            endRadius: 100
                                        )
                                    )
                                    .frame(width: 200, height: 200)
                                    .scaleEffect(flashScale)
                                    .opacity(flashOpacity)
                                    .offset(x: screenCenterX - 100, y: screenCenterY - 100)
                                    .blur(radius: 10)
                            }
                            
                            // 🎯 方案七：粒子效果
                            ForEach(particles) { particle in
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.yellow.opacity(0.8),
                                                Color.purple.opacity(0.6)
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 6, height: 6)
                                    .scaleEffect(particle.scale)
                                    .opacity(particle.opacity)
                                    .offset(x: particle.x, y: particle.y)
                            }
                            
                            // 🎯 方案七：头像周围紫色光环
                            if isTop3RankingUser && haloOpacity > 0 {
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.purple.opacity(0.8),
                                                Color.purple.opacity(0.3),
                                                Color.clear
                                            ]),
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 3
                                    )
                                    .frame(width: 100, height: 100)
                                    .scaleEffect(haloScale)
                                    .opacity(haloOpacity)
                                    .blur(radius: 2)
                            }
                            
                            // 🎯 方案七：头像背景径向渐变光效
                            if isTop3RankingUser && backgroundGlowOpacity > 0 {
                                Circle()
                                    .fill(
                                        RadialGradient(
                                            gradient: Gradient(colors: [
                                                Color.purple.opacity(0.4),
                                                Color.purple.opacity(0.1),
                                                Color.clear
                                            ]),
                                            center: .center,
                                            startRadius: 30,
                                            endRadius: 60
                                        )
                                    )
                                    .frame(width: 120, height: 120)
                                    .opacity(backgroundGlowOpacity)
                                    .blur(radius: 5)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    
                    // 用户名和类型（推荐榜显示地名）
                    VStack(alignment: .leading, spacing: 8) {
                        // 🎯 使用计算属性简化表达式
                        // 🎯 修改：推荐榜显示地名（根据推荐者的 UserNameRecord 决定是否显示彩色），非推荐榜显示彩色用户名
                        Group {
                            if let placeName = record.placeName, !placeName.isEmpty {
                                ColorfulPlaceNameText(
                                    placeName: placeName,
                                    userId: record.userId,
                                    loginType: finalLoginType,
                                    font: .title2,
                                    fontWeight: .bold,
                                    lineLimit: 1,
                                    truncationMode: .tail
                                )
                                .minimumScaleFactor(0.3)
                            } else {
                                ColorfulUserNameText(
                                    userName: displayUserName,
                                    userId: record.userId,
                                    loginType: finalLoginType,
                                    font: .title2,
                                    fontWeight: .bold,
                                    lineLimit: 1,
                                    truncationMode: .tail
                                )
                                .minimumScaleFactor(0.3)
                            }
                        }
                        .onTapGesture {
                            // 🎯 修改：推荐榜和排行榜都显示加好友弹窗（与排行榜一致）
                            showFriendRequestModal()
                        }
                        .onLongPressGesture {
                                let textToCopy: String
                                if let placeName = record.placeName, !placeName.isEmpty {
                                    textToCopy = placeName  // 复制地名
                                } else {
                                    textToCopy = latestUserNames[record.userId] ?? record.userName ?? "未知用户"  // 复制用户名
                                }
                                UIPasteboard.general.string = textToCopy
                                let message = (record.placeName?.isEmpty == false) ? "地名已复制" : "用户名已复制"
                                setCopySuccessMessage(message)
                                setShowCopySuccess(true)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    setShowCopySuccess(false)
                                }
                            }
                        
                        // 用户类型标签和爱心按钮
                        HStack(spacing: 8) {
                        // 用户类型标签（推荐榜显示推荐标识，前3名用户显示"高手"标识替代原用户类型）
                        HStack(spacing: 4) {
                            if let placeName = record.placeName, !placeName.isEmpty {
                                // 推荐榜：显示推荐地点标识
                                Image(systemName: "star.fill")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 11))
                                Text("推荐地点")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.orange)
                            } else if isTop3RankingUser, let rank = rankingPosition {
                                // 🎯 修改：前3名用户显示"高手"标识替代原用户类型标识，并显示排名
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.yellow)
                                    .font(.system(size: 11))
                                HStack(spacing: 0) {
                                    Text("高手")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.orange)
                                    // 🎯 新增：排名文字独立控制显示/消失（4.7秒后消失）
                                    if showRankingText {
                                        Text("（排行榜第\(rank)名）")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.orange)
                                            .transition(.opacity)
                                    }
                                }
                            } else {
                                // 🎯 参考头像界面方式：优先使用实时查询的用户类型，然后使用记录中的用户类型
                                if finalLoginType == "apple" {
                                    Image(systemName: "applelogo")
                                        .foregroundColor(.black)
                                        .font(.system(size: 11))
                                    Text("Apple用户")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    .foregroundColor(.black)
                                } else {
                                    // 游客用户 - 与用户头像界面一致：使用person.circle（蓝色）
                                    Image(systemName: "person.circle")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 11))
                                    Text("游客用户")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(getLabelBackgroundColor())
                        )
                        .opacity((isTop3RankingUser && showChampionAnimation) || !isTop3RankingUser ? 1.0 : 0.0)
                        .scaleEffect((isTop3RankingUser && showChampionAnimation) || !isTop3RankingUser ? 1.0 : 0.5)
                            
                            // 爱心按钮 - 🎯 新增：实时查询服务器状态
                            Button(action: {
                                if displayedFavoriteStatus {
                                    // 取消喜欢
                                    removeFavoriteRecord(record.userId)
                                } else {
                                    // 喜欢
                                    // 🎯 使用 finalLoginType（优先使用实时查询的用户类型）
                                    addFavoriteRecord(
                                        record.userId,
                                        record.userName,
                                        record.userEmail,
                                        finalLoginType,
                                        displayAvatar,
                                        record.objectId
                                    )
                                }
                                
                                // 🎯 新增：操作后重新查询服务器状态
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    loadFavoriteStatusFromServer()
                                }
                            }) {
                                Image(systemName: displayedFavoriteStatus ? "heart.fill" : "heart")
                                    .foregroundColor(displayedFavoriteStatus ? .red : .gray)
                                    .font(.system(size: 16))
                                    .scaleEffect(displayedFavoriteStatus ? 1.26 : 1.0)
                                    .animation(.easeInOut(duration: 0.2), value: displayedFavoriteStatus)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .onAppear {
                                // 🎯 新增：在爱心按钮出现时实时查询服务器状态
                                loadFavoriteStatusFromServer()
                            }
                            
                            // 点赞按钮
                            Button(action: {
                                if isLocationRecordLiked(record.objectId) {
                                    // 取消点赞
                                    removeLikeRecord(record.userId, record.objectId)
                                } else {
                                    // 点赞
                                    // 修正登录类型：对于没有前缀的用户ID，应该是internal类型
                                    let correctedLoginType = record.loginType ?? UserTypeUtils.getLoginTypeFromUserId(record.userId)
                                    
                                    addLikeRecord(
                                        record.userId,
                                        record.userName,
                                        record.userEmail,
                                        correctedLoginType,
                                        displayAvatar,
                                        record.objectId
                                    )
                                }
                            }) {
                                Image(systemName: isLocationRecordLiked(record.objectId) ? "hand.thumbsup.fill" : "hand.thumbsup")
                                    .foregroundColor(isLocationRecordLiked(record.objectId) ? .blue : .gray)
                                    .font(.system(size: 16))
                                    .scaleEffect(isLocationRecordLiked(record.objectId) ? 1.26 : 1.0)
                                    .animation(.easeInOut(duration: 0.2), value: isLocationRecordLiked(record.objectId))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .scaleEffect(1.0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(
                        // 导航按钮 - 位于右上角
                        VStack {
                            HStack {
                                Spacer()
                                Button(action: {
                                    // 显示地图选择弹窗
                                    showMapSelectionForLocation(record)
                                }) {
                                    Text("导航")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.top, 8)
                                .padding(.trailing, 8)
                            }
                            Spacer()
                        }
                    )
                }
            )
            
            // 信息内容区域
            VStack(spacing: 16) {
                // 主要信息行 - 智能自适应缩放，统一比例
                GeometryReader { geometry in
                    let availableWidth = geometry.size.width - 40 // 减去左右padding
                    let itemCount = TimezoneUtils.shouldShowTimezone(record.longitude) ? 3 : 2
                    let spacingWidth = CGFloat(itemCount - 1) * 20 // 间距总宽度
                    let estimatedItemWidth = (availableWidth - spacingWidth) / CGFloat(itemCount)
                    
                    // 无限制缩放策略：确保信息完整显示
                    let baseScale = min(1.0, estimatedItemWidth / 60) // 进一步降低基准宽度到60
                    let deviceScale = UIScreen.main.bounds.width < 375 ? 0.65 : 1.0 // 更激进的设备缩放
                    let contentScale = UIScreen.main.bounds.width < 320 ? 0.55 : 1.0 // 更激进的超小屏幕缩放
                    let finalScale = baseScale * deviceScale * contentScale // 不设置最小限制，确保信息完整
                    
                    HStack(spacing: finalScale < 0.6 ? (finalScale < 0.3 ? 1 : (finalScale < 0.4 ? 2 : (finalScale < 0.5 ? 5 : 10))) : 20) { // 更精细的间距控制
                        // 距离信息
                        if let currentLocation = locationManager.location {
                            // ⚖️ 坐标系转换：LocationRecord中存储的是GCJ-02坐标，需要转回WGS-84才能与当前位置（WGS-84）正确计算距离
                            let (wgsLat, wgsLon) = CoordinateConverter.gcj02ToWgs84(
                                latitude: record.latitude,
                                longitude: record.longitude
                            )
                            
                            let distance = DistanceUtils.calculateDistance(from: currentLocation, to: wgsLat, targetLongitude: wgsLon)
                            
                            VStack(spacing: finalScale < 0.6 ? (finalScale < 0.3 ? 0 : (finalScale < 0.4 ? 1 : (finalScale < 0.5 ? 2 : 4))) : 6) { // 更精细的垂直间距控制
                                Image(systemName: "location.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 24))
                                Text(DistanceUtils.formatDistance(distance))
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                                    .minimumScaleFactor(0.3) // 允许字体缩小到30%，避免省略号
                                    .lineLimit(1) // 单行显示
                                    .truncationMode(.tail)
                            }
                            .frame(maxWidth: .infinity)
                            .onAppear {
                            }
                        }
                        
                        // 时间信息
                        VStack(spacing: finalScale < 0.6 ? (finalScale < 0.3 ? 0 : (finalScale < 0.4 ? 1 : (finalScale < 0.5 ? 2 : 4))) : 6) { // 更精细的垂直间距控制
                            Image(systemName: "clock.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 24))
                            Text(displayTimeText)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                                .minimumScaleFactor(0.3) // 允许字体缩小到30%，避免省略号
                                .lineLimit(1) // 单行显示
                                .truncationMode(.tail)
                        }
                        .frame(maxWidth: .infinity)
                        
                        // 时区信息
                        if TimezoneUtils.shouldShowTimezone(record.longitude) {
                            VStack(spacing: finalScale < 0.6 ? (finalScale < 0.3 ? 0 : (finalScale < 0.4 ? 1 : (finalScale < 0.5 ? 2 : 4))) : 6) { // 更精细的垂直间距控制
                                Image(systemName: "clock.badge")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 24))
                                Text(TimezoneUtils.calculateTimezoneFromLongitude(record.longitude))
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                                    .minimumScaleFactor(0.3) // 允许字体缩小到30%，避免省略号
                                    .lineLimit(1) // 单行显示
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .scaleEffect(finalScale)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: 80) // 固定高度确保布局稳定
                .padding(.horizontal, 20)
                .animation(.easeInOut(duration: 0.3), value: TimezoneUtils.shouldShowTimezone(record.longitude)) // 平滑动画
                .clipped() // 确保内容不会溢出
                
                // 邮箱信息（只显示喜欢了自己的用户的邮箱）- 与用户名显示逻辑一致：实时查询服务器
                let displayedEmail = emailFromServer ?? record.userEmail
                // 🎯 新增：检查是否是默认邮箱，如果是则不显示
                let isDefaultEmail = displayedEmail?.hasSuffix("@internal.com") == true || 
                                   displayedEmail?.hasSuffix("@apple.com") == true || 
                                   displayedEmail?.hasSuffix("@guest.com") == true
                if isUserFavoritedByMe(userId: record.userId), let userEmail = displayedEmail, !userEmail.isEmpty, !isDefaultEmail {
                    Divider()
                        .padding(.horizontal, 20)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 18))
                        Text(userEmail)
                            .font(.title3)
                            .foregroundColor(.blue)
                            .lineLimit(1) // 单行显示
                            .onLongPressGesture {
                                UIPasteboard.general.string = userEmail
                                setCopySuccessMessage("邮箱已复制")
                                setShowCopySuccess(true)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    setShowCopySuccess(false)
                                }
                            }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 20)
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
        )
        .padding(.horizontal, 16)
        .padding(.top, 5)
        .opacity(cardOpacity)
        .scaleEffect(getCardScale())
        .id(record.objectId) // 🎯 修复：使用 record.objectId 作为视图的唯一标识符，强制视图在 record 变化时重新创建
        .onAppear {
            // 与用户头像界面一致：在onAppear时实时查询服务器头像、用户名和邮箱
            loadAvatarFromServer()
            loadUserNameFromServer()
            loadEmailFromServer()
            // 🎯 新增：实时查询 favorite 状态
            loadFavoriteStatusFromServer()
            // 🎯 新增：实时查询用户类型（参考头像界面方式）
            loadLoginTypeFromServer()
            // 🎯 新增：查询 LoginRecord 表的最近上线时间
            loadLastOnlineTime()
            
            // 🎯 修复：每次 onAppear 都重置并重新触发动画，确保第二次打开时动画能正常播放
            // 重置所有动画状态
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
                }
            }
        }
        .task {
            // 🎯 新增：检查查询是否失败，如果失败则重试
            try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 / 7.0)) // 1/7秒
            // 检查是否查询失败且未达到最大重试次数
            let shouldRetryAvatar = avatarFromServer == nil && avatarRetryCount < 2
            let shouldRetryUserName = userNameFromServer == nil && userNameRetryCount < 2
            if shouldRetryAvatar {
                retryLoadAvatarFromServer()
            }
            if shouldRetryUserName {
                retryLoadUserNameFromServer()
            }
        }
        .onDisappear {
            // 🎯 修复：视图消失时重置所有动画状态，确保下次出现时能重新触发
            resetAnimationStates()
        }
        .onChange(of: record.objectId) { oldValue, newValue in
            // 🎯 修复：当 record 变化时，重置状态并重新触发动画
            resetAnimationStates()
            
            // 重新加载数据
            loadAvatarFromServer()
            loadUserNameFromServer()
            loadEmailFromServer()
            loadFavoriteStatusFromServer()
            loadLoginTypeFromServer()
            loadLastOnlineTime()
            
            // 如果是前3名用户，重新触发动画
            if isTop3RankingUser {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    startChampionAnimation()
                }
            } else {
                withAnimation(.easeOut(duration: 0.3)) {
                    cardOpacity = 1.0
                }
            }
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
    
    // 与用户头像界面一致的头像显示优先级
    private var displayAvatar: String? {
        let uid = record.userId
        // 第一优先级：从服务器实时查询的头像（与用户头像界面一致）
        if let serverAvatar = avatarFromServer, !serverAvatar.isEmpty {
            return serverAvatar
        }
        // 第二优先级：从 UserDefaults 获取头像（与用户头像界面一致：使用 displayAvatar，对应 UserDefaults）
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
    
    // 与用户头像界面一致的用户名显示优先级
    private var displayUserName: String {
        let uid = record.userId
        // 第一优先级：从服务器实时查询的用户名
        if let serverName = userNameFromServer, !serverName.isEmpty {
            return serverName
        }
        // 第二优先级：使用本地缓存
        if let latest = latestUserNames[uid], !latest.isEmpty {
            return latest
        }
        // 第三优先级：使用记录中的用户名
        return record.userName ?? "未知用户"
    }
    
    // 🎯 新增：计算最终的用户类型（优先使用实时查询，然后使用记录中的类型）
    private var finalLoginType: String {
        return loginTypeFromServer ?? record.loginType ?? "unknown"
    }
    
    // 🎯 修改：显示在匹配卡片上的时间文案（LoginRecord 表为唯一数据来源）
    private var displayTimeText: String {
        // 🎯 修改：只使用 LoginRecord 表数据，无回退逻辑
        if let text = lastOnlineText, !text.isEmpty {
            return text
        }
        // 如果 LoginRecord 表没有数据，返回空字符串
        return ""
    }
    
    // 🎯 新增：计算显示的用户名或地名文本
    private var displayText: String {
        if let placeName = record.placeName, !placeName.isEmpty {
            return placeName  // 推荐榜：显示地名
        } else {
            return displayUserName  // 排行榜：显示用户名
        }
    }
    
    // 🎯 新增：计算文本颜色
    private var displayTextColor: Color {
        if let placeName = record.placeName, !placeName.isEmpty {
            return Color.green  // 推荐榜：绿色地名
        } else {
            return Color.primary  // 排行榜：默认颜色
        }
    }
    
    // 🎯 新增：检查用户是否在排行榜前3名中
    private var isTop3RankingUser: Bool {
        let top3UserIds = UserDefaultsManager.getTop3RankingUserIds()
        return top3UserIds.contains(record.userId)
    }
    
    // 🎯 新增：获取用户在排行榜中的排名（返回1-3，如果不在前3名则返回nil）
    private var rankingPosition: Int? {
        return UserDefaultsManager.getRankingPosition(userId: record.userId)
    }
    
    // 🎯 新增：计算标签背景颜色
    private func getLabelBackgroundColor() -> Color {
        if let placeName = record.placeName, !placeName.isEmpty {
            return Color.orange.opacity(0.15)
        } else if isTop3RankingUser {
            return Color.orange.opacity(0.15)
        } else if finalLoginType == "apple" {
            return Color.purple.opacity(0.1)
        } else {
            return Color.blue.opacity(0.1)
        }
    }
    
    // 🎯 新增：计算卡片缩放值（避免类型检查超时）
    private func getCardScale() -> CGFloat {
        if isTop3RankingUser {
            return showChampionAnimation ? 1.0 : 0.9
        }
        return 1.0
    }
    
    // 🎯 新增：重置所有动画状态到初始值
    private func resetAnimationStates() {
        showChampionAnimation = false
        crownRotation = 0
        crownScale = 0.3
        crownOffsetX = 0
        crownOffsetY = 0
        avatarScale = 0.8
        cardOpacity = 0
        flashScale = 0
        flashOpacity = 0
        particles = []
        crownGradientOffset = 0
        isCrownPurple = false
        showCrown = false
        showRankingText = false
        haloScale = 0
        haloOpacity = 0
        backgroundGlowOpacity = 0
        heartBeatScale = 1.0
    }
    
    // 🎯 方案七：组合特效动画序列
    private func startChampionAnimation() {
        
        // 获取屏幕中心位置
        let screenBounds = UIScreen.main.bounds
        screenCenterX = screenBounds.width / 2
        screenCenterY = screenBounds.height / 2
        
        // 计算从头像位置到屏幕中心的偏移
        let estimatedAvatarX: CGFloat = 0
        let estimatedAvatarY: CGFloat = -250
        crownOffsetX = screenCenterX - estimatedAvatarX
        crownOffsetY = screenCenterY - estimatedAvatarY
        
        // 第一阶段：卡片淡入，头像缩放
        withAnimation(.easeOut(duration: 0.3)) {
            cardOpacity = 1.0
            avatarScale = 1.0
        }
        
        // 第二阶段：屏幕中心闪光 + 粒子散开（延迟0.1秒）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // 闪光效果
            withAnimation(.easeOut(duration: 0.3)) {
                flashScale = 2.0
                flashOpacity = 1.0
            }
            
            // 粒子生成（12个粒子，向不同方向散开）
            var newParticles: [Particle] = []
            for _ in 0..<12 {
                newParticles.append(Particle(
                    x: screenCenterX,
                    y: screenCenterY,
                    opacity: 1.0,
                    scale: 1.0
                ))
            }
            particles = newParticles
            
            // 粒子散开动画
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.6)) {
                    for i in particles.indices {
                        let angle = Double(i) * (360.0 / 12.0) * .pi / 180.0
                        let distance: CGFloat = 200
                        particles[i].x = screenCenterX + cos(angle) * distance
                        particles[i].y = screenCenterY + sin(angle) * distance
                        particles[i].opacity = 0
                        particles[i].scale = 0.3
                    }
                }
            }
            
            // 闪光淡出
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeOut(duration: 0.2)) {
                    flashOpacity = 0
                }
            }
        }
        
        // 第三阶段：皇冠从屏幕中心出现（彩虹渐变，延迟0.2秒）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // 显示皇冠（从彩虹渐变开始）
            showCrown = true
            
            // 彩虹渐变动画
            withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                crownGradientOffset = 1.0
            }
            
            // 皇冠出现
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                crownRotation = 360
                crownScale = 0.8
            }
            
            // 0.5秒后变为紫色
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isCrownPurple = true
                }
                
                // 🎯 新增：排名文字在紫色皇冠变为紫色时显示
                withAnimation {
                    showRankingText = true
                }
                
                // 🎯 新增：紫色皇冠只显示3.2秒后隐藏
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showCrown = false
                    }
                }
                
                // 🎯 新增：排名文字在4.7秒后隐藏（比紫色皇冠多显示1.5秒）
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.7) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showRankingText = false
                    }
                }
                
                // 皇冠飞向头像
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                        crownRotation = 0
                        crownScale = 1.0
                        crownOffsetX = 0
                        crownOffsetY = -8
                    }
                    
                    // 到达后启动光环和光效
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        // 光环脉冲
                        withAnimation(.easeOut(duration: 0.3)) {
                            haloScale = 1.2
                            haloOpacity = 0.8
                            backgroundGlowOpacity = 0.6
                        }
                        
                        // 光环持续脉冲
                        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                            haloScale = 1.4
                            haloOpacity = 0.4
                        }
                        
                        // 背景光效持续
                        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                            backgroundGlowOpacity = 0.3
                        }
                        
                        // 心跳效果
                        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                            heartBeatScale = 1.1
                        }
                    }
                }
            }
        }
        
        // 第四阶段：显示"高手"标签（延迟1.2秒）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showChampionAnimation = true
            }
        }
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
    
    // 从服务器加载头像 - 🎯 统一从 UserAvatarRecord 表获取
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
    
    // 从服务器加载用户名 - 🎯 统一从 UserNameRecord 表获取
    private func loadUserNameFromServer() {
        let uid = record.userId
        
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
    
    // 🎯 新增：重试查询用户名（最多重试2次）
    private func retryLoadUserNameFromServer() {
        guard userNameRetryCount < 2 else {
            return
        }
        userNameRetryCount += 1
        
        // 🎯 修改：根据重试次数决定延迟时间
        // 第一次重试：延迟1/17秒；第二次重试：延迟0.5秒
        let delay: TimeInterval = userNameRetryCount == 1 ? 1.0 / 17.0 : 0.5
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if self.userNameFromServer == nil {
                self.loadUserNameFromServer()
            }
        }
    }
    
    // 从服务器加载邮箱 - 与用户名查询逻辑一致
    private func loadEmailFromServer() {
        let uid = record.userId
        let loginType = record.loginType ?? "guest"

        LeanCloudService.shared.fetchUserEmail(objectId: uid, loginType: loginType) { email, error in
            DispatchQueue.main.async {
                if let email = email, !email.isEmpty {
                    self.emailFromServer = email
                }
            }
        }
    }
    
    // 🎯 新增：实时查询 favorite 状态 - 与用户名显示一致：实时查询服务器
    private func loadFavoriteStatusFromServer() {
        guard let currentUserId = userManager.currentUser?.id else {
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
    
    // 🎯 新增：从 LoginRecord 表加载最近上线时间
    private func loadLastOnlineTime() {
        let uid = record.userId
        LeanCloudService.shared.fetchUserLastOnlineTime(userId: uid) { success, lastActive in
            if let date = lastActive {
                let formattedText = TimeAgoUtils.formatTimeAgo(from: date)
                
                DispatchQueue.main.async {
                    self.lastOnlineText = formattedText
                }
            }
        }
    }
    
    // 检查用户是否被当前用户喜欢
    private func isUserFavoritedByMe(userId: String) -> Bool {
        return isUserFavorited(userId)
    }
}