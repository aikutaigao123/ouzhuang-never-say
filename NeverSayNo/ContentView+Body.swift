//
//  ContentView+Body.swift
//  NeverSayNo
//
//  Created by Die chen on 2025/7/1.
//

import SwiftUI
import Foundation
import Combine

extension ContentView {
    // MARK: - Body View
    
    var body: some View {
        NavigationStack(path: $path) {
            Group {
                // showInternalInfoConfirmation 已删除（内部用户登录已移除）
                if showAppleInfoConfirmation {
                    // Apple用户信息确认界面
                    UserInfoConfirmView(
                        userManager: userManager,
                        onConfirm: {
                            showAppleInfoConfirmation = false
                            loadMessagesOnLogin()
                            // 🎯 新增：登录后预加载排行榜和推荐榜数据到缓存
                            RankingDataManager.shared.preloadAllData(locationManager: locationManager, userManager: userManager)
                        },
                        onBack: {
                            userManager.logout()
                            showAppleInfoConfirmation = false
                        }
                    )
                    .onAppear {
                        let appleUserName = userManager.currentUser?.fullName ?? "未知用户"
                        
                        
                        // 检查数据一致性
                        if appleUserName != UserDefaultsManager.getCurrentUserName() {
                        }
                        if appleUserName != userManager.diamondManager?.currentUserName {
                        }
                    }
                    .onChange(of: userManager.currentUser?.fullName) { oldValue, newValue in
                        // 打印变化时的其他相关数据
                    }
                } else if showGuestInfoConfirmation {
                    // 游客信息确认界面
                    GuestInfoConfirmationView(
                        displayName: .constant(userManager.currentUser?.fullName ?? ""),
                        email: .constant(userManager.currentUser?.email ?? ""),
                        onConfirm: {
                            showGuestInfoConfirmation = false
                            loadMessagesOnLogin()
                            // 🎯 新增：登录后预加载排行榜和推荐榜数据到缓存
                            RankingDataManager.shared.preloadAllData(locationManager: locationManager, userManager: userManager)
                        },
                        onCancel: {
                            userManager.logout()
                            showGuestInfoConfirmation = false
                        },
                        userManager: userManager
                    )
                    .onAppear {
                    }
                } else if !userManager.isLoggedIn {
                    LoginView(userManager: userManager, locationManager: locationManager, onLoginSuccess: {
                        // 使用导航扩展处理登录后导航
                        handleLoginNavigation()
                    })
                } else {
                    // 主界面 - 显示首页
                    HomeTabView(
                        locationManager: locationManager,
                        userManager: userManager,
                        stateManager: stateManager,
                        unreadMessageCount: $unreadMessageCount,
                        newFriendsCountManager: newFriendsCountManager
                    )
                }
            }
            .navigationDestination(for: String.self) { value in
                navigationDestinationView(for: value)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ResetNavigationState"))) { _ in
            // 重置导航路径
            path.removeAll()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ClearAllNotifications"))) { _ in
            // 🎯 新增：响应清除所有通知的通知，同时清除新朋友申请数量
            newFriendsCountManager.updateCount(0)
        }
        .onChange(of: path) { oldPath, newPath in
            handlePathChange(oldPath: oldPath, newPath: newPath)
        }
        .onChange(of: userManager.isLoggedIn) { oldValue, newValue in
            
            // 当用户登出时，重置标志
            if !newValue {
                hasLoadedMessagesOnLogin = false
                showGuestInfoConfirmation = false
                showAppleInfoConfirmation = false
                // showInternalInfoConfirmation 已删除 = false
                // 用户退出登录时，关闭通知栏
                stateManager.dismissAppLaunchToast()
            } else {
                // 🎯 修改：通知栏查询将在信息确认完成后（loadMessagesOnLogin）执行，不在这里执行
                // 🎯 新增：登录成功后立即检查黑名单和待删除账号
                checkUserBlacklistAndPendingDeletionOnLogin { isBlacklisted, isPendingDeletion in
                    DispatchQueue.main.async {
                        if isBlacklisted {
                            // 账号在黑名单中，显示弹窗提示
                            showBlacklistAlert = true
                            return
                        }
                        
                        if isPendingDeletion {
                            // 账号在待删除账号列表中，显示弹窗询问是否要取消删除
                            if let currentUser = userManager.currentUser {
                                pendingDeletionUserId = currentUser.id
                                pendingDeletionUserName = currentUser.fullName
                                pendingDeletionDeviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
                                showPendingDeletionAlert = true
                            }
                            return
                        }
                        
                        // 账号正常，继续登录流程
                        // 用户登录成功，检查是否需要显示信息确认界面
                        // 检查标志，避免从个人信息页面退出登录时显示
                        let isFromProfileTabLogout = UserDefaults.standard.bool(forKey: "isFromProfileTabLogout")
                        let isFromProfileViewLogout = UserDefaults.standard.bool(forKey: "isFromProfileViewLogout")
                        
                        
                        if !isFromProfileTabLogout && !isFromProfileViewLogout {
                            
                            // 立即显示信息确认界面，避免先显示主界面
                            if userManager.currentUser?.loginType == .guest {
                                showGuestInfoConfirmation = true
                            } else if userManager.currentUser?.loginType == .apple {
                                showAppleInfoConfirmation = true
                            // .internal case 已删除
                                
                                // showInternalInfoConfirmation 已删除 = true
                            } else {
                            }
                        } else {
                        }
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            // 应用即将失去焦点时，保持登录状态，不自动注销
            // 用户登录状态现在会持久化保存
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ReloadRandomMatchHistory"))) { _ in
            // 🔧 响应ProfileTabView的重新加载请求
            loadRandomMatchHistory()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RequestRandomMatchHistory"))) { _ in
            // 🔧 新增：响应请求历史记录数据通知，同步数据给ProfileTabView
            
            // 发送数据同步通知给ProfileTabView
            NotificationCenter.default.post(
                name: NSNotification.Name("SyncRandomMatchHistory"), 
                object: randomMatchHistory
            )
            
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ProfileTabHistoryItemDeleted"))) { notification in
            // 🔧 新增：响应ProfileTabView的删除通知，同步删除操作
            if let deletedItem = notification.object as? RandomMatchHistory {
                // 从ContentView的randomMatchHistory中移除记录
                randomMatchHistory.removeAll { $0.id == deletedItem.id }
                
                // 保存到UserDefaults
                if let data = try? JSONEncoder().encode(randomMatchHistory) {
                    let historyKey = StorageKeyUtils.getHistoryKey(for: userManager.currentUser)
                    UserDefaults.standard.set(data, forKey: historyKey)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HistoryCleared"))) { _ in
            // 🔧 响应历史记录清除通知，确保数据同步
            randomMatchHistory.removeAll()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HistoryItemDeleted"))) { notification in
            // 🔧 优化：响应单个历史记录删除通知，确保数据同步
            if let deletedItem = notification.object as? RandomMatchHistory {
                // 🔧 优化：使用更高效的删除方式
                randomMatchHistory.removeAll { $0.id == deletedItem.id }
                
                // 🔧 优化：异步保存，避免阻塞UI
                DispatchQueue.global(qos: .userInitiated).async {
                    
                    self.saveRandomMatchHistory()
                    
                }
                
            } else {
            }
        }
        // 🔧 优化：简化通知处理，避免复杂的表达式
        .onAppear {
            // 🔧 新增：应用启动时清除登录导航标志
            let hadIsFromProfileTabLogout = UserDefaults.standard.bool(forKey: "isFromProfileTabLogout")
            let hadIsFromProfileViewLogout = UserDefaults.standard.bool(forKey: "isFromProfileViewLogout")
            if hadIsFromProfileTabLogout || hadIsFromProfileViewLogout {
                UserDefaults.standard.set(false, forKey: "isFromProfileTabLogout")
                UserDefaults.standard.set(false, forKey: "isFromProfileViewLogout")
            } else {
            }
            
            // 🎯 修改：移除应用启动时的通知栏查询，改为在登录成功后查询
            
            OnAppearHelpers.handleAppStartup(
                userManager: userManager,
                setupIMListener: setupIMListener,
                startMessageRefreshTimer: startMessageRefreshTimer,
                loadHistoryAndCheckLatestMatch: loadHistoryAndCheckLatestMatch,
                path: $path
            )
            
            // 🔧 新增：先加载黑名单，再加载历史记录数据到ContentView
            loadBlacklist()
            
            // 🎯 新增：注册全局好友申请通知监听器（避免重复注册）
            if notificationObservers.isEmpty {
                let observer1 = NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("NewFriendshipRequest"),
                    object: nil,
                    queue: .main
                ) { notification in
                
                // 🎯 新增：显示好友申请弹窗
                if let userInfo = notification.userInfo,
                   let senderName = userInfo["senderName"] as? String {
                    let senderId = userInfo["senderId"] as? String ?? ""
                    stateManager.friendRequestSenderName = senderName
                    stateManager.friendRequestSenderId = senderId
                    stateManager.showFriendRequestAlert = true
                } else {
                    // 如果没有在通知中传递，则从最新申请中获取
                    FriendshipManager.shared.fetchFriendshipRequestsWithRetry(maxAttempts: 2) { requests, _ in
                        DispatchQueue.main.async {
                            if let requests = requests,
                               let latestRequest = requests.filter({ $0.status == "pending" }).first {
                                let senderId = latestRequest.user.id
                                // 尝试从 UserNameRecord 查询用户名
                                LeanCloudService.shared.fetchUserNameByUserId(objectId: senderId) { name, _ in
                                    DispatchQueue.main.async {
                                        let senderName = name ?? (latestRequest.user.fullName.isEmpty ? "未知用户" : latestRequest.user.fullName)
                                        stateManager.friendRequestSenderName = senderName
                                        stateManager.friendRequestSenderId = senderId
                                        stateManager.showFriendRequestAlert = true
                                    }
                                }
                            } else {
                            }
                        }
                    }
                }
                }
                notificationObservers.append(observer1)
                
                // 🎯 新增：注册询问联系方式是否真实通知监听器
                let observerContactInquiry = NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("NewContactInquiry"),
                    object: nil,
                    queue: .main
                ) { notification in
                    // 🎯 新增：显示询问联系方式是否真实弹窗
                    if let userInfo = notification.userInfo,
                       let senderName = userInfo["senderName"] as? String {
                        let senderId = userInfo["senderId"] as? String ?? ""
                        stateManager.contactInquirySenderName = senderName
                        stateManager.contactInquirySenderId = senderId
                        stateManager.showContactInquiryAlert = true
                    }
                }
                notificationObservers.append(observerContactInquiry)
                
                // 🎯 新增：注册从通知栏点击进入的询问联系方式是否真实通知监听器
                let observerContactInquiryFromNotification = NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("ShowContactInquiryAlertFromNotification"),
                    object: nil,
                    queue: .main
                ) { notification in
                    // 🎯 新增：先关闭所有窗口并导航到主页面
                    stateManager.showMessageSheet = false
                    stateManager.showProfileSheet = false
                    stateManager.showRechargeSheet = false
                    stateManager.showAvatarZoom = false
                    
                    if let userInfo = notification.userInfo,
                       let senderName = userInfo["senderName"] as? String {
                        let senderId = userInfo["senderId"] as? String ?? ""
                        stateManager.contactInquirySenderName = senderName
                        stateManager.contactInquirySenderId = senderId
                        stateManager.showContactInquiryAlert = true
                    }
                }
                notificationObservers.append(observerContactInquiryFromNotification)
                
                // 🎯 新增：注册联系方式真实回复通知监听器
                let observerContactInquiryReply = NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("NewContactInquiryReply"),
                    object: nil,
                    queue: .main
                ) { notification in
                    // 🎯 新增：显示联系方式真实回复弹窗
                    if let userInfo = notification.userInfo,
                       let senderName = userInfo["senderName"] as? String {
                        let senderId = userInfo["senderId"] as? String ?? ""
                        stateManager.contactInquiryReplySenderName = senderName
                        stateManager.contactInquiryReplySenderId = senderId
                        stateManager.showContactInquiryReplyAlert = true
                    }
                }
                notificationObservers.append(observerContactInquiryReply)
                
                // 🎯 新增：注册从通知栏点击进入的联系方式真实回复通知监听器
                let observerContactInquiryReplyFromNotification = NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("ShowContactInquiryReplyAlertFromNotification"),
                    object: nil,
                    queue: .main
                ) { notification in
                    // 🎯 新增：先关闭所有窗口并导航到主页面
                    stateManager.showMessageSheet = false
                    stateManager.showProfileSheet = false
                    stateManager.showRechargeSheet = false
                    stateManager.showAvatarZoom = false
                    
                    if let userInfo = notification.userInfo,
                       let senderName = userInfo["senderName"] as? String {
                        let senderId = userInfo["senderId"] as? String ?? ""
                        stateManager.contactInquiryReplySenderName = senderName
                        stateManager.contactInquiryReplySenderId = senderId
                        stateManager.showContactInquiryReplyAlert = true
                    }
                }
                notificationObservers.append(observerContactInquiryReplyFromNotification)
                
                // 🎯 新增：注册从通知栏点击进入的通知监听器
                let observer2 = NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("ShowFriendRequestAlertFromNotification"),
                    object: nil,
                    queue: .main
                ) { notification in
                
                // 🎯 新增：先关闭所有窗口并导航到主页面
                stateManager.showMessageSheet = false
                stateManager.showProfileSheet = false
                stateManager.showRechargeSheet = false
                stateManager.showAvatarZoom = false
                stateManager.showAvatarBackpack = false
                stateManager.showTermsOfService = false
                stateManager.showPrivacyPolicy = false
                stateManager.showLocationHistory = false
                stateManager.showRandomHistory = false
                stateManager.showReportSheet = false
                
                // 关闭 LegacySearchView 中的 sheet（通过通知）
                NotificationCenter.default.post(name: NSNotification.Name("DismissMessageSheet"), object: nil)
                NotificationCenter.default.post(name: NSNotification.Name("DismissProfileSheet"), object: nil)
                
                // 导航到主页面（selectedTab = 0）
                selectedTab = 0
                NotificationCenter.default.post(name: NSNotification.Name("NavigateToMainTab"), object: nil)
                
                // 延迟显示弹窗，确保窗口已关闭
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    // 🎯 新增：显示好友申请弹窗
                    if let userInfo = notification.userInfo,
                       let senderName = userInfo["senderName"] as? String {
                        let senderId = userInfo["senderId"] as? String ?? ""
                        stateManager.friendRequestSenderName = senderName
                        stateManager.friendRequestSenderId = senderId
                        
                        // 如果 senderId 为空，尝试从最新申请中获取
                        if senderId.isEmpty {
                            FriendshipManager.shared.fetchFriendshipRequestsWithRetry(maxAttempts: 2) { requests, _ in
                                DispatchQueue.main.async {
                                    if let requests = requests,
                                       let latestRequest = requests.filter({ $0.status == "pending" }).first {
                                        let actualSenderId = latestRequest.user.id
                                        // 尝试从 UserNameRecord 查询用户名
                                        LeanCloudService.shared.fetchUserNameByUserId(objectId: actualSenderId) { name, _ in
                                            DispatchQueue.main.async {
                                                let actualSenderName = name ?? (latestRequest.user.fullName.isEmpty ? senderName : latestRequest.user.fullName)
                                                stateManager.friendRequestSenderName = actualSenderName
                                                stateManager.friendRequestSenderId = actualSenderId
                                                stateManager.showFriendRequestAlert = true
                                            }
                                        }
                                    } else {
                                        // 即使找不到，也显示弹窗
                                        stateManager.showFriendRequestAlert = true
                                    }
                                }
                            }
                        } else {
                            stateManager.showFriendRequestAlert = true
                        }
                    } else {
                        // 如果没有在通知中传递，则从最新申请中获取
                        FriendshipManager.shared.fetchFriendshipRequestsWithRetry(maxAttempts: 2) { requests, _ in
                            DispatchQueue.main.async {
                                if let requests = requests,
                                   let latestRequest = requests.filter({ $0.status == "pending" }).first {
                                    let senderId = latestRequest.user.id
                                    // 尝试从 UserNameRecord 查询用户名
                                    LeanCloudService.shared.fetchUserNameByUserId(objectId: senderId) { name, _ in
                                        DispatchQueue.main.async {
                                            let senderName = name ?? (latestRequest.user.fullName.isEmpty ? "未知用户" : latestRequest.user.fullName)
                                            stateManager.friendRequestSenderName = senderName
                                            stateManager.friendRequestSenderId = senderId
                                            stateManager.showFriendRequestAlert = true
                                        }
                                    }
                                } else {
                                }
                            }
                        }
                    }
                }
                }
                notificationObservers.append(observer2)
                
                // 🎯 新增：监听关闭所有窗口并导航到主页面的通知
                let observer3 = NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("CloseAllSheetsAndNavigateToMain"),
                    object: nil,
                    queue: .main
                ) { _ in
                
                // 关闭所有 sheet
                stateManager.showMessageSheet = false
                stateManager.showProfileSheet = false
                stateManager.showRechargeSheet = false
                stateManager.showAvatarZoom = false
                stateManager.showAvatarBackpack = false
                stateManager.showTermsOfService = false
                stateManager.showPrivacyPolicy = false
                stateManager.showLocationHistory = false
                stateManager.showRandomHistory = false
                stateManager.showReportSheet = false
                
                // 关闭 LegacySearchView 中的 sheet（通过通知）
                NotificationCenter.default.post(name: NSNotification.Name("DismissMessageSheet"), object: nil)
                NotificationCenter.default.post(name: NSNotification.Name("DismissProfileSheet"), object: nil)
                
                // 导航到主页面（selectedTab = 0）
                selectedTab = 0
                NotificationCenter.default.post(name: NSNotification.Name("NavigateToMainTab"), object: nil)
                
                }
                notificationObservers.append(observer3)
            }
        }
        .alert("账号状态通知", isPresented: $showPendingDeletionAlert) {
            Button("重新注册", role: .destructive) {
                // 用户选择重新注册，删除 AccountDeletionRequest 记录
                LeanCloudService.shared.deleteAccountDeletionRequest(
                    userId: pendingDeletionUserId,
                    userName: pendingDeletionUserName,
                    deviceId: pendingDeletionDeviceId
                ) { success in
                    DispatchQueue.main.async {
                        if success {
                            // 重新检查，继续登录流程
                            checkUserBlacklistAndPendingDeletionOnLogin { isBlacklisted, isPendingDeletion in
                                DispatchQueue.main.async {
                                    if isBlacklisted {
                                        userManager.logout()
                                        return
                                    }
                                    
                                    if isPendingDeletion {
                                        // 如果仍然在待删除列表中，可能是查询条件不匹配，再次显示弹窗
                                        showPendingDeletionAlert = true
                                        return
                                    }
                                    
                                    // 账号正常，继续登录流程
                                    // 用户登录成功，检查是否需要显示信息确认界面
                                    // 检查标志，避免从个人信息页面退出登录时显示
                                    let isFromProfileTabLogout = UserDefaults.standard.bool(forKey: "isFromProfileTabLogout")
                                    let isFromProfileViewLogout = UserDefaults.standard.bool(forKey: "isFromProfileViewLogout")
                                    
                                    
                                    if !isFromProfileTabLogout && !isFromProfileViewLogout {
                                        
                                        // 立即显示信息确认界面，避免先显示主界面
                                        if userManager.currentUser?.loginType == .guest {
                                            showGuestInfoConfirmation = true
                                        } else if userManager.currentUser?.loginType == .apple {
                                            showAppleInfoConfirmation = true
                                        } else {
                                        }
                                    } else {
                                    }
                                }
                            }
                        } else {
                            // 即使删除失败，也继续登录流程（避免用户无法登录）
                            // 用户登录成功，检查是否需要显示信息确认界面
                            // 检查标志，避免从个人信息页面退出登录时显示
                            let isFromProfileTabLogout = UserDefaults.standard.bool(forKey: "isFromProfileTabLogout")
                            let isFromProfileViewLogout = UserDefaults.standard.bool(forKey: "isFromProfileViewLogout")
                            
                            
                            if !isFromProfileTabLogout && !isFromProfileViewLogout {
                                
                                // 立即显示信息确认界面，避免先显示主界面
                                if userManager.currentUser?.loginType == .guest {
                                    showGuestInfoConfirmation = true
                                } else if userManager.currentUser?.loginType == .apple {
                                    showAppleInfoConfirmation = true
                                } else {
                                }
                            } else {
                            }
                        }
                    }
                }
            }
            Button("退出", role: .cancel) {
                // 用户选择退出，退出登录
                userManager.logout()
            }
        } message: {
            Text("您的账号已被删除。如您希望继续使用此app，请点击\"重新注册\"按钮。")
        }
        .alert("账号已被限制", isPresented: $showBlacklistAlert) {
            Button("确定", role: .cancel) {
                // 用户确认后，退出登录
                userManager.logout()
            }
        } message: {
            Text("您的账号因违反社区管理规定已被限制使用，请联系管理人员。\n\n管理人员邮箱：928322941@qq.com")
        }
        .alert("请设置真实联系方式", isPresented: $showDefaultEmailAlert) {
            Button("去设置") {
                // 跳转到个人资料页面设置邮箱
                NotificationCenter.default.post(name: NSNotification.Name("ShowProfileSheet"), object: nil)
            }
            Button("稍后", role: .cancel) {
                // 🎯 修改：根据来源决定后续操作
                if stateManager.isDefaultEmailAlertFromMessageButton {
                    // 来自消息按钮：继续显示消息界面
                    stateManager.isDefaultEmailAlertFromMessageButton = false
                    // 发送通知继续显示消息界面
                    NotificationCenter.default.post(name: NSNotification.Name("ContinueMessageAfterEmailAlert"), object: nil)
                } else {
                    // 来自搜索按钮：继续执行搜索
                    NotificationCenter.default.post(name: NSNotification.Name("ContinueSearchAfterEmailAlert"), object: nil)
                }
            }
        } message: {
            Text("请将邮箱设置为真实联系方式")
        }
        .overlay(alignment: .center) {
            // 🎯 新增：好友申请自定义弹窗
            FriendRequestAlert(
                isVisible: stateManager.showFriendRequestAlert,
                senderId: stateManager.friendRequestSenderId,
                senderName: stateManager.friendRequestSenderName,
                onAccept: {
                    handleAcceptFriendRequest()
                },
                onReject: {
                    handleRejectFriendRequest()
                },
                onDismiss: {
                    stateManager.showFriendRequestAlert = false
                },
                onAvatarTap: {
                    handleFriendRequestAvatarTap()
                }
            )
            
            // 🎯 新增：询问联系方式是否真实自定义弹窗
            ContactInquiryAlert(
                isVisible: stateManager.showContactInquiryAlert,
                senderId: stateManager.contactInquirySenderId,
                senderName: stateManager.contactInquirySenderName,
                onGoToSettings: {
                    handleContactInquiryGoToSettings()
                },
                onConfirmReal: {
                    handleContactInquiryConfirmReal()
                },
                onDismiss: {
                    stateManager.showContactInquiryAlert = false
                },
                onAvatarTap: {
                    handleContactInquiryAvatarTap()
                }
            )
            
            // 🎯 新增：联系方式真实回复自定义弹窗
            ContactInquiryReplyAlert(
                isVisible: stateManager.showContactInquiryReplyAlert,
                senderId: stateManager.contactInquiryReplySenderId,
                senderName: stateManager.contactInquiryReplySenderName,
                onDismiss: {
                    stateManager.showContactInquiryReplyAlert = false
                },
                onCopyContact: {
                    handleContactInquiryReplyCopyContact()
                },
                onAvatarTap: {
                    handleContactInquiryReplyAvatarTap()
                }
            )
        }
        // 🎯 新增：在 onDisappear 时移除所有观察者
        .onDisappear {
            for observer in notificationObservers {
                NotificationCenter.default.removeObserver(observer)
            }
            notificationObservers.removeAll()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowDefaultEmailAlert"))) { _ in
            // 收到显示默认邮箱提示的通知
            // 🎯 新增：如果不是从消息按钮触发的，确保标志为 false（搜索按钮场景）
            if !stateManager.isDefaultEmailAlertFromMessageButton {
                stateManager.isDefaultEmailAlertFromMessageButton = false
            }
            showDefaultEmailAlert = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ContinueSearchAfterEmailAlert"))) { _ in
            // 收到继续搜索的通知，跳过默认邮箱检查
            // 🎯 修复：按userId隔离
            if let userId = UserDefaultsManager.getCurrentUserId() {
                UserDefaults.standard.set(true, forKey: "shouldSkipDefaultEmailCheck_\(userId)")
                // 通过通知触发搜索（LegacySearchView会监听这个通知）
                NotificationCenter.default.post(name: NSNotification.Name("TriggerSearchWithSkipCheck"), object: nil)
                // 重置标志
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    UserDefaults.standard.set(false, forKey: "shouldSkipDefaultEmailCheck_\(userId)")
                }
            } else {
                UserDefaults.standard.set(true, forKey: "shouldSkipDefaultEmailCheck")
                NotificationCenter.default.post(name: NSNotification.Name("TriggerSearchWithSkipCheck"), object: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    UserDefaults.standard.set(false, forKey: "shouldSkipDefaultEmailCheck")
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ContinueMessageAfterEmailAlert"))) { _ in
            // 🎯 新增：监听从邮箱提示弹窗点击"稍后"后继续显示消息界面的通知（TabBar场景）
            guard let currentUser = userManager.currentUser else {
                return
            }
            let userId = currentUser.id
            // 直接继续显示消息界面，跳过邮箱检查
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
    }
    
    // MARK: - 好友申请处理
    
    /// 处理同意好友申请
    private func handleAcceptFriendRequest() {
        guard !stateManager.friendRequestSenderId.isEmpty else {
            stateManager.showFriendRequestAlert = false
            return
        }
        
        stateManager.showFriendRequestAlert = false
        
        // 查找对应的好友申请
        FriendshipManager.shared.fetchFriendshipRequests { requests, error in
            DispatchQueue.main.async {
                if error != nil {
                    return
                }
                
                guard let requests = requests,
                      let currentUser = userManager.currentUser else {
                    return
                }
                
                // 查找对应的申请
                let targetRequest = requests.first { request in
                    request.user.id == stateManager.friendRequestSenderId &&
                    request.friend.id == currentUser.id &&
                    request.status == "pending"
                }
                
                guard let request = targetRequest else {
                    return
                }
                
                // 接受好友申请
                FriendshipManager.shared.acceptFriendshipRequest(request, attributes: nil) { success, errorMessage in
                    DispatchQueue.main.async {
                        if success {
                            // 刷新好友申请列表
                            NotificationCenter.default.post(name: NSNotification.Name("RefreshNewFriends"), object: nil)
                            NotificationCenter.default.post(name: NSNotification.Name("FriendshipRequestUpdated"), object: nil)
                        } else {
                        }
                    }
                }
            }
        }
    }
    
    /// 处理弹窗中头像点击
    private func handleFriendRequestAvatarTap() {
        guard !stateManager.friendRequestSenderId.isEmpty else {
            return
        }
        
        
        // 获取发送者信息
        let senderId = stateManager.friendRequestSenderId
        let senderName = stateManager.friendRequestSenderName
        
        // 关闭弹窗
        stateManager.showFriendRequestAlert = false
        
        // 查询发送者的头像和登录类型，然后创建 MessageItem 并通过通知触发处理
        LeanCloudService.shared.fetchUserAvatarByUserId(objectId: senderId) { avatar, _ in
            LeanCloudService.shared.fetchUserNameAndLoginType(objectId: senderId) { name, loginType, _ in
                DispatchQueue.main.async {
                    let finalAvatar = avatar ?? "😀"
                    let finalName = name ?? senderName
                    let finalLoginType = loginType ?? "unknown"
                    
                    // 创建 MessageItem（类似于好友列表中的点击）
                    let matchMessage = MessageItem(
                        id: UUID(),
                        objectId: nil,
                        senderId: senderId,
                        senderName: finalName,
                        senderAvatar: finalAvatar,
                        senderLoginType: finalLoginType,
                        receiverId: userManager.currentUser?.id ?? "",
                        receiverName: userManager.currentUser?.fullName ?? "我",
                        receiverAvatar: "😊",
                        receiverLoginType: userManager.currentUser?.loginType.toString(),
                        content: "好友申请",
                        timestamp: Date(),
                        isRead: false,
                        type: .text,
                        deviceId: UIDevice.current.identifierForVendor?.uuidString,
                        messageType: "friend_request",
                        isMatch: false
                    )
                    
                    // 通过通知触发 LegacySearchView 的 handleMessageTap
                    NotificationCenter.default.post(
                        name: NSNotification.Name("HandleMessageTapFromAlert"),
                        object: matchMessage
                    )
                }
            }
        }
    }
    
    /// 处理拒绝好友申请
    private func handleRejectFriendRequest() {
        guard !stateManager.friendRequestSenderId.isEmpty else {
            stateManager.showFriendRequestAlert = false
            return
        }
        
        stateManager.showFriendRequestAlert = false
        
        // 查找对应的好友申请
        FriendshipManager.shared.fetchFriendshipRequests { requests, error in
            DispatchQueue.main.async {
                if error != nil {
                    return
                }
                
                guard let requests = requests,
                      let currentUser = userManager.currentUser else {
                    return
                }
                
                // 查找对应的申请
                let targetRequest = requests.first { request in
                    request.user.id == stateManager.friendRequestSenderId &&
                    request.friend.id == currentUser.id &&
                    request.status == "pending"
                }
                
                guard let request = targetRequest else {
                    return
                }
                
                // 拒绝好友申请
                FriendshipManager.shared.declineFriendshipRequest(request) { success, errorMessage in
                    DispatchQueue.main.async {
                        if success {
                            // 刷新好友申请列表
                            NotificationCenter.default.post(name: NSNotification.Name("RefreshNewFriends"), object: nil)
                            NotificationCenter.default.post(name: NSNotification.Name("FriendshipRequestUpdated"), object: nil)
                        } else {
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 询问联系方式是否真实处理
    
    /// 处理"去设置"按钮点击
    private func handleContactInquiryGoToSettings() {
        stateManager.showContactInquiryAlert = false
        // 跳转到个人资料页面设置邮箱
        NotificationCenter.default.post(name: NSNotification.Name("ShowProfileSheet"), object: nil)
    }
    
    /// 处理"真实"按钮点击
    private func handleContactInquiryConfirmReal() {
        guard !stateManager.contactInquirySenderId.isEmpty else {
            stateManager.showContactInquiryAlert = false
            return
        }
        
        // 获取当前用户信息
        guard let currentUserId = UserDefaultsManager.getCurrentUserId(),
              let currentUser = userManager.currentUser else {
            stateManager.showContactInquiryAlert = false
            return
        }
        
        // 获取发送者信息（询问者）
        let senderId = stateManager.contactInquirySenderId
        let senderName = stateManager.contactInquirySenderName
        
        // 获取当前用户信息
        let currentUserName = UserDefaultsManager.getCurrentUserName()
        let displayName = currentUserName.isEmpty ? currentUser.fullName : currentUserName
        
        // 关闭弹窗
        stateManager.showContactInquiryAlert = false
        
        // 🎯 新增：先更新数据库记录（类似好友申请）
        // 查找对应的 ContactInquiry 记录并更新 status 为 replied
        ContactInquiryManager.shared.markAsRepliedByUsers(inquirerId: senderId, targetUserId: currentUserId) { dbSuccess, inquiryId in
            if dbSuccess {
                // 数据库记录更新成功后，发送 IM 消息作为通知（支持离线推送）
                PatConversationManager.shared.sendContactInquiryReply(
                    fromUserId: currentUserId,
                    toUserId: senderId,
                    fromUserName: displayName,
                    toUserName: senderName
                ) { imSuccess, imErrorMessage in
                    if imSuccess {
                        // 发送成功，可以显示提示（可选）
                    } else {
                        // 发送失败，可以显示错误提示（可选）
                    }
                }
            } else {
                // 数据库更新失败，仍然尝试发送 IM 消息（备用机制）
                PatConversationManager.shared.sendContactInquiryReply(
                    fromUserId: currentUserId,
                    toUserId: senderId,
                    fromUserName: displayName,
                    toUserName: senderName
                ) { imSuccess, imErrorMessage in
                    if imSuccess {
                        // 发送成功，可以显示提示（可选）
                    } else {
                        // 发送失败，可以显示错误提示（可选）
                    }
                }
            }
        }
        
        // 🎯 新增：同时发送好友申请
        // 检查是否向自己发送请求
        guard senderId != currentUserId else {
            return
        }
        
        // 🎯 检查24小时内好友申请数量限制
        let (canSend, _) = UserDefaultsManager.canSendFriendRequest()
        guard canSend else {
            // 超过限制，不发送好友申请，但不影响原有的真实回复功能
            return
        }
        
        // 🎯 检查是否在1分钟内向同一用户发送过好友请求
        guard !UserDefaultsManager.hasSentFriendRequestToUserInLastMinute(targetUserId: senderId) else {
            // 1分钟内已发送过，不重复发送，但不影响原有的真实回复功能
            return
        }
        
        // 🎯 立即记录发送时间（在点击时记录，不依赖API结果）
        UserDefaultsManager.recordFriendRequestSent(to: senderId)
        UserDefaultsManager.recordFriendRequestSentToUser(targetUserId: senderId)
        
        // 获取当前用户信息用于发送好友申请
        let currentUserAvatar = UserDefaultsManager.getCustomAvatar(userId: currentUserId) ?? "person.circle"
        
        // 获取对方（询问者）的完整信息
        LeanCloudService.shared.fetchUserAvatarByUserId(objectId: senderId) { receiverAvatar, _ in
            LeanCloudService.shared.fetchUserNameAndLoginType(objectId: senderId) { receiverName, receiverLoginType, _ in
                DispatchQueue.main.async {
                    // 使用获取到的信息，如果获取失败则使用默认值
                    let finalReceiverName = receiverName ?? senderName
                    let finalReceiverAvatar = receiverAvatar ?? "person.circle"
                    let finalReceiverLoginType = receiverLoginType ?? "guest"
                    
                    // 发送好友申请
                    MessageHelpers.sendFavoriteMessage(
                        senderId: currentUserId,
                        senderName: displayName,
                        senderAvatar: currentUserAvatar,
                        receiverId: senderId,
                        receiverName: finalReceiverName,
                        receiverAvatar: finalReceiverAvatar,
                        receiverLoginType: finalReceiverLoginType,
                        currentUser: currentUser
                    )
                }
            }
        }
    }
    
    /// 处理弹窗中头像点击
    private func handleContactInquiryAvatarTap() {
        guard !stateManager.contactInquirySenderId.isEmpty else {
            return
        }
        
        // 获取发送者信息
        let senderId = stateManager.contactInquirySenderId
        let senderName = stateManager.contactInquirySenderName
        
        // 关闭弹窗
        stateManager.showContactInquiryAlert = false
        
        // 查询发送者的头像和登录类型，然后创建 MessageItem 并通过通知触发处理
        LeanCloudService.shared.fetchUserAvatarByUserId(objectId: senderId) { avatar, _ in
            LeanCloudService.shared.fetchUserNameAndLoginType(objectId: senderId) { name, loginType, _ in
                DispatchQueue.main.async {
                    let finalAvatar = avatar ?? "😀"
                    let finalName = name ?? senderName
                    let finalLoginType = loginType ?? "unknown"
                    
                    // 创建 MessageItem（类似于好友列表中的点击）
                    let matchMessage = MessageItem(
                        id: UUID(),
                        objectId: nil,
                        senderId: senderId,
                        senderName: finalName,
                        senderAvatar: finalAvatar,
                        senderLoginType: finalLoginType,
                        receiverId: userManager.currentUser?.id ?? "",
                        receiverName: userManager.currentUser?.fullName ?? "",
                        receiverAvatar: UserDefaultsManager.getCustomAvatar(userId: userManager.currentUser?.id ?? "") ?? "😀",
                        receiverLoginType: userManager.currentUser?.loginType.toString() ?? "unknown",
                        content: "",
                        timestamp: Date(),
                        isRead: false,
                        type: .text,
                        deviceId: nil,
                        messageType: nil,
                        isMatch: false
                    )
                    
                    // 发送通知，触发消息处理（类似于点击好友列表）
                    NotificationCenter.default.post(
                        name: NSNotification.Name("HandleMessageTap"),
                        object: nil,
                        userInfo: ["message": matchMessage]
                    )
                }
            }
        }
    }
    
    // MARK: - 联系方式真实回复处理
    
    /// 处理复制联系方式按钮点击
    private func handleContactInquiryReplyCopyContact() {
        guard !stateManager.contactInquiryReplySenderId.isEmpty else {
            return
        }
        
        let senderId = stateManager.contactInquiryReplySenderId
        
        // 查询对方的邮箱（使用 fetchUserEmailByUserId，不依赖 loginType）
        LeanCloudService.shared.fetchUserEmailByUserId(objectId: senderId) { email, _ in
            DispatchQueue.main.async {
                if let userEmail = email, !userEmail.isEmpty {
                    // 检查是否是默认邮箱
                    let isDefaultEmail = userEmail.hasSuffix("@internal.com") || 
                                       userEmail.hasSuffix("@apple.com") || 
                                       userEmail.hasSuffix("@guest.com")
                    
                    if !isDefaultEmail {
                        // 复制邮箱到剪贴板
                        UIPasteboard.general.string = userEmail
                        // 显示复制成功提示
                        stateManager.showCopySuccess = true
                        stateManager.alertMessage = "联系方式已复制"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            stateManager.showCopySuccess = false
                        }
                        // 关闭弹窗
                        stateManager.showContactInquiryReplyAlert = false
                    } else {
                        // 默认邮箱，提示用户
                        stateManager.alertMessage = "该用户未设置真实联系方式"
                        stateManager.showAlert = true
                    }
                } else {
                    // 没有邮箱，提示用户
                    stateManager.alertMessage = "该用户未设置联系方式"
                    stateManager.showAlert = true
                }
            }
        }
    }
    
    /// 处理弹窗中头像点击
    private func handleContactInquiryReplyAvatarTap() {
        guard !stateManager.contactInquiryReplySenderId.isEmpty else {
            return
        }
        
        // 获取发送者信息
        let senderId = stateManager.contactInquiryReplySenderId
        let senderName = stateManager.contactInquiryReplySenderName
        
        // 关闭弹窗
        stateManager.showContactInquiryReplyAlert = false
        
        // 查询发送者的头像和登录类型，然后创建 MessageItem 并通过通知触发处理
        LeanCloudService.shared.fetchUserAvatarByUserId(objectId: senderId) { avatar, _ in
            LeanCloudService.shared.fetchUserNameAndLoginType(objectId: senderId) { name, loginType, _ in
                DispatchQueue.main.async {
                    let finalAvatar = avatar ?? "😀"
                    let finalName = name ?? senderName
                    let finalLoginType = loginType ?? "unknown"
                    
                    // 创建 MessageItem（类似于好友列表中的点击）
                    let matchMessage = MessageItem(
                        id: UUID(),
                        objectId: nil,
                        senderId: senderId,
                        senderName: finalName,
                        senderAvatar: finalAvatar,
                        senderLoginType: finalLoginType,
                        receiverId: userManager.currentUser?.id ?? "",
                        receiverName: userManager.currentUser?.fullName ?? "",
                        receiverAvatar: UserDefaultsManager.getCustomAvatar(userId: userManager.currentUser?.id ?? "") ?? "😀",
                        receiverLoginType: userManager.currentUser?.loginType.toString() ?? "unknown",
                        content: "",
                        timestamp: Date(),
                        isRead: false,
                        type: .text,
                        deviceId: nil,
                        messageType: nil,
                        isMatch: false
                    )
                    
                    // 发送通知，触发消息处理（类似于点击好友列表）
                    NotificationCenter.default.post(
                        name: NSNotification.Name("HandleMessageTap"),
                        object: nil,
                        userInfo: ["message": matchMessage]
                    )
                }
            }
        }
    }
}

