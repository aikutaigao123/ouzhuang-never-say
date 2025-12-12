import SwiftUI
import Combine

// MARK: - MessageView Message Handling Extension
extension MessageView {
    
    // MARK: - Message Loading Methods
    
    /// 加载消息数据（带加载状态）
    internal func loadMessages() {
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        isLoading = true
        
        // 使用LeanCloudService加载消息数据
        // 🔧 修复：使用 objectId 查询消息
        LeanCloudService.shared.fetchMessages(userId: currentUser.id) { messages, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if error != nil {
                    return
                }
                
                guard let messages = messages else {
                    return
                }
                
                
                // 处理消息数据
                self.processLoadedMessages(messages)
            }
        }
    }
    
    /// 静默加载消息数据（不显示加载状态）
    internal func loadMessagesSilently() {
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        isSilentLoading = true
        
        // 使用LeanCloudService加载消息数据
        // 🔧 修复：使用 objectId 查询消息
        LeanCloudService.shared.fetchMessages(userId: currentUser.id) { messages, error in
            DispatchQueue.main.async {
                self.isSilentLoading = false
                
                if error != nil {
                    return
                }
                
                guard let messages = messages else {
                    return
                }
                
                
                // 处理消息数据
                self.processLoadedMessages(messages)
            }
        }
    }
    
    /// 处理加载的消息数据
    internal func processLoadedMessages(_ messages: [MessageItem]) {
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        // 🎯 方案1：完全使用 _FriendshipRequest 表管理好友申请
        // 不再从 Message 表过滤好友申请消息，好友申请由 FriendshipManager 管理
        // 只处理拍一拍消息
        let patMessages = MessageUtils.filterPatMessagesByUserId(messages, currentUserId: currentUser.id)
        
        // 处理拍一拍消息
        let processedPatMessages = MessageUtils.processPatMessages(patMessages)
        
        // 🎯 好友申请消息由 FriendshipManager 管理，不在这里处理
        // existingMessages 应该由 FriendshipManager 的数据填充（在 MessageTabView 等地方）
        // 这里只更新拍一拍消息
        
        // 🎯 新增：合并本地保存的拍一拍消息
        let localPatMessages = UserDefaultsManager.getPatMessages(userId: currentUser.id)
        var mergedPatMessages = processedPatMessages
        
        // 合并本地消息（避免重复，并保留本地已读状态）
        var mergedCount = 0
        var duplicateCount = 0
        for localMessage in localPatMessages {
            // 查找匹配的服务器消息
            var foundDuplicate = false
            for index in mergedPatMessages.indices {
                let serverMessage = mergedPatMessages[index]
                let isSameSender = serverMessage.senderId == localMessage.senderId
                let isSameReceiver = serverMessage.receiverId == localMessage.receiverId
                let isSameContent = serverMessage.content == localMessage.content
                let isSameTime = abs(serverMessage.timestamp.timeIntervalSince(localMessage.timestamp)) < 1.0
                let isSameObjectId = serverMessage.objectId == localMessage.objectId && localMessage.objectId != nil
                
                let isDuplicate = (isSameSender && isSameReceiver && isSameContent && isSameTime) || isSameObjectId
                
                if isDuplicate {
                    foundDuplicate = true
                    duplicateCount += 1
                    // 🎯 修复：如果本地消息已标记为已读，则更新服务器消息的已读状态
                    // 这样可以确保重新进入消息界面时，已读状态不会丢失
                    if localMessage.isRead && !serverMessage.isRead {
                        mergedPatMessages[index].isRead = true
                    }
                    break
                }
            }
            
            if !foundDuplicate {
                mergedPatMessages.append(localMessage)
                mergedCount += 1
            }
        }
        
        // 🎯 新增：更新拍一拍消息的用户名（从 UserNameRecord 表获取正确的用户名）
        updatePatMessagesUserNames(mergedPatMessages) { updatedMessages in
            DispatchQueue.main.async {
                // 按时间排序
                let sortedMessages = updatedMessages.sorted { $0.timestamp > $1.timestamp }
                self.existingPatMessages = sortedMessages
                
                // 🎯 新增：保存拍一拍消息到本地
                UserDefaultsManager.savePatMessages(sortedMessages, userId: currentUser.id)
                
                // 🔔 后台消息处理：处理新消息并发送推送通知
                // 只处理拍一拍消息，好友申请消息由 FriendshipManager 管理
                if !processedPatMessages.isEmpty {
                    BackgroundMessageProcessor.shared.processNewMessages(
                        processedPatMessages.map { message in
                            // 将MessageItem转换为字典格式
                            return [
                                "objectId": message.objectId ?? message.id.uuidString,
                                "senderId": message.senderId,
                                "senderName": message.senderName,
                                "receiverId": message.receiverId,
                                "receiverName": message.receiverName,
                                "content": message.content,
                                "messageType": message.messageType ?? "text",
                                "timestamp": ISO8601DateFormatter().string(from: message.timestamp)
                            ]
                        },
                        currentUserId: currentUser.id
                    )
                }
                
                // 🚀 修复：在更新existingPatMessages之后检测新消息
                self.detectNewPatMessages(processedPatMessages)
                
                
                // 🚀 新增：通知ContentView进行匹配状态检测
                self.onMessagesUpdated()
                
                // 🚀 新增：检测并更新消息的匹配状态
                for index in self.existingMessages.indices {
                    let message = self.existingMessages[index]
                    let isMatch = self.detectMatchStatus(for: message)
                    if isMatch != message.isMatch {
                        self.existingMessages[index].isMatch = isMatch
                    } else {
                    }
                }
                
                // 更新未读消息计数
                self.unreadCount = self.calculateUnreadCount()
            }
        }
    }
    
    /// 🎯 新增：更新拍一拍消息的用户名（从 UserNameRecord 表获取正确的用户名）
    private func updatePatMessagesUserNames(_ messages: [MessageItem], completion: @escaping ([MessageItem]) -> Void) {
        let dispatchGroup = DispatchGroup()
        var messageUpdates: [Int: (senderName: String?, receiverName: String?)] = [:]
        
        for (index, message) in messages.enumerated() {
            // 检查 senderName 和 receiverName 是否需要更新（如果是 objectId 或空字符串）
            let needsUpdateSender = message.senderName.isEmpty || looksLikeObjectId(message.senderName)
            let needsUpdateReceiver = message.receiverName.isEmpty || looksLikeObjectId(message.receiverName)
            
            if !needsUpdateSender && !needsUpdateReceiver {
                // 不需要更新，跳过
                continue
            }
            
            // 需要更新，初始化更新字典
            messageUpdates[index] = (senderName: nil, receiverName: nil)
            
            if needsUpdateSender {
                dispatchGroup.enter()
                LeanCloudService.shared.fetchUserNameAndLoginType(objectId: message.senderId) { userName, _, _ in
                    if var updates = messageUpdates[index] {
                        updates.senderName = userName
                        messageUpdates[index] = updates
                    }
                    dispatchGroup.leave()
                }
            }
            
            if needsUpdateReceiver {
                dispatchGroup.enter()
                LeanCloudService.shared.fetchUserNameAndLoginType(objectId: message.receiverId) { userName, _, _ in
                    if var updates = messageUpdates[index] {
                        updates.receiverName = userName
                        messageUpdates[index] = updates
                    }
                    dispatchGroup.leave()
                }
            }
        }
        
        // 等待所有更新完成
        dispatchGroup.notify(queue: .main) {
            // 创建更新后的消息列表
            var finalMessages: [MessageItem] = []
            for (index, message) in messages.enumerated() {
                if let updates = messageUpdates[index] {
                    // 需要更新
                    let newSenderName: String
                    if let name = updates.senderName, !name.isEmpty {
                        newSenderName = name
                    } else {
                        newSenderName = message.senderName
                    }
                    let newReceiverName: String
                    if let name = updates.receiverName, !name.isEmpty {
                        newReceiverName = name
                    } else {
                        newReceiverName = message.receiverName
                    }
                    var newContent = message.content
                    
                    // 🎯 更新 content 中的用户名
                    if message.content.contains("拍了拍") {
                        newContent = "\(newSenderName) 拍了拍 \(newReceiverName)"
                    }
                    
                    let updatedMessage = MessageItem(
                        id: message.id,
                        objectId: message.objectId,
                        senderId: message.senderId,
                        senderName: newSenderName,
                        senderAvatar: message.senderAvatar,
                        senderLoginType: message.senderLoginType,
                        receiverId: message.receiverId,
                        receiverName: newReceiverName,
                        receiverAvatar: message.receiverAvatar,
                        receiverLoginType: message.receiverLoginType,
                        content: newContent,
                        timestamp: message.timestamp,
                        isRead: message.isRead,
                        type: message.type,
                        deviceId: message.deviceId,
                        messageType: message.messageType,
                        isMatch: message.isMatch
                    )
                    finalMessages.append(updatedMessage)
                } else {
                    // 不需要更新
                    finalMessages.append(message)
                }
            }
            
            completion(finalMessages)
        }
    }
    
    /// 🎯 新增：检查字符串是否看起来像是 objectId（长度较长、全是字母数字）
    private func looksLikeObjectId(_ string: String) -> Bool {
        // objectId 通常是 24 个字符的十六进制字符串（MongoDB ObjectId）
        // 或者长度在 20-30 之间，全是字母数字
        if string.count >= 20 && string.count <= 30 {
            let characterSet = CharacterSet.alphanumerics
            return string.unicodeScalars.allSatisfy { characterSet.contains($0) }
        }
        return false
    }
    
    /// 🎯 新增：刷新新朋友列表（从 _FriendshipRequest 表）
    internal func refreshNewFriendsList() {
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
                
                // 🎯 修改：只显示 pending 状态的好友申请，已接受或已拒绝的申请应该从列表中移除
                // 🎯 修改：过滤掉当前用户发出的好友申请，只显示别人发送的申请
                // 将 FriendshipRequest 转换为 MessageItem 格式
                
                // 🎯 新增：获取"一键已读"的时间戳，用于判断已读状态
                let markAllAsReadKey = "MarkAllAsReadTimestamp_\(currentUser.id)"
                let markAllAsReadTimestamp = UserDefaults.standard.object(forKey: markAllAsReadKey) as? Date
                
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
                    
                    let content = "\(senderName) 对你发送了好友申请"
                    let senderAvatar = LeanCloudService.shared.getCachedUserAvatar(for: request.user.id) ?? ""
                    
                    // 🎯 参考头像界面方式：使用 FriendshipRequest 中的 loginType 作为初始值，后续会通过批量查询更新
                    // 不使用全局缓存，而是通过批量查询 UserNameRecord 实时获取（参考头像界面方式）
                    let senderLoginType = request.user.loginType.toString()
                    let receiverLoginType = request.friend.loginType.toString()
                    
                    // 🎯 新增：如果好友申请的创建时间早于或等于"一键已读"的时间戳，则标记为已读
                    // 🔧 修复：添加1秒容差，避免时间精度问题导致相同时间的消息被误判为未读
                    let isRead: Bool
                    if let markAllAsReadTime = markAllAsReadTimestamp {
                        let timeDifference = request.createdAt.timeIntervalSince(markAllAsReadTime)
                        // 如果 createdAt 早于或等于 markAllAsReadTime（允许1秒容差），则标记为已读
                        isRead = timeDifference <= 1.0
                    } else {
                        isRead = false
                    }
                    
                    return MessageItem(
                        objectId: request.objectId,
                        senderId: request.user.id,
                        senderName: senderName, // 🔧 修复：使用处理后的 senderName
                        senderAvatar: senderAvatar,
                        senderLoginType: senderLoginType,
                        receiverId: request.friend.id,
                        receiverName: request.friend.fullName,
                        receiverAvatar: LeanCloudService.shared.getCachedUserAvatar(for: request.friend.id) ?? "",
                        receiverLoginType: receiverLoginType,
                        content: content, // 🔧 修复：使用包含用户名的 content
                        timestamp: request.createdAt,
                        isRead: isRead,
                        type: .text,
                        deviceId: nil,
                        messageType: "friend_request",
                        isMatch: false
                    )
                }
                
                // 🎯 新增：批量查询 UserNameRecord，更新 senderName 和 senderLoginType（参考头像界面方式）
                let senderIds = friendRequestMessages.map { $0.senderId }
                
                // 🎯 使用新的批量查询方法，同时获取用户名和用户类型（参考头像界面的实时查询方式）
                LeanCloudService.shared.batchFetchUserNamesAndLoginTypes(userIds: senderIds) { userNameDict, loginTypeDict in
                    DispatchQueue.main.async {
                        // 更新 MessageItem 的 senderName 和 senderLoginType
                        var updatedMessages = friendRequestMessages
                        for (index, message) in friendRequestMessages.enumerated() {
                            if let userName = userNameDict[message.senderId], !userName.isEmpty, userName != "未知用户" {
                                // 🎯 参考头像界面方式：直接使用查询到的用户类型，不从全局缓存获取
                                let queriedLoginType = loginTypeDict[message.senderId] ?? message.senderLoginType
                                
                                // 更新 senderName 和 senderLoginType
                                updatedMessages[index] = MessageItem(
                                    id: message.id,
                                    objectId: message.objectId,
                                    senderId: message.senderId,
                                    senderName: userName, // 使用从 UserNameRecord 查询到的用户名
                                    senderAvatar: message.senderAvatar,
                                    senderLoginType: queriedLoginType, // 🎯 使用从 UserNameRecord 实时查询到的用户类型（参考头像界面方式）
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
                // 使用 withAnimation 确保 SwiftUI 检测到变化
                withAnimation {
                    self.existingMessages = friendRequestMessages
                }
                
                // 🎯 修改：只统计未读的 pending 状态的数量作为徽章（只统计别人发送的申请）
                let unreadPendingCount = friendRequestMessages.filter { !$0.isRead }.count
                self.newFriendsCountManager.updateCount(unreadPendingCount)
            }
        }
    }
    
    // MARK: - Message State Management
    
    /// 计算未读消息数量
    internal func calculateUnreadCount() -> Int {
        let unreadMessages = existingMessages.filter { !$0.isRead }
        return unreadMessages.count
    }
    
    /// 标记所有消息为已读
    internal func markAllAsRead() {
        // 更新本地状态
        for index in existingMessages.indices {
            existingMessages[index].isRead = true
        }
        
        // 🎯 新增：标记所有拍一拍消息为已读（与展开好友项的逻辑一致）
        var updatedPatMessages = existingPatMessages
        for index in updatedPatMessages.indices {
            if !updatedPatMessages[index].isRead {
                updatedPatMessages[index].isRead = true
            }
        }
        
        // 🎯 强制更新数组引用，触发SwiftUI重新计算patCount（与展开好友项的逻辑一致）
        DispatchQueue.main.async {
            // 🎯 修改：强制触发UI刷新，确保数字立即清0
            // 通过更新 @Binding 变量来触发UI刷新
            self.existingPatMessages = updatedPatMessages
            
            // 🎯 新增：保存"一键已读"的时间戳，用于后续刷新时判断已读状态
            guard let currentUser = self.userManager.currentUser else {
                return
            }
            let markAllAsReadTimestamp = Date()
            let key = "MarkAllAsReadTimestamp_\(currentUser.id)"
            UserDefaults.standard.set(markAllAsReadTimestamp, forKey: key)
            
            // 🎯 新增：保存更新后的拍一拍消息到本地，确保重新进入消息界面时已读状态不丢失
            UserDefaultsManager.savePatMessages(updatedPatMessages, userId: currentUser.id)
            
            // 更新未读计数
            self.unreadCount = 0
            
            // 更新新朋友计数管理器
            self.newFriendsCountManager.updateCount(0)
            
            // 🎯 新增：刷新"新的朋友"列表，确保应用已读状态
            self.refreshNewFriendsList()
            
            // 🎯 新增：发送通知，更新好友列表的拍一拍消息计数
            NotificationCenter.default.post(name: NSNotification.Name("RefreshPatMessages"), object: nil)
        }
    }
    
    /// 检查消息状态并更新UI
    internal func checkMessageStatus() {
        // 检查是否有未读消息
        let currentUnreadCount = calculateUnreadCount()
        if currentUnreadCount != unreadCount {
            unreadCount = currentUnreadCount
        }
        
        // 🚀 修改：不自动显示新的朋友列表，保持隐藏状态
    }
    
    // MARK: - Message Filtering and Processing
    
    /// 过滤消息（按类型、状态等）
    private func filterMessages(_ messages: [MessageItem]) -> [MessageItem] {
        return messages.filter { message in
            // 可以根据需要添加过滤条件
            // 例如：过滤特定类型的消息、特定时间范围的消息等
            return true
        }
    }
    
    /// 按时间排序消息
    private func sortMessagesByTime(_ messages: [MessageItem]) -> [MessageItem] {
        return messages.sorted { $0.timestamp > $1.timestamp }
    }
    
    // MARK: - Message Validation
    
    /// 验证消息数据完整性
    private func validateMessage(_ message: MessageItem) -> Bool {
        // 检查必要字段
        guard !message.senderId.isEmpty,
              !message.receiverId.isEmpty,
              !message.content.isEmpty else {
            return false
        }
        
        // 检查时间戳
        guard message.timestamp <= Date() else {
            return false
        }
        
        return true
    }
    
    /// 验证消息列表
    private func validateMessages(_ messages: [MessageItem]) -> [MessageItem] {
        return messages.filter { validateMessage($0) }
    }
}
