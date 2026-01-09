import SwiftUI
import CoreLocation

struct SearchUtils {
    
    // MARK: - 搜索相关工具函数
    
    /// 发送位置到服务器进行搜索
    static func sendLocationToServer(
        locationManager: LocationManager,
        diamondManager: DiamondManager,
        userManager: UserManager,
        isLoading: Binding<Bool>,
        resultMessage: Binding<String>,
        showRechargeSheet: Binding<Bool>,
        searchStartTime: Date? = nil,
        skipDefaultEmailCheck: Bool = false, // 🎯 新增：是否跳过默认邮箱检查
        onLocationSent: @escaping () -> Void,
        onShowDefaultEmailAlert: ((() -> Void)?) = nil
    ) {
        // 🎯 修改：检查是否是默认邮箱，从 UserNameRecord 表查询邮箱
        if !skipDefaultEmailCheck, let userId = userManager.currentUser?.id, let loginType = userManager.currentUser?.loginType {
            // 🎯 新增：游客账号不提示设置真实邮箱
            if loginType == .guest {
                // 继续执行搜索
                SearchUtils.continueSearchAfterEmailCheck(
                    locationManager: locationManager,
                    diamondManager: diamondManager,
                    userManager: userManager,
                    isLoading: isLoading,
                    resultMessage: resultMessage,
                    showRechargeSheet: showRechargeSheet,
                    searchStartTime: searchStartTime,
                    onLocationSent: onLocationSent
                )
                return
            }
            
            // 🎯 修改：从 UserNameRecord 表查询邮箱（不依赖 loginType）
            LeanCloudService.shared.fetchUserEmailByUserId(objectId: userId) { email, error in
                DispatchQueue.main.async {
                    if error != nil {
                        // 查询失败时，继续执行搜索（不阻止用户操作）
                        SearchUtils.continueSearchAfterEmailCheck(
                            locationManager: locationManager,
                            diamondManager: diamondManager,
                            userManager: userManager,
                            isLoading: isLoading,
                            resultMessage: resultMessage,
                            showRechargeSheet: showRechargeSheet,
                            searchStartTime: searchStartTime,
                            onLocationSent: onLocationSent
                        )
                        return
                    }
                    
                    let currentEmail = email ?? ""
                    
                    let isDefaultEmail = currentEmail.hasSuffix("@internal.com") || 
                                       currentEmail.hasSuffix("@apple.com") || 
                                       currentEmail.hasSuffix("@guest.com")
                    
                    if currentEmail.isEmpty {
                        // 邮箱为空时，继续执行搜索
                        SearchUtils.continueSearchAfterEmailCheck(
                            locationManager: locationManager,
                            diamondManager: diamondManager,
                            userManager: userManager,
                            isLoading: isLoading,
                            resultMessage: resultMessage,
                            showRechargeSheet: showRechargeSheet,
                            searchStartTime: searchStartTime,
                            onLocationSent: onLocationSent
                        )
                        return
                    }
                    
                    if isDefaultEmail {
                        let clickCount = UserDefaultsManager.incrementDefaultEmailSearchClickCount(userId: userId)
                        
                        // 🎯 修改：每3次点击时提示，但17小时内不提示第二次
                        if clickCount % 3 == 0 {
                            // 检查是否在17小时内提示过
                            let hasShownRecently = UserDefaultsManager.hasShownAlertWithinOneMinute(userId: userId)
                            
                            if hasShownRecently {
                                // 继续执行搜索，不提示
                                SearchUtils.continueSearchAfterEmailCheck(
                                    locationManager: locationManager,
                                    diamondManager: diamondManager,
                                    userManager: userManager,
                                    isLoading: isLoading,
                                    resultMessage: resultMessage,
                                    showRechargeSheet: showRechargeSheet,
                                    searchStartTime: searchStartTime,
                                    onLocationSent: onLocationSent
                                )
                            } else {
                                // 记录提示时间
                                UserDefaultsManager.setLastDefaultEmailAlertTime(userId: userId)
                                
                                // 触发提示回调
                                if let callback = onShowDefaultEmailAlert {
                                    callback()
                                } else {
                                    // 回调不存在时，继续执行搜索
                                    SearchUtils.continueSearchAfterEmailCheck(
                                        locationManager: locationManager,
                                        diamondManager: diamondManager,
                                        userManager: userManager,
                                        isLoading: isLoading,
                                        resultMessage: resultMessage,
                                        showRechargeSheet: showRechargeSheet,
                                        searchStartTime: searchStartTime,
                                        onLocationSent: onLocationSent
                                    )
                                }
                                return // 不继续执行搜索，先显示提示
                            }
                        } else {
                            // 继续执行搜索
                            SearchUtils.continueSearchAfterEmailCheck(
                                locationManager: locationManager,
                                diamondManager: diamondManager,
                                userManager: userManager,
                                isLoading: isLoading,
                                resultMessage: resultMessage,
                                showRechargeSheet: showRechargeSheet,
                                searchStartTime: searchStartTime,
                                onLocationSent: onLocationSent
                            )
                        }
                    } else {
                        // 不是默认邮箱，继续执行搜索
                        SearchUtils.continueSearchAfterEmailCheck(
                            locationManager: locationManager,
                            diamondManager: diamondManager,
                            userManager: userManager,
                            isLoading: isLoading,
                            resultMessage: resultMessage,
                            showRechargeSheet: showRechargeSheet,
                            searchStartTime: searchStartTime,
                            onLocationSent: onLocationSent
                        )
                    }
                }
            }
            // 注意：由于是异步查询，这里直接 return，实际的搜索逻辑在回调中执行
            return
        }
        
        // 如果跳过检查或userId不存在，继续执行原有的搜索逻辑
        continueSearchAfterEmailCheck(
            locationManager: locationManager,
            diamondManager: diamondManager,
            userManager: userManager,
            isLoading: isLoading,
            resultMessage: resultMessage,
            showRechargeSheet: showRechargeSheet,
            searchStartTime: searchStartTime,
            onLocationSent: onLocationSent
        )
    }
    
