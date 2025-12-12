import Foundation
import UIKit
import LeanCloud

/**
 * LeanCloud IM 触发器管理器（基于 WebSocket）
 * 负责管理 LeanCloud 即时通讯连接，监听消息接收事件
 * 当收到新消息时触发更新机制，实现真正的实时性
 */
class LeanCloudIMTrigger: ObservableObject {
    static let shared = LeanCloudIMTrigger()
    
    private var isConnected = false
    private var reconnectTimer: Timer?
    private var reconnectAttempts = 0
    private var userId: String?
    private var userName: String?
    
    // 配置信息
    private let config = Configuration.shared
    
    private init() {}
    
    /**
     * 初始化 IM 连接（基于 WebSocket）
     * - Parameters:
     *   - userId: 用户ID
     *   - userName: 用户名
     */
    func initializeIM(userId: String, userName: String) {
        self.userId = userId
        self.userName = userName
        
        // 使用 WebSocket IM 客户端
        initializeWebSocketIM(userId: userId, userName: userName)
        
        isConnected = true
        reconnectAttempts = 0
    }
    
    /**
     * 初始化WebSocket IM客户端
     */
    private func initializeWebSocketIM(userId: String, userName: String) {
        
        // 初始化IM客户端
        PatMessageService.shared.initializeIMClient(userId: userId, userName: userName) { [weak self] success, error in
            if success {
                self?.setupWebSocketIMCallbacks()
            } else {
                // WebSocket 连接失败，记录错误
                self?.handleConnectionError()
            }
        }
    }
    
    /**
     * 设置WebSocket IM回调
     */
    private func setupWebSocketIMCallbacks() {
        // 设置拍一拍消息接收回调
        PatMessageService.shared.onPatMessageReceived = { [weak self] fromUserId, toUserId, content in
            self?.handleWebSocketPatMessage(fromUserId: fromUserId, toUserId: toUserId, content: content)
        }
        
        // 设置错误回调
        PatMessageService.shared.onError = { [weak self] error in
            self?.handleConnectionError()
        }
    }
    
