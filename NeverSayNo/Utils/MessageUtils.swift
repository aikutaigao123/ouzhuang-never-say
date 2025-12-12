import Foundation

// 消息处理工具类
class MessageUtils {
    
    // 去重消息：按发送者、接收者、消息类型和时间去重，优先保留好友申请消息
    static func removeDuplicateMessages(_ messages: [MessageItem]) -> [MessageItem] {
        
        var userMessages: [String: [MessageItem]] = [:]
        var deduplicatedMessages: [MessageItem] = []
        
        // 按时间排序，最新的在前
        let sortedMessages = messages.sorted { $0.timestamp > $1.timestamp }
        
        // 按发送者和接收者分组
        for message in sortedMessages {
            let userKey = "\(message.senderId)_\(message.receiverId)"
            if userMessages[userKey] == nil {
                userMessages[userKey] = []
            }
            userMessages[userKey]?.append(message)
        }
        
        
        // 处理每个用户的消息
        for (_, userMessageList) in userMessages {
            let sortedUserMessages = userMessageList.sorted { $0.timestamp > $1.timestamp } // 最新的在前
            
            
            // 优先选择好友申请消息，如果没有则选择最新的消息
            var selectedMessage: MessageItem?
            
            // 首先查找好友申请消息
            for message in sortedUserMessages {
                if message.content.contains("对你发送了好友申请") {
                    selectedMessage = message
                    break
                }
            }
            
            // 如果没有找到好友申请消息，则选择最新的消息
            if selectedMessage == nil {
                selectedMessage = sortedUserMessages.first
            }
            
            guard let message = selectedMessage else { continue }
            deduplicatedMessages.append(message)
        }
        
        // 重新按时间排序（最新的在前）
        let finalMessages = deduplicatedMessages.sorted { $0.timestamp > $1.timestamp }
        
        
        return finalMessages
    }
    
    // 处理拍一拍消息：保留所有拍一拍消息，无数量限制
    static func processPatMessages(_ messages: [MessageItem]) -> [MessageItem] {
        // 🔍 新增：打印输入消息的详细信息
        
        // 过滤出拍一拍消息
        let patMessages = messages.filter { message in
            let isPatMessage = message.content.contains("拍了拍你") || message.messageType == "pat"
            if isPatMessage {
            }
            return isPatMessage
        }
        
        
        // 按时间排序，最新的在前
        let sortedPatMessages = patMessages.sorted { $0.timestamp > $1.timestamp }
        
        
        // 🔍 新增：打印所有拍一拍消息的详细信息
        for (_, message) in sortedPatMessages.enumerated() {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let _ = formatter.string(from: message.timestamp)
        }
        
        // 返回所有拍一拍消息，无数量限制
        return sortedPatMessages
    }
    
    // 按userid过滤拍一拍消息：只返回与当前用户相关的拍一拍消息
    static func filterPatMessagesByUserId(_ messages: [MessageItem], currentUserId: String) -> [MessageItem] {
        // 🔍 新增：打印输入消息的详细信息
        
        // 过滤出与当前用户相关的拍一拍消息
        let patMessages = messages.filter { message in
            // 🔧 修复：同时检查messageType和content内容
            let isPatMessageType = message.messageType == "pat"
            let isPatContent = message.content.contains("拍了拍")
            
            // 如果messageType是"pat"或者内容包含"拍了拍"，都认为是拍一拍消息
            let isPatMessage = isPatMessageType || isPatContent
            
            if !isPatMessage {
                return false
            }
            
            // 按userid过滤：发送者或接收者是当前用户
            let isRelevantToCurrentUser = message.senderId == currentUserId || message.receiverId == currentUserId
            
            // 🔍 新增：打印过滤过程
            if isPatMessage {
            }
            
            return isRelevantToCurrentUser
        }
        
        
        // 按时间排序，最新的在前
        let sortedPatMessages = patMessages.sorted { $0.timestamp > $1.timestamp }
        
        
        // 🔍 新增：打印所有过滤后的拍一拍消息
        for (_, message) in sortedPatMessages.enumerated() {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let _ = formatter.string(from: message.timestamp)
        }
        
        // 返回所有拍一拍消息，无数量限制
        return sortedPatMessages
    }
    
