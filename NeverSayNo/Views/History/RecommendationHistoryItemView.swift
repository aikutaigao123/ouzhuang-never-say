import SwiftUI
import CoreLocation

// 历史记录推荐卡片视图（参考推荐榜设计）
struct RecommendationHistoryItemView: View {
    let historyItem: RandomMatchHistory
    let cachedDistance: Double? // 保留：作为回退值，如果实时计算失败则使用
    let isHighlighted: Bool
    let locationManager: LocationManager? // 位置管理器，用于实时距离计算
    let onHistoryItemTap: (RandomMatchHistory) -> Void
    let onDeleteHistoryItem: (RandomMatchHistory) -> Void
    
    @State private var avatarFromServer: String? = nil
    @State private var avatarRetryCount: Int = 0
    
    // 头像显示优先级
    private var displayAvatar: String {
        if let serverAvatar = avatarFromServer, !serverAvatar.isEmpty {
            return serverAvatar
        }
        if let customAvatar = UserDefaultsManager.getCustomAvatar(userId: historyItem.record.userId), !customAvatar.isEmpty {
            return customAvatar
        }
        let loginType = historyItem.record.loginType ?? "guest"
        if loginType == "apple" {
            return "person.circle.fill"
        } else {
            return "person.circle"
        }
    }
    
    // 从服务器加载头像
    private func loadAvatarFromServer() {
        let uid = historyItem.record.userId
        LeanCloudService.shared.fetchUserAvatarByUserId(objectId: uid) { avatar, _ in
            DispatchQueue.main.async {
                if let avatar = avatar, !avatar.isEmpty {
                    let wasShowingDefault = self.isShowingDefaultAvatar
                    self.avatarFromServer = avatar
                    let userDefaultsAvatar = UserDefaultsManager.getCustomAvatar(userId: uid)
                    if userDefaultsAvatar != avatar {
                        UserDefaultsManager.setCustomAvatar(userId: uid, emoji: avatar)
                    }
                    if wasShowingDefault {
                    }
                } else {
                    if self.avatarFromServer == nil && self.avatarRetryCount < 2 {
                        self.retryLoadAvatarFromServer()
                    }
                }
            }
        }
    }
    
    private var isShowingDefaultAvatar: Bool {
        let avatar = displayAvatar
        return avatar == "person.circle.fill" || avatar == "person.circle"
    }
    
    // 🎯 新增：实时计算距离（优先使用实时计算，失败则回退到缓存值）
    private var currentDistance: Double? {
        guard let locationManager = locationManager,
              let currentLocation = locationManager.location else {
            // 如果无法实时计算，回退到缓存值
            return cachedDistance
        }
        
        // 使用历史记录中的方法计算实时距离
        return historyItem.calculateCurrentDistance(from: currentLocation)
    }
    
    private func retryLoadAvatarFromServer() {
        guard avatarRetryCount < 2 else {
            return
        }
        avatarRetryCount += 1
        let delay: TimeInterval = avatarRetryCount == 1 ? 1.0 / 17.0 : 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if self.isShowingDefaultAvatar {
                self.loadAvatarFromServer()
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 用户头像
            Group {
                let isSFSymbol = UserAvatarUtils.isSFSymbol(displayAvatar)
                if isSFSymbol {
                    if displayAvatar == "applelogo" || displayAvatar == "apple_logo" {
                        Image(systemName: "applelogo")
                            .font(.system(size: 40))
                            .foregroundColor(.black)
                    } else {
                        Image(systemName: displayAvatar)
                            .font(.system(size: 40))
                            .foregroundColor(displayAvatar == "person.circle.fill" ? .purple : .blue)
                    }
                } else {
                    Text(displayAvatar)
                        .font(.system(size: 40))
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .background(Circle().fill(Color.gray.opacity(0.1)).frame(width: 50, height: 50))
            .onAppear {
                loadAvatarFromServer()
            }
            .task {
                try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 / 7.0))
                if isShowingDefaultAvatar && avatarRetryCount < 2 {
                    retryLoadAvatarFromServer()
                }
            }
            
            // 用户信息（参考推荐榜）
            VStack(alignment: .leading, spacing: 6) {
                // 地名显示 - 作为主要标题
                if let placeName = historyItem.record.placeName, !placeName.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title3)
                            .foregroundColor(.green)
                        ColorfulPlaceNameText(
                            placeName: placeName,
                            userId: historyItem.record.userId,
                            loginType: historyItem.record.loginType
                        )
                    }
                }
                
                // 推荐理由 - 作为主要内容
                if let reason = historyItem.record.reason, !reason.isEmpty {
                    Text("「\(reason)」")
                        .font(.body)
                        .foregroundColor(.black)
                        .lineLimit(3)
                }
                
                // 🎯 修改：距离信息 - 实时计算距离（与匹配卡片一致）
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(currentDistance != nil ? DistanceUtils.formatDistance(currentDistance!) : "暂无位置")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                
                // 🐛 新增：显示匹配时间
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text(TimeAgoUtils.formatTimeAgo(from: historyItem.matchTime))
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(isHighlighted ? Color.green.opacity(0.1) : Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHighlighted ? Color.green : Color.clear, lineWidth: 2)
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
        .onTapGesture {
            onHistoryItemTap(historyItem)
        }
    }
}

