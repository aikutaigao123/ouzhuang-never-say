import SwiftUI

class AvatarManager: ObservableObject {
    @Published var ownedAvatars: Set<String> = []
    @Published var isDualAvatarMode: Bool = false
    @Published var selectedFirstAvatar: String? = nil
    @Published var selectedSecondAvatar: String? = nil
    
    // 计算属性：将已拥有的头像排在前面
    var sortedEmojis: [String] {
        let allEmojis = EmojiList.allEmojis
        let ownedEmojis = allEmojis.filter { ownedAvatars.contains($0) }
        let unownedEmojis = allEmojis.filter { !ownedAvatars.contains($0) }
        return ownedEmojis + unownedEmojis
    }
    
    var canConfirmDualAvatar: Bool {
        selectedFirstAvatar != nil && selectedSecondAvatar != nil
    }
    
    // 加载用户拥有的头像
    func loadOwnedAvatars(userManager: UserManager) {
        
        guard userManager.currentUser?.id != nil else { 
            return 
        }
        
        
        // 从DiamondManager获取服务器数据
        if let diamondManager = userManager.diamondManager {
            // 确保在主线程中访问
            DispatchQueue.main.async {
                let avatarList = diamondManager.ownedAvatars
                // 过滤掉空字符串，确保数据安全
                let validAvatars = avatarList.filter { !$0.isEmpty }
                self.ownedAvatars = Set(validAvatars)
            }
        } else {
            // 如果DiamondManager不可用，使用当前头像作为默认值
            ownedAvatars = []
        }
    }
    
    // 保存头像列表到服务器
    func saveOwnedAvatars(userManager: UserManager) {
        guard userManager.currentUser?.id != nil else { 
            return 
        }
        
        
        // 更新DiamondManager中的头像列表
        if let diamondManager = userManager.diamondManager {
            // 确保在主线程中更新
            DispatchQueue.main.async {
                diamondManager.ownedAvatars = Array(self.ownedAvatars)
                diamondManager.updateOwnedAvatarsToServer()
            }
        } else {
        }
    }
    
    // 检查头像是否已拥有
    func isAvatarOwned(_ emoji: String) -> Bool {
        // 添加安全检查
        guard !emoji.isEmpty else { return false }
        // 确保ownedAvatars不为nil
        return ownedAvatars.contains(emoji)
    }
    
    // 切换为双头像模式
    func switchToDualAvatarMode() {
        
        // 确保在主线程中更新状态
        DispatchQueue.main.async {
            self.isDualAvatarMode = true
            self.selectedFirstAvatar = nil
            self.selectedSecondAvatar = nil
        }
    }
    
    // 切换为单一头像模式
    func switchToSingleAvatarMode() {
        DispatchQueue.main.async {
            self.isDualAvatarMode = false
            self.selectedFirstAvatar = nil
            self.selectedSecondAvatar = nil
        }
    }
    
    // 检查双头像模式（通过拥有的emoji数量判断）
    func checkDualAvatarMode() {
        // 双头像模式默认关闭，只有在用户主动选择时才会开启
        isDualAvatarMode = false
    }
}

