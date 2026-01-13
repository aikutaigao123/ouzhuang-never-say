import Foundation
import SwiftUI

// 统一的 UserDefaults 管理器
class UserDefaultsManager {
    
    // MARK: - 用户头像管理
    static func getCustomAvatar(userId: String) -> String? {
        let key = "custom_avatar_\(userId)"
        let avatar = UserDefaults.standard.string(forKey: key)
        return avatar
    }
    
    static func setCustomAvatar(userId: String, emoji: String) {
        UserDefaults.standard.set(emoji, forKey: "custom_avatar_\(userId)")
    }
    
    static func getCustomAvatarWithDefault(userId: String, defaultEmoji: String = "person.circle") -> String {
        return UserDefaults.standard.string(forKey: "custom_avatar_\(userId)") ?? defaultEmoji
    }
    
    // MARK: - 钻石管理（类似于用户头像界面的缓存机制）
    static func getCustomDiamonds(userId: String) -> Int? {
        let key = "custom_diamonds_\(userId)"
        let diamonds = UserDefaults.standard.integer(forKey: key)
        // 如果值为0，可能是确实为0或者不存在，需要区分
        if diamonds == 0 && UserDefaults.standard.object(forKey: key) == nil {
            return nil
        }
        return diamonds
    }
    
    static func setCustomDiamonds(userId: String, diamonds: Int) {
        UserDefaults.standard.set(diamonds, forKey: "custom_diamonds_\(userId)")
    }
    
    // MARK: - 用户时间缓存管理（存储原始时间，显示时根据当前时间格式化）
    /// 获取用户的最近上线时间缓存（返回原始时间Date，显示时再格式化）
    static func getUserLastOnlineTime(userId: String) -> Date? {
        // 🎯 修改：直接返回Date对象，而不是格式化文本
        if let timestamp = UserDefaults.standard.object(forKey: "user_last_online_time_\(userId)") as? Date {
            return timestamp
        }
        // 兼容旧数据：如果存储的是字符串格式，尝试清理
        if UserDefaults.standard.string(forKey: "user_last_online_time_\(userId)") != nil {
            // 清除旧格式的缓存
            UserDefaults.standard.removeObject(forKey: "user_last_online_time_\(userId)")
            UserDefaults.standard.removeObject(forKey: "user_last_online_time_timestamp_\(userId)")
        }
        return nil
    }
    
    /// 设置用户的最近上线时间缓存（存储原始时间Date）
    static func setUserLastOnlineTime(userId: String, originalTimestamp: Date) {
        // 🎯 修改：只存储原始时间，不存储格式化文本
        UserDefaults.standard.set(originalTimestamp, forKey: "user_last_online_time_\(userId)")
        // 清除旧格式的时间戳键（如果存在）
        UserDefaults.standard.removeObject(forKey: "user_last_online_time_timestamp_\(userId)")
    }
    
    /// 清除用户时间缓存
    static func clearUserLastOnlineTime(userId: String) {
        UserDefaults.standard.removeObject(forKey: "user_last_online_time_\(userId)")
        UserDefaults.standard.removeObject(forKey: "user_last_online_time_timestamp_\(userId)")
    }
    
    // MARK: - 好友列表缓存管理（类似于用户头像界面的缓存机制）
    /// 获取好友的用户名缓存
    static func getFriendUserName(userId: String) -> String? {
        return UserDefaults.standard.string(forKey: "friend_user_name_\(userId)")
    }
    
    /// 设置好友的用户名缓存
    static func setFriendUserName(userId: String, userName: String) {
        UserDefaults.standard.set(userName, forKey: "friend_user_name_\(userId)")
    }
    
    /// 获取好友的头像缓存（复用 getCustomAvatar，因为它是通用的）
    static func getFriendAvatar(userId: String) -> String? {
        return getCustomAvatar(userId: userId)
    }
    
    /// 设置好友的头像缓存（复用 setCustomAvatar，因为它是通用的）
    static func setFriendAvatar(userId: String, avatar: String) {
        setCustomAvatar(userId: userId, emoji: avatar)
    }
    
    // MARK: - 用户信息管理（按用户隔离）
    static func getCurrentUserName(userId: String? = nil) -> String {
        let currentUserId = userId ?? getCurrentUserId() ?? ""
        guard !currentUserId.isEmpty else {
            return "未知用户"
        }
        let key = "current_user_name_\(currentUserId)"
        return UserDefaults.standard.string(forKey: key) ?? "未知用户"
    }
    
    static func setCurrentUserName(_ name: String, userId: String? = nil) {
        let currentUserId = userId ?? getCurrentUserId() ?? ""
        guard !currentUserId.isEmpty else { return }
        let key = "current_user_name_\(currentUserId)"
        UserDefaults.standard.set(name, forKey: key)
    }
    
    static func getCurrentUserEmail(userId: String? = nil) -> String {
        let currentUserId = userId ?? getCurrentUserId() ?? ""
        guard !currentUserId.isEmpty else {
            return ""
        }
        let key = "current_user_email_\(currentUserId)"
        return UserDefaults.standard.string(forKey: key) ?? ""
    }
    
    static func setCurrentUserEmail(_ email: String, userId: String? = nil) {
        let currentUserId = userId ?? getCurrentUserId() ?? ""
        guard !currentUserId.isEmpty else { return }
        let key = "current_user_email_\(currentUserId)"
        UserDefaults.standard.set(email, forKey: key)
    }
    
    static func getCurrentUserId() -> String? {
        return UserDefaults.standard.string(forKey: "current_user_id")
    }
    
    static func setCurrentUserId(_ id: String) {
        UserDefaults.standard.set(id, forKey: "current_user_id")
    }
    
    // MARK: - 登录相关
    static func getLoginType() -> String? {
        return UserDefaults.standard.string(forKey: "loginType")
    }
    
    static func setLoginType(_ type: String) {
        UserDefaults.standard.set(type, forKey: "loginType")
    }
    
    static func isLoggedIn() -> Bool {
        return UserDefaults.standard.bool(forKey: "is_logged_in")
    }
    
    static func setLoggedIn(_ loggedIn: Bool) {
        UserDefaults.standard.set(loggedIn, forKey: "is_logged_in")
    }
    
    // MARK: - 内部账号管理
    static func getInternalSavedAccount() -> String? {
        return UserDefaults.standard.string(forKey: "internal_saved_account")
    }
    
    static func setInternalSavedAccount(_ account: String) {
        UserDefaults.standard.set(account, forKey: "internal_saved_account")
    }
    
    static func removeInternalSavedAccount() {
        UserDefaults.standard.removeObject(forKey: "internal_saved_account")
    }
    
    // MARK: - 邮箱管理
    static func getAppleUserEmail(userId: String) -> String? {
        if let email = UserDefaults.standard.string(forKey: "apple_user_email_\(userId)") {
            return email
        }
        if let originalUid = UserDefaults.standard.string(forKey: "apple_original_uid_\(userId)") {
            return UserDefaults.standard.string(forKey: "apple_user_email_\(originalUid)")
        }
        return nil
    }
    