    // 按userid过滤好友申请消息：只返回与当前用户相关的好友申请消息
    static func filterFriendRequestMessagesByUserId(_ messages: [MessageItem], currentUserId: String) -> [MessageItem] {
        
        // 🔧 修复：先按时间排序，确保时间顺序正确
        let sortedMessages = messages.sorted { $0.timestamp < $1.timestamp }
        
        // 🔧 修复：创建用户对的消息映射，用于检查撤销状态
        var userPairMessages: [String: [MessageItem]] = [:]
        var skippedCount = 0
        var matchedCount = 0
        
        // 按用户对分组消息
        for (index, message) in sortedMessages.enumerated() {
            
            // 🔍 新增：打印前几条消息的详细信息用于调试
            if index < 5 {
            }
            
            // 过滤掉当前用户对自己发送的消息
            if message.senderId == currentUserId {
                if index < 5 {
                }
                skippedCount += 1
                continue
            }
            
            // 只处理与当前用户相关的消息
            if message.receiverId != currentUserId {
                if index < 5 {
                }
                skippedCount += 1
                continue
            }
            
            // 排除拍一拍消息
            let isPatMessage = message.messageType == "pat" || message.content.contains("拍了拍")
            if isPatMessage {
                if index < 5 {
                }
                skippedCount += 1
                continue
            }
            
            // 🔧 修复：更严格的好友申请消息过滤逻辑
            let isFriendRequestMessage = message.messageType == "friend_request" || 
                                       message.messageType == "friend_accept" || 
                                       message.messageType == "friend_reject" ||
                                       message.messageType == "friend_cancel"
            
            let isFavoriteButFriendRequest = message.messageType == "favorite" && 
                                           message.content.contains("对你发送了好友申请")
            
            let isUnfavoriteMessage = message.messageType == "unfavorite" || 
                                    message.content.contains("撤销了好友申请")
            
            // 🔧 修复：更严格的内容匹配，只匹配明确的好友申请消息
            let isContentMatch = !isFriendRequestMessage && !isFavoriteButFriendRequest && !isUnfavoriteMessage && 
                               message.content.contains("对你发送了好友申请")
            
            if isFriendRequestMessage || isFavoriteButFriendRequest || isContentMatch {
                matchedCount += 1
                
                let senderId = message.senderId
                if userPairMessages[senderId] == nil {
                    userPairMessages[senderId] = []
                }
                userPairMessages[senderId]?.append(message)
            } else {
                if index < 5 {
                }
                skippedCount += 1
            }
        }
        
        
        // 🔧 修复：检查每个用户对的消息，只保留未被撤销的好友申请
        var validFriendRequestMessages: [MessageItem] = []
        
        for (_, messages) in userPairMessages {
            
            // 检查是否有好友申请消息
            let friendRequestMessages = messages.filter { message in
                let isFriendRequestMessage = message.messageType == "friend_request" || 
                                           message.messageType == "friend_accept" || 
                                           message.messageType == "friend_reject" ||
                                           message.messageType == "friend_cancel"
                
                let isFavoriteButFriendRequest = message.messageType == "favorite" && 
                                               message.content.contains("对你发送了好友申请")
                
                // 🔧 修复：只匹配明确的好友申请消息，排除其他类型
                let isContentMatch = !isFriendRequestMessage && !isFavoriteButFriendRequest && 
                                   message.content.contains("对你发送了好友申请")
                
                return isFriendRequestMessage || isFavoriteButFriendRequest || isContentMatch
            }
            
            
            // 检查是否有撤销消息
            let unfavoriteMessages = messages.filter { message in
                let isUnfavoriteMessage = message.messageType == "unfavorite" || 
                                        message.content.contains("撤销了好友申请")
                return isUnfavoriteMessage
            }
            
            
            // 如果没有任何撤销消息，保留所有好友申请消息
            if unfavoriteMessages.isEmpty {
                validFriendRequestMessages.append(contentsOf: friendRequestMessages)
            } else {
                // 如果有撤销消息，检查时间顺序
                let latestFriendRequest = friendRequestMessages.max { $0.timestamp < $1.timestamp }
                let latestUnfavorite = unfavoriteMessages.max { $0.timestamp < $1.timestamp }
                
                if let latestRequest = latestFriendRequest, let latestUnfavorite = latestUnfavorite {
                    if latestRequest.timestamp > latestUnfavorite.timestamp {
                        validFriendRequestMessages.append(latestRequest)
                    } else {
                    }
                } else if latestFriendRequest != nil {
                    validFriendRequestMessages.append(contentsOf: friendRequestMessages)
                }
            }
        }
        
        
        // 🔧 新增：去重处理，每个发送者只保留最新的一条消息
        var deduplicatedMessages: [MessageItem] = []
        var latestMessageBySender: [String: MessageItem] = [:]
        
        for message in validFriendRequestMessages {
            let senderId = message.senderId
            if let existingMessage = latestMessageBySender[senderId] {
                // 如果已有该发送者的消息，比较时间，保留最新的
                if message.timestamp > existingMessage.timestamp {
                    latestMessageBySender[senderId] = message
                }
            } else {
                latestMessageBySender[senderId] = message
            }
        }
        
        deduplicatedMessages = Array(latestMessageBySender.values)
        
        // 按时间排序，最新的在前
        let sortedFriendRequestMessages = deduplicatedMessages.sorted { $0.timestamp > $1.timestamp }
        
        // 🔍 新增：详细分析最终消息列表
        var messageCounts: [String: Int] = [:]
        for message in sortedFriendRequestMessages {
            
            // 统计每个发送者的消息数量
            let senderId = message.senderId
            messageCounts[senderId] = (messageCounts[senderId] ?? 0) + 1
        }
        
        // 🔍 新增：分析重复消息
        for (_, count) in messageCounts {
            if count > 1 {
            }
        }
        
        return sortedFriendRequestMessages
    }
    
