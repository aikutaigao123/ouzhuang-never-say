//
//  FriendMatchResultCard.swift
//  NeverSayNo
//
//  Created by Die chen on 2025/7/1.
//

import SwiftUI

struct FriendMatchResultCard: View {
    let record: LocationRecord
    let latestAvatars: [String: String]
    let latestUserNames: [String: String]
    @State private var avatarFromServer: String? = nil
    @State private var userNameFromServer: String? = nil
    // 🎯 新增：LoginRecord 表最近上线时间文案
    @State private var lastOnlineText: String? = nil
    @State private var avatarRetryCount: Int = 0 // 🎯 新增：头像重试次数（最多重试2次）
    @State private var userNameRetryCount: Int = 0 // 🎯 新增：用户名重试次数（最多重试2次）
    @State private var lastOnlineRetryCount: Int = 0 // 🎯 新增：上线时间重试次数（最多重试2次，与用户头像一致）
    
    // 与用户头像界面一致的头像显示优先级
    private var displayAvatar: String {
        // 第一优先级：从服务器实时查询的头像（与用户头像界面一致）
        if let serverAvatar = avatarFromServer, !serverAvatar.isEmpty {
            return serverAvatar
        }
        // 第二优先级：从 UserDefaults 获取头像（与用户头像界面一致：使用 displayAvatar，对应 UserDefaults）
        if let customAvatar = UserDefaultsManager.getCustomAvatar(userId: record.userId), !customAvatar.isEmpty {
            return customAvatar
        }
        // 第三优先级：本地缓存
        if let latest = latestAvatars[record.userId], !latest.isEmpty {
            return latest
        }
        // 第四优先级：使用记录中的头像
        if let recordAvatar = record.userAvatar, !recordAvatar.isEmpty {
            return recordAvatar
        }
        // 第五优先级：默认头像 - 与用户头像界面一致 - Apple账号与内部账号使用相同的默认头像
        let loginType = record.loginType ?? "guest"
        if loginType == "apple" {
            return "person.circle.fill"
        } else {
            return "person.circle" // 游客用户使用person.circle（蓝色）
        }
    }
    
