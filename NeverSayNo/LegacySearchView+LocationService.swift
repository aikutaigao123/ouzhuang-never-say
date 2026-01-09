//
//  LegacySearchView+LocationService.swift
//  NeverSayNo
//
//  Created by Die chen on 2025/7/1.
//

import SwiftUI
import Foundation
import CoreLocation
import LeanCloud

extension LegacySearchView {
    // MARK: - Location Service Methods
    
    /// 清除所有历史记录
    func clearAllHistory() {
        guard let currentUser = userManager.currentUser else { return }
        
        // 只清除当前用户类型的历史记录
        UserDefaults.standard.removeObject(forKey: StorageKeyUtils.getHistoryKey(for: userManager.currentUser))
        // 清除位置历史记录（按用户隔离）
        if let userId = userManager.currentUser?.id {
            UserDefaults.standard.removeObject(forKey: "locationHistory_\(userId)")
        }
        // 清除举报记录
        UserDefaults.standard.removeObject(forKey: StorageKeyUtils.getReportRecordsKey(for: userManager.currentUser))
        reportRecords.removeAll()
        // 清除黑名单记录（按用户隔离）
        if let userId = userManager.currentUser?.id {
            UserDefaults.standard.removeObject(forKey: "blacklistedUserIds_\(userId)")
        }
        // 清除喜欢记录
        UserDefaults.standard.removeObject(forKey: StorageKeyUtils.getFavoriteRecordsKey(for: userManager.currentUser))
        favoriteRecords.removeAll()
        // 清除点赞记录
        UserDefaults.standard.removeObject(forKey: getLikeRecordsKey())
        likeRecords.removeAll()
        
        // 🔧 修复：清除randomMatchHistory数组，确保主界面历史记录按钮同步更新
        randomMatchHistory.removeAll()
        
        // 清除用户操作缓存
        UserActionCacheManager.shared.clearUserCache(currentUserId: currentUser.userId)
        
        // 发送历史清除通知，确保所有相关界面都能同步更新
        NotificationCenter.default.post(name: .init("HistoryCleared"), object: nil)
        
        // 已清除当前用户类型的本地历史记录
    }
    
    /// 发送位置到服务器
    func sendLocationToServer() {
        if searchStartTime != nil {
        } else {
        }
        
        // 记录点击"寻找"按钮的开始时间
        searchStartTime = Date()
        // 🎯 新增：将开始时间存储到 UserDefaults，供后续计算时间差使用（按用户隔离）
        if let userId = UserDefaultsManager.getCurrentUserId() {
            let key = "SearchButtonClickTime_\(userId)"
            UserDefaults.standard.set(searchStartTime, forKey: key)
        }
        
        // 🎯 新增：点击寻找按钮时更新 LoginRecord
        updateLoginRecordForSearch()
        
        SearchUtils.sendLocationToServer(
            locationManager: locationManager,
            diamondManager: diamondManager,
            userManager: userManager,
            isLoading: $isLoading,
            resultMessage: $resultMessage,
            showRechargeSheet: $showRechargeSheet,
            searchStartTime: searchStartTime,
            skipDefaultEmailCheck: {
                // 🎯 修复：按userId隔离
                if let userId = UserDefaultsManager.getCurrentUserId() {
                    return UserDefaults.standard.bool(forKey: "shouldSkipDefaultEmailCheck_\(userId)")
                } else {
                    return UserDefaults.standard.bool(forKey: "shouldSkipDefaultEmailCheck")
                }
            }(), // 🎯 新增：传递跳过标志
            onLocationSent: {
                // 先刷新黑名单，然后开始寻找流程
                // 注意：refreshBlacklistAndHistory 是异步的，但这里不等待它完成就继续
                // 因为黑名单和历史记录的刷新可以在后台进行，不影响匹配流程
                _ = Date()
                self.refreshBlacklistAndHistory()
                
                // 继续原有的寻找流程
                if self.searchStartTime != nil {
                } else {
                }
                self.continueLocationSend()
            },
            onShowDefaultEmailAlert: {
                // 🎯 新增：通过通知显示默认邮箱提示
                NotificationCenter.default.post(name: NSNotification.Name("ShowDefaultEmailAlert"), object: nil)
            }
        )
    }
    
    // 🎯 新增：更新 LoginRecord（点击寻找按钮时调用）
    private func updateLoginRecordForSearch() {
        guard let currentUserId = UserDefaultsManager.getCurrentUserId() else {
            return
        }
        
        let userName = UserDefaultsManager.getCurrentUserName()
        let userEmail = UserDefaultsManager.getCurrentUserEmail()
        let loginType = UserDefaultsManager.getLoginType() ?? "guest"
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
        
        
        LeanCloudService.shared.recordLogin(
            userId: currentUserId,
            userName: userName,
            userEmail: userEmail.isEmpty ? nil : userEmail,
            loginType: loginType,
            deviceId: deviceId
        ) { success in
            if success {
            } else {
            }
        }
    }
    
    /// 静默清理位置记录
    func silentCleanLocationRecords() {
        // 静默执行位置记录清理
        
        // 获取当前用户ID
        guard let currentUserId = userManager.currentUser?.id else {
            // 无法获取当前用户ID
            return
        }
        
        // 当前用户ID
        
        // 获取所有位置记录
        LeanCloudService.shared.fetchAllLocationRecords { allRecords, error in
            DispatchQueue.main.async {
                if error != nil {
                    // 获取位置记录失败
                    return
                }
                
                guard let records = allRecords, !records.isEmpty else {
                    // 没有位置记录需要清理
                    return
                }
                
                // 获取到位置记录
                
                // 只过滤当前用户的记录
                let currentUserRecords = records.filter { $0.userId == currentUserId }
                
                if currentUserRecords.isEmpty {
                    // 当前用户没有位置记录需要清理
                    return
                }
                
                // 当前用户有位置记录
                
                // 如果当前用户只有一条记录，无需清理
                if currentUserRecords.count == 1 {
                    // 当前用户只有1条位置记录，无需清理
                    return
                }
                
                // 按时间戳排序，保留最新的
                let sortedRecords = currentUserRecords.sorted { record1, record2 in
                    let date1 = ISO8601DateFormatter().date(from: record1.timestamp) ?? Date.distantPast
                    let date2 = ISO8601DateFormatter().date(from: record2.timestamp) ?? Date.distantPast
                    return date1 > date2
                }
                
                // 保留最新的记录
                _ = sortedRecords.first!
                
                // 删除其他重复记录
                let recordsToDelete = Array(sortedRecords.dropFirst())
                
                // 当前用户位置记录清理
                
                // 执行删除操作
                if !recordsToDelete.isEmpty {
                    // 开始静默删除重复位置记录
                    
                    let recordIds = recordsToDelete.map { $0.objectId }
                    LeanCloudService.shared.deleteLocationRecords(recordIds: recordIds) { success, error in
                        DispatchQueue.main.async {
                            if success {
                                // 静默清理完成
                            } else {
                                // 静默清理失败
                            }
                        }
                    }
                } else {
                    // 当前用户位置记录已经是最优状态，无需清理
                }
            }
        }
    }
}



