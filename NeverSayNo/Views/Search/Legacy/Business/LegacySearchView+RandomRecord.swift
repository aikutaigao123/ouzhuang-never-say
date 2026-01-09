//
//  LegacySearchView+RandomRecord.swift
//  NeverSayNo
//
//  Created by Assistant on 2024.
//

import Foundation
import CoreLocation

// MARK: - Random Record Fetching Extension
extension LegacySearchView {
    
    /// 获取随机记录
    func fetchRandomRecord() {
        
        // 🎯 新增：增加点击计数器
        searchButtonClickCount += 1
        
        // 🎯 新增：每2次点击后，随机显示一条推荐榜匹配卡片（钻石在位置上传时扣除）
        if searchButtonClickCount % 2 == 0 {
            
            // 🎯 获取当前位置（GCJ-02坐标）用于地理范围查询
            var currentLatitude: Double? = nil
            var currentLongitude: Double? = nil
            if let userLocation = locationManager.location {
                
                // 将WGS-84转换为GCJ-02用于查询（Recommendation表中的坐标是GCJ-02）
                let (gcjLat, gcjLon) = CoordinateConverter.wgs84ToGcj02(
                    latitude: userLocation.coordinate.latitude,
                    longitude: userLocation.coordinate.longitude
                )
                currentLatitude = gcjLat
                currentLongitude = gcjLon
                
            } else {
            }
            
            // 🎯 修改：第二次点击查询推荐榜时，只查询±0.3度范围（固定范围，不扩展）
            if let lat = currentLatitude, let lon = currentLongitude {
                
                // 有位置信息时，使用固定±0.3度范围查询
                LeanCloudService.shared.fetchRecommendationsWithFixedRange(
                    currentLatitude: lat,
                    currentLongitude: lon,
                    range: 0.3  // 固定范围±0.3度
                ) { records, error in
                    self.handleRecommendationQueryResult(records: records, error: error)
                }
            } else {
                
                // 无位置信息时，使用全量查询
                LeanCloudService.shared.fetchAllRecommendations(
                    currentLatitude: nil,
                    currentLongitude: nil
                ) { records, error in
                    self.handleRecommendationQueryResult(records: records, error: error)
                }
            }
        } else {
            // 不是每2次，执行正常的匹配流程
            fetchNormalRandomRecord()
        }
    }
    
