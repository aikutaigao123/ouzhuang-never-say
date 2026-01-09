//
//  LegacySearchView+BlacklistManagement.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//

import Foundation
import UIKit

// MARK: - Blacklist Management Extension
extension LegacySearchView {
    
    /// 加载黑名单用户ID和设备ID列表
    func loadBlacklist() {
        let loadBlacklistStartTime = Date()
        if let searchStart = self.searchStartTime {
            let _ = loadBlacklistStartTime.timeIntervalSince(searchStart)
        }
        
        // 获取设备ID
        let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
        
        LeanCloudService.shared.fetchBlacklist { blacklistedIds, error in
            let loadBlacklistEndTime = Date()
            let _ = loadBlacklistEndTime.timeIntervalSince(loadBlacklistStartTime)
            DispatchQueue.main.async {
                if let _ = error {
                    if let searchStart = self.searchStartTime {
                        let _ = loadBlacklistEndTime.timeIntervalSince(searchStart)
                    }
                    return
                }
                
                if let blacklistedIds = blacklistedIds {
                    if let searchStart = self.searchStartTime {
                        let _ = loadBlacklistEndTime.timeIntervalSince(searchStart)
                    }
                    self.blacklistedUserIds = blacklistedIds
                    
                    // 检查当前用户是否在黑名单中（与排行榜逻辑一致：同时检查用户ID、用户名和设备ID）
                    if let currentUser = self.userManager.currentUser {
                        let currentUserId = currentUser.id
                        let currentUserName = currentUser.fullName
                        
                        // 检查黑名单：同时检查用户ID、用户名和设备ID（与排行榜一致）
                        let userIsBlacklisted = blacklistedIds.contains(currentUserId) ||
                                               blacklistedIds.contains(currentUserName) ||
                                               blacklistedIds.contains(deviceID)
                        
                        // 添加调试信息
                        
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
                    
                    // 加载待删除账号用户ID，然后重新加载历史记录
                    self.loadPendingDeletionUserIds()
                } else {
                    self.blacklistedUserIds = []
                    self.isUserBlacklisted = false
                    // 即使黑名单加载失败，也要加载待删除账号用户ID
                    self.loadPendingDeletionUserIds()
                }
            }
        }
    }
    
    /// 加载待删除账号用户ID列表
    func loadPendingDeletionUserIds() {
        let loadPendingDeletionStartTime = Date()
        if let searchStart = self.searchStartTime {
            let _ = loadPendingDeletionStartTime.timeIntervalSince(searchStart)
        }
        
        LeanCloudService.shared.fetchPendingDeletionUserIds { pendingDeletionIds, error in
            let loadPendingDeletionEndTime = Date()
            let _ = loadPendingDeletionEndTime.timeIntervalSince(loadPendingDeletionStartTime)
            DispatchQueue.main.async {
                if error != nil {
                    if let searchStart = self.searchStartTime {
                        let _ = loadPendingDeletionEndTime.timeIntervalSince(searchStart)
                    }
                    self.pendingDeletionUserIds = []
                    // 即使加载失败，也要重新加载历史记录
                    self.loadRandomMatchHistory()
                    return
                }
                
                if let pendingDeletionIds = pendingDeletionIds {
                    if let searchStart = self.searchStartTime {
                        let _ = loadPendingDeletionEndTime.timeIntervalSince(searchStart)
                    }
                    self.pendingDeletionUserIds = pendingDeletionIds
                    
                    // 重新加载历史记录以应用黑名单和待删除账号过滤
                    self.loadRandomMatchHistory()
                } else {
                    if let searchStart = self.searchStartTime {
                        let _ = loadPendingDeletionEndTime.timeIntervalSince(searchStart)
                    }
                    self.pendingDeletionUserIds = []
                    // 重新加载历史记录以应用过滤
                    self.loadRandomMatchHistory()
                }
            }
        }
    }
    
    /// 刷新黑名单和历史记录
    func refreshBlacklistAndHistory() {
        let refreshStartTime = Date()
        if let searchStart = self.searchStartTime {
            let _ = refreshStartTime.timeIntervalSince(searchStart)
        }
        
        let loadBlacklistStartTime = Date()
        loadBlacklist()
        let loadBlacklistEndTime = Date()
        let _ = loadBlacklistEndTime.timeIntervalSince(loadBlacklistStartTime)
        if let searchStart = self.searchStartTime {
            let _ = loadBlacklistEndTime.timeIntervalSince(searchStart)
        }
        
        // 查询谁喜欢了当前用户
        let loadUsersWhoLikedMeStartTime = Date()
        loadUsersWhoLikedMe()
        let loadUsersWhoLikedMeEndTime = Date()
        let _ = loadUsersWhoLikedMeEndTime.timeIntervalSince(loadUsersWhoLikedMeStartTime)
        if let searchStart = self.searchStartTime {
            let _ = loadUsersWhoLikedMeEndTime.timeIntervalSince(searchStart)
        }
        
        // 注意：loadBlacklist 和 loadUsersWhoLikedMe 是异步的，实际完成时间会在各自的回调中
    }
    
    /// 获取用户/设备的黑名单过期时间
    func getUserBlacklistExpiryTime(userId: String) {
        LeanCloudService.shared.fetchUserBlacklistExpiryTime(userId: userId) { expiryTime, error in
            DispatchQueue.main.async {
                if error != nil {
                    return
                }
                
                if let expiryTime = expiryTime {
                    self.blacklistExpiryTime = expiryTime
                    self.startCountdownTimer()
                } else {
                }
            }
        }
    }
    
    /// 获取设备的黑名单过期时间
    func getDeviceBlacklistExpiryTime(deviceId: String) {
        LeanCloudService.shared.fetchDeviceBlacklistExpiryTime(deviceId: deviceId) { expiryTime, error in
            DispatchQueue.main.async {
                if error != nil {
                    return
                }
                
                if let expiryTime = expiryTime {
                    self.blacklistExpiryTime = expiryTime
                    self.startCountdownTimer()
                } else {
                }
            }
        }
    }
}