    // 按最新消息时间排序好友列表
    static func sortFriendsByLatestMessage(_ friends: [MatchRecord], messages: [MessageItem], currentUserId: String) -> [MatchRecord] {
        
        // 先收集每个好友的最新消息时间信息
        var friendMessageInfo: [(MatchRecord, Date, String)] = []
        
        for (_, friend) in friends.enumerated() {
            let friendId = friend.user1Id == currentUserId ? friend.user2Id : friend.user1Id
            let friendName = friend.user1Id == currentUserId ? friend.user2Name : friend.user1Name
            let latestMessageTime = getLatestMessageTime(for: friendId, in: messages, currentUserId: currentUserId)
            
            friendMessageInfo.append((friend, latestMessageTime, friendName))
            
        }
        
        // 按最新消息时间排序
        let sortedFriends = friendMessageInfo.sorted { $0.1 > $1.1 }
        
        
        return sortedFriends.map { $0.0 }
    }
    
    // 获取与指定好友的最新消息时间
    private static func getLatestMessageTime(for friendId: String, in messages: [MessageItem], currentUserId: String) -> Date {
        // 过滤出与指定好友相关的消息（双向）
        let friendMessages = messages.filter { message in
            return (message.senderId == friendId && message.receiverId == currentUserId) ||
                   (message.senderId == currentUserId && message.receiverId == friendId)
        }
        
        
        // 如果没有消息，返回一个很早的时间
        guard !friendMessages.isEmpty else {
            return Date.distantPast
        }
        
        // 打印所有相关消息的详细信息（调试用）
        
        // 找到最新消息
        let latestMessage = friendMessages.max(by: { $0.timestamp < $1.timestamp })
        let latestTime = latestMessage?.timestamp ?? Date.distantPast
        
        
        return latestTime
    }
}
