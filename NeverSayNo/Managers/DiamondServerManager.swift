import SwiftUI

extension DiamondManager {
    // 🎯 修改：使用 DiamondStore 加载钻石数量
    func loadDiamondsFromServer() {
        // DiamondStore 在初始化时会自动刷新，这里只做手动刷新
        diamondStore?.refreshBalanceFromServer { result in
            DispatchQueue.main.async {
                if case .failure = result {
                    // 刷新失败时保持当前余额
                }
            }
        }
        return
        
        // 以下旧代码保留作为备份（已废弃）
        /*
        
        guard let userId = currentUserId, let loginType = currentLoginType else {
            return
        }
        
        isLoading = true
        
        // 🎯 新增：与用户头像界面一致，先从 UserDefaults 读取作为快速初始化（如果还未初始化）
        if diamonds == 0, let cachedDiamonds = UserDefaultsManager.getCustomDiamonds(userId: userId) {
            self.diamonds = cachedDiamonds
        }
        
        LeanCloudService.shared.fetchDiamondRecords(objectId: userId, loginType: loginType) { records, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    if error.contains("未找到用户的钻石记录") {
                        // 🎯 新增：查询失败时，使用 UserDefaults 作为后备（与用户头像界面一致）
                        if let cachedDiamonds = UserDefaultsManager.getCustomDiamonds(userId: userId) {
                            self.diamonds = cachedDiamonds
                        } else {
                            self.diamonds = 0
                        }
                        self.isServerConnected = true
                    } else {
                        // 🎯 新增：网络错误时，使用 UserDefaults 作为后备（与用户头像界面一致）
                        if let cachedDiamonds = UserDefaultsManager.getCustomDiamonds(userId: userId) {
                            self.diamonds = cachedDiamonds
                        } else {
                            self.diamonds = 0
                        }
                        self.isServerConnected = false
                    }
                } else if let records = records, !records.isEmpty {
                    // 获取最新的钻石记录
                    let latestRecord = records.first!
                    
                    let _ = self.diamonds
                    let newDiamonds = latestRecord.diamonds
                    self.diamonds = newDiamonds
                    self.isServerConnected = true
                    
                    // 🎯 新增：与用户头像界面一致，检查并更新 UserDefaults 以保持一致性
                    let userDefaultsDiamonds = UserDefaultsManager.getCustomDiamonds(userId: userId)
                    if let defaultsDiamonds = userDefaultsDiamonds {
                        if defaultsDiamonds != newDiamonds {
                            // 🔧 自动更新 UserDefaults 以保持一致性
                            UserDefaultsManager.setCustomDiamonds(userId: userId, diamonds: newDiamonds)
                        }
                    } else {
                        UserDefaultsManager.setCustomDiamonds(userId: userId, diamonds: newDiamonds)
                    }
                    
                } else {
                    // 没有记录，默认为0
                    self.diamonds = 0
                    self.isServerConnected = true
                    
                    // 🎯 新增：与用户头像界面一致，更新 UserDefaults
                    UserDefaultsManager.setCustomDiamonds(userId: userId, diamonds: 0)
                }
                
            }
        }
        */
    }
    
    // 从服务器加载用户头像
    func loadUserAvatarFromServer() {
        guard let userId = currentUserId else {
            return
        }
        
        // 🎯 修改：使用 fetchUserAvatarByUserId，不依赖 loginType，直接从 UserAvatarRecord 表获取
        LeanCloudService.shared.fetchUserAvatarByUserId(objectId: userId) { userAvatar, error in
            DispatchQueue.main.async {
                if error != nil {
                    // 网络错误时保持当前头像
                } else if let userAvatar = userAvatar, !userAvatar.isEmpty {
                    // 🔍 检查 UserDefaults 与服务器数据是否一致
                    let oldAvatar = UserDefaultsManager.getCustomAvatar(userId: userId)
                    if let oldValue = oldAvatar, !oldValue.isEmpty {
                        if oldValue != userAvatar {
                        } else {
                        }
                    } else {
                    }
                    UserDefaultsManager.setCustomAvatar(userId: userId, emoji: userAvatar)
                } else {
                }
            }
        }
    }
    
    // 从服务器加载用户名
    func loadUserNameFromServer() {
        
        guard let userId = currentUserId else {
            return
        }
        
        // 🎯 修改：使用 fetchUserNameByUserId，不依赖 loginType，直接从 UserNameRecord 表获取
        LeanCloudService.shared.fetchUserNameByUserId(objectId: userId) { userName, error in
            DispatchQueue.main.async {
                if error != nil {
                    // 网络错误时保持当前用户名
                } else if let userName = userName, !userName.isEmpty {
                    // 更新本地存储和DiamondManager中的用户名
                    let oldLocalName = self.currentUserName
                    let nameChanged = oldLocalName != userName
                    
                    if nameChanged {
                    } else {
                    }
                    
                    UserDefaults.standard.set(userName, forKey: "current_user_name")
                    self.currentUserName = userName
                    
                    // 只有在用户名真正改变时才发出警告
                    if nameChanged {
                    }
                } else {
                    // 服务器上没有用户名记录，使用智能上传逻辑
                    if let localUserName = self.currentUserName, !localUserName.isEmpty,
                       let loginType = self.currentLoginType {
                        let userEmail = self.currentUserEmail ?? UserDefaults.standard.string(forKey: "current_user_email")
                        LeanCloudService.shared.uploadUserNameIfNotExists(objectId: userId, loginType: loginType, userName: localUserName, userEmail: userEmail) { success, message in
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
    
    // 从服务器加载拥有的头像列表
    func loadOwnedAvatarsFromServer() {
        guard let userId = currentUserId, let loginType = currentLoginType else {
            return
        }
        
        
        LeanCloudService.shared.fetchOwnedAvatars(userId: userId, loginType: loginType) { ownedAvatars, error in
            DispatchQueue.main.async {
                if error != nil {
                    self.isServerConnected = false
                } else if let ownedAvatars = ownedAvatars {
                    
                    // 检查是否有重复
                    let uniqueAvatars = Array(Set(ownedAvatars))
                    if uniqueAvatars.count != ownedAvatars.count {
                    }
                    
                    self.ownedAvatars = ownedAvatars
                    self.isServerConnected = true
                    
                    // 计算进度
                    let totalCount = EmojiList.allEmojis.count
                    let ownedCount = ownedAvatars.count
                    let _ = totalCount > 0 ? Int((Double(ownedCount) / Double(totalCount)) * 100) : 0
                    
                    // 检查是否缺少某些头像
                    let allEmojisSet = Set(EmojiList.allEmojis)
                    let ownedAvatarsSet = Set(ownedAvatars)
                    let missingAvatars = allEmojisSet.subtracting(ownedAvatarsSet)
                    if !missingAvatars.isEmpty {
                    } else {
                    }
                } else {
                    self.ownedAvatars = []
                    self.isServerConnected = true
                }
            }
        }
    }
}
