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
    
    // MARK: - 用户信息管理
    static func getCurrentUserName() -> String {
        return UserDefaults.standard.string(forKey: "current_user_name") ?? "未知用户"
    }
    
    static func setCurrentUserName(_ name: String) {
        UserDefaults.standard.set(name, forKey: "current_user_name")
    }
    
    static func getCurrentUserEmail() -> String {
        return UserDefaults.standard.string(forKey: "current_user_email") ?? ""
    }
    
    static func setCurrentUserEmail(_ email: String) {
        UserDefaults.standard.set(email, forKey: "current_user_email")
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
    
    // MARK: - 设置管理
    static func getSettingsJumpTime() -> Date? {
        return UserDefaults.standard.object(forKey: "settings_jump_time") as? Date
    }
    
    static func setSettingsJumpTime(_ date: Date) {
        UserDefaults.standard.set(date, forKey: "settings_jump_time")
    }
    
    static func removeSettingsJumpTime() {
        UserDefaults.standard.removeObject(forKey: "settings_jump_time")
    }
    
    // MARK: - 游戏相关
    static func getMaxComboCount(userId: String) -> Int {
        return UserDefaults.standard.integer(forKey: "max_combo_count_\(userId)")
    }
    
    static func setMaxComboCount(userId: String, count: Int) {
        UserDefaults.standard.set(count, forKey: "max_combo_count_\(userId)")
    }
    
    // MARK: - 历史记录管理
    static func getLocationHistory() -> [LocationRecord] {
        if let data = UserDefaults.standard.data(forKey: "locationHistory"),
           let records = try? JSONDecoder().decode([LocationRecord].self, from: data) {
            return records
        }
        return []
    }
    
    static func setLocationHistory(_ records: [LocationRecord]) {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: "locationHistory")
        }
    }
    
    // MARK: - 排行榜前3名缓存管理
    /// 获取排行榜前3名的用户ID
    static func getTop3RankingUserIds() -> [String] {
        if let userIds = UserDefaults.standard.stringArray(forKey: "top3_ranking_user_ids") {
            return userIds
        }
        return []
    }
    
    /// 设置排行榜前3名的用户ID
    static func setTop3RankingUserIds(_ userIds: [String]) {
        UserDefaults.standard.set(userIds, forKey: "top3_ranking_user_ids")
    }
    
    /// 获取用户在排行榜中的排名（返回1-3，如果不在前3名则返回nil）
    static func getRankingPosition(userId: String) -> Int? {
        let top3UserIds = getTop3RankingUserIds()
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
        
        // 清理历史记录
        UserDefaults.standard.removeObject(forKey: StorageKeyUtils.getHistoryKey(for: user))
        UserDefaults.standard.removeObject(forKey: "locationHistory")
        
        // 清理举报记录
        UserDefaults.standard.removeObject(forKey: StorageKeyUtils.getReportRecordsKey(for: user))
        
        // 清理黑名单
        UserDefaults.standard.removeObject(forKey: "blacklistedUserIds")
        
        // 清理收藏记录
        UserDefaults.standard.removeObject(forKey: StorageKeyUtils.getFavoriteRecordsKey(for: user))
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
    
    /// 检查是否在17小时内提示过
    static func hasShownAlertWithinOneMinute(userId: String) -> Bool {
        guard let lastAlertTime = getLastDefaultEmailAlertTime(userId: userId) else {
            return false
        }
        let timeInterval = Date().timeIntervalSince(lastAlertTime)
        let seventeenHours: TimeInterval = 17 * 60 * 60 // 17小时 = 61200秒
        return timeInterval < seventeenHours
    }
    
    // MARK: - 好友申请限制管理
    /// 24小时内最多可以发送的好友申请数量
    private static let maxFriendRequestsPer24Hours = 300
    
    /// 记录好友申请发送时间
    static func recordFriendRequestSent(to targetUserId: String) {
        let key = "friend_requests_sent"
        var timestamps: [Double] = UserDefaults.standard.array(forKey: key) as? [Double] ?? []
        let currentTimestamp = Date().timeIntervalSince1970
        timestamps.append(currentTimestamp)
        UserDefaults.standard.set(timestamps, forKey: key)
        
        // 计算这是24小时内的第几个
        _ = timestamps.filter { $0 >= Date().timeIntervalSince1970 - (24 * 60 * 60) }
    }
    
    /// 获取24小时内的好友申请数量
    static func getFriendRequestCountInLast24Hours() -> Int {
        let key = "friend_requests_sent"
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
    static func canSendFriendRequest() -> (Bool, String) {
        let count = getFriendRequestCountInLast24Hours()
        if count >= maxFriendRequestsPer24Hours {
            let remainingHours = calculateRemainingHours()
            let message = "24小时内最多只能发送\(maxFriendRequestsPer24Hours)个好友申请，已发送\(count)个。"
            + (remainingHours > 0 ? " 请\(String(format: "%.1f", remainingHours))小时后再试" : " 请稍后再试")
            return (false, message)
        }
        return (true, "")
    }
    
    /// 计算距离最早申请的时间还有多少小时（用于提示用户）
    private static func calculateRemainingHours() -> Double {
        let key = "friend_requests_sent"
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
    static func clearFriendRequestRecords() {
        UserDefaults.standard.removeObject(forKey: "friend_requests_sent")
    }
    
    // MARK: - 拍一拍限制管理
    /// 24小时内最多可以发送的拍一拍数量
    private static let maxPatActionsPer24Hours = 28
    
    /// 记录拍一拍发送时间
    static func recordPatActionSent(to targetUserId: String) {
        let key = "pat_actions_sent"
        var timestamps: [Double] = UserDefaults.standard.array(forKey: key) as? [Double] ?? []
        let currentTimestamp = Date().timeIntervalSince1970
        timestamps.append(currentTimestamp)
        UserDefaults.standard.set(timestamps, forKey: key)
        
        // 计算这是24小时内的第几个
        _ = timestamps.filter { $0 >= Date().timeIntervalSince1970 - (24 * 60 * 60) }
    }
    
    /// 获取24小时内的拍一拍数量
    static func getPatActionCountInLast24Hours() -> Int {
        let key = "pat_actions_sent"
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
    static func canSendPatAction() -> (Bool, String) {
        let count = getPatActionCountInLast24Hours()
        if count >= maxPatActionsPer24Hours {
            let remainingHours = calculatePatRemainingHours()
            let message = "24小时内最多只能发送\(maxPatActionsPer24Hours)次拍一拍，已发送\(count)次。"
            + (remainingHours > 0 ? " 请\(String(format: "%.1f", remainingHours))小时后再试" : " 请稍后再试")
            return (false, message)
        }
        return (true, "")
    }
    
    /// 计算距离最早拍一拍的时间还有多少小时（用于提示用户）
    private static func calculatePatRemainingHours() -> Double {
        let key = "pat_actions_sent"
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
    static func clearPatActionRecords() {
        UserDefaults.standard.removeObject(forKey: "pat_actions_sent")
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
        dailyClicks[today] = currentCount + 1
        
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
}