    // 🎯 新增：继续执行搜索逻辑（将原有逻辑提取为独立方法）
    private static func continueSearchAfterEmailCheck(
        locationManager: LocationManager,
        diamondManager: DiamondManager,
        userManager: UserManager,
        isLoading: Binding<Bool>,
        resultMessage: Binding<String>,
        showRechargeSheet: Binding<Bool>,
        searchStartTime: Date?,
        onLocationSent: @escaping () -> Void
    ) {
        // 如果本地余额为0，从服务器重新确认
        diamondManager.checkDiamondsWithServerConfirmation(2) { hasEnough in
            if !hasEnough {
                showRechargeSheet.wrappedValue = true
                return
            }
            
            // 余额确认充足，开始寻找流程
            isLoading.wrappedValue = true
            resultMessage.wrappedValue = ""
            
            // 首先请求更新位置信息
            locationManager.requestLocation()
            
            // 继续原有的寻找流程
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                onLocationSent()
            }
        }
    }
    
    /// 获取随机位置记录
    static func fetchRandomRecord(
        locationManager: LocationManager,
        userManager: UserManager,
        diamondManager: DiamondManager,
        randomMatchHistory: [RandomMatchHistory],
        blacklistedUserIds: [String] = [],
        pendingDeletionUserIds: [String] = [],
        isLoadingRandomRecord: Binding<Bool>,
        randomRecord: Binding<LocationRecord?>,
        randomRecordNumber: Binding<Int>,
        searchStartTime: Date? = nil,
        onRecordFetched: @escaping (LocationRecord?) -> Void,
        onAvatarRefresh: @escaping () -> Void,
        onHistoryAdd: @escaping (LocationRecord, Int) -> Void,
        onLocationClean: @escaping () -> Void,
        retryCount: Int = 0
    ) {
        isLoadingRandomRecord.wrappedValue = true
        randomRecord.wrappedValue = nil // 清除之前的记录
        randomRecordNumber.wrappedValue = 0 // 重置序号
        
        // 先获取所有记录以确定总数
        LeanCloudService.shared.fetchLocations { records, error in
            DispatchQueue.main.async {
                if error != nil {
                    isLoadingRandomRecord.wrappedValue = false
                    return
                }
                
                let totalRecords = records?.count ?? 0
                
                // 使用LeanCloud服务获取随机位置记录
                let currentLocation = locationManager.location?.coordinate
                let currentUserId = userManager.currentUser?.id
                
                LeanCloudService.shared.fetchRandomLocation(
                    currentLocation: currentLocation,
                    currentUserId: currentUserId,
                    excludeHistory: randomMatchHistory,
                    blacklistedIds: blacklistedUserIds,
                    pendingDeletionIds: pendingDeletionUserIds
                ) { record, error in
                    DispatchQueue.main.async {
                        isLoadingRandomRecord.wrappedValue = false
                        
                        if error != nil {
                            // 匹配失败，不扣除钻石
                            onRecordFetched(nil)
                        } else if let record = record {
                            // 🎯 修复：成功匹配到用户后，才扣除钻石
                            diamondManager.spendDiamonds(2) { success in
                                if success {
                                    // 钻石扣除成功，设置匹配结果
                                    randomRecord.wrappedValue = record
                                    
                                    // 为随机记录分配一个序号（1到总数之间）
                                    randomRecordNumber.wrappedValue = Int.random(in: 1...max(1, totalRecords))
                                    
                                    // 匹配成功后刷新头像缓存
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        onAvatarRefresh()
                                    }
                                    
                                    onRecordFetched(record)
                                    onHistoryAdd(record, randomRecordNumber.wrappedValue)
                                } else {
                                    // 钻石扣除失败，不设置匹配结果
                                    onRecordFetched(nil)
                                }
                            }
                            return
                        } else {
                            // 没有匹配到用户，自动重试一次
                            if retryCount == 0 {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0/17.0) {
                                    fetchRandomRecord(
                                        locationManager: locationManager,
                                        userManager: userManager,
                                        diamondManager: diamondManager,
                                        randomMatchHistory: randomMatchHistory,
                                        isLoadingRandomRecord: isLoadingRandomRecord,
                                        randomRecord: randomRecord,
                                        randomRecordNumber: randomRecordNumber,
                                        searchStartTime: searchStartTime,
                                        onRecordFetched: onRecordFetched,
                                        onAvatarRefresh: onAvatarRefresh,
                                        onHistoryAdd: onHistoryAdd,
                                        onLocationClean: onLocationClean,
                                        retryCount: retryCount + 1
                                    )
                                }
                            } else {
                                // 重试后仍未找到，不扣除钻石
                                onRecordFetched(nil)
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// 设置匹配结果
    static func setMatchResult(
        record: LocationRecord,
        diamondManager: DiamondManager,
        randomRecord: Binding<LocationRecord?>,
        randomRecordNumber: Binding<Int>
    ) {
        // 🎯 修改：钻石已在updateUserScoreLocation中扣除，这里直接设置匹配结果
        randomRecord.wrappedValue = record
        randomRecordNumber.wrappedValue = 1
    }
    
    /// 显示历史匹配
    static func showHistoricalMatch(
        record: LocationRecord,
        randomRecord: Binding<LocationRecord?>,
        randomRecordNumber: Binding<Int>
    ) {
        // 🎯 新增：计算从点击寻找按钮到出现匹配对象的时间（按用户隔离）
        if let userId = UserDefaultsManager.getCurrentUserId() {
            let key = "SearchButtonClickTime_\(userId)"
            if UserDefaults.standard.object(forKey: key) as? Date != nil {
                // 清除 UserDefaults 中的时间记录，避免下次误用
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        
        // 设置匹配结果（不扣除钻石）
        randomRecord.wrappedValue = record
        randomRecordNumber.wrappedValue = 1
    }
    
    /// 添加到所有好友匹配结果
    static func addToAllFriendsMatchResults(
        record: LocationRecord,
        allFriendsMatchResults: Binding<[LocationRecord]>
    ) {
        // 检查是否已存在相同的匹配结果（避免重复）
        let existingIndex = allFriendsMatchResults.wrappedValue.firstIndex { $0.userId == record.userId }
        if let index = existingIndex {
            allFriendsMatchResults.wrappedValue[index] = record
        } else {
            allFriendsMatchResults.wrappedValue.append(record)
        }
    }
    
    // MARK: - 历史记录管理
    
    /// 保存随机匹配历史
    static func saveRandomMatchHistory(
        randomMatchHistory: [RandomMatchHistory],
        userManager: UserManager
    ) {
        if let data = try? JSONEncoder().encode(randomMatchHistory) {
            UserDefaults.standard.set(data, forKey: StorageKeyUtils.getHistoryKey(for: userManager.currentUser))
        }
    }
    
    /// 从本地加载随机匹配历史
    static func loadRandomMatchHistory(
        userManager: UserManager,
        blacklistedUserIds: [String],
        pendingDeletionUserIds: [String],
        randomMatchHistory: Binding<[RandomMatchHistory]>
    ) {
        // 先清空当前历史记录数组，确保不会显示上一个账号的历史
        randomMatchHistory.wrappedValue.removeAll()
        
        let historyKey = StorageKeyUtils.getHistoryKey(for: userManager.currentUser)
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let history = try? JSONDecoder().decode([RandomMatchHistory].self, from: data) {
            // 过滤掉黑名单用户和设备的记录，以及待删除账号用户（与排行榜逻辑一致）
            // 🎯 新增：获取本地黑名单
            let localBlacklistStartTime = Date()
            let localBlacklistedUserIds = LocalBlacklistManager.shared.getAllLocalBlacklistedUserIds()
            let localBlacklistTime = Date().timeIntervalSince(localBlacklistStartTime)
            if localBlacklistTime > 0.01 {
            }
            
            let filterStartTime = Date()
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
            let filterTime = Date().timeIntervalSince(filterStartTime)
            if filterTime > 0.01 {
            }
            
            randomMatchHistory.wrappedValue = filteredHistory
            
            // 如果过滤后有变化，保存过滤后的历史记录
            if filteredHistory.count != history.count {
                saveRandomMatchHistory(
                    randomMatchHistory: filteredHistory,
                    userManager: userManager
                )
            }
        } else {
            // 如果没有找到历史记录，确保数组为空
            randomMatchHistory.wrappedValue = []
        }
    }
    
    /// 添加新的随机匹配记录
    static func addRandomMatchToHistory(
        record: LocationRecord,
        recordNumber: Int,
        locationManager: LocationManager,
        blacklistedUserIds: [String],
        pendingDeletionUserIds: [String],
        randomMatchHistory: Binding<[RandomMatchHistory]>,
        userManager: UserManager
    ) {
        // 检查是否在黑名单中或待删除账号（与排行榜逻辑一致）
        // 🎯 新增：检查本地黑名单
        let localBlacklistStartTime = Date()
        let localBlacklistedUserIds = LocalBlacklistManager.shared.getAllLocalBlacklistedUserIds()
        let isLocalBlacklisted = localBlacklistedUserIds.contains(record.userId)
        let localBlacklistTime = Date().timeIntervalSince(localBlacklistStartTime)
        if localBlacklistTime > 0.01 {
        }
        
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
        
        if isLocalBlacklisted || isBlacklisted || isPendingDeletion {
            // 用户在本地黑名单、服务器黑名单或待删除账号，跳过添加
            return
        }
        
        // 检查是否已经存在该用户的历史记录（避免重复）
        let existingIndex = randomMatchHistory.wrappedValue.firstIndex { $0.record.userId == record.userId }
        if let index = existingIndex {
            // 如果已存在，移除旧记录，添加新记录（移动到最前面）
            randomMatchHistory.wrappedValue.remove(at: index)
            let currentLocation = locationManager.location?.coordinate
            let newHistory = RandomMatchHistory(record: record, recordNumber: recordNumber, currentLocation: currentLocation)
            randomMatchHistory.wrappedValue.insert(newHistory, at: 0)
        } else {
            // 如果不存在，添加新记录
            let currentLocation = locationManager.location?.coordinate
            let newHistory = RandomMatchHistory(record: record, recordNumber: recordNumber, currentLocation: currentLocation)
            randomMatchHistory.wrappedValue.insert(newHistory, at: 0) // 插入到开头
        }
        
        // 限制历史记录数量，最多保存217条
        // 🎯 修改：删除多余记录的方式与清除按钮删除全部记录的方式完全一致
        if randomMatchHistory.wrappedValue.count > 217 {
            randomMatchHistory.wrappedValue = Array(randomMatchHistory.wrappedValue.prefix(217))
            
            // 与清除按钮一致：保存到UserDefaults
            saveRandomMatchHistory(
                randomMatchHistory: randomMatchHistory.wrappedValue,
                userManager: userManager
            )
            
            // 与清除按钮一致：发送历史清除通知，确保所有相关界面都能同步更新
            NotificationCenter.default.post(name: .init("HistoryCleared"), object: nil)
        } else {
            saveRandomMatchHistory(
                randomMatchHistory: randomMatchHistory.wrappedValue,
                userManager: userManager
            )
        }
    }
    
    /// 清除随机匹配历史
    static func clearRandomMatchHistory(
        userManager: UserManager,
        randomMatchHistory: Binding<[RandomMatchHistory]>,
        reportRecords: Binding<[ReportRecord]>,
        onLikedRecordsClear: @escaping () -> Void
    ) {
        // 🚀 优化：立即更新UI，提供即时反馈
        randomMatchHistory.wrappedValue.removeAll()
        reportRecords.wrappedValue.removeAll()
        
        // 清除本地的点赞记录（同步执行，因为可能需要在UI中立即反映）
        onLikedRecordsClear()
        
        // 🚀 优化：将UserDefaults删除操作移到后台线程，避免阻塞UI
        let historyKey = StorageKeyUtils.getHistoryKey(for: userManager.currentUser)
        let reportKey = StorageKeyUtils.getReportRecordsKey(for: userManager.currentUser)
        
        DispatchQueue.global(qos: .userInitiated).async {
            // 只清除当前用户类型的历史记录
            UserDefaults.standard.removeObject(forKey: historyKey)
            
            // 清除举报记录
            UserDefaults.standard.removeObject(forKey: reportKey)
            
            // 在主线程发送通知，确保UI更新
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .init("HistoryCleared"), object: nil)
            }
        }
    }
    
    /// 删除单个随机匹配历史记录
    static func deleteRandomMatchHistoryItem(
        _ historyItem: RandomMatchHistory,
        randomMatchHistory: Binding<[RandomMatchHistory]>,
        userManager: UserManager
    ) {
        if let index = randomMatchHistory.wrappedValue.firstIndex(where: { $0.id == historyItem.id }) {
            randomMatchHistory.wrappedValue.remove(at: index)
            saveRandomMatchHistory(
                randomMatchHistory: randomMatchHistory.wrappedValue,
                userManager: userManager
            )
        }
    }
    
    // MARK: - 举报记录管理
    
    /// 保存举报记录到本地
    static func saveReportRecords(
        reportRecords: [ReportRecord],
        userManager: UserManager
    ) {
        if let data = try? JSONEncoder().encode(reportRecords) {
            UserDefaults.standard.set(data, forKey: StorageKeyUtils.getReportRecordsKey(for: userManager.currentUser))
        }
    }
    
    /// 从本地加载举报记录
    static func loadReportRecords(
        userManager: UserManager,
        reportRecords: Binding<[ReportRecord]>
    ) {
        let reportKey = StorageKeyUtils.getReportRecordsKey(for: userManager.currentUser)
        if let data = UserDefaults.standard.data(forKey: reportKey),
           let records = try? JSONDecoder().decode([ReportRecord].self, from: data) {
            reportRecords.wrappedValue = records
        } else {
            reportRecords.wrappedValue = []
        }
    }
    
    // MARK: - 地图选择
    
    /// 显示地图选择弹窗
    static func showMapSelectionForLocation(
        record: LocationRecord,
        latestUserNames: [String: String]
    ) {
        
        // 这里可以添加地图选择逻辑
        // 目前只是占位符
    }
    
    // MARK: - 静默清理
    
    /// 静默执行位置记录清理
    static func silentCleanLocationRecords() {
        // 静默执行位置记录清理
        // 这里可以添加清理逻辑
    }
}
