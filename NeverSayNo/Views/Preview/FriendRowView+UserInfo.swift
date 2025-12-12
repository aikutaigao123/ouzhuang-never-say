import SwiftUI

extension FriendRowView {
    // 获取好友信息（非当前用户）- 与用户头像界面一致：不使用全局缓存
    var friendInfo: (id: String, name: String, avatar: String, loginType: String) {
        let friendId: String
        let defaultLoginType: String
        
        if friend.user1Id == currentUserId {
            friendId = friend.user2Id
            defaultLoginType = friend.user2LoginType
        } else {
            friendId = friend.user1Id
            defaultLoginType = friend.user1LoginType
        }
        
        // 优先使用缓存的头像和用户名，如果没有则使用MatchRecord中的默认值
        let defaultAvatar = friend.user1Id == currentUserId ? friend.user2Avatar : friend.user1Avatar
        let defaultName = friend.user1Id == currentUserId ? friend.user2Name : friend.user1Name
        
        // 🔧 修复：头像优先级：UserAvatarRecord表 > MatchRecord中的头像 > 默认头像
        let cachedAvatar = avatarCache[friendId]
        let cachedName = userNameCache[friendId]
        
        // 🔍 注意：不再在 computed property 中修改 @State，避免 "Modifying state during view update" 警告
        // 如需追踪调用次数，应在其他地方处理
        
        let finalAvatar: String
        // 不使用全局缓存：优先使用MatchRecord中的默认值，其次使用本地缓存
        if !defaultAvatar.isEmpty && defaultAvatar != "😀" {
            // MatchRecord中有有效的头像，使用
            finalAvatar = defaultAvatar
        } else if let cached = cachedAvatar, !cached.isEmpty && cached != "😀" {
            // 缓存中有有效的头像
            finalAvatar = cached
        } else {
            // 使用默认头像 - 与用户头像界面一致：根据loginType决定 - Apple账号与内部账号使用相同的默认头像
            let loginType = userLoginType ?? defaultLoginType
            if loginType == "apple" {
                finalAvatar = "person.circle.fill"
            } else {
                finalAvatar = "person.circle" // 游客用户或未知类型使用person.circle（蓝色）
            }
        }
        
        // 登录类型不使用全局缓存：优先使用状态中解析到的，其次使用MatchRecord中的默认值
        let finalLoginType = userLoginType ?? defaultLoginType
        
        // 用户名不使用全局缓存：优先本地缓存，其次MatchRecord中的默认值
        let finalName: String
        if let cached = cachedName, !cached.isEmpty {
            finalName = cached
        } else {
            finalName = defaultName
        }
        
        return (friendId, finalName, finalAvatar, finalLoginType)
    }
    
    // 🔧 新增：异步查询最新用户名的方法
    func refreshUserNameFromServer(friendId: String) async {
        
        // 🔧 检查是否已经在 onAppear 中查询过
        if hasLoadedFromServer {
        }
        
        return await withCheckedContinuation { continuation in
            // 🎯 修改：使用 fetchUserNameByUserId，不依赖 loginType，直接从 UserNameRecord 表获取
            LeanCloudService.shared.fetchUserNameByUserId(objectId: friendId) { userName, error in
                DispatchQueue.main.async {
                    if error != nil {
                    } else if let userName = userName, !userName.isEmpty {
                        // 更新本地缓存
                        self.userNameCache[friendId] = userName
                        // 如果 onAppear 的查询还没完成，也更新 userNameFromServer
                        if self.userNameFromServer == nil {
                            self.userNameFromServer = userName
                        }
                    } else {
                    }
                    continuation.resume()
                }
            }
        }
    }
    
    // 🎯 新增：重试查询头像（最多重试2次）
    func retryLoadAvatarFromServer(friendId: String) {
        guard avatarRetryCount < 2 else {
            return
        }
        avatarRetryCount += 1
        
        // 🎯 修改：根据重试次数决定延迟时间
        // 第一次重试：延迟1/17秒；第二次重试：延迟0.5秒
        let delay: TimeInterval = avatarRetryCount == 1 ? 1.0 / 17.0 : 0.5
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // 检查 avatarFromServer 是否为 nil（查询失败的情况）
            if self.avatarFromServer == nil {
                LeanCloudService.shared.fetchUserAvatarByUserId(objectId: friendId) { avatar, error in
                    DispatchQueue.main.async {
                        if let avatar = avatar, !avatar.isEmpty {
                            self.avatarFromServer = avatar
                            self.avatarCache[friendId] = avatar
                            UserDefaultsManager.setCustomAvatar(userId: friendId, emoji: avatar)
                        } else {
                            // 🎯 修改：查询失败时，如果 avatarFromServer 仍为 nil 且未达到最大重试次数，触发第二次重试
                            if self.avatarFromServer == nil && self.avatarRetryCount < 2 {
                                self.retryLoadAvatarFromServer(friendId: friendId)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // 🎯 新增：重试查询用户名（最多重试2次）
    func retryLoadUserNameFromServer(friendId: String) {
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
                LeanCloudService.shared.fetchUserNameByUserId(objectId: friendId) { name, error in
                    DispatchQueue.main.async {
                        if let name = name, !name.isEmpty {
                            self.userNameFromServer = name
                            self.userNameCache[friendId] = name
                            UserDefaultsManager.setFriendUserName(userId: friendId, userName: name)
                        }
                    }
                }
            }
        }
    }
    
    // 获取显示的头像（优先使用实时查询结果）- 与用户头像界面一致
    var displayedAvatar: String {
        let friendId = friend.user1Id == currentUserId ? friend.user2Id : friend.user1Id
        
        // 第一优先级：从服务器实时查询的头像（与用户头像界面一致）
        if let serverAvatar = avatarFromServer, !serverAvatar.isEmpty {
            return serverAvatar
        }
        // 第二优先级：从 UserDefaults 获取头像（与用户头像界面一致：使用 displayAvatar，对应 UserDefaults）
        if let customAvatar = UserDefaultsManager.getCustomAvatar(userId: friendId), !customAvatar.isEmpty {
            
            // 🔍 检查 UserDefaults 与服务器数据是否一致
            if let serverAvatar = avatarFromServer, !serverAvatar.isEmpty {
                if serverAvatar != customAvatar {
                } else {
                }
            } else {
            }
            
            return customAvatar
        }
        // 第三优先级：friendInfo中的头像（可能来自本地缓存或MatchRecord）
        if !friendInfo.avatar.isEmpty && friendInfo.avatar != "😊" {
            if avatarCache[friendId] != nil {
            } else {
            }
            return friendInfo.avatar
        }
        // 返回空字符串表示使用默认头像
        return ""
    }
}

