import SwiftUI

// 本地黑名单查看界面
struct LocalBlacklistView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var blacklistedUserIds: [String] = []
    @State private var userInfoMap: [String: (userName: String, avatar: String, loginType: String)] = [:]
    @State private var isLoading = true
    @State private var showDeleteAlert = false
    @State private var userToRemove: String? = nil
    @State private var userNameToRemove: String? = nil
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack {
                        ProgressView("加载中...")
                            .padding()
                    }
                } else if blacklistedUserIds.isEmpty {
                    // 空状态
                    VStack(spacing: 20) {
                        Image(systemName: "hand.raised.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text("黑名单为空")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                        
                        Text("您还没有拉黑任何用户")
                            .font(.body)
                            .foregroundColor(.gray.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // 黑名单列表
                    List {
                        ForEach(blacklistedUserIds, id: \.self) { userId in
                            if let userInfo = userInfoMap[userId] {
                                BlacklistUserRow(
                                    userId: userId,
                                    userName: userInfo.userName,
                                    avatar: userInfo.avatar,
                                    loginType: userInfo.loginType,
                                    onRemove: {
                                        userNameToRemove = userInfo.userName
                                        userToRemove = userId
                                        showDeleteAlert = true
                                    }
                                )
                            } else {
                                // 加载中的用户信息
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("加载中...")
                                        .font(.body)
                                        .foregroundColor(.gray)
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("黑名单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadBlacklist()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("LocalBlacklistUpdated"))) { _ in
                // 监听黑名单更新通知（延迟执行，避免阻塞主线程）
                // 注意：如果界面正在关闭，不需要重新加载
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    loadBlacklist()
                }
            }
            .alert("移除黑名单", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) {
                    userToRemove = nil
                    userNameToRemove = nil
                }
                Button("确认", role: .destructive) {
                    if let userId = userToRemove {
                        // 移除黑名单（内部已发送LocalBlacklistUpdated通知，无需重复发送）
                        LocalBlacklistManager.shared.removeUserFromLocalBlacklist(userId)
                        
                        // 清理状态
                        userToRemove = nil
                        userNameToRemove = nil
                        
                        // 重新加载黑名单列表（界面保持打开）
                        loadBlacklist()
                        
                        // 延迟发送RefreshMatchStatus通知，避免阻塞UI
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            NotificationCenter.default.post(name: NSNotification.Name("RefreshMatchStatus"), object: nil)
                        }
                    } else {
                        userToRemove = nil
                        userNameToRemove = nil
                    }
                }
            } message: {
                if let userName = userNameToRemove {
                    Text("确定要将 \(userName) 从黑名单中移除吗？移除后，该用户可能会重新出现在您的匹配结果中。")
                } else {
                    Text("确定要将此用户从黑名单中移除吗？")
                }
            }
        }
    }
    
    // 加载黑名单
    private func loadBlacklist() {
        isLoading = true
        
        // 获取所有黑名单用户ID
        let allBlacklistedIds = LocalBlacklistManager.shared.getAllLocalBlacklistedUserIds()
        blacklistedUserIds = Array(allBlacklistedIds).sorted()
        
        // 清空用户信息映射
        userInfoMap.removeAll()
        
        // 如果没有黑名单用户，直接完成加载
        if blacklistedUserIds.isEmpty {
            isLoading = false
            return
        }
        
        // 批量加载用户信息
        var loadedCount = 0
        let totalCount = blacklistedUserIds.count
        
        for userId in blacklistedUserIds {
            // 加载用户名
            LeanCloudService.shared.fetchUserNameByUserId(objectId: userId) { userName, _ in
                DispatchQueue.main.async {
                    let finalUserName = userName ?? "未知用户"
                    
                    // 加载头像
                    LeanCloudService.shared.fetchUserAvatarByUserId(objectId: userId) { avatar, _ in
                        DispatchQueue.main.async {
                            let finalAvatar = avatar ?? "🙂"
                            
                            // 加载登录类型
                            LeanCloudService.shared.fetchUserNameAndLoginType(objectId: userId) { _, loginType, _ in
                                DispatchQueue.main.async {
                                    let finalLoginType = loginType ?? "guest"
                                    
                                    // 更新用户信息映射
                                    userInfoMap[userId] = (
                                        userName: finalUserName,
                                        avatar: finalAvatar,
                                        loginType: finalLoginType
                                    )
                                    
                                    loadedCount += 1
                                    if loadedCount >= totalCount {
                                        isLoading = false
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // 设置超时，避免一直等待
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            if isLoading {
                isLoading = false
            }
        }
    }
}

// 黑名单用户行视图
struct BlacklistUserRow: View {
    let userId: String
    let userName: String
    let avatar: String
    let loginType: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 头像
            if UserAvatarUtils.isSFSymbol(avatar) {
                if avatar == "applelogo" || avatar == "apple_logo" {
                    Image(systemName: "applelogo")
                        .font(.system(size: 40))
                        .foregroundColor(.black)
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(Color.gray.opacity(0.1)))
                } else {
                    Image(systemName: avatar)
                        .font(.system(size: 40))
                        .foregroundColor(avatar == "person.circle.fill" ? .purple : .blue)
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(Color.gray.opacity(0.1)))
                }
            } else {
                Text(avatar)
                    .font(.system(size: 40))
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(Color.gray.opacity(0.1)))
            }
            
            // 用户信息
            VStack(alignment: .leading, spacing: 4) {
                ColorfulUserNameText(
                    userName: userName,
                    userId: userId,
                    loginType: loginType,
                    font: .headline,
                    fontWeight: .semibold,
                    lineLimit: 1,
                    truncationMode: .tail
                )
                
                Text(UserTypeUtils.getUserTypeText(loginType))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // 移除按钮
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 24))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 8)
    }
}


