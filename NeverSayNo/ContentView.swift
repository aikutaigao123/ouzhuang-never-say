//
//  ContentView.swift
//  7.1
//
//  Created by Die chen on 2025/7/1.
//

import SwiftUI
import AuthenticationServices
import CoreLocation
import Foundation
import Security
import StoreKit
import Combine
import MapKit
import LeanCloud

struct ContentView: View {
    @StateObject var userManager = UserManager()
    @StateObject var locationManager = LocationManager()
    @ObservedObject var stateManager = StateManager.shared
    @ObservedObject var newFriendsCountManager = NewFriendsCountManager.shared  // 🎯 方案2：使用共享单例，确保推送和本地 count 同步
    @StateObject var notificationManager = NotificationManager.shared
    @StateObject var diamondManager = DiamondManager.shared
    @State var path: [String] = []
    @State var unreadMessageCount = 0 // 未读消息数量
    @State var previousSearchPointerAngle: Double = 0 // 搜索指针的前一个角度
    
    // 导航路径保护机制
    @State var isNavigating = false
    @State var navigationLock = NSLock()
    
    // 新增：消息刷新定时器
    @State var messageRefreshTimer: Timer?
    let messageRefreshInterval: TimeInterval = 17.0 // 每17秒刷新一次消息
    
    // 新增：Combine 订阅管理
    @State var cancellables = Set<AnyCancellable>()
    @State var hasLoadedMessagesOnLogin = false // 防止重复调用loadMessagesOnLogin
    
    // 🎯 新增：通知观察者令牌管理（用于在 onDisappear 时移除观察者）
    @State var notificationObservers: [NSObjectProtocol] = []
    
    // 新增：底部TabBar状态
    @State var selectedTab = 0
    
    // 游客信息确认界面状态
    @State var showGuestInfoConfirmation = false
    
    // Apple登录信息确认界面状态
    @State var showAppleInfoConfirmation = false
    
    // 内部登录信息确认界面状态
    // @State var showInternalInfoConfirmation = false // 已删除（内部用户登录已移除）
    
    // 待删除账号弹窗状态
    @State var showPendingDeletionAlert = false
    @State var pendingDeletionUserId: String = ""
    @State var pendingDeletionUserName: String = ""
    @State var pendingDeletionDeviceId: String = ""
    
    // 黑名单弹窗状态
    @State var showBlacklistAlert = false
    
    // 🎯 新增：默认邮箱提示Alert
    @State var showDefaultEmailAlert = false
    @State var shouldSkipDefaultEmailCheck = false // 🎯 新增：是否跳过默认邮箱检查
    
    
    // 历史记录相关数据 - 与LegacySearchView共享
    @State var randomMatchHistory: [RandomMatchHistory] = []
    @State var latestAvatars: [String: String] = [:]
    @State var latestUserNames: [String: String] = [:]
    @State var userLoginTypeCache: [String: String] = [:] // 🔧 优化：添加用户类型本地缓存
    
    // 匹配结果相关状态变量
    @State var randomRecord: LocationRecord?
    @State var randomRecordNumber: Int = 0
    @State var isLoadingRandomRecord = false
    @State var allFriendsMatchResults: [LocationRecord] = []
    @State var searchStartTime: Date? = nil // 记录点击"寻找"按钮的开始时间
    @State var searchButtonClickCount: Int = 0 // 🎯 新增：记录点击寻找按钮的次数
    
    // 黑名单和待删除用户数据
    @State var blacklistedUserIds: [String] = []
    @State var pendingDeletionUserIds: [String] = []
    @State var reportRecords: [ReportRecord] = [] // 新增：举报记录
    
    // 使用计算属性访问newFriendsCount
    private var newFriendsCount: Int {
        newFriendsCountManager.count
    }
    
    // MARK: - 登录相关功能已移至 ContentView+Login.swift
    // MARK: - 历史记录管理已移至 ContentView+History.swift
    
    // MARK: - Report Management Methods
    
    /// 保存举报记录到本地
    func saveReportRecords() {
        if let data = try? JSONEncoder().encode(reportRecords) {
            UserDefaults.standard.set(data, forKey: StorageKeyUtils.getReportRecordsKey(for: userManager.currentUser))
        }
    }
    
    /// 从本地加载举报记录
    func loadReportRecords() {
        reportRecords.removeAll()
        if let data = UserDefaults.standard.data(forKey: StorageKeyUtils.getReportRecordsKey(for: userManager.currentUser)),
           let records = try? JSONDecoder().decode([ReportRecord].self, from: data) {
            reportRecords = records
        }
    }
    
