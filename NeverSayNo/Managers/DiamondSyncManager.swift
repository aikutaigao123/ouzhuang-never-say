import SwiftUI

extension DiamondManager {
    // 在服务器上创建钻石记录
    private func createDiamondRecordOnServer(diamonds: Int) {
        guard let userId = currentUserId, let loginType = currentLoginType else { return }
        
        if let userName = currentUserName {
            UserDefaults.standard.set(userName, forKey: "current_user_name")
        }
        
        if let userEmail = currentUserEmail {
            UserDefaults.standard.set(userEmail, forKey: "current_user_email")
        }
        
        LeanCloudService.shared.createDiamondRecordWithSimplifiedData(objectId: userId, loginType: loginType, diamonds: diamonds) { success in
            if success {
            } else {
            }
        }
    }
    
    // 更新服务器上的钻石数量
    func updateDiamondsOnServer() {
        
        guard let userId = currentUserId, let loginType = currentLoginType else { 
            return 
        }
        
        
        if let userName = currentUserName {
            UserDefaults.standard.set(userName, forKey: "current_user_name")
        }
        
        if let userEmail = currentUserEmail {
            UserDefaults.standard.set(userEmail, forKey: "current_user_email")
        }
        
        // 🎯 新增：与用户头像界面一致，立即同步到 UserDefaults（在更新服务器前先更新本地缓存）
        UserDefaultsManager.setCustomDiamonds(userId: userId, diamonds: diamonds)
        
        LeanCloudService.shared.updateDiamonds(objectId: userId, loginType: loginType, diamonds: diamonds) { [weak self] success in
            guard let self else { 
                return 
            }
            DispatchQueue.main.async {
                if success {
                    self.isServerConnected = true
                    // 🎯 新增：服务器更新成功后，确保 UserDefaults 与服务器数据一致
                    UserDefaultsManager.setCustomDiamonds(userId: userId, diamonds: self.diamonds)
                } else {
                    self.isServerConnected = false
                    self.loadDiamondsFromServer()
                }
            }
        }
    }
    
    // 更新头像列表到服务器
    func updateOwnedAvatarsToServer() {
        
        guard let userId = currentUserId, let loginType = currentLoginType else {
            return 
        }
        
        guard !ownedAvatars.isEmpty else {
            return
        }
        
        
        // 检查是否有重复
        let uniqueAvatars = Array(Set(ownedAvatars))
        if uniqueAvatars.count != ownedAvatars.count {
        }
        
        // 计算进度
        let totalCount = EmojiList.allEmojis.count
        let ownedCount = ownedAvatars.count
        let _ = totalCount > 0 ? Int((Double(ownedCount) / Double(totalCount)) * 100) : 0
        
        if let userName = currentUserName {
            UserDefaults.standard.set(userName, forKey: "current_user_name")
        }
        
        if let userEmail = currentUserEmail {
            UserDefaults.standard.set(userEmail, forKey: "current_user_email")
        }
        
        LeanCloudService.shared.updateOwnedAvatars(userId: userId, loginType: loginType, ownedAvatars: ownedAvatars) { [weak self] success in
            guard let self else { return }
            if success {
                self.isServerConnected = true
            } else {
                self.isServerConnected = false
                // ⚠️ 关键修复：不要从服务器重新加载，这会覆盖本地的新数据
                // 保持本地已更新的数据，等待下次同步机会
                // self.loadOwnedAvatarsFromServer()  // ❌ 删除这行，防止覆盖本地数据
            }
        }
    }
}
