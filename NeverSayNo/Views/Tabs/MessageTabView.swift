import SwiftUI
import CoreLocation

// 消息Tab - 消息界面
struct MessageTabView: View {
    @ObservedObject var userManager: UserManager
    @ObservedObject var stateManager: StateManager
    @ObservedObject var newFriendsCountManager: NewFriendsCountManager
    @Binding var unreadMessageCount: Int
    
    // 添加状态变量来存储真实数据
    @State private var existingMessages: [MessageItem] = []
    @State private var existingFriends: [MatchRecord] = []
    @State private var existingPatMessages: [MessageItem] = []
    @State private var existingAvatarCache: [String: String] = [:]
    @State private var existingUserNameCache: [String: String] = [:]
    @State private var favoriteRecords: [FavoriteRecord] = []
    
    // 添加匹配成功相关的状态管理
    @State private var isNewFriendsVisible = true
    @State private var showFriendsList = true
    
    // 🎯 新增：好友申请弹窗状态
    @State private var showFriendRequestAlert = false {
        didSet {
        }
    }
    @State private var friendRequestSenderName = "" {
        didSet {
        }
    }
    
    var body: some View {
        NavigationStack {
            MessageView(
                unreadCount: $unreadMessageCount,
                newFriendsCountManager: newFriendsCountManager,
                userManager: userManager,
                stateManager: stateManager,
                onMessageTap: { message in
                    // 处理消息点击
                    handleMessageTap(message: message)
                },
                isUserFavorited: { userId in
                    favoriteRecords.contains { $0.favoriteUserId == userId }
                },
                onToggleFavorite: { userId, name, avatar, loginType, location, timezone in
                    // 处理收藏/取消收藏
                    toggleFavorite(userId: userId, name: name, avatar: avatar, loginType: loginType, location: location, timezone: timezone)
                },
                onRemoveFavorite: { userId in
                    // 处理移除收藏
                    removeFavorite(userId: userId)
                },
                isUserLiked: { userId in
                    // 检查是否已点赞
                    return false // 暂时返回false，可以根据需要实现
                },
                onToggleLike: { userId, name, avatar, loginType, location, timezone in
                    // 处理点赞/取消点赞
                },
                isUserFavoritedByMe: { userId in
                    // 检查对方是否也喜欢了当前用户
                    return false // 暂时返回false，可以根据需要实现
                },
                favoriteRecords: $favoriteRecords,
                onMessagesUpdated: {
                    // 消息更新后的回调
                    detectAndUpdateMatchStatus()
                },
                onPat: { userId in
                    // 处理拍一拍
                    handlePat(userId: userId)
                },
                onUnfriend: { matchRecord in
                    // 处理解除好友关系
                    handleUnfriend(matchRecord: matchRecord)
                },
                showBottomTabBar: false, // 从底部标签栏进入，不显示底部按钮
                showFriendsList: showFriendsList, // 消息界面显示我的好友列表
                existingMessages: $existingMessages,
                existingFriends: $existingFriends,
                existingPatMessages: $existingPatMessages,
                existingAvatarCache: $existingAvatarCache,
                existingUserNameCache: $existingUserNameCache
            )
        }
        .alert("收到好友申请", isPresented: $showFriendRequestAlert) {
            Button("稍后查看", role: .cancel) {
                // 用户选择稍后查看，不做任何操作
            }
            Button("查看") {
                // 🎯 点击查看后，展开"新的朋友"列表
                isNewFriendsVisible = true
                // 触发展开消息列表
                NotificationCenter.default.post(name: NSNotification.Name("AutoShowNewFriends"), object: nil)
            }
        } message: {
            let messageText = "\(friendRequestSenderName.isEmpty ? "有人" : friendRequestSenderName) 向你发送了好友申请"
            Text(messageText)
        }
        .onAppear {
            let startTime = Date()
            
            // 加载真实数据
            loadRealData()
            
            // 🎯 新增：监听新好友申请通知，立即刷新列表和数量
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("RefreshNewFriends"),
                object: nil,
                queue: .main
            ) { _ in
                self.refreshNewFriendsList()
            }
            
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("NewFriendshipRequest"),
                object: nil,
                queue: .main
            ) { notification in
                
                self.refreshNewFriendsList()
                
                // 🎯 新增：显示好友申请弹窗
                // 从通知中获取发送者信息，如果没有则从最新申请中获取
                if let userInfo = notification.userInfo,
                   let senderName = userInfo["senderName"] as? String {
                    self.friendRequestSenderName = senderName
                    self.showFriendRequestAlert = true
                } else {
                    // 如果没有在通知中传递，则从最新申请中获取
                    FriendshipManager.shared.fetchFriendshipRequestsWithRetry(maxAttempts: 2) { requests, _ in
                        DispatchQueue.main.async {
                            if let requests = requests,
                               let latestRequest = requests.filter({ $0.status == "pending" }).first {
                                let senderName = latestRequest.user.fullName.isEmpty ? "未知用户" : latestRequest.user.fullName
                                self.friendRequestSenderName = senderName
                                self.showFriendRequestAlert = true
                            } else {
                            }
                        }
                    }
                }
            }
            
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("FriendshipRequestUpdated"),
                object: nil,
                queue: .main
            ) { _ in
                self.refreshNewFriendsList()
            }
            
            // 记录视图完全显示的时间
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let endTime = Date()
                let _ = endTime.timeIntervalSince(startTime)
            }
        }
        .onDisappear {
        }
    }
    
    // 🎯 新增：刷新新朋友列表和数量
    private func refreshNewFriendsList() {
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        
        // 🚀 修复：强制刷新，不使用缓存，确保获取最新数据
        // 刷新好友申请列表
        FriendshipManager.shared.fetchFriendshipRequestsWithRetry(maxAttempts: 2) { requests, error in
            DispatchQueue.main.async {
                if error != nil {
                    return
                }
                
                guard let requests = requests else {
                    withAnimation {
                        self.existingMessages = []
                    }
                    self.newFriendsCountManager.updateCount(0)
                    return
                }
                
                
                // 🔍 调试：打印所有请求的状态
                for (_, _) in requests.enumerated() {
                }
                
                // 🎯 修改：只显示 pending 状态的好友申请，已接受或已拒绝的申请应该从列表中移除
                // 🎯 修改：过滤掉当前用户发出的好友申请，只显示别人发送的申请
                // 将 FriendshipRequest 转换为 MessageItem 格式
                
                // 🎯 新增：获取"一键已读"的时间戳，用于判断已读状态
                let markAllAsReadKey = "MarkAllAsReadTimestamp_\(currentUser.id)"
                let markAllAsReadTimestamp = UserDefaults.standard.object(forKey: markAllAsReadKey) as? Date
                
                if markAllAsReadTimestamp != nil {
                } else {
                }
                
                // 🎯 新增：获取本地黑名单
                let localBlacklistedUserIds = LocalBlacklistManager.shared.getAllLocalBlacklistedUserIds()
                
                let friendRequestMessages = requests.compactMap { request -> MessageItem? in
                    // 🚀 修复：只显示 pending 状态的好友申请
                    guard request.status == "pending" else {
                        return nil
                    }
                    
                    let currentUserId = currentUser.id
                    let isSentByCurrentUser = request.user.id == currentUserId
                    
                    // 🎯 修改：过滤掉当前用户发出的好友申请
                    guard !isSentByCurrentUser else {
                        return nil
                    }
                    
                    // 🎯 新增：过滤掉黑名单中的用户发送的好友申请
                    let senderId = request.user.id
                    if localBlacklistedUserIds.contains(senderId) {
                        return nil
                    }
                    
                    // 🔧 修复：如果 fullName 为空，从缓存获取或使用"未知用户"
                    let senderName: String
                    if request.user.fullName.isEmpty {
                        // 尝试从缓存获取用户名
                        let cachedName = LeanCloudService.shared.getCachedUserName(for: request.user.id)
                        senderName = cachedName ?? "未知用户"
                    } else {
                        senderName = request.user.fullName
                    }
                    
                    // 别人向当前用户发送的申请
                    let content = "\(senderName) 对你发送了好友申请"
                    
                    // 🎯 新增：如果好友申请的创建时间早于或等于"一键已读"的时间戳，则标记为已读
                    // 🔧 修复：添加1秒容差，避免时间精度问题导致相同时间的消息被误判为未读
                    let isRead: Bool
                    if let markAllAsReadTime = markAllAsReadTimestamp {
                        let timeDifference = request.createdAt.timeIntervalSince(markAllAsReadTime)
                        // 如果 createdAt 早于或等于 markAllAsReadTime（允许1秒容差），则标记为已读
                        isRead = timeDifference <= 1.0
                        
                        
                        if isRead {
                        } else {
                        }
                    } else {
                        isRead = false
                    }
                    
                    return MessageItem(
                        objectId: request.objectId,
                        senderId: request.user.id,
                        senderName: senderName, // 🔧 修复：使用处理后的 senderName
                        senderAvatar: "",
                        senderLoginType: "unknown",
                        receiverId: request.friend.id,
                        receiverName: request.friend.fullName,
                        receiverAvatar: "",
                        receiverLoginType: "unknown",
                        content: content,
                        timestamp: request.createdAt,
                        isRead: isRead,
                        type: .text,
                        deviceId: nil,
                        messageType: "friend_request", // 🔧 修复：使用 "friend_request" 而不是 "favorite"
                        isMatch: false
                    )
                }
                
                // 🎯 新增：批量查询 UserNameRecord，更新 senderName
                let senderIds = friendRequestMessages.map { $0.senderId }
                
                LeanCloudService.shared.batchFetchUserNames(userIds: senderIds, loginTypes: Array(repeating: "unknown", count: senderIds.count)) { userNameDict in
                    DispatchQueue.main.async {
                        // 更新 MessageItem 的 senderName
                        var updatedMessages = friendRequestMessages
                        for (index, message) in friendRequestMessages.enumerated() {
                            if let userName = userNameDict[message.senderId], !userName.isEmpty, userName != "未知用户" {
                                // 更新 senderName
                                updatedMessages[index] = MessageItem(
                                    id: message.id,
                                    objectId: message.objectId,
                                    senderId: message.senderId,
                                    senderName: userName, // 使用从 UserNameRecord 查询到的用户名
                                    senderAvatar: message.senderAvatar,
                                    senderLoginType: message.senderLoginType,
                                    receiverId: message.receiverId,
                                    receiverName: message.receiverName,
                                    receiverAvatar: message.receiverAvatar,
                                    receiverLoginType: message.receiverLoginType,
                                    content: "\(userName) 对你发送了好友申请", // 更新内容
                                    timestamp: message.timestamp,
                                    isRead: message.isRead,
                                    type: message.type,
                                    deviceId: message.deviceId,
                                    messageType: message.messageType,
                                    isMatch: message.isMatch
                                )
                            }
                        }
                        
                        // 🚀 修复：使用 withAnimation 确保 SwiftUI 检测到变化并立即刷新
                        withAnimation {
                            self.existingMessages = updatedMessages
                        }
                    }
                }
                
                // 🚀 修复：先使用原始数据，等批量查询完成后再更新
                // 使用 withAnimation 确保 SwiftUI 检测到变化
                withAnimation {
                    self.existingMessages = friendRequestMessages
                }
                
                // 🎯 修改：只统计未读的 pending 状态的数量作为徽章（只统计别人发送的申请）
                let unreadPendingCount = friendRequestMessages.filter { !$0.isRead }.count
                let _ = requests.filter { request in
                    request.status == "pending" && request.user.id != currentUser.id
                }.count
                self.newFriendsCountManager.updateCount(unreadPendingCount)
            }
        }
    }
    
    // 加载真实数据的方法
    private func loadRealData() {
        let _ = Date()
        
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        
        // 加载好友列表 - 使用 FriendshipManager 从 _Followee 表加载
        let friendsLoadStartTime = Date()
        
        FriendshipManager.shared.fetchFriendsList { friends, error in
            DispatchQueue.main.async {
                let friendsLoadEndTime = Date()
                let _ = friendsLoadEndTime.timeIntervalSince(friendsLoadStartTime)
                
                if error != nil {
                    self.existingFriends = []
                    return
                }
                
                guard let friends = friends else {
                    self.existingFriends = []
                    return
                }
                
                for (_, _) in friends.enumerated() {
                }
                
                // 将UserInfo转换为MatchRecord格式以保持兼容性
                var friendsList: [MatchRecord] = []
                
                for friend in friends {
                    // 🔧 修复：使用真实的 userId 而不是 objectId
                    // 🎯 修改：user2Name 使用空字符串，不从 friend.fullName 获取（friend.fullName 来自 _Followee 表，可能不准确）
                    // 真实的用户名应该从 UserNameRecord 表获取，后续需要通过 updateFriendsUserInfo 更新
                    let matchRecord = MatchRecord(
                        user1Id: currentUser.userId,  // 使用真实的 userId
                        user2Id: friend.userId,  // 使用真实的 userId，而不是 friend.id (objectId)
                        user1Name: currentUser.fullName,
                        user2Name: "",  // 🎯 修改：使用空字符串，不从 _Followee 表的 displayName 获取
                        user1Avatar: "😀", // 默认头像
                        user2Avatar: "😀", // 默认头像
                        user1LoginType: currentUser.loginType == .apple ? "apple" : "guest",
                        user2LoginType: friend.loginType == .apple ? "apple" : "guest",
                        matchTime: Date(),
                        matchLocation: nil,
                        deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
                        timezone: TimeZone.current.identifier,
                        deviceTime: Date()
                    )
                    friendsList.append(matchRecord)
                }
                
                // 🎯 新增：更新好友的用户信息（从 UserNameRecord 表获取正确的用户名）
                self.updateFriendsUserInfoForMessageTab(friendsList, currentUser: currentUser) { updatedFriends in
                    DispatchQueue.main.async {
                        // 🔍 新增：从UI层面打印详细的好友列表信息
                        self.printDetailedFriendsListFromUI(matchRecords: updatedFriends, currentUser: currentUser)
                        
                        // 🔧 修复：添加去重处理，避免显示重复的好友记录
                        let deduplicatedFriends = self.removeDuplicateFriends(updatedFriends)
                        
                        self.existingFriends = deduplicatedFriends
                    }
                }
            }
        }
        
        // 加载消息数据
        let messagesLoadStartTime = Date()
        
        // 先使用缓存渲染一次"新的朋友"
        let cachedRequests = FriendshipManager.shared.friendshipRequests
        
        // 🎯 新增：获取"一键已读"的时间戳，用于判断已读状态
        let markAllAsReadKey = "MarkAllAsReadTimestamp_\(currentUser.id)"
        let markAllAsReadTimestamp = UserDefaults.standard.object(forKey: markAllAsReadKey) as? Date
        
        if markAllAsReadTimestamp != nil {
        } else {
        }
        
        if !cachedRequests.isEmpty {
            let cachedMessages = cachedRequests.compactMap { request -> MessageItem? in
                // 🚀 修复：只显示 pending 状态的好友申请
                guard request.status == "pending" else {
                    return nil
                }
                
                let currentUserId = currentUser.id
                let isSentByCurrentUser = request.user.id == currentUserId
                
                // 🎯 修改：过滤掉当前用户发出的好友申请
                guard !isSentByCurrentUser else {
                    return nil
                }
                
                // 🔧 修复：如果 fullName 为空，从缓存获取或使用"未知用户"
                let senderName: String
                if request.user.fullName.isEmpty {
                    // 尝试从缓存获取用户名
                    let cachedName = LeanCloudService.shared.getCachedUserName(for: request.user.id)
                    senderName = cachedName ?? "未知用户"
                } else {
                    senderName = request.user.fullName
                }
                
                // 别人向当前用户发送的申请
                let content = "\(senderName) 对你发送了好友申请"
                
                // 🎯 新增：如果好友申请的创建时间早于或等于"一键已读"的时间戳，则标记为已读
                // 🔧 修复：添加1秒容差，避免时间精度问题导致相同时间的消息被误判为未读
                let isRead: Bool
                if let markAllAsReadTime = markAllAsReadTimestamp {
                    let timeDifference = request.createdAt.timeIntervalSince(markAllAsReadTime)
                    // 如果 createdAt 早于或等于 markAllAsReadTime（允许1秒容差），则标记为已读
                    isRead = timeDifference <= 1.0
                    
                    
                    if isRead {
                    } else {
                    }
                } else {
                    isRead = false
                }
                
                return MessageItem(
                    objectId: request.objectId,
                    senderId: request.user.id,
                    senderName: senderName, // 🔧 修复：使用处理后的 senderName
                    senderAvatar: "",
                    senderLoginType: "unknown",
                    receiverId: request.friend.id,
                    receiverName: request.friend.fullName,
                    receiverAvatar: "",
                    receiverLoginType: "unknown",
                    content: content,
                    timestamp: request.createdAt,
                    isRead: isRead,
                    type: .text,
                    deviceId: nil,
                    messageType: "friend_request",
                    isMatch: false
                )
            }
            self.existingMessages = cachedMessages
            let _ = newFriendsCountManager.count
            let _ = cachedRequests.filter { request in
                request.status == "pending" && request.user.id != currentUser.id
            }.count
        }

        // 使用标准好友关系管理器查询好友申请（带退避重试）
        FriendshipManager.shared.fetchFriendshipRequestsWithRetry(maxAttempts: 4) { requests, error in
            DispatchQueue.main.async {
                let messagesLoadEndTime = Date()
                let _ = messagesLoadEndTime.timeIntervalSince(messagesLoadStartTime)
                
                if error != nil {
                    return
                }
                
                guard let requests = requests else {
                    return
                }
                
                // 🎯 修改：只显示 pending 状态的好友申请，已接受或已拒绝的申请应该从列表中移除
                // 🎯 修改：过滤掉当前用户发出的好友申请，只显示别人发送的申请
                // 将FriendshipRequest转换为MessageItem格式以保持兼容性
                let friendRequestMessages = requests.compactMap { request -> MessageItem? in
                    // 🚀 修复：只显示 pending 状态的好友申请
                    guard request.status == "pending" else {
                        return nil
                    }
                    
                    let currentUserId = currentUser.id
                    let isSentByCurrentUser = request.user.id == currentUserId
                    
                    // 🎯 修改：过滤掉当前用户发出的好友申请
                    guard !isSentByCurrentUser else {
                        return nil
                    }
                    
                    // 🔧 修复：如果 fullName 为空，从缓存获取或使用"未知用户"
                    let senderName: String
                    if request.user.fullName.isEmpty {
                        // 尝试从缓存获取用户名
                        let cachedName = LeanCloudService.shared.getCachedUserName(for: request.user.id)
                        senderName = cachedName ?? "未知用户"
                    } else {
                        senderName = request.user.fullName
                    }
                    
                    // 别人向当前用户发送的申请
                    let content = "\(senderName) 对你发送了好友申请"
                    
                    // 🎯 新增：如果好友申请的创建时间早于或等于"一键已读"的时间戳，则标记为已读
                    // 🔧 修复：添加1秒容差，避免时间精度问题导致相同时间的消息被误判为未读
                    let isRead: Bool
                    if let markAllAsReadTime = markAllAsReadTimestamp {
                        let timeDifference = request.createdAt.timeIntervalSince(markAllAsReadTime)
                        // 如果 createdAt 早于或等于 markAllAsReadTime（允许1秒容差），则标记为已读
                        isRead = timeDifference <= 1.0
                        
                        
                        if isRead {
                        } else {
                        }
                    } else {
                        isRead = false
                    }
                    
                    return MessageItem(
                        objectId: request.objectId,
                        senderId: request.user.id,
                        senderName: senderName, // 🔧 修复：使用处理后的 senderName
                        senderAvatar: "", // 需要从其他地方获取
                        senderLoginType: "unknown",
                        receiverId: request.friend.id,
                        receiverName: request.friend.fullName,
                        receiverAvatar: "", // 需要从其他地方获取
                        receiverLoginType: "unknown",
                        content: content,
                        timestamp: request.createdAt,
                        isRead: isRead,
                        type: .text,
                        deviceId: nil,
                        messageType: "friend_request", // 🎯 修复：统一使用 friend_request
                        isMatch: false
                    )
                }
                
                // 🎯 修改：只统计未读的 pending 状态的数量作为徽章（只统计别人发送的申请）
                let unreadPendingCount = friendRequestMessages.filter { !$0.isRead }.count
                let _ = requests.filter { request in
                    request.status == "pending" && request.user.id != currentUser.id
                }.count
                
                // 🎯 新增：批量查询 UserNameRecord，更新 senderName
                let senderIds = friendRequestMessages.map { $0.senderId }
                
                LeanCloudService.shared.batchFetchUserNames(userIds: senderIds, loginTypes: Array(repeating: "unknown", count: senderIds.count)) { userNameDict in
                    DispatchQueue.main.async {
                        // 更新 MessageItem 的 senderName
                        var updatedMessages = friendRequestMessages
                        for (index, message) in friendRequestMessages.enumerated() {
                            if let userName = userNameDict[message.senderId], !userName.isEmpty, userName != "未知用户" {
                                // 更新 senderName
                                updatedMessages[index] = MessageItem(
                                    id: message.id,
                                    objectId: message.objectId,
                                    senderId: message.senderId,
                                    senderName: userName, // 使用从 UserNameRecord 查询到的用户名
                                    senderAvatar: message.senderAvatar,
                                    senderLoginType: message.senderLoginType,
                                    receiverId: message.receiverId,
                                    receiverName: message.receiverName,
                                    receiverAvatar: message.receiverAvatar,
                                    receiverLoginType: message.receiverLoginType,
                                    content: "\(userName) 对你发送了好友申请", // 更新内容
                                    timestamp: message.timestamp,
                                    isRead: message.isRead,
                                    type: message.type,
                                    deviceId: message.deviceId,
                                    messageType: message.messageType,
                                    isMatch: message.isMatch
                                )
                                
                                // 🔍 同时更新缓存，确保后续显示正确
                                self.existingUserNameCache[message.senderId] = userName
                            }
                        }
                        
                        // 🚀 修复：使用 withAnimation 确保 SwiftUI 检测到变化并立即刷新
                        withAnimation {
                            self.existingMessages = updatedMessages
                        }
                    }
                }
                
                // 🚀 修复：先使用原始数据，等批量查询完成后再更新
                withAnimation {
                    self.existingMessages = friendRequestMessages
                }
                
                self.newFriendsCountManager.updateCount(unreadPendingCount)
                
                
                // 检测匹配状态
                self.detectAndUpdateMatchStatus()
            }
        }
        
        // 加载拍一拍消息 - 暂时使用空数组
        self.existingPatMessages = []
        
        // 🔧 修复：加载收藏记录
        loadFavoriteRecords()
    }
    
    // 加载收藏记录
    private func loadFavoriteRecords() {
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        let favoritesLoadStartTime = Date()
        
        LeanCloudService.shared.fetchActiveFavoriteRecords(userId: currentUser.id) { favoriteRecordsData, error in
            DispatchQueue.main.async {
                let favoritesLoadEndTime = Date()
                let _ = favoritesLoadEndTime.timeIntervalSince(favoritesLoadStartTime)
                
                if error != nil {
                    return
                }
                
                guard let favoriteRecordsData = favoriteRecordsData else {
                    return
                }
                
                
                // 转换为FavoriteRecord对象
                let favoriteRecords = favoriteRecordsData.compactMap { FavoriteRecord(dictionary: $0) }
                
                // 打印收藏记录详情
                for (_, _) in favoriteRecords.enumerated() {
                }
                
                self.favoriteRecords = favoriteRecords
                
                // 重新检测匹配状态
                self.detectAndUpdateMatchStatus()
            }
        }
    }
    
    // 处理收藏/取消收藏
    private func toggleFavorite(userId: String, name: String?, avatar: String?, loginType: String?, location: String?, timezone: String?) {
        // 实现收藏/取消收藏逻辑
    }
    
    // 处理移除收藏
    private func removeFavorite(userId: String) {
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        // 从本地数组中移除喜欢记录
        favoriteRecords.removeAll { $0.favoriteUserId == userId }
        
        // 保存到 UserDefaults
        let favoriteKey = StorageKeyUtils.getFavoriteRecordsKey(for: currentUser)
        if let favoriteData = try? JSONEncoder().encode(favoriteRecords) {
            UserDefaults.standard.set(favoriteData, forKey: favoriteKey)
        }
        
        // 发送通知，更新UI
        NotificationCenter.default.post(name: NSNotification.Name("RefreshMatchStatus"), object: nil)
        NotificationCenter.default.post(name: NSNotification.Name("RefreshFriendsList"), object: nil)
    }
    
    // 处理拍一拍
    private func handlePat(userId: String) {
        // 🎯 修复：调用 MessageView 的 handlePatFriend 方法
        // 注意：这里需要访问 MessageView 的实例，但由于 MessageView 是独立的 View，
        // 我们需要通过其他方式处理。实际上，onPat 回调应该直接调用 handlePatFriend。
        // 但是 MessageView 的 handlePatFriend 是 internal 的，无法直接访问。
        // 所以我们需要在 MessageView 内部处理，或者将 handlePatFriend 的逻辑提取出来。
    }
    
    // 处理解除好友关系
    private func handleUnfriend(matchRecord: MatchRecord) {
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        // 确定要解除关系的好友ID
        let friendId = matchRecord.user1Id == currentUser.userId ? matchRecord.user2Id : matchRecord.user1Id
        
        // 获取好友的 LeanCloud objectId
        let friendObjectId = friendId // friendId 就是 objectId
        
        // 1. 删除好友关系
        FriendshipManager.shared.removeFriend(friendObjectId) { success, errorMessage in
            DispatchQueue.main.async {
                if success {
                    // 从本地好友列表中移除
                    self.existingFriends.removeAll { friend in
                        let fId = friend.user1Id == currentUser.userId ? friend.user2Id : friend.user1Id
                        return fId == friendId
                    }
                    
                    // 2. 调用 removeFavorite 取消爱心点亮
                    self.removeFavorite(userId: friendId)
                    
                    // 🎯 新增：清空该好友的拍一拍消息
                    self.clearPatMessagesForFriend(friendId: friendId, currentUserId: currentUser.id)
                    
                    // 3. 刷新好友列表和匹配状态
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshMatchStatus"), object: nil)
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshFriendsList"), object: nil)
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshNewFriends"), object: nil)
                } else {
                    // 即使删除好友关系失败，也执行取消爱心点亮
                    self.removeFavorite(userId: friendId)
                    
                    // 🎯 新增：即使删除好友关系失败，也清空该好友的拍一拍消息
                    self.clearPatMessagesForFriend(friendId: friendId, currentUserId: currentUser.id)
                }
            }
        }
    }
    
    /// 🎯 新增：清空指定好友的拍一拍消息
    private func clearPatMessagesForFriend(friendId: String, currentUserId: String) {
        // 从 existingPatMessages 中移除与该好友相关的所有消息
        existingPatMessages.removeAll { message in
            // 移除发送者或接收者是该好友的消息
            return message.senderId == friendId || message.receiverId == friendId
        }
        
        // 保存更新后的消息列表到本地
        UserDefaultsManager.savePatMessages(existingPatMessages, userId: currentUserId)
        
        // 更新 PatMessageUpdateManager 中的消息列表
        PatMessageUpdateManager.shared.clearPatMessagesForUser(friendId)
        
    }
    
    // 处理消息点击
    private func handleMessageTap(message: MessageItem) {
        
        // 标记消息为已读
        if let index = existingMessages.firstIndex(where: { $0.id == message.id }) {
            existingMessages[index].isRead = true
        }
        
        // 更新未读消息计数
        unreadMessageCount = calculateUnreadCount()
    }
    
    // 检测并更新匹配状态
    private func detectAndUpdateMatchStatus() {
        let matchDetectionStartTime = Date()
        
        // 检测匹配状态并更新UI
        for (index, message) in existingMessages.enumerated() {
            let userId = message.senderId
            let isFavorited = favoriteRecords.contains { $0.favoriteUserId == userId }
            let isFavoritedByMe = favoriteRecords.contains { $0.favoriteUserId == userId }
            
            
            if isFavorited && isFavoritedByMe {
                // 匹配成功
                existingMessages[index].isMatch = true
            }
        }
        
        let _ = existingMessages.filter { $0.isMatch }.count
        
        let matchDetectionEndTime = Date()
        let _ = matchDetectionEndTime.timeIntervalSince(matchDetectionStartTime)
    }
    
    // 计算未读消息数量
    private func calculateUnreadCount() -> Int {
        return existingMessages.filter { !$0.isRead }.count
    }
    
    // MARK: - 去重处理方法
    
    /// 移除重复的好友记录
    private func removeDuplicateFriends(_ friends: [MatchRecord]) -> [MatchRecord] {
        
        var uniqueFriends: [MatchRecord] = []
        var seenPairs: Set<String> = []
        
        for (_, friend) in friends.enumerated() {
            // 创建唯一标识符（按用户ID排序）
            let sortedIds = [friend.user1Id, friend.user2Id].sorted()
            let pairKey = "\(sortedIds[0])-\(sortedIds[1])"
            
            
            if !seenPairs.contains(pairKey) {
                seenPairs.insert(pairKey)
                uniqueFriends.append(friend)
            } else {
            }
        }
        
        for (_, friend) in uniqueFriends.enumerated() {
            let _ = friend.user1Id == (userManager.currentUser?.id ?? "") ? friend.user2Id : friend.user1Id
            let _ = friend.user1Id == (userManager.currentUser?.id ?? "") ? friend.user2Name : friend.user1Name
        }
        
        return uniqueFriends
    }
    
    // 🎯 新增：更新好友的用户信息（从 UserNameRecord 表获取正确的用户名）
    private func updateFriendsUserInfoForMessageTab(_ friends: [MatchRecord], currentUser: UserInfo, completion: @escaping ([MatchRecord]) -> Void) {
        var updatedFriends = friends
        let dispatchGroup = DispatchGroup()
        
        for (index, friend) in friends.enumerated() {
            let friendId = friend.user1Id == currentUser.userId ? friend.user2Id : friend.user1Id
            
            dispatchGroup.enter()
            
            // 🎯 使用 fetchUserNameAndLoginType 同时获取用户名和登录类型，确保获取到正确的用户名
            LeanCloudService.shared.fetchUserNameAndLoginType(objectId: friendId) { userName, loginType, error in
                DispatchQueue.main.async {
                    // 更新用户名
                    if let userName = userName, !userName.isEmpty {
                        if friend.user1Id == currentUser.userId {
                            updatedFriends[index].user2Name = userName
                        } else {
                            updatedFriends[index].user1Name = userName
                        }
                    }
                    
                    // 更新登录类型（如果获取到了）
                    if let loginType = loginType, !loginType.isEmpty {
                        if friend.user1Id == currentUser.userId {
                            updatedFriends[index].user2LoginType = loginType
                        } else {
                            updatedFriends[index].user1LoginType = loginType
                        }
                    }
                    
                    dispatchGroup.leave()
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(updatedFriends)
        }
    }
    
    // 🔍 新增：从UI层面打印详细的好友列表信息
    private func printDetailedFriendsListFromUI(matchRecords: [MatchRecord], currentUser: UserInfo) {
        
        if matchRecords.isEmpty {
        } else {
            
            for (_, matchRecord) in matchRecords.enumerated() {
                // 确定好友信息（非当前用户的那个）
                let _ = matchRecord.user1Id == currentUser.id ? matchRecord.user2Id : matchRecord.user1Id
                let _ = matchRecord.user1Id == currentUser.id ? matchRecord.user2Name : matchRecord.user1Name
                let _ = matchRecord.user1Id == currentUser.id ? matchRecord.user2Avatar : matchRecord.user1Avatar
                let _ = matchRecord.user1Id == currentUser.id ? matchRecord.user2LoginType : matchRecord.user1LoginType
                
                // 格式化匹配时间
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                let _ = dateFormatter.string(from: matchRecord.matchTime)
                
            }
        }
        
    }
}

