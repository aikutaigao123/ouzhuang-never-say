import Foundation

// 本地黑名单管理器（单例）
class LocalBlacklistManager {
    static let shared = LocalBlacklistManager()
    
    private var blacklistedUserIds: Set<String> = []
    private let lock = NSLock()
    
    private init() {
        loadLocalBlacklist()
    }
    
    // 加载本地黑名单
    private func loadLocalBlacklist() {
        lock.lock()
        defer { lock.unlock() }
        
        guard let currentUserId = UserDefaultsManager.getCurrentUserId() else {
            return
        }
        
        let key = "local_blacklisted_user_ids_\(currentUserId)"
        if let data = UserDefaults.standard.data(forKey: key),
           let userIds = try? JSONDecoder().decode([String].self, from: data) {
            blacklistedUserIds = Set(userIds)
        }
    }
    
    // 保存本地黑名单
    private func saveLocalBlacklist() {
        guard let currentUserId = UserDefaultsManager.getCurrentUserId() else {
            return
        }
        
        let key = "local_blacklisted_user_ids_\(currentUserId)"
        if let data = try? JSONEncoder().encode(Array(blacklistedUserIds)) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    // 添加用户到本地黑名单
    func addUserToLocalBlacklist(_ userId: String) {
        let startTime = Date()
        
        guard let currentUserId = UserDefaultsManager.getCurrentUserId() else {
            return
        }
        
        // 先获取锁，执行操作，然后释放锁
        var shouldNotify = false
        do {
            lock.lock()
            defer { 
                lock.unlock()
            }
            
            let lockTime = Date().timeIntervalSince(startTime)
            if lockTime > 0.01 {
            }
            
            blacklistedUserIds.insert(userId)
            
            let saveStartTime = Date()
            saveLocalBlacklist()
            let saveTime = Date().timeIntervalSince(saveStartTime)
            if saveTime > 0.01 {
            }
            
            shouldNotify = true
        }
        
        // 在锁外发送通知和上传到 LeanCloud
        if shouldNotify {
            // 异步发送通知，避免阻塞
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("LocalBlacklistUpdated"), object: nil)
            }
            
            // 异步上传到 LeanCloud
            DispatchQueue.main.async {
                self.uploadAddToLocalBlacklist(userId: userId, currentUserId: currentUserId)
            }
        }
    }
    
    // 上传添加到本地黑名单到 LeanCloud
    private func uploadAddToLocalBlacklist(userId: String, currentUserId: String) {
        // 先尝试从缓存获取用户名
        let userName = UserDefaultsManager.getFriendUserName(userId: userId) ?? userId
        
        // 如果缓存没有，尝试从服务器获取
        if userName == userId {
            LeanCloudService.shared.fetchUserNameByUserId(objectId: userId) { name, _ in
                let finalUserName = name ?? userId
                // 上传到 LeanCloud
                LeanCloudService.shared.addUserToLocalBlacklistTable(
                    userId: userId,
                    userName: finalUserName,
                    currentUserId: currentUserId
                ) { success, error in
                    if success {
                    } else {
                    }
                }
            }
        } else {
            // 直接上传
            LeanCloudService.shared.addUserToLocalBlacklistTable(
                userId: userId,
                userName: userName,
                currentUserId: currentUserId
            ) { success, error in
                if success {
                } else {
                }
            }
        }
    }
    
    // 从本地黑名单移除用户
    func removeUserFromLocalBlacklist(_ userId: String) {
        guard let currentUserId = UserDefaultsManager.getCurrentUserId() else {
            return
        }
        
        // 先获取锁，执行操作，然后释放锁
        var shouldNotify = false
        do {
            lock.lock()
            defer { lock.unlock() }
            
            blacklistedUserIds.remove(userId)
            saveLocalBlacklist()
            shouldNotify = true
        }
        
        // 在锁外异步发送通知和从 LeanCloud 删除
        if shouldNotify {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name("LocalBlacklistUpdated"), object: nil)
            }
            
            // 异步从 LeanCloud 删除
            DispatchQueue.main.async {
                self.uploadRemoveFromLocalBlacklist(userId: userId, currentUserId: currentUserId)
            }
        }
    }
    
    // 上传从本地黑名单删除到 LeanCloud
    private func uploadRemoveFromLocalBlacklist(userId: String, currentUserId: String) {
        LeanCloudService.shared.removeUserFromLocalBlacklistTable(
            userId: userId,
            currentUserId: currentUserId
        ) { success, error in
            if success {
            } else {
            }
        }
    }
    
    // 检查用户是否在本地黑名单中
    func isUserInLocalBlacklist(_ userId: String) -> Bool {
        let checkStartTime = Date()
        
        lock.lock()
        defer { 
            lock.unlock()
            let checkTime = Date().timeIntervalSince(checkStartTime)
            if checkTime > 0.01 {
            }
        }
        
        let result = blacklistedUserIds.contains(userId)
        return result
    }
    
    // 获取所有本地黑名单用户ID
    func getAllLocalBlacklistedUserIds() -> Set<String> {
        lock.lock()
        defer { lock.unlock() }
        
        return blacklistedUserIds
    }
    
    // 清空本地黑名单
    func clearLocalBlacklist() {
        lock.lock()
        defer { lock.unlock() }
        
        blacklistedUserIds.removeAll()
        saveLocalBlacklist()
        
        NotificationCenter.default.post(name: NSNotification.Name("LocalBlacklistUpdated"), object: nil)
    }
}


