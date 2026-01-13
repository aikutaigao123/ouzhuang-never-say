import SwiftUI

// 统一的黑名单管理服务
class SearchBlacklistService: ObservableObject {
    @Published var blacklistedUserIds: Set<String> = []
    @Published var blacklistedDeviceIds: Set<String> = []
    @Published var pendingDeletionUserIds: Set<String> = []
    
    private let userManager: UserManager
    
    init(userManager: UserManager) {
        self.userManager = userManager
        loadBlacklist()
    }
    
    // 加载黑名单用户ID和设备ID列表
    func loadBlacklist() {
        // 获取设备ID
        _ = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
        
        // 从本地存储加载黑名单用户ID
        let blacklistedUserIdsKey = "blacklisted_user_ids_\(userManager.currentUser?.id ?? "guest")"
        if let data = UserDefaults.standard.data(forKey: blacklistedUserIdsKey),
           let userIds = try? JSONDecoder().decode([String].self, from: data) {
            blacklistedUserIds = Set(userIds)
        }
        
        // 从本地存储加载黑名单设备ID
        let blacklistedDeviceIdsKey = "blacklisted_device_ids_\(userManager.currentUser?.id ?? "guest")"
        if let data = UserDefaults.standard.data(forKey: blacklistedDeviceIdsKey),
           let deviceIds = try? JSONDecoder().decode([String].self, from: data) {
            blacklistedDeviceIds = Set(deviceIds)
        }
        
        // 从本地存储加载待删除用户ID
        let pendingDeletionUserIdsKey = "pending_deletion_user_ids_\(userManager.currentUser?.id ?? "guest")"
        if let data = UserDefaults.standard.data(forKey: pendingDeletionUserIdsKey),
           let userIds = try? JSONDecoder().decode([String].self, from: data) {
            pendingDeletionUserIds = Set(userIds)
        }
    }
    
    // 保存黑名单到本地
    func saveBlacklist() {
        // 保存黑名单用户ID
        let blacklistedUserIdsKey = "blacklisted_user_ids_\(userManager.currentUser?.id ?? "guest")"
        if let data = try? JSONEncoder().encode(Array(blacklistedUserIds)) {
            UserDefaults.standard.set(data, forKey: blacklistedUserIdsKey)
        }
        
        // 保存黑名单设备ID
        let blacklistedDeviceIdsKey = "blacklisted_device_ids_\(userManager.currentUser?.id ?? "guest")"
        if let data = try? JSONEncoder().encode(Array(blacklistedDeviceIds)) {
            UserDefaults.standard.set(data, forKey: blacklistedDeviceIdsKey)
        }
        
        // 保存待删除用户ID
        let pendingDeletionUserIdsKey = "pending_deletion_user_ids_\(userManager.currentUser?.id ?? "guest")"
        if let data = try? JSONEncoder().encode(Array(pendingDeletionUserIds)) {
            UserDefaults.standard.set(data, forKey: pendingDeletionUserIdsKey)
        }
    }
    
    // 添加用户到黑名单
    func addUserToBlacklist(_ userId: String) {
        blacklistedUserIds.insert(userId)
        saveBlacklist()
    }
    
    // 添加设备到黑名单
    func addDeviceToBlacklist(_ deviceId: String) {
        blacklistedDeviceIds.insert(deviceId)
        saveBlacklist()
    }
    
    // 添加用户到待删除列表
    func addUserToPendingDeletion(_ userId: String) {
        pendingDeletionUserIds.insert(userId)
        saveBlacklist()
    }
    
    // 从黑名单移除用户
    func removeUserFromBlacklist(_ userId: String) {
        blacklistedUserIds.remove(userId)
        saveBlacklist()
    }
    
    // 从黑名单移除设备
    func removeDeviceFromBlacklist(_ deviceId: String) {
        blacklistedDeviceIds.remove(deviceId)
        saveBlacklist()
    }
    
    // 从待删除列表移除用户
    func removeUserFromPendingDeletion(_ userId: String) {
        pendingDeletionUserIds.remove(userId)
        saveBlacklist()
    }
    
    // 检查用户是否在黑名单中
    func isUserBlacklisted(_ userId: String) -> Bool {
        return blacklistedUserIds.contains(userId)
    }
    
    // 检查设备是否在黑名单中
    func isDeviceBlacklisted(_ deviceId: String) -> Bool {
        return blacklistedDeviceIds.contains(deviceId)
    }
    
    // 检查用户是否在待删除列表中
    func isUserPendingDeletion(_ userId: String) -> Bool {
        return pendingDeletionUserIds.contains(userId)
    }
    
    // 刷新黑名单和历史记录
    func refreshBlacklistAndHistory() {
        // 重新加载黑名单
        loadBlacklist()
        
        // 这里可以添加刷新历史记录的逻辑
        // 比如过滤掉黑名单用户的历史记录
    }
    
    // 清空所有黑名单
    func clearAllBlacklists() {
        blacklistedUserIds.removeAll()
        blacklistedDeviceIds.removeAll()
        pendingDeletionUserIds.removeAll()
        saveBlacklist()
    }
    
    // 获取黑名单统计信息
    var blacklistStats: (userCount: Int, deviceCount: Int, pendingDeletionCount: Int) {
        return (
            userCount: blacklistedUserIds.count,
            deviceCount: blacklistedDeviceIds.count,
            pendingDeletionCount: pendingDeletionUserIds.count
        )
    }
}
