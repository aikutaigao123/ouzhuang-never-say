import SwiftUI

extension MessageView {
    // MARK: - Cache Operations Methods
    
    // 更新全局用户名缓存
    private func updateGlobalUserNameCache() {
        
        LeanCloudService.shared.fetchAllUserNameRecords { records, error in
            if error != nil {
            } else if let records = records {
                
                // 统计不同登录类型的用户数量
                var loginTypeCount: [String: Int] = [:]
                for record in records {
                    let loginType = record["loginType"] as? String ?? "未知"
                    loginTypeCount[loginType, default: 0] += 1
                }
                
                for (_, _) in loginTypeCount {
                }
                
                // 清理消息界面专用缓存，强制使用全局缓存
                self.existingUserNameCache.removeAll()
                
                // 刷新消息列表以使用新的缓存
                DispatchQueue.main.async {
                    self.loadMessages()
                }
            } else {
            }
        }
    }
    
    // 从缓存加载好友列表
    private func loadFriendsFromCache() {
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        // 使用匹配成功判断逻辑：基于favoriteRecords和usersWhoLikedMe
        // 获取所有双向喜欢的用户对
        var matchedUsers: [String] = []
        
        // 遍历当前用户喜欢的所有用户
        for favoriteRecord in favoriteRecords {
            let targetUserId = favoriteRecord.favoriteUserId
            
            // 首先检查是否为自己，如果是则跳过
            if targetUserId == currentUser.id {
                continue
            }
            
            // 检查是否双向喜欢：当前用户喜欢目标用户 && 目标用户喜欢当前用户
            let currentUserLikesTarget = isUserFavorited(targetUserId)
            let targetLikesCurrentUser = isUserFavoritedByMe(targetUserId)
            
            if currentUserLikesTarget && targetLikesCurrentUser {
                // 避免重复添加同一个用户
                if !matchedUsers.contains(targetUserId) {
                    matchedUsers.append(targetUserId)
                }
            }
        }
        
        // 为每个匹配的用户创建MatchRecord对象
        var friendsList: [MatchRecord] = []
        
        for userId in matchedUsers {
            // 创建MatchRecord对象
            let friendRecord = MatchRecord(
                user1Id: currentUser.id,
                user2Id: userId,
                user1Name: currentUser.fullName,
                user2Name: "", // 将从缓存或服务器获取
                user1Avatar: "", // 将从缓存或服务器获取
                user2Avatar: "", // 将从缓存或服务器获取
                user1LoginType: currentUser.loginType == .apple ? "apple" : "guest",
                user2LoginType: "", // 将从缓存或服务器获取
                matchTime: Date(),
                matchLocation: nil,
                deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "",
                timezone: TimeZone.current.identifier,
                deviceTime: Date()
            )
            friendsList.append(friendRecord)
        }
        
        // 立即显示缓存的好友列表
        self.existingFriends = friendsList
        
        // 异步更新用户信息（头像、用户名、登录类型）
        batchFetchFriendData(friends: friendsList)
    }
    
    // 从全局缓存恢复头像和用户名数据到MessageView内部缓存
    internal func restoreCacheFromGlobal() {
        // 收集所有需要恢复缓存的用户ID
        var userIds = Set<String>()
        
        // 从消息中收集用户ID
        for message in existingMessages {
            userIds.insert(message.senderId)
        }
        
        // 从好友列表中收集用户ID
        for friend in existingFriends {
            let friendId = friend.user1Id == userManager.currentUser?.id ? friend.user2Id : friend.user1Id
            userIds.insert(friendId)
        }
        
        // 从拍一拍消息中收集用户ID
        for patMessage in existingPatMessages {
            userIds.insert(patMessage.senderId)
        }
        
        // 与用户头像界面一致：不再从全局缓存恢复，改为实时查询
        // 头像和用户名将在各个组件onAppear时实时查询
        
    }
    
    // 过滤并更新用户名缓存 - 与用户头像界面一致：实时查询服务器
    private func filterAndUpdateUserNameCache(neededUserIds: Set<String>) {
        // 与用户头像界面一致：不再从全局缓存获取，改为实时查询
        // 🎯 修改：使用 fetchUserNameByUserId，不依赖 loginType，直接从 UserNameRecord 表获取
        for userId in neededUserIds {
            LeanCloudService.shared.fetchUserNameByUserId(objectId: userId) { name, _ in
                DispatchQueue.main.async {
                    if let name = name, !name.isEmpty {
                        self.existingUserNameCache[userId] = name
                    }
                }
            }
        }
    }
    
    // 过滤并更新用户头像缓存 - 与用户头像界面一致：实时查询服务器
    private func filterAndUpdateUserAvatarCache(neededUserIds: Set<String>) {
        // 🎯 修改：使用 fetchUserAvatarByUserId，不依赖 loginType，直接从 UserAvatarRecord 表获取
        for userId in neededUserIds {
            LeanCloudService.shared.fetchUserAvatarByUserId(objectId: userId) { avatar, _ in
                DispatchQueue.main.async {
                    if let avatar = avatar, !avatar.isEmpty {
                        self.existingAvatarCache[userId] = avatar
                    }
                }
            }
        }
    }
}

