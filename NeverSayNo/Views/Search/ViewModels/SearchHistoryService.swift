import SwiftUI

// 统一的历史记录管理服务
class SearchHistoryService: ObservableObject {
    @Published var randomMatchHistory: [RandomMatchHistory] = []
    
    private let userManager: UserManager
    
    init(userManager: UserManager) {
        self.userManager = userManager
    }
    
    // 从本地加载随机匹配历史
    func loadRandomMatchHistory() {
        // 先清空当前历史记录数组，确保不会显示上一个账号的历史
        randomMatchHistory.removeAll()
        
        let historyKey = StorageKeyUtils.getHistoryKey(for: userManager.currentUser)
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let history = try? JSONDecoder().decode([RandomMatchHistory].self, from: data) {
            // 过滤掉黑名单用户和设备的记录，以及待删除账号用户（与排行榜逻辑一致）
            // 🎯 新增：获取本地黑名单
            let localBlacklistedUserIds = LocalBlacklistManager.shared.getAllLocalBlacklistedUserIds()
            
            let filteredHistory = history.filter { historyItem in
                // 🎯 新增：检查本地黑名单
                let isLocalBlacklisted = localBlacklistedUserIds.contains(historyItem.record.userId)
                
                // 检查黑名单：同时检查用户ID、用户名和设备ID（与排行榜一致）
                let isBlacklisted =
                    blacklistedUserIds.contains(historyItem.record.userId) ||
                    (historyItem.record.userName != nil && blacklistedUserIds.contains(historyItem.record.userName!)) ||
                    blacklistedUserIds.contains(historyItem.record.deviceId)
                
                // 检查待删除账号：检查用户ID、用户名和设备ID（与排行榜一致）
                let isPendingDeletion =
                    pendingDeletionUserIds.contains(historyItem.record.userId) ||
                    (historyItem.record.userName != nil && pendingDeletionUserIds.contains(historyItem.record.userName!)) ||
                    pendingDeletionUserIds.contains(historyItem.record.deviceId)
                
                return !(isLocalBlacklisted || isBlacklisted || isPendingDeletion)
            }
            
            randomMatchHistory = filteredHistory
            
            // 如果过滤后有变化，保存过滤后的历史记录
            if filteredHistory.count != history.count {
                saveRandomMatchHistory()
            }
        }
    }
    
    // 保存随机匹配历史到本地
    func saveRandomMatchHistory() {
        if let data = try? JSONEncoder().encode(randomMatchHistory) {
            UserDefaults.standard.set(data, forKey: StorageKeyUtils.getHistoryKey(for: userManager.currentUser))
        }
    }
    
    // 添加随机匹配到历史
    func addRandomMatchToHistory(record: LocationRecord, recordNumber: Int) {
        let historyItem = RandomMatchHistory(
            record: record,
            recordNumber: recordNumber,
            currentLocation: nil
        )
        
        randomMatchHistory.append(historyItem)
        
        // 限制历史记录数量，保留最近217条
        // 🎯 修改：删除多余记录的方式与清除按钮删除全部记录的方式完全一致
        if randomMatchHistory.count > 217 {
            randomMatchHistory = Array(randomMatchHistory.suffix(217))
            
            // 与清除按钮一致：保存到UserDefaults
            saveRandomMatchHistory()
            
            // 与清除按钮一致：发送历史清除通知，确保所有相关界面都能同步更新
            NotificationCenter.default.post(name: .init("HistoryCleared"), object: nil)
        } else {
            saveRandomMatchHistory()
        }
    }
    
    // 清理历史记录
    func clearHistory() {
        randomMatchHistory.removeAll()
        saveRandomMatchHistory()
    }
    
    // 获取历史记录数量
    var historyCount: Int {
        return randomMatchHistory.count
    }
    
    // 检查是否已匹配过该用户
    func hasMatchedUser(_ userId: String) -> Bool {
        return randomMatchHistory.contains { $0.record.userId == userId }
    }
    
    // 获取历史记录用于排除
    func getHistoryRecordsForExclusion() -> [LocationRecord] {
        return randomMatchHistory.map { $0.record }
    }
    
    // 黑名单用户ID集合（这里需要从外部传入或从其他服务获取）
    private var blacklistedUserIds: Set<String> = []
    
    // 待删除用户ID集合（这里需要从外部传入或从其他服务获取）
    private var pendingDeletionUserIds: Set<String> = []
    
    // 设置黑名单用户ID
    func setBlacklistedUserIds(_ ids: Set<String>) {
        blacklistedUserIds = ids
    }
    
    // 设置待删除用户ID
    func setPendingDeletionUserIds(_ ids: Set<String>) {
        pendingDeletionUserIds = ids
    }
}
