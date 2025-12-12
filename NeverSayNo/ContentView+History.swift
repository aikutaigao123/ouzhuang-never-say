//
//  ContentView+History.swift
//  NeverSayNo
//
//  Created by Auto on 2025/11/11.
//

import SwiftUI
import Foundation

// MARK: - 历史记录管理
extension ContentView {
    
    // MARK: - 历史记录加载和检查
    
    /// 加载历史记录并检查最新匹配
    func loadHistoryAndCheckLatestMatch() {
        // 获取历史记录键名
        let historyKey: String
        if let currentUser = userManager.currentUser {
            switch currentUser.loginType {
            case .apple:
                historyKey = "randomMatchHistory_apple_\(currentUser.email ?? "unknown")"
            case .guest:
                let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
                let shortDeviceID = String(deviceID.prefix(8))
                historyKey = "randomMatchHistory_guest_\(shortDeviceID)"
            }
        } else {
            let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
            let shortDeviceID = String(deviceID.prefix(8))
            historyKey = "randomMatchHistory_guest_\(shortDeviceID)"
        }
        
        // 加载历史记录
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let history = try? JSONDecoder().decode([RandomMatchHistory].self, from: data),
           !history.isEmpty {
            
            let latestHistory = history.first!
            
            // 通知SearchView显示最新匹配结果
            NotificationCenter.default.post(
                name: NSNotification.Name("ShowLatestMatch"),
                object: latestHistory.record
            )
        } else {
        }
    }
    
    // MARK: - 历史记录数据管理
    
    /// 加载历史记录数据到ContentView
    func loadRandomMatchHistory() {
        // 先清空当前历史记录数组，确保不会显示上一个账号的历史
        randomMatchHistory.removeAll()
        
        guard let currentUser = userManager.currentUser else { 
            return 
        }
        
        let historyKey = StorageKeyUtils.getHistoryKey(for: currentUser)
        
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
                
                if isLocalBlacklisted || isBlacklisted || isPendingDeletion {
                }
                
                return !(isLocalBlacklisted || isBlacklisted || isPendingDeletion)
            }
            
            randomMatchHistory = filteredHistory
            
            // 如果过滤后有变化，保存过滤后的历史记录
            if filteredHistory.count != history.count {
                saveRandomMatchHistory()
            } else {
            }
            
            // 详细打印每个历史记录
            
        } else {
            // 如果没有找到历史记录，确保数组为空
            randomMatchHistory = []
        }
    }
    
    /// 保存历史记录数据
    func saveRandomMatchHistory() {
        if let data = try? JSONEncoder().encode(randomMatchHistory) {
            UserDefaults.standard.set(data, forKey: StorageKeyUtils.getHistoryKey(for: userManager.currentUser))
        }
    }
    
    // MARK: - 黑名单和待删除用户管理
    
    /// 加载黑名单数据
    func loadBlacklist() {
        LeanCloudService.shared.fetchBlacklist { blacklistedIds, error in
            DispatchQueue.main.async {
                if error != nil {
                    return
                }
                
                if let blacklistedIds = blacklistedIds {
                    self.blacklistedUserIds = blacklistedIds
                    
                    // 加载待删除账号用户ID，然后重新加载历史记录
                    self.loadPendingDeletionUserIds()
                } else {
                    self.blacklistedUserIds = []
                    // 即使黑名单加载失败，也要加载待删除账号用户ID
                    self.loadPendingDeletionUserIds()
                }
            }
        }
    }
    
    /// 加载待删除账号用户ID列表
    private func loadPendingDeletionUserIds() {
        LeanCloudService.shared.fetchPendingDeletionUserIds { pendingDeletionIds, error in
            DispatchQueue.main.async {
                if error != nil {
                    self.pendingDeletionUserIds = []
                    // 即使加载失败，也要重新加载历史记录
                    self.loadRandomMatchHistory()
                    return
                }
                
                if let pendingDeletionIds = pendingDeletionIds {
                    self.pendingDeletionUserIds = pendingDeletionIds
                    
                    // 重新加载历史记录以应用黑名单和待删除账号过滤
                    self.loadRandomMatchHistory()
                } else {
                    self.pendingDeletionUserIds = []
                    // 重新加载历史记录以应用过滤
                    self.loadRandomMatchHistory()
                }
            }
        }
    }
}

