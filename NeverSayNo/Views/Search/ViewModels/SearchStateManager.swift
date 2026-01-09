import SwiftUI

class SearchStateManager: ObservableObject {
    @Published var isUserBlacklisted = false
    @Published var blacklistExpiryTime: Date?
    @Published var timeRemaining = ""
    @Published var showCopySuccess = false
    @Published var copySuccessMessage = ""
    
    private var countdownTimer: Timer?
    private let userManager: UserManager
    
    init(userManager: UserManager) {
        self.userManager = userManager
    }
    
    // 黑名单相关方法
    func loadBlacklist() {
        // 获取设备ID
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
        
        LeanCloudService.shared.fetchBlacklist { blacklistedIds, error in
            DispatchQueue.main.async {
                if let _ = error {
                    return
                }
                
                if let blacklistedIds = blacklistedIds {
                    // 检查当前用户是否在黑名单中（与排行榜逻辑一致：同时检查用户ID、用户名和设备ID）
                    if let currentUser = self.userManager.currentUser {
                        let currentUserId = currentUser.id
                        let currentUserName = currentUser.fullName
                        
                        // 检查黑名单：同时检查用户ID、用户名和设备ID（与排行榜一致）
                        let userIsBlacklisted = blacklistedIds.contains(currentUserId) ||
                                               blacklistedIds.contains(currentUserName) ||
                                               blacklistedIds.contains(deviceID)
                        
                        self.isUserBlacklisted = userIsBlacklisted
                        if userIsBlacklisted {
                            // 获取用户的过期时间（优先检查用户ID，然后用户名，最后设备ID）
                            if blacklistedIds.contains(currentUserId) {
                                self.getUserBlacklistExpiryTime(userId: currentUserId)
                            } else if blacklistedIds.contains(currentUserName) {
                                self.getUserBlacklistExpiryTime(userId: currentUserName)
                            } else {
                                self.getDeviceBlacklistExpiryTime(deviceId: deviceID)
                            }
                        } else {
                            self.stopCountdownTimer()
                            self.blacklistExpiryTime = nil
                            self.timeRemaining = ""
                        }
                    }
                } else {
                    self.isUserBlacklisted = false
                }
            }
        }
    }
    
    func startCountdownTimer() {
        stopCountdownTimer() // 先停止之前的定时器
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateCountdown()
        }
    }
    
    func stopCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
    
    func updateCountdown() {
        guard let expiryTime = blacklistExpiryTime else {
            timeRemaining = ""
            return
        }
        
        let now = Date()
        let timeInterval = expiryTime.timeIntervalSince(now)
        
        if timeInterval <= 0 {
            // 已过期，停止定时器并刷新黑名单
            timeRemaining = ""
            stopCountdownTimer()
            blacklistExpiryTime = nil
            isUserBlacklisted = false
            loadBlacklist()
        } else {
            // 计算剩余时间
            let days = Int(timeInterval) / 86400
            let hours = Int(timeInterval) % 86400 / 3600
            let minutes = Int(timeInterval) % 3600 / 60
            let seconds = Int(timeInterval) % 60
            
            if days > 0 {
                timeRemaining = "\(days)天\(hours)小时\(minutes)分钟\(seconds)秒"
            } else if hours > 0 {
                timeRemaining = "\(hours)小时\(minutes)分钟\(seconds)秒"
            } else if minutes > 0 {
                timeRemaining = "\(minutes)分钟\(seconds)秒"
            } else {
                timeRemaining = "\(seconds)秒"
            }
        }
    }
    
    // 复制成功提示
    func showCopySuccessMessage(_ message: String) {
        copySuccessMessage = message
        showCopySuccess = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.showCopySuccess = false
        }
    }
    
    private func getUserBlacklistExpiryTime(userId: String) {
        LeanCloudService.shared.fetchUserBlacklistExpiryTime(userId: userId) { expiryTime, error in
            DispatchQueue.main.async {
                if error != nil {
                    return
                }
                
                if let expiryTime = expiryTime {
                    self.blacklistExpiryTime = expiryTime
                    self.startCountdownTimer()
                }
            }
        }
    }
    
    private func getDeviceBlacklistExpiryTime(deviceId: String) {
        LeanCloudService.shared.fetchDeviceBlacklistExpiryTime(deviceId: deviceId) { expiryTime, error in
            DispatchQueue.main.async {
                if error != nil {
                    return
                }
                
                if let expiryTime = expiryTime {
                    self.blacklistExpiryTime = expiryTime
                    self.startCountdownTimer()
                }
            }
        }
    }
}
