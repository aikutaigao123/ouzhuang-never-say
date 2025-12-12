//
//  ContentView+Navigation.swift
//  NeverSayNo
//
//  Created by Die chen on 2025/7/1.
//

import SwiftUI
import Foundation
import Combine

extension ContentView {
    
    // MARK: - 安全导航方法
    
    /// 安全的导航路径管理
    func safeNavigate(to destination: String) {
        NavigationHelpers.safeNavigate(
            to: destination,
            path: $path,
            isNavigating: $isNavigating,
            navigationLock: navigationLock
        )
    }
    
    /// 安全清理导航路径
    func safeClearPath() {
        
        NavigationHelpers.safeClearPath(
            path: $path,
            isNavigating: $isNavigating,
            navigationLock: navigationLock
        )
        
    }
    
    // MARK: - 导航事件处理
    
    /// 处理路径变化
    func handlePathChange(oldPath: [String], newPath: [String]) {
        
        // 类型安全检查：确保路径中只包含字符串类型
        if !newPath.isEmpty {
            // 由于newPath已经是[String]类型，不需要类型检查
            DispatchQueue.main.async {
                self.path = newPath
            }
            return
        }
        
        // 当路径变化时，如果不在搜索页面或用户信息页面且用户已登录，说明用户返回了
        // 但是用户信息确认后的正常返回不应该注销用户
        if newPath.isEmpty && userManager.isLoggedIn {
            // 只有在特定情况下才注销，比如用户主动返回登录界面
            // 用户信息确认后的正常返回不应该注销
            // 暂时注释掉自动注销逻辑，让用户信息确认后正常返回主界面
            // userManager.logout()
        }
        
        // 导航状态保护：防止并发导航操作
        if !newPath.isEmpty && isNavigating {
            // 如果正在导航中，延迟处理路径变化
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.isNavigating = false
            }
        }
    }
    
    // MARK: - 登录后导航逻辑
    
    /// 处理登录成功后的导航
    func handleLoginNavigation() {
        // ❌ 不再在登录时立即加载消息，避免导致视图重新渲染和重新创建fullScreenCover，造成空白期
        // 消息将在用户信息确认界面的 onConfirm 闭包中加载
        
        // 检查是否是从"我"界面或个人信息界面退出登录后重新登录
        // 如果是，直接返回主界面，避免导航状态冲突
        let isFromProfileTabLogout = UserDefaults.standard.bool(forKey: "isFromProfileTabLogout")
        let isFromProfileViewLogout = UserDefaults.standard.bool(forKey: "isFromProfileViewLogout")
        
        
        if isFromProfileTabLogout || isFromProfileViewLogout {
            // 清除标志
            UserDefaults.standard.set(false, forKey: "isFromProfileTabLogout")
            UserDefaults.standard.set(false, forKey: "isFromProfileViewLogout")
            return
        }
        
        // 根据登录类型决定展示方式
        let loginType = userManager.currentUser?.loginType
        
        // Apple登录：由 onChange(of: userManager.isLoggedIn) 处理显示信息确认界面（使用fullScreenCover）
        if loginType == .apple {
        } else {
            // 游客登录或其他登录类型：由 onChange(of: userManager.isLoggedIn) 处理显示信息确认界面
        }
        
    }
    
    // MARK: - 导航目标视图构建器
    
    /// 构建导航目标视图
    @ViewBuilder
    func navigationDestinationView(for value: String) -> some View {
        
        if value == "userInfo" {
            UserInfoConfirmView(
                userManager: userManager,
                onConfirm: {
                    // 用户信息确认后再次同步消息
                    loadMessagesOnLogin()
                    // 直接回到主界面（带TabBar），不需要跳转 - 使用安全清理
                    safeClearPath()
                },
                onBack: {
                    userManager.logout()
                }
            )
            .navigationBarTitleDisplayMode(.inline)
        // internalUserInfo 已删除（内部用户登录已移除）
        } else if value == "guestInfo" {
            Group {
                GuestInfoConfirmationView(
                    displayName: .constant(userManager.currentUser?.fullName ?? ""),
                    email: .constant(userManager.currentUser?.email ?? ""),
                    onConfirm: {
                        // 用户信息确认后再次同步消息
                        loadMessagesOnLogin()
                        // 直接回到主界面（带TabBar），不需要跳转 - 使用安全清理
                        safeClearPath()
                    },
                    onCancel: {
                        userManager.logout()
                    },
                    userManager: userManager
                )
            }
        } else if value == "search" {
            LegacySearchView(
                locationManager: locationManager,
                userManager: userManager,
                stateManager: stateManager,
                unreadMessageCount: $unreadMessageCount,
                newFriendsCountManager: newFriendsCountManager,
                onBack: {
                    userManager.logout()
                }
            )
            .navigationBarTitleDisplayMode(.inline)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                // 应用重新激活时检查是否需要更新 Apple ID 信息
                userManager.checkAndUpdateAppleIDInfo()
            }
        }
    }
    
    // MARK: - 导航观察者设置
    
    /// 设置导航相关的观察者
    private func setupNavigationObservers() {
        // 路径变化观察
        // 注意：这个需要在主视图中调用 .onChange(of: path) 来使用
    }
    
    // MARK: - TabBar按钮处理
    
    /// 处理底部TabBar按钮点击
    func handleTabBarButtonTap(oldTab: Int, newTab: Int) {
        // 根据不同的标签页处理不同的逻辑
        switch newTab {
        case 0:
            break
        case 1:
            break
        case 2:
            break
        case 3:
            // 使用与主界面消息按钮相同的处理逻辑
            handleMessageButtonTapForTabBar()
        case 4:
            break
        default:
            break
        }
    }
    
    /// 为底部TabBar处理消息按钮点击（与主界面消息按钮保持一致）
    func handleMessageButtonTapForTabBar() {
        // 🎯 新增：检查消息按钮点击次数限制
        guard let currentUser = userManager.currentUser else {
            return
        }
        let userId = currentUser.id
        let (canClick, message) = UserDefaultsManager.canClickMessageButton(userId: userId)
        if !canClick {
            // 超过限制，显示提示
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("MessageButtonLimitExceeded"),
                    object: nil,
                    userInfo: ["message": message, "showAlert": true]
                )
            }
            return
        }
        
        // 记录点击
        UserDefaultsManager.recordMessageButtonClick(userId: userId)
        
        // 从FriendshipManager获取好友列表，并从服务器获取消息数据
        FriendshipManager.shared.fetchFriendsList { friends, error in
            DispatchQueue.main.async {
                if error != nil {
                } else if let friends = friends {
                    if friends.isEmpty {
                    } else {
                        guard let currentUser = self.userManager.currentUser else {
                            return
                        }
                        
                        // 从服务器获取所有消息数据
                        LeanCloudService.shared.fetchMessages(userId: currentUser.id) { allMessages, _ in
                            DispatchQueue.main.async {
                                let allMessagesList = allMessages ?? []
                                
                                // 过滤拍一拍消息
                                let patMessages = MessageUtils.filterPatMessagesByUserId(allMessagesList, currentUserId: currentUser.id)
                                _ = MessageUtils.processPatMessages(patMessages)
                                
                                // 过滤普通消息（排除拍一拍）
                                _ = allMessagesList.filter { message in
                                    let isNotPatMessage = message.messageType != "pat" && !message.content.contains("拍了拍")
                                    return isNotPatMessage
                                }
                            }
                        }
                    }
                } else {
                }
            }
        }
        
        
        // 显示消息界面
        stateManager.showMessageSheet = true
        
    }
    
    
    
    
    // MARK: - 历史记录匹配方法
    
    // 显示历史记录中的匹配结果（不扣除钻石，但添加到历史记录）
    func showHistoricalMatch(record: LocationRecord) {


        // 进入加载状态
        isLoadingRandomRecord = true

        // 清空所有好友匹配结果数组，确保只显示单个匹配卡片（与历史记录按钮行为一致）
        allFriendsMatchResults = []

        let targetUserId = record.userId

        // 🎯 新增：判断是否来自推荐榜（通过placeName或reason字段判断）
        let hasPlaceName = (record.placeName?.isEmpty == false)
        let hasReason = (record.reason?.isEmpty == false)
        let isFromRecommendation = hasPlaceName || hasReason

        
        // 🎯 修改：如果来自推荐榜，直接使用Recommendation表中的经纬度，不查询服务器
        if isFromRecommendation {

            // 停止加载动画
            self.isLoadingRandomRecord = false

            // 尝试补全 loginType
            let resolvedLoginType = record.loginType ?? UserTypeUtils.getLoginTypeFromUserId(record.userId)

            // 直接使用推荐榜的LocationRecord，确保使用Recommendation表中的经纬度
            let adjustedRecord = LocationRecord(
                id: record.id,
                objectId: record.objectId,
                timestamp: record.timestamp,
                latitude: record.latitude, // 🎯 使用Recommendation表中的经纬度
                longitude: record.longitude, // 🎯 使用Recommendation表中的经纬度
                accuracy: record.accuracy,
                userId: record.userId,
                userName: record.userName,
                loginType: resolvedLoginType,
                userEmail: record.userEmail,
                userAvatar: record.userAvatar,
                deviceId: record.deviceId,
                clientTimestamp: record.clientTimestamp,
                timezone: record.timezone,
                status: record.status,
                recordCount: record.recordCount,
                likeCount: record.likeCount,
                placeName: record.placeName, // 🎯 保留推荐榜的地名
                reason: record.reason // 🎯 保留推荐榜的理由
            )

            
            // 显示匹配结果
            
            SearchUtils.showHistoricalMatch(
                record: adjustedRecord,
                randomRecord: self.$randomRecord,
                randomRecordNumber: self.$randomRecordNumber
            )
            
            // 异步刷新对方头像为最新
            self.ensureLatestAvatar(userId: adjustedRecord.userId, loginType: adjustedRecord.loginType)
            
            // 添加到历史记录（从消息或好友点击跳转过来的匹配）
            self.addRandomMatchToHistory(record: adjustedRecord, recordNumber: self.randomRecordNumber)
        } else {
            // 🎯 非推荐榜来源，从服务器获取最新位置记录
            
            
            let applyRecord: (LocationRecord) -> Void = { latestRecord in
                
                // 停止加载动画
                self.isLoadingRandomRecord = false
                
                // 尝试补全 loginType
                let resolvedLoginType = latestRecord.loginType ?? UserTypeUtils.getLoginTypeFromUserId(latestRecord.userId)
                
                // 使用从服务器获取的最新位置
                let adjustedRecord = LocationRecord(
                    id: latestRecord.id,
                    objectId: latestRecord.objectId,
                    timestamp: latestRecord.timestamp,
                    latitude: latestRecord.latitude,
                    longitude: latestRecord.longitude,
                    accuracy: latestRecord.accuracy,
                    userId: latestRecord.userId,
                    userName: latestRecord.userName,
                    loginType: resolvedLoginType,
                    userEmail: latestRecord.userEmail,
                    userAvatar: latestRecord.userAvatar,
                    deviceId: latestRecord.deviceId,
                    clientTimestamp: latestRecord.clientTimestamp,
                    timezone: latestRecord.timezone,
                    status: latestRecord.status,
                    recordCount: latestRecord.recordCount,
                    likeCount: latestRecord.likeCount,
                    placeName: latestRecord.placeName,
                    reason: latestRecord.reason
                )
                
                // 显示匹配结果
                
                SearchUtils.showHistoricalMatch(
                    record: adjustedRecord,
                    randomRecord: self.$randomRecord,
                    randomRecordNumber: self.$randomRecordNumber
                )
                
                // 异步刷新对方头像为最新
                self.ensureLatestAvatar(userId: adjustedRecord.userId, loginType: adjustedRecord.loginType)
                
                // 添加到历史记录（从消息或好友点击跳转过来的匹配）
                self.addRandomMatchToHistory(record: adjustedRecord, recordNumber: self.randomRecordNumber)
            }
            
            // 从服务器获取最新位置记录
            LeanCloudService.shared.fetchLatestLocationForUser(userId: targetUserId) { latestRecord, error in
                DispatchQueue.main.async {
                    if let latestRecord = latestRecord {
                        applyRecord(latestRecord)
                    } else {
                        applyRecord(record)
                    }
                }
            }
        }
    }
    
    // 添加到历史记录
    func addRandomMatchToHistory(record: LocationRecord, recordNumber: Int) {
        // 🎯 新增：检查本地黑名单
        let localBlacklistedUserIds = LocalBlacklistManager.shared.getAllLocalBlacklistedUserIds()
        if localBlacklistedUserIds.contains(record.userId) {
            // 用户在本地黑名单中，跳过添加
            return
        }
        
        // 检查是否在黑名单中（检查用户名或设备ID）或待删除账号
        if blacklistedUserIds.contains(record.userName ?? "") ||
            blacklistedUserIds.contains(record.deviceId) ||
            pendingDeletionUserIds.contains(record.userId) ||
            (record.userName != nil && pendingDeletionUserIds.contains(record.userName!)) ||
            pendingDeletionUserIds.contains(record.deviceId) {
            // 用户在黑名单中，跳过添加
            return
        }
        
        // 检查是否已经存在该用户的历史记录（避免重复）
        let existingIndex = randomMatchHistory.firstIndex { $0.record.userId == record.userId }
        if let index = existingIndex {
            // 如果已存在，移除旧记录，添加新记录（移动到最前面）
            randomMatchHistory.remove(at: index)
            let currentLocation = locationManager.location?.coordinate
            let newHistory = RandomMatchHistory(record: record, recordNumber: recordNumber, currentLocation: currentLocation)
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
    
    // 刷新用户头像为最新
    func ensureLatestAvatar(userId: String, loginType: String?) {
        LeanCloudService.shared.fetchUserAvatarByUserId(objectId: userId) { avatar, _ in
            DispatchQueue.main.async {
                if let avatar = avatar, !avatar.isEmpty {
                    self.latestAvatars[userId] = avatar
                }
            }
        }
    }
    
    // 添加到所有好友匹配结果数组
    func addToAllFriendsMatchResults(record: LocationRecord) {
        SearchUtils.addToAllFriendsMatchResults(
            record: record,
            allFriendsMatchResults: $allFriendsMatchResults
        )
    }
    
}