    static func setAppleUserEmail(userId: String, email: String) {
        UserDefaults.standard.set(email, forKey: "apple_user_email_\(userId)")
        if let originalUid = UserDefaults.standard.string(forKey: "apple_original_uid_\(userId)") {
            UserDefaults.standard.set(email, forKey: "apple_user_email_\(originalUid)")
        }
    }
    
    static func removeAppleUserEmail(userId: String) {
        UserDefaults.standard.removeObject(forKey: "apple_user_email_\(userId)")
        if let originalUid = UserDefaults.standard.string(forKey: "apple_original_uid_\(userId)") {
            UserDefaults.standard.removeObject(forKey: "apple_user_email_\(originalUid)")
        }
    }
    
    static func getGuestUserEmail(userId: String) -> String? {
        return UserDefaults.standard.string(forKey: "guest_user_email_\(userId)")
    }
    
    static func setGuestUserEmail(userId: String, email: String) {
        UserDefaults.standard.set(email, forKey: "guest_user_email_\(userId)")
    }
    
    static func removeGuestUserEmail(userId: String) {
        UserDefaults.standard.removeObject(forKey: "guest_user_email_\(userId)")
    }
    
    static func getInternalUserEmail(userId: String) -> String? {
        return UserDefaults.standard.string(forKey: "internal_user_email_\(userId)")
    }
    
    static func setInternalUserEmail(userId: String, email: String) {
        UserDefaults.standard.set(email, forKey: "internal_user_email_\(userId)")
    }
    
    static func removeInternalUserEmail(userId: String) {
        UserDefaults.standard.removeObject(forKey: "internal_user_email_\(userId)")
    }
    
    // MARK: - 设置管理（按用户隔离）
    static func getSettingsJumpTime(userId: String? = nil) -> Date? {
        let currentUserId = userId ?? getCurrentUserId() ?? ""
        guard !currentUserId.isEmpty else { return nil }
        let key = "settings_jump_time_\(currentUserId)"
        return UserDefaults.standard.object(forKey: key) as? Date
    }
    
    static func setSettingsJumpTime(_ date: Date, userId: String? = nil) {
        let currentUserId = userId ?? getCurrentUserId() ?? ""
        guard !currentUserId.isEmpty else { return }
        let key = "settings_jump_time_\(currentUserId)"
        UserDefaults.standard.set(date, forKey: key)
    }
    
    static func removeSettingsJumpTime(userId: String? = nil) {
        let currentUserId = userId ?? getCurrentUserId() ?? ""
        guard !currentUserId.isEmpty else { return }
        let key = "settings_jump_time_\(currentUserId)"
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    // MARK: - 游戏相关
    static func getMaxComboCount(userId: String) -> Int {
        return UserDefaults.standard.integer(forKey: "max_combo_count_\(userId)")
    }
    
    static func setMaxComboCount(userId: String, count: Int) {
        UserDefaults.standard.set(count, forKey: "max_combo_count_\(userId)")
    }
    
    // MARK: - 历史记录管理（按用户隔离）
    static func getLocationHistory(userId: String? = nil) -> [LocationRecord] {
        let currentUserId = userId ?? getCurrentUserId() ?? ""
        guard !currentUserId.isEmpty else { return [] }
        let key = "locationHistory_\(currentUserId)"
        if let data = UserDefaults.standard.data(forKey: key),
           let records = try? JSONDecoder().decode([LocationRecord].self, from: data) {
            return records
        }
        return []
    }
    
    static func setLocationHistory(_ records: [LocationRecord], userId: String? = nil) {
        let currentUserId = userId ?? getCurrentUserId() ?? ""
        guard !currentUserId.isEmpty else { return }
        let key = "locationHistory_\(currentUserId)"
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    // MARK: - 推荐榜 / 排行榜前20条本地缓存（与历史记录类似，使用 UserDefaults 持久化）
    /// 获取当前用户缓存的推荐榜前20条数据
    static func getTop20Recommendations(userId: String) -> [RecommendationItem] {
        let key = "top20_recommendations_\(userId)"
        if let data = UserDefaults.standard.data(forKey: key),
           let items = try? JSONDecoder().decode([RecommendationItem].self, from: data) {
            return items
        }
        return []
    }
    
    /// 缓存当前用户的推荐榜前20条数据
    static func setTop20Recommendations(_ items: [RecommendationItem], userId: String) {

        let key = "top20_recommendations_\(userId)"
        
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)

            // 🎯 验证：立即读取验证
            if let verifyData = UserDefaults.standard.data(forKey: key),
               let _ = try? JSONDecoder().decode([RecommendationItem].self, from: verifyData) {
            } else {

            }
        } else {

        }
    }
    
    /// 获取当前用户缓存的排行榜前20条数据
    static func getTop20RankingUserScores(userId: String) -> [UserScore] {
        let key = "top20_ranking_userscores_\(userId)"
        if let data = UserDefaults.standard.data(forKey: key),
           let items = try? JSONDecoder().decode([UserScore].self, from: data) {
            return items
        }
        return []
    }
    
    /// 缓存当前用户的排行榜前20条数据
    static func setTop20RankingUserScores(_ items: [UserScore], userId: String) {

        let key = "top20_ranking_userscores_\(userId)"
        
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)

