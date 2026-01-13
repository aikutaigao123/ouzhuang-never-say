//
//  LegacySearchView+HistoryManagement.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//

import Foundation

// MARK: - History Management Extension
extension LegacySearchView {
    
    /// 保存随机匹配历史到本地
    func saveRandomMatchHistory() {
        let historyKey = StorageKeyUtils.getHistoryKey(for: userManager.currentUser)
        
        if let data = try? JSONEncoder().encode(randomMatchHistory) {
            UserDefaults.standard.set(data, forKey: historyKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    /// 从本地加载随机匹配历史
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
                
                return !isLocalBlacklisted && !isBlacklisted && !isPendingDeletion
            }
            
            randomMatchHistory = filteredHistory
            
            // 如果过滤后有变化，保存过滤后的历史记录
            if filteredHistory.count != history.count {
                saveRandomMatchHistory()
            }
        } else {
            // 如果没有找到历史记录，确保数组为空
            randomMatchHistory = []
        }
    }
    
    /// 添加新的随机匹配记录
    func addRandomMatchToHistory(record: LocationRecord, recordNumber: Int) {
        // 检查是否在黑名单中或待删除账号（与排行榜逻辑一致）
        // 检查黑名单：同时检查用户ID、用户名和设备ID（与排行榜一致）
        let isBlacklisted =
            blacklistedUserIds.contains(record.userId) ||
            (record.userName != nil && blacklistedUserIds.contains(record.userName!)) ||
            blacklistedUserIds.contains(record.deviceId)
        
        // 检查待删除账号：检查用户ID、用户名和设备ID（与排行榜一致）
        let isPendingDeletion =
            pendingDeletionUserIds.contains(record.userId) ||
            (record.userName != nil && pendingDeletionUserIds.contains(record.userName!)) ||
            pendingDeletionUserIds.contains(record.deviceId)
        
        if isBlacklisted || isPendingDeletion {
            // 用户在黑名单中或待删除账号，跳过添加
            return
        }
        
        // 检查是否已经存在该用户的历史记录（避免重复）
        let existingIndex = randomMatchHistory.firstIndex { $0.record.userId == record.userId }
        if let index = existingIndex {
            // 如果已存在，移除旧记录，添加新记录（移动到最前面）
            let oldRecord = randomMatchHistory[index].record
            
            // 🔧 修复：如果旧记录是推荐卡片（有placeName或reason），而新记录是个人匹配卡片（没有placeName和reason），
            // 应该保留旧记录的推荐信息，避免推荐卡片信息丢失
            let oldIsRecommendation = (oldRecord.placeName?.isEmpty == false) || (oldRecord.reason?.isEmpty == false)
            let newIsRecommendation = (record.placeName?.isEmpty == false) || (record.reason?.isEmpty == false)
            
            let finalRecord: LocationRecord
            if oldIsRecommendation && !newIsRecommendation {
                // 旧记录是推荐卡片，新记录是个人匹配卡片，保留推荐信息
                finalRecord = LocationRecord(
                    id: record.id,
                    objectId: record.objectId,
                    timestamp: record.timestamp,
                    latitude: record.latitude,
                    longitude: record.longitude,
                    accuracy: record.accuracy,
                    userId: record.userId,
                    userName: record.userName,
                    loginType: record.loginType,
                    userEmail: record.userEmail,
                    userAvatar: record.userAvatar,
                    deviceId: record.deviceId,
                    clientTimestamp: record.clientTimestamp,
                    timezone: record.timezone,
                    status: record.status,
                    recordCount: record.recordCount,
                    likeCount: record.likeCount,
                    placeName: oldRecord.placeName, // 保留旧记录的placeName
                    reason: oldRecord.reason // 保留旧记录的reason
                )
            } else {
                // 其他情况，使用新记录
                finalRecord = record
            }
            
            randomMatchHistory.remove(at: index)
            let currentLocation = locationManager.location?.coordinate
            let newHistory = RandomMatchHistory(record: finalRecord, recordNumber: recordNumber, currentLocation: currentLocation)
            randomMatchHistory.insert(newHistory, at: 0)
        } else {
            // 如果不存在，添加新记录
            let currentLocation = locationManager.location?.coordinate
            let newHistory = RandomMatchHistory(record: record, recordNumber: recordNumber, currentLocation: currentLocation)
            randomMatchHistory.insert(newHistory, at: 0) // 插入到开头
        }
        
        // 限制历史记录数量，最多保存217条
        // 🎯 修改：删除多余记录的方式与清除按钮删除全部记录的方式完全一致
        if randomMatchHistory.count > 217 {
            randomMatchHistory = Array(randomMatchHistory.prefix(217))
            
            // 与清除按钮一致：保存到UserDefaults
            saveRandomMatchHistory()
            
            // 与清除按钮一致：发送历史清除通知，确保所有相关界面都能同步更新
            NotificationCenter.default.post(name: .init("HistoryCleared"), object: nil)
        } else {
            saveRandomMatchHistory()
        }
    }
    
    /// 清除随机匹配历史
    func clearRandomMatchHistory() {
        
        randomMatchHistory.removeAll()
        
        // 只清除当前用户类型的历史记录
        UserDefaults.standard.removeObject(forKey: StorageKeyUtils.getHistoryKey(for: userManager.currentUser))
        
        // 清除举报记录
        UserDefaults.standard.removeObject(forKey: StorageKeyUtils.getReportRecordsKey(for: userManager.currentUser))
        reportRecords.removeAll()
        
        // 清除本地的点赞记录
        clearLikedLocationRecords()
        
        // 发送历史清除通知
        NotificationCenter.default.post(name: .init("HistoryCleared"), object: nil)
    }
}