    /// 添加举报记录
    func addReportRecord(reportedUserId: String, reportedUserName: String?, reportedUserEmail: String?, reportReason: String, reportedDeviceId: String? = nil, reportedUserLoginType: String? = nil) {
        
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        let newReport = ReportRecord(
            reportedUserId: reportedUserId,
            reportedUserName: reportedUserName,
            reportedUserEmail: reportedUserEmail,
            reportReason: reportReason,
            reporterUserId: currentUser.id,
            reporterUserName: currentUser.fullName
        )
        
        // 保存到本地
        reportRecords.append(newReport)
        saveReportRecords()
        
        // 获取举报者头像信息 - 基于用户类型设置默认头像
        // 统一使用随机或已分配的自定义emoji头像
        let reporterAvatar: String = {
            if let saved = UserDefaultsManager.getCustomAvatar(userId: currentUser.id) {
                return saved
            }
            let rand = EmojiList.allEmojis.randomElement() ?? "🙂"
            UserDefaultsManager.setCustomAvatar(userId: currentUser.id, emoji: rand)
            return rand
        }()
        
        // 🎯 修改：使用 fetchUserAvatarByUserId，不依赖 loginType，直接从 UserAvatarRecord 表获取
        let tryFetchReportedAvatar = !reportedUserId.isEmpty
        if tryFetchReportedAvatar {
            LeanCloudService.shared.fetchUserAvatarByUserId(objectId: reportedUserId) { fetchedAvatar, _ in
                let loginType = reportedUserLoginType ?? "guest"
                let finalReportedAvatar = (fetchedAvatar?.isEmpty == false) ? fetchedAvatar! : UserAvatarUtils.defaultAvatar(for: loginType)

                let reportData: [String: Any] = [
                    "reported_user_id": reportedUserId, // 🎯 修改：使用 reportedUserId 而不是 reportedDeviceId
                    "reported_user_name": reportedUserName ?? "",
                    "reported_user_email": reportedUserEmail ?? "",
                    "reported_user_login_type": reportedUserLoginType ?? "unknown",
                    "reported_user_avatar": finalReportedAvatar,
                    "report_reason": reportReason,
                    "report_time": ISO8601DateFormatter().string(from: Date()),
                    "reporter_user_id": currentUser.id,
                    "reporter_user_name": currentUser.fullName,
                    "reporter_user_avatar": reporterAvatar
                ]

                LeanCloudService.shared.uploadReportRecord(reportData: reportData) { success, message in
                    DispatchQueue.main.async {
                        if success {
                            // 举报记录上传成功
                        } else {
                            // 举报记录上传失败
                        }
                    }
                }
            }
        } else {
            // 无法查询真实头像时，使用通用头像占位
            let reportData: [String: Any] = [
                "reported_user_id": reportedUserId, // 🎯 修改：使用 reportedUserId 而不是 reportedDeviceId
                "reported_user_name": reportedUserName ?? "",
                "reported_user_email": reportedUserEmail ?? "",
                "reported_user_login_type": reportedUserLoginType ?? "unknown",
                "reported_user_avatar": UserAvatarUtils.defaultAvatar(for: reportedUserLoginType ?? "guest"),
                "report_reason": reportReason,
                "report_time": ISO8601DateFormatter().string(from: Date()),
                "reporter_user_id": currentUser.id,
                "reporter_user_name": currentUser.fullName,
                "reporter_user_avatar": reporterAvatar
            ]

            LeanCloudService.shared.uploadReportRecord(reportData: reportData) { success, message in
                DispatchQueue.main.async {
                    if success {
                        // 举报记录上传成功
                    } else {
                        // 举报记录上传失败
                    }
                }
            }
        }
    }
    
    /// 检查是否已举报过该用户
    func hasReportedUser(_ userId: String) -> Bool {
        return ReportHelpers.hasReportedUser(userId, reportRecords: reportRecords)
    }
}

