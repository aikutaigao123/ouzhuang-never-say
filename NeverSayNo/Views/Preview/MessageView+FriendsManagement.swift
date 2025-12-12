import SwiftUI
import Combine

// MARK: - MessageView Friends Management Extension
extension MessageView {
    
    // MARK: - Friends Loading Methods
    
    /// 加载好友列表数据（带加载状态）
    internal func loadFriends() {
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        isFriendsRefreshing = true
        
        // 使用 FriendshipManager 从 _Followee 表加载好友列表（friendStatus=true）
        FriendshipManager.shared.fetchFriendsList(completion: { friends, error in
            DispatchQueue.main.async(execute: {
                self.isFriendsRefreshing = false
                
                if error != nil {
                    return
                }
                
                guard let friends = friends else {
                    return
                }
                
                
                // 将UserInfo转换为MatchRecord格式以保持兼容性
                var friendsList: [MatchRecord] = []
                
                for friend in friends {
                    // 🔧 修复：使用真实的 userId 而不是 objectId，这样才能正确查询 UserAvatarRecord 和 UserNameRecord
                    let matchRecord = MatchRecord(
                        user1Id: currentUser.userId,  // 使用真实的 userId
                        user2Id: friend.userId,  // 使用真实的 userId，而不是 friend.id (objectId)
                        user1Name: currentUser.fullName,
                        user2Name: friend.fullName,
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
                
                // 处理好友列表数据
                self.processLoadedFriends(friendsList)
            })
        })
    }
    
    /// 静默加载好友列表数据（不显示加载状态）
    internal func loadFriendsSilently() {
        
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        isFriendsRefreshing = true
        
        // 使用 FriendshipManager 从 _Followee 表加载好友列表（friendStatus=true）
        FriendshipManager.shared.fetchFriendsList(completion: { friends, error in
            DispatchQueue.main.async(execute: {
                self.isFriendsRefreshing = false
                
                
                if error != nil {
                    return
                }
                
                guard let friends = friends else {
                    return
                }
                
                
                // 将UserInfo转换为MatchRecord格式以保持兼容性
                var friendsList: [MatchRecord] = []
                
                for friend in friends {
                    // 🔧 修复：使用真实的 userId 而不是 objectId，这样才能正确查询 UserAvatarRecord 和 UserNameRecord
                    let matchRecord = MatchRecord(
                        user1Id: currentUser.userId,  // 使用真实的 userId
                        user2Id: friend.userId,  // 使用真实的 userId，而不是 friend.id (objectId)
                        user1Name: currentUser.fullName,
                        user2Name: friend.fullName,
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
                
                // 处理好友列表数据
                self.processLoadedFriends(friendsList)
            })
        })
    }
    
    /// 处理加载的好友列表数据
    internal func processLoadedFriends(_ friends: [MatchRecord]) {
        
        // 去重处理
        let deduplicatedFriends = removeDuplicateFriends(friends)
        
        // 🎯 新增：更新好友的用户信息（从 UserNameRecord 表获取正确的用户名）
        updateFriendsUserInfo(deduplicatedFriends) { updatedFriends in
            DispatchQueue.main.async {
                // 🔧 修复：先显示好友列表，然后静默修改排序
                // 使用真实的 userId 以便与 UserNameRecord/UserAvatarRecord 查询一致
                let currentUserId = self.userManager.currentUser?.userId ?? ""
                
                // 检查现有消息数据
                let allMessages = self.existingMessages + self.existingPatMessages
                
                if allMessages.isEmpty {
                    // 先显示好友列表（按匹配时间排序）
                    self.displayFriendsWithFallbackSorting(updatedFriends)
                    // 然后静默加载消息数据并重新排序
                    self.loadMessagesAndSortSilently(updatedFriends)
                } else {
                    self.performFriendsSorting(updatedFriends, messages: allMessages, currentUserId: currentUserId)
                }
                
                // 🚀 移除自动匹配调用，避免无限循环导致闪退
            }
        }
    }
    
    /// 🎯 新增：更新好友的用户信息（从 UserNameRecord 表获取正确的用户名）
    private func updateFriendsUserInfo(_ friends: [MatchRecord], completion: @escaping ([MatchRecord]) -> Void) {
        guard let currentUser = userManager.currentUser else {
            completion(friends)
            return
        }
        
        var updatedFriends = friends
        let dispatchGroup = DispatchGroup()
        
        for (index, friend) in friends.enumerated() {
            let friendId = friend.user1Id == currentUser.userId ? friend.user2Id : friend.user1Id
            let _ = friend.user1Id == currentUser.userId ? friend.user2LoginType : friend.user1LoginType
            
            dispatchGroup.enter()
            
            // 🎯 修改：使用 fetchUserNameAndLoginType 同时获取用户名和登录类型，确保获取到正确的用户名
            LeanCloudService.shared.fetchUserNameAndLoginType(objectId: friendId) { userName, loginType, error in
                DispatchQueue.main.async {
                    // 更新用户名
                    if let userName = userName, !userName.isEmpty {
                        if friend.user1Id == currentUser.userId {
                            updatedFriends[index].user2Name = userName
                        } else {
                            updatedFriends[index].user1Name = userName
                        }
                        // 更新缓存
                        self.existingUserNameCache[friendId] = userName
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
    
    /// 先显示好友列表（按匹配时间排序）
    private func displayFriendsWithFallbackSorting(_ friends: [MatchRecord]) {
        
        let sortedFriends = friends.sorted { $0.matchTime > $1.matchTime }
        
        for (_, friend) in sortedFriends.enumerated() {
            let _ = friend.user1Id == (userManager.currentUser?.id ?? "") ? friend.user2Name : friend.user1Name
        }
        
        // 立即更新好友列表显示
        existingFriends = sortedFriends
        
        // 🚀 修改：不自动显示新的朋友列表，保持隐藏状态
        // 新的朋友列表应该默认隐藏，只有点击按钮时才显示
        
    }
    
    /// 静默加载消息数据并重新排序
    private func loadMessagesAndSortSilently(_ friends: [MatchRecord]) {
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        
        LeanCloudService.shared.fetchMessages(userId: currentUser.id) { messages, error in
            DispatchQueue.main.async {
                if error != nil {
                    return
                }
                
                guard let messages = messages else {
                    return
                }
                
                
                // 过滤相关消息
                let allRelevantMessages = messages.filter { message in
                    // 过滤掉当前用户对自己发送的消息
                    if message.senderId == currentUser.id && message.receiverId == currentUser.id {
                        return false
                    }
                    
                    // 包含所有相关消息类型：好友申请、拍一拍等
                    return message.content.contains("对你发送了好友申请") ||
                           message.content.contains("已同意了你的好友申请") ||
                           message.content.contains("已拒绝了你的好友申请") ||
                           message.content.contains("拍了拍") ||
                           message.messageType == "pat"
                }
                
                
                // 静默重新排序
                self.performSilentResorting(friends, messages: allRelevantMessages, currentUserId: currentUser.id)
            }
        }
    }
    
    /// 静默重新排序好友列表
    private func performSilentResorting(_ friends: [MatchRecord], messages: [MessageItem], currentUserId: String) {
        
        for (_, friend) in friends.enumerated() {
            let _ = friend.user1Id == currentUserId ? friend.user2Name : friend.user1Name
        }
        
        let sortedFriends = MessageUtils.sortFriendsByLatestMessage(friends, messages: messages, currentUserId: currentUserId)
        
        for (_, friend) in existingFriends.enumerated() {
            let _ = friend.user1Id == currentUserId ? friend.user2Name : friend.user1Name
        }
        
        // 🔧 修复：确保UI更新，触发重新渲染
        existingFriends = sortedFriends
        
        for (_, friend) in existingFriends.enumerated() {
            let _ = friend.user1Id == currentUserId ? friend.user2Name : friend.user1Name
        }
        
        // 强制触发UI更新 - 通过修改一个状态变量
        DispatchQueue.main.async {
            
            // 通过修改isNewFriendsVisible来强制UI重新渲染
            let currentState = self.isNewFriendsVisible
            self.isNewFriendsVisible = !currentState
            self.isNewFriendsVisible = currentState
            
            
            // 再次确认好友列表状态
            for (_, friend) in self.existingFriends.enumerated() {
                let _ = friend.user1Id == currentUserId ? friend.user2Name : friend.user1Name
            }
        }
        
        
        for (_, friend) in sortedFriends.enumerated() {
            let _ = friend.user1Id == currentUserId ? friend.user2Name : friend.user1Name
        }
        
    }
    
    /// 加载消息数据然后排序好友列表
    private func loadMessagesAndThenSortFriends(_ friends: [MatchRecord]) {
        guard let currentUser = userManager.currentUser else {
            return
        }
        
        
        LeanCloudService.shared.fetchMessages(userId: currentUser.id) { messages, error in
            DispatchQueue.main.async {
                if error != nil {
                    // 如果消息加载失败，使用按匹配时间排序
                    self.performFallbackSorting(friends)
                    return
                }
                
                guard let messages = messages else {
                    // 如果消息为空，使用按匹配时间排序
                    self.performFallbackSorting(friends)
                    return
                }
                
                
                // 过滤相关消息
                let allRelevantMessages = messages.filter { message in
                    // 过滤掉当前用户对自己发送的消息
                    if message.senderId == currentUser.id && message.receiverId == currentUser.id {
                        return false
                    }
                    
                    // 包含所有相关消息类型：好友申请、拍一拍等
                    return message.content.contains("对你发送了好友申请") ||
                           message.content.contains("已同意了你的好友申请") ||
                           message.content.contains("已拒绝了你的好友申请") ||
                           message.content.contains("拍了拍") ||
                           message.messageType == "pat"
                }
                
                
                // 进行排序
                self.performFriendsSorting(friends, messages: allRelevantMessages, currentUserId: currentUser.id)
            }
        }
    }
    
    /// 执行好友排序
    private func performFriendsSorting(_ friends: [MatchRecord], messages: [MessageItem], currentUserId: String) {
        
        let sortedFriends = MessageUtils.sortFriendsByLatestMessage(friends, messages: messages, currentUserId: currentUserId)
        
        // 更新好友列表
        existingFriends = sortedFriends
        
        // 新朋友列表默认隐藏，只有点击"新的朋友"按钮时才显示
        
        
        for (_, friend) in sortedFriends.enumerated() {
            let _ = friend.user1Id == currentUserId ? friend.user2Name : friend.user1Name
        }
    }
    
    /// 执行回退排序（按匹配时间）
    private func performFallbackSorting(_ friends: [MatchRecord]) {
        
        let sortedFriends = friends.sorted { $0.matchTime > $1.matchTime }
        
        // 更新好友列表
        existingFriends = sortedFriends
        
        // 🚀 修改：不自动显示新的朋友列表，保持隐藏状态
        
        
        for (_, friend) in sortedFriends.enumerated() {
            let _ = friend.user1Id == (userManager.currentUser?.id ?? "") ? friend.user2Name : friend.user1Name
        }
    }
    
    // MARK: - Friends Management Methods
    
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
            // 与用户头像界面一致：直接使用MatchRecord中的字段（实际显示时会在组件onAppear时实时查询）
            let _ = friend.user1Id == (userManager.currentUser?.id ?? "") ? friend.user2Name : friend.user1Name
        }
        
        return uniqueFriends
    }
    
    // sortFriendsByLatestMessage方法使用MessageUtils中的静态方法
    
    /// 获取指定好友的最新消息
    private func getLatestMessageForFriend(_ friend: MatchRecord, messages: [MessageItem]) -> MessageItem? {
        let friendMessages = messages.filter { message in
            return message.senderId == friend.user1Id || message.senderId == friend.user2Id ||
                   message.receiverId == friend.user1Id || message.receiverId == friend.user2Id
        }
        
        return friendMessages.max { $0.timestamp < $1.timestamp }
    }
    
    // MARK: - Friends Status Management
    
    /// 更新好友在线状态（优化版本 - 使用批量查询）
    internal func updateFriendOnlineStatus() {
        guard let currentUser = userManager.currentUser else { 
            return 
        }
        
        // 收集所有需要检查在线状态的好友ID
        var friendIds: Set<String> = []
        for friend in existingFriends {
            friendIds.insert(friend.user1Id)
            friendIds.insert(friend.user2Id)
        }
        friendIds.remove(currentUser.id) // 移除当前用户ID
        
        // 🔧 优化：使用批量查询替代逐个查询
        if !friendIds.isEmpty {
            let friendIdsArray = Array(friendIds)
            let uiStartTime = Date()
            
            LeanCloudService.shared.batchFetchUserLastOnlineTime(userIds: friendIdsArray) { results in
                DispatchQueue.main.async {
                    // 批量更新缓存
                    for (userId, (isOnline, lastActiveTime)) in results {
                        self.onlineStatusCache[userId] = (isOnline, lastActiveTime)
                        
                        // 🔍 新增：打印每个好友的在线状态
                        if let lastActive = lastActiveTime {
                            let formatter = DateFormatter()
                            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                            formatter.timeZone = TimeZone.current
                            let _ = formatter.string(from: lastActive)
                            
                            let _ = Date()
                            let _ = Date().timeIntervalSince(lastActive)
                            let _ = self.formatTimeAgo(Date().timeIntervalSince(lastActive))
                            
                        } else {
                        }
                    }
                    // ⏱️ 计算UI层总耗时
                    let uiEndTime = Date()
                    let _ = uiEndTime.timeIntervalSince(uiStartTime)
                }
            }
        }
    }
    
    /// 检查指定用户的在线状态
    private func checkUserOnlineStatus(_ userId: String) {
        LeanCloudService.shared.fetchUserLastOnlineTime(userId: userId) { isOnline, lastActiveTime in
            DispatchQueue.main.async {
                self.onlineStatusCache[userId] = (isOnline, lastActiveTime)
            }
        }
    }
    
    /// 刷新好友列表显示状态
    internal func refreshFriendsDisplayState() {
        // 🚀 修改：不自动显示新的朋友列表，保持隐藏状态
    }
    
    // MARK: - Friends Validation
    
    /// 验证好友数据完整性
    private func validateFriend(_ friend: MatchRecord) -> Bool {
        // 检查必要字段
        guard !friend.user1Id.isEmpty,
              !friend.user2Id.isEmpty,
              !friend.user1Name.isEmpty,
              !friend.user2Name.isEmpty else {
            return false
        }
        
        // 检查匹配时间
        guard friend.matchTime <= Date() else {
            return false
        }
        
        return true
    }
    
    /// 验证好友列表
    private func validateFriends(_ friends: [MatchRecord]) -> [MatchRecord] {
        return friends.filter { validateFriend($0) }
    }
    
    // MARK: - Friends Filtering
    
    /// 过滤好友列表（按状态、类型等）
    private func filterFriends(_ friends: [MatchRecord]) -> [MatchRecord] {
        return friends.filter { friend in
            // 可以根据需要添加过滤条件
            // 例如：过滤特定类型的好友、特定时间范围的好友等
            return true
        }
    }
    
    /// 按在线状态排序好友
    private func sortFriendsByOnlineStatus(_ friends: [MatchRecord]) -> [MatchRecord] {
        return friends.sorted { friend1, friend2 in
            let friend1Online = getFriendOnlineStatus(friend1)
            let friend2Online = getFriendOnlineStatus(friend2)
            
            // 在线的好友排在前面
            if friend1Online && !friend2Online {
                return true
            }
            if !friend1Online && friend2Online {
                return false
            }
            
            // 如果在线状态相同，按最新消息时间排序
            return false // 这里可以调用其他排序逻辑
        }
    }
    
    /// 获取好友的在线状态
    private func getFriendOnlineStatus(_ friend: MatchRecord) -> Bool {
        // 使用真实的 userId
        let currentUserId = userManager.currentUser?.userId ?? ""
        let friendId = friend.user1Id == currentUserId ? friend.user2Id : friend.user1Id
        
        return onlineStatusCache[friendId]?.0 ?? false
    }
    
    /// 格式化时间差
    private func formatTimeAgo(_ timeInterval: TimeInterval) -> String {
        if timeInterval < 60 {
            return "刚刚"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)分钟前"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)小时前"
        } else if timeInterval < 604800 {
            let days = Int(timeInterval / 86400)
            return "\(days)天前"
        } else {
            return "7天前"
        }
    }
}
