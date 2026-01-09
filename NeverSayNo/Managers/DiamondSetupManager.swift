import SwiftUI

extension DiamondManager {
    // 为新用户初始化所有必要的本地存储
    func initializeNewUserData(userId: String, loginType: String) {
        
        // 1. 分配随机头像
        let randomEmoji = EmojiList.allEmojis.randomElement() ?? "🙂"
        UserDefaults.standard.set(randomEmoji, forKey: "custom_avatar_\(userId)")
        
        
        // 初始化拥有的头像列表到服务器（新用户只拥有初始随机头像）
        ownedAvatars = [randomEmoji]
        isServerConnected = true
        updateOwnedAvatarsToServer()
        
        
        // 2. 创建UserAvatarRecord到服务器
        LeanCloudService.shared.createUserAvatarRecord(objectId: userId, loginType: loginType, userAvatar: randomEmoji) { success in
            if success {
            } else {
            }
        }
        
        // 3. 初始化用户名记录到服务器
        if let userName = currentUserName {
            let userEmail = currentUserEmail ?? UserDefaultsManager.getCurrentUserEmail()
            LeanCloudService.shared.createUserNameRecord(objectId: userId, loginType: loginType, userName: userName, userEmail: userEmail) { success in
                if success {
                } else {
                }
            }
        } else {
        }
        
        // 4. 初始化钻石余额（新用户不赠送钻石）
        
        // 5. 初始化空的历史记录
        UserDefaults.standard.set([], forKey: "location_history_\(userId)")
        UserDefaults.standard.set([], forKey: "randomMatchHistory_\(loginType)_\(userId)")
        UserDefaults.standard.set([], forKey: "favorite_records_\(userId)")
        UserDefaults.standard.set([], forKey: "messages_\(userId)")
        UserDefaults.standard.set([], forKey: "report_records_\(userId)")
        
        
        // 6. 设置登录状态
        UserDefaults.standard.set(true, forKey: "is_logged_in")
        UserDefaults.standard.set(loginType, forKey: "loginType")
        UserDefaults.standard.set(userId, forKey: "current_user_id")
        
        
        // 7. 标记新用户首次登录时间
        let firstLoginTime = Date()
        UserDefaults.standard.set(firstLoginTime, forKey: "first_login_time_\(userId)")
        
    }
}