struct LegacySearchView: View {
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var userManager: UserManager
    @ObservedObject var stateManager: StateManager
    @Binding var unreadMessageCount: Int
    @ObservedObject var newFriendsCountManager: NewFriendsCountManager
    @StateObject var diamondManager = DiamondManager.shared
    var onBack: () -> Void = {}
    @Environment(\.dismiss) private var dismiss
    @State var isLoading = false
    @State var resultMessage = ""
    @State var showAlert = false
    @State var showLogoutAlert = false
    @State var showEditNameAlert = false
    @State var newUserName = ""
    @State var showEditEmailAlert = false
    @State var showLocationHistory = false
    @State var locationHistory: [LocationRecord] = []
    @State var randomRecord: LocationRecord?
    @State var randomRecordNumber: Int = 0
    @State var isLoadingRandomRecord = false
    @State var randomMatchHistory: [RandomMatchHistory] = [] // 新增：随机匹配历史
    @State var showRandomHistory = false // 新增：显示随机历史
    @State var showRechargeAlert = false // 新增：显示充值提示
    @State var searchStartTime: Date? = nil // 记录点击"寻找"按钮的开始时间
    @State var searchButtonClickCount: Int = 0 // 🎯 新增：记录点击寻找按钮的次数
    
    // 🚀 新增：存储所有好友的匹配结果
    @State var allFriendsMatchResults: [LocationRecord] = []
    @State var isLoadingAllFriendsMatch = false
    @State var showRechargeSheet = false // 新增：显示充值界面
    @State var showProfileSheet = false // 新增：显示个人信息界面
    @State var reportRecords: [ReportRecord] = [] // 新增：举报记录（internal 以便扩展访问）

    @State var blacklistedUserIds: [String] = [] // 新增：黑名单用户ID列表
    @State var isUserBlacklisted: Bool = false // 新增：当前用户是否在黑名单中
    @State var blacklistExpiryTime: Date? = nil // 新增：黑名单过期时间
    @State var pendingDeletionUserIds: [String] = [] // 新增：待删除账号用户ID列表
    @State var timeRemaining: String = "" // 新增：剩余时间显示
    @State var countdownTimer: Timer? = nil // 新增：倒计时定时器
    @State var showCopySuccess = false // 新增：显示复制成功提示
    @State var copySuccessMessage = "" // 新增：复制成功消息
    @State var showCancelDeletionAlert = false // 新增：显示取消删除确认对话框
    @State var pendingDeletionDate = "" // 新增：待删除日期
    @State var showAvatarZoom = false // 新增：显示头像放大
    @State var latestAvatars: [String: String] = [:] // 缓存 user_id -> 最新头像
    @State var latestUserNames: [String: String] = [:] // 缓存 user_id -> 最新用户名
    @State var previousSearchPointerAngle: Double = 0 // 搜索指针的前一个角度
    @State var favoriteRecords: [FavoriteRecord] = [] // 新增：喜欢记录
    @State var likeRecords: [LikeRecord] = [] // 新增：点赞记录
    
    // 新增：消息界面数据缓存
    @State var messageViewMessages: [MessageItem] = [] // 消息界面的消息数据
    @State var messageViewFriends: [MatchRecord] = [] // 消息界面的好友数据
    @State var messageViewPatMessages: [MessageItem] = [] // 消息界面的拍一拍消息数据
    @State var messageViewAvatarCache: [String: String] = [:] // 消息界面的头像缓存
    @State var messageViewUserNameCache: [String: String] = [:] // 消息界面的用户名缓存
    
    // 缓存过期时间管理
    @State var avatarCacheTimestamps: [String: Date] = [:]
    @State var userNameCacheTimestamps: [String: Date] = [:]
    let cacheExpirationInterval: TimeInterval = 3 // 3秒缓存过期（测试用）
    @State var showMessageSheet = false // 新增：显示消息界面
    @State var showRankingSheet = false // 新增：显示排行榜界面
    @State var selectedRecommendationId: String? = nil // 新增：当前选中的推荐项目ID
    @State var selectedRankingId: String? = nil // 🎯 新增：当前选中的排行榜项目ID
    @State var selectedHistoryId: UUID? = nil // 🎯 新增：当前选中的历史记录项目ID
    @State var selectedLocation: NavigationTarget? = nil // 新增：地图导航弹窗目标
    @State var showFriendRequestModal = false // 新增：显示加好友弹窗
    @State var selectedTab: Int = 0 // 新增：排行榜界面选中标签
    
    // 加好友弹窗覆盖层
    var friendRequestModalOverlay: some View {
        Group {
            if showFriendRequestModal, let record = randomRecord {
                FriendRequestModal(
                    record: record,
                    latestUserNames: latestUserNames,
                    onDismiss: {
                        showFriendRequestModal = false
                    },
                    onAddFavorite: { userId, userName, userEmail, loginType, userAvatar, recordObjectId in
                        // 🎯 发送好友请求成功后，自动点亮对应的爱心按钮
                        addFavoriteRecord(
                            userId: userId,
                            userName: userName,
                            userEmail: userEmail,
                            loginType: loginType,
                            userAvatar: userAvatar,
                            recordObjectId: recordObjectId
                        )
                    },
                    onReportUser: { userId, userName, userEmail, reportReason, deviceId, loginType in
                        addReportRecord(
                            reportedUserId: userId,
                            reportedUserName: userName,
                            reportedUserEmail: userEmail,
                            reportReason: reportReason,
                            reportedDeviceId: deviceId,
                            reportedUserLoginType: loginType
                        )
                    },
                    hasReportedUser: { userId in
                        hasReportedUser(userId)
                    }
                )
            }
        }
    }
    
