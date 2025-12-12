import SwiftUI

// MARK: - MessageView UI Components Extension
extension MessageView {
    
    // MARK: - UI Computed Properties
    
    // 消息标签页视图
    var messagesTabView: some View {
        VStack {
            if isLoading && existingMessages.isEmpty && existingPatMessages.isEmpty {
                loadingView
            } else if existingMessages.isEmpty && existingPatMessages.isEmpty && existingFriends.isEmpty {
                // 🎯 修复：当没有任何内容时，显示空状态（无论 isNewFriendsVisible 的状态）
                emptyStateView
            } else {
                messageListView
            }
        }
        // 强制在好友数量变化时刷新渲染树，便于挂载 List/friendsSection
        .id(existingFriends.count)
        .onChange(of: existingFriends.count) { _, _ in }
        .onChange(of: existingMessages.count) { _, _ in }
        .onChange(of: existingPatMessages.count) { _, _ in }
        .onChange(of: showFriendsList) { _, _ in }
        .onChange(of: isNewFriendsVisible) { _, _ in }
    }
    
    // MARK: - UI Components
    
    private var loadingView: some View {
        VStack {
            ProgressView()
            Text("加载中...")
                .padding()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "message.circle")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.6))
            Text("暂无消息")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.gray)
            Text("当您收到新消息时会显示在这里")
                .font(.body)
                .foregroundColor(.gray.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 60)
    }
    
    private var messageListView: some View {
        // 🎯 修复：如果 List 会是空的（没有新的朋友列表且没有好友列表），显示空状态
        if !isNewFriendsVisible && (!showFriendsList || existingFriends.isEmpty) {
            return AnyView(emptyStateView)
        }
        
        return AnyView(
            List {
                if isNewFriendsVisible {
                    newFriendsSection
                        .listSectionSeparator(.hidden, edges: .top)
                }
                
                if showFriendsList && !existingFriends.isEmpty {
                    friendsSection
                        .listSectionSeparator(.hidden, edges: .top)
                }
            }
            .listStyle(.plain)
            .listSectionSpacing(.compact)
            .onAppear {
                refreshMessageData()
            }
        )
    }
    
    private var newFriendsSection: some View {
        
        return Section(header:
            NewFriendsHeaderView(
                newFriendsCountManager: newFriendsCountManager,
                isMessagesExpanded: $isMessagesExpanded,
                currentMessagesCount: existingMessages.count,
                userManager: userManager // 🎯 新增：传入 userManager 用于标记已读
            )
        ) {
            if isMessagesExpanded {
                if existingMessages.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.2.badge.plus")
                            .font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.6))
                        Text("暂无新的朋友申请")
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach($existingMessages, id: \.id) { $message in
                        // 🎯 修改：使用 NewFriendRowView 替代 MessageItemView，使样式与好友列表一致
                        NewFriendRowView(
                            message: message,
                            avatarCache: $existingAvatarCache,
                            userNameCache: $existingUserNameCache,
                            onAccept: { requestId in
                                // 🎯 符合好友关系开发指南：接受好友申请
                                FriendshipManager.shared.fetchFriendshipRequests { requests, error in
                                    DispatchQueue.main.async {
                                        if error != nil {
                                            return
                                        }
                                        guard let requests = requests,
                                              let request = requests.first(where: { $0.objectId == requestId }) else {
                                            return
                                        }
                                        
                                        // 获取对方用户信息（发送申请的用户）
                                        let otherUserId = request.user.id
                                        let otherUserName = request.user.fullName
                                        let otherUserEmail = request.user.email
                                        let otherUserLoginType = request.user.loginType.toString()
                                        
                                        FriendshipManager.shared.acceptFriendshipRequest(request, attributes: nil) { success, errorMessage in
                                            DispatchQueue.main.async {
                                                if success {
                                                    // 🎯 新增：点击同意按钮应视为点亮爱心按钮
                                                    let otherUserAvatar = existingAvatarCache[otherUserId] ?? ""
                                                    onToggleFavorite(
                                                        otherUserId,
                                                        otherUserName,
                                                        otherUserEmail,
                                                        otherUserLoginType,
                                                        otherUserAvatar,
                                                        nil
                                                    )
                                                    
                                                    // 🎯 新增：操作后重新查询服务器状态
                                                    NotificationCenter.default.post(name: NSNotification.Name("RefreshNewFriends"), object: nil)
                                                    NotificationCenter.default.post(name: NSNotification.Name("FriendshipRequestUpdated"), object: nil)
                                                }
                                            }
                                        }
                                    }
                                }
                            },
                            onReject: { requestId in
                                // 🎯 符合好友关系开发指南：拒绝好友申请
                                FriendshipManager.shared.fetchFriendshipRequests { requests, error in
                                    DispatchQueue.main.async {
                                        if error != nil {
                                            return
                                        }
                                        guard let requests = requests,
                                              let request = requests.first(where: { $0.objectId == requestId }) else {
                                            return
                                        }
                                        FriendshipManager.shared.declineFriendshipRequest(request) { success, errorMessage in
                                            DispatchQueue.main.async {
                                                if success {
                                                    NotificationCenter.default.post(name: NSNotification.Name("RefreshNewFriends"), object: nil)
                                                    NotificationCenter.default.post(name: NSNotification.Name("FriendshipRequestUpdated"), object: nil)
                                                }
                                            }
                                        }
                                    }
                                }
                            },
                            onTap: {
                                handleMessageTap(message)
                            }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                let currentMessage = message
                                let messageType = currentMessage.messageType ?? ""
                                let content = currentMessage.content
                                
                                let isFriendRequestMessage = (messageType == "friend_request" || messageType == "favorite") && content.contains("对你发送了好友申请")
                                
                                if isFriendRequestMessage {
                                    if let requestId = currentMessage.objectId {
                                        handleDeclineFriendRequest(requestId: requestId)
                                    }
                                } else {
                                    deleteMessage(currentMessage)
                                }
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var friendsSection: some View {
        Section(header: Text("我的好友 (\(existingFriends.count))").font(.headline).foregroundColor(.primary)) {
            ForEach(existingFriends) { friend in
                
                FriendRowView(
                    friend: friend,
                    currentUserId: userManager.currentUser?.userId ?? "",  // 🔧 修复：使用真实的 userId 而不是 objectId
                    avatarCache: $existingAvatarCache,
                    userNameCache: $existingUserNameCache,
                    onlineStatusCache: $onlineStatusCache,
                    loginTypeCache: $loginTypeCache, // 🎯 新增：传递用户类型缓存
                    patMessages: $existingPatMessages,
                    patMessagesExpandedStates: $patMessagesExpandedStates,
                    onTap: {
                        handleFriendTap(friend)
                        // 🎯 修改：不立即发送关闭通知，让 handleFriendTap -> onMessageTap -> handleMessageTap 完成后自动关闭
                        // 通知会在 handleMessageTap 完成后发送
                    },
                    onPat: {
                        // 获取正确的朋友ID（非当前用户）
                        let friendId = friend.user1Id == userManager.currentUser?.id ? friend.user2Id : friend.user1Id
                        onPat(friendId)
                    },
                    patButtonPressed: $patButtonPressed,
                    onViewLocation: { friendId in
                        // 处理查看位置功能
                        handleViewLocation(friendId: friendId)
                    },
                    onUnfriend: {
                        // 🎯 macOS 右键菜单：解除好友关系
                        handleUnfriend(friend)
                    }
                )
                #if os(iOS)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        // 解除好友关系
                        handleUnfriend(friend)
                    } label: {
                        Label("解除关系", systemImage: "person.crop.circle.badge.minus")
                    }
                }
                #endif
            }
        }
    }
}
