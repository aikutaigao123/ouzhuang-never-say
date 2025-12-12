import SwiftUI

extension FriendsListView {
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("加载好友列表...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if friends.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("暂无好友")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                        
                        Text("当您与其他人互相喜欢时，\n他们就会出现在这里")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        // 新的朋友部分
                        
                        if !newFriends.isEmpty {
                            Section(header: newFriendsSectionHeader) {
                                if isNewFriendsExpanded {
                                    
                                    ForEach(newFriends, id: \.id) { newFriend in
                                        NewFriendRowView(
                                            message: newFriend,
                                            avatarCache: $avatarCache,
                                            userNameCache: $userNameCache,
                                            onAccept: { requestId in
                                                // 🎯 符合好友关系开发指南：接受好友申请
                                                // 通过 requestId 查询 FriendshipRequest，然后调用 acceptFriendshipRequest
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
                                                                    // 获取对方头像（从缓存或默认值）
                                                                    let otherUserAvatar = avatarCache[otherUserId] ?? ""
                                                                    
                                                                    // 调用 onToggleFavorite 点亮爱心按钮
                                                                    onToggleFavorite(
                                                                        otherUserId,
                                                                        otherUserName,
                                                                        otherUserEmail,
                                                                        otherUserLoginType,
                                                                        otherUserAvatar,
                                                                        nil // recordObjectId 可以为 nil
                                                                    )
                                                                    
                                                                    NotificationCenter.default.post(name: NSNotification.Name("RefreshNewFriends"), object: nil)
                                                                    NotificationCenter.default.post(name: NSNotification.Name("FriendshipRequestUpdated"), object: nil)
                                                                } else {
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            },
                                            onReject: { requestId in
                                                // 🎯 符合好友关系开发指南：拒绝好友申请
                                                // 通过 requestId 查询 FriendshipRequest，然后调用 declineFriendshipRequest
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
                                                                } else {
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            },
                                            onTap: {
                                                onNewFriendTap(newFriend)
                                                dismiss()
                                            }
                                        )
                                        .onAppear {
                                            // 🔍 新增：详细检查新朋友列表中的消息类型
                                            
                                            // 特别检查拍一拍消息
                                            if newFriend.messageType == "pat" || newFriend.content.contains("拍了拍") {
                                            }
                                            
                                            // 检查撤销消息
                                            if newFriend.content.contains("撤销了好友申请") {
                                            }
                                        }
                                    }
                                }
                            }
                            .onAppear {
                            }
                        } else {
                            Color.clear
                                .frame(height: 0)
                                .onAppear {
                                }
                        }
                        
                        
                        // 现有好友部分
                        if !friends.isEmpty {
                            Section(header: Text("我的好友").font(.headline).foregroundColor(.primary)) {
                                // UI层面：在ForEach前添加一个隐藏视图来触发打印
                                if friends.first != nil {
                                    Color.clear
                                        .frame(height: 0)
                                        .onAppear {
                                            let _ = friends.count
                                            let currentUserId = userManager.currentUser?.userId ?? "nil"
                                            let _ = userManager.currentUser?.id ?? "nil"
                                            for (_, f) in friends.enumerated() {
                                                let _ = f.user1Id == currentUserId
                                                let _ = f.user1Id == currentUserId ? f.user2Id : f.user1Id
                                                let _ = f.user1Id == currentUserId ? f.user2Name : f.user1Name
                                                let _ = f.user1Id == currentUserId ? f.user2LoginType : f.user1LoginType
                                            }
                                        }
                                }
                                ForEach(friends) { friend in
                                    FriendRowView(
                                        friend: friend,
                                        currentUserId: userManager.currentUser?.userId ?? "",  // 🔧 修复：使用真实的 userId 而不是 objectId
                                        avatarCache: $avatarCache,
                                        userNameCache: $userNameCache,
                                        onlineStatusCache: $onlineStatusCache,
                                        loginTypeCache: $loginTypeCache, // 🎯 新增：传递用户类型缓存
                                        patMessages: $patMessages,
                                        patMessagesExpandedStates: $patMessagesExpandedStates,
                                        onTap: {
                                            onFriendTap(friend)
                                            dismiss()
                                        },
                                        onPat: {
                                            // 🔍 关键调试：检查匹配逻辑
                                            let currentUserId = userManager.currentUser?.id ?? ""
                                            let currentUserUserId = userManager.currentUser?.userId ?? ""
                                            
                                            // 尝试用 id 匹配
                                            var friendName: String
                                            var friendId: String
                                            
                                            if friend.user1Id == currentUserId {
                                                friendName = friend.user2Name
                                                friendId = friend.user2Id
                                                let _ = friendId
                                            } else if friend.user1Id == currentUserUserId {
                                                friendName = friend.user2Name
                                                friendId = friend.user2Id
                                            } else if friend.user2Id == currentUserId {
                                                friendName = friend.user1Name
                                                friendId = friend.user1Id
                                            } else if friend.user2Id == currentUserUserId {
                                                friendName = friend.user1Name
                                                friendId = friend.user1Id
                                            } else {
                                                // 默认逻辑
                                                friendName = friend.user1Id == currentUserId ? friend.user2Name : friend.user1Name
                                                friendId = friend.user1Id == currentUserId ? friend.user2Id : friend.user1Id
                                            }
                                            
                                            // 立即显示弹窗反馈
                                            patAlertMessage = "正在向 \(friendName) 发送拍一拍..."
                                            showPatAlert = true
                                            
                                            // 调用handlePatFriend
                                            handlePatFriend(friend)
                                        },
                                        patButtonPressed: $patButtonPressed,
                                        onViewLocation: { friendId in
                                            // 🎯 修改：与查看详情按钮完全一致，调用 onTap() 逻辑
                                            onFriendTap(friend)
                                            dismiss()
                                        },
                                        onUnfriend: {
                                            // 🎯 macOS 右键菜单：解除好友关系
                                            onUnfriend(friend)
                                        }
                                    )
                                    #if os(iOS)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            // 解除好友关系
                                            let currentUserId = userManager.currentUser?.userId ?? "nil"
                                            let _ = friend.user1Id == currentUserId ? friend.user2Id : friend.user1Id
                                            let _ = friend.user1Id == currentUserId ? friend.user2Name : friend.user1Name
                                            let _ = isUserFavorited(friend.user1Id == currentUserId ? friend.user2Id : friend.user1Id)
                                            let _ = isUserFavoritedByMe(friend.user1Id == currentUserId ? friend.user2Id : friend.user1Id)
                                            let _ = favoriteRecords.map { "\($0.favoriteUserId)(status:\($0.status ?? "nil"))" }
                                            onUnfriend(friend)
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                let _ = isUserFavorited(friend.user1Id == currentUserId ? friend.user2Id : friend.user1Id)
                                                let _ = isUserFavoritedByMe(friend.user1Id == currentUserId ? friend.user2Id : friend.user1Id)
                                            }
                                        } label: {
                                            Label("解除关系", systemImage: "person.crop.circle.badge.minus")
                                        }
                                    }
                                    #endif
                                }
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
        }
        .overlay(patFeedbackOverlay)
        .onAppear {
            
            // 🔍 新增：打印UI显示和行数信息
            
            if friends.isEmpty {
            } else {
                for (_, friend) in friends.enumerated() {
                    let _ = friend.user1Id == userManager.currentUser?.id ? friend.user2Id : friend.user1Id
                    let _ = friend.user1Id == userManager.currentUser?.id ? friend.user2Name : friend.user1Name
                }
            }
            
            if newFriends.isEmpty {
            } else {
                for (_, _) in newFriends.enumerated() {
                }
            }
            
            
            // 首先从持久化缓存恢复数据，避免应用后台恢复时缓存丢失
            restoreCacheFromPersistence()
            
            loadFriends()
            loadNewFriends()
            
            // 与用户头像界面一致：不再使用批量查询，改为各个组件onAppear时实时查询
            // batchLoadUserNameAndAvatar() // 已删除：不再使用批量查询
            
        // 监听好友列表刷新通知
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RefreshFriendsList"),
            object: nil,
            queue: .main
        ) { _ in
            loadFriends()
            loadNewFriends()
        }
            
            // 监听匹配状态刷新通知
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("RefreshMatchStatus"),
                object: nil,
                queue: .main
            ) { _ in
                loadNewFriends()
            }
            
            // 监听新的朋友刷新通知
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("RefreshNewFriends"),
                object: nil,
                queue: .main
            ) { _ in
                loadNewFriends()
            }
            
            // 🎯 新增：监听新好友申请通知（IM实时推送）
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("NewFriendshipRequest"),
                object: nil,
                queue: .main
            ) { _ in
                loadNewFriends()
            }
            
            // 🎯 新增：监听好友申请状态更新通知
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("FriendshipRequestUpdated"),
                object: nil,
                queue: .main
            ) { _ in
                loadNewFriends()
            }
            
            // 监听应用恢复前台通知，重新恢复缓存
            NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { _ in
                // 应用恢复前台时，重新恢复缓存
                restoreCacheFromPersistence()
            }
            
        }
        .onDisappear {
            // 移除通知监听器
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("RefreshFriendsList"), object: nil)
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("RefreshMatchStatus"), object: nil)
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("RefreshNewFriends"), object: nil)
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("RefreshPatMessages"), object: nil)
        }
        .refreshable {
            // 支持下拉刷新
            loadFriends()
            loadNewFriends()
        }
        .alert("拍一拍", isPresented: $showPatAlert) {
            Button("确定") { }
        } message: {
            Text(patAlertMessage)
        }
    }
}



