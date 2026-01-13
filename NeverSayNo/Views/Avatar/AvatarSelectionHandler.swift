import SwiftUI

struct AvatarSelectionHandler {
    static func selectAvatar(
        emoji: String,
        avatarManager: AvatarManager,
        currentAvatarEmoji: inout String?,
        userManager: UserManager
    ) {
        guard !emoji.isEmpty else { return }
        
        let isAlreadyOwned = avatarManager.isAvatarOwned(emoji)
        
        if isAlreadyOwned {
            // 直接切换头像
            currentAvatarEmoji = emoji
            saveAvatarToUserDefaults(emoji: emoji, userManager: userManager)
            updateAvatarToServer(emoji: emoji, userManager: userManager)
            
            // 🔧 修复：发送头像更新通知，让所有显示当前用户头像的地方立即更新
            if let userId = userManager.currentUser?.id {
                NotificationCenter.default.post(
                    name: NSNotification.Name("UserAvatarUpdated"),
                    object: nil,
                    userInfo: ["avatar": emoji, "userId": userId]
                )
            }
        } else {
            // 禁止通过点击未解锁头像进行解锁，只能通过随机解锁按钮
            // 这里不执行任何操作，用户需要点击随机解锁头像按钮来解锁
        }
    }
    
    private static func saveAvatarToUserDefaults(emoji: String, userManager: UserManager) {
        // 🔧 统一使用 objectId 作为 userId 和 UserDefaults 的键
        if let userId = userManager.currentUser?.id {
            UserDefaults.standard.set(emoji, forKey: "custom_avatar_\(userId)")
        }
    }
    
    private static func updateAvatarToServer(emoji: String, userManager: UserManager) {
        // 🔧 统一使用 objectId 作为 userId
        guard let userId = userManager.currentUser?.id,
              let currentUser = userManager.currentUser else {
            return
        }
        
        let loginTypeString = getLoginTypeString(currentUser.loginType)
        
        
        DispatchQueue.global(qos: .userInitiated).async {
            LeanCloudService.shared.updateUserAvatarRecord(
                objectId: userId,
                loginType: loginTypeString,
                userAvatar: emoji
            ) { success in
                DispatchQueue.main.async {
                    if success {
                        // 使用新的全面同步方法，确保所有表中的头像数据保持一致
                        LeanCloudService.shared.syncAvatarToAllTables(userId: userId, loginType: loginTypeString, newAvatar: emoji) { success in
                            if success {
                            } else {
                            }
                        }
                    } else {
                    }
                }
            }
        }
    }
    
    // 注意：此方法当前未被使用，保留以备用
    // 如果需要异步扣除钻石，使用回调函数来更新 currentAvatarEmoji
    private static func purchaseAvatar(
        emoji: String,
        avatarManager: AvatarManager,
        userManager: UserManager,
        onSuccess: @escaping (String) -> Void
    ) {
        guard let diamondManager = userManager.diamondManager else { return }
        
        if diamondManager.checkDiamondsWithDebug(5) {
            // 🎯 修改：扣除钻石前先同步服务器数据
            diamondManager.spendDiamonds(5) { success in
                if success {
                    DispatchQueue.main.async {
                        avatarManager.ownedAvatars.insert(emoji)
                        avatarManager.saveOwnedAvatars(userManager: userManager)
                        saveAvatarToUserDefaults(emoji: emoji, userManager: userManager)
                        updateAvatarToServer(emoji: emoji, userManager: userManager)
                        onSuccess(emoji)
                    }
                }
            }
        }
    }
    
    private static func getLoginTypeString(_ loginType: UserInfo.LoginType) -> String {
        switch loginType {
        case .apple: return "apple"
        case .guest: return "guest"
        // .internal case 已删除
        }
    }
    
    // 双头像选择
    static func selectDualAvatar(_ emoji: String, avatarManager: AvatarManager) {
        
        // 确保在主线程中更新状态
        DispatchQueue.main.async {
            if avatarManager.selectedFirstAvatar == nil {
                avatarManager.selectedFirstAvatar = emoji
            } else if avatarManager.selectedSecondAvatar == nil && avatarManager.selectedFirstAvatar != emoji {
                avatarManager.selectedSecondAvatar = emoji
            } else if avatarManager.selectedFirstAvatar == emoji {
                avatarManager.selectedFirstAvatar = nil
            } else if avatarManager.selectedSecondAvatar == emoji {
                avatarManager.selectedSecondAvatar = nil
            }
        }
    }
    
    // 确认双头像
    static func confirmDualAvatar(
        avatarManager: AvatarManager,
        currentAvatarEmoji: inout String?,
        userManager: UserManager,
        dismiss: @escaping () -> Void
    ) {
        guard let firstAvatar = avatarManager.selectedFirstAvatar,
              let secondAvatar = avatarManager.selectedSecondAvatar,
              let userId = userManager.currentUser?.id else { 
            return 
        }
        
        
        // 组合双头像（简单拼接）
        let dualAvatar = "\(firstAvatar)\(secondAvatar)"
        
        // 更新当前头像
        currentAvatarEmoji = dualAvatar
        
        // 保存到UserDefaults
        UserDefaults.standard.set(dualAvatar, forKey: "custom_avatar_\(userId)")
        
        // 🔧 修复：发送头像更新通知，让所有显示当前用户头像的地方立即更新
        NotificationCenter.default.post(
            name: NSNotification.Name("UserAvatarUpdated"),
            object: nil,
            userInfo: ["avatar": dualAvatar, "userId": userId]
        )
        
        // 安全地更新到服务器
        DispatchQueue.main.async {
            updateAvatarToServer(emoji: dualAvatar, userManager: userManager)
        }
        
        // 关闭双头像模式
        avatarManager.switchToSingleAvatarMode()
        
        // 关闭界面
        DispatchQueue.main.async {
            dismiss()
        }
    }
}