    /// 处理推荐榜查询结果
    func handleRecommendationQueryResult(records: [LocationRecord]?, error: String?, isFromPersonalMatch: Bool = false) {
        DispatchQueue.main.async {
            
            // 🎯 修改：如果推荐榜查询失败或为空，直接执行原逻辑查询LocationRecord
            if error != nil {
                // 查询失败
                if isFromPersonalMatch {
                    // 🎯 新增：如果是从个人匹配回退过来的，不再回退到个人匹配，避免无限循环
                    self.isLoadingRandomRecord = false
                    return
                } else {
                    // 正常流程：取消此次查询推荐榜，直接执行原逻辑
                    self.fetchNormalRandomRecord()
                    return
                }
            }
            
            guard let records = records, !records.isEmpty else {
                // 推荐榜为空
                if isFromPersonalMatch {
                    // 🎯 新增：如果是从个人匹配回退过来的，不再回退到个人匹配，避免无限循环
                    self.isLoadingRandomRecord = false
                    return
                } else {
                    // 正常流程：取消此次查询推荐榜，直接执行原逻辑
                    self.fetchNormalRandomRecord()
                    return
                }
            }
            
            
            // 🎯 过滤掉历史记录、黑名单和待删除账号
            // 🔧 修复：寻找推荐卡片时，只根据历史记录中的推荐卡片进行过滤
            // 提取历史记录中的推荐卡片的objectId集合和userId集合
            var excludedObjectIds = Set<String>()
            var excludedUserIds = Set<String>()
            
            // 🔧 新增：只使用历史记录中的推荐卡片进行过滤
            
            let recommendationHistory = self.randomMatchHistory.filter { historyItem in
                let record = historyItem.record
                // 🔧 修复：正确处理可选值，确保推荐卡片被正确识别
                let placeNameIsEmpty = record.placeName?.isEmpty ?? true
                let reasonIsEmpty = record.reason?.isEmpty ?? true
                let isRecommendation = !placeNameIsEmpty || !reasonIsEmpty
                return isRecommendation
            }
            
            for historyItem in recommendationHistory {
                let record = historyItem.record
                
                if !record.objectId.isEmpty {
                    // 推荐榜记录：基于objectId过滤
                    excludedObjectIds.insert(record.objectId)
                }
                // 🔧 注意：如果历史记录中有该用户的推荐卡片，也应该排除该用户的所有推荐卡片
                // 因为已经匹配过该用户的推荐卡片，不应该再匹配该用户的其他推荐卡片
                excludedUserIds.insert(record.userId)
            }
            
            
            // 统计过滤原因
            var excludedByHistoryObjectId = 0  // 推荐榜记录（基于objectId）
            var excludedByHistoryUserId = 0  // 普通记录（基于userId）
            var excludedByBlacklist = 0
            var excludedByPendingDeletion = 0
            var excludedByCurrentUser = 0
            
            let filteredRecords = records.filter { record in
                // 🔧 修复：推荐榜记录基于objectId过滤，允许同一用户的不同推荐卡片
                // 判断当前记录是否为推荐榜记录
                let isRecommendation = (record.placeName?.isEmpty == false) || (record.reason?.isEmpty == false)
                
                
                if isRecommendation {
                    // 🔧 修复：推荐榜记录只基于objectId过滤，允许同一用户的不同推荐卡片
                    // 检查objectId是否在历史记录中（推荐榜匹配记录）
                    if excludedObjectIds.contains(record.objectId) {
                        excludedByHistoryObjectId += 1
                        return false
                    }
                    // 🔧 注意：如果历史记录中有该用户的推荐卡片，排除该用户的所有推荐卡片
                    // 因为已经匹配过该用户的推荐卡片，不应该再匹配该用户的其他推荐卡片
                    if excludedUserIds.contains(record.userId) {
                        excludedByHistoryUserId += 1
                        return false
                    }
                } else {
                    // 普通记录：基于userId过滤
                    if excludedUserIds.contains(record.userId) {
                        excludedByHistoryUserId += 1
                        return false
                    }
                }
                
                // 🎯 新增：检查本地黑名单
                let localBlacklistedUserIds = LocalBlacklistManager.shared.getAllLocalBlacklistedUserIds()
                let isLocalBlacklisted = localBlacklistedUserIds.contains(record.userId)
                
                let isBlacklisted = self.blacklistedUserIds.contains(record.userId) ||
                    (record.userName != nil && self.blacklistedUserIds.contains(record.userName!)) ||
                    self.blacklistedUserIds.contains(record.deviceId)
                
                if isLocalBlacklisted || isBlacklisted {
                    excludedByBlacklist += 1
                }
                
                let isPendingDeletion = self.pendingDeletionUserIds.contains(record.userId) ||
                    (record.userName != nil && self.pendingDeletionUserIds.contains(record.userName!)) ||
                    self.pendingDeletionUserIds.contains(record.deviceId)
                
                if isPendingDeletion {
                    excludedByPendingDeletion += 1
                }
                
                // 排除当前用户
                let isCurrentUser = record.userId == self.userManager.currentUser?.id
                if isCurrentUser {
                    excludedByCurrentUser += 1
                }
                
                return !isLocalBlacklisted && !isBlacklisted && !isPendingDeletion && !isCurrentUser
            }
            
            
            if !filteredRecords.isEmpty {
                
                // 随机选择一条推荐榜记录
                let randomIndex = Int.random(in: 0..<filteredRecords.count)
                let selectedRecord = filteredRecords[randomIndex]
                
                // 🎯 修复：推荐榜匹配成功后，也要扣除钻石
                self.diamondManager.spendDiamonds(2) { success in
                    if success {
                        // 钻石扣除成功，显示匹配卡片
                        self.isLoadingRandomRecord = false
                        self.showHistoricalMatch(record: selectedRecord)
                        
                        // 刷新头像
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.refreshSearchViewAvatars()
                        }
                        
                        // 添加到历史记录
                        self.addRandomMatchToHistory(record: selectedRecord, recordNumber: 1)
                        
                        // 🎯 修复：扣除钻石后，更新 UserScore 的 totalScore
                        if let location = self.locationManager.location,
                           let userId = self.userManager.currentUser?.id,
                           let userName = self.userManager.currentUser?.fullName {
                            let loginType: String
                            switch self.userManager.currentUser?.loginType {
                            case .apple: loginType = "apple"
                            case .guest: loginType = "guest"
                            case .none: loginType = "guest"
                            }
                            let userEmail = self.userManager.currentUser?.email
                            
                            // 获取头像
                            LeanCloudService.shared.fetchUserAvatarByUserId(objectId: userId) { avatar, _ in
                                let userAvatar = avatar ?? UserAvatarUtils.defaultAvatar(for: loginType)
                                
                                // 更新 UserScore（包含扣除后的钻石数）
                                DispatchQueue.global(qos: .utility).async {
                                    self.updateUserScoreLocation(
                                        location: location,
                                        userId: userId,
                                        userName: userName,
                                        loginType: loginType,
                                        userEmail: userEmail,
                                        avatar: userAvatar
                                    ) { success in
                                        if success {
                                        } else {
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        self.isLoadingRandomRecord = false
                    }
                }
            } else {
                // 过滤后没有有效记录
                if isFromPersonalMatch {
                    // 🎯 新增：如果是从个人匹配回退过来的，不再回退到个人匹配，避免无限循环
                    self.isLoadingRandomRecord = false
                } else {
                    // 正常流程：取消此次查询推荐榜，直接执行原逻辑
                    self.fetchNormalRandomRecord()
                }
            }
        }
    }
    
    /// 🎯 新增：查询推荐匹配（用于个人匹配失败时的回退）
    func fetchRecommendationMatch() {
        // 获取当前位置（GCJ-02坐标）用于地理范围查询
        var currentLatitude: Double? = nil
        var currentLongitude: Double? = nil
        if let userLocation = locationManager.location {
            // 将WGS-84转换为GCJ-02用于查询（Recommendation表中的坐标是GCJ-02）
            let (gcjLat, gcjLon) = CoordinateConverter.wgs84ToGcj02(
                latitude: userLocation.coordinate.latitude,
                longitude: userLocation.coordinate.longitude
            )
            currentLatitude = gcjLat
            currentLongitude = gcjLon
        }
        
        // 查询推荐榜
        if let lat = currentLatitude, let lon = currentLongitude {
            // 有位置信息时，使用固定±0.3度范围查询
            LeanCloudService.shared.fetchRecommendationsWithFixedRange(
                currentLatitude: lat,
                currentLongitude: lon,
                range: 0.3  // 固定范围±0.3度
            ) { records, error in
                // 🎯 新增：标记这是从个人匹配回退过来的，防止无限循环
                self.handleRecommendationQueryResult(records: records, error: error, isFromPersonalMatch: true)
            }
        } else {
            // 无位置信息时，使用全量查询
            LeanCloudService.shared.fetchAllRecommendations(
                currentLatitude: nil,
                currentLongitude: nil
            ) { records, error in
                // 🎯 新增：标记这是从个人匹配回退过来的，防止无限循环
                self.handleRecommendationQueryResult(records: records, error: error, isFromPersonalMatch: true)
            }
        }
    }
    
    /// 获取正常的随机匹配记录
    func fetchNormalRandomRecord() {
        // 重新加载历史记录以确保数据是最新的
        loadRandomMatchHistory()
        
        // 获取搜索开始时间（从 LegacySearchView 的 searchStartTime 获取）
        let startTime = self.searchStartTime
        
        SearchUtils.fetchRandomRecord(
            locationManager: locationManager,
            userManager: userManager,
            diamondManager: diamondManager,
            randomMatchHistory: randomMatchHistory,
            blacklistedUserIds: blacklistedUserIds,
            pendingDeletionUserIds: pendingDeletionUserIds,
            isLoadingRandomRecord: $isLoadingRandomRecord,
            randomRecord: $randomRecord,
            randomRecordNumber: $randomRecordNumber,
            searchStartTime: startTime,
            onRecordFetched: { record in
                if record != nil {
                    // 🎯 修复：匹配成功并扣除钻石后，更新 UserScore 的 totalScore
                    // 需要获取最近的位置信息来更新 UserScore
                    if let location = self.locationManager.location,
                       let userId = self.userManager.currentUser?.id,
                       let userName = self.userManager.currentUser?.fullName {
                        let loginType: String
                        switch self.userManager.currentUser?.loginType {
                        case .apple: loginType = "apple"
                        case .guest: loginType = "guest"
                        case .none: loginType = "guest"
                        }
                        let userEmail = self.userManager.currentUser?.email
                        
                        // 获取头像
                        LeanCloudService.shared.fetchUserAvatarByUserId(objectId: userId) { avatar, _ in
                            let userAvatar = avatar ?? UserAvatarUtils.defaultAvatar(for: loginType)
                            
                            // 更新 UserScore（包含扣除后的钻石数）
                            DispatchQueue.global(qos: .utility).async {
                                self.updateUserScoreLocation(
                                    location: location,
                                    userId: userId,
                                    userName: userName,
                                    loginType: loginType,
                                    userEmail: userEmail,
                                    avatar: userAvatar
                                ) { success in
                                    if success {
                                    } else {
                                    }
                                }
                            }
                        }
                    }
                } else {
                    // 🎯 新增：如果个人匹配失败，回退到推荐匹配
                    self.fetchRecommendationMatch()
                }
            },
            onAvatarRefresh: {
                                self.refreshSearchViewAvatars()
            },
            onHistoryAdd: { record, recordNumber in
                self.addRandomMatchToHistory(record: record, recordNumber: recordNumber)
            },
            onLocationClean: {
                                self.silentCleanLocationRecords()
                            }
        )
    }
}

