import SwiftUI

extension MessageView {
    // MARK: - Cache Refresh Timer Methods
    
    /// 启动缓存刷新定时器
    internal func startCacheRefreshTimer() {
        stopCacheRefreshTimer() // 先停止现有定时器
        
        cacheRefreshTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { _ in
            // 每10分钟检查一次缓存状态
            self.checkAndRefreshCache()
        }
    }
    
    /// 停止缓存刷新定时器
    internal func stopCacheRefreshTimer() {
        cacheRefreshTimer?.invalidate()
        cacheRefreshTimer = nil
    }
    
    /// 检查并刷新缓存
    private func checkAndRefreshCache() {
        
        // 检查数据源一致性
        if !existingPatMessages.isEmpty {
            let _ = existingPatMessages.first!
            let _ = existingPatMessages.last!
            
            // 检查数据源的时间戳分布
            let _ = Date()
            let _ = Date().addingTimeInterval(-300)
            let _ = existingPatMessages.filter { $0.timestamp > Date().addingTimeInterval(-300) }
            
            // 检查数据源的时间戳排序
            let sortedMessages = existingPatMessages.sorted { $0.timestamp > $1.timestamp }
            let isSorted = existingPatMessages.count == sortedMessages.count && 
                          zip(existingPatMessages, sortedMessages).allSatisfy { $0.id == $1.id }
            if !isSorted {
            }
        }
        
    }
}