    // 从服务器加载头像 - 🎯 统一从 UserAvatarRecord 表获取
    private func loadAvatarFromServer() {
        let uid = record.userId
        
        // 🎯 修改：使用 fetchUserAvatarByUserId，不依赖 loginType，直接从 UserAvatarRecord 表获取
        LeanCloudService.shared.fetchUserAvatarByUserId(objectId: uid) { avatar, _ in
            DispatchQueue.main.async {
                if let avatar = avatar, !avatar.isEmpty {
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
    
    var body: some View {
        VStack(spacing: 8) {
            // 用户信息
            HStack(spacing: 12) {
                // 头像 - 与用户头像界面一致：支持SF Symbol和emoji/文本
                Group {
                    if displayAvatar == "applelogo" || displayAvatar == "apple_logo" {
                        Image(systemName: "applelogo")
                            .font(.system(size: 32))
                            .foregroundColor(.black)
                    } else if UserAvatarUtils.isSFSymbol(displayAvatar) {
                        // 🔧 修复：检查是否是 SF Symbol，如果是则显示图标而不是文字
                        Image(systemName: displayAvatar)
                            .font(.system(size: 32))
                            .foregroundColor(displayAvatar == "person.circle.fill" ? .purple : .blue)
                    } else {
                        Text(displayAvatar)
                            .font(.system(size: 32))
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
                .background(Circle().fill(Color.gray.opacity(0.1)).frame(width: 60, height: 60))
                
                // 用户名和类型
                VStack(alignment: .leading, spacing: 4) {
                    ColorfulUserNameText(
                        userName: displayUserName,
                        userId: record.userId,
                        loginType: record.loginType,
                        font: .headline,
                        fontWeight: .bold,
                        lineLimit: 1,
                        truncationMode: .tail
                    )
                    
                    Text(record.loginType == "apple" ? "Apple用户" : "内部用户")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                
                Spacer()
                
                // 匹配状态
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 20))
            }
            
            // 底部信息
            HStack {
                Text("匹配时间: \(displayMatchTimeText)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Spacer()
                
                Text("位置: \(String(format: "%.2f", record.latitude)), \(String(format: "%.2f", record.longitude))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .onAppear {
            // 与用户头像界面一致：在onAppear时实时查询服务器头像和用户名
            loadAvatarFromServer()
            loadUserNameFromServer()
            loadLastOnlineTime()
        }
        .task {
            // 🎯 新增：检查查询是否失败，如果失败则重试
            try? await Task.sleep(nanoseconds: UInt64(1_000_000_000.0 / 7.0)) // 1/7秒
            // 检查是否查询失败且未达到最大重试次数
            let shouldRetryAvatar = avatarFromServer == nil && avatarRetryCount < 2
            let shouldRetryUserName = userNameFromServer == nil && userNameRetryCount < 2
            let shouldRetryLastOnline = lastOnlineText == nil && lastOnlineRetryCount < 2
            if shouldRetryAvatar {
                retryLoadAvatarFromServer()
            }
            if shouldRetryUserName {
                retryLoadUserNameFromServer()
            }
            if shouldRetryLastOnline {
                retryLoadLastOnlineTime()
            }
        }
    }
    
    // 与用户头像界面一致的用户名显示优先级
    private var displayUserName: String {
        let uid = record.userId
        // 第一优先级：从服务器实时查询的用户名
        if let serverName = userNameFromServer, !serverName.isEmpty {
            return serverName
        }
        // 第二优先级：本地缓存
        if let latest = latestUserNames[uid], !latest.isEmpty {
            return latest
        }
        // 第三优先级：使用记录中的用户名
        return record.userName ?? "未知用户"
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
    
    // 🎯 修改：用于展示的匹配时间文案（LoginRecord 表为唯一数据来源）
    private var displayMatchTimeText: String {
        // 🎯 修改：只使用 LoginRecord 表数据，无回退逻辑
        if let text = lastOnlineText, !text.isEmpty {
            return text
        }
        // 如果 LoginRecord 表没有数据，返回空字符串
        return ""
    }
    
    // 🎯 修改：从 LoginRecord 表加载最近上线时间（唯一数据来源）
    private func loadLastOnlineTime() {
        let uid = record.userId
        LeanCloudService.shared.fetchUserLastOnlineTime(userId: uid) { success, lastActive in
            DispatchQueue.main.async {
                if success, let date = lastActive {
                    self.lastOnlineText = TimeAgoUtils.formatTimeAgo(from: date)
                    // 🎯 新增：查询成功，重置重试次数
                    self.lastOnlineRetryCount = 0
                } else {
                    // 🎯 修改：LoginRecord 表为唯一数据来源，API 失败时不使用回退逻辑
                    self.lastOnlineText = nil
                    // 🎯 新增：查询失败时，如果 lastOnlineText 仍为 nil 且未达到最大重试次数，触发重试
                    if self.lastOnlineText == nil && self.lastOnlineRetryCount < 2 {
                        self.retryLoadLastOnlineTime()
                    }
                }
            }
        }
    }
    
    // 🎯 新增：重试查询上线时间（最多重试2次，与用户头像一致）
    private func retryLoadLastOnlineTime() {
        guard lastOnlineRetryCount < 2 else {
            return
        }
        lastOnlineRetryCount += 1
        
        // 🎯 修改：根据重试次数决定延迟时间（与用户头像一致）
        // 第一次重试：延迟1/17秒；第二次重试：延迟0.5秒
        let delay: TimeInterval = lastOnlineRetryCount == 1 ? 1.0 / 17.0 : 0.5
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if self.lastOnlineText == nil {
                self.loadLastOnlineTime()
            }
        }
    }
}