    // 加载新朋友申请数量
    // loadNewFriendsCount method moved to LegacySearchView+FriendsManagement.swift
    
    // 刷新所有显示用户的最新头像和用户名（优化版本）
    // refreshSearchViewAvatars method moved to LegacySearchView+AvatarManagement.swift
     
     // 防止重复刷新的标志
     @State var isRefreshing = false
     
     
     
     // 根据用户ID获取登录类型
     // getLoginTypeForUser method moved to LegacySearchView+CacheHelpers.swift
     
     // 拉取并缓存指定用户的最新头像（仅当缓存不存在时）
    // ensureLatestAvatar method moved to LegacySearchView+CacheHelpers.swift
    
    // 用户名解析器（优先使用缓存的最新用户名）
    // userNameResolver method moved to LegacySearchView+CacheHelpers.swift

    // 权限状态文本
    var authorizationStatusText: String {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            return "未确定"
        case .restricted:
            return "受限制"
        case .denied:
            return "已拒绝"
        case .authorizedAlways:
            return "始终允许"
        case .authorizedWhenInUse:
            return "使用时允许"
        @unknown default:
            return "未知状态"
        }
    }
    
    // 发送喜欢消息
    // sendFavoriteMessage method moved to LegacySearchView+MessageSending.swift
    
    // handlePatFriendInMessageView method moved to LegacySearchView+MessageSending.swift
    
    // MARK: - Body View moved to LegacySearchView+Body.swift
    
    // cancelAccountDeletion method moved to LegacySearchView+AccountManagement.swift
    
    // MARK: - Location Service Methods moved to LegacySearchView+LocationService.swift
    
    // 登录成功后读取所有本地缓存数据
    // loadAllLocalCacheDataOnLogin method moved to LegacySearchView+CacheManagement.swift
    
    // 清理过期的缓存 - 改为在数据更新完成后调用
    // cleanupExpiredCache method moved to LegacySearchView+CacheManagement.swift
    
    // 在数据更新完成后清理过期缓存
    // cleanupCacheAfterUpdate method moved to LegacySearchView+CacheManagement.swift
    
    // 检查用户缓存是否过期
    // isCacheExpired method moved to LegacySearchView+CacheManagement.swift
    
    
    // 喜欢记录键名获取已移至 StorageKeyUtils.swift
    
    // 加载喜欢记录
    // loadFavoriteRecords method moved to LegacySearchView+DataManagement.swift
    
    // MARK: - 数据打印辅助函数
    
    // 打印FavoriteRecord表和MatchRecord表数据
    // 调试函数已移动到DebugFunctions.swift
    
    // 获取指定用户的爱心状态
    // getHeartStatusForUser method moved to LegacySearchView+DataManagement.swift
    
    // 打印所有用户的爱心状态汇总
    // printHeartStatusSummary method moved to LegacySearchView+DataManagement.swift
    
    // 🔍 新增：打印我的好友列表
    // printMyFriendsList method moved to LegacySearchView+DataManagement.swift
    
    // 同步好友数据并打印列表
    // ⚠️ 已废弃：不再使用 MatchRecord 表
    // 现在使用 FriendshipManager 从 _Followee 表获取好友列表
    func syncFriendsAndPrintList() {
        // 此函数已被废弃，请使用 FriendshipManager.shared.fetchFriendsList
    }
    
    // 同步后打印好友列表
    // printFriendsListAfterSync method moved to LegacySearchView+DataManagement.swift
    
    // syncMessagesAndPrintNewFriendsList method moved to LegacySearchView+DataManagement.swift
    
    // printNewFriendsListAfterSync method moved to LegacySearchView+DataManagement.swift
    
    // printNewFriendsList method moved to LegacySearchView+DebugFunctions.swift
    
    // printLeanCloudTables method moved to LegacySearchView+DebugFunctions.swift
    
    // 打印FavoriteRecord表数据
    // printFavoriteRecordTable method moved to LegacySearchView+DebugFunctions.swift
    
    // 打印MatchRecord表数据
    // printMatchRecordTable method moved to LegacySearchView+DebugFunctions.swift
    
    // 🔧 新增：验证拍一拍消息同步结果
    // verifyPatMessageSync method moved to LegacySearchView+DataManagement.swift
    
    // 辅助函数：封装消息获取和打印逻辑
    // fetchAndPrintMessages method moved to LegacySearchView+DataManagement.swift
    
    // 消息按钮点击处理逻辑 - 缓存优化版本，优先使用缓存数据
    // 注意：新朋友列表默认隐藏，只有点击新朋友按钮时才显示
    // handleMessageButtonTap method moved to LegacySearchView+DataManagement.swift
    
    // updateAllFriendsAvatarsInRealTime method moved to LegacySearchView+DataManagement.swift
    
    // 从服务器获取数据
    // fetchDataFromServer method moved to LegacySearchView+DataFetching.swift
    
    // 在后台更新缓存
    // updateCachesInBackground method moved to LegacySearchView+DataFetching.swift
    
    // MARK: - 用户头像获取方法
    
    /// 从UserAvatarRecord表获取正确的用户头像 - 只从UserAvatarRecord表读取
    // getCorrectUserAvatar method moved to LegacySearchView+DataFetching.swift
    
    // MARK: - MatchRecord保存方法
    
    /// 将MatchRecord保存到LeanCloud
    // saveMatchRecordsToLeanCloud method moved to LegacySearchView+DataManagement.swift
    
    // MARK: - Match Status Detection
    
    /**
     * 检测并更新消息的匹配状态
     */
    // detectAndUpdateMatchStatus method moved to LegacySearchView+DataManagement.swift
    
    /**
     * 处理匹配成功事件
     */
    // handleMatchSuccess method moved to LegacySearchView+DataManagement.swift
    
    /**
     * 更新指定用户相关消息的匹配状态
     */
    // updateMessageMatchStatusForUser method moved to LegacySearchView+DataManagement.swift
    
    /**
     * 标记相关消息为已读（匹配成功时调用）
     */
    // markRelatedMessagesAsRead method moved to LegacySearchView+MessageHandling.swift
    
    // MARK: - 缓存管理方法
    
    /// 获取缓存的喜欢记录
    // getCachedFavoriteRecords method moved to LegacySearchView+DataManagement.swift
    
    /// 获取缓存的喜欢我的用户记录
    // getCachedUsersWhoLikedMe method moved to LegacySearchView+DataManagement.swift
    
    // cacheFavoriteRecords and cacheUsersWhoLikedMe methods moved to LegacySearchView+DataManagement.swift
    
    /// 获取缓存的消息数据
    // getCachedMessages method moved to LegacySearchView+CacheManagement.swift
    
    /// 获取缓存的拍一拍消息数据
    // getCachedPatMessages method moved to LegacySearchView+CacheManagement.swift
    
    /// 获取缓存的好友数据
    // getCachedFriends method moved to LegacySearchView+CacheManagement.swift
    
    /// 缓存消息数据
    // cacheMessages method moved to LegacySearchView+CacheManagement.swift
    
    /// 缓存拍一拍消息数据（优化：增加缓存容量）
    // cachePatMessages method moved to LegacySearchView+CacheManagement.swift
    
    /// 缓存好友数据
    // cacheFriends method moved to LegacySearchView+CacheManagement.swift
    
    /// 使用缓存数据更新消息界面
    // updateMessageViewDataWithCache method moved to LegacySearchView+DataManagement.swift
    
    // 分析好友在线状态和3个表的数据
    // analyzeFriendsOnlineStatus method moved to LegacySearchView+DataManagement.swift
    
    // 分析用户在线状态
    // analyzeUserOnlineStatus method moved to LegacySearchView+DataManagement.swift
    
    // getFriendTableData method moved to LegacySearchView+DataManagement.swift
    
    // 格式化时间差 - 已替换为统一的TimeAgoUtils.formatTimeAgo()方法
    
    
    // 根据用户ID获取用户名
    // getUserNameById method moved to LegacySearchView+DataManagement.swift
    
    // 获取指定用户的消息
    // getMessagesForUser method moved to LegacySearchView+DataManagement.swift
    
    // 强制更新全局缓存（每次点击消息按钮时调用）
    // forceUpdateGlobalCache method moved to LegacySearchView+DataManagement.swift
    
    
    // 打印好友列表信息
    // printFriendsListInfo method moved to LegacySearchView+DataManagement.swift
    
    // 获取好友列表
    // getFriendsList method moved to LegacySearchView+DataManagement.swift
    
    // 获取好友的最近上线时间（使用统一方法）
    // getFriendLastOnlineTime method moved to LegacySearchView+DataManagement.swift
    
    // 打印好友列表和登录记录
    // printFriendsListAndLoginRecords method moved to LegacySearchView+DataManagement.swift
            
            // 打印LoginRecord表内容
    // printLoginRecords method moved to LegacySearchView+DataManagement.swift
            
            // 打印InternalLoginRecord表内容
    // printInternalLoginRecords method moved to LegacySearchView+DataManagement.swift
    
    // 检查匹配成功UI显示与好友数量的一致性
    // checkMatchStatusConsistency method moved to LegacySearchView+DataManagement.swift
    
    
    // 打印新的朋友列表内容
    // printNewFriendsList method moved to LegacySearchView+DataManagement.swift
    
    // 保存喜欢记录
    // saveFavoriteRecords method moved to LegacySearchView+DataManagement.swift
    
    // 添加喜欢记录（乐观更新版本 - 立即UI响应）
    // MARK: - 喜欢记录管理已移至 LegacySearchView+FavoriteManagement.swift
    
    // 移除喜欢记录（乐观更新版本 - 立即UI响应）
    // func removeFavoriteRecord - moved to LegacySearchView+FavoriteManagement.swift
    
    // 回滚添加喜欢的UI状态
    // rollbackFavoriteUI method moved to LegacySearchView+DataManagement.swift
    
    // 回滚取消喜欢的UI状态
    // rollbackUnfavoriteUI method moved to LegacySearchView+DataManagement.swift
    
    // 🎯 新增：处理解除好友关系（删除好友关系 + 取消爱心点亮）
    // func handleUnfriend - moved to LegacySearchView+FavoriteManagement.swift
    
    // 处理拍一拍消息接收
    // handlePatMessageReceived method moved to LegacySearchView+DataManagement.swift
    
    // 检查用户是否已被喜欢
    // func isUserFavorited - moved to LegacySearchView+FavoriteManagement.swift
    
    // ⚠️ 已废弃：清理服务器上的重复MatchRecord记录
    // 不再使用 MatchRecord 表管理好友关系
    @available(*, deprecated, message: "MatchRecord is no longer used for friendship management")
    func cleanupDuplicateMatchRecords(userId: String) {
        // 此方法已废弃，不再执行任何操作
    }

    // 打印MatchRecord和FavoriteRecord表状态
    // ⚠️ 已废弃：不再打印 MatchRecord 表状态
    // printTableStatus and debugPrintFavoriteRecordState methods moved to LegacySearchView+DataManagement.swift
    
    // 检查指定用户是否喜欢了当前用户（从FavoriteRecord表查询）
    // func isUserFavoritedByMe - moved to LegacySearchView+FavoriteManagement.swift
    
    // getLatestUserAvatar method moved to LegacySearchView+DataManagement.swift
    
    // 打印UserScore表内容
    // func printUserScoreTableContent - moved to LegacySearchView+UserScore.swift
    // func printUserNameRecordTableContent - moved to LegacySearchView+UserScore.swift
    // func printLocationRecordTableContent - moved to LegacySearchView+UserScore.swift
    
    // 点赞记录键名获取
    // getLikeRecordsKey method moved to LegacySearchView+DataManagement.swift
    
    // 加载点赞记录
    // loadLikeRecords method moved to LegacySearchView+DataManagement.swift
    
    // 保存点赞记录
    // saveLikeRecords method moved to LegacySearchView+DataManagement.swift
    
    // MARK: - 点赞记录管理已移至 LegacySearchView+LikeManagement.swift
    // func addLikeRecord - moved to LegacySearchView+LikeManagement.swift
    // func removeLikeRecord - moved to LegacySearchView+LikeManagement.swift
    // func isUserLiked - moved to LegacySearchView+LikeManagement.swift
    // func isLocationRecordLiked - moved to LegacySearchView+LikeManagement.swift
    // func getLikedLocationRecordObjectIds - moved to LegacySearchView+LikeManagement.swift
    // func clearLikedLocationRecords - moved to LegacySearchView+LikeManagement.swift
    // func printLikedLocationRecords - moved to LegacySearchView+LikeManagement.swift
    
    // 存储喜欢当前用户的用户列表
    @State var usersWhoLikedMe: [FavoriteRecord] = []
    
    // MARK: - 用户积分管理已移至 LegacySearchView+UserScore.swift
    // func updateUserScore - moved to LegacySearchView+UserScore.swift
    // func getLatestUserLocation - moved to LegacySearchView+UserScore.swift
    // func uploadUserScoreWithLocation - moved to LegacySearchView+UserScore.swift
    // func calculateFavoriteCount - moved to LegacySearchView+UserScore.swift
    // func getFavoriteCount - moved to LegacySearchView+UserScore.swift
    // func getLikeCount - moved to LegacySearchView+UserScore.swift
    // func updateUserScoreLocation - moved to LegacySearchView+UserScore.swift
    // func printUserScoreTableContent - moved to LegacySearchView+UserScore.swift
    // func printUserNameRecordTableContent - moved to LegacySearchView+UserScore.swift
    // func printLocationRecordTableContent - moved to LegacySearchView+UserScore.swift
    
    // loadUsersWhoLikedMe method moved to LegacySearchView+DataManagement.swift
    
    // 创建双向喜欢逻辑的好友记录
    // createMatchRecordsFromDualLike method moved to LegacySearchView+DataManagement.swift
    
    // 验证usersWhoLikedMe与消息历史的一致性
    // validateUsersWhoLikedMeWithMessageHistory method moved to LegacySearchView+DataManagement.swift
    
    // 获取当前用户头像
    // getCurrentUserAvatar method moved to LegacySearchView+DataManagement.swift
    
    // 发送取消喜欢消息
    // 使用正确用户名发送取消好友申请消息
    // MARK: - 消息发送功能已移至 LegacySearchView+MessageSending.swift
    // func sendUnfavoriteMessageWithCorrectName - moved to LegacySearchView+MessageSending.swift
    // func sendUnfavoriteMessage - moved to LegacySearchView+MessageSending.swift
    
    // 发送同意好友申请消息
    // sendAcceptMessage method moved to LegacySearchView+MessageSending.swift
    
    // 发送拒绝好友申请消息
    // sendRejectMessage method moved to LegacySearchView+MessageSending.swift
    
    // 发送取消点赞消息
    // sendUnlikeMessage method moved to LegacySearchView+MessageSending.swift
    
    // 更新MatchRecord表状态
    // updateMatchRecordStatusForUsers method moved to LegacySearchView+MessageSending.swift
    
    // 发送点赞消息
    // sendLikeMessage method moved to LegacySearchView+MessageSending.swift
    
    // cleanupInvalidFavoriteRecords method moved to LegacySearchView+DataManagement.swift
    
    // 🔧 新增：打印Message表数据
    // printMessageTable method moved to LegacySearchView+DataManagement.swift
    
    // 🔧 新增：强制以服务器数据为准，清理本地不一致数据
    // forceSyncWithServerData method moved to LegacySearchView+DataManagement.swift
    
    // 从LeanCloud同步喜欢记录（同步所有记录，包括cancelled状态）
    // syncFavoriteRecordsFromLeanCloud method moved to LegacySearchView+DataManagement.swift
    
    // 从LeanCloud同步点赞记录
    // syncLikeRecordsFromLeanCloud method moved to LegacySearchView+DataManagement.swift
    
    // 处理历史记录点击，直接匹配该用户（不消耗钻石）- 与排行榜逻辑一致：从服务器获取最新位置记录
    // func handleHistoryItemTap - moved to ContentView+HistoryHandling.swift
    
    // 处理搜索用户点击，直接匹配该用户（不消耗钻石）- 与历史记录逻辑一致：从服务器获取最新位置记录
    // func handleUserSearchTap - moved to ContentView+HistoryHandling.swift
    
    // 处理排行榜项目点击，直接匹配该用户（不消耗钻石）- 与历史记录逻辑一致：从服务器获取最新位置记录
    // func handleRankingItemTap - moved to ContentView+HistoryHandling.swift
    
    // 处理推荐榜项目点击 - 与历史记录逻辑一致
    // func handleRecommendationItemTap - moved to ContentView+HistoryHandling.swift
    
    // 处理消息点击，直接匹配该用户（不消耗钻石）- 与历史记录逻辑一致
    // func handleMessageTap - moved to ContentView+HistoryHandling.swift
    
    // 设置匹配结果的辅助方法
    // setMatchResult method moved to LegacySearchView+DataManagement.swift
    
    // 注意：uploadMatchRecordToLeanCloud方法已移除
    // MatchRecord现在从Message表读取数据生成，不再本地上传
    
    // 🚀 新增：将匹配结果添加到所有好友匹配结果数组中
    // addToAllFriendsMatchResults method moved to LegacySearchView+DataManagement.swift
    
    // 计算好友申请相关消息数量（同步时使用，与MessageView逻辑一致）
    // calculateFriendRequestCount method moved to LegacySearchView+DataManagement.swift
    
    // 从LeanCloud同步好友申请数据（已移除 Message 表查询）
    // syncMessagesFromLeanCloud method moved to LegacySearchView+MessageHandling.swift
    
    // 打印好友列表
    // printFriendsList method moved to LegacySearchView+DataManagement.swift
    
    // 打印好友列表详情
    // printFriendsListDetails method moved to LegacySearchView+DataManagement.swift
    
    // calculateUnreadPendingCount method moved to LegacySearchView+MessageHandling.swift
    
    // sendLocationToServer method moved to LegacySearchView+LocationService.swift
    
    // continueLocationSend method moved to LegacySearchView+LocationAndBlacklist.swift
    

    

    

    
    // 时间戳格式化已移至 TimestampUtils.swift
    // 时间差计算已移至 TimeAgoUtils.swift
    
    // 距离计算已移至 DistanceUtils.swift
    
    // 方向计算已移至 BearingUtils.swift
    
    // 时区计算已移至 TimezoneUtils.swift
    
    // 中国范围判断已移至 TimezoneUtils.swift
    
    // 时区显示判断已移至 TimezoneUtils.swift
    
    // 时区名称获取已移至 TimezoneUtils.swift
    
    // 方向文字描述已移至 BearingUtils.swift
    
    // 距离格式化已移至 DistanceUtils.swift
    
    // fetchRandomRecord method moved to LegacySearchView+LocationAndBlacklist.swift
    

    
    // 历史记录键名获取已移至 StorageKeyUtils.swift
    
    // 举报记录键名获取已移至 StorageKeyUtils.swift
    
    // saveRandomMatchHistory method moved to LegacySearchView+LocationAndBlacklist.swift
    
    // loadRandomMatchHistory method moved to LegacySearchView+LocationAndBlacklist.swift
    
    // addRandomMatchToHistory method moved to LegacySearchView+LocationAndBlacklist.swift
    
    // clearRandomMatchHistory method moved to LegacySearchView+LocationAndBlacklist.swift
    

    
    // 删除单个历史记录项
    // func deleteRandomMatchHistoryItem - moved to ContentView+HistoryHandling.swift
    
    // saveReportRecords method moved to LegacySearchView+LocationAndBlacklist.swift
    
    // loadReportRecords method moved to LegacySearchView+LocationAndBlacklist.swift
    
    // All blacklist and location methods moved to LegacySearchView+LocationAndBlacklist.swift
    
    // silentCleanLocationRecords method moved to LegacySearchView+LocationService.swift
    
    // 用户类型背景颜色获取已移至 UserTypeUtils.swift