    /**
     * 处理WebSocket拍一拍消息
     */
    private func handleWebSocketPatMessage(fromUserId: String, toUserId: String, content: String) {
        guard let currentUserId = self.userId else {
            return
        }
        
        // 🔧 关键检查：只有当消息是发给当前用户时才处理
        guard toUserId == currentUserId else {
            return
        }
        
        // 🎯 新增：检查发送方是否在我的好友列表中
        let isFriend = FriendshipManager.shared.isFriend(fromUserId)
        if !isFriend {
            // 发送方不在好友列表中，不处理这个消息
            return
        }
        
        // 与用户头像界面一致：实时查询服务器获取用户名
        let _ = UserTypeUtils.getLoginTypeFromUserId(fromUserId)
        let _ = UserTypeUtils.getLoginTypeFromUserId(toUserId)
        
        // 🎯 修改：使用 fetchUserNameAndLoginType 获取用户名，如果失败则使用"未知用户"而不是 userId
        LeanCloudService.shared.fetchUserNameAndLoginType(objectId: fromUserId) { senderName, _, _ in
            // 如果无法获取用户名，使用"未知用户"而不是 userId
            let resolvedSenderName: String
            if let name = senderName, !name.isEmpty {
                resolvedSenderName = name
            } else {
                resolvedSenderName = "未知用户"
            }
            
            // 异步查询接收者用户名
            LeanCloudService.shared.fetchUserNameAndLoginType(objectId: toUserId) { receiverName, _, _ in
                // 如果无法获取用户名，使用"未知用户"而不是 userId
                let resolvedReceiverName: String
                if let name = receiverName, !name.isEmpty {
                    resolvedReceiverName = name
                } else {
                    resolvedReceiverName = "未知用户"
                }
                
                // 构造消息数据格式
                let messageData: [String: Any] = [
                    "objectId": UUID().uuidString,
                    "messageType": "pat",
                    "senderId": fromUserId, // 🎯 新增：添加发送者ID，用于好友检查
                    "senderName": resolvedSenderName,
                    "receiverName": resolvedReceiverName,
                    "receiverId": toUserId, // 🔧 修复：使用实际的接收者ID，而不是currentUserId
                    "timestamp": ISO8601DateFormatter().string(from: Date())
                ]
                
                // 调用后台消息处理器
                BackgroundMessageProcessor.shared.processReceivedMessage(messageData, currentUserId: currentUserId)
                
                // 🎯 新增：立即创建 MessageItem 并发送通知，触发UI更新
                // 🎯 修改：更新 content，使用从 UserNameRecord 获取的正确用户名
                let messageContent = "\(resolvedSenderName) 拍了拍 \(resolvedReceiverName)"
                let newMessage = MessageItem(
                    senderId: fromUserId,
                    senderName: resolvedSenderName,
                    senderAvatar: "",
                    senderLoginType: nil,
                    receiverId: toUserId,
                    receiverName: resolvedReceiverName,
                    receiverAvatar: "",
                    receiverLoginType: nil,
                    content: messageContent,
                    timestamp: Date(),
                    isRead: false,
                    type: .text,
                    messageType: "pat",
                    isMatch: false
                )
                
                // 🎯 发送 PatMessageAdded 通知，让 MessageView 立即更新 existingPatMessages
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("PatMessageAdded"),
                        object: nil,
                        userInfo: ["message": newMessage]
                    )
                }
            }
        }
        
        // 触发消息接收通知（用于从服务器获取最新数据）
        triggerMessageUpdate()
    }
    
    private func appStateString(_ state: UIApplication.State) -> String {
        switch state {
        case .active: return "前台活跃"
        case .inactive: return "前台非活跃"
        case .background: return "后台"
        @unknown default: return "未知"
        }
    }
    
    /**
     * 断开连接
     */
    func disconnect() {
        isConnected = false
        
        // 停止重连
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        
        // 断开WebSocket IM客户端
        PatMessageService.shared.disconnectIMClient { success in
        }
        
        userId = nil
        userName = nil
        
    }
    
    /**
     * 检查连接状态
     */
    var connectionStatus: Bool {
        return isConnected && userId != nil
    }
    
    /**
     * 启动LiveQuery订阅
     */
    private func startLiveQuerySubscription() {
        guard let userId = self.userId else { return }
        
        // 启动好友关系LiveQuery订阅
        FriendshipLiveQueryManager.shared.startSubscription(currentUserId: userId)
        
        // 设置通知监听
        setupLiveQueryNotificationHandlers()
    }
    
    /**
     * 设置LiveQuery通知处理器
     */
    private func setupLiveQueryNotificationHandlers() {
        // 监听新好友申请
        NotificationCenter.default.addObserver(
            forName: .newFriendshipRequest,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleNewFriendshipRequest(notification)
        }
        
        // 监听好友申请状态变化
        NotificationCenter.default.addObserver(
            forName: .friendshipRequestUpdated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleFriendshipRequestUpdate(notification)
        }
        
        // 监听新好友关系
        NotificationCenter.default.addObserver(
            forName: .newFriendship,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleNewFriendship(notification)
        }
    }
    
    /**
     * 处理新好友申请
     */
    private func handleNewFriendshipRequest(_ notification: Notification) {
        
        // 触发消息更新
        triggerMessageUpdate()
        
        // 处理通知逻辑
        if let userInfo = notification.userInfo,
           let object = userInfo["object"] as? LCObject {
            processNewFriendshipRequestForNotifications(object: object)
        }

        // 新增：收到通知后主动拉取并打印当前好友申请详情
        FriendshipManager.shared.fetchFriendshipRequests { requests, error in
            if error != nil {
                return
            }
            let list = requests ?? []
            if list.isEmpty {
            } else {
                for (_, _) in list.enumerated() {
                }
            }
        }
    }
    
    /**
     * 处理好友申请状态变化
     */
    private func handleFriendshipRequestUpdate(_ notification: Notification) {
        
        // 触发消息更新
        triggerMessageUpdate()
    }
    
    /**
     * 处理新好友关系
     */
    private func handleNewFriendship(_ notification: Notification) {
        
        // 触发消息更新
        triggerMessageUpdate()
    }
    
    /**
     * 处理新好友申请通知
     */
    private func processNewFriendshipRequestForNotifications(object: LCObject) {
        guard self.userId != nil else { return }
        
        // 这里可以添加具体的通知处理逻辑
        // 例如：发送本地推送通知
    }
    
    /**
     * 触发消息更新通知
     */
    private func triggerMessageUpdate() {
        // 发送消息接收通知
        NotificationCenter.default.post(name: .imMessageReceived, object: nil)
    }
    
    /**
     * 处理连接错误
     */
    private func handleConnectionError() {
        reconnectAttempts += 1
        let maxAttempts = config.imMaxReconnectAttempts
        
        if reconnectAttempts >= maxAttempts {
            // 达到最大重连次数(\(maxAttempts))，停止重连
            disconnect()
        } else {
            scheduleReconnect()
        }
    }
    
    /**
     * 重连机制
     */
    private func scheduleReconnect() {
        let delay = Double(reconnectAttempts * 2) // 2秒、4秒、6秒
        
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            // 尝试重连 IM 触发器，第 \(self.reconnectAttempts) 次
            if let userId = self.userId, let userName = self.userName {
                self.initializeIM(userId: userId, userName: userName)
            }
        }
    }
    
    /**
     * 手动触发消息更新
     */
    func triggerManualCheck() {
        guard isConnected else {
            // IM 触发器未连接，无法手动检查
            return
        }
        
        // 手动触发消息更新通知
        triggerMessageUpdate()
    }
    
    /**
     * 获取连接统计信息
     */
    func getConnectionStats() -> (isConnected: Bool, userId: String?, reconnectAttempts: Int) {
        return (isConnected: isConnected, userId: userId, reconnectAttempts: reconnectAttempts)
    }
}

// MARK: - 通知名称
extension Notification.Name {
    static let imMessageReceived = Notification.Name("imMessageReceived")
}
