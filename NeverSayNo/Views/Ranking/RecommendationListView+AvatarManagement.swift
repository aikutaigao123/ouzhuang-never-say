import SwiftUI

// MARK: - RecommendationListView Avatar Management Extension
extension RecommendationListView {
    
    // 刷新推荐榜中的头像和用户名 - 与用户头像界面一致：实时查询服务器
    func refreshRecommendationAvatars() {
        // 清理头像和用户名缓存，确保获取最新数据
        latestAvatars.removeAll()
        latestUserNames.removeAll()
        
        // 为推荐榜中的每个用户获取最新头像和用户名 - 与用户头像界面一致：实时查询服务器
        for item in recommendationData {
            let userId = item.userId  // 使用实际的用户ID
            let _ = item.loginType ?? "guest"
            
            // 🎯 修改：使用 fetchUserAvatarByUserId，不依赖 loginType，直接从 UserAvatarRecord 表获取
            LeanCloudService.shared.fetchUserAvatarByUserId(objectId: userId) { avatar, _ in
                DispatchQueue.main.async {
                    if let avatar = avatar, !avatar.isEmpty {
                        self.latestAvatars[item.id] = avatar
                        
                        // 🎯 新增：更新 UserDefaults 中的头像缓存（用于其他用户的信息）
                        let userDefaultsAvatar = UserDefaultsManager.getCustomAvatar(userId: userId)
                        if userDefaultsAvatar != avatar {
                            UserDefaultsManager.setCustomAvatar(userId: userId, emoji: avatar)
                        }
                    }
                }
            }
            
            // 🎯 修改：使用 fetchUserNameByUserId，不依赖 loginType，直接从 UserNameRecord 表获取
            LeanCloudService.shared.fetchUserNameByUserId(objectId: userId) { name, _ in
                DispatchQueue.main.async {
                    if let name = name, !name.isEmpty {
                        self.latestUserNames[item.id] = name
                        
                        // 🎯 新增：更新 UserDefaults 中的用户名缓存（用于其他用户的信息）
                        let userDefaultsUserName = UserDefaultsManager.getFriendUserName(userId: userId)
                        if userDefaultsUserName != name {
                            UserDefaultsManager.setFriendUserName(userId: userId, userName: name)
                        }
                    }
                }
            }
        }
    }
    
    // 刷新推荐榜专用的头像和用户名缓存 - 与用户头像界面一致：实时查询服务器
    func refreshRecommendationSpecificAvatars() {
        // 清理推荐榜专用的头像和用户名缓存，确保获取最新数据
        recommendationAvatarCache.removeAll()
        recommendationUserNameCache.removeAll()
        
        // 为推荐榜中的每个用户获取最新头像和用户名 - 与用户头像界面一致：实时查询服务器
        for item in recommendationData {
            let userId = item.userId  // 使用实际的用户ID
            let _ = item.loginType ?? "guest"
            
            // 🎯 修改：使用 fetchUserAvatarByUserId，不依赖 loginType，直接从 UserAvatarRecord 表获取
            LeanCloudService.shared.fetchUserAvatarByUserId(objectId: userId) { avatar, _ in
                DispatchQueue.main.async {
                    if let avatar = avatar, !avatar.isEmpty {
                        self.recommendationAvatarCache[item.id] = avatar
                        
                        // 🎯 新增：更新 UserDefaults 中的头像缓存（用于其他用户的信息）
                        let userDefaultsAvatar = UserDefaultsManager.getCustomAvatar(userId: userId)
                        if userDefaultsAvatar != avatar {
                            UserDefaultsManager.setCustomAvatar(userId: userId, emoji: avatar)
                        }
                    }
                }
            }
            
            // 🎯 修改：使用 fetchUserNameByUserId，不依赖 loginType，直接从 UserNameRecord 表获取
            LeanCloudService.shared.fetchUserNameByUserId(objectId: userId) { name, _ in
                DispatchQueue.main.async {
                    if let name = name, !name.isEmpty {
                        self.recommendationUserNameCache[item.id] = name
                        
                        // 🎯 新增：更新 UserDefaults 中的用户名缓存（用于其他用户的信息）
                        let userDefaultsUserName = UserDefaultsManager.getFriendUserName(userId: userId)
                        if userDefaultsUserName != name {
                            UserDefaultsManager.setFriendUserName(userId: userId, userName: name)
                        }
                    }
                }
            }
        }
    }
}