// 指南针视图组件

    // 更新UserScore表中的位置信息
    // func updateUserScoreLocation - moved to LegacySearchView+UserScore.swift
    
    // 打印爱心点击后的调试信息
    // printDebugInfoAfterHeartClick method moved to LegacySearchView+DebugAndUI.swift
    
    // showMapSelectionForLocation method moved to LegacySearchView+DebugAndUI.swift
    
    // handleUnfriend method moved to LegacySearchView+DebugAndUI.swift
    
    // deleteFriendRequestMessages method moved to LegacySearchView+DataManagement.swift
    
    // updateMessageViewData method moved to LegacySearchView+DataManagement.swift
    
    // 计算最短路径角度差
    
}

#Preview {
    ContentView()
}

// 举报记录UI数据模型

// 状态标签视图

// AvatarZoomView 已移至 Views/Avatar/AvatarZoomView.swift
 // 头像预览视图已移至 Views/Preview/MatchedAvatarPreviewView.swift

// IAP充值界面已移至 Views/Preview/RealIAPRechargeView.swift

// IAP商品卡片已移至 Views/Preview/IAPProductCard.swift
// 消息界面已移至 Views/Preview/MessageView.swift

    // printAllUserTables method moved to LegacySearchView+DebugAndUI.swift
    
    
    // MARK: - 消息实时刷新定时器管理
    
    // 启动消息刷新定时器
    // Timer methods moved to appropriate extensions
    
    /// 设置 IM 消息监听
    func setupIMListener() {
        // IM listener setup
    }
    
    /// 启动消息刷新定时器
    func startMessageRefreshTimer() {
        // Timer setup
    }
    
    // IM methods moved to appropriate extensions

// 🚀 新增：好友匹配结果卡片组件