            // 🎯 验证：立即读取验证
            if let verifyData = UserDefaults.standard.data(forKey: key),
               let _ = try? JSONDecoder().decode([UserScore].self, from: verifyData) {
            } else {

            }
        } else {

        }
    }
    
    // MARK: - 排行榜前3名缓存管理（按用户隔离）
    /// 获取排行榜前3名的用户ID
    static func getTop3RankingUserIds(userId: String) -> [String] {
        let key = "top3_ranking_user_ids_\(userId)"
        if let userIds = UserDefaults.standard.stringArray(forKey: key) {
            return userIds
        }
        return []
    }
    
    /// 设置排行榜前3名的用户ID
    static func setTop3RankingUserIds(_ userIds: [String], userId: String) {
        let key = "top3_ranking_user_ids_\(userId)"
        UserDefaults.standard.set(userIds, forKey: key)
    }
    
    /// 获取用户在排行榜中的排名（返回1-3，如果不在前3名则返回nil）
    static func getRankingPosition(userId: String, currentUserId: String) -> Int? {
        let top3UserIds = getTop3RankingUserIds(userId: currentUserId)
        if let index = top3UserIds.firstIndex(of: userId) {
            return index + 1 // 索引0 = 第1名，索引1 = 第2名，索引2 = 第3名
        }
        return nil
    }
    
    // MARK: - 拍一拍消息本地存储管理
    /// 获取本地保存的拍一拍消息
    static func getPatMessages(userId: String) -> [MessageItem] {
        let key = "patMessages_\(userId)"
        if let data = UserDefaults.standard.data(forKey: key),
           let messages = try? JSONDecoder().decode([MessageItem].self, from: data) {
            return messages
        }
        return []
    }
    
    /// 保存拍一拍消息到本地
    static func savePatMessages(_ messages: [MessageItem], userId: String) {
        let key = "patMessages_\(userId)"
        if let data = try? JSONEncoder().encode(messages) {
            UserDefaults.standard.set(data, forKey: key)
            // 🎯 优化：通知 PatMessageUpdateManager 清除缓存
            NotificationCenter.default.post(
                name: NSNotification.Name("PatMessagesSaved"),
                object: nil,
                userInfo: ["userId": userId]
            )
        }
    }
    
    /// 添加拍一拍消息到本地（合并到现有消息）
    static func addPatMessage(_ message: MessageItem, userId: String) {
        var existingMessages = getPatMessages(userId: userId)
        
        // 检查是否已存在相同消息（避免重复）
        let isDuplicate = existingMessages.contains { existing in
            let isSameSender = existing.senderId == message.senderId
            let isSameReceiver = existing.receiverId == message.receiverId
            let isSameContent = existing.content == message.content
            let isSameTime = abs(existing.timestamp.timeIntervalSince(message.timestamp)) < 1.0
            let isSameObjectId = existing.objectId == message.objectId && message.objectId != nil
            
            return (isSameSender && isSameReceiver && isSameContent && isSameTime) || isSameObjectId
        }
        
        if !isDuplicate {
            // 添加到列表开头
            existingMessages.insert(message, at: 0)
            
            // 限制本地存储的消息数量（最多保存1000条）
            if existingMessages.count > 1000 {
                existingMessages = Array(existingMessages.prefix(1000))
            }
            
            // 保存更新后的消息列表（savePatMessages 会自动发送通知清除缓存）
            savePatMessages(existingMessages, userId: userId)
        }
    }
    
    /// 清除本地保存的拍一拍消息
    static func clearPatMessages(userId: String) {
        let key = "patMessages_\(userId)"
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    // MARK: - 点赞的LocationRecord记录管理
    static func getLikedLocationRecords(forKey key: String) -> [String] {
        if let objectIds = UserDefaults.standard.stringArray(forKey: key) {
            return objectIds
        }
        return []
    }
    
    static func setLikedLocationRecords(_ objectIds: [String], forKey key: String) {
        UserDefaults.standard.set(objectIds, forKey: key)
    }
    
    static func addLikedLocationRecord(_ objectId: String, forKey key: String) {
        var likedRecords = getLikedLocationRecords(forKey: key)
        if !likedRecords.contains(objectId) {
            likedRecords.append(objectId)
            setLikedLocationRecords(likedRecords, forKey: key)
        }
    }
    
    static func removeLikedLocationRecord(_ objectId: String, forKey key: String) {
        var likedRecords = getLikedLocationRecords(forKey: key)
        likedRecords.removeAll { $0 == objectId }
        setLikedLocationRecords(likedRecords, forKey: key)
    }
    
    static func isLocationRecordLiked(_ objectId: String, forKey key: String) -> Bool {
        let likedRecords = getLikedLocationRecords(forKey: key)
        return likedRecords.contains(objectId)
    }
    
    static func clearLikedLocationRecords(forKey key: String) {
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    // MARK: - 通用数据操作
    static func getData(forKey key: String) -> Data? {
        return UserDefaults.standard.data(forKey: key)
    }
    
    static func setData(_ data: Data, forKey key: String) {
        UserDefaults.standard.set(data, forKey: key)
    }
    
    static func getStringArray(forKey key: String) -> [String]? {
        return UserDefaults.standard.stringArray(forKey: key)
    }
    
    static func setStringArray(_ array: [String], forKey key: String) {
        UserDefaults.standard.set(array, forKey: key)
    }
    
    // MARK: - 清理操作
    static func clearAllUserData(for user: UserInfo?) {
        guard let user = user else { return }
        let userId = user.id
        
        // 清理历史记录
        UserDefaults.standard.removeObject(forKey: StorageKeyUtils.getHistoryKey(for: user))
        UserDefaults.standard.removeObject(forKey: "locationHistory_\(userId)")
        
        // 清理举报记录
        UserDefaults.standard.removeObject(forKey: StorageKeyUtils.getReportRecordsKey(for: user))
        
        // 清理黑名单（按用户隔离）
        UserDefaults.standard.removeObject(forKey: "blacklistedUserIds_\(userId)")
        
        // 清理收藏记录
        UserDefaults.standard.removeObject(forKey: StorageKeyUtils.getFavoriteRecordsKey(for: user))
    }
    
    // MARK: - 黑名单管理（按用户隔离）
    static func getBlacklistedUserIds(userId: String? = nil) -> [String] {
        let currentUserId = userId ?? getCurrentUserId() ?? ""
        guard !currentUserId.isEmpty else { return [] }
        let key = "blacklistedUserIds_\(currentUserId)"
        if let data = UserDefaults.standard.data(forKey: key),
           let userIds = try? JSONDecoder().decode([String].self, from: data) {
            return userIds
        }
        return []
    }
    
    static func setBlacklistedUserIds(_ userIds: [String], userId: String? = nil) {
        let currentUserId = userId ?? getCurrentUserId() ?? ""
        guard !currentUserId.isEmpty else { return }
        let key = "blacklistedUserIds_\(currentUserId)"
        if let data = try? JSONEncoder().encode(userIds) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    static func clearBlacklistedUserIds(userId: String? = nil) {
        let currentUserId = userId ?? getCurrentUserId() ?? ""
        guard !currentUserId.isEmpty else { return }
        let key = "blacklistedUserIds_\(currentUserId)"
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    static func clearUserEmails(for user: UserInfo) {
        removeAppleUserEmail(userId: user.id)
        removeGuestUserEmail(userId: user.id)
    }
    
    // MARK: - 用户设置初始化
    static func initializeUserSettings(userId: String, loginType: String) {
        // 设置随机头像
        let randomEmoji = EmojiList.allEmojis.randomElement() ?? "🙂"
        setCustomAvatar(userId: userId, emoji: randomEmoji)
        
        // 初始化各种记录
        UserDefaults.standard.set([], forKey: "location_history_\(userId)")
        UserDefaults.standard.set([], forKey: "randomMatchHistory_\(loginType)_\(userId)")
        UserDefaults.standard.set([], forKey: "favorite_records_\(userId)")
        UserDefaults.standard.set([], forKey: "messages_\(userId)")
        UserDefaults.standard.set([], forKey: "report_records_\(userId)")
        
        // 设置登录状态
        setLoggedIn(true)
        setLoginType(loginType)
        setCurrentUserId(userId)
        
        // 设置首次登录时间
        UserDefaults.standard.set(Date(), forKey: "first_login_time_\(userId)")
    }
    
    // MARK: - 彩色模式管理
    /// 获取彩色模式开关状态（从 UserDefaults 缓存）
    static func getColorfulModeEnabled(userId: String) -> Bool? {
        let key = "colorful_mode_enabled_\(userId)"
        // 如果 key 不存在，返回 nil（表示还未查询过）
        if UserDefaults.standard.object(forKey: key) == nil {
            return nil
        }
        return UserDefaults.standard.bool(forKey: key)
    }
    
    /// 设置彩色模式开关状态（更新 UserDefaults 缓存）
    static func setColorfulModeEnabled(userId: String, enabled: Bool) {
        let key = "colorful_mode_enabled_\(userId)"
        UserDefaults.standard.set(enabled, forKey: key)
    }
    
    // MARK: - 默认邮箱用户点击寻找按钮计数
    /// 获取默认邮箱用户点击寻找按钮的次数
    static func getDefaultEmailSearchClickCount(userId: String) -> Int {
        return UserDefaults.standard.integer(forKey: "default_email_search_click_count_\(userId)")
    }
    
    /// 增加默认邮箱用户点击寻找按钮的次数
    static func incrementDefaultEmailSearchClickCount(userId: String) -> Int {
        let currentCount = getDefaultEmailSearchClickCount(userId: userId)
        let newCount = currentCount + 1
        UserDefaults.standard.set(newCount, forKey: "default_email_search_click_count_\(userId)")
        return newCount
    }
    
    /// 重置默认邮箱用户点击寻找按钮的次数（当用户设置真实邮箱后调用）
    static func resetDefaultEmailSearchClickCount(userId: String) {
        UserDefaults.standard.removeObject(forKey: "default_email_search_click_count_\(userId)")
        // 🎯 新增：同时清除上次提示时间
        UserDefaults.standard.removeObject(forKey: "default_email_alert_last_shown_time_\(userId)")
    }
    
    // MARK: - 默认邮箱提示时间管理
    /// 获取上次提示的时间
    static func getLastDefaultEmailAlertTime(userId: String) -> Date? {
        if let timestamp = UserDefaults.standard.object(forKey: "default_email_alert_last_shown_time_\(userId)") as? Date {
            return timestamp
        }
        return nil
    }
    
    /// 设置上次提示的时间
    static func setLastDefaultEmailAlertTime(userId: String) {
        UserDefaults.standard.set(Date(), forKey: "default_email_alert_last_shown_time_\(userId)")
    }
    
    // MARK: - 免费匹配次数限制管理（11分钟内最多6次）
    /// 获取免费匹配记录（时间戳列表）
    static func getFreeMatchTimestamps(userId: String) -> [Date] {
        let key = "free_match_timestamps_\(userId)"
        if let data = UserDefaults.standard.data(forKey: key),
           let timestamps = try? JSONDecoder().decode([Date].self, from: data) {
            return timestamps
        }
        return []
    }
    
    /// 添加免费匹配记录（记录时间戳）
    static func recordFreeMatch(userId: String) {
        let key = "free_match_timestamps_\(userId)"
        var timestamps = getFreeMatchTimestamps(userId: userId)
        
        let now = Date()
        // 只保留11分钟内的记录
        let elevenMinutesAgo = now.addingTimeInterval(-660) // 11分钟 = 660秒
        timestamps = timestamps.filter { $0 > elevenMinutesAgo }
        
        // 添加当前时间戳
        timestamps.append(now)
        
        // 保存
        if let data = try? JSONEncoder().encode(timestamps) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    /// 获取11分钟内免费匹配的次数
    static func getFreeMatchCountInLastHour(userId: String) -> Int {
        let timestamps = getFreeMatchTimestamps(userId: userId)
        let now = Date()
        // 只统计11分钟内的记录
        let elevenMinutesAgo = now.addingTimeInterval(-660) // 11分钟 = 660秒
        
        // 只统计11分钟内的记录
        let recentTimestamps = timestamps.filter { $0 > elevenMinutesAgo }
        return recentTimestamps.count
    }
    
    /// 检查是否可以执行免费匹配（11分钟内最多6次）
    static func canPerformFreeMatch(userId: String) -> Bool {
        return getFreeMatchCountInLastHour(userId: userId) < 6
    }
    
    /// 检查是否在17小时内提示过
    static func hasShownAlertWithinOneMinute(userId: String) -> Bool {
        guard let lastAlertTime = getLastDefaultEmailAlertTime(userId: userId) else {
            return false
        }
        let timeInterval = Date().timeIntervalSince(lastAlertTime)
        let seventeenHours: TimeInterval = 17 * 60 * 60 // 17小时 = 61200秒
        return timeInterval < seventeenHours
    }
    
    // MARK: - 好友申请限制管理（按用户隔离）
    /// 24小时内最多可以发送的好友申请数量
    private static let maxFriendRequestsPer24Hours = 17
    
    /// 记录好友申请发送时间
    static func recordFriendRequestSent(to targetUserId: String, userId: String? = nil) {
        let currentUserId = userId ?? getCurrentUserId() ?? ""
        guard !currentUserId.isEmpty else { return }
        let key = "friend_requests_sent_\(currentUserId)"
        var timestamps: [Double] = UserDefaults.standard.array(forKey: key) as? [Double] ?? []
        let currentTimestamp = Date().timeIntervalSince1970
        timestamps.append(currentTimestamp)
        UserDefaults.standard.set(timestamps, forKey: key)
        
        // 计算这是24小时内的第几个
        _ = timestamps.filter { $0 >= Date().timeIntervalSince1970 - (24 * 60 * 60) }
    }
    
    /// 获取24小时内的好友申请数量
    static func getFriendRequestCountInLast24Hours(userId: String? = nil) -> Int {
        let currentUserId = userId ?? getCurrentUserId() ?? ""
        guard !currentUserId.isEmpty else { return 0 }
        let key = "friend_requests_sent_\(currentUserId)"
        guard let timestamps = UserDefaults.standard.array(forKey: key) as? [Double] else {
            return 0
        }
        
        let now = Date().timeIntervalSince1970
        let twentyFourHoursAgo = now - (24 * 60 * 60)
        
        // 过滤出24小时内的记录
        let recentRequests = timestamps.filter { $0 >= twentyFourHoursAgo }
        
        // 清理过期记录
        if recentRequests.count != timestamps.count {
            UserDefaults.standard.set(recentRequests, forKey: key)
        }
        
        return recentRequests.count
    }
    
    /// 检查是否可以发送好友申请（24小时内最多300个）
    /// 注意：这是客户端本地限制，用于防止用户发送过多申请
    /// LeanCloud 开发指南中没有规定好友申请数量限制，这是应用自定义的限制
    static func canSendFriendRequest(userId: String? = nil) -> (Bool, String) {
        let count = getFriendRequestCountInLast24Hours(userId: userId)
        if count >= maxFriendRequestsPer24Hours {
            let remainingHours = calculateRemainingHours(userId: userId)
            let message = "24小时内最多只能发送\(maxFriendRequestsPer24Hours)个好友申请，已发送\(count)个。"
            + (remainingHours > 0 ? " 请\(String(format: "%.1f", remainingHours))小时后再试" : " 请稍后再试")
            return (false, message)
        }
        return (true, "")
    }
    
    /// 计算距离最早申请的时间还有多少小时（用于提示用户）
    private static func calculateRemainingHours(userId: String? = nil) -> Double {
        let currentUserId = userId ?? getCurrentUserId() ?? ""
        guard !currentUserId.isEmpty else { return 0 }
        let key = "friend_requests_sent_\(currentUserId)"
        guard let timestamps = UserDefaults.standard.array(forKey: key) as? [Double] else {
            return 0
        }
        
        let now = Date().timeIntervalSince1970
        let twentyFourHoursAgo = now - (24 * 60 * 60)
        
        // 过滤出24小时内的记录
        let recentRequests = timestamps.filter { $0 >= twentyFourHoursAgo }
        
        // 找到最早的时间戳
        if let earliestTimestamp = recentRequests.min() {
            let hoursSinceEarliest = (now - earliestTimestamp) / 3600.0
            let remainingHours = 24.0 - hoursSinceEarliest
            return max(0, remainingHours)
        }
        
        return 0
    }
    
    /// 清理所有好友申请记录
    static func clearFriendRequestRecords(userId: String? = nil) {
        let currentUserId = userId ?? getCurrentUserId() ?? ""
        guard !currentUserId.isEmpty else { return }
        let key = "friend_requests_sent_\(currentUserId)"
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    /// 检查是否在1分钟内向同一用户发送过好友请求
    static func hasSentFriendRequestToUserInLastMinute(targetUserId: String) -> Bool {
        let key = "friend_request_sent_to_user_\(targetUserId)"
        guard let lastSentTime = UserDefaults.standard.object(forKey: key) as? Date else {
            return false
        }
        let timeInterval = Date().timeIntervalSince(lastSentTime)
        return timeInterval < 60.0 // 1分钟 = 60秒
    }
    
    /// 记录向特定用户发送好友请求的时间
    static func recordFriendRequestSentToUser(targetUserId: String) {
        let key = "friend_request_sent_to_user_\(targetUserId)"
        UserDefaults.standard.set(Date(), forKey: key)
    }
    
    // MARK: - 拍一拍限制管理（按用户隔离）
    /// 24小时内最多可以发送的拍一拍数量
    private static let maxPatActionsPer24Hours = 28
    
    /// 记录拍一拍发送时间
    static func recordPatActionSent(to targetUserId: String, userId: String? = nil) {
        let currentUserId = userId ?? getCurrentUserId() ?? ""
        guard !currentUserId.isEmpty else { return }
        let key = "pat_actions_sent_\(currentUserId)"
        var timestamps: [Double] = UserDefaults.standard.array(forKey: key) as? [Double] ?? []
        let currentTimestamp = Date().timeIntervalSince1970
        timestamps.append(currentTimestamp)
        UserDefaults.standard.set(timestamps, forKey: key)
        
        // 清理过期记录
        let now = Date().timeIntervalSince1970
        let twentyFourHoursAgo = now - (24 * 60 * 60)
        let recentActions = timestamps.filter { $0 >= twentyFourHoursAgo }
        
        if recentActions.count != timestamps.count {
            UserDefaults.standard.set(recentActions, forKey: key)
        }
    }
    
    /// 获取24小时内的拍一拍数量
    static func getPatActionCountInLast24Hours(userId: String? = nil) -> Int {
        let currentUserId = userId ?? getCurrentUserId() ?? ""
        guard !currentUserId.isEmpty else { return 0 }
        let key = "pat_actions_sent_\(currentUserId)"
        guard let timestamps = UserDefaults.standard.array(forKey: key) as? [Double] else {
            return 0
        }

        let now = Date().timeIntervalSince1970
        let twentyFourHoursAgo = now - (24 * 60 * 60)

        // 过滤出24小时内的记录
        let recentActions = timestamps.filter { $0 >= twentyFourHoursAgo }

        // 清理过期记录
        if recentActions.count != timestamps.count {
            UserDefaults.standard.set(recentActions, forKey: key)
        }

        return recentActions.count
    }
    
    /// 检查是否可以发送拍一拍（24小时内最多28个）
    /// 注意：这是客户端本地限制，用于防止用户发送过多拍一拍
    static func canSendPatAction(userId: String? = nil) -> (Bool, String) {
        let count = getPatActionCountInLast24Hours(userId: userId)
        
        if count >= maxPatActionsPer24Hours {
            let remainingHours = calculatePatRemainingHours(userId: userId)
            let message = "24小时内最多只能发送\(maxPatActionsPer24Hours)次拍一拍，已发送\(count)次。"
            + (remainingHours > 0 ? " 请\(String(format: "%.1f", remainingHours))小时后再试" : " 请稍后再试")
            return (false, message)
        }
        
        return (true, "")
    }
    
    /// 计算距离最早拍一拍的时间还有多少小时（用于提示用户）
    private static func calculatePatRemainingHours(userId: String? = nil) -> Double {
        let currentUserId = userId ?? getCurrentUserId() ?? ""
        guard !currentUserId.isEmpty else { return 0 }
        let key = "pat_actions_sent_\(currentUserId)"
        guard let timestamps = UserDefaults.standard.array(forKey: key) as? [Double] else {
            return 0
        }
        
        let now = Date().timeIntervalSince1970
        let twentyFourHoursAgo = now - (24 * 60 * 60)
        
        // 过滤出24小时内的记录
        let recentActions = timestamps.filter { $0 >= twentyFourHoursAgo }
        
        // 找到最早的时间戳
        if let earliestTimestamp = recentActions.min() {
            let hoursSinceEarliest = (now - earliestTimestamp) / 3600.0
            let remainingHours = 24.0 - hoursSinceEarliest
            return max(0, remainingHours)
        }
        
        return 0
    }
    
    /// 清理所有拍一拍记录
    static func clearPatActionRecords(userId: String? = nil) {
        let currentUserId = userId ?? getCurrentUserId() ?? ""
        guard !currentUserId.isEmpty else { return }
        let key = "pat_actions_sent_\(currentUserId)"
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    /// 🎯 新增：获取1分钟内对特定用户的拍一拍数量
    static func getPatActionCountInLastMinute(targetUserId: String) -> Int {
        let key = "pat_action_sent_to_user_\(targetUserId)"
        guard let timestamps = UserDefaults.standard.array(forKey: key) as? [Double] else {
            return 0
        }
        
        let now = Date().timeIntervalSince1970
        let oneMinuteAgo = now - 60.0 // 1分钟 = 60秒
        
        // 过滤出1分钟内的记录
        let recentActions = timestamps.filter { $0 >= oneMinuteAgo }
        
        // 清理过期记录
        if recentActions.count != timestamps.count {
            UserDefaults.standard.set(recentActions, forKey: key)
        }
        
        return recentActions.count
    }
    
    /// 🎯 新增：检查是否在1分钟内向同一用户发送拍一拍超过3次
    static func hasSentPatActionToUserInLastMinute(targetUserId: String, maxCount: Int = 3) -> Bool {
        let key = "pat_action_sent_to_user_\(targetUserId)"
        guard let timestamps = UserDefaults.standard.array(forKey: key) as? [Double] else {
            return false
        }
        
        let now = Date().timeIntervalSince1970
        let oneMinuteAgo = now - 60.0 // 1分钟 = 60秒
        
        // 过滤出1分钟内的记录
        let recentActions = timestamps.filter { $0 >= oneMinuteAgo }
        
        // 清理过期记录
        if recentActions.count != timestamps.count {
            UserDefaults.standard.set(recentActions, forKey: key)
        }
        
        // 检查是否超过限制
        return recentActions.count >= maxCount
    }
    
    /// 🎯 新增：检查拍一拍按钮是否应该被禁用（1分钟内超过3次）
    static func isPatButtonDisabled(targetUserId: String, maxCount: Int = 3) -> Bool {
        return hasSentPatActionToUserInLastMinute(targetUserId: targetUserId, maxCount: maxCount)
    }
    
    /// 🎯 新增：获取距离按钮恢复的剩余时间（秒）
    static func getPatButtonRemainingCooldown(targetUserId: String, maxCount: Int = 3) -> TimeInterval? {
        let key = "pat_action_sent_to_user_\(targetUserId)"
        guard let timestamps = UserDefaults.standard.array(forKey: key) as? [Double] else {
            return nil
        }
        
        let now = Date().timeIntervalSince1970
        let oneMinuteAgo = now - 60.0
        
        // 过滤出1分钟内的记录
        let recentActions = timestamps.filter { $0 >= oneMinuteAgo }
        
        // 如果记录数少于限制，不需要冷却
        if recentActions.count < maxCount {
            return nil
        }
        
        // 找到最早的时间戳
        if let earliestTimestamp = recentActions.min() {
            let elapsed = now - earliestTimestamp
            let remaining = 60.0 - elapsed // 1分钟 = 60秒
            return max(0, remaining)
        }
        
        return nil
    }
    
    /// 🎯 新增：记录向特定用户发送拍一拍的时间
    static func recordPatActionSentToUser(targetUserId: String) {
        let key = "pat_action_sent_to_user_\(targetUserId)"
        var timestamps: [Double] = UserDefaults.standard.array(forKey: key) as? [Double] ?? []
        let currentTimestamp = Date().timeIntervalSince1970
        timestamps.append(currentTimestamp)
        
        // 只保留最近1分钟内的记录（避免数据过多）
        let oneMinuteAgo = currentTimestamp - 60.0
        let recentTimestamps = timestamps.filter { $0 >= oneMinuteAgo }
        
        UserDefaults.standard.set(recentTimestamps, forKey: key)
    }
    
    // MARK: - 排行榜点击限制管理
    /// 每天最多可以点击排行榜按钮的次数
    private static let maxRankingClicksPerDay = 200
    
    /// 记录排行榜按钮点击（按天统计）
    static func recordRankingButtonClick(userId: String) {
        let key = "ranking_clicks_\(userId)"
        let today = getTodayString()
        
        // 获取今天的点击记录
        var dailyClicks: [String: Int] = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
        
        // 清理非今天的记录
        dailyClicks = dailyClicks.filter { $0.key == today }
        
        // 增加今天的点击次数
        let currentCount = dailyClicks[today] ?? 0
        let newCount = currentCount + 1
        dailyClicks[today] = newCount
        
        // 保存
        UserDefaults.standard.set(dailyClicks, forKey: key)
    }
    
    /// 获取今天排行榜按钮的点击次数
    static func getRankingClickCountToday(userId: String) -> Int {
        let key = "ranking_clicks_\(userId)"
        let today = getTodayString()
        
        guard let dailyClicks = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] else {
            return 0
        }
        
        // 清理非今天的记录
        let todayClicks = dailyClicks.filter { $0.key == today }
        if todayClicks.count != dailyClicks.count {
            UserDefaults.standard.set(todayClicks, forKey: key)
        }
        
        return todayClicks[today] ?? 0
    }
    
    /// 检查是否可以点击排行榜按钮（每天最多200次）
    static func canClickRankingButton(userId: String) -> (Bool, String) {
        let count = getRankingClickCountToday(userId: userId)
        
        if count >= maxRankingClicksPerDay {
            let message = "今天已点击\(count)次排行榜，每天最多只能点击\(maxRankingClicksPerDay)次。请明天再试。"
            return (false, message)
        }
        
        return (true, "")
    }
    
    /// 获取今天的日期字符串（用于按天统计）
    private static func getTodayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: Date())
    }
    
    /// 清理所有排行榜点击记录
    static func clearRankingClickRecords(userId: String) {
        UserDefaults.standard.removeObject(forKey: "ranking_clicks_\(userId)")
    }
    
    // MARK: - 排行榜下拉刷新限制管理
    /// 每天最多可以下拉刷新排行榜的次数
    private static let maxRankingRefreshPerDay = 15
    
    /// 记录排行榜下拉刷新（按天统计）
    static func recordRankingRefresh(userId: String) {
        let key = "ranking_refresh_\(userId)"
        let today = getTodayString()
        
        // 获取今天的刷新记录
        var dailyRefreshes: [String: Int] = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
        
        // 清理非今天的记录
        dailyRefreshes = dailyRefreshes.filter { $0.key == today }
        
        // 增加今天的刷新次数
        let currentCount = dailyRefreshes[today] ?? 0
        dailyRefreshes[today] = currentCount + 1
        
        // 保存
        UserDefaults.standard.set(dailyRefreshes, forKey: key)
    }
    
    /// 获取今天排行榜下拉刷新的次数
    static func getRankingRefreshCountToday(userId: String) -> Int {
        let key = "ranking_refresh_\(userId)"
        let today = getTodayString()
        
        guard let dailyRefreshes = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] else {
            return 0
        }
        
        // 清理非今天的记录
        let todayRefreshes = dailyRefreshes.filter { $0.key == today }
        if todayRefreshes.count != dailyRefreshes.count {
            UserDefaults.standard.set(todayRefreshes, forKey: key)
        }
        
        return todayRefreshes[today] ?? 0
    }
    
    /// 检查是否可以下拉刷新排行榜（每天最多15次）
    static func canRefreshRankingList(userId: String) -> (Bool, String) {
        let count = getRankingRefreshCountToday(userId: userId)
        if count >= maxRankingRefreshPerDay {
            let message = "今天已刷新\(count)次排行榜，每天最多只能刷新\(maxRankingRefreshPerDay)次。请明天再试。"
            return (false, message)
        }
        return (true, "")
    }
    
    /// 清理所有排行榜下拉刷新记录
    static func clearRankingRefreshRecords(userId: String) {
        UserDefaults.standard.removeObject(forKey: "ranking_refresh_\(userId)")
    }
    
    // MARK: - 推荐榜下拉刷新限制管理
    /// 每天最多可以下拉刷新推荐榜的次数
    private static let maxRecommendationRefreshPerDay = 15
    
    /// 记录推荐榜下拉刷新（按天统计）
    static func recordRecommendationRefresh(userId: String) {
        let key = "recommendation_refresh_\(userId)"
        let today = getTodayString()
        
        // 获取今天的刷新记录
        var dailyRefreshes: [String: Int] = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
        
        // 清理非今天的记录
        dailyRefreshes = dailyRefreshes.filter { $0.key == today }
        
        // 增加今天的刷新次数
        let currentCount = dailyRefreshes[today] ?? 0
        dailyRefreshes[today] = currentCount + 1
        
        // 保存
        UserDefaults.standard.set(dailyRefreshes, forKey: key)
    }
    
    /// 获取今天推荐榜下拉刷新的次数
    static func getRecommendationRefreshCountToday(userId: String) -> Int {
        let key = "recommendation_refresh_\(userId)"
        let today = getTodayString()
        
        guard let dailyRefreshes = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] else {
            return 0
        }
        
        // 清理非今天的记录
        let todayRefreshes = dailyRefreshes.filter { $0.key == today }
        if todayRefreshes.count != dailyRefreshes.count {
            UserDefaults.standard.set(todayRefreshes, forKey: key)
        }
        
        return todayRefreshes[today] ?? 0
    }
    
    /// 检查是否可以下拉刷新推荐榜（每天最多15次）
    static func canRefreshRecommendationList(userId: String) -> (Bool, String) {
        let count = getRecommendationRefreshCountToday(userId: userId)
        if count >= maxRecommendationRefreshPerDay {
            let message = "今天已刷新\(count)次推荐榜，每天最多只能刷新\(maxRecommendationRefreshPerDay)次。请明天再试。"
            return (false, message)
        }
        return (true, "")
    }
    
    /// 清理所有推荐榜下拉刷新记录
    static func clearRecommendationRefreshRecords(userId: String) {
        UserDefaults.standard.removeObject(forKey: "recommendation_refresh_\(userId)")
    }
    
    // MARK: - 好友列表缓存管理
    /// 获取当前用户缓存的好友列表
    static func getFriendsList(userId: String) -> [MatchRecord] {
        let key = "friends_list_\(userId)"
        if let data = UserDefaults.standard.data(forKey: key),
           let friends = try? JSONDecoder().decode([MatchRecord].self, from: data) {
            return friends
        }
        return []
    }
    
    /// 缓存当前用户的好友列表
    static func setFriendsList(_ friends: [MatchRecord], userId: String) {
        let key = "friends_list_\(userId)"
        if let data = try? JSONEncoder().encode(friends) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    // MARK: - 好友列表下拉刷新限制管理
    /// 每天最多可以下拉刷新好友列表的次数
    private static let maxFriendsRefreshPerDay = 15
    
    /// 记录好友列表下拉刷新（按天统计）
    static func recordFriendsRefresh(userId: String) {
        let key = "friends_refresh_\(userId)"
        let today = getTodayString()
        
        // 获取今天的刷新记录
        var dailyRefreshes: [String: Int] = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
        
        // 清理非今天的记录
        dailyRefreshes = dailyRefreshes.filter { $0.key == today }
        
        // 增加今天的刷新次数
        let currentCount = dailyRefreshes[today] ?? 0
        dailyRefreshes[today] = currentCount + 1
        
        // 保存
        UserDefaults.standard.set(dailyRefreshes, forKey: key)
    }
    
    /// 获取今天好友列表下拉刷新的次数
    static func getFriendsRefreshCountToday(userId: String) -> Int {
        let key = "friends_refresh_\(userId)"
        let today = getTodayString()
        
        guard let dailyRefreshes = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] else {
            return 0
        }
        
        // 清理非今天的记录
        let todayRefreshes = dailyRefreshes.filter { $0.key == today }
        if todayRefreshes.count != dailyRefreshes.count {
            UserDefaults.standard.set(todayRefreshes, forKey: key)
        }
        
        return todayRefreshes[today] ?? 0
    }
    
    /// 检查是否可以下拉刷新好友列表（每天最多15次）
    static func canRefreshFriendsList(userId: String) -> (Bool, String) {
        let count = getFriendsRefreshCountToday(userId: userId)
        if count >= maxFriendsRefreshPerDay {
            let message = "今天已刷新\(count)次好友列表，每天最多只能刷新\(maxFriendsRefreshPerDay)次。请明天再试。"
            return (false, message)
        }
        return (true, "")
    }
    
    /// 清理所有好友列表下拉刷新记录
    static func clearFriendsRefreshRecords(userId: String) {
        UserDefaults.standard.removeObject(forKey: "friends_refresh_\(userId)")
    }
    
    // MARK: - 历史记录按钮点击限制管理
    /// 每天最多可以点击历史记录按钮的次数
    private static let maxHistoryClicksPerDay = 200
    
    /// 记录历史记录按钮点击（按天统计）
    static func recordHistoryButtonClick(userId: String) {
        let key = "history_clicks_\(userId)"
        let today = getTodayString()
        
        // 获取今天的点击记录
        var dailyClicks: [String: Int] = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
        
        // 清理非今天的记录
        dailyClicks = dailyClicks.filter { $0.key == today }
        
        // 增加今天的点击次数
        let currentCount = dailyClicks[today] ?? 0
        dailyClicks[today] = currentCount + 1
        
        // 保存
        UserDefaults.standard.set(dailyClicks, forKey: key)
    }
    
    /// 获取今天历史记录按钮的点击次数
    static func getHistoryClickCountToday(userId: String) -> Int {
        let key = "history_clicks_\(userId)"
        let today = getTodayString()
        
        guard let dailyClicks = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] else {
            return 0
        }
        
        // 清理非今天的记录
        let todayClicks = dailyClicks.filter { $0.key == today }
        if todayClicks.count != dailyClicks.count {
            UserDefaults.standard.set(todayClicks, forKey: key)
        }
        
        return todayClicks[today] ?? 0
    }
    
    /// 检查是否可以点击历史记录按钮（每天最多200次）
    static func canClickHistoryButton(userId: String) -> (Bool, String) {
        let count = getHistoryClickCountToday(userId: userId)
        if count >= maxHistoryClicksPerDay {
            let message = "今天已点击\(count)次历史记录，每天最多只能点击\(maxHistoryClicksPerDay)次。请明天再试。"
            return (false, message)
        }
        return (true, "")
    }
    
    /// 清理所有历史记录按钮点击记录
    static func clearHistoryClickRecords(userId: String) {
        UserDefaults.standard.removeObject(forKey: "history_clicks_\(userId)")
    }
    
    // MARK: - 举报按钮点击限制管理
    /// 每天最多可以点击举报按钮的次数
    private static let maxReportClicksPerDay = 20
    
    /// 记录举报按钮点击（按天统计）
    static func recordReportButtonClick(userId: String) {
        let key = "report_clicks_\(userId)"
        let today = getTodayString()
        
        // 获取今天的点击记录
        var dailyClicks: [String: Int] = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
        
        // 清理非今天的记录
        dailyClicks = dailyClicks.filter { $0.key == today }
        
        // 增加今天的点击次数
        let currentCount = dailyClicks[today] ?? 0
        dailyClicks[today] = currentCount + 1
        
        // 保存
        UserDefaults.standard.set(dailyClicks, forKey: key)
    }
    
    /// 获取今天举报按钮的点击次数
    static func getReportClickCountToday(userId: String) -> Int {
        let key = "report_clicks_\(userId)"
        let today = getTodayString()
        
        guard let dailyClicks = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] else {
            return 0
        }
        
        // 清理非今天的记录
        let todayClicks = dailyClicks.filter { $0.key == today }
        if todayClicks.count != dailyClicks.count {
            UserDefaults.standard.set(todayClicks, forKey: key)
        }
        
        return todayClicks[today] ?? 0
    }
    
    /// 检查是否可以点击举报按钮（每天最多20次）
    static func canClickReportButton(userId: String) -> (Bool, String) {
        let count = getReportClickCountToday(userId: userId)
        if count >= maxReportClicksPerDay {
            let message = "今天已点击\(count)次举报，每天最多只能点击\(maxReportClicksPerDay)次。请明天再试。"
            return (false, message)
        }
        return (true, "")
    }
    
    /// 清理所有举报按钮点击记录
    static func clearReportClickRecords(userId: String) {
        UserDefaults.standard.removeObject(forKey: "report_clicks_\(userId)")
    }
    
    // MARK: - 消息按钮点击限制管理
    /// 每天最多可以点击消息按钮的次数
    private static let maxMessageClicksPerDay = 300
    
    /// 记录消息按钮点击（按天统计）
    static func recordMessageButtonClick(userId: String) {
        let key = "message_clicks_\(userId)"
        let today = getTodayString()
        
        // 获取今天的点击记录
        var dailyClicks: [String: Int] = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]
        
        // 清理非今天的记录
        dailyClicks = dailyClicks.filter { $0.key == today }
        
        // 增加今天的点击次数
        let currentCount = dailyClicks[today] ?? 0
        dailyClicks[today] = currentCount + 1
        
        // 保存
        UserDefaults.standard.set(dailyClicks, forKey: key)
    }
    
    /// 获取今天消息按钮的点击次数
    static func getMessageClickCountToday(userId: String) -> Int {
        let key = "message_clicks_\(userId)"
        let today = getTodayString()
        
        guard let dailyClicks = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] else {
            return 0
        }
        
        // 清理非今天的记录
        let todayClicks = dailyClicks.filter { $0.key == today }
        if todayClicks.count != dailyClicks.count {
            UserDefaults.standard.set(todayClicks, forKey: key)
        }
        
        return todayClicks[today] ?? 0
    }
    
    /// 检查是否可以点击消息按钮（每天最多300次）
    static func canClickMessageButton(userId: String) -> (Bool, String) {
        let count = getMessageClickCountToday(userId: userId)
        if count >= maxMessageClicksPerDay {
            let message = "今天已点击\(count)次消息，每天最多只能点击\(maxMessageClicksPerDay)次。请明天再试。"
            return (false, message)
        }
        return (true, "")
    }
    
    /// 清理所有消息按钮点击记录
    static func clearMessageClickRecords(userId: String) {
        UserDefaults.standard.removeObject(forKey: "message_clicks_\(userId)")
    }
    
    // MARK: - 询问联系方式是否真实限制管理（按用户隔离）
    /// 24小时内最多可以发送的询问联系方式是否真实数量
    private static let maxContactInquiryPer24Hours = 17
    
    /// 记录询问联系方式是否真实发送时间
    static func recordContactInquirySent(to targetUserId: String, userId: String? = nil) {
        let currentUserId = userId ?? getCurrentUserId() ?? ""
        guard !currentUserId.isEmpty else { return }
        let key = "contact_inquiries_sent_\(currentUserId)"
        var timestamps: [Double] = UserDefaults.standard.array(forKey: key) as? [Double] ?? []
        let currentTimestamp = Date().timeIntervalSince1970
        timestamps.append(currentTimestamp)
        UserDefaults.standard.set(timestamps, forKey: key)
        
        // 计算这是24小时内的第几个
        _ = timestamps.filter { $0 >= Date().timeIntervalSince1970 - (24 * 60 * 60) }
    }
    
    /// 获取24小时内的询问联系方式是否真实数量
    static func getContactInquiryCountInLast24Hours(userId: String? = nil) -> Int {
        let currentUserId = userId ?? getCurrentUserId() ?? ""
        guard !currentUserId.isEmpty else { return 0 }
        let key = "contact_inquiries_sent_\(currentUserId)"
        guard let timestamps = UserDefaults.standard.array(forKey: key) as? [Double] else {
            return 0
        }
        
        let now = Date().timeIntervalSince1970
        let twentyFourHoursAgo = now - (24 * 60 * 60)
        
        // 过滤出24小时内的记录
        let recentInquiries = timestamps.filter { $0 >= twentyFourHoursAgo }
        
        // 清理过期记录
        if recentInquiries.count != timestamps.count {
            UserDefaults.standard.set(recentInquiries, forKey: key)
        }
        
        return recentInquiries.count
    }
    
    /// 检查是否可以发送询问联系方式是否真实（24小时内最多17个）
    static func canSendContactInquiry(userId: String? = nil) -> (Bool, String) {
        let count = getContactInquiryCountInLast24Hours(userId: userId)
        if count >= maxContactInquiryPer24Hours {
            let remainingHours = calculateContactInquiryRemainingHours(userId: userId)
            let message = "24小时内最多只能发送\(maxContactInquiryPer24Hours)次询问，已发送\(count)次。"
            + (remainingHours > 0 ? " 请\(String(format: "%.1f", remainingHours))小时后再试" : " 请稍后再试")
            return (false, message)
        }
        return (true, "")
    }
    
    /// 计算距离最早询问的时间还有多少小时（用于提示用户）
    private static func calculateContactInquiryRemainingHours(userId: String? = nil) -> Double {
        let currentUserId = userId ?? getCurrentUserId() ?? ""
        guard !currentUserId.isEmpty else { return 0 }
        let key = "contact_inquiries_sent_\(currentUserId)"
        guard let timestamps = UserDefaults.standard.array(forKey: key) as? [Double] else {
            return 0
        }
        
        let now = Date().timeIntervalSince1970
        let twentyFourHoursAgo = now - (24 * 60 * 60)
        
        // 过滤出24小时内的记录
        let recentInquiries = timestamps.filter { $0 >= twentyFourHoursAgo }
        
        // 找到最早的时间戳
        if let earliestTimestamp = recentInquiries.min() {
            let hoursSinceEarliest = (now - earliestTimestamp) / 3600.0
            let remainingHours = 24.0 - hoursSinceEarliest
            return max(0, remainingHours)
        }
        
        return 0
    }
    
    /// 清理所有询问联系方式是否真实记录
    static func clearContactInquiryRecords(userId: String? = nil) {
        let currentUserId = userId ?? getCurrentUserId() ?? ""
        guard !currentUserId.isEmpty else { return }
        let key = "contact_inquiries_sent_\(currentUserId)"
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    /// 检查是否在1分钟内向同一用户发送过询问联系方式是否真实
    static func hasSentContactInquiryToUserInLastMinute(targetUserId: String) -> Bool {
        let key = "contact_inquiry_sent_to_user_\(targetUserId)"
        guard let lastSentTime = UserDefaults.standard.object(forKey: key) as? Date else {
            return false
        }
        let timeInterval = Date().timeIntervalSince(lastSentTime)
        return timeInterval < 60.0 // 1分钟 = 60秒
    }
    
    /// 记录向特定用户发送询问联系方式是否真实的时间
    static func recordContactInquirySentToUser(targetUserId: String) {
        let key = "contact_inquiry_sent_to_user_\(targetUserId)"
        UserDefaults.standard.set(Date(), forKey: key)
    }
}
