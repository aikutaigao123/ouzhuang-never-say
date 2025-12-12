//
//  LegacySearchView+CountdownTimer.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//

import Foundation

// MARK: - Countdown Timer Management Extension
extension LegacySearchView {
    
    /// 开始倒计时定时器
    func startCountdownTimer() {
        stopCountdownTimer() // 先停止之前的定时器
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateCountdown()
        }
    }
    
    /// 停止倒计时定时器
    func stopCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
    
    /// 更新倒计时显示
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
            refreshBlacklistAndHistory()
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
}

