import SwiftUI

// 位置历史记录视图
struct LocationHistoryView: View {
    let locations: [LocationRecord]
    let isLoading: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var userNameCache: [String: String] = [:] // 用户名缓存
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack {
                        ProgressView()
                        Text("加载中...")
                            .padding()
                    }
                } else if locations.isEmpty {
                    VStack {
                        Image(systemName: "location.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("暂无位置记录")
                            .font(.title2)
                            .foregroundColor(.gray)
                        Text("发送位置后这里会显示记录")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding()
                } else {
                    List(Array(locations.enumerated().reversed()), id: \.element.id) { index, location in
                        LocationHistoryRowView(
                            index: index,
                            location: location,
                            userNameCache: $userNameCache
                        )
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("位置记录 (\(locations.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// 位置历史记录行视图
struct LocationHistoryRowView: View {
    let index: Int
    let location: LocationRecord
    @Binding var userNameCache: [String: String]
    @State private var userNameFromServer: String? = nil
    @State private var userNameRetryCount: Int = 0 // 🎯 新增：用户名重试次数（最多重试2次）
    
    // 优先使用 UserNameRecord 表中的用户名，否则使用 location.userName
    private var displayedUserName: String {
        if let serverName = userNameFromServer, !serverName.isEmpty {
            return serverName
        }
        if let cachedName = userNameCache[location.userId], !cachedName.isEmpty {
            return cachedName
        }
        return location.userName ?? "未知用户"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("记录 #\(index + 1)")
                    .font(.headline)
                    .foregroundColor(.blue)
                Spacer()
                Text(TimestampUtils.formatDate(location.timestamp, tzID: location.timezone))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("📍 纬度: \(String(format: "%.6f", location.latitude))")
                        .font(.caption)
                    Text("📍 经度: \(String(format: "%.6f", location.longitude))")
                        .font(.caption)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("👤")
                            .font(.caption)
                            .foregroundColor(.blue)
                        ColorfulUserNameText(
                            userName: displayedUserName,
                            userId: location.userId,
                            loginType: location.loginType,
                            font: .caption,
                            fontWeight: .regular,
                            lineLimit: 1,
                            truncationMode: .tail
                        )
                        .foregroundColor(.blue)
                    }
                        .onAppear {
                        // 与用户头像界面一致：在onAppear时实时查询服务器用户名
                        loadUserNameFromServer()
                    }
                    .task {
                        // 🎯 新增：检查查询是否失败，如果失败则重试
                        try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 / 7.0)) // 1/7秒
                        // 检查是否查询失败（userNameFromServer 为 nil）且未达到最大重试次数
                        let shouldRetry = userNameFromServer == nil && userNameRetryCount < 2
                        if shouldRetry {
                            retryLoadUserNameFromServer()
                        }
                    }
                    Text("🔐 \(location.loginType ?? "guest")")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    Text("📱 \(String(location.deviceId.prefix(8)))")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    // 从服务器加载用户名 - 🎯 统一从 UserNameRecord 表获取
    private func loadUserNameFromServer() {
        // 如果缓存中已有数据，直接使用
        if let cachedName = userNameCache[location.userId], !cachedName.isEmpty {
            self.userNameFromServer = cachedName
            return
        }
        
        // 如果已经查询过，不再重复查询
        if userNameFromServer != nil {
            return
        }
        
        // 🎯 修改：使用 fetchUserNameByUserId，不依赖 loginType，直接从 UserNameRecord 表获取
        LeanCloudService.shared.fetchUserNameByUserId(objectId: location.userId) { name, _ in
            DispatchQueue.main.async {
                if let name = name, !name.isEmpty {
                    self.userNameFromServer = name
                    self.userNameCache[location.userId] = name
                    
                    // 🎯 新增：更新 UserDefaults 中的用户名缓存（用于其他用户的信息）
                    let userDefaultsUserName = UserDefaultsManager.getFriendUserName(userId: location.userId)
                    if userDefaultsUserName != name {
                        UserDefaultsManager.setFriendUserName(userId: location.userId, userName: name)
                    }
                }
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
            // 检查 userNameFromServer 是否为 nil（查询失败的情况）
            if self.userNameFromServer == nil {
                self.loadUserNameFromServer()
            }
        }
    }
}
