import SwiftUI

// 推荐榜项目视图
struct RecommendationItemView: View {
    let item: RecommendationItem
    let cachedDistance: Double?
    let isHighlighted: Bool
    @Binding var avatarCache: [String: String] // 保留：用于批量刷新（虽然单个查询不再使用）
    @Binding var userNameCache: [String: String] // 保留：用于批量刷新（虽然单个查询不再使用）
    @State private var avatarFromServer: String? = nil
    @State private var userNameFromServer: String? = nil
    @State private var avatarRetryCount: Int = 0 // 🎯 修改：记录头像重试次数（最多重试2次）
    
    // 🎯 头像显示优先级 - 只从 UserAvatarRecord 表获取，不从 item 中读取
    private var displayAvatar: String {
        // 第一优先级：从服务器实时查询的头像（从 UserAvatarRecord 表获取）
        if let serverAvatar = avatarFromServer, !serverAvatar.isEmpty {
            return serverAvatar
        }
        // 第二优先级：从 UserDefaults 获取头像（缓存的头像）
        if let customAvatar = UserDefaultsManager.getCustomAvatar(userId: item.userId), !customAvatar.isEmpty {
            return customAvatar
        }
        // 第三优先级：使用默认头像（根据 loginType）
        // 🎯 不再从 item.userAvatar 中读取头像
        let loginType = item.loginType ?? "guest"
        if loginType == "apple" {
            return "person.circle.fill"
        } else {
            return "person.circle"
        }
    }
    
    // 从服务器加载头像 - 🎯 统一从 UserAvatarRecord 表获取（与排行榜一致：直接查询服务器）
    private func loadAvatarFromServer() {
        let uid = item.userId
        
        // 🎯 修改：与排行榜一致，直接查询服务器，不使用缓存机制
        LeanCloudService.shared.fetchUserAvatarByUserId(objectId: uid) { avatar, _ in
            DispatchQueue.main.async {
                if let avatar = avatar, !avatar.isEmpty {
                    // 🎯 新增：检查是否更新了UI显示
                    let wasShowingDefault = self.isShowingDefaultAvatar
                    self.avatarFromServer = avatar
                    
                    // 🎯 新增：更新 UserDefaults 中的头像缓存（用于其他用户的信息）
                    let userDefaultsAvatar = UserDefaultsManager.getCustomAvatar(userId: uid)
                    if userDefaultsAvatar != avatar {
                        UserDefaultsManager.setCustomAvatar(userId: uid, emoji: avatar)
                    }
                    
                    // 如果之前显示默认头像，现在获取到了新头像，UI会自动更新
                    if wasShowingDefault {
                        // 头像已更新，UI会自动刷新
                    }
                } else {
                    // 🎯 修改：查询失败时，如果 avatarFromServer 仍为 nil 且未达到最大重试次数，触发第二次重试
                    if self.avatarFromServer == nil && self.avatarRetryCount < 2 {
                        self.retryLoadAvatarFromServer()
                    }
                }
            }
        }
    }
    
    // 🎯 新增：检查是否显示默认头像
    private var isShowingDefaultAvatar: Bool {
        let avatar = displayAvatar
        return avatar == "person.circle.fill" || avatar == "person.circle"
    }
    
    // 🎯 修改：重试查询头像（最多重试2次）
    private func retryLoadAvatarFromServer() {
        guard avatarRetryCount < 2 else {
            return
        }
        avatarRetryCount += 1
        
        // 🎯 修改：根据重试次数决定延迟时间
        // 第一次重试：延迟1/17秒；第二次重试：延迟0.5秒
        let delay: TimeInterval = avatarRetryCount == 1 ? 1.0 / 17.0 : 0.5
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // 检查是否仍然显示默认头像，如果是则重试
            if self.isShowingDefaultAvatar {
                self.loadAvatarFromServer()
            }
        }
    }
    
    // 从服务器加载用户名 - 🎯 统一从 UserNameRecord 表获取（与排行榜一致：直接查询服务器）
    private func loadUserNameFromServer() {
        let uid = item.userId
        
        // 🎯 修改：与排行榜一致，直接查询服务器，不使用缓存机制
        LeanCloudService.shared.fetchUserNameByUserId(objectId: uid) { name, _ in
            DispatchQueue.main.async {
                if let name = name, !name.isEmpty {
                    self.userNameFromServer = name
                    
                    // 🎯 新增：更新 UserDefaults 中的用户名缓存（用于其他用户的信息）
                    let userDefaultsUserName = UserDefaultsManager.getFriendUserName(userId: uid)
                    if userDefaultsUserName != name {
                        UserDefaultsManager.setFriendUserName(userId: uid, userName: name)
                    }
                }
            }
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 🎯 删除：排名显示（前三名的SF Symbol图标和数字排名）
            
            // 用户头像 - 与用户头像界面一致：支持SF Symbol和emoji/文本
            Group {
                let isSFSymbol = UserAvatarUtils.isSFSymbol(displayAvatar)
                
                // 🔍 添加详细的调试信息
                
                if isSFSymbol {
                    if displayAvatar == "applelogo" || displayAvatar == "apple_logo" {
                        Image(systemName: "applelogo")
                            .font(.system(size: 40))
                            .foregroundColor(.black)
                            .onAppear {
                            }
                    } else {
                        // 🔧 修复：统一处理所有 SF Symbol
                        Image(systemName: displayAvatar)
                            .font(.system(size: 40))
                            .foregroundColor(displayAvatar == "person.circle.fill" ? .purple : .blue)
                            .onAppear {
                            }
                    }
                } else {
                    Text(displayAvatar)
                        .font(.system(size: 40))
                        .fixedSize(horizontal: true, vertical: false)
                        .onAppear {
                        }
                }
            }
            .background(Circle().fill(Color.gray.opacity(0.1)).frame(width: 50, height: 50))
            .onAppear {
                // 与用户头像界面一致：在onAppear时实时查询服务器头像和用户名
                loadAvatarFromServer()
                loadUserNameFromServer()
            }
            .task {
                // 🎯 修改：当显示默认头像时，延迟后自动重试一次查询
                // 🎯 修改：等待初始查询完成（1/7秒后），如果仍然显示默认头像，则重试
                try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 / 7.0)) // 1/7秒
                // 🎯 修改：检查是否仍然显示默认头像且未达到最大重试次数
                if isShowingDefaultAvatar && avatarRetryCount < 2 {
                    retryLoadAvatarFromServer()
                }
            }
            
            // 用户信息
            VStack(alignment: .leading, spacing: 6) {
                // 地名显示 - 作为主要标题（根据推荐者的 UserNameRecord 决定是否显示彩色）
                if !item.placeName.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title3)
                            .foregroundColor(.green)
                        // 🎯 修改：根据推荐者的 colorfulModeEnabled 决定是否显示彩色
                        // 如果启用了彩色模式，显示彩色渐变；否则显示绿色
                        ColorfulPlaceNameText(
                            placeName: item.placeName,
                            userId: item.userId,
                            loginType: item.loginType
                        )
                    }
                }
                
                // 推荐理由 - 作为主要内容
                Text("「\(item.reason)」")
                    .font(.body)
                    .foregroundColor(.black)
                    .lineLimit(3)
                
                // 距离信息 - 使用与排行榜相同的显示方式
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(cachedDistance != nil ? DistanceUtils.formatDistance(cachedDistance!) : "暂无位置")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            
            Spacer()
            
            // 点赞数量
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(item.likeCount)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                
                Text("点赞数")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
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
    }

}

