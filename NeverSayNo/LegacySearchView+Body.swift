//
//  LegacySearchView+Body.swift
//  NeverSayNo
//
//  Created by Die chen on 2025/7/1.
//

import SwiftUI
import Foundation
import Combine

extension LegacySearchView {
    // MARK: - Body View
    
    var body: some View {
        VStack {
            // 顶部导航栏
            SearchNavigationBar(
                userManager: userManager,
                diamondManager: diamondManager,
                newFriendsCountManager: newFriendsCountManager,
                showAvatarZoom: $showAvatarZoom,
                showProfileSheet: $showProfileSheet,
                showRechargeSheet: $showRechargeSheet,
                showRankingSheet: $showRankingSheet,
                showMessageSheet: $showMessageSheet,
                randomRecord: randomRecord,
                onMessageButtonTap: handleMessageButtonTap,
                isUserFavorited: isUserFavorited,
                isUserLiked: isUserLiked
            )
            
            // 指南针容器
            SearchCompassView(
                locationManager: locationManager,
                randomRecord: randomRecord
            )
            
            // 寻找按钮
            SearchButton(
                locationManager: locationManager,
                diamondManager: diamondManager,
                isLoading: $isLoading,
                isUserBlacklisted: $isUserBlacklisted,
                onSearch: {
                    sendLocationToServer()
                },
                onRecharge: {
                    showRechargeSheet = true
                },
                onRandomMatch: { record in
                    // 🎯 新增：钻石为0时的随机匹配处理
                    randomRecord = record
                    randomRecordNumber = Int.random(in: 1...40) // 随机序号（从40条中选的）
                    isLoading = false
                    
                    // 🎯 新增：添加到历史记录
                    addRandomMatchToHistory(record: record, recordNumber: randomRecordNumber)
                }
            )
            .padding(.top, 20)
            
            // 消耗钻石说明
            if !isLoading && !isUserBlacklisted {
                SearchUIComponents.diamondCostHint(diamondManager: diamondManager)
            }
            
            // 位置状态提示
            if locationManager.location == nil && !isLoading && !isUserBlacklisted {
                SearchUIComponents.locationStatusHint()
            }
            
            // 倒计时显示
            if isUserBlacklisted && !timeRemaining.isEmpty {
                SearchUIComponents.timeRemainingHint(timeRemaining)
            }
            
            // 🚀 修改：显示所有好友的匹配结果
            if !allFriendsMatchResults.isEmpty {
                // 显示所有好友匹配结果
                VStack(spacing: 16) {
                    SimpleViews.FriendsMatchStatusTitle()
                    
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(allFriendsMatchResults, id: \.userId) { record in
                                FriendMatchResultCard(record: record, latestAvatars: latestAvatars, latestUserNames: latestUserNames)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            } else if let record = randomRecord {
                // 🎯 新增：打印匹配卡片渲染条件
                // 注意：这里会多次触发，因为 SwiftUI 的 body 会多次调用
                // 实际的卡片显示打印在 MatchResultCard.onAppear 中
                
                MatchResultCard(
                    record: record,
                    locationManager: locationManager,
                    userManager: userManager,
                    latestAvatars: latestAvatars,
                    latestUserNames: latestUserNames,
                    isUserFavorited: isUserFavorited,
                    isUserFavoritedByMe: isUserFavoritedByMe,
                    isLocationRecordLiked: isLocationRecordLiked,
                    addFavoriteRecord: addFavoriteRecord,
                    removeFavoriteRecord: removeFavoriteRecord,
                    addLikeRecord: { userId, userName, userEmail, loginType, userAvatar, objectId, isRecommendation in
                        self.addLikeRecord(userId: userId, userName: userName, userEmail: userEmail, loginType: loginType, userAvatar: userAvatar, recordObjectId: objectId, isRecommendation: isRecommendation)
                    },
                    removeLikeRecord: { userId, objectId, isRecommendation in
                        self.removeLikeRecord(userId: userId, recordObjectId: objectId, isRecommendation: isRecommendation)
                    },
                    showMapSelectionForLocation: { record in
                        let userName = latestUserNames[record.userId] ?? record.userName ?? "未知用户"
                        let (wgsLat, wgsLon) = CoordinateConverter.gcj02ToWgs84(
                            latitude: record.latitude,
                            longitude: record.longitude
                        )
                        selectedLocation = NavigationTarget(
                            userId: record.userId,
                            userName: userName,
                            loginType: record.loginType,
                            latitude: wgsLat,
                            longitude: wgsLon
                        )
                    },
                    showRankingSheet: {
                        selectedTab = 0
                                    showRankingSheet = true
                    },
                    showFriendRequestModal: {
                                    showFriendRequestModal = true
                    },
                    selectedTab: selectedTab,
                    copySuccessMessage: copySuccessMessage,
                    showCopySuccess: showCopySuccess,
                    setCopySuccessMessage: { message in
                        copySuccessMessage = message
                    },
                    setShowCopySuccess: { show in
                        showCopySuccess = show
                    },
                    ensureFavoriteState: {
                        self.loadUsersWhoLikedMe()
                        FriendshipManager.shared.fetchFriendsList { _, _ in }
                    },
                    onDeleteRecommendation: { // 🎯 新增：删除推荐榜记录
                        guard let record = randomRecord else {
                            return
                        }
                        // 检查是否来自推荐榜
                        let isFromRecommendation = (record.placeName?.isEmpty == false) || 
                                                   (record.reason?.isEmpty == false)
                        if isFromRecommendation && !record.objectId.isEmpty {
                            LeanCloudService.shared.deleteRecommendation(objectId: record.objectId) { success, error in
                                DispatchQueue.main.async {
                                    if success {
                                        // 删除成功，发送通知刷新推荐榜列表
                                        NotificationCenter.default.post(
                                            name: NSNotification.Name("RefreshRecommendationList"),
                                            object: nil
                                        )
                                        // 清除当前显示的记录
                                        randomRecord = nil
                                    }
                                }
                            }
                        }
                    }
                )
            } else {
                // 无匹配结果时的占位符
                EmptyState()
            }
            
            LoadingIndicator(isLoading: isLoadingRandomRecord)
            
            ResultMessage(message: resultMessage)
            
            // 复制成功提示
            SuccessToast(isVisible: showCopySuccess, message: copySuccessMessage)
            
            // 防刷提示
            WarningToast(isVisible: stateManager.showAntiSpamToast, message: stateManager.antiSpamMessage)
            
            // 拍一拍消息弹窗
            PatMessageAlert(
                isVisible: stateManager.showPatMessageAlert,
                senderName: stateManager.patMessageSenderName,
                receiverName: userManager.currentUser?.userId ?? "你",
                onAppear: {
                    stateManager.patMessageAlertCount += 1
                },
                onDisappear: {
                    // 拍一拍消息弹窗消失时的处理
                }
            )
        }
        .padding()
        .overlay(alignment: .top) {
            // 应用启动提示（显示在顶部，只在登录成功后显示）
            if stateManager.showAppLaunchToast && userManager.isLoggedIn {
                VStack {
                    InfoToast(
                        isVisible: stateManager.showAppLaunchToast,
                        message: stateManager.appLaunchMessage,
                        title: "欢迎使用 欧庄 - Never say No",
                        onAgree: {
                            // 点击同意，检查Blacklist字段
                            if stateManager.currentNotificationIsBlacklist {
                                // 如果Blacklist为true，退出登录
                                // 先关闭通知栏
                                stateManager.dismissAppLaunchToast()
                                // 执行退出登录
                                userManager.logout()
                                // 重置导航状态
                                DispatchQueue.main.async {
                                    NotificationCenter.default.post(name: NSNotification.Name("ResetNavigationState"), object: nil)
                                }
                            } else {
                                // 如果Blacklist为false，正常关闭通知栏
                                stateManager.dismissAppLaunchToast()
                            }
                        },
                        onDisagree: {
                            // 点击不同意，退出登录
                            // 先关闭通知栏
                            stateManager.dismissAppLaunchToast()
                            // 执行退出登录
                            userManager.logout()
                            // 重置导航状态
                            DispatchQueue.main.async {
                                NotificationCenter.default.post(name: NSNotification.Name("ResetNavigationState"), object: nil)
                            }
                        }
                    )
                    .padding(.top, 60) // 距离顶部60点，下移通知栏
                    Spacer()
                }
            }
        }
        .modifier(AlertDialogs(
            showAlert: $showAlert,
            showLogoutAlert: $showLogoutAlert,
            showEditNameAlert: $showEditNameAlert,
            showEditEmailAlert: $showEditEmailAlert,
            showCancelDeletionAlert: $showCancelDeletionAlert,
            showFriendRequestLimitAlert: $stateManager.showFriendRequestLimitAlert,
            showPatActionLimitAlert: $stateManager.showPatActionLimitAlert,
            showMessageButtonLimitAlert: $stateManager.showMessageButtonLimitAlert,
            newUserName: $newUserName,
            resultMessage: $resultMessage,
            pendingDeletionDate: $pendingDeletionDate,
            friendRequestLimitMessage: $stateManager.friendRequestLimitMessage,
            patActionLimitMessage: $stateManager.patActionLimitMessage,
            messageButtonLimitMessage: $stateManager.messageButtonLimitMessage,
            userManager: userManager,
           onLogout: {
               // 设置标志，表示是从个人信息界面退出登录
               UserDefaults.standard.set(true, forKey: "isFromProfileViewLogout")
               
               userManager.logout()
               
               // 重置导航状态，避免 SwiftUI 导航路径类型不匹配
               DispatchQueue.main.async {
                   // 发送通知重置导航状态
                   NotificationCenter.default.post(name: NSNotification.Name("ResetNavigationState"), object: nil)
               }
           },
            onUpdateUserName: { userName in
                userManager.updateUserName(userName)
            },
            onCancelDeletion: {
                cancelAccountDeletion()
            },
            onContinueDeletion: {
                // 继续删除，立即退出登录
                userManager.clearAppleIDStoredInfo()
                // 清除历史记录
                clearAllHistory()
                userManager.logout()
            }
        ))
        .modifier(NotificationObservers(
            showProfileSheet: $showProfileSheet,
            selectedTab: $selectedTab,
            onShowLatestMatch: { record in
                showHistoricalMatch(record: record)
            },
            onShowFriendLocation: { record in
                // 处理显示好友位置的逻辑
            }
        ))
        .onAppear {
            // 连接钻石管理器与用户管理器
            userManager.diamondManager = diamondManager
            
            // 通知观察者将在NotificationObservers中处理
            
            // 如果用户已经登录但钻石管理器还没有设置用户信息，重新设置
            if let currentUser = userManager.currentUser {
                let loginType: String
                switch currentUser.loginType {
                case .apple:
                    loginType = "apple"
                case .guest:
                    loginType = "guest"
                }
                diamondManager.setCurrentUser(userId: currentUser.userId, loginType: loginType, userName: currentUser.fullName, userEmail: currentUser.email)
            }
            
            // 进入页面时再次请求位置
            locationManager.requestLocation()
            // 启动方向更新
            locationManager.startHeadingUpdates()
            // 加载黑名单
            loadBlacklist()
            // 加载举报记录
            loadReportRecords()
            // 加载随机匹配历史记录（会在loadBlacklist中调用）
            // 检查历史记录，如果有记录则显示最新匹配结果
            if !randomMatchHistory.isEmpty {
                let latestHistory = randomMatchHistory.first!
                showHistoricalMatch(record: latestHistory.record)
            }
            // 加载喜欢记录
            loadFavoriteRecords()
            // 加载点赞记录
            loadLikeRecords()
            // 从LeanCloud同步喜欢记录
            syncFavoriteRecordsFromLeanCloud()
            // 从LeanCloud同步点赞记录
            syncLikeRecordsFromLeanCloud()
            // 查询谁喜欢了当前用户
            loadUsersWhoLikedMe()
            // 同步消息数据
            syncMessagesFromLeanCloud()
            // 确保MatchRecord表存在
            LeanCloudService.shared.ensureMatchRecordTableExists { success in
                if success {
                    // 表检查/创建成功
                } else {
                    // 表检查/创建失败
                }
            }
            
            // 🎯 新增：应用启动时自动检查并创建当前用户的UserNameRecord（如果不存在）
            if let currentUser = userManager.currentUser {
                let userId = currentUser.id
                let loginType = currentUser.loginType == .apple ? "apple" : "guest"
                let userName = currentUser.fullName
                let userEmail = currentUser.email
                
                LeanCloudService.shared.ensureCurrentUserUserNameRecordExists(
                    objectId: userId,
                    loginType: loginType,
                    userName: userName,
                    userEmail: userEmail
                ) { success, message in
                    if success {
                        // 记录已存在或创建成功
                    } else {
                        // 创建失败
                    }
                    
                    // 🎯 在UserNameRecord检查完成后，延迟执行UserAvatarRecord检查，避免请求过于频繁
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        LeanCloudService.shared.ensureCurrentUserAvatarRecordExists(
                            objectId: userId,
                            loginType: loginType,
                            userAvatar: nil // 传入nil会自动生成随机emoji
                        ) { success, message in
                            if success {
                                // 记录已存在或创建成功
                            } else {
                                // 创建失败
                            }
                        }
                    }
                }
            }
            
            // 延迟重新加载喜欢记录，确保数据同步
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                // 延迟重新加载喜欢记录
                self.loadUsersWhoLikedMe()
                // 注意：不在这里重新同步favoriteRecords，避免覆盖用户刚刚的解除关系操作
                // self.syncFavoriteRecordsFromLeanCloud()
                self.syncLikeRecordsFromLeanCloud()
            }
            // 如有未同步的充值余额，尝试重试
            diamondManager.retryPendingDiamondSync()
            diamondManager.checkDiamondSystemStatus()
            
            // 检查是否有待删除的账号请求
            checkPendingDeletionRequest()
            
            // 其他通知观察者将在NotificationObservers中处理
        }
        .modifier(OnDisappearLogic(
            locationManager: locationManager,
            stopCountdownTimer: stopCountdownTimer
        ))
        .sheet(isPresented: $showLocationHistory) {
            LocationHistoryView(locations: locationHistory, isLoading: false)
        }
                 .sheet(isPresented: $showRandomHistory, onDismiss: {
                     // 发送通知关闭个人信息界面，直接返回到主界面
                     NotificationCenter.default.post(name: NSNotification.Name("DismissProfileSheet"), object: nil)
                 }) {
            ZStack {
                // 背景点击区域 - 使用全屏背景
                Color.black.opacity(0.001) // 几乎透明但可点击
                    .ignoresSafeArea()
                    .onTapGesture {
                        showRandomHistory = false
                        // 发送通知关闭个人信息界面，直接返回到主界面
                        NotificationCenter.default.post(name: NSNotification.Name("DismissProfileSheet"), object: nil)
                    }
                
                // 🔧 修复：使用条件渲染避免重复初始化
                if showRandomHistory {
                    RandomMatchHistoryView(
                 history: randomMatchHistory, // 直接传递数组引用
                 calculateDistance: DistanceUtils.calculateDistance,
                 formatDistance: DistanceUtils.formatDistance,
                 formatTimestamp: TimestampUtils.formatTimestamp,
                 calculateBearing: BearingUtils.calculateBearing,
                 getDirectionText: BearingUtils.getDirectionText,
                 calculateTimezoneFromLongitude: TimezoneUtils.calculateTimezoneFromLongitude,
                 getTimezoneName: TimezoneUtils.getTimezoneName,
                 onClearHistory: clearRandomMatchHistory,
                 onDeleteHistoryItem: deleteRandomMatchHistoryItem,
                 onReportUser: { userId, userName, userEmail, reason, deviceId, loginType in
                     addReportRecord(reportedUserId: userId, reportedUserName: userName, reportedUserEmail: userEmail, reportReason: reason, reportedDeviceId: deviceId, reportedUserLoginType: loginType)
                 },
                 hasReportedUser: hasReportedUser,
                 avatarResolver: { uid, ltype, snapshot in
                     // 与用户头像界面一致：不使用全局缓存，优先使用本地缓存
                     if let uid = uid, let latest = latestAvatars[uid], !latest.isEmpty { return latest }
                     return snapshot
                 },
                 userNameResolver: { uid, ltype in
                     // 与用户头像界面一致：不使用全局缓存，优先使用本地缓存
                     if let uid = uid, let latest = latestUserNames[uid], !latest.isEmpty { return latest }
                     return nil
                 },
                 ensureLatestAvatar: { uid, ltype in
                     ensureLatestAvatar(userId: uid, loginType: ltype)
                 },
                 isUserFavorited: isUserFavorited,
                 isUserFavoritedByMe: isUserFavoritedByMe,
                 onToggleFavorite: { userId, userName, userEmail, loginType, userAvatar, recordObjectId in
                     if isUserFavorited(userId: userId) {
                         // 取消喜欢回调
                         removeFavoriteRecord(userId: userId)
                     } else {
                         // 喜欢回调
                         addFavoriteRecord(
                             userId: userId,
                             userName: userName,
                             userEmail: userEmail,
                             loginType: loginType,
                             userAvatar: userAvatar,
                             recordObjectId: recordObjectId
                         )
                     }
                 },
                 isUserLiked: isUserLiked,
                 onToggleLike: { userId, userName, userEmail, loginType, userAvatar, recordObjectId in
                     if isUserLiked(userId: userId) {
                         // 取消点赞回调
                         removeLikeRecord(userId: userId)
                     } else {
                         // 点赞回调
                         addLikeRecord(
                             userId: userId,
                             userName: userName,
                             userEmail: userEmail,
                             loginType: loginType,
                             userAvatar: userAvatar,
                             recordObjectId: recordObjectId
                         )
                     }
                 },
                 onHistoryItemTap: handleHistoryItemTap,
                 locationManager: locationManager,
                 selectedItemId: selectedHistoryId // 传递位置管理器用于动态距离计算
             )
             .background(Color.clear) // 防止历史记录内容拦截背景点击
                } // 🔧 修复：添加条件渲染的闭合括号
            }
         }
        .sheet(isPresented: $showRechargeSheet) {
            RechargeView(diamondManager: diamondManager)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TriggerSearchWithSkipCheck"))) { _ in
            // 🎯 新增：收到继续搜索通知，重新触发搜索（跳过默认邮箱检查）
            sendLocationToServer()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowProfileSheet"))) { _ in
            // 🎯 新增：收到显示个人资料页面的通知
            showProfileSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HistoryItemDeleted"))) { notification in
            // 🔧 修复：监听历史记录删除通知，同步更新LegacySearchView的randomMatchHistory
            if notification.object as? RandomMatchHistory != nil {
                // 🔧 修复：ContentView已经删除并保存到UserDefaults，所以直接重新加载即可
                // 不需要尝试从当前数组中删除，因为可能已经不存在了
                loadRandomMatchHistory()
            }
        }
        .sheet(isPresented: $showProfileSheet) {
            ProfileView(
                userManager: userManager,
                diamondManager: diamondManager,
                showLogoutAlert: $showLogoutAlert,
                showRechargeSheet: $showRechargeSheet,
                newUserName: $newUserName,
                isUserBlacklisted: isUserBlacklisted,
                onClearAllHistory: clearAllHistory,
                onShowHistory: {
                    // 🔧 如果数据为空，尝试重新加载
                    if randomMatchHistory.isEmpty {
                        loadRandomMatchHistory()
                        // 等待一下让数据加载完成
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            // 先关闭个人信息界面，然后显示历史记录界面
                            showProfileSheet = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                showRandomHistory = true
                            }
                        }
                    } else {
                        // 先关闭个人信息界面，然后显示历史记录界面
                        showProfileSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showRandomHistory = true
                        }
                    }
                },
                newFriendsCountManager: newFriendsCountManager,
                onNavigateToTab: { tabIndex in
                    // 关闭个人信息界面并切换到指定标签
                    selectedTab = tabIndex
                    showProfileSheet = false
                },
                showBottomTabBar: true
            )
        }
        .sheet(isPresented: $showAvatarZoom) {
            AvatarZoomView(userManager: userManager, showRandomButton: true)
        }
        .sheet(item: $selectedLocation) { location in
            MapSelectionView(
                userId: location.userId,
                userName: location.userName,
                loginType: location.loginType,
                latitude: location.latitude,
                longitude: location.longitude,
                locationManager: locationManager
            )
        }
        .sheet(isPresented: $showMessageSheet, onDismiss: {
            // 消息界面关闭后，重新同步消息数据
            syncMessagesFromLeanCloud()
        }) {
            
            MessageView(
                unreadCount: $unreadMessageCount, 
                newFriendsCountManager: newFriendsCountManager,
                userManager: userManager,
                stateManager: stateManager,
                onMessageTap: { message in
                    // 处理消息点击，直接匹配该用户
                    handleMessageTap(message: message)
                    // 🎯 修改：延迟关闭消息界面，等待 handleMessageTap 完成后再关闭
                    // 不立即关闭，让 handleMessageTap 异步完成后自动关闭
                },
                onUserSearchTap: { user in
                    // 处理搜索用户点击，直接匹配该用户（与历史记录逻辑一致）
                    handleUserSearchTap(user: user)
                },
                isUserFavorited: isUserFavorited,
                onToggleFavorite: { userId, userName, userEmail, loginType, userAvatar, recordObjectId in
                    if isUserFavorited(userId: userId) {
                        // 消息取消喜欢
                        removeFavoriteRecord(userId: userId)
                    } else {
                        // 消息喜欢
                        addFavoriteRecord(
                            userId: userId,
                            userName: userName,
                            userEmail: userEmail,
                            loginType: loginType,
                            userAvatar: userAvatar,
                            recordObjectId: recordObjectId
                        )
                    }
                    
                    let isMatched = isUserFavorited(userId: userId) && isUserFavoritedByMe(userId: userId)
                    
                    // 🚀 修复：立即更新相关消息的匹配状态
                    updateMessageMatchStatusForUser(userId: userId, isMatch: isMatched)
                },
                onRemoveFavorite: { userId in
                    // 直接移除喜欢记录，与取消爱心完全一致
                    removeFavoriteRecord(userId: userId)
                },
                isUserLiked: isUserLiked,
                onToggleLike: { userId, userName, userEmail, loginType, userAvatar, recordObjectId in
                    if isUserLiked(userId: userId) {
                        // 消息取消点赞
                        removeLikeRecord(userId: userId)
                    } else {
                        // 消息点赞
                        addLikeRecord(
                            userId: userId,
                            userName: userName,
                            userEmail: userEmail,
                            loginType: loginType,
                            userAvatar: userAvatar,
                            recordObjectId: recordObjectId
                        )
                    }
                },
                isUserFavoritedByMe: isUserFavoritedByMe,
                favoriteRecords: $favoriteRecords,
                onMessagesUpdated: {
                    // 🚀 新增：消息更新后，检测匹配状态
                    detectAndUpdateMatchStatus()
                },
                onPat: { friendId in
                    // 🚀 新增：处理拍一拍回调
                    handlePatFriendInMessageView(friendId: friendId)
                },
                onUnfriend: { friend in
                    // 🔧 新增：处理解除好友关系（视为取消爱心点亮）
                    handleUnfriend(friend)
                },
                showBottomTabBar: true, // 从搜索界面进入，显示底部按钮
                showFriendsList: true, // 搜索界面显示我的好友列表
                existingMessages: $messageViewMessages,
                existingFriends: $messageViewFriends,
                existingPatMessages: $messageViewPatMessages,
                existingAvatarCache: $messageViewAvatarCache,
                existingUserNameCache: $messageViewUserNameCache
            )
            .onAppear {
                // 再次确认进入后绑定值
            }
        }
                              .sheet(isPresented: $showRankingSheet) {
                          RankingView(
                            locationManager: locationManager, 
                            userManager: userManager, 
                            onRankingItemTap: handleRankingItemTap, 
                            onRecommendationItemTap: handleRecommendationItemTap,
                            initialTab: selectedTab,
                            selectedRecommendationId: selectedRecommendationId,
                            selectedRankingId: selectedRankingId
                          )
                          .onAppear {
                              // 🎯 新增：每次打开排行榜时，触发排行榜数据刷新，从而更新前3名缓存
                              // RankingView会在内部自动加载数据并更新缓存
                          }
                          .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshRecommendationList"))) { notification in
                              // 🎯 新增：监听刷新通知，如果包含新上传的项目ID，设置selectedRecommendationId
                              if let userInfo = notification.userInfo,
                                 let newObjectId = userInfo["selectedRecommendationId"] as? String {
                                  selectedRecommendationId = newObjectId
                              }
                          }
                          .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshRankingList"))) { notification in
                              // 🎯 新增：监听排行榜刷新通知，更新选中的排行榜项目ID
                              if let userInfo = notification.userInfo,
                                 let newItemId = userInfo["selectedRankingId"] as? String {
                                  selectedRankingId = newItemId
                              }
                          }
                          .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshHistoryList"))) { notification in
                              // 🎯 新增：监听历史记录刷新通知，更新选中的历史记录项目ID
                              if let userInfo = notification.userInfo,
                                 let newItemId = userInfo["selectedHistoryId"] as? UUID {
                                  selectedHistoryId = newItemId
                              }
                          }
                      }
        .overlay(friendRequestModalOverlay)
        .navigationBarBackButtonHidden(false)
        .onAppear {
            // 搜索视图出现时自动刷新头像缓存
            refreshSearchViewAvatars()
            // 开始持续位置更新
            locationManager.startUpdatingLocation()
            // 加载新朋友申请数量
            loadNewFriendsCount()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DismissProfileSheet"))) { _ in
            showRandomHistory = false
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DismissMessageSheet"))) { _ in
            // 🎯 新增：与历史记录逻辑一致：关闭消息界面，直接返回到主界面
            showMessageSheet = false
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CloseAllSheetsAndNavigateToMain"))) { _ in
            // 🎯 新增：关闭所有 sheet 并导航到主页面
            showMessageSheet = false
            showProfileSheet = false
            showRechargeSheet = false
            showRankingSheet = false
            showAvatarZoom = false
            showFriendRequestModal = false
            // 导航到主页面（selectedTab = 0）
            selectedTab = 0
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowRankingSheet"))) { _ in
            // 🎯 新增：收到打开排行榜的通知（从免费寻找提示弹窗触发）
            showRankingSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FriendRequestLimitExceeded"))) { notification in
            // 🎯 新增：监听好友申请限制通知
            if let message = notification.userInfo?["message"] as? String {
                // 检查是否需要显示弹窗（而不是 Toast）
                if let showAlert = notification.userInfo?["showAlert"] as? Bool, showAlert {
                    stateManager.showFriendRequestLimitAlert(message: message)
                } else {
                    stateManager.showAntiSpamToast(message: message)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PatActionLimitExceeded"))) { notification in
            // 🎯 新增：监听拍一拍限制通知
            if let message = notification.userInfo?["message"] as? String {
                // 检查是否需要显示弹窗（而不是 Toast）
                if let showAlert = notification.userInfo?["showAlert"] as? Bool, showAlert {
                    stateManager.showPatActionLimitAlert(message: message)
                } else {
                    stateManager.showAntiSpamToast(message: message)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MessageButtonLimitExceeded"))) { notification in
            // 🎯 新增：监听消息按钮限制通知
            if let message = notification.userInfo?["message"] as? String {
                // 检查是否需要显示弹窗（而不是 Toast）
                if let showAlert = notification.userInfo?["showAlert"] as? Bool, showAlert {
                    stateManager.showMessageButtonLimitAlert(message: message)
                } else {
                    stateManager.showAntiSpamToast(message: message)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HandleMessageTapFromAlert"))) { notification in
            // 🎯 新增：监听从弹窗触发的消息点击通知
            if let message = notification.object as? MessageItem {
                handleMessageTap(message: message)
            }
        }
        .onDisappear {
            // 停止持续位置更新
            locationManager.stopUpdatingLocation()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // 应用重新激活时检查是否需要更新 Apple ID 信息
            userManager.checkAndUpdateAppleIDInfo()
            
            // 🎯 新增：应用重新激活时，如果用户已登录且不在登录界面，显示通知栏
            if userManager.isLoggedIn {
                // 延迟查询，避免与应用启动时的查询冲突
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    // 再次检查用户是否仍然登录
                    guard userManager.isLoggedIn else {
                        return
                    }
                    
                    // 查询通知内容
                    LeanCloudService.shared.fetchNotificationItems { items, error in
                        DispatchQueue.main.async {
                            // 再次检查用户是否仍然登录
                            if userManager.isLoggedIn, !items.isEmpty {
                                // 依次显示所有通知（全局通知在前，用户特定通知在后）
                                let notificationItems = items.map { (message: $0.message, isBlacklist: $0.isBlacklist) }
                                stateManager.showAppLaunchToasts(items: notificationItems)
                            }
                        }
                    }
                }
            }
        }
                        .interactiveDismissDisabled(false)
    }
}

